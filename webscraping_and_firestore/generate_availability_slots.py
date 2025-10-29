import json
from pathlib import Path

MIN_FREE_MINUTES = 30  # keep only intervals >= 20 min (15-min gaps will be dropped)

def to_minutes(hhmm: str) -> int:
    """Convert 'HH:MM' to total minutes since midnight."""
    h, m = map(int, hhmm.split(":"))
    return h * 60 + m

def generate_slots(in_path="out_availability.jsonl",
                   out_path="availability_slots.jsonl"):
    with open(in_path) as fin, open(out_path, "w") as fout:
        for line in fin:
            obj = json.loads(line)
            common = {
                "roomId": obj["roomId"],
                "buildingCode": obj["buildingCode"],
                "roomNumber": obj["roomNumber"],
                "floor": obj["floor"],
                "campusZone": obj["campusZone"],
                "date": obj["date"]
            }
            for iv in obj["free"]:
                s, e = iv["start"], iv["end"]
                startMin, endMin = to_minutes(s), to_minutes(e)
                duration = endMin - startMin
                if duration < MIN_FREE_MINUTES:
                    continue  # drop short intervals (e.g., 1:45–2:00 = 15 min)
                slot = {
                    **common,
                    "start": s,
                    "end": e,
                    "startMin": startMin,
                    "endMin": endMin,
                    "durationMin": duration,
                }
                fout.write(json.dumps(slot) + "\n")
    print(f"Created {out_path}")

if __name__ == "__main__":
    generate_slots()
