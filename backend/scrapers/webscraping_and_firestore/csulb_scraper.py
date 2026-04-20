# run the code below to activate the virtual enviroment to activate the dependencies
# source .venv/bin/activate

import requests
from bs4 import BeautifulSoup
from collections import defaultdict
from datetime import datetime
import re as _re_from_norm
from datetime import datetime as _dt_from_norm
from datetime import timedelta
import json
import os

# --- student-definition campus zone helper ---
UPPER_STUDENT = {
    "AS","CINE","ED2","EED","FA1","FA2","FA3","FA4","FO2",
    "LA1","LA2","LA3","LA4","LA5","LAB","LH","MHB","MIC",
    "MLSC","PH1","PSY","SSC","TA","UT"
}
def _campus_zone_student(bcode: str) -> str:
    return "upper" if (bcode or "").upper() in UPPER_STUDENT else "lower"
# --- end zone helper ---

# --- added helpers for building/room/floor enrichment ---
import re as _re_floor

def _split_room_id_for_floor(room_id: str):
    if "-" in room_id:
        bcode, rest = room_id.split("-", 1)
    else:
        m = _re_floor.match(r"^([A-Za-z]+)(.*)$", room_id or "")
        if m:
            bcode, rest = m.group(1), m.group(2).lstrip("-")
        else:
            bcode, rest = "", room_id or ""
    return (bcode.strip().upper(), rest.strip())

def _infer_floor(room_number: str):
    s = (room_number or "").strip().upper()
    if s.startswith(("LL", "L0", "B", "G")):
        return 0
    if s.startswith("M"):
        return 1
    m = _re_floor.search(r"(\d)", s)
    if not m:
        return None
    d = int(m.group(1))
    return 0 if d == 0 else d
# --- end helpers ---


DAY_MAP = {"M":0, "Tu":1, "W":2, "Th":3, "F":4, "Sa":5, "Su":6}

def expand_days_to_dates(start_date: str, end_date: str, days: list[str]) -> list[str]:
    start = datetime.strptime(start_date.split('(')[0].strip(), "%b %d,%Y")
    end   = datetime.strptime(end_date.split('(')[0].strip(),   "%b %d,%Y")
    targets = {DAY_MAP[d] for d in days}
    out, cur = [], start
    one = timedelta(days=1)
    while cur <= end:
        if cur.weekday() in targets:
            out.append(cur.strftime("%Y-%m-%d"))
        cur += one
    return out

def build_daily_busy_and_free(rows: list[dict], campus_open=("07:00","22:00")):
    # explode to daily busy rows
    daily = []
    for row in rows:
        room_id = f"{row['building_code']}-{row['room']}"
        for d in expand_days_to_dates(row['start_date'], row['end_date'], row['days']):
            daily.append({"roomId": room_id, "date": d, "start": row["start_time"], "end": row["end_time"]})

    # group by (roomId, date)
    grouped = defaultdict(list)
    for r in daily:
        grouped[(r["roomId"], r["date"])].append({"start": r["start"], "end": r["end"]})

    # validate/merge busy, then invert to free (clipped)
    result = {}
    for (roomId, date), intervals in grouped.items():
        busy = validate_and_merge(intervals)
        free = invert_busy_to_free(busy, campus_open[0], campus_open[1])
        result[(roomId, date)] = {"busy": busy, "free": free}
    return result

def _to_24_for_norm(hhmm_ampm: str) -> str:
    s = hhmm_ampm.strip().upper()
    m = _re_from_norm.fullmatch(r'(\d{1,2})(?::(\d{2}))?(AM|PM)', s)
    if not m:
        raise ValueError(f"Bad time token: {hhmm_ampm!r}")
    hh = int(m.group(1))
    mm = m.group(2) or "00"
    ampm = m.group(3)
    return _dt_from_norm.strptime(f"{hh:02d}:{mm}{ampm}", "%I:%M%p").strftime("%H:%M")

def _mins(hhmm: str) -> int:
    h, m = map(int, hhmm.split(":"))
    return h * 60 + m

