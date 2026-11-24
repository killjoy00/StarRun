#!/usr/bin/env python3
"""Strict audit report for opt-in, matched-seed real-engine campaign traces."""
import collections
import json
import pathlib
import statistics
import sys

FLEET = {"vanguard", "kestrel", "bulwark", "wraith", "arcwing", "haven", "lancer"}
SAMPLE = {"vanguard", "bulwark", "haven"}
EXPECTED = {
    "build": ["baseline", "focused", "shielded", "focused_alt", "engine"],
    "route": ["repair", "overclock", "bounty", "adaptive"],
    "difficulty": [f"{d}-p{p}" for d in ("normal", "hard", "insane") for p in (0, 32, 100)],
    "economy": ["spread", "weapons", "hull", "abilities", "salvage", "tools", "spread-no-tools"],
    "endgame": ["finish", "endless", "archive"],
}
EXPECTED_SEEDS = {810000 + (200 + i + 1) * 7919 for i in range(4)}

def read(paths):
    groups = collections.defaultdict(list)
    prices = {}
    seen = set()
    for path in paths:
        config, done, rows = [], [], []
        for line in pathlib.Path(path).read_text(errors="replace").splitlines():
            if line.startswith("AUDIT_CONFIG "): config.append(json.loads(line.split(" ", 1)[1]))
            elif line.startswith("AUDIT_RUN "): rows.append(json.loads(line.split(" ", 1)[1]))
            elif line.startswith("AUDIT_DONE "): done.append(json.loads(line.split(" ", 1)[1]))
            elif line.startswith("AUDIT_PRICE "):
                item = json.loads(line.split(" ", 1)[1])
                if item["id"] in prices and prices[item["id"]] != item:
                    raise ValueError("Inconsistent production prices")
                prices[item["id"]] = item
        if len(config) != 1 or len(done) != 1:
            raise ValueError(f"{path}: incomplete audit")
        c, d = config[0], done[0]
        suite, ship = c["suite"], c["ship"]
        if (suite, ship) in seen or suite not in EXPECTED or c["labels"] != EXPECTED[suite]:
            raise ValueError(f"{path}: duplicate or unexpected cohort")
        if c["seeds"] != 4 or c["offset"] != 200 or d["suite"] != suite or d["ship"] != ship or d["faults"] or d["runs"] != len(rows):
            raise ValueError(f"{path}: invalid config or simulation fault")
        seen.add((suite, ship))
        for label in EXPECTED[suite]:
            cell = [r for r in rows if r["label"] == label]
            if len(cell) != 4 or {r["seed"] for r in cell} != EXPECTED_SEEDS:
                raise ValueError(f"{path}: missing matched seed for {label}")
        if len(rows) != 4 * len(EXPECTED[suite]):
            raise ValueError(f"{path}: unexpected row count")
        for r in rows:
            if r["suite"] != suite or r["ship"] != ship or r["status"] not in ("won", "dead", "timeout"):
                raise ValueError(f"{path}: bad run identity or fault")
            if r["status"] in ("won", "dead"):
                s = r["settlement"]
                if s["earned"] != r["cores_if_claimed"] or s["finished_runs"] != 1 or r["won"] != (r["status"] == "won"):
                    raise ValueError(f"{path}: invalid actual settlement")
            elif r["settlement"]:
                raise ValueError(f"{path}: timeout must not be settled")
            if len({s["stage"] for s in r["stages"]}) != len(r["stages"]):
                raise ValueError(f"{path}: duplicate world trace")
            groups[(suite, r["label"])].append(r)
    expected = {(suite, ship) for suite in EXPECTED for ship in (SAMPLE if suite in ("economy", "endgame") else FLEET)}
    if seen != expected or len(prices) != 44 or sum(len(i["prices"]) for i in prices.values()) != 214:
        raise ValueError(f"Incomplete fleet or price audit: missing {expected-seen}; prices {len(prices)}")
    # All paired endgame/route policies must behave identically before
    # the decision they compare. Compare actual first world and entry payout.
    for suite, stage_limit in (("route", 1), ("endgame", 4)):
        for label in EXPECTED[suite][1:]:
            base = index(groups[(suite, EXPECTED[suite][0])])
            for r in groups[(suite, label)]:
                b = base[(r["ship"], r["seed"])]
                pre = lambda x: [s for s in x["stages"] if s["stage"] <= stage_limit]
                if pre(r) != pre(b):
                    raise ValueError(f"{suite}: pre-decision mismatch {label} {r['ship']} {r['seed']}")
    return groups, prices

