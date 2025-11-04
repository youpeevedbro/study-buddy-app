# backend/main.py
from dotenv import load_dotenv
import os

load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"), override=True)


from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from backend.routers import rooms  # our read-only router
from backend.routers import addgroup

# --- Verify .env loaded (optional sanity log) ---
if not os.getenv("GOOGLE_APPLICATION_CREDENTIALS"):
    print("⚠️  GOOGLE_APPLICATION_CREDENTIALS not loaded from .env")
else:
    print(f"✅ Using service account at {os.getenv('GOOGLE_APPLICATION_CREDENTIALS')}")

# --- FastAPI setup ---
app = FastAPI(title="StudyBuddy API", version="1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # tighten in production
    allow_methods=["*"],
    allow_headers=["*"],
    allow_credentials=True,
)

# --- Routers ---
app.include_router(rooms.router, prefix="/rooms", tags=["rooms"])
app.include_router(addgroup.router, prefix="/groups", tags=["groups"])

# --- Health check ---
@app.get("/health")
def health():
    return {"ok": True, "service": "StudyBuddy API"}
