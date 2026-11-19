# Android / Google Play delivery

## Status

Star/Run is a **Godot 4.6.3** game with a single shared GDScript gameplay tree across
iOS, Web, Windows, Linux and Android. The Android preset is configured to produce a
Google Play **Android App Bundle (AAB)** under the package ID `com.rsm.starrun`.

- Player-facing name: **Star/Run**. Android `versionName` initially `1.3`; versionCode `1`.
- Target: **Android API 36** (Android 16), minimum API 26, arm64 and x86_64.
- First release: **free and ad-free**. No Android AdMob SDK, purchase or Play Games
  Services integration is claimed. Local saves, Daily scores and achievements remain available.
- Same gameplay and progression as the current main branch; Android Game Center is disabled.
- Icon: generated from the existing original `assets/icon.svg`, not a substitute design.
- CI workflow: [Android Play AAB build](../.github/workflows/android.yml) checks that a
  signed AAB can be produced using a **temporary CI-only key**. Never upload this
  disposable-key artifact to Google Play; it is not the production upload key.

Android cannot be called tested on a real phone until a physical Android device has
been used. Rendering, touchscreen, insets, state persistence, resume/background,
60 Hz pacing, daily date rollover and four-world boss battles need hardware checks.

## Automated export and signing

The canonical export is `bash tools/android-export.sh` on a runner with
OpenJDK 17, Android SDK 36 and pinned Godot 4.6.3. It downloads matching Android
export templates, rasterizes the original logo with Godot, imports the game,
performs a script smoke test, installs the Android Gradle template, and exports
`build/android/StarRun.aab`.

The command requires Godot's standard release signing environment variables
`GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`,
and `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`. Signing credentials are **not**
committed to this public repository. The shared EZTrivia release workflow should
use its existing Google Play service account and upload keystore, with its
publisher permissions explicitly checked for the new Star/Run app.

A publishing runner can provide `STARRUN_ANDROID_VERSION_CODE` and
`STARRUN_ANDROID_VERSION_NAME` to stamp a build number into its disposable
checkout. Never reuse a Play versionCode; no iOS marketing version is changed.

## Google Play account steps (one-time, browser only)

1. In [Google Play Console](https://play.google.com/console), click **Create app**.
   App name **Star/Run**, app type **Game**, free, default language **English (United States)**.
   Use Android package name **`com.rsm.starrun`**, if available.
2. Complete Play app signing enrollment. If asked, choose Google's managed app-signing
   key; the GitHub release workflow supplies the **upload** key. Do not upload a
   temporary CI-key build. Give the existing Play service account access to this
   new app's testing tracks if its current permissions are app-scoped.
3. Complete the **Games** listing, support email, public privacy policy URL,
   data safety, content rating, target audience and content declarations. Declare
   the actual shipped ad-free binary; do not claim Android ads, online leaderboards
   or purchases before they exist. Privacy-policy draft: [PRIVACY.md](../PRIVACY.md).
4. Upload the Play-signed AAB to **Internal testing** using the shared release
   workflow, then add testers and verify launch and restore on Android hardware.
   This is **not** a production release.
5. After Android verification, start any required **closed testing** and obtain
   production access before promoting to a public launch. Personal developer
   accounts created after November 13, 2023 generally require at least **12 opted-in
   testers continuously for 14 days** before requesting production access.
6. Final public publication and countries/territories must be authorized separately.

## Play listing draft

**Title:** Star/Run

**Short description:** Build a powerful ship in a four-world tactical space roguelite.

**Full description:**

Your ship flies and fires automatically. Your job is choosing the upgrades that
change how it fights and saving your abilities for the moments that matter.

Fly through four worlds with different enemies, weapons, and bosses.
Pick from six ships and six pilots, build powerful combinations from active
abilities and passive upgrades, and choose your route after every boss fight.

Spend earned Cores on permanent Hangar upgrades. Return stronger, try a different
ship, or tackle a tougher difficulty. Daily Challenges give you a fresh run to
compare against your own best.

There's no steering or aiming. Star/Run is about build choices, tradeoffs and
deciding when to use the abilities you have.

Use genuine game captures (not mock cards) for phone screenshots, ideally from
a production-signed Android build. Suggested order: combat and ability buttons;
three-way upgrade; world/boss; route selection; Hangar; ship and pilot; Daily.

## Release guards

Do not publish to `production` in the first pipeline. An Android AAB build
and a Play Internal release do **not** establish physical-device readiness,
store policy approval, or eligibility for production. Reuse Google Play signing
and API credentials through the shared EZTrivia repository; do not copy private
credentials into StarRun or any PR branch.
