# Star/Run iPhone monetization — staged release gates

## Store-first initial release (November 16, 2026)
Star/Run must be publicly listed in the App Store before AdMob can complete app review. For Apple's **first public review only**, ship a **free, ad-free game with no visible Remove Ads purchase**:
- `data/admob.json`: `enabled=false`, `test_mode=false`. No Google sample ads or live ad SDK in the initial public build.
- The iPhone Settings panel hides the purchase/restore controls while ads are disabled, avoiding a paid Remove Ads offer that cannot currently provide value. The StoreKit implementation and Apple IAP record remain intact for a later update.
- The already-requested **0.9.6 sandbox beta** is pinned to its older source SHA, so that earlier beta remains usable for exercising test ads/purchases (if the signed upload succeeded); this new change does **not** modify it.
- Before submitting the initial ad-free binary, **recheck the published Apple App Privacy answers**. AdMob's six data categories may need to be removed for this initial binary because the Google Mobile Ads SDK is absent. Game Center and any other included SDKs must still be disclosed accurately.
- Submit initial version without the `Remove Ads` IAP. Apple's first non-consumable can be reviewed with **a later new app version** after AdMob approval and on-device testing.
- After Apple's public launch and AdMob app approval, create a separately reviewed update that re-enables live ads with the privacy/consent gates and activates the already-configured non-consumable. Submit that IAP together with the new app version. Do not switch production ads on merely because code compiles.

**Do not reuse 0.9.6's Google sample-ad TestFlight binary as the public App Store build.** A new signed candidate built from this store-first configuration is required.


## Product choice
- **One non-consumable:** Remove Ads; canonical product ID \`com.rsm.starrun.remove_ads\`.
- **Price:** Owned by the publisher in App Store Connect (do not embed USD or a guessed amount in the UI). The app shows Apple's *localized* price returned by StoreKit.
- The purchase is optional; no power, weapons or Cores are locked behind it.
- Purchase sheet is Apple's; Restore purchases is always present in iPhone Settings.
- A verified Apple transaction is needed to grant the entitlement. The entitlement is stored locally for offline use after successful purchase/restore, and recovered from Apple's history on reinstall. Never grant based on a button tap or empty store response.
- Ads are only on the title/results screens. The StoreKit entitlement check runs *before* the ad SDK can load a banner or request UMP consent. Purchase or restore removes any visible banner immediately.

## Exactly what is staged now
- The SDK is OpenIAP Godot 4.4.0, StoreKit 2, iOS 17+; pinned via release SHA256 in tools/install-iap.sh. Installed only on macOS iPhone export.
- AdMob test mode uses Google's sample App ID and banner unit, via data/admob.json enabled=true + test_mode=true. Production IDs are recorded but not used by this candidate.
- Live ad serving MUST remain disabled until consent messages and Apple disclosures are approved, a physical iPhone confirms the consent form/banner placement, and the test-mode flag is turned off in a separately reviewed commit.
- No public App Store submission or TestFlight release is authorized by this PR.

## Completed App Store Connect Remove Ads product setup (2026-11-16)
- Existing Star/Run App Store Connect app: `com.rsm.starrun`. No second app created.
- StoreKit non-consumable: `com.rsm.starrun.remove_ads`, Apple IAP ID `6835610167`.
- **Apple-verified one-time US price: $1.99**. Existing price schedule was preserved.
- English (U.S.) localization: **Remove Ads** — "Permanently removes banner ads from Star/Run."
- Review screenshot: **1290 × 2796 PNG** captured from the running Godot Settings UI, uploaded through the Apple asset API and processed **COMPLETE**. See EZTrivia run `43957359340` and asset ID `8f2b3cf7-cd3b-4194-8b6b-4459876a85bd`.
- App Review instructions explain how to purchase and restore.
- Apple product state: **READY_TO_SUBMIT**; IAP version: **PREPARE_FOR_SUBMISSION**. Product was **not submitted** for review.
- Existing region availability preserved, with new territories enabled. App Store Connect setup validation run: `43958431840`.

## Remaining actions for the Apple account owner
1. Verify **Business → Agreements, Tax, and Banking** has an **Active Paid Apps Agreement**, complete tax/bank forms where Apple requests. These legal and financial decisions belong to the account holder.
2. Complete the app's **App Privacy**, age rating, export compliance, copyright and App Review contact questions. Disclosures must match the *actual* Google ad SDK and tracking/consent behavior in the final signed build.
3. Install the next signed TestFlight beta and perform a sandbox **$1.99 Remove Ads purchase**, **Restore Purchases**, cancel/pending tests and clean reinstall on an iPhone. Verify no banner requests occur for owned/pending/unverified entitlements.
4. When the final production binary, consent, and purchase tests pass, submit the initial non-consumable with the matching app version for Apple's review. Do not submit a public App Store release until launch approval.

## Required AdMob publisher actions (mobile browser)
1. Go to AdMob -> **Privacy & messaging** for the existing Star/Run iOS app, review and **publish** appropriate EEA/UK consent messages and applicable US state privacy choices; accurately set the application's age/audience treatment. The Google publisher App ID and banner ID have already been configured in repo, so don't create another AdMob app.
2. Confirm your published privacy policy is linked in App Store Connect and covers AdMob, Game Center, saved data, third-party privacy requests and support.
3. Use a real iPhone TestFlight sandbox run to confirm Google *test* banner appears only on title/results, consent gate works, and bought/restored entitlement hides banners even after reinstall. Test with consent rejected/required and no-fill; the game must stay playable.
4. Only after acceptance, request the live-ad switch: disable test_mode with a reviewed commit, sign a new TestFlight beta, verify live serving and the final App Privacy responses.

## Engineering acceptance
- iOS export imports both OpenIAP frameworks and embeds/signs them in Xcode; abort if a required bundle is absent. Verify version, bundle ID and native frameworks in signed archive.
- Non-iOS app must never expose a fake purchase flow or receive live ads.
- The player cannot buy twice while an operation is pending; a genuine completed transaction grants Remove Ads, and restore recovers an existing purchase.
- Apple may take time to propagate a newly created IAP to sandbox products; no product price will be invented as fallback.
