# backend/routers/rooms.py
import base64, json
from fastapi import APIRouter, HTTPException, Query
from typing import List, Optional, Dict, Any
from services.firestore_client import get_db
from models.room import Room, RoomsResponse

router = APIRouter()
COLLECTION = "availabilitySlots"

def _doc_to_room(doc) -> Room:
    d = doc.to_dict() or {}
    return Room(
        id=doc.id,
        buildingCode=d.get("buildingCode", ""),
        roomNumber=str(d.get("roomNumber", "")),
        date=d.get("date", ""),                     # <-- now included
        start=d.get("start", ""),
        end=d.get("end", ""),
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
    limit: int = Query(50, ge=1, le=200),           # default 50
    pageToken: Optional[str] = None
):
    """
    List rooms with cursor pagination.
    Order: roomId, date, startMin
    pageToken is a urlsafe base64-encoded JSON: {"roomId": "...", "date": "...", "startMin": 420}
    """
    try:
        db = get_db()
        col = db.collection(COLLECTION)

        # Order for deterministic pagination
        query = (
            col.order_by("roomId")
               .order_by("date")
               .order_by("startMin")
               .limit(limit + 1)  # fetch one extra to detect "has more"
        )

        if pageToken:
            cursor = _decode_token(pageToken)
            query = query.start_after([cursor.get("roomId", ""), cursor.get("date", ""), cursor.get("startMin", 0)])

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
        raise HTTPException(status_code=500, detail=f"/rooms failed: {type(e).__name__}: {e}")
