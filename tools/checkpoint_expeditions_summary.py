#!/usr/bin/env python3
"""Validate checkpoint forks and actual Archive comparisons."""
import collections
import json
import pathlib
import statistics
import sys

FLEET = ("vanguard","bulwark","haven","arcwing","wraith","kestrel","lancer")
SAMPLE = ("vanguard","bulwark","haven","arcwing")
SEEDS = {810000 + (430+i+1)*7919 for i in range(8)}
POLICIES = ("timed","on_cooldown")
DESTINATIONS = ("shipyard","research","blockade","rift","pirates","graveyard","smugglers","uncharted")
GROUP = dict(zip(DESTINATIONS,("repair","repair","overclock","overclock","bounty","bounty","bounty","bounty")))
EXPECTED = {(s,h,p) for s in FLEET for h in ("p8","p32","max") for p in POLICIES}
ARCHIVE_EXPECTED = {(s,h,p) for s in SAMPLE for h in ("p32","max") for p in POLICIES}

def read(paths, suite):
    cells={}
    for path in paths:
        records=collections.defaultdict(list)
        for line in pathlib.Path(path).read_text(errors="replace").splitlines():
            key,_,value=line.partition(" ")
            if key in ("CHECKPOINT_CONFIG","CHECKPOINT_RUN","CHECKPOINT_DONE"):
                records[key].append(json.loads(value))
        configs,rows,done=(records[k] for k in ("CHECKPOINT_CONFIG","CHECKPOINT_RUN","CHECKPOINT_DONE"))
        if len(configs)!=1 or len(rows)!=8 or done!=[{"runs":8,"faults":0}]:
            raise ValueError(f"incomplete cohort {path}")
        c=configs[0]
        key=c["ship"],c["budget"],c["policy"]
        if key in cells or c["suite"]!=suite or c["offset"]!=430 or c["seeds"]!=8 or {r["seed"] for r in rows}!=SEEDS:
            raise ValueError(f"unmatched cohort {path}")
        for r in rows:
            if (r["ship"],r["budget"],r["policy"])!=key or r["suite"]!=suite or r["status"] not in ("cleared","dead","timeout"):
                raise ValueError(f"bad identity/status {path}")
            stages=r["stages"]
            if not stages or [s["stage"] for s in stages]!=list(range(1,len(stages)+1)):
                raise ValueError("incomplete history")
            if suite=="routes":
                if len(r["forks"])!=len(stages)-1:
                    raise ValueError("missing intermission fork")
                for f,next_stage in zip(r["forks"], stages[1:]):
                    variants=f["variants"]
                    hand=f["offered"]
                    if [GROUP[x] for x in hand]!=["repair","overclock","bounty"] or [v["id"] for v in variants]!=hand or f["continued"] not in hand:
                        raise ValueError("invalid real offer/choice")
                    for v in variants:
                        if v["stage"]!=f["world"] or v["destination"]!=v["id"] or v["status"] not in ("cleared","dead","timeout") or v["incremental_cores"]!=v["cores_if_claimed"]-f["start"]["cores"]:
                            raise ValueError("wrong next-world trace")
                    controls=f["controls"]
                    if [v["id"] for v in controls]!=[id for id in hand if id in ("shipyard","graveyard","smugglers","uncharted")]:
                        raise ValueError("missing actual old-route counterfactual")
                    for probe in controls:
                        if probe["route_version"]!=0 or probe["id"]!=probe["destination"] or probe["stage"]!=f["world"] or probe["status"] not in ("cleared","dead","timeout") or probe["incremental_cores"]!=probe["cores_if_claimed"]-f["start"]["cores"]:
                            raise ValueError("invalid old-route branch")
                    if any(v["route_version"]!=1 or (v["id"]=="smugglers" and v["curated_picks"]!=1 and v["status"]=="cleared") for v in variants):
                        raise ValueError("production destination or curated choice was not exercised")
                    chosen=next(v for v in variants if v["id"]==f["continued"])
                    if any(chosen[k]!=next_stage[k] for k in ("status","elapsed","level","hull","kills","destination","cores_if_claimed")):
                        raise ValueError("restored branch differs from actual continuation")
            else:
                if len(r["archives"])!=(3 if r["archive_eligible"] else 0):
                    raise ValueError("missing actual Archive entry pair")
                if r["archives"]:
                    a,b,candidate=r["archives"]
                    if r["signals"]<2 or stages[-1]["stage"]!=4 or stages[-1]["status"]!="cleared" or [a["revision"],b["revision"],candidate["revision"]]!=["control","initial","candidate"] or [a["archive_version"],b["archive_version"],candidate["archive_version"]]!=[0,3,4] or (candidate["status"]=="cleared" and candidate["remaining_emitters"]!=0) or any(x["entry_cores"]!=a["entry_cores"] or x["locked_cores"]!=a["entry_cores"] or x["stage"]!=5 or x["status"] not in ("cleared","dead","timeout") for x in (a,b,candidate)):
                        raise ValueError("invalid Archive comparison")
        cells[key]=rows
    if set(cells)!=(EXPECTED if suite=="routes" else ARCHIVE_EXPECTED):
        raise ValueError("missing expected cells")
    return [r for rows in cells.values() for r in rows]

