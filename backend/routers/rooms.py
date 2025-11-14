import base64
import json
from typing import List, Optional, Dict, Any

from fastapi import APIRouter, HTTPException, Query
from google.cloud import firestore

from services.firestore_client import get_db
from models.room import Room, RoomsResponse

router = APIRouter()

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
        # If Firestore prompts for an index (composite index needed), follow the GCP link it prints.
        raise HTTPException(
            status_code=500,
            detail=f"/rooms failed: {type(e).__name__}: {e}",
        )

@router.post("/rooms/{room_id}/report_locked")
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

        return {"lockedReports": new_count}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"report_locked failed: {type(e).__name__}: {e}",
        )

@router.post("/admin/reset_locked_reports")
def reset_locked_reports():
    """
    Reset locked_reports = 0 for all availabilitySlots documents.

    Intended to be called by a scheduled job once per day (around 00:00).
    """
    try:
        db = get_db()
        col = db.collection(COLLECTION)

        batch = db.batch()
        updated = 0

        for i, doc in enumerate(col.stream(), start=1):
            batch.update(doc.reference, {"locked_reports": 0})
            updated += 1

            # Firestore batches limited to 500 writes; keep some margin.
            if i % 400 == 0:
                batch.commit()
                batch = db.batch()

        batch.commit()
        return {"status": "ok", "roomsReset": updated}
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"reset_locked_reports failed: {type(e).__name__}: {e}",
        )
