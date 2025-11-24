from fastapi import APIRouter, HTTPException, Depends
from typing import List, Union
from services.firestore_client import get_db, firestore
from google.cloud.firestore_v1.base_query import FieldFilter
from google.cloud.firestore_v1.field_path import FieldPath
from models.group import StudyGroupCreate, StudyGroupPublicResponse, StudyGroupPrivateResponse, StudyGroupUpdate, JoinedStudyGroupResponse, JoinedStudyGroup, UserGroupRole
from datetime import datetime, timezone
from zoneinfo import ZoneInfo
from auth import verify_firebase_token

router = APIRouter()
COLLECTION = "studyGroups"
USER_COLLECTION = "users"

UID = input("\nEnter User ID: ") # TEMPORARY 

def convert_to_utc_datetime(date: str, time: str) -> datetime:
    dt = datetime.strptime(f"{date} {time}" , "%Y-%m-%d %H:%M")
    la_tz = ZoneInfo("America/Los_Angeles")
    dt_la = dt.replace(tzinfo=la_tz)
    return dt_la.astimezone(timezone.utc) 

def _doc_to_publicStudyGroup(doc, owner_doc) -> StudyGroupPublicResponse: 
    d = doc.to_dict()
    o = owner_doc.to_dict()
    return StudyGroupPublicResponse(
        id=d.get("id", ""),
        buildingCode=d.get("buildingCode", ""),
        roomNumber=str(d.get("roomNumber", "")),
        date=d.get("date", ""),
        startTime=d.get("startTime", ""),
        endTime=d.get("endTime", ""),
        name=d.get("name", ""),
        quantity=int(d.get("quantity", 0)),
        access=UserGroupRole.PUBLIC,
        ownerID=owner_doc.id,
        ownerHandle=o.get("handle", ""),
        ownerDisplayName=o.get("displayName", ""),
        availabilitySlotDocument=d.get("availabilitySlotDocument", "")
    )

def _doc_to_privateStudyGroup(doc, owner_doc, members: list[str], access: UserGroupRole) -> StudyGroupPrivateResponse: 
    d = doc.to_dict()
    o = owner_doc.to_dict()
    return StudyGroupPrivateResponse(
        id=d.get("id", ""),
        buildingCode=d.get("buildingCode", ""),
        roomNumber=str(d.get("roomNumber", "")),
        date=d.get("date", ""),
        startTime=d.get("startTime", ""),
        endTime=d.get("endTime", ""),
        name=d.get("name", ""),
        quantity=int(d.get("quantity", 0)),
        access=access,
        ownerID=owner_doc.id,
        ownerHandle=o.get("handle", ""),
        ownerDisplayName=o.get("displayName", ""),
        members=members,
        availabilitySlotDocument=d.get("availabilitySlotDocument", "")
    )

def _check_overlappingGroups(userData: dict, groupData: dict):
    joinedGroups = userData.get("joinedStudyGroups", {})
    newStartTime = convert_to_utc_datetime(groupData["date"], groupData["startTime"])
    newEndTime = convert_to_utc_datetime(groupData["date"], groupData["endTime"])

    for key, value in joinedGroups.items():
        groupStartTime = convert_to_utc_datetime(value["date"], value["startTime"])
        groupEndTime = convert_to_utc_datetime(value["date"], value["endTime"])

        if not (newEndTime <= groupStartTime or newStartTime >= groupEndTime):
            raise HTTPException(status_code=409, detail="Time overlap exists with joined Study Groups")


def _get_user_groupRole(uid: str, groupData: dict) -> UserGroupRole:
    if uid == groupData.get("ownerID", ""):
        return UserGroupRole.OWNER
    elif uid in groupData.get("members", []):
        return UserGroupRole.MEMBER
    else:
        return UserGroupRole.PUBLIC

