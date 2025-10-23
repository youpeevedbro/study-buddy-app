import os
from dotenv import load_dotenv

# Load backend/.env before importing routers that use env vars
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), ".env"))

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import ingest

app = FastAPI(title="StudyBuddy Ingest Backend", version="1.0.0")

origins = [o.strip() for o in os.getenv("CORS_ALLOW_ORIGINS","").split(",") if o.strip()]
if origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

app.include_router(ingest.router)

@app.get("/healthz")
def health():
    return {"ok": True}
