# Five-part balance audit (post #81)

**Frozen gameplay baseline:** cd749fd5c490b7cf64aa32cea391784dd2553683. No production tuning, deployment or release in this research PR.

## What we are measuring

The opt-in [Five-part balance audit](../.github/workflows/project-balance-audit.yml) runs 624 real campaigns (plus five smoke runs) with four matched seeds per ship/label. Pilot is Vale, standard artifact, scripted threat-timed actives. All offered hands, upgrade ranks, prototype offers, boss combat, unlocks and payout settlement use production code. No forced cards, wins, levels, synthetic XP or injected rewards. The economy study uses real finite draft tools; the others use existing three draft policies plus engine-oriented and alternate-evolution variants. No merchant trades, rival history, ads, Daily or human-learning assumptions. A 900-second per-world diagnostic cap is recorded separately, never as death or settled payout.

| Study | Ships | Policies | Attempts |
|---|---:|---|---:|
| Build variety | 7 | baseline, focused, shielded, alternate evolution, engine-seeking | 140 |
| Routes | 7 | repair, overclock, bounty, hull-adaptive | 112 |
| Difficulty | 7 | Normal/Hard/Insane × zero/32%/100% Hangar | 252 |
| Economy | 3 | spread and five group-focused 8%-budget portfolios, spread without tools | 84 |
| Endgame | 3 | W4 claim, continue Endless through W7, attempt real signal-based Archive | 36 |
| **Total** | | | **624** |

- Build: actual offers and choices, acquired fusions/evolutions/mutations, tier 2/3 engines, real proc counts, and matched outcomes. Compare availability versus selection; winning builds have survivor bias. Alternate evolution policies are not isolated tests of each individual evolution.
- Route: identical W1 state for every policy on each seed; report matched W4 clears, actual next-world survival, ending hull, level and earnings. Adaptive picks by hull; fixed routes isolate route policy more cleanly.
- Difficulty: real conditional clear rates and paid Cores per attempted simulated minute. Compare to Normal at the same Hangar. A higher reward multiplier does not necessarily mean a better progression path.
- Economy: exact price for all 214 ranks from production Catalog.price; matched spending ceiling and actual spend for portfolios, usage of finite draft tools. A portfolio comparison does not establish the value of each individual rank.
- Endgame: all branches pursue the same legitimate signals before the W4 decision. Test real Archive eligibility and actual entry, continuation to W7, incremental paid Cores, and recorded victory/achievement settlement. Do not fabricate a W4 clear or force a signal.

## Source review before experiments

1. The 44 Hangar tracks total 31,437 Cores over 214 ranks. Hull and Weapons account for 24,274 Cores (77.2%). For Munitions Lab, the first extended rank costs 20× the preceding rank. The first extended rank in the shield line costs ~13.3× the previous rank. These cliffs deliberately preserve early purchases and stretch late progression, but deserve an opportunity-cost check. Previous matched 50-run evidence: full Hangar at run 45; longest pre-max no-purchase streak one run. Do not globally cut prices again.
2. Shielded Passage offers a 70% hull repair, full shields, 35% incoming-damage reduction and cooldown benefits. Redline Assault trades survivability for a 35% gun-power and 20% fire-rate increase; Hunter Contract trades pressure for XP, a draft and bounty. The existing adaptive bot only considers hull, so evaluate fixed policies before modifying their tradeoffs.
3. Hard and Insane offer 1.75× and 2.5× base payout multipliers, but the right progression path depends on time and survivability, not multiplier alone.
4. Endless applies per-depth multipliers to boss HP (1.48×), wave HP (1.30×), damage (1.22×), spawn rate (1.08×), firing rate (1.07×), and module HP (1.42×); payout adds a triangular 75-Core increment per cleared extra world before the regular 1.30× multiplier. Silent Archive locks the Citadel payout on entry and awards its unique achievement on clear.
5. Production Progress.settle records full-run victories for won runs or a secret route after W4. A player who clears W4, continues Endless, then dies may not record a victory; the audit checks actual settled entrants, distinguishes campaign clear from extension outcome, and measures whether saved W4 Cores are preserved. Decide any change based on actual behavior and intended semantics.

## Acceptance and follow-up

- Smoke and all 27 research jobs complete, report rejects incomplete cohorts, missing seeds, actual faults, unexpected duplicate payouts or pre-decision mismatches.
- Save the report in the PR and turn measured issues into prioritized, specific changes with focused tests. Do not tune from anecdotal four-seed cells or change baseline difficulty gates just to pass the study.
- Leave PR #81's Normal balance and Hangar prices untouched unless evidence supports a subsequent change. No release, external service or user interaction required.
