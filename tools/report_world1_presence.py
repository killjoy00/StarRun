#!/usr/bin/env python3
"""Matched-seed World 1 on-screen enemy density and difficulty assessment."""
import json
import statistics
import sys
from pathlib import Path

def load(path):
    rows = []
    for line in Path(path).read_text().splitlines():
        if "WORLD1_PROBE " in line:
            rows.append(json.loads(line.split("WORLD1_PROBE ", 1)[1]))
    if not rows:
        raise ValueError(f"No completed World 1 probe rows in {path}")
    return rows

before, after = load(sys.argv[1]), load(sys.argv[2])
assert [r["seed"] for r in before] == [r["seed"] for r in after], "Mismatched seeds"
def mean(rows, key, phase=None):
    if phase:
        values = [r[phase][key] for r in rows if r[phase]["samples"]]
    else:
        values = [r[key] for r in rows]
    return round(statistics.mean(values), 2) if values else None

print("## Matched-seed World 1 balance: empty Hangar, same ship/pilot\n")
print(f"**Ship:** {after[0]['ship']} · **Difficulty:** {after[0]['difficulty']} · **Seeds:** {len(before)}\n")
print("| Metric | Before | After |")
print("|---|---:|---:|")
for desc, key, phase in [
    ("World 1 clears", "won_world1", None),
    ("First enemy visible (seconds)", "first_enemy", None),
    ("First 3 enemies together (seconds, -1=never)", "first_three", None),
    ("0–45s mean visible enemies", "mean_enemies", "early"),
    ("0–45s empty-screen %", "empty_pct", "early"),
    ("45–120s mean visible enemies", "mean_enemies", "middle"),
    ("120–240s mean visible enemies", "mean_enemies", "late"),
    ("0–45s mean visible hostile bullets", "mean_bullets", "early"),
    ("0–45s crowded (>=3) %", "crowded_pct", "early"),
    ("Level at World 1 end", "level", None),
    ("Total damage taken", "damage_taken", None),
]:
    print(f"| {desc} | {mean(before,key,phase)} | {mean(after,key,phase)} |")
print("\nDeterministic scripted bot outcomes, **not** real player win rates or a substitute for human playtesting.")
