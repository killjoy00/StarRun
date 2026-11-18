# StarRun build engines — first implementation for #60

This PR adds **six automatic build engines**, using existing weapons and cards. It is the **first of three planned PRs**. Rank-5 weapon evolution choices, build-aware draft weighting and optional fusion decisions are follow-ups. There are no new combat buttons, currencies, weapons, or ability-timing requirements.

## Earned thresholds

An engine uses a primary item, a secondary system and a third complementary item:
- **Precursor:** primary rank 4 + secondary rank 2. Small weapon-specific 6% damage bonus, 5% shield recharge, or 6% hull repair.
- **Online:** primary rank 5 + secondary rank 2 + third rank 2. New automatic combat behavior.
- **Mastered:** primary rank 8 + secondary rank 5 + third rank 5. More frequent/stronger automatic signature.

Storm Circuit's third item may be any of Pulse, Seeker or Lance. Salvage Carrier requires a genuinely learned Wing Drones ability, but its signature works even if that ability is never manually cast.

World 1, published Dailies and the Drone Armada challenge have no new engine mechanics. The existing Daily draft pool, timings and scores remain unchanged. Engine state is stored in the version-1 checkpoint and older saves without these fields restore cleanly.

## Mechanical payoff

| Engine | Components | Automatic payoff |
| --- | --- | --- |
| Execution Network | Pulse + Targeting + Finisher | Five hits on the same target trigger one precision follow-up (mastery: three), with a global cooldown |
| Missile Siege | Seeker + Siege Rounds + First Strike | Hits on bosses, modules and elite leaders build a 5-second, three-stack breach mark that strengthens follow-up seekers |
| Storm Circuit | Arc + Autoloader + another automatic weapon | Arc charges up to six targets for 4 seconds; another weapon discharges real additional damage and a small chain (mastery: up to two chains) |
| Prism Hunter | Lance + Targeting + First Strike | Repeated beam hits on the same priority target produce a capped, earned focus strike |
| Fortress Reactor | Shield + Regen + Shield Focus | Shields above 75% for 8s charge an automatic counterbattery; loss of shield resets it (mastery: 6s) |
| Salvage Carrier | Harvester + Repair Bots + Wing Drones | Six charge units from actual kills and bounded elite/boss damage generate guided support fire and a small hull repair; mastery doubles the volley |

Source engine damage cannot trigger another engine event; all engine effects have deterministic throttles and hard caps. They do not add enemy spawns, XP, Cores or loot. Actual kills pay existing normal rewards **once**.

## Player-facing presentation

Online engines appear in the existing equipment and run-summary screens without lengthening regular upgrade cards. Engine unlocks and real signature procs have restrained color-coded rings rendered below hostile shots and compatible with reduced effects and 3x speed. Only engine unlocks (not routine procs) have restrained sound/haptic cues.

## Validation

A dedicated Godot Actions workflow runs tests/build_engines.gd for each tier threshold, actual damage, cross-weapon chaining, zero-cast support, non-recursion, RNG isolation, save/resume and World 1/Daily exclusions. Existing campaign, Silent Archive, boss phase, UI, and unsigned iPhone workflows also run before review. Matched-seed scripted outcomes are **not** human-player fun evidence.

The rest of #60 is staged:
1. Rank-5 specialization, better build-aware drafts, fusion choice and compact engine-progress display.
2. Pilot, Prototype and rare mutation integration, followed by matched-seed balancing and physical iPhone readability checks.

This feature PR does **not** upload TestFlight or publish the app.