def pct(n,d): return f"{n}/{d} ({100*n/d:.0f}%)" if d else "—"
def mean(values): 
    vs=list(values)
    return statistics.mean(vs) if vs else 0
def clear(v): return v["status"]=="cleared"
def earned(v): return v["incremental_cores"] if v["status"]!="timeout" else 0

def route_report(rows):
    entries=[(r,f,v) for r in rows for f in r["forks"] for v in f["variants"]]
    print("# Eight destinations: matched actual warp branches")
    print(f"{len(rows)} genuine launch trajectories; {len(entries)//3} real saved intermissions, {len(entries)} next-world branches. All restored continuation traces match the original trajectory. One of each offered group per hand; different seeds offer different concrete destinations. Two scripted cast policies, three Hangar budgets and alternating focused/shielded builds. Timed-out branches are distinct and unpaid. Neither conditional outcomes nor the prescribed continuation slot represent human preferences.")
    print("| Destination | Trials | Next-world clear | Low hull (<80%) | High hull | Avg levels gained | Avg incremental Cores | Cores/sim min | Timeout |")
    print("|---|---:|---:|---:|---:|---:|---:|---:|---:|")
    for id in DESTINATIONS:
        e=[(r,f,v) for r,f,v in entries if v["id"]==id]
        vs=[v for _,_,v in e]
        low=[v for _,f,v in e if f["start"]["hull_fraction"]<0.8]
        high=[v for _,f,v in e if f["start"]["hull_fraction"]>=0.8]
        rate=60*sum(map(earned,vs))/max(1,sum(v["elapsed"] for v in vs))
        print(f"| {id} | {len(vs)} | {pct(sum(map(clear,vs)),len(vs))} | {pct(sum(map(clear,low)),len(low))} | {pct(sum(map(clear,high)),len(high))} | {mean(v['level_gain'] for v in vs):.1f} | {mean(map(earned,vs)):.1f} | {rate:.1f} | {sum(v['status']=='timeout' for v in vs)} |")
    print("\nPaired wins/losses only where both options actually appeared in the same hand.")
    print("| Destination A | B | Shared checkpoints | A only clear | B only clear | Both clear | Neither | Mean A−B levels | Mean A−B Cores |")
    print("|---|---|---:|---:|---:|---:|---:|---:|---:|")
    for i,a in enumerate(DESTINATIONS):
        for b in DESTINATIONS[i+1:]:
            pairs=[]
            for r in rows:
                for f in r["forks"]:
                    d={v["id"]:v for v in f["variants"]}
                    if a in d and b in d: pairs.append((d[a],d[b]))
            if not pairs: continue
            o=collections.Counter((clear(x),clear(y)) for x,y in pairs)
            print(f"| {a} | {b} | {len(pairs)} | {o[True,False]} | {o[False,True]} | {o[True,True]} | {o[False,False]} | {mean(x['level_gain']-y['level_gain'] for x,y in pairs):+.1f} | {mean(earned(x)-earned(y) for x,y in pairs):+.1f} |")
    print("\n### Stratified checks")
    print("| Destination | Budget | Cast policy | Build | Branches | Clears | Avg end hull % | Avg incremental Cores |")
    print("|---|---|---|---|---:|---:|---:|---:|")
    groups=collections.defaultdict(list)
    for r,f,v in entries: groups[(v["id"],r["budget"],r["policy"],r["style"])].append(v)
    for (d,h,p,s),vs in sorted(groups.items()):
        print(f"| {d} | {h} | {p} | {s} | {len(vs)} | {pct(sum(map(clear,vs)),len(vs))} | {mean(100*v['hull']/max(1,v['max_hull']) for v in vs):.1f} | {mean(map(earned,vs)):.1f} |")
    print("\\n### Matched old/new destination revisions")
    print("| Destination | Cohort | Pairs | Old/new clears | Old/new exclusive clears | Old/new levels | Old/new Cores | New curated picks | Old/new end hull % |")
    print("|---|---|---:|---|---|---|---|---:|---|")
    for id in ("shipyard","graveyard","smugglers","uncharted"):
        probes=[(r,f,old,next(v for v in f["variants"] if v["id"]==id)) for r in rows for f in r["forks"] for old in f["controls"] if old["id"]==id]
        if not probes: raise ValueError("no matched probes for "+id)
        for label,ps in [("All",probes),("Original four",[x for x in probes if x[0]["seed"]<810000+(430+5)*7919]),("Additional four",[x for x in probes if x[0]["seed"]>=810000+(430+5)*7919]),("Hull below 80%",[x for x in probes if x[1]["start"]["hull_fraction"]<0.8])]+[(h,[x for x in probes if x[0]["budget"]==h]) for h in ("p8","p32","max")]:
            a=[x[2] for x in ps]; b=[x[3] for x in ps]; o=collections.Counter((clear(x),clear(y)) for x,y in zip(a,b))
            def pair(fn): return f"{mean(map(fn,a)):.1f} / {mean(map(fn,b)):.1f}"
            print(f"| {id} | {label} | {len(ps)} | {pct(sum(map(clear,a)),len(a))} / {pct(sum(map(clear,b)),len(b))} | {o[True,False]} / {o[False,True]} | {pair(lambda v:v['level_gain'])} | {pair(earned)} | {sum(v['curated_picks'] for v in b)} | {pair(lambda v:100*v['hull']/max(1,v['max_hull']))} |")
    print("\nOnly change a demonstrably redundant destination with sufficient shared checkpoints and mechanical evidence. Same-group alternatives never co-occur; comparisons across hands are observational. Low-health cells may be sparse. Payoffs include hypothetical immediate payout difference, not extra repeatable settlements. No equal-win-rate requirement.")

