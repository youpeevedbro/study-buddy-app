# backend/auth.py
import os
from typing import List, Optional

from fastapi import Header, HTTPException, status
from firebase_admin import auth as fb_auth

from google.oauth2 import id_token as google_id_token
from google.auth.transport import requests as google_requests

# -------------------------
# Config from environment
# -------------------------

# Student email domains (e.g. "student.csulb.edu")
_domains_raw = os.getenv("ALLOWED_EMAIL_DOMAINS") or os.getenv("ALLOWED_EMAIL_DOMAIN", "")
ALLOWED_EMAIL_DOMAINS: List[str] = [
    d.strip().lower() for d in _domains_raw.split(",") if d.strip()
]

# Service accounts allowed to call protected endpoints (cron, system jobs)
_service_accounts_raw = os.getenv("ALLOWED_SERVICE_ACCOUNTS", "")
ALLOWED_SERVICE_ACCOUNTS: List[str] = [
    s.strip().lower() for s in _service_accounts_raw.split(",") if s.strip()
]

# Expected audience for Google OIDC tokens (Cloud Run URL)
SERVICE_AUDIENCE: Optional[str] = os.getenv("SERVICE_AUDIENCE")


def _email_domain(email: str) -> str:
    """Return the exact domain part after '@'."""
    if "@" not in email:
        return ""
    return email.split("@", 1)[1].lower()


def _check_student_email_domain(email: str):
    """
    Enforce that the Firebase-authenticated user has a domain
    exactly in ALLOWED_EMAIL_DOMAINS (e.g. student.csulb.edu).
    No wildcards, no subdomains.
    """
    if not ALLOWED_EMAIL_DOMAINS:
        return  # nothing configured, allow all (not your case)

    domain = _email_domain(email)
    if domain not in ALLOWED_EMAIL_DOMAINS:
        # Don't fall back to service-account auth if this was
        # a valid Firebase token with a wrong domain.
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Email domain not allowed: {domain}",
        )


def _try_verify_firebase_id_token(raw_token: str):
    """
    Try to verify as a Firebase ID token.
    On success: enforce student domain and return claims.
    On failure: return None (so we can try OIDC).
    """
    try:
        decoded = fb_auth.verify_id_token(raw_token, check_revoked=True)
    except Exception:
        # Not a valid Firebase token → let caller try OIDC
        return None

    email = (decoded.get("email") or "").lower()
    if not email:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Firebase token has no email",
        )

    _check_student_email_domain(email)
    return decoded


def _try_verify_service_account_token(raw_token: str):
    """
    Verify Google OIDC token for service accounts (e.g., Cloud Scheduler → Cloud Run).
    Requires SERVICE_AUDIENCE and ALLOWED_SERVICE_ACCOUNTS to be set.
    """
    if not SERVICE_AUDIENCE:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="SERVICE_AUDIENCE not configured on server",
        )

    request = google_requests.Request()
    try:
        payload = google_id_token.verify_oauth2_token(
            raw_token, request, SERVICE_AUDIENCE
        )
    except Exception as e:
        # Not a valid OIDC token, or wrong audience/issuer
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid OIDC token: {e}",
        )

    issuer = payload.get("iss")
    if issuer not in ("https://accounts.google.com", "accounts.google.com"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid OIDC issuer: {issuer}",
        )

    email = (payload.get("email") or "").lower()
    if not email:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="OIDC token has no email",
        )

    if ALLOWED_SERVICE_ACCOUNTS and email not in ALLOWED_SERVICE_ACCOUNTS:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Service account not allowed: {email}",
        )

    return payload


def verify_firebase_token(authorization: str | None = Header(default=None)):
    """
    FastAPI dependency used in main.py.

    Auth flow:
      1. Expect Authorization: Bearer <token>
      2. Try Firebase ID token:
         - if valid AND domain allowed → OK (student)
         - if valid BUT domain not allowed → 403
         - if invalid → fall through to OIDC
      3. Try Google OIDC token:
         - if valid OIDC & service account allowed → OK (cron/system)
         - otherwise → 401/403
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
        )

    raw_token = authorization.split(" ", 1)[1].strip()

    # 1) Try Firebase (students)
    decoded = _try_verify_firebase_id_token(raw_token)
    if decoded is not None:
        return decoded

    # 2) Try OIDC (service accounts, e.g., Cloud Scheduler)
    return _try_verify_service_account_token(raw_token)
