"""
semester_utils.py
Location: backend/scrapers/webscraping_and_firestore/

Firestore semester cleanup logic.
- Tracks Fall, Spring, Summer only
- Deletes stale semesters by querying the sem_year tag on every doc
"""

import logging
from google.cloud import firestore

logger = logging.getLogger(__name__)

VALID_SEMS = ["Spring", "Summer", "Fall"]


def firestore_key(sem: str, year: int) -> str:
    return f"{sem}_{year}"


def get_all_stored_semesters(db: firestore.Client) -> list[tuple[str, int]]:
    """Returns all (sem, year) stored in Firestore under class_availability."""
    stored = []
    for doc in db.collection("class_availability").list_documents():
        parts = doc.id.split("_", 1)
        if len(parts) == 2 and parts[0] in VALID_SEMS:
            try:
                stored.append((parts[0], int(parts[1])))
            except ValueError:
                pass
    return stored


def prune_stale_semesters(db: firestore.Client, keep: list[tuple[str, int]]):
    """Deletes any stored semester not in the keep list."""
    keep_set = set(keep)
    for sem, year in get_all_stored_semesters(db):
        if (sem, year) not in keep_set:
            delete_semester_data(db, sem, year)


def delete_semester_data(db: firestore.Client, sem: str, year: int):
    """
    Deletes all Firestore data for a semester by querying the sem_year tag:
      - availabilitySlots flat collection
      - buildings/.../rooms/.../busy/{date} docs
      - buildings/.../rooms/.../availability/{date} docs
      - class_availability metadata doc
    """
    key = firestore_key(sem, year)
    logger.info(f"🗑  Deleting stale: {key}")

    _batch_delete_query(db, db.collection("availabilitySlots").where("sem_year", "==", key))

    for bldg in db.collection("buildings").list_documents():
        for room in bldg.collection("rooms").list_documents():
            for sub in ("busy", "availability"):
                _batch_delete_query(db, room.collection(sub).where("sem_year", "==", key))

    db.collection("class_availability").document(key).delete()
    logger.info(f"  ✅ Deleted {key}")


def _batch_delete_query(db: firestore.Client, query, chunk: int = 400):
    batch = db.batch()
    count = 0
    for doc in query.stream():
        batch.delete(doc.reference)
        count += 1
        if count % chunk == 0:
            batch.commit()
            batch = db.batch()
    if count % chunk != 0:
        batch.commit()
    if count:
        logger.info(f"    Deleted {count} docs")