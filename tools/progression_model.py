#!/usr/bin/env python3
"""Estimate how many runs it takes to fill the Hangar.

Reads Hangar prices from scripts/catalog.gd and the bot's measured Cores per
run at several Hangar shares (balance_matrix --trace logs named
*-<hangar>-<ship>.log, hangar in none/p25/half/p75/max). A simulated player
starts at zero, earns the measured average payout for their current Hangar
share (linear between measured points), and always buys the cheapest next
rank. Prints runs needed to reach 25/50/75/100% of the full Hangar cost.

This models a bot that plays with near-perfect ability timing; real players
probably earn less per run, so treat the result as a lower bound.

Usage: progression_model.py <logs...> [--price-scale=1.0]
"""
import json
import math
import re
import sys

SHARE = {"none": 0.0, "p25": 0.25, "half": 0.5, "p75": 0.75, "max": 1.0}


def hangar_prices(scale: float) -> list[tuple[str, int]]:
    text = open("scripts/catalog.gd").read()
    block = text[text.index("const HANGAR"):]
    block = block[: block.index("\n]")]
    ranks = []
    for line in block.splitlines():
        if '"id"' not in line:
            continue
        field = lambda name, default=None: (lambda m: int(m.group(1)) if m else default)(re.search(r'"%s":\s*(\d+)' % name, line))
        item = re.search(r'"id":\s*"([a-z_]+)"', line).group(1)
        cost, step, top = field("cost", 0), field("step", 0), field("max", 1)
        tier_from, tier_step = field("tier_from", 0), field("tier_step", 0)
        for rank in range(top):
            base = cost + step * rank
            if tier_from and rank >= tier_from:
                base += tier_step * (rank - tier_from + 1)
            price = math.ceil(math.ceil(base * 1.15) * 1.10) if base > 0 else 0
            ranks.append((item, math.ceil(price * scale)))
    return ranks


def payouts(paths: list[str]) -> dict[float, float]:
    by_share: dict[float, list[int]] = {}
    for path in paths:
        match = re.search(r"-(none|p25|half|p75|max)-[a-z]+(?:-\d+)?\.log$", path)
        if not match:
            continue
        for line in open(path, errors="replace"):
            if line.startswith("CAMPAIGN_TRACE "):
                final = json.loads(line.split(" ", 1)[1]).get("final", {})
                if "cores" in final:
                    by_share.setdefault(SHARE[match.group(1)], []).append(final["cores"])
    return {share: sum(values) / len(values) for share, values in sorted(by_share.items())}


def interpolate(points: dict[float, float], share: float) -> float:
    keys = sorted(points)
    if share <= keys[0]:
        return points[keys[0]]
    for low, high in zip(keys, keys[1:]):
        if share <= high:
            t = (share - low) / (high - low)
            return points[low] + t * (points[high] - points[low])
    return points[keys[-1]]


def main() -> int:
    scale = 1.0
    paths = []
    for arg in sys.argv[1:]:
        if arg.startswith("--price-scale="):
            scale = float(arg.split("=", 1)[1])
        else:
            paths.append(arg)
    points = payouts(paths)
    if len(points) < 2:
        print("Need payout logs for at least two Hangar shares.")
        return 1
    # Cheapest-first order, same as the bot's partial Hangar profiles.
    by_item: dict[str, list[int]] = {}
    for item, price in hangar_prices(scale):
        by_item.setdefault(item, []).append(price)
    total = sum(sum(prices) for prices in by_item.values())
    owned = {item: 0 for item in by_item}
    spent = banked = 0.0
    runs = 0
    milestones = {0.25: None, 0.5: None, 0.75: None, 1.0: None}
    while spent < total and runs < 5000:
        runs += 1
        banked += interpolate(points, spent / total)
        while True:
            options = [(prices[owned[item]], item) for item, prices in by_item.items() if owned[item] < len(prices)]
            if not options:
                break
            price, item = min(options)
            if price > banked:
                break
            banked -= price
            spent += price
            owned[item] += 1
        for mark in milestones:
            if milestones[mark] is None and spent >= total * mark - 1e-6:
                milestones[mark] = runs
    print(f"Full Hangar: {total} Cores (price scale {scale}).")
    print("Measured Cores per run: " + ", ".join(f"{int(s * 100)}% Hangar {v:.0f}" for s, v in points.items()))
    for mark, count in milestones.items():
        print(f"- {int(mark * 100)}% of the Hangar after {count} runs")
    return 0


if __name__ == "__main__":
    sys.exit(main())
