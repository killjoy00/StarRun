# Star/Run 1.3 — ship/pilot balance review and elite formations

**Apple marketing version remains 1.3.** Future private TestFlight deliveries use a higher build number, not a new short version. No ads, first-purchase IAP or App Store submission is changed by this work.

## Goal 1: compare all six ships and six pilots at equal Hangar investment

The unmodified loadout audit ran all 6 ships × 6 pilots × 2 difficulty/Hangar cells, two identical starting seeds per pilot: **144 real, scripted two-world attempts**. No injected upgrade cards, enemy kills or victory states. Standard focused draft choices and timed actives were used for all; each scenario was identical apart from the selected ship/pilot. Source: [Actions #44148947874](https://github.com/killjoy00/StarRun/actions/runs/44148947874).

| Ship | Normal/mid Hangar World 1 | Normal/mid Hangar World 2 | Hard/max Hangar World 1 | Hard/max Hangar World 2 |
| --- | ---: | ---: | ---: | ---: |
| Vanguard | 12/12 | 11/12 | 12/12 | 12/12 |
| Kestrel | 12/12 | 12/12 | 12/12 | 12/12 |
| Bulwark | 12/12 | 10/12 | **6/12** | **6/12** |
| Wraith | 12/12 | 12/12 | 12/12 | 12/12 |
| Arcwing | 12/12 | **8/12** | 12/12 | 12/12 |
| Haven | 12/12 | 11/12 | **7/12** | **7/12** |

Under **Hard/max Hangar**, pilot aggregate first-world clears were: Rookie **9/12**, Ace **11/12**, Engineer **9/12**, Hunter **10/12**, Scavenger **11/12**, Tactician **11/12**. On Normal/mid Hangar the pilot World-2 sample was Rookie **11/12**, Ace **9/12**, Engineer **11/12**, Hunter **11/12**, Scavenger **11/12**, Tactician **11/12**. This is too few seeds to rank pilots conclusively.

**Finding:** Hard/max Bulwark with Rookie or Engineer cleared **0/2** first worlds, while Kestrel, Vanguard, Wraith and Arcwing all cleared **12/12** across the six pilots. Haven mostly failed Hard on the first boss. Their real World-1 boss fights went long; dead Bulwark runs still had approximately **2k–19k boss HP** remaining, and dead Haven runs often still had substantial boss HP. This suggests **poor boss damage before the ship can outlast the fight**, not a need for indiscriminate enemy HP reductions. Arcwing's Normal/mid World-2 fragility merits more seeds and player QA before additional tuning.

### Targeted identity-preserving tuning

- **Bulwark:** +12% *automatic weapon* damage against boss cores and targetable boss parts only. Still slower, heavier, Pulse-centric. Ordinary-wave damage unchanged.
- **Haven:** +12% Seeker Pod damage. Still a repair/support ship without a Pulse starter and with its existing status resistance.
- **Engineer pilot:** +6% automatic weapon damage while shield exceeds 50% capacity. Keeps +20 shield and +0.8 shield regeneration and makes protecting that shield an active strategic tradeoff. Every other pilot's bonuses are unchanged.
- **Vanguard/Kestrel/Wraith/Arcwing and Rookie/Ace/Hunter/Scavenger/Tactician:** no broad numerical buffs or nerfs from the tiny sample. Arcwing World-2 concern is a separate follow-up, not a blanket nerf to Ion Storm.

A matched study runs **every pilot** in Bulwark/Haven on Hard/max Hangar with independent seeds and Normal/mid Hangar as a no-regression guard. It compares the immutable same-elite pre-tuning commit `cf17a7d5c5de72a31f0d62cb848b815bd22b730d` against the new traits; there is **no extra elite-formation variable** in this causal comparison. Tests verify exact boss/Seeker/shield conditional multipliers and save compatibility. Do not claim true player win probabilities or balanced skill ceilings from two seeds.

## Goal 3: meaningful elite formation counterplay in Worlds 2–4

- Reuse the existing three queued normal enemy spawn slots; about **half of naturally occurring encounter formations** in Worlds 2, 3 and 4 are promoted to a coordinated squad. No World-1 elites or new boss phases.
- The first existing unit becomes a clearly marked **ELITE LEADER**, with 20% extra HP and a moderate auto-targeting priority. The other two units are **LINKED** and use **20% shorter repeat-shot intervals** (about 25% more volleys) while the leader survives. No extra bullets per volley, enemies, XP, Cores, mines, heavy beams or carriers.
- Destroying that leader marks **all surviving and still-queued escorts** as disrupted, delays their next shot by at least 1.8 seconds, returns them to their original shooting rate, and shows a cyan **FORMATION BROKEN** cue held for at least **1 real second** even at 3x combat speed.
- If a leader dies before both wingmen enter, later-spawned units remain disrupted. Old saved flights with plain string formation queues still load. Boss entry clears the remaining queue and normal formations remain normal. All new markers are drawn on the actual playfield, including reduced effects.
- The player still doesn't steer or manually aim; this is an explicit tactical objective for their auto-targeter and ability timing, not a forced kill or skill check.

## Acceptance / release discipline

- All six ship-specific campaign smokes, genuine four-world Normal victory, save/replay, UI, actual visual screenshots and unsigned iPhone build must pass.
- New deterministic tests cover elite leader destruction before and after wings spawn, ordinary enemy shots, no added XP, unchanged World-1, real-time cue, and existing checkpoint formats.
- Matched tuning evidence for Bulwark/Haven must be reviewed before merge; do not force equality between free and paid pilots at any cost.
- The 72-cell baseline audit remains manually rerunnable, not an expensive recurring CI requirement.
- **Stay at version 1.3**, queue a new signed build only after an approved green merge, and do not submit to public App Review or enable ads.
