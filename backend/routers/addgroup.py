from fastapi import APIRouter, HTTPException
from google.cloud import firestore

from backend.models.addgroup import Group
from backend.services.firestore_client import get_db

# The router is included in main with prefix "/groups"; keep local routes simple
router = APIRouter()

@router.post("/create", status_code=201)
def create_group(group: Group):
    """Create a study group document in the `groups` collection.

    Effective path: POST /groups/create (combined with include_router prefix)
    """
    try:
        db = get_db()
        write_result, doc_ref = db.collection("groups").add(
            {
                "name": group.name,
                "date": group.date,
                "starttime": group.starttime,
                "endtime": group.endtime,
                "location": group.location,
                "max_members": group.max_members,
                "creator_id": group.creator_id,
                "created_at": firestore.SERVER_TIMESTAMP,
            }
        )
        print(f"[groups] created {doc_ref.id} name='{group.name}'")
        return {"id": doc_ref.id, "message": "Group created successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Create group failed: {type(e).__name__}: {e}")
