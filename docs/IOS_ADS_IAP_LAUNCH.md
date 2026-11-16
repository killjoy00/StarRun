# Star/Run iPhone monetization — staged release gates

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

## Required App Store Connect owner actions (mobile browser)
1. Open App Store Connect -> Apps -> Star/Run -> Monetization -> In-App Purchases -> +. Create a **Non-Consumable** with Reference Name **Remove Ads** and Product ID **com.rsm.starrun.remove_ads**. Product IDs cannot be reused or renamed; copy exactly.
2. Add English (U.S.) localization: Display Name **Remove Ads**; Description **Permanently removes banner ads from Star/Run.** Set an agreed price in **Pricing**; do not guess which pricing tier the user wants. Save. The first IAP may need to accompany the first app-version submission.
3. Add the App Review screenshot showing the Remove Ads button in iPhone Settings after a signed test build is captured, and other review metadata Apple requires. Leave the IAP unsubmitted until the matching signed binary is validated. In App Review note that a purchase is optional and Restore Purchases is under Settings.
4. In **Business -> Agreements, Tax, and Banking**, accept the Paid Apps Agreement and finish tax/banking validation; Apple must mark it active for purchases to work.
5. Under Apps -> Star/Run -> App Privacy, enter the real hosted policy URL https://github.com/killjoy00/StarRun/blob/main/PRIVACY.md and make disclosures that match the *actual shipped* Google Mobile Ads SDK. Google lists device IDs, IP-derived coarse location, advertising data, product interaction and diagnostic/performance data depending on setup. Tracking/ATT answers must reflect actual SDK behavior and consent configuration, not a generic "we collect nothing."
6. Complete App Information age rating (stylized sci-fi violence), Games/Action category, copyright and content rights, export-compliance declarations and Free pricing/territories; fill App Review contact details.
7. Don't submit the public App Store version until the signed release-candidate build, live banner controls and a sandbox purchase+restore on an iPhone are verified.

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
