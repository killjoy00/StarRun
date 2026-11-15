# Native delivery and human playtest gates

**Updated for StarRun v0.8.1 TestFlight beta.** Godot 4.6.3 is pinned. Changing engine versions or renderers requires repeating all exports, gameplay tests and on-device performance checks.

## Automation now working

The StarRun repo has deterministic 60 Hz simulation, save/checkpoint regression tests, strict Godot script parse checks, phone-layout UAT checks, and Web/Windows/Linux playable exports in GitHub Actions. A native iPhone Xcode project is compiled without signing in StarRun CI.

The TestFlight workflow resides in **killjoy00/EZTrivia** and reuses its existing Apple API credentials. **StarRun 0.8.1 (build 1011) uploaded successfully** in the [shared release workflow](https://github.com/killjoy00/EZTrivia/actions/runs/43678788579), from immutable source `17e60c879349923dcee00e7a6a1e78ffc78adab7` ([PR #16](https://github.com/killjoy00/StarRun/pull/16)). Logs confirm version 0.8.1, build 1011, the verified `com.rsm.starrun` archive, `Upload succeeded` and `EXPORT SUCCEEDED`. It includes the rank-5 fusion and visual changes in PR #15, separate menu redesign in PR #12, combat readability/rerolls in PR #13 and progression/iPhone fixes in PR #14. This confirms App Store Connect delivery; Apple processing, tester availability and physical-device acceptance were not verified. The previous successful beta was [0.8.0 build 1009](https://github.com/killjoy00/EZTrivia/actions/runs/43666519593).

Build 1010 failed before upload because automatic archive signing attempted to create another Apple Development certificate after the account reached its certificate limit. The StarRun release workflow now signs every binary locally with an ad-hoc identity during archive, verifies the complete archive, then uses Apple-managed distribution signing during export/upload. This preserves embedded-code signatures without consuming another disposable development certificate. No existing certificate was revoked and no other app's signing workflow was changed.

No Vercel dependency is required. CI prevents nonfatal Godot parser errors from slipping through an otherwise green iOS export.

## Still required before claiming iPhone launch readiness

1. **Physical iPhone UAT:** test small and current portrait aspect ratios, safe areas, four ability buttons, card wrapping, and menus. Verify four single-row ability controls, short drafts visible at once and long drafts scrollable by holding any card, Build detail collapse/expand, and exact draft preservation on resize/resume.
2. **Four-stage tactical walkthrough:** verify Ion Storm, Solar Foundry and Void Citadel have distinct palettes and silhouettes in motion; check destructible launch bays, cooling vents and shield pylons actually change boss behavior, and the phases are obvious without manual aiming. Verify boss explosions and explicit Warp/Claim, one-of-three Prototype offers, Safe/Redline/Bounty routes and correct saves/resumes during each decision.
3. **Performance:** sustained normal gameplay and dense projectile stress (including ≥500 enemy bullets and 100 player shots, then a 2,000/500 engineering probe) at 1× and 3× speed. Record device, thermal condition, p50/p95 frame time and visual clarity. Compact projectile storage/render batching remain separate optimization options if the benchmark fails.
4. **Audio / accessibility:** heavy attack cue remains audible; large explosions and warp do not obscure the next UI choice. Validate reduced glow and screen sensitivity, VoiceOver expectations, contrast, readable minimum 16-point phone text and ≥44-point touch controls.
5. **Ads integration:** test a maintained iOS plugin and Apple tracking consent/no fill/offline/failure paths without interrupting deterministic combat. No ad flow is claimed working.
6. **StoreKit:** test a real non-consumable purchase, refund and restore, pending/cancelled purchase, clean install and entitlement recovery. No purchase flow is claimed working.

## Steam still required

Prove an exported build through Steam with Steam Deck controller play, real achievement, and cloud-save conflict handling. A signed iPhone upload or unsigned Linux/Windows build does not establish Steam readiness.

## v0.7 specific acceptance

Check ten active fusions for one-button use and a freed slot; test four occupied slots when a valid partner is offered; verify eight passive pairs and rank 5/10 bonuses (including legacy checkpoint migration); check that the new Stage 1 turret is recognizable and that no mobile screen requires four-card vertical scrolling. [GAMEPLAY_V07.md](GAMEPLAY_V07.md) specifies individual cases. Signed v0.7 build 1007 uploaded successfully. Apple processing and physical iPhone acceptance remain outstanding.

## v0.7.1 menu redesign acceptance

v0.7.1 changes only screens outside combat (title, settings, briefing, Hangar, Ships & pilots, draft, pause, Build, boss clear, prototype, route, results). Gameplay, balance and the combat HUD are unchanged. Automated: 209 responsive UI checks and 409 simulation assertions. On a physical iPhone, check:

- **Safe area:** title wordmark, back buttons and wallet sit below the Dynamic Island or notch; bottom buttons and sheets clear the home indicator. The insets come from `DisplayServer.get_display_safe_area()` converted to canvas units and have not been seen on hardware.
- **Touch:** whole draft, prototype, route and ship cards respond to a tap; a tap arriving as a draft opens (within 0.35 s) is ignored; hover/pressed outlines do not stick after a tap.
- **Confirmations:** ship/pilot unlock and Refund all need a second tap; Launch over a saved flight shows the abandon sheet; Cancel returns without changes.
- **First run:** a fresh install shows the four-step briefing on the first Launch only.
- **Known open item:** the combat HUD still starts 16 pt from the top edge and may sit under the Dynamic Island. Out of scope for this menu pass.

## Human fun gate

With one fixed signature and up to three drafted actives, players should be able to identify active Fortress/Glass Cannon/Control/Salvager combos, explain tradeoffs of the Prototype and route choices, and describe why they held an ability for a specific boss phase. Monitor decision comprehension and voluntary replays. Check progression on Normal/Hard/Insane and whether Stage 2–4 pressure ramps without sudden unavoidable damage. A maxed-out ship clearing Stage 1 easily is **intentional**. Bot scores are test diagnostics, not evidence of human enjoyment.

## v0.7.2 combined beta

This release includes the menu redesign from PR #12 (merged at `7cf7c42`) plus
combat readability, immediate fusion/rank milestone cues and the permanent
per-stage reroll correction. See [ART_AUDIO.md](ART_AUDIO.md#combat-readability--november-13-2026-central)
for behavior and verification. **Build 1008 was signed and uploaded successfully on November 13, 2026 at 10:03 p.m. Central.** The upload log confirms `Upload succeeded` and `EXPORT SUCCEEDED`. Apple reported the package was processing; tester availability has not been independently confirmed. The release passed 584 simulation assertions, 209 layout checks, 85 rendered visual checks, all playable exports and the native iPhone compile.

## v0.8.0 progression and iPhone input

Includes the PR #12 menu redesign and PR #13 combat readability pass. This candidate raises world 2–4 pressure, adds ten passive tracks, removes consumed fusion-component offers, and upgrades fused skills directly. Combat HUD geometry uses the device safe-area insets and a separate toolbar row. Native scroll handling now receives drags starting on cards, icons, text and purchase buttons; dragging cancels the pending button action.

`tests/touch_and_safe_area.gd` exercises actual viewport press/hold/drag/release events under Godot's touchscreen emulation, including both drag directions, no accidental purchase/selection, a subsequent normal tap, simulated 59-point cutout/34-point home inset, and HUD/toolbar separation. This is automated desktop emulation; physical iPhone acceptance remains the next device check. See [GAMEPLAY_V08.md](GAMEPLAY_V08.md) for measured balance results and upgrade details.

Release verification: 679 simulation assertions, 209 responsive layout checks, 85 rendered readability checks and 43 touch/safe-area checks passed. The [playable pipeline](https://github.com/killjoy00/StarRun/actions/runs/43666158013) produced Web, Windows and Linux builds; the [native iPhone pipeline](https://github.com/killjoy00/StarRun/actions/runs/43666157996) also passed before signing. The exact reviewed source tree was verified again after merge, including ancestry of both earlier visual passes.


## v0.8.1 Hangar, pilots and fusions

- **38 permanent Hangar tracks:** 16 added across hull, weapons, abilities, tactics and salvage. Existing purchases and refund values are preserved; new tracks default to zero for older profiles. See [HANGAR_EXPANSION.md](HANGAR_EXPANSION.md).
- **Six pilot portraits:** painted face portraits replace the pilot symbols on selection cards and the equipped pilot on the menu. Portraits preserve touch scrolling and fit narrow phone layouts. See [PILOT_ART.md](PILOT_ART.md) for assets and generation prompts.
- **22 active abilities:** Wing Drones provides temporary escorts; Ion Mine places an armed proximity blast. Both at rank 5 combine into Storm Carrier, which occupies one slot.
- **11 fusions:** both component abilities must reach rank 5 before fusion. Each has a distinct icon and cast effect; formation feedback remains visible through the paused draft transition. Earned legacy fusions remain intact, while invalid old draft offers are refreshed safely. See [GAMEPLAY_V081.md](GAMEPLAY_V081.md).
- The tougher later worlds, ten additional passives, notch clearance, ability/passive labels, consumed-component filtering and native menu hold-drag fixes from v0.8.0 remain included.

Release verification: **904 simulation assertions, 209 responsive layout checks, 91 readability checks, 106 fusion-rendering checks, 44 expanded Hangar/portrait checks and 47 touch/safe-area checks passed.** The [playable pipeline](https://github.com/killjoy00/StarRun/actions/runs/43677614317) also exported Web, Windows and Linux, and the [native iPhone pipeline](https://github.com/killjoy00/StarRun/actions/runs/43677614291) compiled successfully. The merged tree `1df98871e4b41615f1bd5b337dd43421f7c664d1` exactly matches the tested PR.

On iPhone, check pilot-face scrolling, new Hangar purchases, Wing Drones/Ion Mine through world transitions and save/resume, rank-5 fusion offers and cast visibility, top safe-area clearance and dense-combat performance. Automated rendering and touch emulation do not replace this device check.
