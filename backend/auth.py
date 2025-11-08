# backend/auth.py
import os
import time
import requests
from jose import jwt
from fastapi import Security, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from dotenv import load_dotenv

# Load env from project root/.env
load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"), override=True)

AUTH0_DOMAIN   = os.getenv("AUTH0_DOMAIN")
AUTH0_AUDIENCE = os.getenv("AUTH0_AUDIENCE")
ALGORITHMS     = ["RS256"]

if not AUTH0_DOMAIN or not AUTH0_AUDIENCE:
    raise RuntimeError("AUTH0_DOMAIN and AUTH0_AUDIENCE must be set")

security = HTTPBearer()

# ---- JWKS cache with TTL ----
_JWKS_CACHE       = None
_JWKS_FETCHED_AT  = 0.0
_JWKS_TTL_SECONDS = 60 * 10  # 10 minutes

def _fetch_jwks() -> dict:
    url = f"https://{AUTH0_DOMAIN}/.well-known/jwks.json"
    try:
        resp = requests.get(url, timeout=5)
        resp.raise_for_status()
        return resp.json()
    except requests.RequestException as e:
        raise HTTPException(status_code=503, detail=f"JWKS fetch failed: {e}")

def _get_jwks(force: bool = False) -> dict:
    global _JWKS_CACHE, _JWKS_FETCHED_AT
    now = time.time()
    if force or _JWKS_CACHE is None or (now - _JWKS_FETCHED_AT) > _JWKS_TTL_SECONDS:
        _JWKS_CACHE = _fetch_jwks()
        _JWKS_FETCHED_AT = now
    return _JWKS_CACHE

def _pick_key_by_kid(kid: str) -> dict | None:
    jwks = _get_jwks()
    return next((k for k in jwks.get("keys", []) if k.get("kid") == kid), None)

def verify_token(token: str):
    # 1) Read unverified header to get kid
    try:
        header = jwt.get_unverified_header(token)
        kid = header.get("kid")
        if not kid:
            raise HTTPException(status_code=401, detail="Token is missing 'kid' header")
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token header")

    # 2) Pick key by kid (refresh once if not found to handle rotation)
    rsa_key = _pick_key_by_kid(kid)
    if not rsa_key:
        # JWKS may have rotated – force refresh once
        _get_jwks(force=True)
        rsa_key = _pick_key_by_kid(kid)
        if not rsa_key:
            raise HTTPException(status_code=401, detail="Signing key not found (kid mismatch)")

    # 3) Decode & validate with a little clock-skew leeway
    try:
        payload = jwt.decode(
            token,
            rsa_key,
            algorithms=ALGORITHMS,
            audience=AUTH0_AUDIENCE,
            issuer=f"https://{AUTH0_DOMAIN}/",
            options={"leeway": 60},  # 60s clock skew tolerance
        )
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.JWTClaimsError as e:
        # wrong audience/issuer/etc.
        raise HTTPException(status_code=401, detail=f"Invalid claims: {str(e)}")
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token")

def get_current_user(credentials: HTTPAuthorizationCredentials = Security(security)):
    token = credentials.credentials
    return verify_token(token)
