# backend/main.py
from dotenv import load_dotenv
import os
from auth import get_current_user
load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"), override=True)


from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import rooms  # our read-only router
from fastapi.openapi.utils import get_openapi
from fastapi import Depends, Security
from auth import get_current_user, security

# --- Verify .env loaded (optional sanity log) ---
if not os.getenv("GOOGLE_APPLICATION_CREDENTIALS"):
    print("⚠️  GOOGLE_APPLICATION_CREDENTIALS not loaded from .env")
else:
    print(f"✅ Using service account at {os.getenv('GOOGLE_APPLICATION_CREDENTIALS')}")

# --- FastAPI setup ---
app = FastAPI(title="StudyBuddy API", version="1.0", redirect_slashes=False)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # tighten in production
    allow_methods=["*"],
    allow_headers=["*"],
    allow_credentials=True,
)

# --- Routers ---
app.include_router(rooms.router, tags=["rooms"])

# --- Health check ---
@app.get("/health")
def health():
    return {"ok": True, "service": "StudyBuddy API"}

@app.get("/protected", dependencies=[Security(security)])
def protected(user=Depends(get_current_user)):
    return {
        "ok": True,
        "sub": user["sub"],
        "aud": user["aud"],
        "iss": user["iss"]
    }

# def custom_openapi():
#     if app.openapi_schema:
#         return app.openapi_schema
#     openapi_schema = get_openapi(
#         title="StudyBuddy API",
#         version="1.0",
#         description="Study Buddy backend with Auth0 authentication",
#         routes=app.routes,
#     )
#     openapi_schema["components"]["securitySchemes"] = {
#         "BearerAuth": {
#             "type": "http",
#             "scheme": "bearer",
#             "bearerFormat": "JWT"
#         }
#     }
#     openapi_schema["security"] = [{"BearerAuth": []}]
#     app.openapi_schema = openapi_schema
#     return app.openapi_schema

# app.openapi = custom_openapi
