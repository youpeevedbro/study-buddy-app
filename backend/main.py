# backend/main.py
from dotenv import load_dotenv
import os
from typing import List

from fastapi import FastAPI, Depends, Header, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware

import firebase_admin
from firebase_admin import auth, credentials
from routers import rooms  # our read-only router
from routers import addgroup

# --- Auth dependency (import the single source of truth from auth.py) ---
from auth import verify_firebase_token  # noqa: E402

# Load .env from project root
load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"), override=True)

# --- Firebase Admin init (for token verification) ---
sa_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
if not sa_path or not os.path.exists(sa_path):
    raise RuntimeError("GOOGLE_APPLICATION_CREDENTIALS not set or file not found.")
cred = credentials.Certificate(sa_path)
firebase_admin.initialize_app(cred)
print(f"Firebase Admin initialized with {sa_path}")

# --- Allowed domains (plural preferred; fallback to singular) ---
_domains_raw = os.getenv("ALLOWED_EMAIL_DOMAINS") or os.getenv("ALLOWED_EMAIL_DOMAIN", "@csulb.edu")
allowed_domains: List[str] = [d.strip().lower() for d in _domains_raw.split(",") if d.strip()]
print(f"Allowed domains: {allowed_domains}")

# --- FastAPI app & CORS ---
app = FastAPI(title="StudyBuddy API", version="1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # tighten for production
    allow_methods=["*"],
    allow_headers=["*"],
    allow_credentials=True,
)

def verify_firebase_token(authorization: str | None = Header(default=None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")

    token = authorization.split(" ", 1)[1]
    try:
        decoded = auth.verify_id_token(token, check_revoked=True)
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=f"Invalid token: {e}")

    email = (decoded.get("email") or "").lower()
    if not email:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="No email in token")

    # --- Domain guard (supports multiple, comma-separated) ---
    if allowed_domains and not any(email.endswith(d) for d in allowed_domains):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Email domain not allowed")

    return decoded  # can return claims for downstream use

# --- Routers ---
app.include_router(rooms.router, prefix="/rooms", tags=["rooms"], dependencies=[Depends(verify_firebase_token)])
app.include_router(addgroup.router, prefix="/groups", tags=["groups"])

# --- Health check ---
@app.get("/health")
def health():
    return {"ok": True, "service": "StudyBuddy API"}
