# CI validation tiers

The #92 release was blocked by a research matrix, not a functional failure.
At its approved merge, 13/14 active checks passed; the 59-job checkpoint study
was still running. Sample individual route jobs spent 21.8–31.2 minutes in
simulation alone, plus substantial runner queues. Source: run 45509801237,
jobs 138854633458, 138854633535, 138854633619, 138854633663.

## Routine PR checks

- Playable simulation / parse / first flight / persistence / UI and layout
  stay unconditional. Ordinary full-campaign smoke runs for ordinary simulation
  changes. Native and desktop exports run for relevant source/assets/export
  changes, not documentation or isolated test-only edits.
- Destination smoke: seven representative ship/budget/policy cells, two seeds
  each (14 campaigns vs 336 in the research grid). Real offered destinations
  and production branches; check reward/identity, no timeout, curated choices,
  all four changed destinations. Independently replay the first seed's first
  reached warp; otherwise reuse the selected already-flown fork. The full
  experiment still independently replays every warp.
- Archive smoke: phase/save/restore fixtures across all 21 ship/difficulty
  cells and eight known qualifying **frozen baseline** gates (two per selected
  loadout). Includes previous Insane failures Bulwark 833757 and Kestrel
  825838 / 841676. On cache miss, generate genuine gates with the immutable
  #92 merged source, not a fabricated checkpoint. Verify identity, snapshot
  roundtrip, real signals, payout, all phases, wins and no timeouts under both
  policies. Cache is scoped by baseline + harness hash + loadout. A replay
  verifies current boss behavior, not current gate qualification rates.
  If save schema changes, deliberately update the pinned fixture baseline and
  requalify the known cases; never silently regenerate a fabricated win.
- Fleet, persistent progression, and Endless experiments are selected only
  for relevant changes. Their original sample sizes and assertions remain.
  Shared simulation helpers or unknown dependencies conservatively trigger
  all gameplay checks. Archive-only edits are recognized only for a narrow
  allowlist of existing functions, not arbitrary matching text. The core
  suite is never skipped by this classifier.

## Full research (Actions > Run workflow)

Run **Full destination and Archive checkpoint research** with all, routes or
archive for major redesigns or a deliberate deep audit. It keeps all 42 route
cohorts / 16 Archive cohorts and all eight seeds, original historical controls,
independent replay checks and reports. No routine pull request auto-trigger.
Run **Silent Archive cross-ship real-campaign review** for changes to entry
eligibility, draft builds, signal routing or major Archive balance, or before
a public release: all 84 natural campaigns and 21 loadouts, not just frozen
gates. Manual ordinary fleet/progression/Endless workflows remain available.
Do not treat fewer passing smoke cases as equivalent statistical evidence.

Target routine PR latency: 15 minutes (target, not a measured result). Cold
frozen gate generation and runner congestion may exceed this; compare actual
logs and wall time before claiming improvement. No change to gameplay,
signing, branch protections, or public release policy.