@firestore.transactional
def _create_group_transaction(transaction, userRef, newGroupRef, data):
    user_doc = userRef.get(transaction=transaction)
    if user_doc.exists:
        user_dict = user_doc.to_dict()
    else:
        raise HTTPException(status_code=404, detail="Study Group Owner not found")
    _check_overlappingGroups(user_dict, data)

    groupID = newGroupRef.id
    transaction.set(newGroupRef, data)
    transaction.update(userRef, {
        "joinedStudyGroupIds": firestore.ArrayUnion([groupID]),
        f"joinedStudyGroups.{groupID}": {"name": data["name"],
                                        "startTime": data["startTime"],
                                        "endTime": data["endTime"],
                                        "date": data["date"] }
    })
    # possibly ADD: INCREMENENT studyGroupCount in availabilitySlots doc

@firestore.transactional
def _add_groupMember_transaction(transaction, groupRef, userRef):
    group_dict = groupRef.get(transaction=transaction).to_dict() or {}
    transaction.update(groupRef, {"members": firestore.ArrayUnion([userRef.id]),
                                  "quantity": firestore.Increment(1)})
    transaction.update(userRef, {
        "joinedStudyGroupIds": firestore.ArrayUnion([groupRef.id]),
        f"joinedStudyGroups.{groupRef.id}": {"name": group_dict.get("name", ""),
                                             "startTime": group_dict.get("startTime", ""),
                                             "endTime": group_dict.get("endTime", ""),
                                             "date": group_dict.get("date", "")}
                                        
    })
    # possibly ADD: INCREMENT projectedMembers in availabilitySlot doc
    # ADD: DELETE incoming_request doc associated with this user and studygroup

@firestore.transactional
def _update_group_transaction(transaction, studyGroupRef, updates_data: dict, usersQuery):
    user_docs = usersQuery.get(transaction=transaction)
    doc = studyGroupRef.get(transaction=transaction)

    """
    originalGroupDict = doc.to_dict()
    user_groupUpdates = {"name": originalGroupDict["name"], "startTime": originalGroupDict["startTime"], 
                        "endTime": originalGroupDict["endTime"], "date": originalGroupDict["date"]}

    if any(key in updates_data for key in ["date", "startTime", "endTime"]):   # Any time changes
        user_groupTimeUpdates = {
            field: updates_data.get(field, originalGroupDict.get(field))
            for field in ["date", "startTime", "endTime"]
        }
        user_groupUpdates.update(user_groupTimeUpdates)
        updates_data["expireAt"] = convert_to_utc_datetime(user_groupUpdates["date"], user_groupUpdates["endTime"]) # update expireAt field in case date or endTime changes
        # ADD: READ Owner's joined study groups + Ensure no overlapping times
        # ADD: UPDATE all applicable incoming_requests documents 'expireAt' field
    
    if "name" in updates_data:
        # ADD: UPDATE all applicable incoming_requests documents 'studyGroupName' field
        user_groupUpdates.update({"name": updates_data["name"]})
    
    if "availabilitySlotDocument" in updates_data:
        # possibly ADD: DECREMENT studygroup count in old availabilitySlots doc
        # possibly ADD: INCREMENT studygroup count in new availabilitySlots doc
        print("updating...")
    """
    
    transaction.update(studyGroupRef, updates_data)   # Updates StudyGroup Doc
    for doc in user_docs: # Updates all applicable User docs
        transaction.update(doc.reference, {f"joinedStudyGroups.{studyGroupRef.id}.name": updates_data.get("name")} )
    # ADD: UPDATE all applicable incoming_requests documents 'studyGroupName' field


    """
    if any(key in updates_data for key in ["date", "startTime", "endTime", "name"]): # Only update users if necessary
        for doc in user_docs:
            transaction.update(doc.reference, {f"joinedStudyGroups.{studyGroupRef.id}": user_groupUpdates})
    """

@firestore.transactional
def _delete_groupMember_transaction(transaction, groupRef, userRef):
    transaction.update(groupRef, {"members": firestore.ArrayRemove([userRef.id]),
                                 "quantity": firestore.Increment(-1)})

    transaction.update(userRef, {
        "joinedStudyGroupIds": firestore.ArrayRemove([groupRef.id]),
        f"joinedStudyGroups.{groupRef.id}": firestore.DELETE_FIELD
    })
    # possibly ADD: DECREMENT projectedMembers in availabilitySlot doc
    


