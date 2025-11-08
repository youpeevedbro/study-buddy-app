from fastapi import APIRouter, HTTPException
from services.firestore_client import get_db, firestore
from models.group import StudyGroupCreate
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

router = APIRouter()
COLLECTION = "studyGroups"

def convert_to_utc_datetime(date: str, time: str) -> datetime:
    date_str = f"{date} {time}" 
    format_str = "%Y-%m-%d %H:%M"
    dt = datetime.strptime(date_str, format_str)
    la_tz = ZoneInfo("America/Los_Angeles")
    dt_la = dt.replace(tzinfo=la_tz)

    dt_utc = dt_la.astimezone(timezone.utc) #datetime object in UTC
    return dt_utc


@firestore.transactional
def _create_group_transaction(transaction, newGroupRef, data):
    # READ User's joined study groups
    # Ensure no overlapping times
    transaction.set(newGroupRef, data)
    # UPDATE User's joined study groups

#ADD dependendency: get User
@router.post("/")
def create_group(group: StudyGroupCreate): 
    try:
        db = get_db()
        col = db.collection(COLLECTION)
        transaction = db.transaction()

        newGroupRef = col.document() # creates studyGroup doc ref + auto-ID
        group_dict = group.model_dump()
        data = { 
            'id': newGroupRef.id,
            'buildingCode': group_dict["building"],
            'roomNumber': group_dict["roomNumber"],
            'date': group_dict["date"],
            'startTime': group_dict["startTime"],
            'endTime': group_dict["endTime"],
            'name': group_dict["name"],
            'quantity': 1,
            # ADD owner fields + members
            'availabilitySlotDocument': group_dict["availabilitySlotDocument"],
            'expireAt': convert_to_utc_datetime(group_dict["date"], group_dict["endTime"])
        }
        
        _create_group_transaction(transaction, newGroupRef, data)
        #INCREMENENT availabilityslots?
        
    except Exception as e:
        # Surface exact failure in response while we debug
        raise HTTPException(status_code=500, detail=f"/groups failed: {type(e).__name__}: {e}")
    

@router.get("/{group_id}")
def get_group(group_id: int):
    try:
        return {"group_id": group_id}
    except Exception as e:
        # Surface exact failure in response while we debug
        raise HTTPException(status_code=500, detail=f"/groups failed: {type(e).__name__}: {e}")
    
    