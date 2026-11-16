# Star/Run: AdMob banner and store setup

## Current state

- **0.9.4 (1019)** was already uploaded to TestFlight from source `fd5cb98e`. It has **no live AdMob SDK/banner**.
- The next candidate uses the [Poing Godot AdMob v5.1.0 iOS SDK](https://github.com/poingstudios/godot-admob-plugin/releases/tag/v5.1.0), pinned by checksum in `tools/install-admob.sh`, only when a deliberate iPhone ad configuration or the branch's Google test mode enables it.
- The native ad banner is on **title and results screens only**. No banners during combat, upgrade choices, boss fights, route/prototype selections, or on Web/Windows/Linux.
- A successful ad load reserves 64 logical points above the bottom safe area for the title/results footer. A no-fill, SDK failure or unavailable consent means no ad and no layout reservation. Ads cannot affect gameplay time or save data.
- Consent refreshes every app launch through Google's UMP; **no banner request is sent until UMP reports obtained/not-required consent**. A failed request/form keeps ads hidden. A Settings privacy action is displayed when UMP says it is required.
- The repository commits **no private Google account credentials**. `data/admob.json` starts `enabled=false`. CI uses Google's sample App ID/banner ID only on the research branch. No auto-deploy or TestFlight upload of the ad build.

## Your steps: AdMob (mobile browser works)

1. Open [Google AdMob](https://admob.google.com/) and sign in or create a publisher account. Complete any account verification requested by Google.
2. Go to **Apps** and choose **Add app**. Choose **iOS**, with the app name **Star/Run** and existing bundle ID **`com.rsm.starrun`**. If it's not yet publicly listed, use the **not listed in a supported app store** option if shown; you can link the existing App Store record later.
3. Copy the **App ID**, which looks like `ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX`. This is *not* your Google account ID or the ad unit ID.
4. Within that iOS app, choose **Ad units > Add ad unit > Banner**. Name it `StarRun iPhone Banner`, save it, then copy its **Ad unit ID**, which looks like `ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX`.
5. Under **Privacy & messaging** in AdMob, configure and publish the required consent / privacy messages for the intended audience and jurisdictions (at minimum review EEA/UK and applicable US state privacy rules). If prompted about children or age classification, answer for the actual intended audience. Don't guess or switch off required notices to get ads displaying.
6. **Send me only those two AdMob identifiers** (App ID with `~` and banner unit ID with `/`) and tell me whether the Privacy & messaging setup is published. They are public placement identifiers, not secret keys; **do not send passwords, private keys, or billing details**.
7. I can then put those values in the reviewed iOS release configuration, rerun CI, and prepare a **new TestFlight-only** candidate. We should first verify a Google **test ad** appears on an iPhone before making live ad requests.

### Ad review checklist

- No actual ad on the flight HUD (overlays would cover four ability slots), menus with touch decisions, or transition cards.
- Failure/no fill/consent denied leaves the game completely playable, with no fake ad placeholder.
- Banner only appears on menu/results if it loaded, with navigation safely above it.
- Verify banner is not under the home indicator on physical iPhone.
- If targeting or tracking involves Apple's IDFA, the required App Tracking Transparency permission and Apple App Privacy disclosures must be handled before using that tracking behavior. Do not imply Apple authorization from CI.
- Update a publicly hosted privacy policy with accurate Google/Apple SDK data disclosures **before live ads or store submission**.
- Ads can be turned off by config if native bugs arise. **Remove Ads IAP is not implemented** and is a separate feature requiring StoreKit / entitlement tests.

## Your steps: App Store listing

1. Open [App Store Connect](https://appstoreconnect.apple.com/apps). Select the **existing StarRun app** with bundle ID `com.rsm.starrun`. Do **not** create another iPhone app record.
2. In **App Information**, set the visible name to **Star/Run** when your current version is editable. Keep the bundle ID unchanged.
3. Under an editable iOS app version (if none exists, start a new version when allowed), paste the subtitle, promotional copy, full description and keywords from [APP_STORE_LISTING.md](APP_STORE_LISTING.md).
4. Select category **Games** and appropriate game genres, answer the current age-rating questionnaire based on stylized combat and actual ad creatives, and choose where the game will be available. The game currently targets **iPhone portrait**.
5. Put a functioning, public **Support URL** in the required field. Publish a real **Privacy Policy URL** and enter it in App Privacy/Privacy Policy; the policy must cover the *actual ad-integrated binary* and the native Game Center/sharing features. Send me the two URLs when ready if you'd like me to check the content.
6. Review **App Privacy** questions in App Store Connect after determining AdMob's SDK collection/tracking behavior. Include advertising and diagnostics data as applicable; never mark “data not collected” just because your own code does not directly read ad IDs.
7. Upload actual full-resolution, Apple-compatible iPhone screenshots. Prefer gameplay, Build/upgrades, warp choices, ships, Hangar and Daily. Follow the suggested order in [APP_STORE_LISTING.md](APP_STORE_LISTING.md). Do not use a placeholder/ad test creative in public listing screenshots.
8. Verify copyright holder, content rights, export compliance, pricing and version details. **Save the draft only**. Do not select **Submit for Review** or schedule release without a separate go-ahead.

## What I can do without your accounts

- Build the deterministic balance matrix and record failed no-Hangar Hard/Insane clears; tune actual combat rather than inventing forced deaths.
- Implement/configure banner placement, download/verify the native SDK on CI, and test unsigned iPhone builds with Google's sample IDs.
- Provide all App Store copy, screenshot plan and accurate release/change notes.
- Commit code/docs, open a PR, keep public release disabled, and run the GitHub CI check.

## Sources

- [Poing Studios banner API](https://poingstudios.github.io/godot-admob-plugin/5.1/ad_formats/banner/get_started/)
- [Poing Studios UMP user messaging](https://poingstudios.github.io/godot-admob-plugin/5.1/privacy/user_messaging_tools/get_started/)
- [Apple product pages](https://developer.apple.com/app-store/product-page/)
- [Apple App Privacy](https://developer.apple.com/app-store/app-privacy-details/)
