import os
import json
from fastapi import APIRouter, HTTPException
from firestore_client import db
from models import Meeting
from utils import parse_days, parse_time_range, split_location

router = APIRouter(prefix="/ingest", tags=["ingest"])

# 🔧 Define your fixed default data folder (no more ../assets nonsense)
DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "web_scraping")

def resolve_path(raw_path: str | None) -> str:
    """Resolve file path to either absolute or under web_scraping/."""
    if not raw_path:
        raise HTTPException(status_code=400, detail="Missing 'path'")
    abs_path = raw_path if os.path.isabs(raw_path) else os.path.join(DATA_DIR, raw_path)
    abs_path = os.path.normpath(abs_path)
    if not os.path.exists(abs_path):
        raise HTTPException(status_code=404, detail=f"File not found: {abs_path}")
    return abs_path


@router.post("/buildings")
def ingest_buildings(payload: dict):
    """
    POST body: { "path": "building_codes.json" }
    Reads JSON: { "EN2": "ENGINEERING 2", ... }
    """
    abs_path = resolve_path(payload.get("path"))
    with open(abs_path, "r", encoding="utf-8") as f:
        data: dict[str, str] = json.load(f)

    batch = db().batch()
    col = db().collection("buildings")
    for code, name in data.items():
        batch.set(col.document(code), {"code": code, "name": name})
    batch.commit()

    return {"status": "ok", "written": len(data), "collection": "buildings"}


@router.post("/classes")
def ingest_classes(payload: dict):
    """
    POST body: { "path": "classes.json", "term": "Fall_2025" }
    Each row: [subject, session_title, days, time_label, location]
    """
    abs_path = resolve_path(payload.get("path"))
    term = payload.get("term")
    if not term:
        raise HTTPException(status_code=400, detail="Missing 'term'")

    with open(abs_path, "r", encoding="utf-8") as f:
        rows = json.load(f)

    col = db().collection("meetings")
    batch = db().batch()
    written = 0
    skipped = 0

    for row in rows:
        if not isinstance(row, list) or len(row) < 5:
            skipped += 1
            continue
        subject, session_title, days_str, time_label, location = row[:5]
        if str(location).strip().upper() == "ONLINE-ONLY":
            skipped += 1
            continue

        days = parse_days(days_str)
        if not days:
            skipped += 1
            continue

        start_min, end_min = parse_time_range(time_label)
        if start_min == 0 and end_min == 0:
            skipped += 1
            continue

        bcode, rnum = split_location(location)
        for wd in days:
            m = Meeting(
                term=term,
                subject=subject,
                building_code=bcode,
                room_number=rnum,
                weekday=wd,
                start_min=start_min,
                end_min=end_min,
                time_label=time_label,
                session_title=session_title,
            )
            batch.set(col.document(), m.model_dump())
            written += 1
            if written % 450 == 0:
                batch.commit()
                batch = db().batch()

    batch.commit()
    return {
        "status": "ok",
        "written_meetings": written,
        "skipped_rows": skipped,
        "collection": "meetings",
    }
