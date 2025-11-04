from pydantic import BaseModel

class Group(BaseModel):
    name: str
    date: str | None = None
    time: str | None = None
    location: str
    max_members: int | None = None
    creator_id: str | None = None
