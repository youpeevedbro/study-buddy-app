# backend/models/room.py
from typing import List, Optional
from pydantic import BaseModel

class Room(BaseModel):
    id: str
    buildingCode: str
    roomNumber: str
    date: str            # <-- add date
    start: str           # "07:00"
    end: str             # "16:00"
    lockedReports: int = 0

class RoomsResponse(BaseModel):
    items: List[Room]
    nextPageToken: Optional[str] = None
