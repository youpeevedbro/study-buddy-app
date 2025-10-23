from pydantic import BaseModel
from typing import Any, List, Optional, Literal

# Raw "meeting" rows we’ll write to Firestore
class Meeting(BaseModel):
    term: str
    subject: str
    building_code: str
    room_number: str
    weekday: Literal[1,2,3,4,5,6,7]   # Mon=1 … Sun=7
    start_min: int
    end_min: int
    time_label: Optional[str] = None
    session_title: Optional[str] = None
