#!/usr/bin/env python3
"""Summarise balance_matrix --trace --density logs against the difficulty targets.

Targets (Normal, full campaign):
  no Hangar   never finishes the campaign
  half Hangar wins 40-60% (half the Cores of a full Hangar)
  max Hangar  wins most runs (70%+)

Usage: difficulty_summary.py <log> [<log> ...]
Log names must end in -<hangar>-<ship>[-<chunk>].log.
"""
import collections
import json
import re
import sys

TARGETS = {"none": (0.0, 0.0), "half": (0.40, 0.60), "max": (0.70, 1.0)}


def main() -> int:
    wins = collections.Counter()
    runs = collections.Counter()
    per_ship = collections.defaultdict(lambda: [0, 0])
    density = collections.defaultdict(lambda: collections.defaultdict(lambda: [0.0, 0.0]))
    tuning = ""
    # Per world: runs that entered it and runs that cleared it, per Hangar level.
    entered = collections.defaultdict(lambda: [0, 0, 0, 0])
    cleared = collections.defaultdict(lambda: [0, 0, 0, 0])
    difficulty = "normal"
    for path in sys.argv[1:]:
        match = re.search(r"-(none|half|max|mid)-([a-z]+)(?:-\d+)?\.log$", path)
        if not match:
            continue
        hangar, ship = match.group(1), match.group(2)
        for line in open(path, errors="replace"):
            if line.startswith("BALANCE_MATRIX ") and '"difficulty"' in line:
                difficulty = json.loads(line.split(" ", 1)[1]).get("difficulty", difficulty)
            if line.startswith("WORLD_TUNING "):
                tuning = line.split(" ", 1)[1].strip()
            elif line.startswith("CAMPAIGN_TRACE "):
                trace = json.loads(line.split(" ", 1)[1])
                stages = trace["stages"]
                won = len(stages) == 4 and all(s["status"] == "cleared" for s in stages)
                for index, stage in enumerate(stages[:4]):
                    entered[hangar][index] += 1
                    cleared[hangar][index] += int(stage["status"] == "cleared")
                wins[hangar] += int(won)
                runs[hangar] += 1
                per_ship[(hangar, ship)][0] += int(won)
                per_ship[(hangar, ship)][1] += 1
            elif line.startswith("DENSITY_TRACE "):
                trace = json.loads(line.split(" ", 1)[1])
                for phase, stats in trace["phases"].items():
                    world, _, part = phase.partition("/")
                    if part in ("waves", "mid", "opening"):
                        density[hangar][world][0] += stats["enemy_sum"]
                        density[hangar][world][1] += stats["samples"]
    print(f"Difficulty: {difficulty}. World tuning: {tuning or 'none (current game values)'}\n")
    print("| Hangar | Wins | Target | Per ship | Enemies on screen (W1/W2/W3/W4) |")
    print("|---|---|---|---|---|")
    ok = True
    for hangar in ("none", "half", "max", "mid"):
        if not runs[hangar]:
            continue
        rate = wins[hangar] / runs[hangar]
        low, high = TARGETS.get(hangar, (0.0, 1.0))
        hit = low <= rate <= high
        ok = ok and hit
        ships = ", ".join(f"{ship} {w}/{n}" for (h, ship), (w, n) in sorted(per_ship.items()) if h == hangar)
        worlds = " / ".join(
            f"{density[hangar][w][0] / density[hangar][w][1]:.1f}" if density[hangar][w][1] else "-"
            for w in ("W1", "W2", "W3", "W4")
        )
        target = "never" if hangar == "none" else (f"{low:.0%}-{high:.0%}" if hangar in TARGETS else "-")
        print(f"| {hangar} | {wins[hangar]}/{runs[hangar]} ({rate:.0%}) {'OK' if hit else 'MISS'} | {target} | {ships} | {worlds} |")
    print("\nDeaths per world: share of runs that reached a world and died in it.")
    print("Even progression means similar numbers in each world.\n")
    print("| Hangar | W1 | W2 | W3 | W4 |")
    print("|---|---|---|---|---|")
    for hangar in ("none", "half", "max", "mid"):
        if not runs[hangar]:
            continue
        cells = []
        for index in range(4):
            n_in = entered[hangar][index]
            cells.append(f"{(n_in - cleared[hangar][index]) / n_in:.0%} of {n_in}" if n_in else "-")
        print(f"| {hangar} | " + " | ".join(cells) + " |")
    print("\nAll targets met." if ok else "\nTargets missed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