@firestore.transactional
def _delete_group_transaction(transaction, groupRef, usersQuery):
    user_docs = usersQuery.get(transaction=transaction)
    for doc in user_docs:
        transaction.update(doc.reference, {
            "joinedStudyGroupIds": firestore.ArrayRemove([groupRef.id]),
            f"joinedStudyGroups.{groupRef.id}": firestore.DELETE_FIELD})
    # ADD: DELETE all applicable incoming_requests docs associated with study group (collection group query)
    # possibly ADD: DECREMENT studygroup count in availabilitySlot doc
    transaction.delete(groupRef)


#ADD dependendency: get User
@router.post("/")
def create_group(group: StudyGroupCreate): 
    try:
        db = get_db()
        col = db.collection(COLLECTION)
        transaction = db.transaction()

        
        uid = UID # Eventually replace with uid from client

        userRef = db.collection(USER_COLLECTION).document(uid)

        newGroupRef = col.document() # creates studyGroup doc ref + auto-ID
        data = group.model_dump()
        data.update({"id": newGroupRef.id,  
                     "quantity": 1, 
                     "ownerID": userRef.id,
                     "members": [userRef.id],
                     "expireAt":convert_to_utc_datetime(data["date"], data["endTime"]) })
        
        _create_group_transaction(transaction, userRef, newGroupRef, data)
        
    except Exception as e:
        # Surface exact failure in response while we debug
        raise HTTPException(status_code=500, detail=f"/groups failed: {type(e).__name__}: {e}")

# ADD dependency: User accepting request to join is Study Group Owner 
#                    + ensure User being added is not already a member
@router.post("/{group_id}/members/{user_id}")
def add_group_member(group_id: str, user_id: str):
    """
    Adding a new member to a study group. Use when Study Group Owner accepts a request to join.
    """
    try:
        db = get_db()
        col = db.collection(COLLECTION)
        transaction = db.transaction()

        groupRef = col.document(group_id)
        userRef = db.collection(USER_COLLECTION).document(user_id)
        _add_groupMember_transaction(transaction, groupRef, userRef)
        
    except Exception as e:
        # Surface exact failure in response while we debug
        raise HTTPException(status_code=500, detail=f"/groups failed: {type(e).__name__}: {e}")
    
# ADD dependency: get User
@router.get("/myStudyGroups")
#def get_joined_groups(claims: dict = Depends(verify_firebase_token)) -> JoinedStudyGroupResponse:
def get_joined_groups() -> JoinedStudyGroupResponse:
    try:

        uid = UID # Eventually replace with uid from client

        db = get_db()
        col = db.collection(USER_COLLECTION)
        doc = col.document(uid).get()
        items: List[JoinedStudyGroup] = []
        if doc.exists:
            user_dict = doc.to_dict()
            joinedGroups = user_dict.get("joinedStudyGroups", {})
            for key, value in joinedGroups.items():
                groupEndTime = convert_to_utc_datetime(value["date"], value["endTime"])
                if groupEndTime < datetime.now(timezone.utc):
                    continue   # do not send past study groups
                items.append(
                    JoinedStudyGroup(
                        id = key,
                        name = value.get("name", ""),
                        startTime = value.get("startTime", ""),
                        endTime = value.get("endTime", ""),
                        date = value.get("date", "")
                ))
            items.sort(key=lambda item: convert_to_utc_datetime(item.date, item.startTime))
            return JoinedStudyGroupResponse(items=items)
        else:
            raise HTTPException(status_code=404, detail="User doc not found")
    except Exception as e:
        # Surface exact failure in response while we debug
        raise HTTPException(status_code=500, detail=f"/groups failed: {type(e).__name__}: {e}")



