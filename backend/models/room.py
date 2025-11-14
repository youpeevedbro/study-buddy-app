from typing import List, Optional
from pydantic import BaseModel

class Room(BaseModel):
    id: str
    buildingCode: str
    roomNumber: str
    date: str            # e.g. "2025-10-28"
    start: str           # e.g. "07:00"
    end: str             # e.g. "16:00"
    lockedReports: int = 0   # exposed to frontend as lockedReports

class RoomsResponse(BaseModel):
    items: List[Room]
    nextPageToken: Optional[str] = None
