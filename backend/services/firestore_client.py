import os, logging
from functools import lru_cache
from google.cloud import firestore
from google.oauth2 import service_account

log = logging.getLogger("uvicorn.error")

@lru_cache(maxsize=1)
def get_db() -> firestore.Client:
    cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS") or ""
    project_id = os.getenv("FIRESTORE_PROJECT_ID")

    log.info(f"Firestore init: PROJECT={project_id}, CREDS='{cred_path}' (exists={os.path.exists(cred_path)})")

    if cred_path and os.path.exists(cred_path):
        creds = service_account.Credentials.from_service_account_file(cred_path)
        return firestore.Client(project=project_id, credentials=creds)

    raise RuntimeError(
        "Service account JSON not found or env var not set. "
        f"GOOGLE_APPLICATION_CREDENTIALS='{cred_path}'"
    )
