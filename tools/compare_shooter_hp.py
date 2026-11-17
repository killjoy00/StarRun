#!/usr/bin/env python3
"""Matched, actual-combat readout for a targeted shooter HP experiment."""
import json
import pathlib
import sys
from collections import defaultdict

def read(path):
    text = pathlib.Path(path).read_text(errors="replace").splitlines()
    data = {"densities":{},"traces":{},"matrix":[]}
    for line in text:
        for code in ("DENSITY_TRACE","CAMPAIGN_TRACE","BALANCE_MATRIX"):
            if code+" {" not in line:
                continue
            item = json.loads(line.split(code+" ",1)[1])
            if code == "BALANCE_MATRIX":
                data["matrix"].append(item)
                continue
            key = int(item["seed"])
            if code == "DENSITY_TRACE":
                data["densities"][key] = item["phases"]
            else:
                data["traces"][key] = item
    if not data["densities"] or len(data["densities"])!=len(data["traces"]) or len(data["matrix"])!=1:
        raise SystemExit(f"Missing or incomplete matched combat data: {path}")
    return data

def calc(data,pred):
    hits = 0
    samples = 0
    crowded = 0
    boss = 0
    for phases in data["densities"].values():
        for name,measure in phases.items():
            if not pred(name):
                continue
            hits += int(measure["bullet_sum"])
            samples += int(measure["samples"])
            crowded += int(measure["over_20"])
            boss += int(measure["boss_bullet_sum"])
    return dict(mean=round(hits/samples,2) if samples else None,
                crowded=round(100*crowded/samples,1) if samples else None,
                seconds=round(samples*.2,1),
                boss_owned=round(boss/samples,2) if samples else None)

def main():
    if len(sys.argv)!=4:
        raise SystemExit("Usage: compare_shooter_hp.py baseline.log challenger.log report.md")
    old,new=read(sys.argv[1]),read(sys.argv[2])
    if set(old["densities"])!=set(new["densities"]):
        raise SystemExit("Mismatched starting seeds")
    for key in ("ship","difficulty","pilot","hangar","build","route","policy","seeds"):
        if old["matrix"][0][key]!=new["matrix"][0][key]:
            raise SystemExit(f"Mismatched scenario: {key}")
    oldmat,newmat=old["matrix"][0],new["matrix"][0]
    name=f"{oldmat['ship']} / {oldmat['difficulty']} / {oldmat['hangar']} Hangar"
    cohorts={
        "All active combat":lambda x: True,
        "World 1 waves (unchanged)":lambda x:x=="W1/waves",
        "Worlds 2–4 waves":lambda x:x in ("W2/waves","W3/waves","W4/waves"),
        "Worlds 2–4 boss fights (unchanged boss stats)":lambda x:x in ("W2/boss","W3/boss","W4/boss"),
    }
    lines=[
        f"### {name}", "",
        "| Metric | Current 1.2 | Targeted shooter HP |",
        "| :-- | --: | --: |",
        f"| Full four-world wins | {oldmat['campaign_wins']}/{oldmat['seeds']} | {newmat['campaign_wins']}/{newmat['seeds']} |",
        f"| World clears W1 / W2 / W3 / W4 | {'/'.join(map(str, oldmat['world_clears']))} | {'/'.join(map(str, newmat['world_clears']))} |",
    ]
    for label,predicate in cohorts.items():
        a,b=calc(old,predicate),calc(new,predicate)
        def v(x): return "n/a" if x is None else str(x)
        lines.extend([
            f"| {label} mean visible enemy bullets | {v(a['mean'])} | {v(b['mean'])} |",
            f"| {label} % sampled frames with 20+ enemy bullets | {v(a['crowded'])} | {v(b['crowded'])} |",
            f"| {label} sample time (seconds) | {a['seconds']} | {b['seconds']} |",
        ])
    hazard=lambda run:sum(float(stage.get("damage_taken",{}).get("hazard",0))
                            for t in run["traces"].values() for stage in t["stages"]
                            if isinstance(stage.get("damage_taken"),dict))
    # Damage is stage cumulative; report stage final values rather than
    # interpreting them as escape counts (many hazards are not escapes).
    lines.extend(["",f"Total reported stage-final hazard damage (not equivalent to escape count): {hazard(old):.1f} → {hazard(new):.1f}.",
                  "All trials use real spawning, projectile collisions, draft choices and timed active inputs.",
                  "The same start seeds can produce divergent RNG after a different kill or draft offer.",
                  "Small bot samples, not human win probabilities.", ""])
    result="\n".join(lines)
    pathlib.Path(sys.argv[3]).write_text(result)
    print(result)
    print("SHOOTER_HP_ROLLUP "+json.dumps({
        "cohort":name,"baseline":{k:calc(old,v) for k,v in cohorts.items()},
        "candidate":{k:calc(new,v) for k,v in cohorts.items()},
        "before":{k:oldmat[k] for k in ("campaign_wins","world_clears","seeds")},
        "after":{k:newmat[k] for k in ("campaign_wins","world_clears","seeds")}
    },sort_keys=True))

if __name__=="__main__":
    main()
