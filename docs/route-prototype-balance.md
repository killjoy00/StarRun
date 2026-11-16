# Star/Run warp choices and four-world balance investigation

## What changed

The intermission should offer three genuinely different plans for the **next world**, not three versions of a number bump.

| Route | What changes for that world | Risk or opportunity cost |
| --- | --- | --- |
| Shielded passage (`repair`) | +70% max-hull repair; full starting shields; **25% less incoming damage**, plus **15% shorter active-ability cooldowns** in the next world | No attack, XP or Core bonus |
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
