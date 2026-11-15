# StarRun Worlds 2–4: evidence-based balance investigation (2026-11-15)

## What we tested

This pass follows [issue #19](https://github.com/killjoy00/StarRun/issues/19). The original full-campaign smoke suite used a simple bot that auto-flies and auto-fires, automatically selects offered upgrade cards, and activates abilities via a scripted policy. In six one-seed ship/difficulty pairs, none completed World 2. **Those outcomes were not human players and did not prove the campaign was unwinnable.**

We added a focused but still legitimate draft strategy to `tests/balance_matrix.gd`: weapon ranks, boss damage, defensive recovery, relevant counters, and prototype/route choices. It only selects actually offered draft cards, follows the normal game simulation with full boss HP, and never injects weapons, forces damage, or skips an encounter. It can be run with no Hangar, a modest Hangar, or a maxed Hangar. The latter is a ceiling fixture, not a first-time player's build.

The research workflow `.github/workflows/campaign-research.yml` captures time, World 1–4 clears, boss health/components, damage sources, rank build, active slots and the last events for **three identical seeds in each of 13 different fixtures**. The seeds are `817919`, `825838`, and `833757` (one per fixture, replayed at each stage of this investigation). Three trials per cell provide reproducible **signals**, not precise win-rate estimates.

## Primary findings

1. **The simple bot was strategically weak.** It often used four active slots early and neglected weapon investment. For a no-Hangar Vanguard, even a focused bot still died in World 1 or early World 2 in all three seeds. We did *not* make all four worlds easy for a new, unupgraded ship.
2. **Legitimate four-world victories were already possible for well-equipped builds.** Before changing gameplay, an Arcwing with max Hangar completed all four worlds on the initial controlled seed. Full 3-seed pre-tuning studies also found an Arcwing with moderate Hangar winning at least once, plus maxed Wraith/Bulwark wins. This demonstrated that fixed artificial boss kills were unnecessary.
3. **Repeated status rounds and early heavy beams were the later-world bottleneck.** World 2 often killed underpowered ships with ion/corrosion and prolonged disruption; World 3 introduced strong heat/slag pressure; in World 4, consecutive `void_lancer` heavy warnings combined with penetrating Void/Gravity shots could kill even a reasonably developed ship long before its boss.
4. **Ability counters had holes.** Barrier blocked only plain chaff; Deflector and Prism failed to recognize Heat, Gravity or Void as ordinary small status shots; Mend healed but didn't clear accumulated corrosion or overheating. Those omissions disproportionately hurt defensive/support loadouts.
5. **Long-run course boundary bug:** the movement course was pre-generated through 1,200 seconds. The fourth world could push past that window and effectively leave the ship on the last interpolation segment. The course now extends lazily with a separate deterministic RNG, reconstructible from the original seed on restore without shifting combat/draft RNG.

## Implemented adjustments

- Worlds 2–4 now begin with **75%, 82% and 65% respectively** of their prior incoming damage, then climb smoothly to full authored pressure by 155s, 170s and 195s of each world. Enemy counts/health/XP and boss encounter pressure remain unchanged, as do World 1's previously validated timing rules.
- World 4's early pre-boss heavy-lancer interval is at least **7.8 seconds** through the first 135 seconds; afterward its original interval returns. Void projectiles in World 4 now bleed **20% rather than 30%** of their damage directly through shields. The final boss retains its original beam patterns, module shielding and full threat cadence.
- `Barrier` now blocks small Chaff, Ion, Corrosion, Disrupt, Heat, Gravity and Void projectiles. `Deflector` absorbs those same small rounds for shield; `Prism` converts nearby ones into guided fire. **Ordance, mines, slag and heavy beams still penetrate** and remain special counter situations.
- `Mend` now purges active corrosion and overheating when deliberately cast, on top of its existing heal. No passive automatic cleanse.
- **Haven** alone gains 25% resistance to damage from status projectiles (Ion/Corrosion/Disrupt/Heat/Gravity/Void) and periodic corrosion hull damage; beams and non-status/explosive threats still deal full damage.
- All relevant descriptions and regression assertions updated. No generic extra XP, free equipment, artificial kills, or across-the-board boss HP cuts.

## Reproducible three-seed scripted outcomes

The tables below count **complete four-world campaign wins**, not just World 1 or a single boss. All trials used **Normal** difficulty and a focused scripted policy unless otherwise noted.

| Ship and build | Early World 4 tuning* | After specialist counters and Haven resilience |
| --- | ---: | ---: |
| Vanguard, no Hangar | 0/3 | 0/3 |
| Vanguard, moderate Hangar | 0/3 | **1/3** |
| Vanguard, maximum Hangar | 1/3 | **1/3** |
| Arcwing, moderate Hangar | 1/3 | **1/3** |
| Arcwing, maximum Hangar | 3/3 | **3/3** |
| Kestrel, moderate Hangar | 0/3 | **2/3** |
| Wraith, moderate Hangar | 0/3 | 0/3 |
| Wraith, maximum Hangar | 2/3 | **3/3** |
| Bulwark, moderate Hangar | 0/3 | 0/3 |
| Bulwark, maximum Hangar, **Hard** | 1/3 | **2/3** |
| Haven, moderate Hangar | 0/3 | 0/3 |
| Haven, maximum Hangar | 0/3 | **1/3** |

*Early tuning had already included the XP-neutral stage-entry damage ramps, the early World 4 heavy interval and Void hull-bleed adjustment. The later column adds status-shot specialist coverage, Mend cleansing and Haven resistance. This is an attribution-limited controlled comparison, not a claim that a single change explains every win.*

Baseline bot and focused no-Hangar Vanguard remained 0/3 full-campaign wins. **These are deterministic automated bots with only three seeds per fixture, not observed players or estimates of human completion probability.** World 3–4 viability for smaller Hangars remains challenging by design.

## Regression gates

- The normal CI suite tests save/restore determinism after 1,200 seconds; early-vs-full stage damage; World 4 beam interval and Void shield penetration; each small projectile counter; early rockets/beams still piercing Barrier; Mend status purging; and Haven's status/DOT resistances.
- A separate `real_campaign` job in the regular `playable.yml` workflow uses the **moderate-Hangar Arcwing**, Normal difficulty, reactive scripted ability usage, and the actual seed `825838`, with genuine upgrade-card choices, intermissions, boss modules and HP. It fails unless World 4 is genuinely defeated. This is a smoke **existence test**, not a mandated balance win-rate threshold. 
- Broad 324-trial weekly grid remains available for long-run comparisons. The branch-specific 13-fixture research workflow can inspect all difficulty reports and matched inputs. Neither is automatically the PR critical path.

## Limitations and next decision

A model that steers the course and selects draft cards automatically is only a proxy for players. The three-seed results demonstrate real campaign *possibility*, not enjoyable difficulty. Several moderate builds (especially Haven, Bulwark and Wraith) continue to stall before the end; additional broad nerfs would be premature without better bot policy, real-device testing and genuine player data. Further work should test different playstyles and the four-world experience, especially early World 3 and World 4 status-effect readability. Gameplay balance changes in this pass must not imply Apple TestFlight has been uploaded or physically accepted; iOS validation/release are separate.
