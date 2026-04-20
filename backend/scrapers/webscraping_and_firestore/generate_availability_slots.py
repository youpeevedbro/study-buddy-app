import json
import os

MIN_FREE_MINUTES = 30  # keep only intervals >= 30 min

# Default paths relative to this file — used when running standalone.
# main.py in services/ overrides these before calling generate_slots().
_HERE = os.path.dirname(os.path.abspath(__file__))
_IN_PATH  = os.path.join(_HERE, "out_availability.jsonl")
_OUT_PATH = os.path.join(_HERE, "availability_slots.jsonl")


def to_minutes(hhmm: str) -> int:
    """Convert 'HH:MM' to total minutes since midnight."""
    h, m = map(int, hhmm.split(":"))
    return h * 60 + m


def generate_slots(in_path: str = None, out_path: str = None):
    """
    Converts out_availability.jsonl → availability_slots.jsonl.
    in_path / out_path default to module-level _IN_PATH / _OUT_PATH
    so callers in services/ can pass explicit paths without touching this file.
    """
    in_path  = in_path  or _IN_PATH
    out_path = out_path or _OUT_PATH

    with open(in_path, "r", encoding="utf-8") as fin, \
         open(out_path, "w", encoding="utf-8") as fout:
        for line in fin:
            if not line.strip():
                continue
            obj = json.loads(line)
            common = {
                "roomId":          obj["roomId"],
                "buildingCode":    obj["buildingCode"],
                "roomNumber":      obj["roomNumber"],
                "floor":           obj["floor"],
                "campusZone":      obj["campusZone"],
                "date":            obj["date"],
                "currentCheckins": 0,
            }
            for iv in obj["free"]:
                s, e = iv["start"], iv["end"]
                startMin, endMin = to_minutes(s), to_minutes(e)
                duration = endMin - startMin
                if duration < MIN_FREE_MINUTES:
                    continue
                slot = {
                    **common,
                    "start":       s,
                    "end":         e,
                    "startMin":    startMin,
                    "endMin":      endMin,
                    "durationMin": duration,
                    "locked_reports": 0,
                }
                fout.write(json.dumps(slot) + "\n")

    print("✅ Created availability_slots.jsonl")
    print(f"   - Input:  {in_path}")
    print(f"   - Output: {out_path}")


if __name__ == "__main__":
    generate_slots()