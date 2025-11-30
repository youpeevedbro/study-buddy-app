# backend/routers/groups.py
from fastapi import APIRouter, HTTPException, Depends
from typing import List, Union
from services.firestore_client import get_db, firestore
from google.cloud.firestore_v1.base_query import FieldFilter
from google.cloud.firestore_v1.field_path import FieldPath
from models.group import (
    StudyGroupCreate,
    StudyGroupPublicResponse,
    StudyGroupPrivateResponse,
    StudyGroupUpdate,
    JoinedStudyGroupResponse,
    JoinedStudyGroup,
    UserGroupRole,
    StudyGroupList,
    SimpleJoinRequest,
    SimpleJoinRequestList,
    InviteByHandle,
    OutgoingGroupInvite,
    OutgoingGroupInviteList,
    IncomingGroupInvite,
    IncomingGroupInviteList,
)
from datetime import datetime, timezone
from zoneinfo import ZoneInfo
from auth import verify_firebase_token

router = APIRouter()
COLLECTION = "studyGroups"
USER_COLLECTION = "users"
JOIN_REQUEST_SUBCOLLECTION = "incomingRequests"
INVITES_SUBCOLLECTION = "invites"


def convert_to_utc_datetime(date: str, time: str) -> datetime:
    dt = datetime.strptime(f"{date} {time}" , "%Y-%m-%d %H:%M")
    la_tz = ZoneInfo("America/Los_Angeles")
    dt_la = dt.replace(tzinfo=la_tz)
    return dt_la.astimezone(timezone.utc) 

def _doc_to_publicStudyGroup(doc, owner_doc, has_pending: bool = False) -> StudyGroupPublicResponse: 
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
        availabilitySlotDocument=d.get("availabilitySlotDocument", ""),
        hasPendingRequest=has_pending,
    )

def _doc_to_privateStudyGroup(doc, owner_doc, members: list[str], access: UserGroupRole, has_pending: bool = False,) -> StudyGroupPrivateResponse: 
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
        availabilitySlotDocument=d.get("availabilitySlotDocument", ""),
        hasPendingRequest=has_pending,
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
    req_ref = groupRef.collection(JOIN_REQUEST_SUBCOLLECTION).document(userRef.id)
    transaction.delete(req_ref)

@firestore.transactional
def _update_group_transaction(transaction, studyGroupRef, updates_data: dict, usersQuery):
    user_docs = usersQuery.get(transaction=transaction)
    doc = studyGroupRef.get(transaction=transaction)
    
    transaction.update(studyGroupRef, updates_data)   # Updates Study group doc
    for doc in user_docs: # Updates all applicable User docs - only updates name
        transaction.update(doc.reference, {f"joinedStudyGroups.{studyGroupRef.id}.name": updates_data.get("name")} )
    # ADD: UPDATE all applicable incoming_requests documents 'studyGroupName' field



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
    
    # Explicitly delete incomingRequests subcollection for this group
    reqs = groupRef.collection(JOIN_REQUEST_SUBCOLLECTION).stream()
    for r in reqs:
        transaction.delete(r.reference)
    
    # delete invites subcollection
    invs = groupRef.collection(INVITES_SUBCOLLECTION).stream()
    for inv in invs:
        transaction.delete(inv.reference)

    # possibly ADD: DECREMENT studygroup count in availabilitySlot doc
    transaction.delete(groupRef)


@router.post("/")
def create_group(group: StudyGroupCreate, claims: dict = Depends(verify_firebase_token),): 
    try:
        db = get_db()
        col = db.collection(COLLECTION)
        transaction = db.transaction()

        uid = claims.get("uid") or claims.get("sub")
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
#def add_group_member(group_id: str, user_id: str, claims: dict = Depends(verify_firebase_token)):
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



@router.get("/myStudyGroups")
def get_joined_groups(claims: dict = Depends(verify_firebase_token)) -> JoinedStudyGroupResponse:
    """
    Returns data from 'joinedStudyGroups' field in User document
    """
    try:

        uid = claims.get("uid") or claims.get("sub")

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


