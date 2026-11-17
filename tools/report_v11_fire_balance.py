#!/usr/bin/env python3
"""Summarize two deterministic Star/Run bot-balance matrices for GitHub Actions."""
import json
import pathlib
import sys


def load(path):
    rows = {}
    for line in pathlib.Path(path).read_text(errors="replace").splitlines():
        if line.startswith("BALANCE_MATRIX "):
            row = json.loads(line.split(" ", 1)[1])
            rows[row["policy"]] = row
    return rows


def main():
    if len(sys.argv) != 4:
        raise SystemExit("Usage: report_v11_fire_balance.py BASELINE_LOG CANDIDATE_LOG OUT_MD")
    before, after = load(sys.argv[1]), load(sys.argv[2])
    missing = set(("never", "on_cooldown", "timed")) - set(before) | set(("never", "on_cooldown", "timed")) - set(after)
    if missing:
        raise SystemExit(f"Missing balance matrix policy rows: {sorted(missing)}")
    item = after["timed"]
    header = f"### {item['ship']} / {item['difficulty']} / {item['hangar']} Hangar / {item['build']} build"
    lines = [
        header,
        "",
        "| Active policy | Baseline W1–W4 clears | 1.1 W1–W4 clears | Baseline wins | 1.1 wins |",
        "| :-- | :-- | :-- | --: | --: |",
    ]
    for policy in ("never", "on_cooldown", "timed"):
        b, a = before[policy], after[policy]
        if (b["seeds"] != a["seeds"] or b["ship"] != a["ship"] or b["difficulty"] != a["difficulty"]
                or b["hangar"] != a["hangar"] or b["build"] != a["build"] or b["route"] != a["route"]):
            raise SystemExit(f"Mismatched comparison scenario {policy}")
        fmt = lambda r: "/".join(str(x) for x in r["world_clears"])
        lines.append(f"| {policy} | {fmt(b)} | {fmt(a)} | {b['campaign_wins']}/{b['seeds']} | {a['campaign_wins']}/{a['seeds']} |")
    lines += [
        "",
        f"Matched seed starts per policy: **{item['seeds']}**; scripted autopilot, real combat, real offered cards.",
        "This is a screening comparison; combat RNG and subsequent draft offers can diverge after the first differing kill.",
        "",
    ]
    text = "\n".join(lines)
    pathlib.Path(sys.argv[3]).write_text(text)
    print(text)


if __name__ == "__main__":
    main()
