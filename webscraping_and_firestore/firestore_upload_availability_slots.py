from google.cloud import firestore
import json
import os
import time

def upload_slots(jsonl_path="availability_slots.jsonl", batch_size=500):
    db = firestore.Client()
    batch = db.batch()
    count = 0
    with open(jsonl_path, "r", encoding="utf-8") as f:
        for line in f:
            obj = json.loads(line)
            # unique, deterministic doc ID
            doc_id = f'{obj["roomId"]}_{obj["date"]}_{obj["startMin"]}_{obj["endMin"]}'
            ref = db.collection("availabilitySlots").document(doc_id)
            batch.set(ref, obj)
            count += 1
            if count % batch_size == 0:
                batch.commit()
                print(f"Committed {count} docs so far...")
                batch = db.batch()
                # time.sleep(0.1)

    if count % batch_size != 0:
        batch.commit()
        print(f"Final commit: {count} total docs uploaded.")

if __name__ == "__main__":
    upload_slots()
