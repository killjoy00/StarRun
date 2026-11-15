# Star Run — active ability balance pass (2026-11-15)

The baseline is `main` at the start of this pass. These are small cooldown adjustments, **not** a claim of matched-seed win-rate proof; the simulation and fixed-build timing suites remain CI gates. Values are seconds before Hangar, pilot, milestone and fusion modifiers.

| Ability | Before | Proposed / implemented | Why |
| --- | ---: | ---: | --- |
| Nova | 20 | **24** | Clears every projectile, cancels beams and damages the entire enemy pack. One broadly useful emergency button should not refresh as quickly as specialists. |
| Flak screen | 16 | **14** | Only removes missiles, mines and slag; faster uptime pays for its narrower coverage. |
| Chaff barrier | 25 | **21** | Does not protect against heavy beams; let players use it for recurring swarms. |
| Decoy beacon | 22 | **20** | Indirect avoidance needs more opportunities to compete against guaranteed prevention. |
| Signal jammer | 24 | **22** | Proactive interruption requires timing before a charge begins. |
| Precision focus | 23 | **21** | It competes with damage actives while relying on the player's automatic weapon loadout. |
| Chain overload | 24 | **22** | Only detonates nearby small shots; its payoff depends on an encounter's projectile density. |
| Reactor reboot | 34 | **30** | Requires at least one other active on cooldown, otherwise it provides little value. |
| Salvage surge | 28 | **24** | Gives no immediate survival or boss damage and must compete with combat slots. |

## Keep for now

- **Aegis (14s):** preserve the readable heavy-beam counter window; it is the game's clearest input-timing skill.
- **EMP (23s):** still a strong early interrupt that has no Nova AoE damage. Compare against Jammer after telemetry.
- **Capacitor (20s):** direct shield reset has a clear niche, especially in Ion Storm.
- **Barrage (14s), Wing drones (18s), Ion mine (15s):** preserve their distinct projectile, summon and trap cadence until matched-seed pressure and long-run stacking are evaluated.
- **Fusions:** retain their separate authored cooldowns. Fusion strength should be assessed after the base-ability effects, not modified blindly with base cooldowns.

## Follow-up recommendations, not yet applied

1. **Measure choice rate, use timing and survival by ability** at the same stage, seed, rank and loadout. A low pick rate by itself may be unfamiliarity, not weakness.
2. **Test Rail strike and Energy siphon in World 3/4 and endless.** Their mostly flat direct damage competes with bosses whose HP scales steeply. Favor a capped percent-of-target-max-health component over unbounded flat damage if they fall behind.
3. **Check Decoy versus EMP/Jammer** against beam, missile and swarm encounters. If proactive bait is still too weak, strengthen duration/redirect consistency rather than another cooldown cut.
4. **Track four-slot economy.** Salvage and Reboot trade an entire button slot for indirect value; consider reward and cooldown only after checking that they are actively pressed in real runs.
5. **Include 10+ ranks and fusions in every balance fixture.** Do not balance early World 1 at the expense of a powerful long-run build.

## Acceptance criteria

The normal four-world campaign must remain completable with reasonable timed inputs, timed counters must beat on-cooldown spam in matched-seed fixtures, World 5 must increase danger above World 4, and each narrow specialist must have a recognizable situation to shine. Review the simulation job's `BALANCE` and `FIXED_BUILD_TIMING` output before merging further numerical changes.


## Follow-up: evidence-driven balance pass (2026-11-15)

**Correction to the earlier summary:** These are scripted bots, not human players. The baseline World 1 comparison stops after **World 1**, so 14/24 no-active clears does **not** mean 14 complete campaigns. In the 24-seed World 1 fixture, no active casts cleared 14/24, on-cooldown casts cleared 19/24, and reactive timing cleared 20/24. A separate *fixed-loadout, hard-mode World 1 boss* comparison cleared 24/24 when the Nova Guard fusion was timed versus 5/24 when spammed. That strong single-fusion result does not establish that timing is crucial for all abilities.

The bots always move and fire automatically. "Never" means **no manual active-ability casts**, not that the ship literally does nothing. Bots also choose upgrades. In normal runs, combat and draft share RNG; matched seeds are comparable starting conditions, not an exactly matched sequence of upgrade offers. Results must never be presented as human-player outcomes.

### Changes in this follow-up

