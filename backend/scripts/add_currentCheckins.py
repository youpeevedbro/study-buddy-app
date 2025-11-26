# backend/scripts/add_currentCheckins.py
from google.cloud import firestore

BATCH_SIZE = 500  # you can drop this to 200 if you want smaller batches


def main():
    db = firestore.Client()
    col = db.collection("availabilitySlots")

    total_updated = 0
    last_doc = None  # we'll store the last DocumentSnapshot here

    while True:
        # Base query: order by roomId so pagination is stable
        q = col.order_by("roomId").limit(BATCH_SIZE)

        # If we already processed a batch, continue after the last doc
        if last_doc is not None:
            q = q.start_after(last_doc)

        # Fetch this batch
        docs = list(q.stream(timeout=120))

        if not docs:
            break  # no more documents

        for doc in docs:
            data = doc.to_dict() or {}
            if "currentCheckins" not in data:
                doc.reference.update({"currentCheckins": 0})
                total_updated += 1

        # Remember the last document for the next loop
        last_doc = docs[-1]

        print(f"Processed batch, total updated so far: {total_updated}")

    print(f"Done. Updated {total_updated} documents.")


if __name__ == "__main__":
    main()
