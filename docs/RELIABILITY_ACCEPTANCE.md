# Code-first acceptance for Game Center, Silent Archive and gameplay (PR #58)

This combines the automated portions of issues #23, #49 and #51. It does **not** certify Apple's Game Center review, TestFlight processing, audio/haptics on hardware, or player enjoyment. No public App Store release is implied.

## Game Center / issue #23

- The bridge uses the existing iOS-only `GameCenterKit` singleton and handles native callback IDs only when a corresponding request is actually pending.
- Failed/duplicate/mismatched network callbacks are ignored or left retryable; signing out removes a pending lock so the next authenticated session can retry. Native callbacks cannot be correlated across different attempts of the same leaderboard identifier because the SDK does not expose a request ID; we do not claim stronger guarantees than the plug-in provides.
- Daily sync uses the current UTC day, not the date of a suspended older Daily. Improved same-day replays replace the previously acknowledged score.
- `open_frequency` remains a local-only discovery achievement and is never sent to Apple. Any unknown/unsupported achievement is also skipped.
- `tests/game_center_contract.gd` checks native method/signal semantics, failures, reconnect, UTC reset, replay improvements and exact resource-manifest identifier parity.

Still required: verify Apple's board/assets processing and review, signed-in native leaderboards/achievements on an iPhone, sign-out behavior, and native share-sheet delivery.

## Silent Archive / issue #49

- `tests/reliability_matrix.gd` saves and restores live boss warnings on all three difficulties, checks coordinate offers survive app restarts, and verifies ending settlement is exactly once.
- `tests/warning_window_audit.gd` prints actual boss charged-warning durations at 1x and 3x and separate *estimates* for stage-three/four projectile travel, marking values below **0.80 seconds** for human review. This is an **observational threshold**, not a fairness gate or an automatic reason to increase invulnerability. The value is adjustable after real playtesting.
- The actual drawing test captures World 3, World 4 and Custodian phases (three each) at 540x960 with full/reduced effects; consult the `StarRun-combat-readability` artifact.

Still required: touch-control reaction at 3x, device haptics and sound, safe areas and clarity during crossfire, physical sleep/resume, and whether the phase pacing is fun.

## Quartermaster, mutations and general gameplay / issue #51

- After an accepted trade, `merchant_state = "receipt"` is persisted. The purchase has already happened exactly once; the game pauses with the receipt until the player taps Back to the game. A crash or home-screen return cannot hide the receipt or reapply the payment.
- A new merchant hail is postponed (not permanently consumed) when an Archive signal is unresolved, a Rival Captain notification is pending, or a draft is active. Rival arrivals are likewise deferred during modal trade or coordinate decisions.
- Closing an earlier modal surfaces the outstanding signal. `tests/event_overlay_smoke.gd` covers actual UI screens at 360/390 logical widths, including restarting after preview/confirmation and again after trade.
- `tests/reliability_matrix.gd` exercises state immutability and exactly-once settlement over multiple fixed seeds. Daily retains no Quartermaster or coordinate signals.

## Balance audit (observational only)

New `.github/workflows/reliability-audit.yml` reuses genuine seeded combat tools rather than making scripted boss kills or injecting upgrades:

- Kestrel, Arcwing and Haven: Normal/Hard, 6 distinct fixed seeds per cell, empty Hangar, legitimately offered draft picks, time/level/crowd/empty-screen data.
- Kestrel/Arcwing merchant: naturally encountered hails, decline versus Hot Reactor versus available mutation (3 matched seeds per ship), true paid costs and stage reach.
- Vanguard/Arcwing mutations: 2 matched seeds each, genuine World 1, World 2 checkpoint shared with unmutated and eight paid-cost variants.

These are **scripts**, not human win-rate estimates. They are intended to surface repeatable defects or extreme concentration, not to force every build to win. Review GitHub Actions logs/artifacts before any subsequent difficulty tweak.

## Merge / release checklist

1. Green Game Center mock, event UI, save/restart, warnings, World 1, market and mutation workflow.
2. Green pre-existing simulation/replay, UI, real four-world/Archive, six-ship smoke, and unsigned iPhone export.
3. Review any severe difference between old/new supported behavior. Do not modify the Daily schedule, monetization, native signing secrets or publish to the App Store.
4. Merge as a single PR only when all required final-head checks pass. **Request a separate private TestFlight** after merge, then perform the three remaining hardware/Apple acceptance tasks.
