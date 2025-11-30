from pydantic import BaseModel

class Group(BaseModel):
    name: str
    date: str
    starttime: str
    endtime: str
    building: str
    room: str
    creator_id: str | None = None

