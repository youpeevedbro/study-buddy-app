import os
from dotenv import load_dotenv
from google.cloud import firestore

# Make sure .env is considered even if this module is imported first
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), ".env"))

# Prefer GCP_PROJECT_ID; fall back to FIREBASE_PROJECT_ID
_project_id = os.getenv("GCP_PROJECT_ID") or os.getenv("FIREBASE_PROJECT_ID")
if not _project_id:
    raise RuntimeError("Set GCP_PROJECT_ID or FIREBASE_PROJECT_ID in backend .env")

_db = firestore.Client(project=_project_id)

def db():
    return _db
