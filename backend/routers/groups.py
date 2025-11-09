from fastapi import APIRouter, HTTPException
from services.firestore_client import get_db, firestore
from models.group import StudyGroupCreate, StudyGroupPublicResponse, StudyGroupUpdate
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

router = APIRouter()
COLLECTION = "studyGroups"

def convert_to_utc_datetime(date: str, time: str) -> datetime:
    dt = datetime.strptime(f"{date} {time}" , "%Y-%m-%d %H:%M")
    la_tz = ZoneInfo("America/Los_Angeles")
    dt_la = dt.replace(tzinfo=la_tz)
    return dt_la.astimezone(timezone.utc) #datetime object in UTC

def _doc_to_publicStudyGroup(doc) -> StudyGroupPublicResponse: 
    d = doc.to_dict()
    return StudyGroupPublicResponse(
        id=d.get("id", ""),
        building=d.get("buildingCode", ""),
        roomNumber=d.get("roomNumber", ""),
        date=d.get("date", ""),
        startTime=d.get("startTime", ""),
        endTime=d.get("endTime", ""),
        name=d.get("name", ""),
        quantity=d.get("quantity", ""),
        # ADD owner fields
        availabilitySlotDocument=d.get("availabilitySlotDocument", "")
    )


@firestore.transactional
def _create_group_transaction(transaction, newGroupRef, data):
    # READ User's joined study groups
    # Ensure no overlapping times
    transaction.set(newGroupRef, data)
    # UPDATE User's joined study groups

@firestore.transactional
def _update_group_transaction(transaction, studyGroupRef, updates_data):
    doc_dict = studyGroupRef.get(transaction=transaction).to_dict()

    if any(key in updates_data for key in ["date", "startTime", "endTime"]):   # Manages Time Updates
        date = updates_data["date"] if "date" in updates_data else doc_dict["date"]
        startTime = updates_data["startTime"] if "startTime" in updates_data else doc_dict["startTime"]
        endTime = updates_data["endTime"] if "endTime" in updates_data else doc_dict["endTime"]
        
        # READ User's joined study groups
        # Ensure no overlapping times
        # UPDATE all applicable User's joined study groups
        transaction.update(studyGroupRef, {"date": date,
                                            "startTime": startTime,
                                            "endTime": endTime,
                                            "expireAt": convert_to_utc_datetime(date, endTime)
                                            })
        # UPDATE incoming_requests documents 'expireAt' field
    
    if "name" in updates_data:
        # UPDATE all applicable incoming requests documents
        # UPDATE all applicable User's joined study groups
        print("updating...")
    
    if "availabilitySlotDocument" in updates_data:
        # DECREMENT quantity in old availabilitySlots?
        # INCREMENT quantity in new availabilitySlots?
        print("updating...")
    
    for key in ["date", "startTime", "endTime"]:
        updates_data.pop(key, None)
    if len(updates_data) > 0:
        transaction.update(studyGroupRef, updates_data)   # Updates remaining fields not related to time
        

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
    

# ADD dependency: get User
@router.get("/{group_id}") 
def get_group(group_id: str) -> StudyGroupPublicResponse:
    try:
        db = get_db()
        col = db.collection(COLLECTION)
        doc = col.document(group_id).get()
        if doc.exists:
            return _doc_to_publicStudyGroup(doc)
        else:
            raise HTTPException(status_code=404, detail="Study Group not found")
    except Exception as e:
        # Surface exact failure in response while we debug
        raise HTTPException(status_code=500, detail=f"/groups failed: {type(e).__name__}: {e}")
    

# ADD dependencies: get User + ensure User is owner of Study Group
@router.patch("/{group_id}")
def update_group(group_id: str, group_update: StudyGroupUpdate):
    try:
        db = get_db()
        col = db.collection(COLLECTION)
        studyGroupRef = col.document(group_id)
        groupUpdates_dict = group_update.model_dump(exclude_unset=True)

        transaction = db.transaction()
        _update_group_transaction(transaction, studyGroupRef, groupUpdates_dict)

    except Exception as e:
        # Surface exact failure in response while we debug
        raise HTTPException(status_code=500, detail=f"/groups failed: {type(e).__name__}: {e}")
    

    
