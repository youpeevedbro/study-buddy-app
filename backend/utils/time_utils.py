# backend/utils/time_utils.py
def hhmm_to_min(hhmm: str) -> int:
    hh, mm = hhmm.split(":")
    return int(hh) * 60 + int(mm)

def min_to_hhmm(m: int) -> str:
    return f"{m // 60:02d}:{m % 60:02d}"