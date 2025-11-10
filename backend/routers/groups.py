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
        buildingCode=d.get("buildingCode", ""),
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
        updates_data["expireAt"] = convert_to_utc_datetime(date, endTime) # update expireAt field in case date or endTime changes
        # READ User's joined study groups
        # Ensure no overlapping times
        # UPDATE all applicable User's joined study groups
        # UPDATE incoming_requests documents 'expireAt' field
    
    if "name" in updates_data:
        # UPDATE all applicable incoming requests documents
        # UPDATE all applicable User's joined study groups
        print("updating...")
    
    if "availabilitySlotDocument" in updates_data:
        # DECREMENT quantity in old availabilitySlots?
        # INCREMENT quantity in new availabilitySlots?
        print("updating...")
    
    transaction.update(studyGroupRef, updates_data)   #Updates StudyGroup Doc

@firestore.transactional
def _delete_group_transaction(transaction, studyGroupRef):
    # DELETE study group from applicable User documents (joinedStudyGroups)
    # DELETE incoming_requests documents related to study group (collection group query)
    # DECREMENT quantity in study group's related availabilitySlotDoc?
    transaction.delete(studyGroupRef)


#ADD dependendency: get User
@router.post("/")
def create_group(group: StudyGroupCreate): 
    try:
        db = get_db()
        col = db.collection(COLLECTION)
        transaction = db.transaction()

        newGroupRef = col.document() # creates studyGroup doc ref + auto-ID
        data = group.model_dump()
        data.update({"id": newGroupRef.id,  # ADD owner fields + members 
                     "quantity": 1, 
                     "expireAt":convert_to_utc_datetime(data["date"], data["endTime"]) })
        
        _create_group_transaction(transaction, newGroupRef, data)
        #INCREMENENT availabilityslots?
        
    except Exception as e:
        # Surface exact failure in response while we debug
        raise HTTPException(status_code=500, detail=f"/groups failed: {type(e).__name__}: {e}")

# ADD dependency: User accepting request to join is Study Group Owner 
#                    + ensure User being added is not already a member
@router.post("/{group_id}/members/{user_id}")
def add_group_member(group_id: str, user_id: str):
    try:
        db = get_db()
        col = db.collection(COLLECTION)
        groupRef = col.document(group_id)
        # UPDATE availability slot document for quantity?
        groupRef.update({"members": firestore.ArrayUnion([user_id])})
        groupRef.update({"quantity": firestore.Increment(1)})
        
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
    

# ADD dependency: get User + ensure User is member of study group
@router.delete("/{group_id}/members/{user_id}")
def delete_group_member(group_id: str, user_id: str):
    try:
        db = get_db()
        col = db.collection(COLLECTION)
        groupRef = col.document(group_id)
        # UPDATE availability slot document for quantity?
        groupRef.update({"members": firestore.ArrayRemove([user_id])})
        groupRef.update({"quantity": firestore.Increment(-1)})
        
    except Exception as e:
        # Surface exact failure in response while we debug
        raise HTTPException(status_code=500, detail=f"/groups failed: {type(e).__name__}: {e}")

# ADD dependency: get User + ensure User is owner of study group
@router.delete("/{group_id}")
def delete_group(group_id: str):
    try:
        db = get_db()
        col = db.collection(COLLECTION)
        transaction = db.transaction()
        groupRef = col.document(group_id)
        _delete_group_transaction(transaction, groupRef)

    except Exception as e:
        # Surface exact failure in response while we debug
        raise HTTPException(status_code=500, detail=f"/groups failed: {type(e).__name__}: {e}")