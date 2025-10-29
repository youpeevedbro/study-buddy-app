# main.py
from dotenv import load_dotenv
load_dotenv()  # loads GOOGLE_APPLICATION_CREDENTIALS, FIRESTORE_PROJECT_ID, etc.

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import rooms  # our read-only router

app = FastAPI(title="StudyBuddy API", version="1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # tighten for prod
    allow_methods=["*"],
    allow_headers=["*"],
    allow_credentials=True,
)

# expose it as /rooms even though Firestore uses availabilitySlots
app.include_router(rooms.router, prefix="/rooms", tags=["rooms"])

# main.py
@app.get("/")
def health():
    return {"ok": True, "service": "StudyBuddy API"}
