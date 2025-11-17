# backend/routers/rooms.py
import base64
import json
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, HTTPException, Query

from services.firestore_client import get_db
from models.room import Room, RoomsResponse

try:
    from zoneinfo import ZoneInfo
    TZ = ZoneInfo("America/Los_Angeles")
except Exception:
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
    building: Optional[str] = Query(None, description="buildingCode like AS, ECS, LA1"),
    startTime: Optional[str] = Query(None, description="HH:mm (inclusive start of desired window)"),
    endTime: Optional[str] = Query(None, description="HH:mm (exclusive end of desired window)"),
):
    """
    Returns ONLY today's available room slots (from `availabilitySlots`).

    Time filter semantics (overlap mode):

    - start only (T):  slot contains T
                       => startMin <= T < endMin

    - end only (E):    slot starts before E
                       => startMin < E

    - both S–E:        slot overlaps [S,E)
                       => endMin > S AND startMin < E

    Because Firestore only allows range filters on ONE field, we:
    - push one side of the inequality into Firestore
    - finish the other side(s) in Python.
    """
    try:
        db = get_db()
        col = db.collection(COLLECTION)

        now = datetime.now(TZ) if TZ else datetime.utcnow()
        # today = (now + timedelta(days=1)).strftime("%Y-%m-%d") # THIS IS FOR TESTING
        today = now.strftime("%Y-%m-%d")

        # Base query: today only
        q = col.where("date", "==", today)

        # Optional: building
        if building:
            q = q.where("buildingCode", "==", building)

        # Parse time params
        start_min_param = _parse_hhmm_to_min(startTime)
        end_min_param = _parse_hhmm_to_min(endTime)

        # Flags for Python-side filtering
        filter_contains_T = False   # start-only case
        filter_overlap_SE = False   # both S–E case

        # --- Apply Firestore-side filters (only one inequality field allowed) ---
        if start_min_param is not None and end_min_param is not None:
            # Overlap S–E: endMin > S AND startMin < E
            # Firestore: push startMin < E
            q = q.where("startMin", "<", end_min_param)
            filter_overlap_SE = True  # we'll enforce endMin > S in Python

        elif start_min_param is not None and end_min_param is None:
            # "Free AT T": startMin <= T < endMin
            # Firestore: push endMin > T
            q = q.where("endMin", ">", start_min_param)
            filter_contains_T = True  # we'll enforce startMin <= T in Python

        elif start_min_param is None and end_min_param is not None:
            # "Free UNTIL E": slot started before E
            # Firestore: startMin < E (no extra Python filter needed)
            q = q.where("startMin", "<", end_min_param)

        fetch_limit = 2000  # overfetch to account for post-filtering

        # Stable ordering for pagination
        q = (
            q.order_by("roomId")
             .order_by("date")
             .order_by("startMin")
             .limit(fetch_limit)
        )

        # Cursor
        if pageToken:
            cursor = _decode_token(pageToken)
            q = q.start_after([
                cursor.get("roomId", ""),
                cursor.get("date", ""),
                cursor.get("startMin", 0),
            ])

        print(
            f"[rooms] date={today} "
            f"building={building!r} "
            f"startTimeParam={startTime!r} (min={start_min_param}) "
            f"endTimeParam={endTime!r} (min={end_min_param}) "
            f"limit={limit} fetch_limit={fetch_limit}"
        )

        # --- Fetch from Firestore ---
        docs = list(q.stream())
        print(f"[rooms DEBUG] BEFORE post-filter: {len(docs)} docs")
        preview_before = []
        for d in docs[:15]:
            data = d.to_dict() or {}
            preview_before.append(
                (
                    data.get("buildingCode"),
                    str(data.get("roomNumber")),
                    data.get("startMin"),
                    data.get("endMin"),
                )
            )
        print("    first 15:", preview_before)

        # --- Python-side filtering for the parts Firestore can't express ---
        if filter_contains_T and start_min_param is not None:
            # Keep only slots with startMin <= T
            tmp = []
            for d in docs:
                data = d.to_dict() or {}
                start_min = int(data.get("startMin", 9999))
                if start_min <= start_min_param:
                    tmp.append(d)
            docs = tmp

        if filter_overlap_SE and start_min_param is not None:
            # We already enforced startMin < E in Firestore,
            # now enforce endMin > S here.
            tmp = []
            for d in docs:
                data = d.to_dict() or {}
                end_min = int(data.get("endMin", -1))
                if end_min > start_min_param:
                    tmp.append(d)
            docs = tmp

        print(f"[rooms DEBUG] AFTER post-filter: {len(docs)} docs")
        preview_after = []
        for d in docs[:15]:
            data = d.to_dict() or {}
            preview_after.append(
                (
                    data.get("buildingCode"),
                    str(data.get("roomNumber")),
                    data.get("startMin"),
                    data.get("endMin"),
                )
            )
        print("    first 15:", preview_after)

        # --- Pagination bookkeeping (on the filtered docs) ---
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
        detail = f"/rooms failed: {type(e).__name__}: {e}"
        print("\n" + "=" * 70)
        print("🔥 Firestore query failed or post-filter error.")
        print(detail)
        print("=" * 70 + "\n")
        raise HTTPException(status_code=500, detail=detail)
