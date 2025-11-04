from fastapi import APIRouter, HTTPException
from typing import List
from backend.services.firestore_client import get_db
from backend.models.room import Room, RoomsResponse

router = APIRouter()
COLLECTION = "availabilitySlots"

def _doc_to_room(doc) -> Room:
    d = doc.to_dict() or {}
    return Room(
        id=doc.id,
        buildingCode=d.get("buildingCode", ""),
        roomNumber=str(d.get("roomNumber", "")),
        start=d.get("start", ""),
        end=d.get("end", ""),
        lockedReports=int(d.get("locked_reports", 0)),
    )

@router.get("/", response_model=RoomsResponse)
def list_rooms(limit: int = 25):
    try:
        db = get_db()
        # Minimal test: just fetch a few docs from the known collection
        docs = list(db.collection(COLLECTION).limit(limit).stream())
        items: List[Room] = [_doc_to_room(d) for d in docs]
        return RoomsResponse(items=items, nextPageToken=None)
    except Exception as e:
        # Surface exact failure in response while we debug
        raise HTTPException(status_code=500, detail=f"/rooms failed: {type(e).__name__}: {e}")
