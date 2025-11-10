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


# Response model for getting a Study Group (where user is not a member)
class StudyGroupPublicResponse(BaseModel):
    id: str
    buildingCode: str
    roomNumber: int
    date: str
    startTime: str
    endTime: str
    name: str
    quantity: int
    # ADD owner fields
    availabilitySlotDocument: str

# Response model for getting a Study Group (where user is a member)
class StudyGroupPrivateResponse(BaseModel):
    id: str
    buildingCode: str
    roomNumber: int
    date: str
    startTime: str
    endTime: str
    name: str
    quantity: int
    # ADD owner fields
    members: list[str]  #List of User IDs
    availabilitySlotDocument: str

# Request model for updating a Study Group
class StudyGroupUpdate(BaseModel):
    buildingCode: str | None = None
    roomNumber: int | None = None
    date: str | None = None
    startTime: str | None = None
    endTime: str | None = None
    name: str | None = None
    availabilitySlotDocument: str | None = None




    

