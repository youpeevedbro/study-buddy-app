from pydantic import BaseModel

# Request model for creating a Study Group
class StudyGroupCreate(BaseModel):
    building: str
    roomNumber: int
    date: str        #YYYY-MM-DD
    startTime: str   #HH:MM on 24 hr cycle
    endTime: str     #HH:MM on 24 hr cycle
    name: str
    availabilitySlotDocument: str #{BUILDING}-{ROOM#}_{YYYY}-{MM}-{DD}_{startMin}_{endMin}


    

