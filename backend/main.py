# backend/main.py
from dotenv import load_dotenv
import os
from typing import List

from fastapi import FastAPI, Depends, Header, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware

import firebase_admin
from firebase_admin import auth, credentials

from routers import rooms
from routers import addgroup

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
# Allowed email domains (backend enforcement)
# --------------------------------------------------------------------
# Normalize: remove leading '@', split comma list
_domains_raw = (
    os.getenv("ALLOWED_EMAIL_DOMAINS")    # e.g. "csulb.edu,student.csulb.edu"
    or os.getenv("ALLOWED_EMAIL_DOMAIN")  # fallback
    or "csulb.edu"                        # final fallback
)

allowed_domains: List[str] = [
    d.strip().lower().lstrip("@")
    for d in _domains_raw.split(",")
    if d.strip()
]

print(f"✅ Allowed domains (base): {allowed_domains}")

# --------------------------------------------------------------------
# FastAPI app + CORS
# --------------------------------------------------------------------
app = FastAPI(title="StudyBuddy API", version="1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],    # tighten later
    allow_methods=["*"],
    allow_headers=["*"],
    allow_credentials=True,
)

# --------------------------------------------------------------------
# Firebase token verification dependency
# --------------------------------------------------------------------
def verify_firebase_token(authorization: str | None = Header(default=None)):
    """Verifies Firebase ID token + enforces email domain restrictions."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token"
        )

    token = authorization.split(" ", 1)[1]

    try:
        decoded = auth.verify_id_token(token, check_revoked=True)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {e}"
        )

    email = (decoded.get("email") or "").lower()
    if not email:
        raise HTTPException(status_code=401, detail="No email in token")

    # Extract just the domain — everything after the last '@'
    domain = email.split("@")[-1]

    # Allow exact domain or any subdomain of it
    def _allowed(d: str) -> bool:
        # d is base, e.g. "csulb.edu"
        return domain == d or domain.endswith("." + d)

    if allowed_domains and not any(_allowed(d) for d in allowed_domains):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Email domain not allowed: {domain}"
        )

    return decoded  # claims available to downstream routes

# --------------------------------------------------------------------
# Routers
# --------------------------------------------------------------------
app.include_router(
    rooms.router,
    prefix="/rooms",
    tags=["rooms"],
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