def _from_mins(x: int) -> str:
    return f"{x//60:02d}:{x%60:02d}"

def validate_and_merge(intervals: list[dict]) -> list[dict]:
    pairs = []
    for w in intervals or []:
        try:
            s, e = _mins(w["start"]), _mins(w["end"])
            if e > s:
                pairs.append((s, e))
        except Exception:
            continue
    pairs.sort()
    merged = []
    for s, e in pairs:
        if not merged or s > merged[-1][1]:
            merged.append([s, e])
        else:
            merged[-1][1] = max(merged[-1][1], e)
    return [{"start": _from_mins(s), "end": _from_mins(e)} for s, e in merged]

def invert_busy_to_free(busy: list[dict], open_start="07:00", open_end="22:00") -> list[dict]:
    cs, ce = _mins(open_start), _mins(open_end)
    pairs = []
    for w in busy or []:
        try:
            s, e = _mins(w["start"]), _mins(w["end"])
            if e <= s:
                continue
            s = max(s, cs); e = min(e, ce)
            if e > s:
                pairs.append((s, e))
        except Exception:
            continue
    pairs.sort()
    merged = []
    for s, e in pairs:
        if not merged or s > merged[-1][1]:
            merged.append([s, e])
        else:
            merged[-1][1] = max(merged[-1][1], e)

    free = []
    cur = cs
    for s, e in merged:
        if cur < s:
            free.append({"start": _from_mins(cur), "end": _from_mins(s)})
        cur = max(cur, e)
    if cur < ce:
        free.append({"start": _from_mins(cur), "end": _from_mins(ce)})
    return free

def normalize_time_range(raw_range: str) -> tuple[str, str]:
    t = raw_range.strip().upper().replace(" ", "")
    m = _re_from_norm.fullmatch(r'(\d{1,2}(?::\d{2})?)(AM|PM)?-(\d{1,2}(?::\d{2})?)(AM|PM)', t)
    if m:
        s, sfx_s, e, sfx_e = m.groups()
        sfx_s = sfx_s or sfx_e
        s24 = _to_24_for_norm(f"{s}{sfx_s}")
        e24 = _to_24_for_norm(f"{e}{sfx_e}")
        if m.group(2) is None:
            s_min = int(s24[:2]) * 60 + int(s24[3:])
            e_min = int(e24[:2]) * 60 + int(e24[3:])
            if s_min >= e_min:
                sfx_s = "AM" if sfx_e == "PM" else "PM"
                s24 = _to_24_for_norm(f"{s}{sfx_s}")
        return s24, e24

    m2 = _re_from_norm.fullmatch(r'(\d{1,2}(?::\d{2})?)(AM|PM)-(\d{1,2}(?::\d{2})?)(AM|PM)', t)
    if m2:
        s, sfx_s, e, sfx_e = m2.groups()
        return _to_24_for_norm(f"{s}{sfx_s}"), _to_24_for_norm(f"{e}{sfx_e}")

    if "-" in t:
        s, e = t.split("-", 1)
        if ":" not in s: s += ":00"
        if ":" not in e: e += ":00"
        return _to_24_for_norm(f"{s}AM"), _to_24_for_norm(f"{e}AM")

    raise ValueError(f"Unrecognized time range: {raw_range!r}")

base_url = "https://www.csulb.edu/"

def scrape_building_codes_and_names() -> dict:
    url = "https://www.csulb.edu/maps/building-names-codes"
    r = requests.get(url)
    r.raise_for_status()
    soup = BeautifulSoup(r.content, 'lxml')
    table = soup.find_all('tr')
    body = table[1:]
    building_acronyms = []
    building_names = []
    for row in body:
        cols = row.find_all('td')
        acronym = cols[0].text.strip()
        building = cols[1].text.strip()
        if acronym == "":
            continue
        else:
            building_acronyms.append(acronym)
            building_names.append(building)
    building_acronyms_and_names = dict(zip(building_acronyms, building_names))
    building_acronyms_and_names = {k.strip().upper(): v.strip() for k, v in building_acronyms_and_names.items()}
    try:
        import os, json
        overrides_path = os.path.join(os.path.dirname(__file__), "overrides_buildings.json")
        if os.path.exists(overrides_path):
            with open(overrides_path, "r", encoding="utf-8") as _f:
                overrides = json.load(_f)
                overrides = {str(k).strip().upper(): str(v).strip() for k, v in overrides.items() if v}
                building_acronyms_and_names.update(overrides)
    except Exception as _e:
        print(f"⚠️ Could not load overrides_buildings.json: {_e}")
    return building_acronyms_and_names


