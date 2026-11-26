# Notes for Claude

- The owner does NOT merge pull requests. Claude merges its own PRs (squash) once CI is green, then continues the release flow.
- Develop on the `claude/elegant-allen-ml1shu` branch; open PRs as drafts, mark ready and merge after checks pass.
- Releases are requested from the EZTrivia repo: `.github/starrun-release-request.json` (TestFlight) and `.github/starrun-android-release-request.json` (Google Play; keep `release_status` as `draft` unless the owner asks for a release).
- Difficulty targets (Normal, full campaign): no Hangar never finishes, mid Hangar (p32) wins 40-60%, max Hangar wins 70%+. Measure with the Difficulty experiment workflow.


## CI test selection

See [CI validation tiers](docs/CI_VALIDATION_TIERS.md). Keep core regression checks on every PR. Development preview pushes on codex/** defer the long replay and ordinary campaign matrices to PR/main/manual validation; retain lightweight startup/UI checks and playable exports. Use targeted destination/Archive smoke and conservative change scope for expensive simulation/native jobs. Run the complete checkpoint/cross-ship research manually for major relevant balance work or public release acceptance; do not automatically restart the full research matrix after a UI or localized tuning change. Preserve assertions and distinguish frozen-gate replays from natural campaigns.

## Portfolio mobile releases

The canonical app registry, read-only dashboard and standard release request protocol are in [mobilereleases](https://github.com/killjoy00/mobilereleases). Read its current README and registry before any release request. Star/Run signed releases remain in EZTrivia. Retain both existing request files and their existing draft/testing safeguards. Follow this repository's existing tests, release authorization and app-specific requirements. Never equate a successful workflow with store availability or publish to production without explicit owner approval. Report store stages separately and sanitize public evidence.
