from fastapi import APIRouter, HTTPException, Query, Security
from auth import security
from typing import List, Optional
from services.firestore_client import get_db
from models.room import Room, RoomsResponse

COLLECTION = "availabilitySlots"

router = APIRouter(
    prefix="/rooms",
    tags=["rooms"],
    dependencies=[Security(security)]  # 🔒 Full section protection
)

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

@router.get("", response_model=RoomsResponse, include_in_schema=False)  # accept /rooms (hidden in docs)
@router.get("/", response_model=RoomsResponse)
def list_rooms(
    limit: int = Query(25, ge=1, le=500),
    building: Optional[str] = None,
    start: Optional[int] = Query(None, description="Start time in minutes"),
    end: Optional[int]   = Query(None, description="End time in minutes"),
):
    """
    Filters:
      - building: 'AS', 'COB', etc.
      - start/end (minutes): overlaps window if (startMin < end) & (endMin > start)
    """
    try:
        db = get_db()
        q = db.collection(COLLECTION)

        if building:
            q = q.where("buildingCode", "==", building)

        # Use ONE inequality in Firestore to stay within limits.
        used_time_filter = False
        if end is not None:
            q = q.where("startMin", "<", end)
            used_time_filter = True

        # If you order, the first order_by must match the inequality field.
        # This may require an index if combined with building filter.
        try:
            q = q.order_by("startMin")
        except Exception:
            # If Firestore complains about indexing, you can skip ordering or create the suggested index.
            pass

        docs = list(q.limit(limit).stream())

        items: List[Room] = []
        for doc in docs:
            d = doc.to_dict() or {}
            # Apply the second half of the overlap in Python (endMin > start)
            if used_time_filter and start is not None:
                end_min = int(d.get("endMin", -1))
                if not (end_min > start):
                    continue  # skip non-overlapping

            # Map to your response model
            items.append(
                Room(
                    id=doc.id,
                    buildingCode=d.get("buildingCode", ""),
                    roomNumber=str(d.get("roomNumber", "")),
                    start=d.get("start", ""),
                    end=d.get("end", ""),
                    lockedReports=int(d.get("locked_reports", 0)),
                )
            )

        items.sort(key=lambda r: (r.start, r.buildingCode, r.roomNumber))

        return RoomsResponse(items=items, nextPageToken=None)

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"/rooms failed: {type(e).__name__}: {e}")
