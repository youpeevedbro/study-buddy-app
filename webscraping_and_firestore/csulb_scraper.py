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
    start = datetime.strptime(start_date, "%b %d,%Y")
    end   = datetime.strptime(end_date,   "%b %d,%Y")
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
        busy = validate_and_merge(intervals)  # filters end<=start, merges overlaps
        free = invert_busy_to_free(busy, campus_open[0], campus_open[1])
        result[(roomId, date)] = {"busy": busy, "free": free}
    return result

def _to_24_for_norm(hhmm_ampm: str) -> str:
    """
    Accepts 'H[H][:MM]AM/PM' (minutes optional) and returns 'HH:MM' 24h.
    Examples: '8AM' -> '08:00', '9:50PM' -> '21:50'
    """
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
    """
    Keep only intervals with end > start, merge overlaps/adjacent, return sorted 'HH:MM' dicts.
    """
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
    """
    Busy must already be merged. Returns free windows clipped to campus open hours.
    """
    cs, ce = _mins(open_start), _mins(open_end)
    # Convert busy dicts to minutes and clip to campus hours
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
    # Merge again defensively after clipping
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
    """
    Handles:
      - '11:00-12:15PM'
      - '8-9:50AM'
      - '8-9AM'
      - '9:30AM-10:45AM'
    Returns ('HH:MM','HH:MM') in 24h.
    """
    t = raw_range.strip().upper().replace(" ", "")
    # Allow minutes on either side (optional), AM/PM on start optional, end required
    m = _re_from_norm.fullmatch(r'(\d{1,2}(?::\d{2})?)(AM|PM)?-(\d{1,2}(?::\d{2})?)(AM|PM)', t)
    if m:
        s, sfx_s, e, sfx_e = m.groups()
        # Inherit end suffix if start missing
        sfx_s = sfx_s or sfx_e
        s24 = _to_24_for_norm(f"{s}{sfx_s}")
        e24 = _to_24_for_norm(f"{e}{sfx_e}")
        # If we inherited and start>=end (rare), flip the start's suffix once
        if m.group(2) is None:
            s_min = int(s24[:2]) * 60 + int(s24[3:])
            e_min = int(e24[:2]) * 60 + int(e24[3:])
            if s_min >= e_min:
                sfx_s = "AM" if sfx_e == "PM" else "PM"
                s24 = _to_24_for_norm(f"{s}{sfx_s}")
        return s24, e24

    # Both have explicit suffixes? (covered above, but keep a clear path)
    m2 = _re_from_norm.fullmatch(r'(\d{1,2}(?::\d{2})?)(AM|PM)-(\d{1,2}(?::\d{2})?)(AM|PM)', t)
    if m2:
        s, sfx_s, e, sfx_e = m2.groups()
        return _to_24_for_norm(f"{s}{sfx_s}"), _to_24_for_norm(f"{e}{sfx_e}")

    # Last resort: no suffixes anywhere -> assume AM both sides and add :00 if needed
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
    # raises an exception if the request fails
    r.raise_for_status()
    soup = BeautifulSoup(r.content, 'lxml')
    table = soup.find_all('tr')

    # gets all the table rows starting at index 1, skipping the table row header
    body = table[1:]

    # empty lists to store the building acronyms and names
    building_acronyms = []
    building_names = []

    # for loop to get all the 'td' HTML elements from each row
    for row in body:
        cols = row.find_all('td')
        # accessing the first 'td' element and storing the string in a variable
        acronym = cols[0].text.strip()
        # accessing the second 'td' element and storing the string in a variable
        building = cols[1].text.strip()
        # if the acronym is equal to &nbsp, skip and continue the for loop
        if acronym == "":
            continue
        else:
            # store the building acronym in the building_acronyms list
            building_acronyms.append(acronym)
            # store the building name in the building_names list
            building_names.append(building)
            
    # create a dictonary, using the building acronyms and names
    building_acronyms_and_names = dict(zip(building_acronyms, building_names))

    # Ensure uppercase keys (normalize)
    building_acronyms_and_names = {k.strip().upper(): v.strip() for k, v in building_acronyms_and_names.items()}

    # Load optional overrides to cover codes missing from the page
    try:
        import os, json
        overrides_path = os.path.join(os.path.dirname(__file__), "overrides_buildings.json")
        if os.path.exists(overrides_path):
            with open(overrides_path, "r", encoding="utf-8") as _f:
                overrides = json.load(_f)
                # normalize override keys to uppercase
                overrides = {str(k).strip().upper(): str(v).strip() for k, v in overrides.items() if v}
                building_acronyms_and_names.update(overrides)
    except Exception as _e:
        print(f"⚠️ Could not load overrides_buildings.json: {_e}")

    return building_acronyms_and_names

