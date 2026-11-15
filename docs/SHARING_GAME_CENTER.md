# Star/Run 0.9.1 — sharing, native achievements, leaderboard and branding

## Player-facing features

- **Share a Daily score:** Results has **Copy & share today's scorecard**. This copies a short, plain-text card containing the original UTC day, achieved score, Worlds cleared (or full victory), ship, pilot and #StarRun. It does not publish player information, reveal the full draft, or require an account. The user pastes the copied card into messaging/social apps. This is **copy-to-clipboard**, not an automatically opened native iOS share sheet.
- **Achievement unlock notifications:** The game queues short, nonblocking banners after a completed run, with a small success sound. Each new award appears in order; none interrupt combat. Awards remain saved in the local profile.
- **App title:** The Godot project, web loading page/HTML title, app icon and generated iOS icon all use **Star/Run** with the amber slash motif. The bundle ID stays **com.rsm.starrun**; changing it would break continuity of the TestFlight app and saved progress.
- **Online Daily rankings (iPhone):** The optional Game Center menu opens the native daily leaderboard when the iPhone player is authenticated and the matching leaderboard exists in App Store Connect. The same UTC seed, ship, pilot, Normal difficulty and zero Hangar rules apply. The best score from the *current* UTC day is submitted, and Apple's recurring board resets at 00:00 UTC. Older daily scores remain local rather than being mistakenly submitted into today's board. Achievements are reported at 100% when earned and confirmed by Apple, using matching identifiers.
- **Offline and other platforms:** All local achievements, local best score, clipboard sharing and UI work without Game Center. This integration has no Steam/web/Windows leaderboard and does not claim cross-platform synchronization.

## Apple Game Center implementation

Godot iOS builds install the **pinned GameCenterKit 1.0.1** release from \`keremvatandas/godot-ios-gamecenter\`. A GitHub-published SHA-256 is verified before extraction. The addon is installed only into macOS CI's temporary Godot checkout, not into Web/Windows/Linux builds. The iOS export enables \`entitlements/game_center=true\`; GameKit is embedded by the addon. The app checks for the native singleton before calling it.

\`data/game_center.json\` declares:
- Bundle ID: \`com.rsm.starrun\`
- Recurring BEST_SCORE leaderboard ID: \`com.rsm.starrun.daily\`
- Recurrence: \`FREQ=DAILY;INTERVAL=1\`, duration \`PT24H\`, next start at UTC midnight
- All 17 local achievements with IDs \`com.rsm.starrun.<achievement_id>\`, English titles/descriptions, 785 total points (100 max each, 1000 total Apple ceiling).

\`tools/render_game_center_artwork.py\` generates **17 opaque, RGB, 1024×1024, 72 ppi** PNG badges, suitable for the App Store Connect artwork requirements. They were successfully uploaded and committed in App Store Connect by the [achievement art workflow](https://github.com/killjoy00/EZTrivia/actions/runs/43748596068), and are also preserved as a GitHub Actions artifact. They are not distributed as font files.

\`tools/provision_game_center.py\` is an idempotent Apple API provisioner for the existing App Store Connect app. It created the Game Center detail, recurring UTC Daily board, English localization, 17 achievement definitions and English descriptions on [November 15, 2026](https://github.com/killjoy00/EZTrivia/actions/runs/43748388148), then uploaded and committed all 17 badge images [successfully](https://github.com/killjoy00/EZTrivia/actions/runs/43748596068). It refuses to silently reconfigure an existing Daily board with incompatible recurrence or Apple achievements with mismatched permanent point values.

The approved-commit workflow lives in the shared Apple-credential repo at \`killjoy00/EZTrivia/.github/workflows/starrun-gamecenter-setup.yml\`. It is triggered through a new \`.github/starrun-gamecenter-request.json\` on that repo's main branch, selecting an immutable reviewed StarRun SHA. **No Apple credentials or IDs are committed into StarRun.**

## Apple gates that cannot be inferred from a successful code build

1. App Store Connect's Game Center detail for **com.rsm.starrun** is enabled, and the app's 0.9.1 signed archive/upload succeeded with the Game Center entitlement. Actual native Game Center sign-in remains unverified.
2. The Game Center detail, recurring UTC Daily board, 17 achievements and their English localizations were created successfully on November 15, 2026.
3. The 17 localized **1024×1024 artwork files have been uploaded and committed successfully** to App Store Connect. Confirm Apple finishes processing each image in its UI before submitting components for review.
4. The first Game Center leaderboard and achievement releases must pass Apple's review/publication rules. A successful TestFlight binary upload is not proof that Apple made those metadata resources live.
5. Native authentication, personal-best submission, award sync, and Game Center panels need an actual iPhone with Game Center signed in and an App Store Connect sandbox/TestFlight build.

Only after (1)–(5) pass should the game be advertised as having **live online rankings and Apple-approved achievements**. Until then, local progression and clipboard sharing are fully functional. The app should not display a nonfunctional leaderboard button outside iOS and can show a clear Game Center sign-in/availability message on iOS.

## Explicitly not in scope

No daily seed version labels, no dedicated Daily history screen, no new difficulty balance changes, no monetization changes, and no universal leaderboard shared with Steam or web. Game Center is Apple's service; authenticated results are not independently anti-cheat verified by the game.
