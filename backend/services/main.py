"""
main.py
Location: backend/services/main.py

FastAPI app serving both the StudyBuddy API and the scraper cron endpoint.
Cloud Scheduler hits POST /scrape every Monday at midnight Pacific.

Import path setup:
  services/ is the working directory in the container.
  scrapers/webscraping_and_firestore/ is added to sys.path so all
  scraper modules can be imported directly by name.
"""

import os
import sys
import json
import logging
from datetime import date
from contextlib import asynccontextmanager

import requests as _req
from bs4 import BeautifulSoup as _BS
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from google.cloud import firestore

# ── path setup ────────────────────────────────────────────────────────
# services/main.py  →  ../../scrapers/webscraping_and_firestore/
_HERE       = os.path.dirname(os.path.abspath(__file__))
_SCRAPER_DIR = os.path.abspath(os.path.join(_HERE, "scrapers", "webscraping_and_firestore"))
if _SCRAPER_DIR not in sys.path:
    sys.path.insert(0, _SCRAPER_DIR)

from csulb_scraper import (
    scrape_building_codes_and_names,
    clean_scraped_data,
    build_daily_busy_and_free,
    _split_room_id_for_floor,
    _infer_floor,
    _campus_zone_student,
)
from semester_discovery import discover_available_semesters
from semester_utils import firestore_key, prune_stale_semesters
from generate_availability_slots import generate_slots
import firestore_upload_buildings as fub

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ── JSONL work files written to the services/ directory in the container ──
_WORK = _HERE
BUSY_PATH  = os.path.join(_WORK, "out_busy.jsonl")
FREE_PATH  = os.path.join(_WORK, "out_availability.jsonl")
SLOTS_PATH = os.path.join(_WORK, "availability_slots.jsonl")

# Fallback session label when a subject page has no sessionTitle header.
# Add new entries each year — old ones are harmless.
SEM_DEFAULTS: dict[tuple[str, int], str] = {
    ("Spring", 2025): "Jan 20-May 14,2025",
    ("Summer", 2025): "Jun 2-Aug 6,2025",
    ("Fall",   2025): "Aug 25-Dec 10,2025",
    ("Spring", 2026): "Jan 20-May 15,2026",
    ("Summer", 2026): "Jun 1-Aug 5,2026",
    ("Fall",   2026): "Aug 24-Dec 11,2026",
    ("Spring", 2027): "Jan 19-May 14,2027",
    ("Summer", 2027): "Jun 7-Aug 11,2027",
    ("Fall",   2027): "Aug 23-Dec 10,2027",
}


# ── FastAPI app ────────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("StudyBuddy backend starting up")
    yield
    logger.info("StudyBuddy backend shutting down")

app = FastAPI(title="StudyBuddy API", lifespan=lifespan)


# ── Request / Response models ──────────────────────────────────────────

class ScrapeRequest(BaseModel):
    sem: str | None = None
    year: int | None = None


class ScrapeResponse(BaseModel):
    status: str
    today: str | None = None
    semesters_scraped: list | None = None
    kept: list[str] | None = None
    detail: str | None = None


# ── Scraping helpers ───────────────────────────────────────────────────

def _scrape_subjects_dynamic(sem: str, year: int) -> dict:
    base_url = (
        f"https://web.csulb.edu/depts/enrollment/registration"
        f"/class_schedule/{sem}_{year}/By_Subject/"
    )
    r = _req.get(base_url, timeout=15)
    r.raise_for_status()
    soup = _BS(r.content, "lxml")
    links = {}

    table = soup.find("div", class_="indexList")
    if table:
        for ul in table.find_all("ul"):
            for li in ul.find_all("li"):
                for a in li.find_all("a"):
                    links[a.get_text(strip=True)] = base_url + a["href"].strip()
    else:
        import re
        for a in soup.find_all("a", href=True):
            href = a["href"]
            if "/By_Subject/" in href and href.endswith(".html") and "index" not in href:
                full = href if href.startswith("http") else "https://web.csulb.edu" + href
                links[a.get_text(strip=True)] = full

    return links


def _scrape_subject_links_dynamic(class_links: list, default_session: str) -> list:
    classes = []
    for link in class_links:
        try:
            page = _req.get(link, timeout=15)
            page.raise_for_status()
        except Exception as e:
            logger.warning(f"Failed to fetch {link}: {e}")
            continue

        soup = _BS(page.content, "lxml")
        for sess in soup.find_all("div", class_="session"):
            title_tag = sess.find("h2", class_="sessionTitle")
            if title_tag:
                session_title = title_tag.get_text(strip=True)
                st = session_title.lower()
                if "session: " in st:
                    session_title = session_title.replace(" - ", "-")
                    if "(8w1)" in st:
                        session_title = session_title.removeprefix("Session: ").removesuffix(" (8W1)")
                    elif "(8w2)" in st:
                        session_title = session_title.removeprefix("Session: ").removesuffix(" (8W2)")
                    else:
                        session_title = session_title.removeprefix("Session: ")
            else:
                session_title = default_session

            for block in sess.find_all("div", class_="courseBlock"):
                for row in block.find_all("tr"):
                    cols = row.find_all("td")
                    if len(cols) < 9:
                        continue
                    days     = cols[5].text.strip()
                    time_str = cols[6].text.strip()
                    location = cols[8].text.strip()
                    if days.lower() in ("tba", "na"):
                        continue
                    if location.lower() in ("tba", "na"):
                        continue
                    if "online" in location.lower() or "off" in location.lower():
                        continue
                    classes.append([session_title, days, time_str, location])
    return classes


