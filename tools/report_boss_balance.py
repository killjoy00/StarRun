#!/usr/bin/env python3
"""Report actual boss durations and campaign results for matched Star/Run seeds.

No forced kills, fabricated upgrades or human win-rate estimates. Combat RNG
can diverge between baseline and challenger after the first gameplay change.
"""
import json
import pathlib
import sys


def load(path):
    data = pathlib.Path(path).read_text(errors="replace").splitlines()
    rows = [json.loads(line.split("BALANCE_MATRIX ", 1)[1])
            for line in data if line.startswith("BALANCE_MATRIX ")]
    trials = [json.loads(line.split("CAMPAIGN_TRACE ", 1)[1])
              for line in data if line.startswith("CAMPAIGN_TRACE ")]
    summaries = [json.loads(line.split("BALANCE_MATRIX_SUMMARY ", 1)[1])
                 for line in data if line.startswith("BALANCE_MATRIX_SUMMARY ")]
    if len(rows) != 1 or len(summaries) != 1 or summaries[0]["faults"] or len(trials) != rows[0]["seeds"]:
        raise SystemExit(f"Invalid or incomplete bot simulation at {path}")
    bosses = {}
    for stage in range(1, 5):
        seconds = [float(t["boss_seconds"]) for trial in trials
                   for t in trial["stages"]
                   if int(t["stage"]) == stage and t["status"] == "cleared"
                   and t.get("boss_spawned", False)]
        bosses[stage] = seconds
    return rows[0], bosses, trials


def avg(numbers):
    return round(sum(numbers) / len(numbers), 1) if numbers else None


def fmt(n):
    return "—" if n is None else f"{n:.1f}s"


def main():
    if len(sys.argv) != 4:
        raise SystemExit("Usage: report_boss_balance.py BEFORE.log AFTER.log REPORT.md")
    before, before_bosses, before_trials = load(sys.argv[1])
    after, after_bosses, after_trials = load(sys.argv[2])
    for key in ("ship", "difficulty", "policy", "hangar", "build", "route", "pilot", "seeds"):
        if before[key] != after[key]:
            raise SystemExit(f"Unmatched {key}: {before[key]} vs {after[key]}")
    lines = [
        f"### {before['ship']} / {before['difficulty']} / {before['hangar']} Hangar / {before['build']} build / {before['route']} route",
        "",
        "| Real bot result | 1.1 baseline | 1.2 challenger |",
        "| :-- | --: | --: |",
        f"| Full campaign wins | {before['campaign_wins']}/{before['seeds']} | {after['campaign_wins']}/{after['seeds']} |",
        f"| World clears W1/W2/W3/W4 | {'/'.join(map(str, before['world_clears']))} | {'/'.join(map(str, after['world_clears']))} |",
    ]
    for stage in range(1, 5):
        b, a = before_bosses[stage], after_bosses[stage]
        lines.append(f"| World {stage} defeated-boss time ({len(b)}→{len(a)} clears) | {fmt(avg(b))} | {fmt(avg(a))} |")
    lines += [
        "",
        f"{before['seeds']} identical starting seeds. Only *defeated* bosses enter the fight-time averages.",
        "A failed or unfinished boss is shown in the world-clear count rather than averaged as a zero-second kill.",
        "Combat and draft RNG can diverge; these are scripted autopilot screening results, **not human win rates**.",
        "",
    ]
    out = "\n".join(lines)
    pathlib.Path(sys.argv[3]).write_text(out)
    print(out)


if __name__ == "__main__":
    main()
