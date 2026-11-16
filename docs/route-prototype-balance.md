# Star/Run warp choices and four-world balance investigation

## What changed

The intermission should offer three genuinely different plans for the **next world**, not three versions of a number bump.

| Route | What changes for that world | Risk or opportunity cost |
| --- | --- | --- |
| Shielded passage (`repair`) | +70% max-hull repair; full starting shields; **35% less incoming damage**; **+15% automatic weapon damage while shields are above 50%**, plus **15% shorter active-ability cooldowns** | Weapon bonus is lost at half shields; no XP or Core bonus |
| Redline assault (`overclock`) | **+35% automatic weapon damage**, **+20% automatic fire rate** | +10% max-hull repair; start on 50% shields; **20% more hull damage received** |
| Hunter contract (`bounty`) | **One bonus upgrade pick** on warp; **+50% kill XP**; +30 × next-world number base Cores if next boss dies; +40% max-hull repair | **30% more** enemy health, enemy attack damage and spawn pressure |

These route changes are checkpointed; bonuses reset at the next intermission. Hunter's bonus draft is actually offered at the next world start; its XP applies to real enemy kills, not automatically to every time step. The boss contract is awarded only once, on defeating the next boss. World 1 always uses neutral route effects.

### Prototype changes

| Prototype | Stronger gain | Cost |
| --- | --- | --- |
| Bastion Lattice | +85% shield regeneration (was 40%) | -12% automatic damage |
| Volatile Core | +55% automatic damage (was 30%) | +30% hull damage taken (was 25%) |
| Null Harmonics | -38% ability cooldown (was 22%) | -12% automatic damage |
| Salvage Charter | +75% *base* run Cores (was 35%) | -15% automatic damage |
| Breach Optics | +140% damage to boss modules (was 70%) | -10% other damage |
| Mirror Cell | +60% max shields, with the new capacity filled immediately (was 30%) | +15% ability cooldown |
| Echo Coil | +70% ability power, including healing/duration (was 40%) | +18% ability cooldown |
| Emergency Safeguard | First shield break per world immediately restores 80% max shields **and 15 hull** (was 30 shield) | -10% automatic damage |

Existing saves and daily choice rules are preserved. The game still offers three random prototypes or the option to bank +10 flat Cores.

## Progression target for Hard and Insane

The intended opening pressure is severe: **a player with no permanent Hangar upgrades should not be able to clear World 1 on Hard or Insane.** Normal remains a valid starting difficulty; Hangar investments make tougher settings increasingly accessible. This is tested as real combat, not an artificial victory veto. The expanded study checks six ships, six pilots, two upgrade/ability-use policies and three seeds each (432 no-Hangar attempts). **Any observed clear is a red test and requires investigation.** This is an empirical CI gate over a finite sample, not a mathematical claim that no player could ever survive. Separate four-world route research compares representative ships/pilots and none/mid/max Hangar levels using full combat.

## What the balance checks actually measure

1. **Mechanical invariant grid** in `tests/run.gd`: 4 worlds × 3 difficulties × 3 Hangar settings, testing world threat escalation, all 81 later-world route combinations, stat effects, restore behavior and each prototype's distinctive benefit. Bosses are deliberately defeated only to initialize intermission mechanics in these *unit tests*. These are **not victories or player outcomes**.
2. **Real campaign simulator** in `tests/balance_matrix.gd`: the established auto-flying, auto-firing ship with a timed active-use policy and focused draft chooser. It must select actually offered upgrades and prototypes, obey real cooldowns, fight every wave and boss, and can die or time out. The new `--route=repair|overclock|bounty|adaptive` flag runs identical input seeds for route comparisons, logging clears separately for Worlds 1–4. Changed combat can still alter subsequent draft RNG and offered options.
3. **Nine-cell research workflow** in `.github/workflows/route-balance.yml`: 3 difficulties × none/mid/max Hangar with the *same* Arcwing/Rookie ship, focused build, timed active policy and two matched seeds, repeated for each route. This gives 54 genuine attempted campaigns across 27 route/cell combinations, with stage reports and downloadable logs. The ordinary CI separately covers all six ships and the known real-completion regression.

## How to interpret outcomes

- **World 1** has no route or prototype. Separately inspect early survival, especially Normal/no Hangar.
- **Worlds 2–4** should get harder, but a focused and adequately equipped pilot should have a credible way to complete Normal. A late-world wall for all routes is a likely defect.
- **Normal vs Hard vs Insane** should have increasing pressure on matched settings. **None vs mid vs max Hangar** should provide clear progression without making higher difficulties automatic.
- Route comparisons should find distinct *tradeoffs*. Shielded passage should save damaged ships; Redline should accelerate offensive builds, but invite deaths when hurt; Hunter contract should build more XP/Cores at the cost of survival. It is not necessary for all three to produce equal clears.
- Two deterministic seeds are **screening, not statistical win-rate estimates**. The bot's draft policy, shield timing and RNG are not equivalent to human players. Treat any 0/2 or 2/2 cell as a follow-up signal, never a human success-rate estimate.

Do not tune an entire difficulty based solely on a 2-seed difference. Investigate any observed unexpected result with the existing 3-seed `campaign-research.yml` fixtures or more matched seeds first. No automatic promotion to TestFlight is part of this balance experiment.

## 2026-11-16 buff-first balance changes

Redline (+35% damage / +20% fire rate) and its existing risks are **unchanged**. Shielded Passage has a larger defensive and warp-repair payoff. Hunter Contract grants an extra actual draft pick each warp, more kill XP, higher boss Core rewards and more repair while retaining its 30% enemy threat cost. World 2+ defensive actives also improve: Mend clears shield suppression and precisely timed Flak returns 12 shield instead of 8. Normal World 1 and unupgraded Hard/Insane World 1 abilities stay unchanged.

