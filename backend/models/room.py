from typing import List, Optional
from pydantic import BaseModel

class Room(BaseModel):
    id: str
    buildingCode: str
    roomNumber: str
    start: str   # "07:00"
    end: str     # "16:00"
    lockedReports: int = 0  # default until you wire metrics

class RoomsResponse(BaseModel):
    items: List[Room]
    nextPageToken: Optional[str] = None