- **World 1 pressure:** preserve enemy **spawn rate/XP**, but after 110 seconds accelerate enemy gunfire (interval x0.80) and make the well-telegraphed heavy beams hit 20% harder. The World 1 boss's non-heavy gunfire accelerates only after its first 18 seconds (interval x0.80). The opening segment and heavy-beam warning length remain unchanged. These are simulation hypotheses, not guaranteed win-rate targets.

- **Aegis precision:** casting in the final 0.7 seconds of a heavy-beam warning or just before a projectile hit restores 10 base shield and rebates 20% cooldown, in addition to regular blocking. A blind cast still prevents damage but gains no extra shield/recharge. This is intended to widen the ordinary timed-vs-cooldown advantage beyond the specialized Nova Guard fixture.
- **Flak:** intercepting ordnance on an imminent collision path, or mines/slag just about to detonate nearby, restores up to 8 shield times effect strength. Casting early still clears ordnance but receives no shield reward.
- **Jammer:** suppresses future fire as before; when used in the last 1.5 seconds of a telegraphed heavy charge, it *also* cancels that charge and reduces that cast's cooldown by 20%. Early casts do not interrupt an already charging beam.
- **Rail Strike:** adds 0.8% of maximum boss HP, capped at 2,200 damage *before ability-power scaling*. The existing base strike remains and ordinary enemies receive no HP-based bonus.
- **Energy Siphon:** adds 0.4% of maximum boss HP, capped at 1,200 extra pre-scaled damage. Healing now uses actual recorded damage after defenses and overkill, capped at 25 times ability-power scaling per cast. This avoids boss HP becoming an unlimited healing source.
- **Other actives:** no cooldowns changed in this pass.

### Automated measurement and safeguards

- The existing simulation tests retain the quick 24-seed World 1 comparison and fixed-loadout Nova Guard timing gate; they now add close-call / early-cast tests for Flak and Jammer, Rail Strike late-boss/cap assertions, and Siphon actual-damage/healing-cap assertions.
- The new [balance matrix](../tests/balance_matrix.gd) simulates all four worlds, all six ships, and Normal/Hard/Insane with the three active-use policies. It reports **stage-by-stage clear counts**, entire-campaign victories, casts, mean final hull, and timeouts. This is an automated **diagnostic**, not a passing win-rate target.
- Every regular PR runs a one-seed **6 x 3 x 3** full-campaign smoke matrix to catch structural regressions. The [weekly balance workflow](../.github/workflows/balance-matrix.yml) runs six matched seeds per ship/difficulty combination: **108 distinct matched seed/configuration fixtures for each policy, 324 scripted trials total**, sharded over 18 jobs, with downloadable logs. Manual workflow dispatch can request 100 seeds per cell for deeper analysis.
- Do **not** automatically rebalance around the first matrix. Look for World 1 no-active clears around 35-45%, timed-input clears around 75-85%, and a meaningful timed-over-cooldown advantage, then evaluate actual human-player playtesting. These are design hypotheses and must not be misrepresented as current measured performance.

### Next decision criteria

First inspect whether no-cast World 1 clears and timed-over-cooldown differences move in the intended direction; second verify that World 2-4 remain achievable for at least one well-played ship/build; third compare Rail Strike/Siphon boss damage and healing by world without making ranks 5-10 oppressive. If an automated policy fails later stages, determine whether this reflects game difficulty, the scripted upgrade policy, or a simulation timeout before tuning enemies.


**Iterative test result:** The *rejected first approach* increased spawn frequency and thereby fed the autopilot more kill XP: World 1 no-cast clears rose from 14/24 (previous baseline) to **16/24**, on-cooldown cleared 18/24, and timed cleared 19/24. The fixed Nova Guard Hard boss remained timing-dependent (24/24 vs 0/24), but the overall comparison got worse. That spawn change was reverted and replaced with projectile pressure and heavy-beam damage. Do not cite the 16/24 as the new final tuned outcome.

**Projectile-pressure iteration:** On the 24-scripted-seed World 1 fixture, maintaining spawn XP while raising avoidable projectile pressure yielded 8/24 no-active clears, 18/24 on-cooldown clears and 19/24 reactive clears. This materially improves the need for active use but timing beats cooldown only marginally, so Aegis now also rewards a precise counter; new results must be measured before claiming any additional improvement. The dedicated fixed-loadout Nova Guard fixture remains 24/24 timed vs 5/24 on-cooldown.