@router.get("/")
def get_all_groups(claims: dict = Depends(verify_firebase_token)) -> StudyGroupList:
    """"
    Returns List of Study Groups with appropriate access based on user.
    Owners and members have access to the 'members' field.
    Users who are not members can see number of people in a group but do not have access to the 'members' field.
    """
    try:
        db = get_db()
        col = db.collection(COLLECTION)
        items: List[StudyGroupPublicResponse] = []

        uid = claims.get("uid") or claims.get("sub")
        
        # 0) Find all groups where this user has a pending join request
        pending_query = db.collection_group(JOIN_REQUEST_SUBCOLLECTION).where(
            "requesterId", "==", uid
        )
        pending_group_ids = {
            d.reference.parent.parent.id  # parent = incomingRequests, parent.parent = group doc
            for d in pending_query.stream()
        }


        docs = col.stream()
        for doc in docs:
            groupEndTime = doc.to_dict()["expireAt"]
            if groupEndTime < datetime.now(timezone.utc):
                continue   # do not send past study groups

            ownerID = doc.to_dict().get("ownerID", "")
            owner_doc = db.collection(USER_COLLECTION).document(ownerID).get()
            if not owner_doc.exists:
                continue  # do not send groups with invalid field for 'ownerID'
            
            doc_dict = doc.to_dict()
            user_role = _get_user_groupRole(uid, doc_dict)

            has_pending = doc.id in pending_group_ids

            if user_role == UserGroupRole.MEMBER or user_role == UserGroupRole.OWNER:
                members = []
                member_ids = doc_dict.get("members", [])
                member_docs = db.collection(USER_COLLECTION).where(FieldPath.document_id(), "in", member_ids).get() #only up to 30 members
                for user_doc in member_docs:
                    members.append(user_doc.to_dict().get("displayName", ""))
            
                # Build private response with has_pending
                item = _doc_to_privateStudyGroup(doc, owner_doc, members, user_role, has_pending)
                items.append(item)
            
            else: # user role is public access
                item = _doc_to_publicStudyGroup(doc, owner_doc, has_pending)
                items.append(item)
        
        items.sort(key=lambda item: convert_to_utc_datetime(item.date, item.startTime))
        return StudyGroupList(items=items)
            
    
    except Exception as e:
        # Surface exact failure in response while we debug
        raise HTTPException(status_code=500, detail=f"/groups failed: {type(e).__name__}: {e}")


@router.get("/{group_id}", 
            response_model=Union[StudyGroupPrivateResponse, StudyGroupPublicResponse]) 
def get_group(group_id: str, claims: dict = Depends(verify_firebase_token)):
    """
    Returns single study group with appropriate access based on the user sending the request
    """
    try:

        uid = claims.get("uid") or claims.get("sub")

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
    


@router.patch("/{group_id}")
def update_group(group_id: str, group_update: StudyGroupUpdate, claims: dict = Depends(verify_firebase_token)):
    """
    Only updates 'name' field of a study group. 
    Updates study group document and applicable user documents
    """
    try:

        uid = claims.get("uid") or claims.get("sub")

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
    


@router.delete("/{group_id}/members/currentUser")
def delete_group_member(group_id: str, claims: dict = Depends(verify_firebase_token)):
    """
    Deleting a member from a study group. Use when User decides to leave a study group.
    """
    try:

        uid = claims.get("uid") or claims.get("sub")

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


@router.delete("/{group_id}")
def delete_group(group_id: str, claims: dict = Depends(verify_firebase_token)):
    try:

        uid = claims.get("uid") or claims.get("sub")
    
        db = get_db()
        col = db.collection(COLLECTION)
        transaction = db.transaction()

        groupRef = col.document(group_id)
        groupDoc = groupRef.get()
        usersQuery = db.collection(USER_COLLECTION).where(filter=FieldFilter("joinedStudyGroupIds", "array_contains", group_id))
        
        if groupDoc.exists:
            user_role = _get_user_groupRole(uid, groupDoc.to_dict())
            
            if user_role != UserGroupRole.OWNER:
                raise HTTPException(status_code=403, detail=f"Only Study Group Owners can delete groups")
            
            _delete_group_transaction(transaction, groupRef, usersQuery)

    except Exception as e:
        # Surface exact failure in response while we debug
        raise HTTPException(status_code=500, detail=f"/groups failed: {type(e).__name__}: {e}")
    
