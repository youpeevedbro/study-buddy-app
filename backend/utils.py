import re
from typing import List, Tuple

def parse_days(days_str: str) -> List[int]:
    """CSULB compact day strings like 'MW', 'TuTh', 'F' → [1,3], [2,4], [5]"""
    if not days_str or days_str.upper() == "TBA":
        return []
    s = days_str.strip()
    s = s.replace("Th", "R")   # avoid clashing with 'T'
    s = s.replace("Tu", "U")
    days = []
    for ch in s:
        if ch == 'M': days.append(1)
        elif ch == 'U': days.append(2)
        elif ch == 'W': days.append(3)
        elif ch == 'R': days.append(4)
        elif ch == 'F': days.append(5)
    return days

_time_re = re.compile(r'(\d{1,2})(?::(\d{2}))?\s*-\s*(\d{1,2})(?::(\d{2}))?\s*([AP]M)', re.I)

def _to_minutes(h: int, m: int, ampm: str) -> int:
    ampm = ampm.upper()
    if h == 12:
        h = 0
    if ampm == 'PM':
        h += 12
    return h*60 + m

def parse_time_range(label: str) -> Tuple[int, int]:
    """
    "8-9:15AM" → (480, 555), "11:30-12:45PM" → (690, 765)
    If the format can’t be parsed, return (0,0) so caller can skip.
    """
    s = label.replace(" ", "")
    m = _time_re.search(s)
    if not m:
        return (0, 0)
    sh = int(m.group(1)); sm = int(m.group(2) or 0)
    eh = int(m.group(3)); em = int(m.group(4) or 0)
    ampm = m.group(5).upper()
    return _to_minutes(sh, sm, ampm), _to_minutes(eh, em, ampm)

def split_location(loc: str) -> Tuple[str, str]:
    """'EN2-312' → ('EN2','312'); 'Library - 408' → ('Library','408'); fallback: ('loc','NA')"""
    loc = loc.strip()
    if "-" in loc:
        b, r = loc.split("-", 1)
        return b.strip(), r.strip()
    parts = loc.split()
    if parts and parts[-1].isdigit():
        return parts[0], parts[-1]
    return loc, "NA"
