# backend/auth.py
from typing import Annotated, List
from fastapi import Depends, Header, HTTPException, status
from firebase_admin import auth as fb_auth
import os

ALLOWED_DOMAINS: List[str] = [
    d.strip().lower()
    for d in os.getenv("ALLOWED_EMAIL_DOMAIN", "@csulb.edu").split(",")
    if d.strip()
]

def verify_firebase_token(authorization: Annotated[str | None, Header()] = None):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")
    token = authorization.split(" ", 1)[1]
    try:
        decoded = fb_auth.verify_id_token(token, check_revoked=True)
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=f"Invalid token: {e}")

    email = (decoded.get("email") or "").lower()
    if not email or (ALLOWED_DOMAINS and not any(email.endswith(d) for d in ALLOWED_DOMAINS)):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Email domain not allowed")

    return decoded  # return claims for downstream use
