# backend/routers/rooms.py
import base64
import json
import logging
from typing import List, Optional, Dict, Any

from fastapi import APIRouter, HTTPException, Query
from google.cloud import firestore

from services.firestore_client import get_db
from models.room import Room, RoomsResponse

router = APIRouter()
log = logging.getLogger("uvicorn.error")

# Each document in this collection is an availability slot for a room/time.
COLLECTION = "availabilitySlots"


def _doc_to_room(doc) -> Room:
    d = doc.to_dict() or {}
    return Room(
        id=doc.id,
        buildingCode=d.get("buildingCode", ""),
        roomNumber=str(d.get("roomNumber", "")),
        date=d.get("date", ""),
        start=d.get("start", ""),
        end=d.get("end", ""),
        # Firestore field stored as "locked_reports"
        lockedReports=int(d.get("locked_reports", 0)),
    )


def _encode_token(cursor: Dict[str, Any]) -> str:
    raw = json.dumps(cursor).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("utf-8")


def _decode_token(token: str) -> Dict[str, Any]:
    raw = base64.urlsafe_b64decode(token.encode("utf-8"))
    return json.loads(raw.decode("utf-8"))


@router.get("/", response_model=RoomsResponse)
def list_rooms(
    limit: int = Query(50, ge=1, le=200),
    pageToken: Optional[str] = Query(None, alias="pageToken"),
    building: Optional[str] = Query(None),
    date: Optional[str] = Query(None),
):
    """
    List rooms with cursor pagination.
    Collection: availabilitySlots

    Order: roomId, date, startMin
    pageToken is a urlsafe base64-encoded JSON:
      {
        "roomId": "...",
        "date": "...",
        "startMin": 420
      }

    Optional filters:
      - building -> filters by buildingCode
      - date     -> filters by date field ("YYYY-MM-DD")
    """
    try:
        db = get_db()
        col = db.collection(COLLECTION)

        # Start with base query and apply filters
        query = col
        if building:
            query = query.where("buildingCode", "==", building)
        if date:
            query = query.where("date", "==", date)

        # Deterministic order for pagination
        query = (
            query.order_by("roomId")
                 .order_by("date")
                 .order_by("startMin")
                 .limit(limit + 1)  # fetch one extra to detect "has more"
        )

        if pageToken:
            cursor = _decode_token(pageToken)
            query = query.start_after([
                cursor.get("roomId", ""),
                cursor.get("date", ""),
                cursor.get("startMin", 0),
            ])

        docs = list(query.stream())
        has_more = len(docs) > limit
        docs = docs[:limit]

        items: List[Room] = [_doc_to_room(d) for d in docs]

        next_token = None
        if has_more and docs:
            last = docs[-1].to_dict() or {}
            next_token = _encode_token({
                "roomId": last.get("roomId", ""),
                "date": last.get("date", ""),
                "startMin": last.get("startMin", 0),
            })

        return RoomsResponse(items=items, nextPageToken=next_token)

    except Exception as e:
        log.exception("list_rooms failed: %s", e)
        # If Firestore prompts for an index (composite index needed), follow the GCP link it prints.
        raise HTTPException(
            status_code=500,
            detail=f"/rooms failed: {type(e).__name__}: {e}",
        )


@router.post("/{room_id}/report_locked")
def report_locked(room_id: str):
    """
    Increment the locked_reports counter for a specific availability slot.

    Returns the new lockedReports value exposed to the frontend.
    """
    try:
        db = get_db()
        doc_ref = db.collection(COLLECTION).document(room_id)
        snap = doc_ref.get()
        if not snap.exists:
            raise HTTPException(status_code=404, detail="Room slot not found")

        # Atomically increment the Firestore field "locked_reports"
        doc_ref.update({"locked_reports": firestore.Increment(1)})

        new_snap = doc_ref.get()
        data = new_snap.to_dict() or {}
        new_count = int(data.get("locked_reports", 0))

        log.info("report_locked: room_id=%s new_count=%d", room_id, new_count)
        return {"lockedReports": new_count}
    except HTTPException:
        raise
    except Exception as e:
        log.exception("report_locked failed for room_id=%s: %s", room_id, e)
        raise HTTPException(
            status_code=500,
            detail=f"report_locked failed: {type(e).__name__}: {e}",
        )


@router.post("/admin/reset_locked_reports")
def reset_locked_reports():
    """
    Reset locked_reports = 0 for all availabilitySlots documents.

    Intended to be called by a scheduled job once per day (around 00:00).

    Uses list_documents() instead of query.stream() to avoid Firestore's
    internal retry bug that caused:
      AttributeError: '_UnaryStreamMultiCallable' object has no attribute '_retry'
    """
    try:
        db = get_db()
        col = db.collection(COLLECTION)

        log.info("reset_locked_reports: starting full reset for collection '%s'", COLLECTION)

        batch = db.batch()
        updated = 0
        BATCH_SIZE = 400

        # list_documents() yields DocumentReference objects (no query retry bug)
        for i, doc_ref in enumerate(col.list_documents(page_size=BATCH_SIZE), start=1):
            batch.update(doc_ref, {"locked_reports": 0})
            updated += 1

            if i % BATCH_SIZE == 0:
                log.info(
                    "reset_locked_reports: committing intermediate batch of %d docs (total so far=%d)",
                    BATCH_SIZE,
                    updated,
                )
                batch.commit()
                batch = db.batch()

        # Commit any remaining updates
        if updated % BATCH_SIZE != 0:
            log.info(
                "reset_locked_reports: committing final batch, total docs=%d",
                updated,
            )
            batch.commit()

        log.info("reset_locked_reports: DONE, roomsReset=%d", updated)
        return {"status": "ok", "roomsReset": updated}

    except Exception as e:
        log.exception("reset_locked_reports: FAILED: %s", e)
        raise HTTPException(
            status_code=500,
            detail=f"reset_locked_reports failed: {type(e).__name__}: {e}",
        )
