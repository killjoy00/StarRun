# First playable — accepted review changes

2026-11-12. This document records the implemented prototype and is authoritative for prototype tuning; DESIGN.md retains the full-game vision.

## Decisions

1. The first run starts with both Aegis (8 s, 1.8 s protection) and Nova (12 s, global projectile clear and charge interrupt). Upgrades extend their effects. Their theoretical activation cadence is 4.8 s; good play is expected to hold them when that creates value.
2. One five-minute slice: waves until 04:00, then Harvester. A base, intentionally played run should finish around 05:00. Human time also includes paused card selection.
3. Pulse and seekers start at level 1. Aegis and Nova start at level 1. Four passive tracks start at zero. Thus the slice has **36 upgrade picks**, not 63. It normally offers approximately 14–20 choices depending on kills. This gives room to specialize without filling every track.
4. In the full game, the old 43-pick base capacity and 63-pick expanded capacity must each have a defined upgrade budget. Do not use the expanded total to justify base-ship specialization. Forty choices over 24–28 combat minutes means an average of 36–42 combat seconds between choices, not 30. Total session time includes draft pauses.
5. Only one heavy lane may charge at a time. Telegraph is 1.8 s; heavy scheduling is globally spaced by 10 s during waves and 8.5 s against the boss. Single heavy hits are at most 35 base hull. Nova interrupts bosses as well as regular enemies. Beam collision follows the previewed ship position.
6. Seekers target a charging source first, then ordnance, then the nearest enemy. Pulse fires forward. This makes target selection a property of the build, without adding aiming.
7. Final-ten-second events include sources, shield breaks, upgrade and ability decisions, and cooldown availability at death, alongside damage by class and weapon.
8. Matched-seed bots are part of the first milestone: never activate, activate immediately, and react to threats. They use identical card-choice policies. Require timed play to improve clear rate over no input and improve surviving hull or clear rate over immediate activation. Preserve a clearable base ship; do not add a mandatory Hangar grind.
9. Exact checkpoints preserve all simulation state, RNG state, current hand, outstanding level-ups, and cooldowns. Drafts freeze simulation. Saves are atomic on the native filesystem and stored through Godot's browser persistence on web. Save identity prevents repeated payout on the same resumed run.
10. A small Hangar proves the run loop; it does not gate the abilities required for the first-run experience. Extra ships, slots, prototypes, rerolls, and three additional levels remain later content.

## Verification limits

Headless simulation measures rules and bot performance. It does not prove real-hardware 60 fps, human readability, controller ergonomics, browser persistence on Safari, or storefront integration. These require the explicit gates in NATIVE_DELIVERY.md and external playtesting.

## Current automated result — v0.2

With no Hangar upgrades, the twelve fixed seeds in `tests/run.gd` produced 12/12 clears for both timed and immediate activation. Timed activation retained 142.0 hull on average versus 118.5 for immediate activation; no activation cleared 0/12, with mean survival of 127.1 seconds. These results use the new seeded flight course; the earlier six-second weave produced different outcomes. Card decisions use the same policy across all three cohorts. These small, fixed cohorts are regression checks, not a player difficulty estimate; they do not replace the human fun gate.

All 36 simulation assertions and 18 responsive-layout checks pass. Layout checks cover 375×667, 390×844, and 1280×800 logical windows. Native desktop launch, the new illustrated ships/backdrop, draft selection, Aegis, and pause were exercised visually. Web, Windows, and Linux exports completed; Windows has not been run on a Windows machine. The cloud browser lacks WebGL2, so browser gameplay could not be visually verified there. Human listening and physical-device performance checks remain open.