@router.post("/cleanupCurrentUser")
def cleanup_current_user_study_groups(
    claims: dict = Depends(verify_firebase_token),
):
    """
    Used when a user is about to delete their account.

    It will:
    1) Delete all study groups they OWN, and remove those groups from every
       user's joinedStudyGroupIds / joinedStudyGroups.
    2) Remove them from any study groups they JOINED (but do not own),
       updating both the group.members and their user doc.
    """
    try:
        db = get_db()
        col = db.collection(COLLECTION)
        users_col = db.collection(USER_COLLECTION)

        uid = claims.get("uid") or claims.get("sub")

        # 1) Delete all groups this user OWNS
        owned_groups = col.where("ownerID", "==", uid).stream()

        for g in owned_groups:
            group_ref = col.document(g.id)

            # All users who have this group in joinedStudyGroupIds
            users_query = users_col.where(
                filter=FieldFilter("joinedStudyGroupIds", "array_contains", g.id)
            )

            tx = db.transaction()
            _delete_group_transaction(tx, group_ref, users_query)

        # 2) Remove the user from groups they JOINED (but don't own)
        joined_groups = col.where(
            filter=FieldFilter("members", "array_contains", uid)
        ).stream()

        for g in joined_groups:
            gdict = g.to_dict() or {}

            # If they own it, it was already deleted above
            if gdict.get("ownerID") == uid:
                continue

            group_ref = col.document(g.id)
            user_ref = users_col.document(uid)

            tx = db.transaction()
            _delete_groupMember_transaction(tx, group_ref, user_ref)

        # 3) Delete any join requests this user has sent
        #    (studyGroups/*/incomingRequests where requesterId == uid)
        req_query = db.collection_group(JOIN_REQUEST_SUBCOLLECTION).where(
            "requesterId", "==", uid
        )
        for req_doc in req_query.stream():
            req_doc.reference.delete()
        
        # 4) Delete any invites where this user is the invitee
        invite_query = db.collection_group(INVITES_SUBCOLLECTION).where(
            "inviteeId", "==", uid
        )
        for inv_doc in invite_query.stream():
            inv_doc.reference.delete()
        
        
        # Nothing to return; caller just needs success status
        return {"status": "ok"}

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"/groups cleanupCurrentUser failed: {type(e).__name__}: {e}",
        )



@router.post("/{group_id}/requests/currentUser")
def create_join_request_current_user(
    group_id: str,
    claims: dict = Depends(verify_firebase_token),
):
    """
    Current user requests to join the given study group.
    Creates/overwrites studyGroups/{groupId}/incomingRequests/{userId}.
    """
    try:
        db = get_db()
        uid = claims.get("uid") or claims.get("sub")

        users_col = db.collection(USER_COLLECTION)
        groups_col = db.collection(COLLECTION)

        # 1) Get user
        user_doc = users_col.document(uid).get()
        if not user_doc.exists:
            raise HTTPException(status_code=404, detail="User not found")
        user_data = user_doc.to_dict() or {}

        # 2) Get group
        group_ref = groups_col.document(group_id)
        group_doc = group_ref.get()
        if not group_doc.exists:
            raise HTTPException(status_code=404, detail="Study Group not found")
        group_data = group_doc.to_dict() or {}

        # 3) User must not already be owner or member
        role = _get_user_groupRole(uid, group_data)
        if role != UserGroupRole.PUBLIC:
            raise HTTPException(
                status_code=400,
                detail="You are already a member or owner of this study group.",
            )

        # 4) Optional: block overlapping groups
        _check_overlappingGroups(user_data, group_data)

        # 5) Create / overwrite incoming request doc
        req_ref = group_ref.collection(JOIN_REQUEST_SUBCOLLECTION).document(uid)
        req_ref.set(
            {
                "requesterId": uid,
                "requesterHandle": user_data.get("handle", ""),
                "requesterDisplayName": user_data.get("displayName", ""),
                "createdAt": datetime.now(timezone.utc),
            }
        )

        return {"status": "ok"}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"/group/{group_id}/requests/currentUser failed: {type(e).__name__}: {e}",
        )

