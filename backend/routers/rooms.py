# backend/routers/rooms.py
import base64, json
import logging
from datetime import datetime, timedelta
from fastapi import APIRouter, HTTPException, Query, Depends
from typing import Any, Dict, List, Optional
from google.cloud import firestore
from google.api_core.exceptions import AlreadyExists
from services.firestore_client import get_db
from models.room import Room, RoomsResponse
from auth import verify_firebase_token

try:
    from zoneinfo import ZoneInfo
    TZ = ZoneInfo("America/Los_Angeles")
except Exception:
    TZ = None

router = APIRouter()
log = logging.getLogger("uvicorn.error")

# Each document in this collection is an availability slot for a room/time.
COLLECTION = "availabilitySlots"
# Subcollection used to track which users have reported a slot as locked.
USER_SUBCOLLECTION = "lockedReportsUsers"



def _doc_to_room(doc, user_has_reported: bool = False) -> Room:
    d = doc.to_dict() or {}
    return Room(
        id=doc.id,
        buildingCode=d.get("buildingCode", ""),
        roomNumber=str(d.get("roomNumber", "")),
        date=d.get("date", ""),
        start=d.get("start", ""),
        end=d.get("end", ""),
        # Firestore field stored as "locked_reports"
        lockedReports = int(d.get("locked_reports", 0) or 0),
        userHasReported=user_has_reported,
        currentCheckins=int(d.get("currentCheckins", 0) or 0),
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
    pageToken: Optional[str] = Query(None, alias="pageToken"),
    building: Optional[str] = Query(None, description="buildingCode like AS, ECS, LA1"),
    startTime: Optional[str] = Query(None, description="HH:mm (inclusive start of desired window)"),
    endTime: Optional[str] = Query(None, description="HH:mm (exclusive end of desired window)"),
    claims: dict = Depends(verify_firebase_token),
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

        uid = claims.get("uid") or claims.get("sub")

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

        items: List[Room] = []

        for d in docs:
            user_has_reported = False
            if uid:
                try:
                    vote_ref = d.reference.collection(USER_SUBCOLLECTION).document(uid)
                    vote_snap = vote_ref.get()
                    user_has_reported = vote_snap.exists
                except Exception as ex:
                    # Don't fail the whole request if this per-doc check breaks
                    log.warning(
                        "list_rooms: failed userHasReported check for doc %s uid=%s: %s",
                        d.id,
                        uid,
                        ex,
                    )
            items.append(_doc_to_room(d, user_has_reported=user_has_reported))

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
        log.exception("list_rooms failed: %s", e)
        raise HTTPException(
            status_code=500,
            detail=f"/rooms failed: {type(e).__name__}: {e}",
        )


@router.post("/{room_id}/report_locked")
def report_locked(
    room_id: str,
    claims: dict = Depends(verify_firebase_token),
):
    """
    Increment the locked_reports counter for a specific availability slot,
    but ONLY once per unique user (Firebase uid), regardless of session/device.

    We enforce uniqueness by creating:
      availabilitySlots/{room_id}/lockedReportsUsers/{uid}

    If that doc already exists, we do NOT increment again.
    """
    uid = claims.get("uid") or claims.get("sub")
    email = (claims.get("email") or "").lower()

    if not uid:
        raise HTTPException(
            status_code=400,
            detail="Missing uid in token; cannot uniquely identify user",
        )

    try:
        db = get_db()
        slot_ref = db.collection(COLLECTION).document(room_id)
        snap = slot_ref.get()
        if not snap.exists:
            raise HTTPException(status_code=404, detail="Room slot not found")

        votes_ref = slot_ref.collection(USER_SUBCOLLECTION).document(uid)

        # Try to create a marker doc for this user.
        # - If it already exists, Firestore raises AlreadyExists → user already reported.
        # - If it succeeds, this is the first report from this uid.
        try:
            votes_ref.create(
                {
                    "createdAt": firestore.SERVER_TIMESTAMP,
                    "email": email,
                }
            )
            first_time = True
        except AlreadyExists:
            first_time = False

        if first_time:
            # First time this user reports → increment the counter
            slot_ref.update({"locked_reports": firestore.Increment(1)})

        # Read the latest count (outside any transaction)
        new_snap = slot_ref.get()
        data = new_snap.to_dict() or {}
        new_count = int(data.get("locked_reports", 0))

        log.info(
            "report_locked: room_id=%s uid=%s first_time=%s new_count=%d",
            room_id,
            uid,
            first_time,
            new_count,
        )
        return {
            "lockedReports": new_count,
            # after this call, this user *has* reported this slot
            "userHasReported": True,
        }

    except HTTPException:
        raise
    except Exception as e:
        log.exception(
            "report_locked failed for room_id=%s uid=%s: %s", room_id, uid, e
        )
        raise HTTPException(
            status_code=500,
            detail=f"report_locked failed: {type(e).__name__}: {e}",
        )


@router.post("/admin/reset_locked_reports")
def reset_locked_reports(claims: dict = Depends(verify_firebase_token)):
    """
    Reset locked_reports = 0 ONLY for slots that currently have
    locked_reports > 0, and clear their per-user 'lockedReportsUsers'
    subcollections.

    Intended to be called by a scheduled job once per day (around 00:00)
    using Cloud Scheduler + OIDC service account auth.

    This is implemented as a loop over small batches of docs with
    locked_reports > 0, so it finishes within Cloud Run / Scheduler
    time limits.
    """
    try:
        db = get_db()
        col = db.collection(COLLECTION)

        log.info(
            "reset_locked_reports: starting selective reset for collection '%s'",
            COLLECTION,
        )

        BATCH_SIZE = 100
        total_slots = 0
        total_votes = 0
        batch_round = 0

        while True:
            batch_round += 1

            # Only documents that actually have any reports
            query = col.where("locked_reports", ">", 0).limit(BATCH_SIZE)
            docs = list(query.stream())

            if not docs:
                log.info(
                    "reset_locked_reports: no more docs with locked_reports > 0 "
                    "(completed in %d rounds)",
                    batch_round - 1,
                )
                break

            batch = db.batch()
            slots_in_batch = 0
            votes_in_batch = 0

            for d in docs:
                slot_ref = d.reference
                slots_in_batch += 1
                total_slots += 1

                # 1) reset locked_reports count
                batch.update(slot_ref, {"locked_reports": 0})

                # 2) delete all per-user vote docs under this slot
                votes_col = slot_ref.collection(USER_SUBCOLLECTION)
                for vote_ref in votes_col.list_documents():
                    batch.delete(vote_ref)
                    votes_in_batch += 1
                    total_votes += 1

            batch.commit()

            log.info(
                (
                    "reset_locked_reports: committed batch #%d: "
                    "slotsReset=%d, userVotesCleared=%d "
                    "(totals so far: slots=%d, votes=%d)"
                ),
                batch_round,
                slots_in_batch,
                votes_in_batch,
                total_slots,
                total_votes,
            )

        log.info(
            "reset_locked_reports: DONE, slotsReset=%d, userVotesCleared=%d",
            total_slots,
            total_votes,
        )
        return {
            "status": "ok",
            "slotsReset": total_slots,
            "userVotesCleared": total_votes,
        }

    except Exception as e:
        log.exception("reset_locked_reports: FAILED: %s", e)
        raise HTTPException(
            status_code=500,
            detail=f"reset_locked_reports failed: {type(e).__name__}: {e}",
        )