def scrape_subjects() -> dict:
    base_url = 'https://web.csulb.edu/depts/enrollment/registration/class_schedule/Fall_2025/By_Subject/'
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

def scrape_subject_links(class_links) -> list:
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
                    else :
                        session_title = session_title.removeprefix("Session: ")
            else:
                session_title = "Aug 25-Dec 10,2025"
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
                        # classes.append([location])
    return classes

def clean_scraped_data(classes: list, building_map: dict) -> list:
    cleaned_data = []

    DAY_CODES = {
        "MTuWTh": ["M", "Tu", "W", "Th"],
        "MWF": ["M", "W", "F"],
        "TuTh": ["Tu", "Th"],
        "SaSu": ["Sa", "Su"],
        "WF": ["W", "F"],
        "MW": ["M", "W"],
        "M": ["M"], "Tu": ["Tu"], "W": ["W"], "Th": ["Th"], "F": ["F"], "Sa": ["Sa"], "Su": ["Su"]
    }

    for item in classes:
        sessions, days, time, location = [x.strip() for x in item]

        # Dates like "Aug 25-Dec 10,2025" → "Aug 25,2025" and "Dec 10,2025"
        startSession, endSession = sessions.split('-')
        startSession = startSession + "," + endSession.split(",", 1)[1]

        # Days list
        daysOfWeek = DAY_CODES.get(days, [days])

        for d in daysOfWeek:
            assert d in DAY_MAP, f"Unexpected day token: {d}"

        # Times → use the robust normalizer (handles “11:00-12:15PM” etc.)
        startTime24, endTime24 = normalize_time_range(time)

        # Building + room (exact uppercase code lookup)
        if "-" not in location:
            # skip malformed rows
            continue
        location_building_code, location_room_number = location.split("-", 1)
        code_key = location_building_code.strip().upper()
        location_building_name = building_map.get(code_key, "Unknown Building")

        cleaned_data.append({
            "start_date": startSession,
            "end_date":   endSession,
            "days":       daysOfWeek,
            "start_time": startTime24,   # already HH:MM
            "end_time":   endTime24,     # already HH:MM
            "building_name": location_building_name,
            "building_code": code_key,
            "room":         location_room_number.strip()
        })

    # Warn if any codes from the schedule aren’t in your map (so you can add to overrides)
    _seen = {row["building_code"] for row in cleaned_data}
    _missing = sorted(_seen - set(building_map.keys()))
    if _missing:
        print(f"⚠️ Missing building codes in map: {_missing}. Add them to overrides_buildings.json and rerun.")

    return cleaned_data

# def to_24hr(t: str) -> str:
#     # e.g., "8:00AM" -> "08:00", "12:15PM" -> "12:15", "12:00AM" -> "00:00"
#     return datetime.strptime(t, "%I:%M%p").strftime("%H:%M")

# def convert_times_to_24h_format(cleaned_classes: list) -> list:
#     for item in cleaned_classes:
#         item['start_time'] = to_24hr(item['start_time'])
#         item['end_time']   = to_24hr(item['end_time'])
#     return cleaned_classes

def main():
    building_map   = scrape_building_codes_and_names()
    subject_links  = scrape_subjects()
    classes        = scrape_subject_links(subject_links.values())
    cleaned_classes= clean_scraped_data(classes, building_map)

    # Sanity-check cleaned rows (already HH:MM)
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

    # Optional: debug dump
    with open("final_output.txt", "w") as f:
        for item in cleaned_classes:
            f.write(f"{item}\n")

    # Build per (roomId,date)
    per_day = build_daily_busy_and_free(cleaned_classes, campus_open=("07:00","22:00"))

    # Write JSONL files
    
    with open("out_busy.jsonl", "w") as fb, open("out_availability.jsonl", "w") as fa:
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
                "campusOpen": {"start":"07:00","end":"22:00"},
                "free": data["free"],
                "buildingCode": bcode,
                "roomNumber": room_num,
                "floor": floor,
                "campusZone": campusZone
            }) + "\n")
            
if __name__ == "__main__":
    main()