@router.get("/{group_id}/requests", response_model=SimpleJoinRequestList)
def list_incoming_requests(
    group_id: str,
    claims: dict = Depends(verify_firebase_token),
):
    """
    Owner lists incoming join requests for this study group.
    """
    try:
        db = get_db()
        uid = claims.get("uid") or claims.get("sub")

        group_ref = db.collection(COLLECTION).document(group_id)
        group_doc = group_ref.get()
        if not group_doc.exists:
            raise HTTPException(status_code=404, detail="Study Group not found")

        group_data = group_doc.to_dict() or {}
        role = _get_user_groupRole(uid, group_data)
        if role != UserGroupRole.OWNER:
            raise HTTPException(
                status_code=403,
                detail="Only Study Group Owners can view join requests.",
            )

        group_name = group_data.get("name", "")

        req_docs = group_ref.collection(JOIN_REQUEST_SUBCOLLECTION).stream()
        users_col = db.collection(USER_COLLECTION)

        items: list[SimpleJoinRequest] = []
        for d in req_docs:
            req_data = d.to_dict() or {}
            requester_id = req_data.get("requesterId")
            if not requester_id:
                continue

            user_doc = users_col.document(requester_id).get()
            if not user_doc.exists:
                continue
            user_data = user_doc.to_dict() or {}

            items.append(
                SimpleJoinRequest(
                    requesterId=requester_id,
                    requesterHandle=user_data.get("handle", ""),
                    requesterDisplayName=user_data.get("displayName", ""),
                    groupId=group_id,
                    groupName=group_name,
                )
            )

        return SimpleJoinRequestList(items=items)

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"/group/{group_id}/requests failed: {type(e).__name__}: {e}",
        )

@router.get("/{group_id}/invites", response_model=OutgoingGroupInviteList)
def list_outgoing_invites(
    group_id: str,
    claims: dict = Depends(verify_firebase_token),
):
    """
    Owner lists outgoing invites for this study group.
    """
    try:
        db = get_db()
        uid = claims.get("uid") or claims.get("sub")

        group_ref = db.collection(COLLECTION).document(group_id)
        group_doc = group_ref.get()
        if not group_doc.exists:
            raise HTTPException(status_code=404, detail="Study Group not found")

        group_data = group_doc.to_dict() or {}
        role = _get_user_groupRole(uid, group_data)
        if role != UserGroupRole.OWNER:
            raise HTTPException(
                status_code=403,
                detail="Only Study Group Owners can view outgoing invites.",
            )

        invite_docs = group_ref.collection(INVITES_SUBCOLLECTION).stream()

        items: list[OutgoingGroupInvite] = []
        for d in invite_docs:
            inv = d.to_dict() or {}
            items.append(
                OutgoingGroupInvite(
                    inviteeId=inv.get("inviteeId", ""),
                    inviteeHandle=inv.get("inviteeHandle", ""),
                    inviteeDisplayName=inv.get("inviteeDisplayName", ""),
                    groupId=inv.get("groupId", group_id),
                    groupName=inv.get("groupName", group_data.get("name", "")),
                    ownerId=inv.get("ownerId", ""),
                    ownerHandle=inv.get("ownerHandle", ""),
                    ownerDisplayName=inv.get("ownerDisplayName", ""),
                )
            )

        return OutgoingGroupInviteList(items=items)

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"/group/{group_id}/invites failed: {type(e).__name__}: {e}",
        )

