"""
semester_discovery.py
Location: backend/scrapers/webscraping_and_firestore/

Scrapes https://www.csulb.edu/student-records/schedule-of-classes to find
which Fall, Spring, and Summer semesters are currently listed, then validates
each one's By_Subject index actually has real courses before scraping it.

Winter is excluded — it's CPaCE (different domain/format, not scrapeable).
"""

import re
import logging
import requests
from bs4 import BeautifulSoup

logger = logging.getLogger(__name__)

SCHEDULE_PAGE = "https://www.csulb.edu/student-records/schedule-of-classes"
HEADERS = {"User-Agent": "StudyBuddy/1.0 (CSULB student app)"}
TIMEOUT = 15
SUPPORTED_SEMS = {"Fall", "Spring", "Summer"}


def discover_available_semesters() -> list[tuple[str, int]]:
    """
    Returns validated (sem, year) tuples for Fall, Spring, Summer only.
    A semester is valid if its By_Subject index has >= 5 subject links.
    """
    logger.info(f"Discovering semesters from {SCHEDULE_PAGE}")
    try:
        resp = requests.get(SCHEDULE_PAGE, headers=HEADERS, timeout=TIMEOUT)
        resp.raise_for_status()
    except requests.RequestException as e:
        logger.error(f"Failed to fetch schedule page: {e}")
        return []

    soup = BeautifulSoup(resp.text, "lxml")
    candidates = _extract_semester_links(soup)
    logger.info(f"Candidates: {[(s, y) for s, y, _ in candidates]}")

    validated = []
    for sem, year, url in candidates:
        if _validate_subject_index(sem, year, url):
            validated.append((sem, year))
            logger.info(f"  ✅ {sem} {year} — valid")
        else:
            logger.warning(f"  ⚠️  {sem} {year} — empty or unreachable, skipping")

    return validated


def _extract_semester_links(soup: BeautifulSoup) -> list[tuple[str, int, str]]:
    """
    Finds all Fall/Spring/Summer links on the schedule page.
    All three use the same web.csulb.edu/.../By_Subject/ format.
    Returns list of (sem, year, index_url).
    """
    results = []
    for a in soup.find_all("a", href=True):
        m = re.search(r"/class_schedule/(Fall|Spring|Summer)_(\d{4})/By_Subject", a["href"])
        if m:
            sem, year = m.group(1), int(m.group(2))
            index_url = (
                f"https://web.csulb.edu/depts/enrollment/registration"
                f"/class_schedule/{sem}_{year}/By_Subject/index.html"
            )
            results.append((sem, year, index_url))

    seen, unique = set(), []
    for item in results:
        key = (item[0], item[1])
        if key not in seen:
            seen.add(key)
            unique.append(item)
    return unique


def _validate_subject_index(sem: str, year: int, index_url: str) -> bool:
    """Returns True if the index page has >= 5 real subject links."""
    try:
        resp = requests.get(index_url, headers=HEADERS, timeout=TIMEOUT)
        if resp.status_code != 200:
            logger.warning(f"  {sem} {year}: HTTP {resp.status_code}")
            return False
    except requests.RequestException as e:
        logger.warning(f"  {sem} {year}: request failed — {e}")
        return False

    soup = BeautifulSoup(resp.text, "lxml")
    subject_links = [
        a["href"] for a in soup.find_all("a", href=True)
        if re.search(r"/By_Subject/[A-Za-z].+\.html", a["href"])
        and "index" not in a["href"]
    ]

    if len(subject_links) < 5:
        logger.warning(f"  {sem} {year}: only {len(subject_links)} subject links — not posted yet")
        return False

    logger.info(f"  {sem} {year}: {len(subject_links)} subjects")
    return True