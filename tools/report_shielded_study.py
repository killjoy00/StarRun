#!/usr/bin/env python3
"""Aggregate the matched Star/Run Godot study without pretending to estimate human win rates."""
import collections
import json
import os
from pathlib import Path
import sys

source = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("matched-artifacts")
rows = []
for path in sorted(source.rglob("shielded-*.log")):
    for line in path.read_text(errors="replace").splitlines():
        if "BALANCE_MATRIX " not in line:
            continue
        try:
            data = json.loads(line.split("BALANCE_MATRIX ", 1)[1])
        except json.JSONDecodeError:
            continue
        rows.append(data)

# There should be one row for every matrix cell, route and draft policy.
expected = 12 * 3 * 2
keys = [(r["difficulty"], r["hangar"], r["ship"], r["pilot"], r["route"], r["build"]) for r in rows]
complete = len(rows) == expected and len(set(keys)) == expected
totals = collections.defaultdict(lambda: collections.Counter())
tiers = collections.defaultdict(lambda: collections.Counter())
for r in rows:
    k = (r["build"], r["route"])
    t = (r["difficulty"], r["hangar"], r["build"], r["route"])
    for bucket in (totals[k], tiers[t]):
        bucket["wins"] += int(r["campaign_wins"])
        bucket["attempts"] += int(r["seeds"])
        bucket["world1"] += int(r["world_clears"][0])
        bucket["fusion"] += int(r.get("shieldstorm_runs", 0))
        bucket["rank5"] += int(r.get("focus5_runs", 0))
        bucket["rank10"] += int(r.get("focus10_runs", 0))
        bucket["auto_pulses"] += int(r.get("shieldstorm_trigger_worlds", 0))
        bucket["full_hull_seconds"] += float(r.get("pristine_focus_seconds", 0.0))

def count(bucket, name):
    return str(bucket.get(name, 0))

lines = [
    "# Shieldstorm vs Redline — matched automated balance",
    "",
    "**Status:** " + ("COMPLETE" if complete else "INCOMPLETE — not all study cells are available"),
    "",
    "Scripted autopilot + automatic weapons + real random draft hands. These are **not human win rates**.",
    "All policies use the same four starting seeds in each ship, pilot, difficulty, Hangar and route cell.",
    "Combat choices can lead to different RNG trajectories after the starting seed.",
    "",
    "## Four-world victories by build and route",
    "",
    "| Draft strategy | Route | Victories | Shieldstorm built | Focus rank 5 | Focus rank 10 | Auto clears | Full-hull Focus time |",
    "|---|---|---:|---:|---:|---:|---:|---:|",
]
for build in ("focused", "shielded"):
    for route in ("repair", "overclock", "bounty"):
        x = totals[(build, route)]
        wins = f'{count(x, "wins")}/{count(x, "attempts")}'
        lines.append(
            f'| {build} | {route} | {wins} | {count(x, "fusion")} | {count(x, "rank5")} | '
            f'{count(x, "rank10")} | {count(x, "auto_pulses")} | {x["full_hull_seconds"]:.1f}s |'
        )
lines += [
    "",
    "## By difficulty and Hangar",
    "",
    "| Difficulty | Hangar | Draft | Shielded | Redline | Hunter |",
    "|---|---|---|---:|---:|---:|",
]
for difficulty, hangar in (("normal", "mid"), ("hard", "mid"), ("hard", "max"), ("insane", "max")):
    for build in ("focused", "shielded"):
        def score(route):
            x = tiers[(difficulty, hangar, build, route)]
            return f'{count(x, "wins")}/{count(x, "attempts")}'
        lines.append(f'| {difficulty} | {hangar} | {build} | {score("repair")} | {score("overclock")} | {score("bounty")} |')

lines += [
    "",
    "## What this can and cannot establish",
    "",
    "- Shielded draft + Shielded Passage vs the same shielded draft + Redline isolates the route effect, with matched starting seeds.",
    "- Shielded draft + Shielded Passage vs focused draft + Redline compares deliberately optimized styles, not route modifiers alone.",
    "- Fusion/rank counts are actual achievements, not forced unlocks. If they are scarce, the run cannot establish the feature's combat potential.",
    "- The full-hull counter measures only the seconds in Worlds 2–4 when rank 5+ is owned and hull is truly at maximum.",
    f'- Collected {len(rows)}/{expected} unique summary rows; {len(set(keys))} distinct matrix cells.',
]
notes = "\n".join(lines) + "\n"
Path("shielded-build-summary.md").write_text(notes)
Path("shielded-build-summary.json").write_text(json.dumps({
    "complete": complete,
    "expected_cells": expected,
    "observed_cells": len(rows),
    "rows": rows,
}, indent=2) + "\n")
if os.getenv("GITHUB_STEP_SUMMARY"):
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as handle:
        handle.write(notes)
print(notes)
if not complete:
    raise SystemExit("Incomplete matched study; examine the archived per-cell logs")
