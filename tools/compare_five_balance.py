#!/usr/bin/env python3
"""Compare real-combat Star/Run balance logs; never fabricate a win-rate target."""
import json
import pathlib
import sys


def read(path):
    lines = pathlib.Path(path).read_text(errors="replace").splitlines()
    rows = [json.loads(line.split("BALANCE_MATRIX ", 1)[1])
            for line in lines if line.startswith("BALANCE_MATRIX ")]
    summary = [json.loads(line.split("BALANCE_MATRIX_SUMMARY ", 1)[1])
               for line in lines if line.startswith("BALANCE_MATRIX_SUMMARY ")]
    if len(rows) != 1 or len(summary) != 1 or summary[0]["faults"]:
        raise SystemExit(f"Missing, duplicated, or failed real campaign result: {path}")
    return rows[0], summary[0]


def main():
    if len(sys.argv) != 4:
        raise SystemExit("Usage: compare_five_balance.py baseline.log candidate.log output.md")
    baseline, baseline_summary = read(sys.argv[1])
    candidate, candidate_summary = read(sys.argv[2])
    for key in ("ship", "difficulty", "policy", "build", "hangar", "route", "pilot", "seeds"):
        if baseline[key] != candidate[key]:
            raise SystemExit(f"Unmatched scenario {key}: {baseline[key]} != {candidate[key]}")
    if baseline_summary["trials"] != candidate_summary["trials"]:
        raise SystemExit("Mismatch in trial count")
    count = baseline["seeds"]
    route = baseline["route"]
    title = (f"{baseline['ship']} / {baseline['difficulty']} / "
             f"{baseline['hangar']} Hangar / {baseline['build']} build / "
             f"{baseline['policy']} actives / route {route}")
    details = [
        f"### {title}",
        "",
        "| Metric | 1.1 baseline | Five-part challenger |",
        "| :-- | --: | --: |",
        f"| Four-world victories | {baseline['campaign_wins']}/{count} | {candidate['campaign_wins']}/{count} |",
        f"| Clears W1 / W2 / W3 / W4 | {' / '.join(map(str, baseline['world_clears']))} | {' / '.join(map(str, candidate['world_clears']))} |",
    ]
    for field, label in [
        ("mean_cleared_boss_seconds", "Mean cleared-boss fight seconds"),
        ("overlap_seconds", "Total overlapping warning seconds"),
        ("unanswered_overlap_seconds", "Warning seconds without ready counter"),
        ("shieldstorm_runs", "Runs ending with Shieldstorm"),
    ]:
        if field in baseline and field in candidate:
            details.append(f"| {label} | {baseline[field]} | {candidate[field]} |")
    details += [
        "",
        f"**Matched starting seeds:** {count}. Gameplay RNG can diverge after different combat outcomes.",
        "These are scripted bots choosing real offered upgrades and using the game's real combat;",
        "they are not human playtest win rates. Boss means include only stages whose boss was defeated.",
        "",
    ]
    rendered = "\n".join(details)
    pathlib.Path(sys.argv[3]).write_text(rendered)
    print(rendered)


if __name__ == "__main__":
    main()
