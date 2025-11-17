import os
import json
import firebase_admin
from firebase_admin import credentials, firestore

def main():
    try:
        print("🔍 Checking environment and credential...")

        # Load from .env if needed (optional)
        from dotenv import load_dotenv
        load_dotenv()

        cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
        print(f"📄 Credential path from .env: {cred_path}")

        if not cred_path or not os.path.exists(cred_path):
            print(f"❌ Credential file not found at: {cred_path}")
            return

        # Check that it’s a valid JSON file
        with open(cred_path, "r") as f:
            data = json.load(f)
            print(f"✅ JSON loaded successfully. Project ID: {data.get('project_id')}")

        # Initialize Firebase Admin
        print("🚀 Initializing Firebase app...")
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)

        # Optional: test Firestore connection
        db = firestore.client()
        docs = db.collections()
        print("✅ Firebase Admin initialized successfully!")
        print(f"📚 Found {len(list(docs))} top-level Firestore collections (if Firestore is enabled).")

    except Exception as e:
        print(f"🚨 Error occurred: {e}")

if __name__ == "__main__":
    main()
