from fastapi import APIRouter, HTTPException
from google.cloud import firestore

from backend.models.addgroup import Group
from backend.services.firestore_client import get_db

# The router is included in main with prefix "/groups"; keep local routes simple
router = APIRouter()

@router.post("/create")
def create_group(group: Group):
    """Create a study group document in the `groups` collection.

    Effective path: POST /groups/create (combined with include_router prefix)
    """
    try:
        db = get_db()
        doc_ref, write_result = db.collection("groups").add(
            {
                "name": group.name,
                "date": group.date,
                "time": group.time,
                "location": group.location,
                "max_members": group.max_members,
                "creator_id": group.creator_id,
                "created_at": firestore.SERVER_TIMESTAMP,
            }
        )
        return {"id": doc_ref.id, "message": "Group created successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
