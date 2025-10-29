import os, logging
from functools import lru_cache
from google.cloud import firestore
from google.oauth2 import service_account

log = logging.getLogger("uvicorn.error")

@lru_cache(maxsize=1)
def get_db() -> firestore.Client:
    cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    project_id = os.getenv("FIRESTORE_PROJECT_ID")

    if cred_path and os.path.exists(cred_path):
        log.info(f"Firestore: using service account at {cred_path}")
        creds = service_account.Credentials.from_service_account_file(cred_path)
        return firestore.Client(project=project_id, credentials=creds)

    log.info("Firestore: using default ADC credentials (no explicit JSON path found)")
    return firestore.Client(project=project_id)
