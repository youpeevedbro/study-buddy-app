# backend/services/firestore_client.py
import os
import logging
from functools import lru_cache

from google.cloud import firestore
from google.oauth2 import service_account

log = logging.getLogger("uvicorn.error")


@lru_cache(maxsize=1)
def get_db() -> firestore.Client:
    """
    Returns a Firestore client that works in all environments:

    LOCAL DEVELOPMENT:
        - If GOOGLE_APPLICATION_CREDENTIALS points to a real JSON service
          account file, we use that for auth and also use FIRESTORE_PROJECT_ID.

    CLOUD RUN:
        - No credentials file.
        - Uses Application Default Credentials (service account attached to the
          Cloud Run service).
        - We DO NOT pass project=, so Firestore auto-detects the correct GCP project
          from the Cloud Run metadata server.

    This makes the backend immune to anyone accidentally setting corrupted
    FIRESTORE_PROJECT_ID values in Cloud Run.
    """

    cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    project_id = os.getenv("FIRESTORE_PROJECT_ID")

    log.info(
        "Firestore init: GOOGLE_APPLICATION_CREDENTIALS='%s' (exists=%s), FIRESTORE_PROJECT_ID='%s'",
        cred_path,
        os.path.exists(cred_path or ""),
        project_id,
    )

    # ------------------------------------------------------
    # LOCAL DEVELOPMENT (JSON credentials present)
    # ------------------------------------------------------
    if cred_path and os.path.exists(cred_path):
        log.info("Firestore (LOCAL): using local service account JSON")

        creds = service_account.Credentials.from_service_account_file(cred_path)

        if project_id:
            log.info(f"Firestore (LOCAL): using explicit project '{project_id}'")
            return firestore.Client(project=project_id, credentials=creds)

        # No project provided — let Firestore infer it
        log.warning("Firestore (LOCAL): FIRESTORE_PROJECT_ID missing, inferring project from JSON file")
        client = firestore.Client(credentials=creds)
        log.info(f"Firestore (LOCAL): inferred project '{client.project}'")
        return client

    # ------------------------------------------------------
    # CLOUD RUN (NO JSON CREDENTIALS)
    # ------------------------------------------------------
    log.info("Firestore (CLOUD RUN): using ADC (Application Default Credentials)")
    log.info("Firestore (CLOUD RUN): ignoring FIRESTORE_PROJECT_ID entirely")

    # This auto-detects the correct project ID from Cloud Run metadata
    client = firestore.Client()
    log.info(f"Firestore (CLOUD RUN): initialized with project '{client.project}'")

    return client