def index(rows):
    return {(r["ship"], r["seed"]): r for r in rows}

def pct(n, d):
    return f"{100*n/d:.1f}%" if d else "—"

def mean(values):
    values = list(values)
    return statistics.mean(values) if values else 0.0

def settled_cores(r):
    return r["settlement"].get("earned", 0)

def cores_min(rows):
    seconds = sum(r["seconds"] for r in rows)
    return 60 * sum(map(settled_cores, rows)) / seconds if seconds else 0.0

def world(rows, number):
    records = [s for r in rows for s in r["stages"] if s["stage"] == number]
    cleared = sum(s["status"] == "cleared" for s in records)
    return f"{cleared}/{len(records)} ({pct(cleared,len(records))})" if records else "—"

def common_table(groups, suite):
    print("| Cohort | Attempts | W1 clear | W2 clear | W3 clear | W4 clear | Timeout | Avg paid Cores/attempt | Cores/sim min |")
    print("|---|---:|---:|---:|---:|---:|---:|---:|---:|")
    for label in EXPECTED[suite]:
        rows = groups[(suite,label)]
        print(f"| {label} | {len(rows)} | " + " | ".join(world(rows, w) for w in range(1,5)) + f" | {sum(r['status']=='timeout' for r in rows)} | {mean(map(settled_cores,rows)):.1f} | {cores_min(rows):.2f} |")

def paired(groups, suite, baseline):
    base = index(groups[(suite,baseline)])
    print(f"\nMatched W4 outcomes versus {baseline} (same ship and seed; success = cleared W4, not claim status).")
    print("| Comparison | Both clear | Candidate only | Baseline only | Neither |")
    print("|---|---:|---:|---:|---:|")
    for label in EXPECTED[suite]:
        if label == baseline: continue
        outcomes = collections.Counter((base[(r["ship"],r["seed"])]["clears"]>=4,r["clears"]>=4) for r in groups[(suite,label)])
        print(f"| {label} | {outcomes[True,True]} | {outcomes[False,True]} | {outcomes[True,False]} | {outcomes[False,False]} |")

def observed(rows, kind):
    c = collections.Counter()
    for r in rows:
        for key, count in r["counts"].get(kind,{}).items(): c[key] += count
    return c

def builds(groups):
    print("\n## 1. Build variety")
    common_table(groups,"build")
    paired(groups,"build","focused")
    print("\nActual attained build mechanics, including late evolutions and engine procs. Conditioning on W2 arrival controls for whether a run had access to advanced mechanics, not survivor bias within that world.")
    print("| Policy | W2 arrivals | Any fusion | Any evolution | Any full engine (tier 2+) | Any mastery (tier 3) | Any actual engine proc | Mutation | Unidentified picks |")
    print("|---|---:|---:|---:|---:|---:|---:|---:|---:|")
    for label in EXPECTED["build"]:
        rows = groups[("build",label)]
        elig = [r for r in rows if any(s["stage"]>=2 for s in r["stages"])]
        checks = [
            lambda s: bool(s["fusions"]), lambda s: bool(s["evolutions"]),
            lambda s: any(t>=2 for t in s["tiers"].values()), lambda s: any(t>=3 for t in s["tiers"].values()),
            lambda s: any(t>0 for t in s["engine_procs"].values()), lambda s: bool(s["mutations"])]
        cells = [pct(sum(any(check(s) for s in r["stages"]) for r in elig),len(elig)) for check in checks]
        print(f"| {label} | {len(elig)} | " + " | ".join(cells) + f" | {sum(r['counts']['unidentified_picks'] for r in rows)} |")
    print("\nPer engine by build policy (formed / proc runs / mastery / W4 clears among formed).")
    print("| Policy | Engine | Formed | Proc | Mastery | W4 clear of formed |")
    print("|---|---|---:|---:|---:|---:|")
    for label in EXPECTED["build"]:
        rows = groups[("build",label)]
        engines = sorted(rows[0]["stages"][0]["tiers"])
        for e in engines:
            formed = [r for r in rows if any(s["tiers"].get(e,0)>=2 for s in r["stages"])]
            proc = [r for r in rows if any(s["engine_procs"].get(e,0)>0 for s in r["stages"])]
            mastered = [r for r in rows if any(s["tiers"].get(e,0)>=3 for s in r["stages"])]
            print(f"| {label} | {e} | {len(formed)}/{len(rows)} | {len(proc)} | {len(mastered)} | {sum(r['clears']>=4 for r in formed)}/{len(formed)} |")
    print("\nFusion, evolution, mutation and Prototype usage (raw run counts are observational; do not infer causal power from winning builds).")
    for label in EXPECTED["build"]:
        rows = groups[("build",label)]
        for title,key in (("Fusions","fusions"),("Evolutions","evolutions"),("Mutations","mutations")):
            counts = collections.Counter()
            for r in rows:
                seen = set()
                for s in r["stages"]:
                    seen.update(s[key].values() if isinstance(s[key],dict) else s[key])
                counts.update(seen)
            print(f"- {label} {title}: " + (", ".join(f"{k} {v}" for k,v in counts.most_common()) or "none"))
        offers, picks = observed(rows,"prototype_offers"), observed(rows,"prototype_picks")
        print(f"- {label} prototype picks/offers: " + ", ".join(f"{k} {picks[k]}/{n}" for k,n in offers.most_common()))
    print("\nDraft opportunity audit (aggregate natural offers and selected cards across policies, not a player popularity measure).")
    rows = [r for label in EXPECTED["build"] for r in groups[("build",label)]]
    offers, picks = observed(rows,"offers"), observed(rows,"picks")
    print("| Card | Picks | Offers | Pick/offer |")
    print("|---|---:|---:|---:|")
    for key,n in sorted(offers.items(),key=lambda x:(picks[x[0]]/x[1],-x[1])):
        print(f"| {key} | {picks[key]} | {n} | {pct(picks[key],n)} |")
    print("\nAll fusion choices accept the offered fusion; baseline and focused use the original default evolution policy, focused_alt takes the opposite option. Engine policy prioritizes existing natural ingredients. Manual draft preferences and merchant/rival paths are not modeled.")

