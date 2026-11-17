#!/usr/bin/env python3
"""Paired real-combat validation of weak ship + pilot perk changes."""
import json, pathlib, sys
PILOTS=("rookie","ace","engineer","hunter","scavenger","tactician")

def read(path):
    lines=pathlib.Path(path).read_text(errors="replace").splitlines()
    rows=[json.loads(l.split("BALANCE_MATRIX ",1)[1]) for l in lines if l.startswith("BALANCE_MATRIX ")]
    sums=[json.loads(l.split("BALANCE_MATRIX_SUMMARY ",1)[1]) for l in lines if l.startswith("BALANCE_MATRIX_SUMMARY ")]
    if len(rows)!=1 or len(sums)!=1 or sums[0]["faults"]:
        raise SystemExit(f"Incomplete Godot simulation: {path}")
    return rows[0]

def main():
    if len(sys.argv)!=6:
        raise SystemExit("Usage: report_identity_tuning.py SHIP DIFFICULTY HANGAR SEEDS REPORT")
    ship,difficulty,hangar,seeds,out=sys.argv[1:]
    lines=[f"### {ship} / {difficulty} / equal {hangar} Hangar",
           f"**{seeds} matched seeds per pilot**, naturally offered cards, same elites in both branches.",
           "",
           "| Pilot | Baseline World 1 | Tuned World 1 | Baseline World 2 | Tuned World 2 |",
           "| --- | ---: | ---: | ---: | ---: |"]
    base_total=[0,0];next_total=[0,0]
    for pilot in PILOTS:
        a=read(f"review/base-{pilot}.log"); b=read(f"review/new-{pilot}.log")
        for key in ("ship","difficulty","hangar","pilot","policy","route","build","seeds"):
            if a[key]!=b[key]:raise SystemExit(f"Unmatched {key} for {pilot}")
        for i in range(2):
            base_total[i]+=int(a["world_clears"][i])
            next_total[i]+=int(b["world_clears"][i])
        lines.append(f"| {pilot} | {a['world_clears'][0]}/{seeds} | {b['world_clears'][0]}/{seeds} | {a['world_clears'][1]}/{seeds} | {b['world_clears'][1]}/{seeds} |")
    n=int(seeds)*len(PILOTS)
    lines.extend(["",f"**Aggregate World 1:** {base_total[0]}/{n} → {next_total[0]}/{n}. **World 2:** {base_total[1]}/{n} → {next_total[1]}/{n}.",
                  "A World-1 test isolates the ship/pilot perks from new elites, which never spawn there.",
                  "These are small deterministic bot samples, not human win-rate or skill estimates.",""])
    md="\n".join(lines)
    pathlib.Path(out).write_text(md)
    print(md)
    print("IDENTITY_TUNING "+json.dumps({"ship":ship,"difficulty":difficulty,"hangar":hangar,
        "seeds":int(seeds),"before":base_total,"after":next_total},sort_keys=True))

if __name__=="__main__": main()