def archive_report(rows):
    entrants=[r for r in rows if r["archives"]]
    if not entrants: raise ValueError("no actual Archive entries")
    print("# Custodian challenge: paired real Archive entries")
    print(f"{len(rows)} actual campaigns; {len(entrants)} earned signal-qualified entries; {3*len(entrants)} real Archive fights. Identical pre-entry checkpoints and locked Cores. Legacy, previous redesigned version, and the calibrated candidate. No forced kills/signals. The timed policy responds to the candidate’s explicit late-counter cue; cooldown-only uses no special rule. Both policies retain their normal behavior for previous versions.")
    print("| Budget | Policy | Attempts | Eligible | Legacy / prior / redesigned clears | Boss seconds (clears) | Boss counters | Boss damage received | Timeouts |")
    print("|---|---|---:|---:|---|---|---|---|---|")
    for h in ("p32","max"):
        for p in POLICIES:
            rs=[r for r in rows if r["budget"]==h and r["policy"]==p]
            pairs=[r["archives"] for r in rs if r["archives"]]
            cohorts=[[x[i] for x in pairs] for i in range(3)]
            outcomes=" / ".join(pct(sum(map(clear,vs)),len(vs)) for vs in cohorts)
            secs=" / ".join(f"{mean(v['boss_seconds'] for v in vs if clear(v)):.1f}" for vs in cohorts)
            counters=" / ".join(f"{mean(v['boss_counters'] for v in vs):.1f}" for vs in cohorts)
            damage=" / ".join(f"{mean(v['boss_damage'] for v in vs):.1f}" for vs in cohorts)
            timeouts=" / ".join(str(sum(v["status"]=="timeout" for v in vs)) for vs in cohorts)
            print(f"| {h} | {p} | {len(rs)} | {len(pairs)} | {outcomes} | {secs} | {counters} | {damage} | {timeouts} |")
    o=collections.Counter((clear(r["archives"][0]),clear(r["archives"][2])) for r in entrants)
    print(f"\nPaired outcomes: old-only clears {o[True,False]}, new-only clears {o[False,True]}, both {o[True,True]}, neither {o[False,False]}.")
    print("| Ship | Budget | Policy | Old clear | New clear |")
    print("|---|---|---|---:|---:|")
    for s in SAMPLE:
        for h in ("p32","max"):
            for p in POLICIES:
                a=[r["archives"] for r in entrants if (r["ship"],r["budget"],r["policy"])==(s,h,p)]
                print(f"| {s} | {h} | {p} | {pct(sum(clear(x[0]) for x in a),len(a))} | {pct(sum(clear(x[2]) for x in a),len(a))} |")
    print("\nReview actual counter effectiveness, final-phase pressure, deaths and boss durations. Aim for roughly 60–120 simulated boss seconds for strong builds, with meaningful survival pressure and no excessive stall. Treat target as a tuning goal, not fabricated evidence. Preserve payout and entry eligibility. Do not infer human win rates.")

if __name__=="__main__":
    suite=sys.argv[1]
    rows=read(sys.argv[2:],suite)
    (route_report if suite=="routes" else archive_report)(rows)