def routes(groups):
    print("\n## 2. Route balance")
    common_table(groups,"route")
    paired(groups,"route","repair")
    print("\nRoute-specific next-world outcomes (actual chosen routes; adaptive is not a randomized causal comparison).")
    print("| Policy | Actual route | World arrivals | Clears | Avg ending hull % | Mean level |")
    print("|---|---|---:|---:|---:|---:|")
    for label in EXPECTED["route"]:
        rows = groups[("route",label)]
        for route in ("repair","overclock","bounty"):
            stages = [s for r in rows for s in r["stages"] if s["stage"]>=2 and s["route"]==route]
            if not stages: continue
            print(f"| {label} | {route} | {len(stages)} | {sum(s['status']=='cleared' for s in stages)} ({pct(sum(s['status']=='cleared' for s in stages),len(stages))}) | {mean(100*s['hull']/s['max_hull'] for s in stages if s['max_hull']>0):.1f}% | {mean(s['level'] for s in stages):.1f} |")

def difficulties(groups):
    print("\n## 3. Hard and Insane progression")
    common_table(groups,"difficulty")
    print("\nRewards are compared by actual paid Cores / total simulated time including unsuccessful and timed-out attempts; no automatic difficulty recommendation based on reward multiplier alone.")
    print("| Ship | Normal p32 | Hard p32 | Insane p32 | Normal max | Hard max | Insane max |")
    print("|---|---:|---:|---:|---:|---:|---:|")
    for ship in sorted(FLEET):
        cells=[]
        for p in (32,100):
            for d in ("normal","hard","insane"):
                rows=[r for r in groups[("difficulty",f"{d}-p{p}")] if r["ship"]==ship]
                cells.append(f"{sum(r['clears']>=4 for r in rows)}/{len(rows)}; {cores_min(rows):.1f}/min")
        print(f"| {ship} | " + " | ".join(cells) + " |")

