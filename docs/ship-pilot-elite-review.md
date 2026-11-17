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
- **Haven:** first-pass +12% Seeker Pod damage; the Insane follow-up also shortens Seeker reloads from 0.70s to 0.55s (Hunter: 0.62s to 0.50s), and makes the ship's signature Repair Drones heal 25% more. No Pulse starter, and its status resistance remains intact.
- **Engineer pilot:** +6% automatic weapon damage while shield exceeds 50% capacity. Keeps +20 shield and +0.8 shield regeneration and makes protecting that shield an active strategic tradeoff. Every other pilot's bonuses are unchanged.
- **Vanguard/Kestrel/Wraith/Arcwing and Rookie/Ace/Hunter/Scavenger/Tactician:** no broad numerical buffs or nerfs from the tiny sample. Arcwing World-2 concern is a separate follow-up, not a blanket nerf to Ion Storm.

A matched study runs **every pilot** in Bulwark/Haven on Hard/max Hangar with independent seeds and Normal/mid Hangar as a no-regression guard. It compares the immutable same-elite pre-tuning commit `cf17a7d5c5de72a31f0d62cb848b815bd22b730d` against the new traits; there is **no extra elite-formation variable** in this causal comparison. Tests verify exact boss/Seeker/shield conditional multipliers and save compatibility. Do not claim true player win probabilities or balanced skill ceilings from two seeds.


### Insane/max Hangar follow-up: finding the underpowered support ship

On the **first-pass 1.3 tuning** (before the extra Haven support changes), the same 6 ships × 6 pilots with two identical starts per pilot were simulated for up to two worlds on **Insane/max Hangar**, timed active-ability use, actual card offers and natural elite formations. Source: [Actions #44157962809](https://github.com/killjoy00/StarRun/actions/runs/44157962809).

| Ship | Insane/max World 1 | Insane/max World 2 |
| --- | ---: | ---: |
| Vanguard | 5/12 | 4/12 |
| Kestrel | 5/12 | 5/12 |
| Bulwark | 10/12 | 10/12 |
| Wraith | 9/12 | 9/12 |
| Arcwing | 9/12 | 9/12 |
| Haven | **2/12** | **2/12** |

**Diagnosis:** 9/12 Haven attempts died before the World-1 boss. The support ship struggled to eliminate early threats and earn upgrades, not merely to damage the boss. More boss-only damage cannot solve that. Other ships ranged from 5/12 to 10/12 first-world clears with the same seeds and Hangar spend.

**Second targeted Haven adjustment:** a quicker signature Seeker Pod reload (~20–21% shorter) and +25% effectiveness of Haven's Repair Drones, retaining its no-Pulse identity. Dedicated [matched Haven before/after jobs](https://github.com/killjoy00/StarRun/actions/workflows/loadout-tuning-review.yml) compare all pilots against the immutable first-pass PR head `96c79f3f28b283067732b728f98d8036bc0b6220` on Insane/max plus a Normal/mid no-regression control. Do not claim the follow-up improves outcomes until those jobs finish.

These are just **two starting seeds per pilot**: useful for finding glaring weaknesses, not estimates of true player win rates. The full original Normal/mid and Hard/max study and this Insane/max follow-up use the same two starting seeds, but different Hangar tiers by difficulty to stress realistic progression points. A future manual audit can rerun all three tiers.
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
- The 72-cell Normal/Hard baseline plus the Insane/max follow-up remain manually rerunnable as a three-difficulty audit; the costly full grid is not a standing CI requirement.
- **Stay at version 1.3**, queue a new signed build only after an approved green merge, and do not submit to public App Review or enable ads.
