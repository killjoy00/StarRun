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
