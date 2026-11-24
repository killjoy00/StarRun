#!/usr/bin/env python3
"""Validate combined Expedition + approved Endless, without weakening #88's isolated comparison."""
import collections
import json
import pathlib
import sys

SHIPS = ("vanguard","bulwark","haven")
HANGARS = ("p32","max")
POLICIES = ("timed","on_cooldown")
SEEDS = {810000 + (310+i+1)*7919 for i in range(4)}
DESTINATIONS = {"shipyard":"repair","research":"repair","blockade":"overclock","rift":"overclock","pirates":"bounty","graveyard":"bounty","smugglers":"bounty","uncharted":"bounty"}
cells = {}
offers = collections.Counter()
choices = collections.Counter()
for path in sys.argv[1:]:
    records = collections.defaultdict(list)
    for line in pathlib.Path(path).read_text(errors="replace").splitlines():
        key, _, value = line.partition(" ")
        if key in ("EXPEDITION_DEEP_CONFIG","EXPEDITION_DEEP_RUN","EXPEDITION_DEEP_DONE"):
            records[key].append(json.loads(value))
    config, rows, done = (records[k] for k in ("EXPEDITION_DEEP_CONFIG","EXPEDITION_DEEP_RUN","EXPEDITION_DEEP_DONE"))
    if len(config)!=1 or len(rows)!=4 or done != [{"runs":4,"faults":0}]:
        raise ValueError(f"incomplete or faulty {path}")
    c = config[0]
    key = c["ship"], c["hangar"], c["strategy"]
    if key in cells or c["seeds"]!=4 or c["limit"]!=12 or c["offset"]!=310 or {r["seed"] for r in rows}!=SEEDS:
        raise ValueError(f"unmatched cohort {path}")
    for r in rows:
        if (r["ship"],r["hangar"],r["strategy"])!=key or r["status"] not in ("dead","cap","timeout"):
            raise ValueError(f"fault or identity mismatch {path}")
        stages=r["stages"]
        if [s["stage"] for s in stages]!=list(range(1,len(stages)+1)) or sum(s["status"]=="cleared" for s in stages)!=r["clears"]:
            raise ValueError("invalid combat history")
        if (r["entry_cores"]>=0)!=(r["clears"]>=4) or (r["status"]=="cap")!=(r["clears"]==12):
            raise ValueError("invalid extension entry or cap")
        if r["status"]=="timeout":
            if r["settlement"]: raise ValueError("timeout paid")
        else:
            if r["settlement"].get("finished_runs")!=1: raise ValueError("missing settlement")
            if r["entry_cores"]>=0 and r["settlement"]["earned"]<r["entry_cores"]: raise ValueError("lost earned W4 Cores")
        if len(r["destinations"])!=len(stages)-1 or len(r["mutations"])>1 or r["workshop_installs"] not in (0,1):
            raise ValueError("incomplete destinations or duplicated mutation")
        for s,d in zip(stages[1:],r["destinations"]):
            hand=d["offered"]
            chosen=d["chosen"]
            if [DESTINATIONS[id] for id in hand]!=["repair","overclock","bounty"] or chosen not in hand or d["world"]!=s["stage"] or s["destination"]!=chosen or d["group"]!=DESTINATIONS[chosen]:
                raise ValueError("unoffered or lost destination")
            offers.update(hand)
            choices.update([chosen])
    cells[key]=rows
if set(cells)!={(s,h,p) for s in SHIPS for h in HANGARS for p in POLICIES}:
    raise ValueError("missing candidate cohorts")
all_rows=[r for rows in cells.values() for r in rows]
if not any(r["clears"]>=5 for r in all_rows):
    raise ValueError("no genuine Endless continuation reached")
print("# Expedition + Endless compatibility")
print("48 real candidate attempts with new regular rules, using the same ship/seed/budget/policy design as the prior #88 study. This is a combined compatibility and behavior test, not an isolated scaling comparison. World 12 is a diagnostic claim cap; timeouts are unpaid and not deaths.")
print("| Hangar | Strategy | Attempts | W4 | W5 | W7 | W9 | W12 | Timeout | Mutation | Fusion | Engine proc |")
print("|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
for h in HANGARS:
    for p in POLICIES:
        rs=[r for s in SHIPS for r in cells[s,h,p]]
        counts=[sum(r["clears"]>=w for r in rs) for w in (4,5,7,9,12)]
        fields=[sum(r["status"]=="timeout" for r in rs),sum(bool(r["mutations"]) for r in rs),sum(bool(r["fusions"]) for r in rs),sum(any(n>0 for n in r["engine_procs"].values()) for r in rs)]
        print(f"| {h} | {p} | {len(rs)} | "+" | ".join(str(n) for n in counts+fields)+" |")
print("\n| Destination | Offered | Chosen |")
print("|---|---:|---:|")
for d in DESTINATIONS: print(f"| {d} | {offers[d]} | {choices[d]} |")
print(f"\nWorkshop installations: {sum(r['workshop_installs'] for r in all_rows)}. Actual active replacements: {sum(r['swaps'] for r in all_rows)}. No duplicated mutation or lost W4 payouts. Victory credit remains the separate #86 issue.")
