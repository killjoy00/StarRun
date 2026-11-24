#!/usr/bin/env python3
"""Compare actual paid-core rate of fresh regular attempts across difficulties."""
import collections
import json
import pathlib
import sys

SHIPS = {"vanguard","kestrel","bulwark","wraith","arcwing","haven","lancer"}
DIFFICULTIES = {"normal","hard","insane"}
SEEDS = {810000 + (200+i+1)*7919 for i in range(4)}
rows = collections.defaultdict(list)
seen = set()
for path in sys.argv[1:]:
    rev, ship, difficulty = pathlib.Path(path).stem.split("-",2)
    key = (rev, ship, difficulty)
    if key in seen:
        raise ValueError("duplicate cell")
    seen.add(key)
    cell = []
    for line in pathlib.Path(path).read_text(errors="replace").splitlines():
        if line.startswith("CAMPAIGN_TRACE "):
            cell.append(json.loads(line.split(" ",1)[1]))
    if len(cell)!=4 or {r["seed"] for r in cell}!=SEEDS:
        raise ValueError(f"missing matched seed: {path}")
    for r in cell:
        if r["ship"]!=ship or r["difficulty"]!=difficulty or r["hangar"]!="none" or r["strategy"]!="timed" or r["build"]!="focused":
            raise ValueError(f"wrong configuration: {path}")
        if r["final"]["status"] not in ("dead","won"):
            raise ValueError(f"unsettled run: {path}")
        if difficulty!="normal" and any(s["stage"]==1 and s["status"]=="cleared" for s in r["stages"]):
            raise ValueError("advanced fresh-Hangar W1 gate failed")
    rows[(rev,difficulty)].extend(cell)
expected={(v,s,d) for v in ("control","candidate") for s in SHIPS for d in DIFFICULTIES}
if seen!=expected:
    raise ValueError(f"incomplete audit: {expected-seen}")
print("# Fresh Hangar recovery comparison")
print("168 genuine completed attempts, matched ship and seeds; focused draft, timed casts, repair policy. No combat changes before W1. Simulated time excludes menu/load overhead. Core payout from production simulation, not synthetic.")
print("| Revision | Difficulty | Attempts | Mean Cores | Cores / sim minute |")
print("|---|---|---:|---:|---:|")
rates={}
for v in ("control","candidate"):
    for d in ("normal","hard","insane"):
        rs=rows[v,d]
        paid=sum(r["final"]["cores"] for r in rs)
        seconds=sum(r["final"]["seconds"] for r in rs)
        rates[v,d]=60*paid/seconds
        print(f"| {v} | {d} | {len(rs)} | {paid/len(rs):.2f} | {rates[v,d]:.2f} |")
for d in ("hard","insane"):
    old= {(r["ship"],r["seed"]):r for r in rows["control",d]}
    for r in rows["candidate",d]:
        b=old[r["ship"],r["seed"]]
        if r["final"]["seconds"]!=b["final"]["seconds"] or r["final"]["kills"]!=b["final"]["kills"] or r["final"]["level"]!=b["final"]["level"]:
            raise ValueError("Advanced opener combat changed; not an isolated recovery comparison")
    if rates["candidate",d]>rates["candidate","normal"]:
        raise ValueError(f"{d} early failure still beats Normal Core/min in this cohort")
print("\nBoth advanced early-failure Core rates are at or below Normal in the tested cohort.")
