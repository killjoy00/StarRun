# Star/Run — App Store listing draft (en-US)

Status: **Saved and read back successfully in App Store Connect's existing iOS 1.0 draft on 2026-11-16.** This is for the iPhone app already registered as `com.rsm.starrun`. Do not create a new app ID and do not publish the app without separate authorization.

## Product page

- **App name:** Star/Run
- **Subtitle:** Tactical space auto-shooter
- **Primary category:** Games
- **Suggested game category:** Action; Strategy if a second category is allowed and appropriate
- **Language:** English (U.S.)
- **Price:** Free (verify in App Store Connect); ads not live until SDK, AdMob account and disclosures are complete
- **Age rating:** Answer Apple's current age-rating questionnaire based on actual stylized sci-fi combat and ad content; do not invent an age rating
- **Availability:** iPhone, portrait. `export_presets.cfg` currently targets iPhone only; do not upload iPad screenshots unless iPad support is enabled
- **Game Center:** do not claim public online leaderboards/Apple achievements until issue #23's Apple review and iPhone verification are complete

### Promotional text (170-character field)

Four worlds, six ships, and a new decision after every boss. Defend your ship, push your weapons, or take a harder fight for more rewards.

### Description

Your ship flies and fires. You decide when to use its abilities and what to build next.

Star/Run is a space auto-shooter with a four-world campaign. Your weapons fire automatically, but survival depends on the upgrades you choose, the abilities you save for the right moment, and how you handle each boss.

**What you can do**

- Pick from six ships and six pilots, each with different strengths.
- Build around 22 active abilities, passive upgrades and combined abilities.
- Fight through the Debris Belt, Ion Storm, Solar Foundry and Void Citadel. Each world has its own enemies and boss.
- After a boss fight, choose your next route: repair and play safer, boost your weapons with less protection, or fight stronger enemies for extra rewards.
- Try eight powerful Prototypes, each with a drawback—or skip them for Cores.
- Spend earned Cores on permanent Hangar upgrades.
- Play the Daily Challenge with the same starting setup as everyone else. Your best result is saved locally.
- Choose Normal, Hard or Insane. Hard and Insane are built for ships with Hangar upgrades, not fresh-start clears.
- Keep going in Endless mode after completing the four-world campaign.

Star/Run is about a series of small decisions that add up over the course of a run. A strong build helps; good timing still matters.

### Keywords (comma-delimited; keep under Apple's 100-character limit)

roguelite,autoshooter,space,arcade,ship,bullet hell,upgrade,boss,builder,survival,action

### What's New (next public version, only after the ad build is verified)

Route choices now have clearer tradeoffs, and Prototypes have stronger effects. The title screen is simpler, with ship and pilot details separated from the artwork. We also made improvements to balance and layout.

## Screenshots: recommended order

Use **real game captures**, not art that suggests controls/features that the game does not have. The CI workflow already creates the screenshots in the `StarRun-UI-matrix` artifact. For publication, capture them from the release candidate at an **Apple-supported full device resolution** with labels added only outside gameplay imagery.

1. **Auto-fire. You choose when.** Actual combat with visible abilities and a clear boss warning
2. **Four different worlds.** Distinct Ion Storm or Solar Foundry combat
3. **Build as you fly.** An actual upgrade selection with distinct options
4. **Three ways forward.** A route decision with repair, Redline and contract
5. **Pick your ship and pilot.** Ship / pilot selection
6. **Come back stronger.** Hangar upgrades
7. **A new Daily each day.** The Daily Challenge on the title screen
8. **Keep flying after the win.** Endless option after World 4 (only if visually clear)

**Completed 2026-11-16:** Seven real Godot game-UI screenshots from the already-uploaded Star/Run 0.9.4 source were captured, converted to Apple's accepted **1290 × 2796** iPhone large-display size, uploaded to the existing iOS 1.0 en-US draft, and **all seven were confirmed COMPLETE by Apple**.

- [Apple screenshot upload and validation — success](https://github.com/killjoy00/EZTrivia/actions/runs/43911365253)
- Source screenshot artifact available in that workflow's Artifacts section.
- Apple screenshot set: `APP_IPHONE_67`. No simulator-only UI, advertising test creatives or invented gameplay elements were added.

## Fields requiring account access

1. **Support URL:** use a public, working support page. A GitHub Issues page can be a temporary support route if the repo is public and you are prepared to receive support there; a dedicated support page is preferable.
2. **Marketing URL:** optional; leave blank until a real landing page exists.
3. **Privacy policy URL:** required for iOS; publish an accurate policy covering Google Mobile Ads if ads are enabled, Apple Game Center, local saves and contact details. The repo's draft policy is not automatically a hosted legal policy.
4. **Copyright:** enter the actual rights-holder name and year; this is an ownership statement, not a tagline.
5. **Age rating / content rights / export compliance / availability / pricing:** complete inside the Apple account based on actual app, territory and use of encryption.
6. **App Privacy details:** follow Apple's questions for the **shipped binary**, including Google AdMob SDK data collection after that SDK is genuinely installed. Do not mark third-party ad tracking as absent without reviewing the vendor disclosure.
7. **App Review notes:** four on-screen active slots, ship flies and fires automatically, no account needed for offline play; daily scores saved locally; Game Center optional. Provide test login only if Apple requests one and it truly exists.

## Actual App Store Connect sync

Apple accepted the name **Star/Run**, subtitle, promotional text, description, keywords and GitHub Issues support URL. The iOS 1.0 version remains **PREPARE_FOR_SUBMISSION** and no App Review submission occurred.

- [Apple metadata apply workflow](https://github.com/killjoy00/EZTrivia/actions/runs/43896945124)
- [Apple metadata readback verification](https://github.com/killjoy00/EZTrivia/actions/runs/43897202012)
- Machine-readable source: [docs/app-store/en-US.json](app-store/en-US.json)

**Screenshots are populated** and confirmed COMPLETE. Age rating, App Privacy answers, price, and privacy policy URL remain separate account declarations. The user's remaining account steps below cover only those fields.

## Owner steps (no local code or terminal)

1. Sign in at https://appstoreconnect.apple.com/apps and open the existing **StarRun** app (`com.rsm.starrun`).
2. Verify **Star/Run** and **Tactical space auto-shooter** appear as the name and subtitle. Both were saved and read back through Apple's API.
3. Open the current **iOS 1.0 draft** and confirm the description, promotional copy, keywords and support URL are there. They were populated automatically; do not paste them a second time.
4. Enter **Support URL** and **Privacy Policy URL** only after those pages actually exist. Complete the copyright, age-rating, App Privacy, and pricing/availability forms accurately.
5. **Done:** The seven screenshot uploads are confirmed COMPLETE in Apple. You may review their order in App Store Connect. No test ads appear.
6. **Save** the listing draft. Do not press **Submit for Review** or publish until ads and the release candidate are validated.

Sources: Apple's [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information), [product page guidance](https://developer.apple.com/app-store/product-page/), and [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).
