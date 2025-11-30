# backend/models/group.py
from enum import Enum
from typing import List, Union
from pydantic import BaseModel

# Request model for creating a Study Group
class StudyGroupCreate(BaseModel):
    buildingCode: str
    roomNumber: int
    date: str        #YYYY-MM-DD
    startTime: str   #HH:MM on 24 hr cycle
    endTime: str     #HH:MM on 24 hr cycle
    name: str
    availabilitySlotDocument: str #{BUILDING}-{ROOM#}_{YYYY}-{MM}-{DD}_{startMin}_{endMin}

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "buildingCode": "VEC",
                    "roomNumber": 305,
                    "date": "2025-08-20",
                    "startTime": "9:00",
                    "endTime": "13:00",
                    "name": "Calc1 Study Group",
                    "availabilitySlotDocument": "VEC-305_2025-08-20_540_780"
                }
            ]
        }
    }

class UserGroupRole(str, Enum):
    PUBLIC = "public"
    MEMBER = "member"
    OWNER = "owner"


# Response model for getting a Study Group (where user is not a member)
class StudyGroupPublicResponse(BaseModel):
    id: str
    buildingCode: str
    roomNumber: str
    date: str
    startTime: str
    endTime: str
    name: str
    quantity: int
    access: UserGroupRole
    ownerID: str
    ownerHandle: str
    ownerDisplayName: str
    availabilitySlotDocument: str
    hasPendingRequest: bool = False

# Response model for getting a Study Group (where user is a member)
class StudyGroupPrivateResponse(BaseModel):
    id: str
    buildingCode: str
    roomNumber: str
    date: str
    startTime: str
    endTime: str
    name: str
    quantity: int
    access: UserGroupRole
    ownerID: str
    ownerHandle: str
    ownerDisplayName: str
    members: List[str]  #List of Member Display Names
    availabilitySlotDocument: str
    hasPendingRequest: bool = False

# Request model for updating a Study Group
class StudyGroupUpdate(BaseModel):
    #buildingCode: str | None = None
    #roomNumber: int | None = None
    #date: str | None = None
    #startTime: str | None = None
    #endTime: str | None = None
    name: str 
    #availabilitySlotDocument: str | None = None

class JoinedStudyGroup(BaseModel):
    id: str
    name: str
    startTime: str
    endTime: str
    date: str

class JoinedStudyGroupResponse(BaseModel):
    items: List[JoinedStudyGroup]

# Response model for list of all study groups
class StudyGroupList(BaseModel):
    items: List[Union[StudyGroupPublicResponse, StudyGroupPrivateResponse]]




class SimpleJoinRequest(BaseModel):
    requesterId: str
    requesterHandle: str
    requesterDisplayName: str
    groupId: str
    groupName: str

class SimpleJoinRequestList(BaseModel):
    items: List[SimpleJoinRequest]


class InviteByHandle(BaseModel):
    handle: str

class OutgoingGroupInvite(BaseModel):
    inviteeId: str
    inviteeHandle: str
    inviteeDisplayName: str
    groupId: str
    groupName: str
    ownerId: str
    ownerHandle: str
    ownerDisplayName: str


class OutgoingGroupInviteList(BaseModel):
    items: List[OutgoingGroupInvite]


class IncomingGroupInvite(BaseModel):
    inviteeId: str          # the invited user (current user when viewing myInvites)
    groupId: str
    groupName: str
    ownerId: str
    ownerHandle: str
    ownerDisplayName: str


class IncomingGroupInviteList(BaseModel):
    items: List[IncomingGroupInvite]