# ── Firestore tagged uploads ───────────────────────────────────────────

def _tag_jsonl(path: str, sem_year: str):
    """Adds sem_year field to every line of a JSONL file in-place."""
    lines = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            if line.strip():
                obj = json.loads(line)
                obj["sem_year"] = sem_year
                lines.append(json.dumps(obj))
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def _upload_slots_tagged(jsonl_path: str, sem_year: str, batch_size: int = 400):
    """Uploads availability slots tagged with sem_year for future clean deletion."""
    db = firestore.Client()
    batch = db.batch()
    count = 0
    with open(jsonl_path, "r", encoding="utf-8") as f:
        for line in f:
            if not line.strip():
                continue
            obj = json.loads(line)
            obj["sem_year"] = sem_year
            doc_id = f'{obj["roomId"]}_{obj["date"]}_{obj["startMin"]}_{obj["endMin"]}'
            ref = db.collection("availabilitySlots").document(doc_id)
            batch.set(ref, obj)
            count += 1
            if count % batch_size == 0:
                batch.commit()
                logger.info(f"  Slots committed: {count}")
                batch = db.batch()
    if count % batch_size != 0:
        batch.commit()
    logger.info(f"  Total slots uploaded: {count}")
    return count


# ── Per-semester pipeline ──────────────────────────────────────────────

def _run_semester(sem: str, year: int, building_map: dict) -> dict:
    key = firestore_key(sem, year)
    default_session = SEM_DEFAULTS.get(
        (sem, year),
        (
            f"Jan 20-May 15,{year}" if sem == "Spring"
            else f"Jun 1-Aug 5,{year}" if sem == "Summer"
            else f"Aug 24-Dec 11,{year}"
        )
    )

    logger.info(f"  ▶ {key}")

    subject_links = _scrape_subjects_dynamic(sem, year)
    logger.info(f"    Subjects: {len(subject_links)}")

    raw = _scrape_subject_links_dynamic(list(subject_links.values()), default_session)
    logger.info(f"    Raw rows: {len(raw)}")

    cleaned = clean_scraped_data(raw, building_map)
    logger.info(f"    Cleaned:  {len(cleaned)}")
    if not cleaned:
        return {"key": key, "skipped": True, "reason": "no cleaned data"}

    per_day = build_daily_busy_and_free(cleaned, campus_open=("07:00", "22:00"))

    with open(BUSY_PATH, "w", encoding="utf-8") as fb, \
         open(FREE_PATH,  "w", encoding="utf-8") as fa:
        for (roomId, dt), data in per_day.items():
            bcode, room_num = _split_room_id_for_floor(roomId)
            floor = _infer_floor(room_num)
            zone  = _campus_zone_student(bcode)
            fb.write(json.dumps({
                "roomId": roomId, "date": dt,
                "intervals": data["busy"],
                "buildingCode": bcode, "roomNumber": room_num,
                "floor": floor, "campusZone": zone,
            }) + "\n")
            fa.write(json.dumps({
                "roomId": roomId, "date": dt,
                "campusOpen": {"start": "07:00", "end": "22:00"},
                "free": data["free"],
                "buildingCode": bcode, "roomNumber": room_num,
                "floor": floor, "campusZone": zone,
            }) + "\n")

    _tag_jsonl(BUSY_PATH, key)
    _tag_jsonl(FREE_PATH, key)

    # Generate >=30 min slots, passing explicit paths
    generate_slots(in_path=FREE_PATH, out_path=SLOTS_PATH)

    logger.info(f"    Uploading to Firestore…")
    fub.upsert_buildings()
    fub.upload_busy()
    fub.upload_availability()
    _upload_slots_tagged(SLOTS_PATH, sem_year=key)

    return {
        "key": key,
        "skipped": False,
        "subjects": len(subject_links),
        "raw_rows": len(raw),
        "cleaned_rows": len(cleaned),
        "room_date_pairs": len(per_day),
    }


# ── Pipeline orchestrator ──────────────────────────────────────────────

def _run_pipeline(force_sem: str = None, force_year: int = None) -> dict:
    db = firestore.Client()

    if force_sem and force_year:
        semesters = [(force_sem, force_year)]
    else:
        semesters = discover_available_semesters()

    if not semesters:
        return {
            "status": "no_semesters",
            "detail": "Nothing valid found on schedule page — may not be posted yet",
        }

    logger.info(f"Semesters to scrape: {[firestore_key(s, y) for s, y in semesters]}")

    prune_stale_semesters(db, semesters)

    building_map = scrape_building_codes_and_names()

    results = []
    for sem, year in semesters:
        results.append(_run_semester(sem, year, building_map))

    return {
        "status": "ok",
        "today": str(date.today()),
        "semesters_scraped": results,
        "kept": [firestore_key(s, y) for s, y in semesters],
    }


# ── Routes ─────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/scrape", response_model=ScrapeResponse)
async def scrape(body: ScrapeRequest = ScrapeRequest()):
    """
    Triggered by Cloud Scheduler every Monday at midnight Pacific.
    No body needed — semesters are auto-discovered from the CSULB page.
    Optional override: { "sem": "Fall", "year": 2026 }
    """
    try:
        force_sem  = body.sem  or os.environ.get("SEM")
        force_year = body.year or (int(os.environ["YEAR"]) if os.environ.get("YEAR") else None)
        result = _run_pipeline(force_sem, force_year)
        return result
    except Exception as e:
        logger.exception("Scrape pipeline failed")
        raise HTTPException(status_code=500, detail=str(e))