def economy(groups, prices):
    print("\n## 4. Hangar value")
    common_table(groups,"economy")
    paired(groups,"economy","spread")
    print("\nEqual spending ceiling, discrete actual prices, common 1% starting foundation for targeted profiles. These are portfolio comparisons, not individual-rank causal estimates. Spread-no-tools tests the cost of ignoring actual finite draft actions.")
    print("| Portfolio | Actual spend (range) | W4 clears | Rerolls / banishes / skips | Average final level |")
    print("|---|---:|---:|---|---:|")
    for label in EXPECTED["economy"]:
        rows = groups[("economy",label)]
        tools = observed(rows,"tools")
        cost = [r["hangar_cost"] for r in rows]
        levels = [r["stages"][-1]["level"] for r in rows]
        print(f"| {label} | {min(cost)}–{max(cost)} | {sum(r['clears']>=4 for r in rows)}/{len(rows)} | {tools['reroll']} / {tools['banish']} / {tools['skip']} | {mean(levels):.1f} |")
    total = sum(sum(i["prices"]) for i in prices.values())
    print(f"\nProduction catalog: {len(prices)} tracks, {sum(len(i['prices']) for i in prices.values())} ranks, **{total:,} Cores** total. Price cliffs quantify cost, not usefulness.")
    print("| Track | Group | First rank | Last rank | Total | Biggest adjacent price ratio |")
    print("|---|---|---:|---:|---:|---:|")
    for i in sorted(prices.values(),key=lambda i:sum(i["prices"]),reverse=True):
        p=i["prices"]
        jump=max((b/a for a,b in zip(p,p[1:]) if a),default=1)
        print(f"| {i['name']} | {i['group']} | {p[0]} | {p[-1]} | {sum(p)} | {jump:.1f}× |")
    print("\nCheck weak portfolio results against usage and intended specialization; expensive ranks or unused tools are candidates for further isolated tests, not automatic nerfs.")

def endgame(groups):
    print("\n## 5. Endgame")
    common_table(groups,"endgame")
    print("\nOnly three selected ships at maximum Hangar. Same signal pursuit, seed, build and route before W4; Archive may legitimately be inaccessible if two signals were not recovered. Endless continues through at most W7; no fabricated completion.")
    print("| Path | W4 clears | Eligible Archive | Entered extension | W5 clear | W6 clear | W7 clear | Mean extra paid Cores vs W4 claim (settled entrants) | Mean extension min |")
    print("|---|---:|---:|---:|---:|---:|---:|---:|---:|")
    for label in EXPECTED["endgame"]:
        rows=groups[("endgame",label)]
        entrants=[r for r in rows if r["endgame_entered"]]
        finished=[r for r in entrants if r["settlement"]]
        extra=mean(settled_cores(r)-r["entry_cores"] for r in finished)
        minutes=mean(sum(s["elapsed"] for s in r["stages"] if s["stage"]>4)/60 for r in entrants)
        print(f"| {label} | {sum(r['clears']>=4 for r in rows)} | {sum(r['archive_eligible'] for r in rows)} | {len(entrants)} | {world(rows,5)} | {world(rows,6)} | {world(rows,7)} | {extra:.1f} | {minutes:.1f} |")
    print("\nSettlement integrity and incentives after a legitimate World 4 victory.")
    print("| Path | Settled entrants | W4 clears with no recorded victory | Archive achievement | Beyond the Chart | Lost saved W4 Cores |")
    print("|---|---:|---:|---:|---:|---:|")
    for label in EXPECTED["endgame"]:
        rows=[r for r in groups[("endgame",label)] if r["entry_cores"]>=0 and r["settlement"]]
        missing=sum(r["settlement"]["victories"]==0 for r in rows)
        archive=sum(r["settlement"]["archive_cleared"] for r in rows)
        six=sum("endless_six" in r["settlement"]["awards"] for r in rows)
        lost=sum(settled_cores(r)<r["entry_cores"] for r in rows)
        print(f"| {label} | {len(rows)} | {missing} | {archive} | {six} | {lost} |")
    print("\nArchive has a locked-in payout by design; compare its discovery/achievement payoff separately from Endless' rising Core payout. Timeout is not a defeat or a paid run.")

def main():
    groups, prices=read(sys.argv[1:])
    count=sum(len(rows) for rows in groups.values())
    print("# Star/Run five-part balance audit")
    print(f"**{count} real campaign attempts** across matched seeds and actual catalog prices. All traces validated. Automated timed pilot, Vale, standard artifact; no player data, ads, merchant transactions or rival history. A 900-second per-world diagnostic cap reports timeouts separately with zero paid Cores. Four seeds per ship/label are exploratory, not precise estimates of human behavior.")
    builds(groups)
    routes(groups)
    difficulties(groups)
    economy(groups, prices)
    endgame(groups)
    print("\n## Decision rule\nDo not rebalance from raw popularity or a single four-seed ship cell. Prioritize matched outcome differences, mechanical evidence, and reproducible defects; follow each proposed product change with a scoped counterfactual and the existing Normal balance/progression gates.")

if __name__ == "__main__":
    main()
