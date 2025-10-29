# Check 1:

# def hhmm_to_min(t):
#     h, m = map(int, t.split(":"))
#     return h*60 + m

# bad = 0
# q = (db.collection("availabilitySlots")
#        .where(filter=FieldFilter("date", "==", "2025-10-28"))
#        .limit(5000))  # keep it large but bounded

# for doc in q.stream():
#     d = doc.to_dict()
#     calc_start = hhmm_to_min(d["start"])
#     calc_end   = hhmm_to_min(d["end"])
#     if d["startMin"] != calc_start or d["endMin"] != calc_end or d["durationMin"] != (d["endMin"] - d["startMin"]):
#         bad += 1
#         print("MISMATCH:", doc.id, d["start"], d["startMin"], d["end"], d["endMin"], d["durationMin"], "calc:", calc_start, calc_end, calc_end-calc_start)

# print("TOTAL mismatches:", bad)

# Check 2: detect overlapping slots for the same room on the same day

# pull one day to check overlaps
# DAY = "2025-10-28"
# rooms = defaultdict(list)

# q = db.collection("availabilitySlots").where(filter=FieldFilter("date","==",DAY)).limit(10000)
# for doc in q.stream():
#     d = doc.to_dict()
#     rooms[d["roomId"]].append((d["startMin"], d["endMin"], doc.id))

# overlaps = 0
# for roomId, intervals in rooms.items():
#     intervals.sort()
#     for (s1,e1,_id1),(s2,e2,_id2) in zip(intervals, intervals[1:]):
#         if s2 < e1:  # overlap
#             overlaps += 1
#             print("OVERLAP:", roomId, (s1,e1), (s2,e2), _id1, _id2)

# print("TOTAL overlaps:", overlaps)


from google.cloud import firestore
from zoneinfo import ZoneInfo
from google.cloud.firestore_v1 import FieldFilter
from datetime import datetime
from collections import defaultdict
from collections import Counter

db = firestore.Client()
today = "2025-10-29"

start_date = "2025-10-27"
end_date   = "2025-10-28"


# QUERY 0: REAL TESTING FOR FUN

# # compute "now" in minutes after midnight (adjust if you want local tz math)
# now = datetime.now()
# nowMin = now.hour * 60 + now.minute

# # server: one inequality on endMin, plus equalities
# q = (db.collection("availabilitySlots")
#        .where(filter=FieldFilter("date", "==", today))
#        .where(filter=FieldFilter("buildingCode", "==", "MLSC"))
#     #    .where(filter=FieldFilter("floor", "==", 3))
#        .where(filter=FieldFilter("endMin", ">=", nowMin))
#     )

# # client refine: ensure the slot already started
# for doc in q.stream():
#     d = doc.to_dict()
#     if d["startMin"] <= nowMin:
#         # print(doc.id, d)
#         print(d["roomId"], d["start"], d["end"])



# QUERY 1: COB building -> 2025-10-27 -> durationMin >= 60 minutes

q = (db.collection("availabilitySlots")
       .where(filter=FieldFilter("buildingCode", "==", "COB"))
       .where(filter=FieldFilter("date", "==", today))
       .where(filter=FieldFilter("durationMin", ">=", 60)))

for doc in q.stream():
    d = doc.to_dict()
    # print(doc.id, doc.to_dict())
    print(d["roomId"], d["start"], d["end"])



# QUERY 2: 2025-10-27 -> COB building -> 2nd floor -> classrooms available NOW

# # compute "now" in minutes after midnight (adjust if you want local tz math)
# now = datetime.now()
# nowMin = now.hour * 60 + now.minute

# # server: one inequality on endMin, plus equalities
# q = (db.collection("availabilitySlots")
#        .where(filter=FieldFilter("date", "==", today))
#        .where(filter=FieldFilter("buildingCode", "==", "COB"))
#        .where(filter=FieldFilter("floor", "==", 2))
#        .where(filter=FieldFilter("endMin", ">=", nowMin))
#     )

# # client refine: ensure the slot already started
# for doc in q.stream():
#     d = doc.to_dict()
#     if d["startMin"] <= nowMin:
#         print(doc.id, d)



# QUERY 3: Display all rooms available in "lower" campus between 2025-10-27 and 2025-10-28

# q = (db.collection("availabilitySlots")
#        .where(filter=FieldFilter("campusZone", "==", "lower"))
#        .where(filter=FieldFilter("date", ">=", start_date))
#        .where(filter=FieldFilter("date", "<=", end_date)))

# cnt = 0
# for doc in q.stream():
#     d = doc.to_dict()
#     cnt += 1
#     print(doc.id, d)
# print("TOTAL:", cnt)



# QUERY 4: 2025-10-27 -> rooms available NOW with at least 60 minutes remaining

