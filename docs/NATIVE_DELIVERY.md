# Native delivery and human playtest gates

**Updated for StarRun v0.7.0 TestFlight beta.** Godot 4.6.3 is pinned. Changing engine versions or renderers requires repeating all exports, gameplay tests and on-device performance checks.

## Automation now working

The StarRun repo has deterministic 60 Hz simulation, save/checkpoint regression tests, strict Godot script parse checks, phone-layout UAT checks, and Web/Windows/Linux playable exports in GitHub Actions. A native iPhone Xcode project is compiled without signing in StarRun CI.

The signed TestFlight workflow resides in **killjoy00/EZTrivia** and reuses that repo's existing Apple credentials. The StarRun **0.7.0 (build 1007)** upload succeeded in the [shared TestFlight workflow](https://github.com/killjoy00/EZTrivia/actions/runs/43546788036), using immutable source commit `c9ea98f205dca4ae175f02d84cae0c277f17acde`. This verifies signing and delivery to App Store Connect, **not** Apple processing, tester assignment, physical-device usability, ads or any purchase integration.

No Vercel dependency is required. CI prevents nonfatal Godot parser errors from slipping through an otherwise green iOS export.

## Still required before claiming iPhone launch readiness

1. **Physical iPhone UAT:** test small and current portrait aspect ratios, safe areas, four ability buttons, card wrapping, and menus. Verify four single-row ability controls, every draft option visible at once without scrolling, Build detail collapse/expand, and exact draft preservation on resize/resume.
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
for behavior and verification. Signing/upload status is recorded after delivery.
