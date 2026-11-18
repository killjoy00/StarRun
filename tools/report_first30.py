#!/usr/bin/env python3
"""Summarize identical-seed, empty-Hangar baseline/candidate first 30 seconds."""
import json
import statistics
import sys
from pathlib import Path
PHASES = ["0–8 scouts","8–12 warning","12–18 wing","18–21 break","21–30 push"]

def parse(path):
    records=[]
    for line in Path(path).read_text().splitlines():
        if "OPENING_PLAYTEST " in line:
            records.append(json.loads(line.split("OPENING_PLAYTEST ",1)[1]))
    if not records:
        raise RuntimeError(f"No playable probe results from {path}")
    if any(x["fault"] or x["elapsed"] < 28 for x in records):
        raise RuntimeError(f"Unfinished or faulty first 30 seconds: {path}")
    return records

old,new = (parse(path) for path in sys.argv[1:3])
if [x["seed"] for x in old] != [x["seed"] for x in new]:
    raise RuntimeError("Before/after seed mismatch")
def mean(rows, key, phase=None):
    values=[r["phases"][phase][key] if phase else r[key] for r in rows]
    return round(statistics.mean(values),2)

print(f"## Thirty-second, empty-Hangar matched playtest: {new[0]['ship']}, {new[0]['difficulty']}")
print(f"**Seeds:** {len(new)} · Actual combat and legitimate draft offers, no forced kills\n")
print("| Measurement | Previous 1.3 | New opening |")
print("|---|---:|---:|")
for key,name in [("first_three","First 3 visible enemies (sec)"),("first_bullet","First hostile shot (sec)"),("level","Level after 30 sec"),("kills","Kills after 30 sec"),("damage_taken","Damage taken"),("hull","Remaining hull")]:
    print(f"| {name} | {mean(old,key)} | {mean(new,key)} |")
for p in PHASES:
    for key,short in [("mean_enemies","enemies"),("empty_pct","empty %"),("mean_bullets","hostile shots")]:
        print(f"| {p} — {short} | {mean(old,key,p)} | {mean(new,key,p)} |")
print("\nAutomated pilot behavior, **not a human fun rating or real-device playtest**.")
if mean(new,"first_three") < 0 or mean(new,"first_three") > 18.0:
    raise RuntimeError("New World 1 failed to deliver its early three-ship encounter")
if mean(new,"level") < mean(old,"level") - 1.0:
    raise RuntimeError("First 30 seconds starves upgrade levels excessively")