# pt = ZoneInfo("America/Los_Angeles")
# now = datetime.now(pt)
# nowMin = now.hour*60 + now.minute

# MIN_REMAINING = 60

# q = (db.collection("availabilitySlots")
#        .where(filter=FieldFilter("date", "==", today))
#        .where(filter=FieldFilter("endMin", ">=", nowMin)))

# hits = 0
# for doc in q.stream():
#     d = doc.to_dict()
#     if d["startMin"] <= nowMin and (d["endMin"] - nowMin) >= MIN_REMAINING:
#         hits += 1
        # print(d["roomId"], d["start"], d["end"], d["campusZone"])
# print("TOTAL free ≥60m now:", hits)



# QUERY 5: 2025-10-28 -> VEC building -> overlapping 13:00–15:00 slots

# BUILDING = "VEC"     # change if you want
# DAY = "2025-10-28"
# window_start = 13*60   # 13:00
# window_end   = 15*60   # 15:00

# q = (db.collection("availabilitySlots")
#        .where(filter=FieldFilter("date", "==", DAY))
#        .where(filter=FieldFilter("buildingCode", "==", BUILDING))
#        .where(filter=FieldFilter("endMin", ">=", window_start)))

# count = 0
# for doc in q.stream():
#     d = doc.to_dict()
#     if d["startMin"] <= window_end:  # client refine
#         count += 1
#         print(doc.id, d["roomId"], d["start"], d["end"])
# print("TOTAL overlapping 13:00-15:00:", count)



# QUERY 6: 2025-10-28 -> VEC building -> 5th floor -> durationMin >= 120 minutes

# q = (db.collection("availabilitySlots")
#        .where(filter=FieldFilter("date", "==", "2025-10-28"))
#        .where(filter=FieldFilter("buildingCode", "==", "VEC"))
#        .where(filter=FieldFilter("floor", "==", 5))
#        .where(filter=FieldFilter("durationMin", ">=", 120)))

# n = 0
# for doc in q.stream():
#     d = doc.to_dict()
#     n += 1
#     print(doc.id, d["roomId"], d["start"], d["end"], d["durationMin"])
# print("TOTAL VEC floor 5 ≥120m:", n)


# QUERY 7: 2025-10-27 -> "upper" campus -> rooms available NOW with at least 90 minutes remaining

# pt = ZoneInfo("America/Los_Angeles")
# now = datetime.now(pt)
# nowMin = now.hour*60 + now.minute
# MIN_REMAINING = 90

# q = (db.collection("availabilitySlots")
#        .where(filter=FieldFilter("date", "==", today))
#        .where(filter=FieldFilter("campusZone", "==", "upper"))
#        .where(filter=FieldFilter("endMin", ">=", nowMin)))

# count = 0
# for doc in q.stream():
#     d = doc.to_dict()
#     if d["startMin"] <= nowMin and (d["endMin"] - nowMin) >= MIN_REMAINING:
#         count += 1
#         print(d["roomId"], d["start"], d["end"], d["campusZone"], "remain:", d["endMin"] - nowMin)
# print("TOTAL upper campus free ≥90m now:", count)



# QUERY 8: 2025-10-27 -> COB building -> 2nd floor -> classrooms available NOW sorted by remaining minutes DESC

# pt = ZoneInfo("America/Los_Angeles")
# now = datetime.now(pt)
# nowMin = now.hour*60 + now.minute

# q = (db.collection("availabilitySlots")
#        .where(filter=FieldFilter("date", "==", today))
#        .where(filter=FieldFilter("buildingCode", "==", "COB"))
#        .where(filter=FieldFilter("floor", "==", 2))
#        .where(filter=FieldFilter("endMin", ">=", nowMin)))

# rows = []
# for doc in q.stream():
#     d = doc.to_dict()
#     if d["startMin"] <= nowMin:
#         rows.append((d["roomId"], d["start"], d["end"], d["endMin"] - nowMin))
# for r in sorted(rows, key=lambda x: -x[3]):  # desc by remaining minutes
#     print(*r)



# QUERY 9: count of available slots per day in VEC building for the week 2025-10-27 to 2025-11-02

# start_week = "2025-10-27"
# end_week   = "2025-11-02"
# BUILDING   = "VEC"

# q = (db.collection("availabilitySlots")
#        .where(filter=FieldFilter("buildingCode", "==", BUILDING))
#        .where(filter=FieldFilter("date", ">=", start_week))
#        .where(filter=FieldFilter("date", "<=", end_week)))

# by_day = Counter()
# for doc in q.stream():
#     by_day[doc.to_dict()["date"]] += 1

# for day, n in sorted(by_day.items()):
#     print(day, n)