The Insane Harvester HP factor increases from 5.0 to 5.5 so its HP exceeds Hard at matched equipment. Hangar's future purchase prices rise about 15%; existing ranks keep their exact historical refund value through a migrated purchase-receipt ledger. These adjustments need expanded and regular CI validation before merging.

### Shielded Passage follow-up

The first post-buff 21-cell route comparison produced 32/84 Shielded, 46/84 Redline and 43/84 Hunter full-campaign victories (previous study: 31/84, 44/84 and 34/84). Hunter moved much closer while Shielded barely changed. Rather than reduce Redline damage, a second challenger gives Shielded **15% shorter active cooldowns from World 2 onward**, aiming to improve tactical Aegis/Mend/Flak value. This second challenger requires its own new balance study before claiming improvement.

### Shieldstorm defensive fusion and Shield Focus milestones (2026-11-16)

- **Shieldstorm** is a new optional active fusion: Aegis rank 5 + Flak rank 5. It competes with Nova Guard/Missile Grid for its components rather than adding a fifth active slot. On cast it clears hostile bullets and heavy-beam charges, restores shields and grants brief Aegis; it deals no free damage and awards no XP.
- Once fused, the **first survivable shield break per world from World 2 onward** automatically sweeps hostile bullets and charging beams. It refreshes at warp, survives checkpoints, and does not prevent the hit that broke the shield. World 1 has no automatic rescue.
- **Shield Focus** keeps its existing high-shield damage. Rank 5 now grants **+12% weapon damage at full hull**; rank 10 adds another **+18%** at full hull. One hull hit disables this bonus until repaired, making Shielded Passage's large warp repair and reduced incoming damage useful for offense without changing Redline's stats.
- These are earned build options, not unconditional Shielded Passage multipliers. Repeat matched balance tests with a shield-oriented drafting policy as well as the baseline focused policy to measure whether players can reasonably assemble them.

### Route offense and late-world enemy adjustment (2026-11-16)

Following a complete matched 288-campaign study (Shielded 24/48 vs Redline 35/48 using conventional focused drafting; Shieldstorm-first builds underperformed on all routes), Shielded Passage gains a **direct**, draft-independent buff in Worlds 2–4: its damage reduction rises from 25% to **35%** and it receives **+15% automatic weapon damage while current shields exceed 50% of maximum**. At exactly 50% the weapon bonus turns off; repairing shields restores it. The pre-existing 70% warp repair, full shields, and 15% faster ability cooldowns remain. This offensive bonus is not added to Redline or Hunter.

Across all three routes, **Worlds 2–4** enemy regular health, boss core health and boss-module health are multiplied by **0.90**. Incoming attack and corrosion damage are multiplied by **1.05**; encounter frequency, movement, telegraphs, XP and Cores are unchanged. This makes survival more meaningful without increasing enemy time-to-kill. **World 1 and Endless World 5+** retain authored values. The change is deliberately not described as a tested balance improvement until real-combat CI comparisons finish.

The targeted Shieldstorm/Redline study, expanded route study, replay/checkpoint tests, and playable build must be rerun on the amended commit. Existing completed studies represent **pre-change baselines**, not post-change results.


### Insane challenge adjustment (2026-11-16)

Insane previously shared a 1.60 multiplier between health, enemy damage and **spawn density**. At maximum Hangar, four matched World 1 seeds produced roughly 26% more Insane kills than Hard; more kills mean more XP and upgrades, sometimes letting Insane builds outgrow Hard builds despite more damage taken.

Insane now scales enemy HP and shot/beam damage by **2.0x Normal** (25% more than the previous Insane 1.6x). Spawn frequency and ordinary enemy firing intervals retain the previous **1.6x**; those are separate from combat strength so the additional challenge does not award more kills/XP or extra projectiles. Hard is unchanged at 1.25x. Boss enrage, enemy-drop XP, reward multipliers, Shielded Passage, and World 2-4 enemy adjustments remain intact. This is designed to correct the Insane progression advantage; verify with actual matched campaigns, not difficulty labels alone.


### More Insane projectiles and targeted passive buffs (2026-11-16)

On Insane, ordinary enemy projectile firing cadence is now **2.0× Normal** rather than 1.6× (+25% relative shot frequency) and bosses fire projectile fans **25% more often**. The enemy spawn multiplier remains **1.6×** and does not scale with the additional shot pressure. Carrier/echo-carrier firing remains at its old 1.6× schedule, preventing extra minion launches and farmable XP; boss timed launch cycles and independently telegraphed heavy-beam timings remain unchanged. Enemy HP and attack strength remain 2.0× Normal on Insane, as established in the previous change. Hard and Normal are untouched.

The World 2+ weaker passives receive **buffs, not blanket nerfs**: First Strike (Opening Salvo) now adds its established 4%/rank + rank 5/10 milestones to automatic hits as long as the enemy is **above 75% health**, not only the first undamaged hit. Last Stand retains its existing per-rank damage and milestones but activates below **60% hull** instead of 40%. Insulation retains its status-duration reductions and additionally reduces ion, corrosion, disrupt, heat, gravity and void attack damage by **0.8% per rank, +3% at rank 5, and +4% at rank 10**, reaching **15% at rank 10**. Ongoing corrosion damage also receives this resistance. Chaff, heavy beams, ordnance, and physical hazards remain outside this specific damage resistance. In-game card descriptions and milestone copy reflect all updates.

These are combat-driven advantages, not direct XP/Cores. Full simulation, UI, build and paired difficulty tests must validate outcomes before claiming Insane's final ordering or the passive buffs' relative effectiveness. The previous 288-campaign study is a pre-buff reference, not an evaluation of these changes.
