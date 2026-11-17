# Star/Run 1.1 — enemy gunfire and charge clarity

## Release intent
Version 1.1 is the next **private TestFlight / first App Store review candidate**. It remains a free, ad-free build until the game is publicly approved by Apple and the AdMob review is complete. Do not display Google sample ads or offer the $1.99 Remove Ads purchase in an ad-free public version.

The last requested 1.0 upload is an **obsolete candidate**, not permission to submit it to Apple. A new signed 1.1 archive must be built from the final merged source after gameplay and iPhone CI pass.

## Why fire-rate tuning is small
- Normal World 1 already permits approximately 19/24 timed-actives bot clears across the fixed 24-seed regression; 8/24 clear without manually activating actives. Those are automated bot runs, **not real-player win rates**.
- Hard and Insane already shoot faster: ordinary projectile cadence is 1.25x / 2.0x Normal, and late World 1 applies additional multipliers. Insane bosses already fire projectile fans 1.25x as often as Normal. World 2–4 stages already accelerate non-boss projectile countdowns by 1.15x / 1.35x / 1.60x, while their enemies deal more damage.
- Increasing enemy **spawns** creates more XP, possibly making players stronger and undermining difficulty; adding heavy beams makes Aegis timing harder without better visual cues; increasing mine or carrier cycles adds hazards or enemies and XP.

## 1.1 tuning (effective frequency change versus the same previous code)
| Fire source | Interval multiplier | Approximately more volleys | Rationale |
| --- | ---: | ---: | --- |
| Normal gunfire, World 1 | 0.92 | +8.7% | More activity without adding enemies |
| Normal gunfire, Worlds 2+ | 0.94 | +6.4% | Late worlds already have rapid shots |
| Boss projectile fans, all worlds | 0.95 | +5.3% | Small extra pressure; heavy charge cadence unchanged |
| Missile bomber ordnance | 0.96 | +4.2% | Ordnance requires a specialized answer |
| Carrier / Echo Carrier | 1.00 | Unchanged | Do not increase XP-bearing minion launches |
| Minelayer / Slag Bomber | 1.00 | Unchanged | No increase in mine / slag density |
| Heavy beams / charge warning duration | 1.00 | Unchanged | Preserve the original 1.8s warning and interval |

No changes to shot damage, projectile velocity, hitboxes, wave timing, enemy hit points, loot, rewards, draft RNG, or the 1.1 save format.

## Red charging-beam clarity
- A red `CHARGING` ring identifies the enemy responsible for an active danger lane when it is on-screen.
- When that enemy dies, the lane instead shows `BEAM CANCELED` in cyan for 0.85 **real-time seconds**, and `SOURCE DOWN` where that enemy was.
- The original heavy-beam tutorial now explains how destroying the charging source interrupts the attack, whereas Aegis protects against a fired attack. Existing interrupted-beam achievements still count.
- The existing Prism lance dry-fire fix is included separately from enemy heavy beams.

## Validation and decision criteria
1. The normal playable regression (24 matched-seed World 1 attempts, fixed-build timing) must pass and maintain a meaningful timed-use benefit over blindly spamming actives.
2. A legitimate, timed-actives Normal campaign with a mid Hangar must still complete four worlds without forced victories or injected upgrades.
3. Six representative ship/difficulty/Hangar combinations run **baseline and 1.1** on three identical start seeds and all three active strategies. The matched tests compare actual stage clears and four-world completions; game combat RNG can diverge after a kill, so they are a screening study, not human player win probabilities.
4. No-Hangar Hard/Insane's existing progression gate must not be bypassed; native iPhone compile and responsive/readability screenshot checks must pass.
5. If the comparison reveals a major reduction in Normal accessibility, reduce the fire multiplier and rerun. Do not tune the whole game based on a one-seed result.

**Baseline:** GitHub main after the Prism lance fix, commit `5603b43f1f84f87094792c8cefe00756b3e3d985`. **Candidate:** the 1.1 PR's head SHA. Detailed paired logs are retained as GitHub Actions artifacts; publication is not automatic.
