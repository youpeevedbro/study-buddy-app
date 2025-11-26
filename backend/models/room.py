# backend/models/room.py
from typing import List, Optional
from pydantic import BaseModel


class Room(BaseModel):
    id: str
    buildingCode: str
    roomNumber: str
    date: str            # e.g. "2025-10-28"
    start: str           # e.g. "07:00"
    end: str             # e.g. "16:00"
    lockedReports: int = 0          # total unique-user reports
    userHasReported: bool = False   # did *this* user already report?
    currentCheckins: int = 0   # 👈 NEW


class RoomsResponse(BaseModel):
    items: List[Room]
    nextPageToken: Optional[str] = None