@router.delete("/{group_id}/requests/{user_id}")
def decline_request(
    group_id: str,
    user_id: str,
    claims: dict = Depends(verify_firebase_token),
):
    """
    Owner declines a join request: delete incomingRequests/{userId}.
    """
    try:
        db = get_db()
        uid = claims.get("uid") or claims.get("sub")

        group_ref = db.collection(COLLECTION).document(group_id)
        group_doc = group_ref.get()
        if not group_doc.exists:
            raise HTTPException(status_code=404, detail="Study Group not found")

        group_data = group_doc.to_dict() or {}
        role = _get_user_groupRole(uid, group_data)

        # Allow if:
        #   - requester = uid == user_id
        #   - OR group owner
        if uid != user_id and role != UserGroupRole.OWNER:
            raise HTTPException(
                status_code=403,
                detail="Only Study Group Owners or the requester can cancel join requests.",
            )

        req_ref = group_ref.collection(JOIN_REQUEST_SUBCOLLECTION).document(user_id)
        if req_ref.get().exists:
            req_ref.delete()

        return {"status": "ok"}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"/group/{group_id}/requests/{user_id} failed: {type(e).__name__}: {e}",
        )


@router.post("/{group_id}/inviteByHandle")
def invite_user_by_handle(
    group_id: str,
    payload: InviteByHandle,
    claims: dict = Depends(verify_firebase_token),
):
    """
    Study group owner invites a user by their handle.

    This creates a pending invite:
      studyGroups/{groupId}/invites/{inviteeUserId}

    The user must later ACCEPT to become a member.
    """
    try:
        db = get_db()
        uid = claims.get("uid") or claims.get("sub")

        groups_col = db.collection(COLLECTION)
        users_col = db.collection(USER_COLLECTION)

        group_ref = groups_col.document(group_id)
        group_doc = group_ref.get()
        if not group_doc.exists:
            raise HTTPException(status_code=404, detail="Study Group not found")

        group_data = group_doc.to_dict() or {}
        group_name = group_data.get("name", "")

        # 1) Ensure caller is the owner
        role = _get_user_groupRole(uid, group_data)
        if role != UserGroupRole.OWNER:
            raise HTTPException(
                status_code=403,
                detail="Only Study Group Owners can invite users.",
            )

        # 2) Get owner user data (for ownerHandle / ownerDisplayName)
        owner_doc = users_col.document(uid).get()
        if not owner_doc.exists:
            raise HTTPException(status_code=404, detail="Owner user doc not found")
        owner_data = owner_doc.to_dict() or {}

        # 3) Look up the user by handle
        handle = payload.handle
        user_query = users_col.where("handle", "==", handle).limit(1).stream()
        user_docs = list(user_query)
        if not user_docs:
            raise HTTPException(status_code=404, detail="User with that handle not found")

        user_doc = user_docs[0]
        invited_user_id = user_doc.id
        invited_user_data = user_doc.to_dict() or {}

        # 4) Do not invite yourself
        if invited_user_id == uid:
            raise HTTPException(
                status_code=400,
                detail="You cannot invite yourself.",
            )

        # 5) Optional: check overlapping groups for the invited user
        _check_overlappingGroups(invited_user_data, group_data)

        # 6) Make sure they’re not already member/owner
        if invited_user_id == group_data.get("ownerID") or invited_user_id in group_data.get("members", []):
            raise HTTPException(
                status_code=400,
                detail="User is already in this study group.",
            )

        # 7) Create/overwrite invite doc: studyGroups/{groupId}/invites/{inviteeUserId}
        invite_ref = group_ref.collection(INVITES_SUBCOLLECTION).document(invited_user_id)
        invite_ref.set(
            {
                "inviteeId": invited_user_id,
                "inviteeHandle": invited_user_data.get("handle", ""),
                "inviteeDisplayName": invited_user_data.get("displayName", ""),
                "ownerId": uid,
                "ownerHandle": owner_data.get("handle", ""),
                "ownerDisplayName": owner_data.get("displayName", ""),
                "groupId": group_id,
                "groupName": group_name,
                "createdAt": datetime.now(timezone.utc),
            }
        )

        return {"status": "ok"}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"/group/{group_id}/inviteByHandle failed: {type(e).__name__}: {e}",
        )

