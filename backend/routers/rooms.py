# backend/routers/rooms.py
import base64
import json
from datetime import datetime
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, HTTPException, Query
from services.firestore_client import get_db
from models.room import Room, RoomsResponse

# ---- Timezone (America/Los_Angeles). Falls back to UTC if zoneinfo missing.
try:
    from zoneinfo import ZoneInfo
    TZ = ZoneInfo("America/Los_Angeles")
except Exception:
    TZ = None  # use UTC fallback below

router = APIRouter()
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
    pageToken: Optional[str] = None,
    building: Optional[str] = Query(None, description="buildingCode like AS, ECS, LA1"),
):
    """
    Returns ONLY today's available room slots (from `availabilitySlots`).
    Optional filter: `?building=AS`

    Stable sort: roomId, date, startMin
    Cursor token: {"roomId": "...", "date": "yyyy-MM-dd", "startMin": int}
    """
    try:
        db = get_db()
        col = db.collection(COLLECTION)

        # Resolve 'today' in campus TZ (or UTC fallback)
        now = datetime.now(TZ) if TZ else datetime.utcnow()
        today = now.strftime("%Y-%m-%d")

        # Base query: only today's docs
        q = col.where("date", "==", today)

        # Optional: filter by building code
        if building:
            q = q.where("buildingCode", "==", building)

        # Deterministic order + fetch +1 to detect "has more"
        q = (
            q.order_by("roomId")
             .order_by("date")
             .order_by("startMin")
             .limit(limit + 1)
        )

        # Cursor pagination
        if pageToken:
            cursor = _decode_token(pageToken)
            q = q.start_after([
                cursor.get("roomId", ""),
                cursor.get("date", ""),
                cursor.get("startMin", 0),
            ])

        docs = list(q.stream())
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
        # Print full error (includes Firestore "create index" link) to terminal.
        detail = f"/rooms failed: {type(e).__name__}: {e}"
        print("\n" + "=" * 70)
        print("🔥 Firestore query failed — likely needs a composite index.")
        print(detail)
        print("=" * 70 + "\n")
        raise HTTPException(status_code=500, detail=detail)
