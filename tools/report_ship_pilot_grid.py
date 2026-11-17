#!/usr/bin/env python3
"""Review *every* ship×pilot combination at the same Hangar investment.

Per-case Godot balance_matrix JSON is from real combat and real offered draft
cards. Short trials are an early progression screen, not full player win rates.
"""
import json
import pathlib
import sys

PILOTS = ("rookie","ace","engineer","hunter","scavenger","tactician")
def main():
    if len(sys.argv)!=5:
        raise SystemExit("Usage: report_loadout_grid.py ship difficulty hangar out.md")
    ship,difficulty,hangar,out=sys.argv[1:]
    rows=[]
    for pilot in PILOTS:
        path=pathlib.Path("review")/f"{pilot}.log"
        lines=path.read_text(errors="replace").splitlines()
        results=[json.loads(l.split("BALANCE_MATRIX ",1)[1]) for l in lines if l.startswith("BALANCE_MATRIX ")]
        summaries=[json.loads(l.split("BALANCE_MATRIX_SUMMARY ",1)[1]) for l in lines if l.startswith("BALANCE_MATRIX_SUMMARY ")]
        traces=[json.loads(l.split("CAMPAIGN_TRACE ",1)[1]) for l in lines if l.startswith("CAMPAIGN_TRACE ")]
        if len(results)!=1 or len(summaries)!=1 or summaries[0]["faults"] or len(traces)!=results[0]["seeds"]:
            raise SystemExit(f"Incomplete or invalid player/bot trials: {path}")
        r=results[0]
        if (r["ship"],r["pilot"],r["difficulty"],r["hangar"],r["policy"])!=(ship,pilot,difficulty,hangar,"timed"):
            raise SystemExit("Mismatched ship/pilot/difficulty/Hangar or active policy")
        elapsed=sum(float(t["stages"][0]["elapsed"]) for t in traces)/len(traces)
        kills=sum(int(t["final"].get("kills",0)) for t in traces)/len(traces)
        rows.append(dict(pilot=pilot,w1=int(r["world_clears"][0]),w2=int(r["world_clears"][1]),
                         wins=int(r["campaign_wins"]),seeds=int(r["seeds"]),
                         avg_w1_seconds=round(elapsed,1),avg_kills=round(kills,1),
                         mean_hull=float(r["mean_final_hull"])))
    md=[f"### {ship} / {difficulty} / equal {hangar} Hangar",
        "All six pilots on the **same ship and Hangar tier**, with identical starting seeds per pilot. Timed active-ability policy, actual upgrade offers; stage 2 limit. In-depth four-world wins are not measured here.",
        "",
        "| Pilot | World 1 clears | World 2 clears | Mean first-stage seconds | Mean kills |",
        "| --- | ---: | ---: | ---: | ---: |"]
    for row in rows:
        md.append(f"| {row['pilot']} | {row['w1']}/{row['seeds']} | {row['w2']}/{row['seeds']} | {row['avg_w1_seconds']} | {row['avg_kills']} |")
    md.extend(["",f"GRID_SUMMARY {json.dumps({'ship':ship,'difficulty':difficulty,'hangar':hangar,'pilots':rows},sort_keys=True)}", ""])
    report="\n".join(md)
    pathlib.Path(out).write_text(report)
    print(report)

if __name__=="__main__":
    main()
