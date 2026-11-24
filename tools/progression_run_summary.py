#!/usr/bin/env python3
"""Summarize complete real-campaign progression logs; fail on missing/invalid cohorts."""
import json
import pathlib
import sys


def load(path):
    groups = {"CONFIG": [], "RUN": [], "SUMMARY": []}
    for line in path.read_text(errors="replace").splitlines():
        for key, values in groups.items():
            prefix = f"PROGRESSION_{key} "
            if line.startswith(prefix):
                values.append(json.loads(line[len(prefix):]))
    configs, rows, summaries = (groups[k] for k in ("CONFIG", "RUN", "SUMMARY"))
    if len(configs) != 1 or len(summaries) != 1:
        raise ValueError(f"{path}: expected exactly one config and summary")
    config, summary = configs[0], summaries[0]
    if len(rows) != config["runs"] or [r["run"] for r in rows] != list(range(1, len(rows)+1)):
        raise ValueError(f"{path}: incomplete or unordered progression")
    if any(r["cores_earned_total"] != r["cores_spent_total"] + r["cores_banked"] for r in rows):
        raise ValueError(f"{path}: invalid Core ledger")
    if sum(bool(r["won"]) for r in rows) != summary["wins"]:
        raise ValueError(f"{path}: win-count mismatch")
    return config, rows, summary


def mark(value):
    return str(value) if value else "not reached"


def main():
    files = sorted(pathlib.Path(p) for p in sys.argv[1:])
    if not files:
        raise ValueError("No progression logs")
    print("# Star/Run persistent progression")
    print("Actual seeded campaigns; Vanguard/Vale, Normal, regular full runs, cheapest affordable Hangar rank first. No Daily, ads, purchased loadouts, later starts or real-player learning. Abilities are cast on cooldown to hold combat behavior constant. This is a meta-progression diagnostic, not a human win rate.")
    print("\n| Revision / active policy | First W1 | First W2 | First W3 | First win | Wins | Hangar ranks | Hangar cost | Longest no-purchase streak | Combat min |")
    print("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    results = {}
    for path in files:
        config, rows, summary = load(path)
        label = path.stem
        results[label] = (config, rows, summary)
        first = " | ".join(mark(v) for v in summary["first_clears"])
        print(f"| {label} | {first} | {summary['wins']}/{summary['runs']} | {summary['rank_pct']:.1f}% | {summary['cost_pct']:.1f}% | {summary['max_no_purchase_streak']} | {summary['combat_minutes']:.0f} |")
    print("\n## Progress checkpoints")
    print("| Cohort | Run | Wins to date | Cores earned | Ranks owned | Cost share | New unlocks to date |")
    print("|---|---:|---:|---:|---:|---:|---|")
    for label, (config, rows, summary) in results.items():
        for n in sorted(set([min(len(rows), x) for x in (1, 5, 10, 20, 30, 40, 50)] + [len(rows)])):
            r = rows[n-1]
            unlocks = ", ".join(dict.fromkeys(u for x in rows[:n] for u in x["unlocked"])) or "—"
            wins = sum(bool(x["won"]) for x in rows[:n])
            print(f"| {label} | {n} | {wins} | {r['cores_earned_total']} | {r['ranks_owned']}/{config['hangar_ranks']} | {r['cost_pct']:.1f}% | {unlocks} |")
    print("\n## Matched before/after")
    print("| Active policy | First-win run (old → new) | Run-50 wins (old → new) | Hangar cost share (old → new) | No-purchase streak (old → new) |")
    print("|---|---|---|---|---|")
    for label, (config, rows, new) in results.items():
        if not label.startswith("candidate-"):
            continue
        control = results.get("control-" + label.removeprefix("candidate-"))
        if not control:
            continue
        old_config, old_rows, old = control
        if [x["seed"] for x in rows] != [x["seed"] for x in old_rows]:
            raise ValueError(f"{label}: control seeds differ")
        print(f"| {config['strategy']} | {mark(old['first_win'])} → {mark(new['first_win'])} | {old['wins']} → {new['wins']} | {old['cost_pct']:.1f}% → {new['cost_pct']:.1f}% | {old['max_no_purchase_streak']} → {new['max_no_purchase_streak']} |")


if __name__ == "__main__":
    main()