@router.get("/myInvites", response_model=IncomingGroupInviteList)
def list_my_incoming_invites(
    claims: dict = Depends(verify_firebase_token),
):
    """
    Current user lists all incoming group invites.
    """
    try:
        db = get_db()
        uid = claims.get("uid") or claims.get("sub")

        # collection_group query across all studyGroups/*/invites
        invite_query = db.collection_group(INVITES_SUBCOLLECTION).where(
            "inviteeId", "==", uid
        )

        items: list[IncomingGroupInvite] = []
        for d in invite_query.stream():
            inv = d.to_dict() or {}
            items.append(
                IncomingGroupInvite(
                    inviteeId=inv.get("inviteeId", ""),
                    groupId=inv.get("groupId", ""),
                    groupName=inv.get("groupName", ""),
                    ownerId=inv.get("ownerId", ""),
                    ownerHandle=inv.get("ownerHandle", ""),
                    ownerDisplayName=inv.get("ownerDisplayName", ""),
                )
            )

        return IncomingGroupInviteList(items=items)

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"/groups/myInvites failed: {type(e).__name__}: {e}",
        )

@router.post("/{group_id}/invites/{user_id}/accept")
def accept_invite(
    group_id: str,
    user_id: str,
    claims: dict = Depends(verify_firebase_token),
):
    """
    Invited user accepts an invite to join the study group.

    This:
      1) Verifies that the current user == user_id
      2) Adds them as a member using _add_groupMember_transaction
      3) Deletes the invite doc
    """
    try:
        db = get_db()
        uid = claims.get("uid") or claims.get("sub")

        if uid != user_id:
            raise HTTPException(
                status_code=403,
                detail="You can only accept invites addressed to yourself.",
            )

        groups_col = db.collection(COLLECTION)
        users_col = db.collection(USER_COLLECTION)

        group_ref = groups_col.document(group_id)
        group_doc = group_ref.get()
        if not group_doc.exists:
            raise HTTPException(status_code=404, detail="Study Group not found")
        group_data = group_doc.to_dict() or {}

        # Check they are not already member/owner
        role = _get_user_groupRole(uid, group_data)
        if role != UserGroupRole.PUBLIC:
            # Already in group; just delete invite if exists
            invite_ref = group_ref.collection(INVITES_SUBCOLLECTION).document(uid)
            if invite_ref.get().exists:
                invite_ref.delete()
            return {"status": "already_member"}

        # Verify invite exists
        invite_ref = group_ref.collection(INVITES_SUBCOLLECTION).document(uid)
        if not invite_ref.get().exists:
            raise HTTPException(status_code=404, detail="Invite not found")

        user_ref = users_col.document(uid)

        # Use same transaction helper as join approval
        tx = db.transaction()
        _add_groupMember_transaction(tx, group_ref, user_ref)

        # Delete invite (now consumed)
        invite_ref.delete()

        return {"status": "ok"}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"/group/{group_id}/invites/{user_id}/accept failed: {type(e).__name__}: {e}",
        )

@router.delete("/{group_id}/invites/{user_id}")
def decline_invite(
    group_id: str,
    user_id: str,
    claims: dict = Depends(verify_firebase_token),
):
    """
    Invited user declines an invite, or owner cancels an invite.

    Allowed if:
      - current user == invitee (decline)
      - OR current user is the group owner (cancel)
    """
    try:
        db = get_db()
        uid = claims.get("uid") or claims.get("sub")

        group_ref = db.collection(COLLECTION).document(group_id)
        group_doc = group_ref.get()
        if not group_doc.exists:
            raise HTTPException(status_code=404, detail="Study Group not found")

        group_data = group_doc.to_dict() or {}
        role = _get_user_groupRole(uid, group_data)

        # Okay if:
        #   - invitee themselves (uid == user_id)
        #   - OR group owner
        if uid != user_id and role != UserGroupRole.OWNER:
            raise HTTPException(
                status_code=403,
                detail="Only the invitee or the Study Group Owner can delete invites.",
            )

        invite_ref = group_ref.collection(INVITES_SUBCOLLECTION).document(user_id)
        if invite_ref.get().exists:
            invite_ref.delete()

        return {"status": "ok"}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"/group/{group_id}/invites/{user_id} failed: {type(e).__name__}: {e}",
        )