def scrape_subjects(sem: str = "Fall", year: int = 2026) -> dict:
    """
    Scrapes the By_Subject index for the given semester and year.
    Defaults to Fall 2026. Pass sem/year to scrape other semesters.
    """
    base_url = f'https://web.csulb.edu/depts/enrollment/registration/class_schedule/{sem}_{year}/By_Subject/'
    url = base_url + '#'
    r = requests.get(url)
    soup = BeautifulSoup(r.content, 'lxml')
    table = soup.find('div', class_='indexList')
    ul_rows = table.find_all('ul')
    class_names = []
    class_links = []
    for ul in ul_rows:
        li_rows = ul.find_all('li')
        for li in li_rows:
            for a in li.find_all('a'):
                class_names.append(a.text.strip())
                class_links.append(base_url + a['href'].strip())
    class_names_and_links = dict(zip(class_names, class_links))
    return class_names_and_links


def scrape_subject_links(class_links, default_session: str = "Aug 24-Dec 11,2026") -> list:
    """
    Scrapes all subject pages. default_session is used when a page has no
    sessionTitle header. Update this string each semester.
    """
    classes = []
    for link in class_links:
        page = requests.get(link)
        page_soup = BeautifulSoup(page.content, 'lxml')
        sessions = page_soup.find_all('div', class_='session')

        for indiv_session in sessions:
            session_duration = indiv_session.find('h2', class_='sessionTitle')
            if session_duration:
                session_title = session_duration.get_text(strip=True)
                st_lower = session_title.lower()
                if "session: " in st_lower:
                    if " - " in st_lower:
                        session_title = session_title.replace(" - ", "-")
                    if "(8w1)" in st_lower:
                        session_title = session_title.removeprefix("Session: ").removesuffix(" (8W1)")
                    elif "(8w2)" in st_lower:
                        session_title = session_title.removeprefix("Session: ").removesuffix(" (8W2)")
                    else:
                        session_title = session_title.removeprefix("Session: ")
            else:
                session_title = default_session
            courseBlocks = indiv_session.find_all('div', class_='courseBlock')
            for indiv_courseBlock in courseBlocks:
                rows = indiv_courseBlock.find_all('tr')
                for indiv_row in rows:
                    cols = indiv_row.find_all('td')
                    if len(cols) < 9:
                        continue
                    days = cols[5].text.strip()
                    time = cols[6].text.strip()
                    location = cols[8].text.strip()
                    if days.lower() == "tba" or days.lower() == "na":
                        continue
                    if location.lower() == "tba" or location.lower() == "na":
                        continue
                    if "online" in location.lower():
                        continue
                    if "off" in location.lower():
                        continue
                    else:
                        classes.append([session_title, days, time, location])
    return classes

