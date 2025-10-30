# firestore_upload_nested.py — emulator-aware, persistent-ready version
import json, os, time, random, sys
from typing import Dict, Iterable, Tuple, Set
from google.cloud import firestore
from google.api_core import exceptions as gex

# ---------- INPUT FILES ----------
BUSY_JSONL  = "out_busy.jsonl"
FREE_JSONL  = "out_availability.jsonl"
OVERRIDES   = "overrides_buildings.json"

# ---------- AUTO-DETECT ENVIRONMENT ----------
IN_EMULATOR = bool(os.getenv("FIRESTORE_EMULATOR_HOST"))
def env_or_default(var, default, cast_func=lambda x: x):
    v = os.getenv(var)
    return cast_func(v) if v is not None else default

# ---------- TUNING KNOBS ----------
BATCH_SIZE = 500 # docs per batch commit
INTER_COMMIT_SLEEP = 0.0 # seconds
RESUME_MODE = env_or_default("FS_RESUME", "true").lower() in ("1", "true", "yes")
FILTER_CODES = None
codes_str = os.getenv("FS_CODES")
if codes_str:
    FILTER_CODES = {c.strip().upper() for c in codes_str.split(",") if c.strip()}

BACKOFF_MAX_RETRIES = 16
BACKOFF_BASE_SLEEP = 2.0
BACKOFF_MAX_SLEEP  = 90.0

# ---------- FIRESTORE CLIENT ----------
db = firestore.Client()

# ---------- HELPERS ----------
def _commit_with_backoff(batch, desc: str):
    attempt = 0
    while True:
        try:
            batch.commit()
            return
        except (gex.ResourceExhausted, gex.ServiceUnavailable, gex.DeadlineExceeded, gex.RetryError) as e:
            sleep = min(
                BACKOFF_MAX_SLEEP,
                BACKOFF_BASE_SLEEP * (2 ** attempt) * (1.0 + random.random() * 0.3),
            )
            print(f"[{desc}] backoff {attempt+1}/{BACKOFF_MAX_RETRIES} — sleep {sleep:.1f}s … ({type(e).__name__})")
            time.sleep(sleep)
            attempt += 1
            if attempt >= BACKOFF_MAX_RETRIES:
                print(f"[{desc}] final cool-down {BACKOFF_MAX_SLEEP:.1f}s before last retry…")
                time.sleep(BACKOFF_MAX_SLEEP)
                batch.commit()
                return

def batched_set(pairs: Iterable[tuple], batch_size=BATCH_SIZE, desc="write") -> int:
    batch = db.batch()
    i = total = 0
    last_log = time.time()
    for ref, data, merge in pairs:
        batch.set(ref, data, merge=merge)
        i += 1; total += 1
        if i >= batch_size:
            _commit_with_backoff(batch, desc)
            time.sleep(INTER_COMMIT_SLEEP)
            batch = db.batch(); i = 0
            if time.time() - last_log > 10:
                print(f"[{desc}] wrote {total} docs so far…"); last_log = time.time()
    if i: _commit_with_backoff(batch, desc)
    return total

def split_room_id(room_id: str) -> Tuple[str, str]:
    return room_id.split("-", 1)

def _code_allowed(bcode: str) -> bool:
    return (FILTER_CODES is None) or (bcode in FILTER_CODES)

def load_overrides(path: str) -> Dict[str, str]:
    if not os.path.exists(path): return {}
    with open(path, "r", encoding="utf-8") as f: raw = json.load(f)
    return {k.strip().upper(): v.strip() for k, v in raw.items() if v}

def collect_codes_from_jsonl(path: str) -> Set[str]:
    codes = set()
    if not os.path.exists(path): return codes
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            if not line.strip(): continue
            obj = json.loads(line)
            rid = obj.get("roomId", "")
            if "-" in rid: codes.add(rid.split("-", 1)[0])
    return codes

# ---------- BUILDINGS UPSERT ----------
def upsert_buildings():
    overrides = load_overrides(OVERRIDES)
    codes = collect_codes_from_jsonl(BUSY_JSONL) | collect_codes_from_jsonl(FREE_JSONL) | set(overrides.keys())
    if FILTER_CODES is not None: codes = codes & FILTER_CODES
    writes = []
    for code in sorted(codes):
        name = overrides.get(code, code)
        ref = db.collection("buildings").document(code)
        writes.append((ref, {"code": code, "name": name}, True))
    n = batched_set(writes, desc="buildings")
    print(f"Upserted buildings: {n}")

# ---------- ROOM HELPERS ----------
def ensure_room_doc(bcode: str, room_id: str):
    room_ref = db.collection("buildings").document(bcode).collection("rooms").document(room_id)
    room_ref.set({"roomId": room_id, "building_code": bcode}, merge=True)

# ---------- UPLOADERS ----------
def upload_busy():
    if not os.path.exists(BUSY_JSONL):
        print(f"Skip: {BUSY_JSONL} not found"); return
    writes = []
    with open(BUSY_JSONL, "r", encoding="utf-8") as f:
        for line in f:
            if not line.strip(): continue
            obj = json.loads(line)
            room_id, date = obj["roomId"], obj["date"]
            bcode, room = split_room_id(room_id)
            if not _code_allowed(bcode): continue
            ensure_room_doc(bcode, room_id)
            doc_ref = (db.collection("buildings").document(bcode)
                         .collection("rooms").document(room_id)
                         .collection("busy").document(date))
            if RESUME_MODE and doc_ref.get().exists: continue
            payload = {**obj, "building_code": bcode, "room": room, "roomId": room_id}
            writes.append((doc_ref, payload, False))
    n = batched_set(writes, desc="busy")
    print(f"Uploaded busy docs: {n}")

def upload_availability():
    if not os.path.exists(FREE_JSONL):
        print(f"Skip: {FREE_JSONL} not found"); return
    writes = []
    with open(FREE_JSONL, "r", encoding="utf-8") as f:
        for line in f:
            if not line.strip(): continue
            obj = json.loads(line)
            room_id, date = obj["roomId"], obj["date"]
            bcode, room = split_room_id(room_id)
            if not _code_allowed(bcode): continue
            ensure_room_doc(bcode, room_id)
            doc_ref = (db.collection("buildings").document(bcode)
                         .collection("rooms").document(room_id)
                         .collection("availability").document(date))
            if RESUME_MODE and doc_ref.get().exists: continue
            payload = {**obj, "building_code": bcode, "room": room, "roomId": room_id}
            writes.append((doc_ref, payload, False))
    n = batched_set(writes, desc="availability")
    print(f"Uploaded availability docs: {n}")

# ---------- MAIN ----------
if __name__ == "__main__":
    try:
        print("Starting Firestore upload...")
        print("Target:", "EMULATOR" if IN_EMULATOR else "PRODUCTION")
        if FILTER_CODES:
            print("Building filter active:", ", ".join(sorted(FILTER_CODES)))
        print(f"RESUME_MODE={RESUME_MODE}, BATCH_SIZE={BATCH_SIZE}, INTER_COMMIT_SLEEP={INTER_COMMIT_SLEEP}s")

        upsert_buildings()
        upload_busy()
        upload_availability()
        print("✅ Done.")
    except Exception as e:
        print("❌ Upload failed:", repr(e))
        sys.exit(1)
