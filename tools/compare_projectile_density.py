#!/usr/bin/env python3
"""Time-weighted on-screen enemy projectile occupancy from actual Godot fights.

Three different gameplay versions execute the identical instrumented diagnostic
script. Each log contains matched seeds and per-world wave/boss phase samples.
These are deterministic bot simulations, not live-user analytics.
"""
import json
import pathlib
import sys
from collections import defaultdict

METRICS = ("samples", "bullet_sum", "boss_bullet_sum", "charge_sum", "max_visible", "over_20", "over_40")
SUMMED = {"samples", "bullet_sum", "boss_bullet_sum", "charge_sum", "over_20", "over_40"}

def load(path):
    rows = {}
    lines = pathlib.Path(path).read_text(errors="replace").splitlines()
    for line in lines:
        if "DENSITY_TRACE " not in line:
            continue
        entry = json.loads(line.split("DENSITY_TRACE ", 1)[1])
        key = (entry["seed"], entry["ship"], entry["difficulty"],
               entry["hangar"], entry["build"], entry["route"], entry["strategy"])
        if key in rows:
            raise SystemExit(f"Duplicate seed {key} in {path}")
        rows[key] = entry["phases"]
    if not rows or not any(sum(v["samples"] for v in phases.values()) > 0 for phases in rows.values()):
        raise SystemExit(f"No genuine projectile occupancy samples in {path}")
    return rows

def empty():
    return dict.fromkeys(METRICS, 0)

def aggregate(rows, predicate):
    counts = empty()
    for phases in rows.values():
        for phase, value in phases.items():
            if not predicate(phase):
                continue
            for k in SUMMED:
                counts[k] += int(value[k])
            counts["max_visible"] = max(counts["max_visible"], int(value["max_visible"]))
    return counts

def metric(counts):
    n = counts["samples"]
    return {
        "mean_visible":round(counts["bullet_sum"]/n,2) if n else None,
        "mean_boss_owned":round(counts["boss_bullet_sum"]/n,2) if n else None,
        "mean_charge_lanes":round(counts["charge_sum"]/n,2) if n else None,
        "pct_over_20":round(100*counts["over_20"]/n,1) if n else None,
        "pct_over_40":round(100*counts["over_40"]/n,1) if n else None,
        "sampled_peak":counts["max_visible"] if n else None,
        "seconds_sampled":round(n*0.2,1),
    }

def str_num(v):
    return "n/a" if v is None else str(v)

def main():
    if len(sys.argv) != 5:
        raise SystemExit("Usage: compare_density.py pre11.log v11.log v12.log output.md")
    versions = ("pre-1.1", "1.1", "1.2")
    loaded = {ver:load(path) for ver,path in zip(versions,sys.argv[1:4])}
    all_keys = list(loaded.values())[0].keys()
    if any(set(rows) != set(all_keys) for rows in list(loaded.values())[1:]):
        raise SystemExit("Unmatched simulation starting seeds across versions")
    patterns = {
        "All combat":lambda k:True,
        "Enemy waves":lambda k:k.endswith("/waves"),
        "Boss fights":lambda k:k.endswith("/boss"),
    }
    for stage in range(1,5):
        patterns[f"World {stage} waves"]=lambda k,i=stage:k==f"W{i}/waves"
        patterns[f"World {stage} boss"]=lambda k,i=stage:k==f"W{i}/boss"
    metrics = {label:{ver:metric(aggregate(rows,pred)) for ver,rows in loaded.items()} for label,pred in patterns.items()}
    cols = ["Phase","Pre-1.1 mean","1.1 mean","1.2 mean","Change pre-1.1 → 1.2"]
    lines=[
        "# Star/Run on-screen enemy projectile density — matched bot runs",
        "",
        f"Each version has **{len(all_keys)} identical starting seed/scenario pairs**.",
        "Godot samples enemy bullet positions **inside the actual 540×960 playfield** every 0.2s of active, unpaused gameplay. Charged heavy-beam warning lanes are tracked separately and are **not** counted as bullets. Friendly shots are excluded.",
        "For each phase the average is weighted by seconds spent in that phase. Different progression, deaths and ability use can change which worlds/fight phases are sampled; read the sample times below before generalizing.",
        "",
        "| "+" | ".join(cols)+" |",
        "| "+" | ".join(["---"]+["---:"]*(len(cols)-1))+" |",
    ]
    for label, versions_metrics in metrics.items():
        a,b,c=[versions_metrics[v]["mean_visible"] for v in versions]
        delta = (f"{(c/a-1)*100:+.1f}%" if a is not None and a>0 and c is not None else "n/a")
        lines.append(f"| {label} | {str_num(a)} | {str_num(b)} | {str_num(c)} | {delta} |")
    lines += ["", "## Per-phase sample time (simulated seconds)", "",
              "| Phase | Pre-1.1 | 1.1 | 1.2 |","| --- | ---: | ---: | ---: |"]
    for label, ver_metrics in metrics.items():
        lines.append("| "+label+" | "+" | ".join(str(ver_metrics[v]["seconds_sampled"]) for v in versions)+" |")
    lines += ["", "## Crowd pressure and boss-only projectiles", "",
              "| Measure | Pre-1.1 | 1.1 | 1.2 |", "| --- | ---: | ---: | ---: |"]
    for phase, metric_name, label in [
        ("All combat","pct_over_20","Combat time with 20+ enemy bullets on screen (%)"),
        ("All combat","pct_over_40","Combat time with 40+ enemy bullets on screen (%)"),
        ("All combat","sampled_peak","Largest observed on-screen bullet count"),
        ("Boss fights","mean_visible","Mean all enemy bullets during boss fights"),
        ("Boss fights","mean_boss_owned","Mean bullets fired by bosses during boss fights"),
        ("Boss fights","mean_charge_lanes","Mean charging heavy-beam lanes during boss fights"),
    ]:
        lines.append("| "+label+" | "+" | ".join(str_num(metrics[phase][v][metric_name]) for v in versions)+" |")
    # Balance-diagnostic limitations and per-case population must be visible.
    lines += ["", "## Cohorts actually sampled", "",
              "Scenarios: "+", ".join(sorted({f"{k[1]} {k[2]} {k[3]} Hangar" for k in all_keys}))+".",
              "No spawned enemies, draft cards, boss kills or RNG have been injected.",
              "Combat and draft RNG may diverge between versions after a kill.",
              "**These are bot runs, not human player telemetry or a render-time frame counter.**",
              ""]
    pathlib.Path(sys.argv[4]).write_text("\n".join(lines))
    print("\n".join(lines))
    print("DENSITY_ROLLUP "+json.dumps({"versions":versions,"scenarios":len(all_keys),"metrics":metrics},sort_keys=True))

if __name__ == "__main__":
    main()
