# World 3/4 damage-driven boss objectives (issue #36)

These bosses now have **three damage-driven stages**. There is **no cooldown or enforced invulnerability timer** between phases. Once players have damaged the core to a threshold *and destroyed its targetable components*, the next stage starts immediately. Auto-weapons automatically target live components; if a shot collides with the boss's large hit circle first, damage is redirected to a visible component.

| Encounter | Stage 1 | Stage 2 | Stage 3 |
| --- | --- | --- | --- |
| World 3 — Crucible Engine | Two original cooling vents. Core can be lowered to 65% HP, but not past the floor until vents die. | At 65% HP, immediately deploy two new cooling vents and a seven-round heat surge. The core can be lowered to 30%, then both vents must die. | At 30%, spawn a final central vent and another heat surge. The last 6% of core HP is held until the vent breaks, then the core can be defeated immediately. |
| World 4 — Void Regent | Two original shield pylons. Core floor 65% HP. | At 65% HP, spawn two reconfigured shield pylons and a nine-round void surge. Core floor 35% HP. | At 35%, trigger **Final Onslaught** and another void surge, with no new pylons or forced waiting. |

The displayed core shield and named, ringed targetable objectives make the protection visible. Damage to the sealed core is reduced; after each component is destroyed, remaining shielding is weaker. Regular projectile patterns, heavy-beam warnings and the existing boss counters remain intact.

**Economy:** Newly spawned objective modules have zero XP and cannot award additional kills, module-salvage Cores, or other payouts. The original two components and the normal boss completion payout keep their original rules. World 1 and 2, Daily openings, secret Archive, regular enemy density, and preexisting difficulty multipliers are unchanged.

**Checkpointing:** `late_boss_phase` is stored in the flight snapshot, and active module and bullet objects are already part of the snapshot. Resuming mid-phase must not regenerate an extra set of modules or change the original saved state. Old saves without this field default to the initial phase.

## Automated review

- `tests/run.gd` checks enormous single-hit overkill, all phase floors, new vents/pylons, additional attacks, auto-aim, zero extra rewards, kill conditions, and both boss checkpoint states.
- `tests/boss_phase_matrix.gd` checks six ships × Normal/Hard/Insane × no/mid/max Hangar × both bosses (108 isolated boss scenarios). The tests execute the real damage pipeline and verify immediate phase changes, target selection, checkpoints and kills. These are *mechanical verification cases*, not a claim about human win rates.
- `.github/workflows/playable.yml` remains the regular actual-four-world campaign, complete regression and UI/screenshot gate. Validate high-Hangar Wraith/Insane separately against real draft outcomes before shipping.
- On iPhone TestFlight, verify the highlighted targets, shield ring, beam/heat/void overlaps, and sudden phase changes at 1× and 3×. Do not infer touch readability from headless CI.

This is a deliberate alternative to adding more boss HP or mandatory phase waits.
