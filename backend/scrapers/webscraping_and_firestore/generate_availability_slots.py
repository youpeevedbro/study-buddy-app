import json
import os
from pathlib import Path

MIN_FREE_MINUTES = 30  # keep only intervals >= 30 min

def to_minutes(hhmm: str) -> int:
    """Convert 'HH:MM' to total minutes since midnight."""
    h, m = map(int, hhmm.split(":"))
    return h * 60 + m

def generate_slots():
    # --- paths relative to this script ---
    here = os.path.dirname(__file__)
    in_path = os.path.join(here, "out_availability.jsonl")
    out_path = os.path.join(here, "availability_slots.jsonl")

    # --- open and process ---
    with open(in_path, "r", encoding="utf-8") as fin, open(out_path, "w", encoding="utf-8") as fout:
        for line in fin:
            if not line.strip():
                continue
            obj = json.loads(line)
            common = {
                "roomId": obj["roomId"],
                "buildingCode": obj["buildingCode"],
                "roomNumber": obj["roomNumber"],
                "floor": obj["floor"],
                "campusZone": obj["campusZone"],
                "date": obj["date"],
            }
            for iv in obj["free"]:
                s, e = iv["start"], iv["end"]
                startMin, endMin = to_minutes(s), to_minutes(e)
                duration = endMin - startMin
                if duration < MIN_FREE_MINUTES:
                    continue  # drop short intervals
                slot = {
                    **common,
                    "start": s,
                    "end": e,
                    "startMin": startMin,
                    "endMin": endMin,
                    "durationMin": duration,
                }
                fout.write(json.dumps(slot) + "\n")

    print("✅ Created availability_slots.jsonl")
    print(f"   - Input:  {in_path}")
    print(f"   - Output: {out_path}")

if __name__ == "__main__":
    generate_slots()
