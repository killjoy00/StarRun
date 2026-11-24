#!/usr/bin/env python3
"""Validate paired deep Endless experiments without treating cap as defeat."""
import collections
import json
import pathlib
import statistics
import sys

SHIPS = ("vanguard", "bulwark", "haven")
HANGARS = ("p32", "max")
POLICIES = ("timed", "on_cooldown")
REVISIONS = ("control", "candidate")
SEEDS = {810000 + (310 + i + 1) * 7919 for i in range(4)}

def load(paths):
    cohorts = {}
    for path in paths:
        config, rows, done = [], [], []
        revision = pathlib.Path(path).name.split("-", 1)[0]
        for line in pathlib.Path(path).read_text(errors="replace").splitlines():
            if line.startswith("DEEP_CONFIG "): config.append(json.loads(line.split(" ",1)[1]))
            elif line.startswith("DEEP_RUN "): rows.append(json.loads(line.split(" ",1)[1]))
            elif line.startswith("DEEP_DONE "): done.append(json.loads(line.split(" ",1)[1]))
        if len(config)!=1 or len(done)!=1 or len(rows)!=4 or done[0]!={"runs":4,"faults":0}:
            raise ValueError(f"Incomplete or failed {path}")
        c=config[0]
        key=(revision,c["ship"],c["hangar"],c["strategy"])
        if key in cohorts or c["limit"]!=12 or c["offset"]!=310 or c["seeds"]!=4 or {r["seed"] for r in rows}!=SEEDS:
            raise ValueError(f"Unmatched cohort {path}")
        for r in rows:
            if (r["ship"],r["hangar"],r["strategy"])!=key[1:] or r["status"] not in ("dead","cap","timeout"):
                raise ValueError(f"Bad run {path}")
            stages=r["stages"]
            if not stages or [s["stage"] for s in stages]!=list(range(1,len(stages)+1)):
                raise ValueError("Missing stage history")
            if sum(s["status"]=="cleared" for s in stages)!=r["clears"]:
                raise ValueError("Invalid world clear count")
            if r["status"]=="cap" and r["clears"]!=12:
                raise ValueError("Invalid capped campaign")
            if r["status"]=="timeout" and r["settlement"]:
                raise ValueError("Timeout was paid")
            if r["status"]!="timeout" and r["settlement"].get("finished_runs")!=1:
                raise ValueError("Invalid settlement")
            if (r["entry_cores"]>=0)!=(r["clears"]>=4):
                raise ValueError("Incorrect Endless entry")
        cohorts[key]={r["seed"]:r for r in rows}
    expected={(v,s,h,p) for v in REVISIONS for s in SHIPS for h in HANGARS for p in POLICIES}
    if set(cohorts)!=expected: raise ValueError(f"Missing cohorts {expected-set(cohorts)}")
    for _,ship,hangar,policy in sorted(k for k in expected if k[0]=="control"):
        control=cohorts[("control",ship,hangar,policy)]
        candidate=cohorts[("candidate",ship,hangar,policy)]
        for seed in SEEDS:
            a,b=control[seed],candidate[seed]
            pre=lambda r:[s for s in r["stages"] if s["stage"]<=4]
            if pre(a)!=pre(b) or a["entry_cores"]!=b["entry_cores"]:
                raise ValueError(f"Regular campaign changed: {ship}/{hangar}/{policy}/{seed}")
    return cohorts

def ratio(n,d):
    return f"{n}/{d} ({100*n/d:.0f}%)" if d else "—"

def mean(values):
    values=list(values)
    return statistics.mean(values) if values else 0

def main():
    cohorts=load(sys.argv[1:])
    print("# Endless escalation — matched real-flight report")
    print("96 attempts: 3 ships × 2 Hangar levels × 2 cast policies × 4 held-out seeds × 2 revisions. All W1–W4 traces and entry payouts match exactly. World 12 is a diagnostic claim cap, not a defeat. A 900-second world timeout is distinct and unpaid. Small cohorts are directional; no human win-rate claim.")
    print("\n| Revision | Hangar | Policy | W4 clears | W5 | W6 | W7 | W8 | W9 | W10 | W11 | W12 | Median extra worlds cleared | Timeouts |")
    print("|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    for h in HANGARS:
        for p in POLICIES:
            for v in REVISIONS:
                rows=[r for s in SHIPS for r in cohorts[(v,s,h,p)].values()]
                entrants=[r for r in rows if r["entry_cores"]>=0]
                cells=[ratio(len(entrants),len(rows))]+[ratio(sum(r["clears"]>=w for r in entrants),len(entrants)) for w in range(5,13)]
                median=statistics.median([r["clears"]-4 for r in entrants]) if entrants else "—"
                print(f"| {v} | {h} | {p} | "+" | ".join(cells)+f" | {median} | {sum(r['status']=='timeout' for r in rows)} |")
    print("\n| Hangar | Policy | Paired entrants | Candidate shallower | Same depth | Candidate deeper | Mean extra depth (old → new) | Mean incremental paid Cores (old → new) |")
    print("|---|---|---:|---:|---:|---:|---:|---:|")
    for h in HANGARS:
        for p in POLICIES:
            pairs=[(cohorts[("control",s,h,p)][seed],cohorts[("candidate",s,h,p)][seed]) for s in SHIPS for seed in sorted(SEEDS) if cohorts[("control",s,h,p)][seed]["entry_cores"]>=0]
            lower=sum(b["clears"]<a["clears"] for a,b in pairs)
            higher=sum(b["clears"]>a["clears"] for a,b in pairs)
            both_paid=[(a,b) for a,b in pairs if a["settlement"] and b["settlement"]]
            da,db=(mean(pair[i]["clears"]-4 for pair in pairs) for i in (0,1))
            ca,cb=(mean(pair[i]["settlement"]["earned"]-pair[i]["entry_cores"] for pair in both_paid) for i in (0,1))
            print(f"| {h} | {p} | {len(pairs)} | {lower} | {len(pairs)-lower-higher} | {higher} | {da:.2f} → {db:.2f} | {ca:.1f} → {cb:.1f} |")
    print("\nActual endgame settlement (the existing #86 victory-credit concern is reported, not silently changed here).")
    print("| Revision | Settled Endless deaths | Missing W4 victory credit | Lost W4 payout |")
    print("|---|---:|---:|---:|")
    for v in REVISIONS:
        rows=[r for key,cell in cohorts.items() if key[0]==v for r in cell.values() if r["entry_cores"]>=0 and r["settlement"]]
        deaths=[r for r in rows if r["status"]=="dead"]
        print(f"| {v} | {len(deaths)} | {sum(r['settlement']['victories']==0 for r in deaths)} | {sum(r['settlement']['earned']<r['entry_cores'] for r in rows)} |")
    print("\nReview depth, cap/timeout rates, and first Endless-world accessibility before merging. The existing regular campaign and archive are not retuned.")

if __name__=="__main__": main()
