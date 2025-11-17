# backend/main.py
from dotenv import load_dotenv
import os
from typing import List

from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware

import firebase_admin
from firebase_admin import credentials

from routers import rooms
from routers import addgroup
from auth import verify_firebase_token  # use shared auth helper

# --------------------------------------------------------------------
# Load .env for LOCAL development only.
# Cloud Run will ignore this and use env vars you pass via gcloud.
# --------------------------------------------------------------------
load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"), override=True)

# --------------------------------------------------------------------
# 🔥 Firebase Admin Initialization (LOCAL + CLOUD RUN SAFE)
# --------------------------------------------------------------------
sa_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")

if sa_path and os.path.exists(sa_path):
    # Local development mode
    cred = credentials.Certificate(sa_path)
    firebase_admin.initialize_app(cred)
    print(f"✅ Firebase Admin initialized using local service account: {sa_path}")
else:
    # Cloud Run mode (Application Default Credentials)
    firebase_admin.initialize_app()
    print("✅ Firebase Admin initialized using Application Default Credentials (ADC)")

# --------------------------------------------------------------------
# Allowed email domains (for logging only; enforcement is in auth.py)
# --------------------------------------------------------------------
_domains_raw = (
    os.getenv("ALLOWED_EMAIL_DOMAINS")    # e.g. "student.csulb.edu"
    or os.getenv("ALLOWED_EMAIL_DOMAIN")  # fallback
    or "student.csulb.edu"                # final fallback
)

allowed_domains: List[str] = [
    d.strip().lower().lstrip("@")
    for d in _domains_raw.split(",")
    if d.strip()
]

print(f"✅ Allowed domains (Firebase users): {allowed_domains}")

# --------------------------------------------------------------------
# FastAPI app + CORS
# --------------------------------------------------------------------
app = FastAPI(title="StudyBuddy API", version="1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],    # you can tighten this later
    allow_methods=["*"],
    allow_headers=["*"],
    allow_credentials=True,
)

# --------------------------------------------------------------------
# Routers
# --------------------------------------------------------------------
app.include_router(
    rooms.router,
    prefix="/rooms",
    tags=["rooms"],
    # Students (Firebase) + Cloud Scheduler service account
    dependencies=[Depends(verify_firebase_token)],
)

app.include_router(
    addgroup.router,
    prefix="/groups",
    tags=["groups"],
)

# --------------------------------------------------------------------
# Health Check for Cloud Run
# --------------------------------------------------------------------
@app.get("/health")
def health():
    return {"ok": True, "service": "StudyBuddy API"}
