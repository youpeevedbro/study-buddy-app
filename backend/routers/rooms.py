# backend/routers/rooms.py
import base64
import json
from datetime import datetime
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, HTTPException, Query

from services.firestore_client import get_db
from models.room import Room, RoomsResponse
from google.cloud.firestore_v1 import FieldFilter

# Try to respect local timezone (PST/PDT for CSULB)
try:
    from zoneinfo import ZoneInfo

    TZ = ZoneInfo("America/Los_Angeles")
except Exception:  # pragma: no cover - fallback for older Python
    TZ = None

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


def _parse_hhmm_to_min(hhmm: Optional[str]) -> Optional[int]:
    """
    Convert "HH:mm" -> minutes after midnight.
    Returns None if the string is missing or malformed.
    """
    if not hhmm:
        return None
    try:
        h, m = hhmm.split(":")
        return int(h) * 60 + int(m)
    except Exception:
        return None


@router.get("/", response_model=RoomsResponse)
def list_rooms(
    limit: int = Query(50, ge=1, le=200),
    pageToken: Optional[str] = None,
    building: Optional[str] = Query(
        None, description="buildingCode like AS, ECS, LA1"
    ),
    startTime: Optional[str] = Query(
        None, description="HH:mm (inclusive start of desired window)"
    ),
    endTime: Optional[str] = Query(
        None, description="HH:mm (exclusive end of desired window)"
    ),
):
    """
    List *today's* available room slots (from `availabilitySlots`).

    Time filtering uses **overlap semantics**:

      - startTime only:
            return slots where endMin > startMinParam
              (room is free at/after that time)

      - endTime only:
            return slots where startMin < endMinParam
              (room is free up until that time)

      - both startTime & endTime:
            return slots that overlap [startTime, endTime), i.e.
                endMin   > startMinParam
            AND startMin < endMinParam

        We push part of this into Firestore:
            where("startMin", "<", endMinParam)
        and finish `endMin > startMinParam` in Python.

    Results are ordered (and paginated) by:
        roomId, date, startMin
    and returned inside a RoomsResponse with nextPageToken.
    """
    try:
        db = get_db()
        col = db.collection(COLLECTION)

        # --- Determine "today" in CSULB time ---
        now = datetime.now(TZ) if TZ else datetime.utcnow()
        today = now.strftime("%Y-%m-%d")

        # --- Base query: today's slots only ---
        q = col.where("date", "==", today)

        # Optional: building filter
        if building:
            q = q.where(filter=FieldFilter("buildingCode", "==", building))

        # --- Parse time filters ---
        start_min_param = _parse_hhmm_to_min(startTime)
        end_min_param = _parse_hhmm_to_min(endTime)

        # --- Apply time filters (overlap semantics) ---
        need_python_filter = False

        if start_min_param is not None and end_min_param is not None:
            # Overlap:
            #   endMin > start_min_param  AND  startMin < end_min_param
            #
            # Firestore side: limit startMin < end_min_param
            q = q.where(filter=FieldFilter("startMin", "<", end_min_param))
            # We'll enforce `endMin > start_min_param` in Python
            need_python_filter = True

        elif start_min_param is not None:
            # Free at/after this time -> slot must extend past start
            q = q.where(filter=FieldFilter("endMin", ">", start_min_param))

        elif end_min_param is not None:
            # Free until this time -> slot must start before end
            q = q.where(filter=FieldFilter("startMin", "<", end_min_param))

        # --- Deterministic ordering + overfetch (+1) for has_more ---
        q = (
            q.order_by("roomId")
            .order_by("date")
            .order_by("startMin")
            .limit(limit + 1)
        )

        # --- Cursor pagination ---
        if pageToken:
            cursor = _decode_token(pageToken)
            q = q.start_after(
                [
                    cursor.get("roomId", ""),
                    cursor.get("date", ""),
                    cursor.get("startMin", 0),
                ]
            )

        # --- Fetch documents ---
        docs = list(q.stream())

        # Complete Python-side filter for overlap both-times case
        if need_python_filter and start_min_param is not None:
            filtered: List[Any] = []
            for d in docs:
                data = d.to_dict() or {}
                end_min = data.get("endMin", -1)
                # Keep only slots whose end is after the window start
                if end_min > start_min_param:
                    filtered.append(d)
            docs = filtered

        has_more = len(docs) > limit
        docs = docs[:limit]

        items: List[Room] = [_doc_to_room(d) for d in docs]

        next_token = None
        if has_more and docs:
            last_data = docs[-1].to_dict() or {}
            next_token = _encode_token(
                {
                    "roomId": last_data.get("roomId", ""),
                    "date": last_data.get("date", ""),
                    "startMin": last_data.get("startMin", 0),
                }
            )

        return RoomsResponse(items=items, nextPageToken=next_token)

    except Exception as e:
        # Helpful logging if Firestore wants a composite index
        detail = f"/rooms failed: {type(e).__name__}: {e}"
        print("\n" + "=" * 70)
        print("🔥 Firestore /rooms query failed — possibly needs a composite index.")
        print(detail)
        print("=" * 70 + "\n")
        raise HTTPException(status_code=500, detail=detail)
