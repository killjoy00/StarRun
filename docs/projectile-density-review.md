# On-screen enemy projectile density: 1.0-era / 1.1 / 1.2

This study answers whether faster enemy firing actually means more *enemy projectiles simultaneously visible* in active combat. Source: [GitHub Actions run #44103290731](https://github.com/killjoy00/StarRun/actions/runs/44103290731), PR #38.

## Measurement

- Same 12 starting seed/scenario combinations in each version, three seeds per configuration:
  Vanguard Normal/no Hangar; Arcwing Normal/mid Hangar; Bulwark Hard/max Hangar; Wraith Insane/max Hangar.
- During each live, non-paused Godot simulation every 0.2 game seconds, count projectile centers inside the 540×960 field. Include enemy bullets and ordnance, not friendly shots. Measure charging heavy-beam lanes separately.
- Run exactly the same instrumented `tests/balance_matrix.gd --density` diagnostic against the pinned prior version, merged 1.1, and merged 1.2. The game logic is unchanged, no forced victories or draft picks.
- Time-weighted mean is total sampled bullets divided by number of samples per phase. This is **not** a customer statistic or render-frame performance measurement.
- Versions can change kill speed, upgrade draws, stage access, ability activations, and fight duration; comparisons need cohort context.

## Main result

| Time-weighted mean number of visible hostile projectiles | Before 1.1 | 1.1 | 1.2 |
| --- | ---: | ---: | ---: |
| All combat, four cohorts pooled by active time | 9.47 | 5.14 | **6.68** |
| All enemy-wave time | 8.86 | 4.08 | **5.27** |
| All boss fights | 17.72 | 18.39 | **20.01** |
| World 1 enemy waves | 2.49 | 2.84 | **2.84** |
| World 1 bosses | 16.80 | 19.14 | **21.78** |

**Interpretation:** Compared with 1.1, v1.2 increases pooled visible shots across whole combat by ~30% (5.14→6.68) and during boss fights by ~9% (18.39→20.01). Boss-fight time with >=20 projectiles rose from 44.6% to **52.1%**. But 1.2 is not uniformly denser than the older pre-1.1 game: heavily upgraded ships often wipe out ordinary waves early, before their higher firing rates take effect.

| Same ship/setting, mean hostile bullets per active frame | Pre-1.1 all | 1.1 all | 1.2 all | 1.1 boss | 1.2 boss |
| --- | ---: | ---: | ---: | ---: | ---: |
| Vanguard / Normal / no Hangar | 11.70 | 14.17 | **14.43** | 18.82 | 20.20 |
| Arcwing / Normal / mid Hangar | 7.10 | 5.31 | **7.45** | 13.09 | 11.96 |
| Bulwark / Hard / max Hangar | 7.88 | 4.18 | **5.07** | 22.69 | 25.82 |
| Wraith / Insane / max Hangar | 12.23 | 1.97 | **2.63** | 15.66 | 21.50 |

Wave pressure in the max-Hangar builds remains extremely low even at 1.2: Bulwark **1.45** enemy bullets on average, Wraith **1.49**. By contrast, their boss fights average **25.82** and **21.50** enemy bullets, respectively.

The Vanguard starter's World-1 waves increased 7.71→8.48 from pre-1.1 to 1.2 (+10%), and its first boss 15.88→20.20 (+27%). World-1 enemy-wave density **did not** change from 1.1 to 1.2; the second release increased *boss* fire only, not ordinary enemy firing again.

## Implications for the next balance pass

1. **Research enemy lifetime before increasing ordinary enemy HP.** Later-stage enemy health already scales ×4.8/11/22 before difficulty multipliers. A global HP increase could defer XP, leave more enemies alive when subsequent waves spawn, cause more off-screen escapes (+5 hazard damage) and weaken beginner/low-Hangar builds. The dynamic depends on whether a shooter is killed before its first volley, not just its health.
2. If more bullets in veteran waves are the goal, first trial a **small HP bump on selected projectile-firing enemies after World 1**, excluding fast rusher/interceptors, carriers that spawn XP minions, and mine/slag specialists. Analyze time-weighted visible bullet density, escaped-enemy damage, time to kill, and full campaign clears on identical seeds.
3. Compare a **shorter first-shot windup** challenger as an alternative to more HP. Current spawned shooters begin with a random 1–3 second first-fire timer; a shorter first volley could add screen pressure without inflating time-to-kill or suppressing XP.
4. Avoid merely raising the maximum count: over-crowding is a readability/telegraph problem. Track share of time with 20+ or 40+ enemy bullets and whether defensive cooldowns are ready.
5. Bosses are already much denser than waves; prioritize **clear telegraphs and special-phase objectives** over another across-the-board boss volley increase.

Both competing changes should be research-only PRs until matched data show acceptable Normal playability and Hard/Insane progression. No ad/Apple/TestFlight actions are implied.
