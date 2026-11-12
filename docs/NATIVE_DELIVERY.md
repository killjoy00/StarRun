# Native delivery gates

The first playable uses Godot 4.6.3, with a matching pinned export-template set. Moving to another engine version requires repeating exports, replay tests, and device checks.

## Automated now

GitHub Actions builds Web, Windows, and Linux after simulation checks. Linux's exported executable receives a headless startup check. Downloadable artifacts are retained for 30 days. There is no Vercel dependency.

## iOS / TestFlight — still required

1. Register a unique bundle identifier and App Store Connect app. Reuse the existing Apple team and signing workflow where available; do not reset another app's credentials.
2. Add a macOS workflow using the matching Godot export templates, export to Xcode, archive/sign, then upload through App Store Connect. A successful headless Linux export is not evidence that this works.
3. Install on a physical supported iPhone, including a small 16:9 device if supported. Verify ability reach, card text, safe areas, phone interruptions, audio, persistence and exact resume.
4. Run the 2,000 enemy plus 500 player-projectile render/collision stress case for sustained performance, not just average frame rate. Record device, renderer, thermal conditions and p95 frame time. This is not yet passed.
5. Spike ads with a maintained plugin, including consent decline, no fill, cancellation, failure and offline behavior. Never make a run depend on an ad loading.
6. Spike a real non-consumable purchase, pending/cancelled purchase, restore, and entitlement recovery on a clean installation. Evaluate both the legacy InAppStore plugin and the community `godot-sdk-integrations/godot-storekit2` option against the pinned engine. The latter describes its API as unstable.

## Steam — still required

Prove an exported build through Steam, controller play on Steam Deck, a real achievement and cloud-save conflict handling. The unsigned Linux/Windows playtest builds do not establish Steam SDK integration or Deck verification.

## Human fun gate

Players should understand the two buttons, deliberately hold or spend one in response to a threat, understand their final damage sequence, and want another attempt. Compare intentional play with immediate activation; count meaningful choices and explanations, not just button frequency. Do not expand to four levels until this is observed.