def clean_scraped_data(classes: list, building_map: dict) -> list:
    cleaned_data = []

    DAY_CODES = {
        "MTuWThF": ["M", "Tu", "W", "Th", "F"],
        "MTuWTh": ["M", "Tu", "W", "Th"],
        "MWF": ["M", "W", "F"],
        "TuWTh": ["Tu", "W", "Th"],
        "TuThF": ["Tu", "Th", "F"],
        "TuTh": ["Tu", "Th"],
        "MWTh": ["M", "W", "Th"],
        "SaSu": ["Sa", "Su"],
        "WTh": ["W", "Th"],
        "WF": ["W", "F"],
        "MW": ["M", "W"],
        "MF": ["M", "F"],
        "MTh": ["M", "Th"],
        "M": ["M"], "Tu": ["Tu"], "W": ["W"], "Th": ["Th"], "F": ["F"], "Sa": ["Sa"], "Su": ["Su"]
    }

    for item in classes:
        sessions, days, time, location = [x.strip() for x in item]

        startSession, endSession = sessions.split('-')
        startSession = startSession + "," + endSession.split(",", 1)[1]

        if time.strip().upper() == "NA":
            continue

        daysOfWeek = DAY_CODES.get(days, [days])

        if any(d not in DAY_MAP for d in daysOfWeek):
            continue

        startTime24, endTime24 = normalize_time_range(time)

        if "-" not in location:
            continue
        location_building_code, location_room_number = location.split("-", 1)
        code_key = location_building_code.strip().upper()
        location_building_name = building_map.get(code_key, "Unknown Building")

        cleaned_data.append({
            "start_date": startSession,
            "end_date":   endSession,
            "days":       daysOfWeek,
            "start_time": startTime24,
            "end_time":   endTime24,
            "building_name": location_building_name,
            "building_code": code_key,
            "room":         location_room_number.strip()
        })

    _seen = {row["building_code"] for row in cleaned_data}
    _missing = sorted(_seen - set(building_map.keys()))
    if _missing:
        print(f"⚠️ Missing building codes in map: {_missing}. Add them to overrides_buildings.json and rerun.")

    return cleaned_data


def main():
    building_map   = scrape_building_codes_and_names()
    subject_links  = scrape_subjects(sem="Fall", year=2026)
    classes        = scrape_subject_links(subject_links.values(), default_session="Aug 24-Dec 11,2026")
    cleaned_classes= clean_scraped_data(classes, building_map)

    _bad_rows = []
    for _r in cleaned_classes:
        _s, _e = _r.get("start_time"), _r.get("end_time")
        try:
            if len(_s) != 5 or len(_e) != 5: _bad_rows.append(("bad-format", _r)); continue
            if _mins(_e) <= _mins(_s):        _bad_rows.append(("end<=start", _r))
        except Exception:
            _bad_rows.append(("parse-error", _r))
    if _bad_rows:
        raise RuntimeError(f"Found {len(_bad_rows)} invalid cleaned rows; first: {_bad_rows[0]}")

    here = os.path.dirname(__file__)
    final_out_path = os.path.join(here, "final_output.txt")
    out_busy_path = os.path.join(here, "out_busy.jsonl")
    out_avail_path = os.path.join(here, "out_availability.jsonl")

    with open(final_out_path, "w", encoding="utf-8") as f:
        for item in cleaned_classes:
            f.write(f"{item}\n")

    per_day = build_daily_busy_and_free(cleaned_classes, campus_open=("07:00", "22:00"))

    with open(out_busy_path, "w", encoding="utf-8") as fb, open(out_avail_path, "w", encoding="utf-8") as fa:
        for (roomId, date), data in per_day.items():
            bcode, room_num = _split_room_id_for_floor(roomId)
            floor = _infer_floor(room_num)
            campusZone = _campus_zone_student(bcode)

            fb.write(json.dumps({
                "roomId": roomId,
                "date": date,
                "intervals": data["busy"],
                "buildingCode": bcode,
                "roomNumber": room_num,
                "floor": floor,
                "campusZone": campusZone
            }) + "\n")

            fa.write(json.dumps({
                "roomId": roomId,
                "date": date,
                "campusOpen": {"start": "07:00", "end": "22:00"},
                "free": data["free"],
                "buildingCode": bcode,
                "roomNumber": room_num,
                "floor": floor,
                "campusZone": campusZone
            }) + "\n")

    print(f"✅ Scrape complete!")
    print(f"   - Wrote {len(cleaned_classes)} cleaned class entries to {final_out_path}")
    print(f"   - Wrote busy slots to {out_busy_path}")
    print(f"   - Wrote availability slots to {out_avail_path}")

if __name__ == "__main__":
    main()