# ADD dependency: get User
@router.get("/{group_id}", 
            response_model=Union[StudyGroupPrivateResponse, StudyGroupPublicResponse]
) 
def get_group(group_id: str):
    try:

        uid = UID # Eventually replace with uid from client

        db = get_db()
        col = db.collection(COLLECTION)
        doc = col.document(group_id).get()
      
        if doc.exists:
            group_dict = doc.to_dict()
            user_role = _get_user_groupRole(uid, group_dict)

         
            ownerID = group_dict.get("ownerID", "")
            owner_doc = db.collection(USER_COLLECTION).document(ownerID).get()

            if owner_doc.exists:
                if user_role == UserGroupRole.MEMBER or user_role == UserGroupRole.OWNER:

                    members = []
                    member_ids = group_dict.get("members", [])
                    member_docs = db.collection(USER_COLLECTION).where(FieldPath.document_id(), "in", member_ids).get() #only up to 30 members
                    for user_doc in member_docs:
                        members.append(user_doc.to_dict().get("displayName", ""))
                
                    return _doc_to_privateStudyGroup(doc, owner_doc, members, user_role)  
                
                # user_role is public access
                return _doc_to_publicStudyGroup(doc, owner_doc)
            
            else:
                raise HTTPException(status_code=404, detail="This Study Group may no longer exist. Study Group Owner not found.")
        else:
            raise HTTPException(status_code=404, detail="Study Group not found.")
    
    except HTTPException as e: 
        if e.status_code == 404:
            raise e
    except Exception as e:
        # Surface exact failure in response while we debug
        raise HTTPException(status_code=500, detail=f"/groups failed: {type(e).__name__}: {e}")
    

# ADD dependencies: get User + ensure User is owner of Study Group
@router.patch("/{group_id}")
def update_group(group_id: str, group_update: StudyGroupUpdate):
    try:

        uid = UID # Eventually replace with uid from client

        db = get_db()
        col = db.collection(COLLECTION)
        studyGroupRef = col.document(group_id)
        groupDoc = studyGroupRef.get()

        if not groupDoc.exists:
            raise HTTPException(status_code=404, detail="Study Group not found")

        user_role = _get_user_groupRole(uid, groupDoc.to_dict())
        if user_role != UserGroupRole.OWNER:
            raise HTTPException(status_code=403, detail=f"Only Study Group Owners can edit groups")

        groupUpdates_dict = group_update.model_dump(exclude_unset=True)
        usersQuery = db.collection(USER_COLLECTION).where(filter=FieldFilter("joinedStudyGroupIds", "array_contains", group_id))

        transaction = db.transaction()
        _update_group_transaction(transaction, studyGroupRef, groupUpdates_dict, usersQuery)

    except Exception as e:
        # Surface exact failure in response while we debug
        raise HTTPException(status_code=500, detail=f"/groups failed: {type(e).__name__}: {e}")
    

# ADD dependency: get User + ensure User is member of study group
@router.delete("/{group_id}/members/currentUser")
def delete_group_member(group_id: str):
    """
    Deleting a member from a study group. Use when User decides to leave a study group.
    """
    try:

        uid = UID # REPLACE WITH UID FROM CLIENT

        db = get_db()
        col = db.collection(COLLECTION)
        transaction = db.transaction()

        groupRef = col.document(group_id)
        groupDoc = groupRef.get()
        userRef = db.collection(USER_COLLECTION).document(uid)

        if groupDoc.exists:
            user_role = _get_user_groupRole(uid, groupDoc.to_dict())
            if user_role == UserGroupRole.OWNER:
                raise HTTPException(status_code=403, detail=f"Study Group Owners cannot leave groups they have created. Must delete instead.")
            if user_role == UserGroupRole.MEMBER:
                _delete_groupMember_transaction(transaction, groupRef, userRef)
        
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
        usersQuery = db.collection(USER_COLLECTION).where(filter=FieldFilter("joinedStudyGroupIds", "array_contains", group_id))
        _delete_group_transaction(transaction, groupRef, usersQuery)

    except Exception as e:
        # Surface exact failure in response while we debug
        raise HTTPException(status_code=500, detail=f"/groups failed: {type(e).__name__}: {e}")