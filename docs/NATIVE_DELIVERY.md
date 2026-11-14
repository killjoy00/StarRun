# Native delivery and human playtest gates

**Updated November 13, 2026.** Godot 4.6.3 is pinned. Changing engine versions or renderers requires repeating all exports, gameplay tests and on-device performance checks.

## Automation now working

The StarRun repo has deterministic 60 Hz simulation, save/checkpoint regression tests, strict Godot script parse checks, phone-layout UAT checks, and Web/Windows/Linux playable exports in GitHub Actions. A native iPhone Xcode project is compiled without signing in StarRun CI.

The signed TestFlight workflow resides in **killjoy00/EZTrivia** and reuses that repo's existing Apple credentials. The StarRun **0.4.0 (build 1004)** upload succeeded and Apple accepted it on November 13. That verifies delivery to App Store Connect, **not** physical-device UX, Apple processing status, tester-group assignment or any advertising/store functionality. Later StarRun gameplay versions are not TestFlight-delivered until their specific release upload passes.

No Vercel dependency is required. CI prevents nonfatal Godot parser errors from slipping through an otherwise green iOS export.

## Still required before claiming iPhone launch readiness

1. **Physical iPhone UAT:** test small and current portrait aspect ratios, safe areas, four ability buttons, card wrapping, and menus. On the v0.5 game specifically test a Build view with many installed systems and Hangar upgrades, a long Results report, fixed bottom navigation, and a saved run resumed after returning to the main menu.
2. **Four-stage walkthrough:** verify Ion Storm, Solar Foundry and Void Citadel have distinct palettes and silhouettes in motion, not merely color filters; validate ten new enemies' attack shapes and damage labels; check that each boss victory plays a visible multi-burst explosion, displays the reward/next destination and cannot be skipped unintentionally. Tap Warp/Claim and verify the transition and correct saved state.
3. **Performance:** sustained normal gameplay and dense projectile stress (including ≥500 enemy bullets and 100 player shots, then a 2,000/500 engineering probe) at 1× and 3× speed. Record device, thermal condition, p50/p95 frame time and visual clarity. Compact projectile storage/render batching remain separate optimization options if the benchmark fails.
4. **Audio / accessibility:** heavy attack cue remains audible; large explosions and warp do not obscure the next UI choice. Validate reduced glow and screen sensitivity, VoiceOver expectations, contrast, readable minimum 16-point phone text and ≥44-point touch controls.
5. **Ads integration:** test a maintained iOS plugin and Apple tracking consent/no fill/offline/failure paths without interrupting deterministic combat. No ad flow is claimed working.
6. **StoreKit:** test a real non-consumable purchase, refund and restore, pending/cancelled purchase, clean install and entitlement recovery. No purchase flow is claimed working.

## Steam still required

Prove an exported build through Steam with Steam Deck controller play, real achievement, and cloud-save conflict handling. A signed iPhone upload or unsigned Linux/Windows build does not establish Steam readiness.

## Human fun gate

With one fixed signature and up to three drafted actives, players should describe why they held an ability for a specific attack, feel that level-ups matter, and voluntarily try another build. Check progression on Normal/Hard/Insane and whether Stage 2–4 pressure ramps without sudden unavoidable damage. A maxed-out ship clearing Stage 1 easily is **intentional**. Bot scores are test diagnostics, not evidence of human enjoyment.
