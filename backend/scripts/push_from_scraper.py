import os, requests, argparse

API = os.getenv("API_BASE", "http://127.0.0.1:8080")

def post_json(path: str, payload: dict):
    r = requests.post(f"{API}{path}", json=payload, timeout=300)
    r.raise_for_status()
    print(path, "→", r.json())

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--buildings", default=os.getenv("BUILDINGS_JSON", "../assets/building_codes.json"))
    ap.add_argument("--classes", default=os.getenv("CLASSES_JSON", "../classes.json"))
    ap.add_argument("--term", default=os.getenv("CURRENT_TERM", "Fall_2025"))
    args = ap.parse_args()

    post_json("/ingest/buildings", {"path": args.buildings})
    post_json("/ingest/classes", {"path": args.classes, "term": args.term})
