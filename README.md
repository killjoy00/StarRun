# Star/Run

**Star/Run** is the in-game title for the StarRun repository. Version **0.9.1** adds one-tap clipboard sharing for Daily scorecards, queued achievement unlock celebrations, unified icon/web/app branding, and an optional **iPhone Game Center** connection for online Daily scores and Apple achievements. Game Center requires Apple-side setup, badges, review and physical-device testing before it can be called live. See [sharing and Game Center requirements](docs/SHARING_GAME_CENTER.md) and [Daily and achievements rules](docs/DAILY_ACHIEVEMENTS.md).

StarRun is a no-steering, no-aiming roguelite autoshooter. The ship flies and fires automatically; the player chooses its build and *when* to use four equipped active abilities.

## Gameplay: four-world roguelite plus 0.9.0 progression and daily missions

- **Four active slots from 22 abilities.** Every ship starts with a signature ability. Each ability has a matching partner; upgrading both to rank 5 makes a stronger fused ability and frees a slot. Eleven fusions are available.
- **Normal, Hard, Insane.** Choose the difficulty before launch. Higher settings increase enemy health, damage and firing pressure, with respective core rewards of **1×, 1.75×, and 2.5×**.
- **Stage 1: Debris Belt.** Fly through changing scenery and enemy waves, then defeat the Harvester. A full Hangar can make this stage easy, by design.
- **Stage 2: Ion Storm.** A fully different cobalt lightning environment, new electrical silhouettes, ion shield suppression, corrosion, ability disruption and the Storm Carrier.
- **Stage 3: Solar Foundry.** Molten orange factory corridors, Forge Turrets, Slag Bombers, Ember Hunters and Splitters. Heat impairs automatic weapons; molten bombs are visible and shootable. The Crucible Engine is the boss.
- **Stage 4: Void Citadel.** Violet fortress architecture, blinking Phase Stalkers, Void Lancers, Gravity Sentinels and Echo Carriers. Gravity slows weapon fire; void shots partially bypass shields; the Void Regent fires twin telegraphed beams.
- **Tactical multi-part bosses.** Storm Carrier has targetable fighter-launch bays; Crucible Engine has cooling vents and alternating armored/exposed windows; Void Regent has shield pylons and a final onslaught. Autopilot weapons can prioritize these real weak points—no aiming or steering required.
- **Build bonuses.** Fortress, Glass Cannon, Control and Salvager remain meaningful, even if their source skills fuse. Eight weapon/system pairs grant additional passive effects, with no extra ability buttons.
- **Eight Prototypes.** Between stages, choose one permanent run-changing Prototype from three random, save-stable choices. Prototypes boost durability, damage, cooldowns, boss targeting or core income—but always with a cost.
- **Choose your next route.** After the warp and Prototype draft, choose **Safe Passage** (big repair), **Redline Jump** (+25% next-stage automatic damage, limited repairs/shields), or **High-Risk Contract** (+30% enemy pressure, additional cores for beating the next boss). Decisions persist through checkpoints.
- **Boss victories are earned moments.** Defeating a boss freezes combat for oversized explosions and shockwaves. Tap **Warp to next stage**, pick a Prototype and route, and receive an extra level-up before the next stage. After Stage 4, tap **Claim victory** for the full report.
- **Phone-first menus.** Title, Hangar, Ships & pilots, drafts, intermissions and results share one layout system: header on top, actions pinned to the bottom within thumb reach, and safe-area margins for the notch and home indicator. The whole card is the tap target; holding and dragging it scrolls when content overflows. Combat HUD and controls also respect the notch and home indicator. Permanent unlocks, Refund all and abandoning a saved flight take a second tap or a confirmation. The first flight opens with a four-step briefing.
- **Meaningful timing.** Aegis base cooldown is 14 seconds and Nova is 20 seconds. Chaff, heavy telegraphs, ordnance, mines and stage-specific suppression require different responses.
- **Real milestones at ranks 5 and 10.** All 47 base upgrade tracks and 11 fused tracks get breakpoint effects. Later picks add two ranks; crossing rank 5 or 10 triggers the effect immediately, even if the choice skipped that exact number.
- **Ten more passives from world 2.** Siege rounds, Finisher rounds, First strike, Blast plating, Insulation, Shield reserve, Combat repairs, Last stand, Shield focus and Follow-through. Active, Passive and Auto weapon labels stay visible on every draft card. Consumed fusion components leave the pool; upgrade the combined ability directly.
- **Later worlds scale with growing builds.** Worlds 2–4 have substantially higher health, damage and firing pressure, stronger boss modules and longer boss fights. Aegis effects leave a vulnerability window between casts.
- **Six ships and six pilots.** Each ship has a distinct flight, weapon and signature-ability starting package. Pilots provide additional specialties and each has a painted face portrait.
- **Readable threats.** Enemy rounds and beam warnings share a coral outline and render above friendly effects. A fractured shield ring and segmented shield bar make shield loss visible, including with reduced effects. Fusion and rank-5/10 picks get a thin accent border.
- **Persistent Hangar.** Thirty-eight refundable permanent upgrades enhance weapons, defense, ability power, draft tools and salvage. Reroll uplinks grant one reroll per rank each stage. Equipment and selected difficulty are retained in saves.

Current active pool: Aegis, Nova, Barrage, Overdrive, Chrono, Repair Drones, Flak Screen, EMP Blackout, Deflector, Rail Strike, Prism Reversal, Chaff Barrier, Capacitor, Precision Focus, Decoy Beacon, Signal Jammer, Energy Siphon, Chain Overload, Reactor Reboot, Salvage Surge, Wing Drones, Ion Mine.

## Controls

On iPhone, four compact on-screen buttons run left to right on one row. Fused abilities use just one button. On keyboard, use **1–4** (Space uses slot 1); **B** opens the build, **Tab** cycles play speed and **Esc/P** pauses. Controller **A / X / Y / B** activates slots 1–4; Start pauses. Level-up choices use keys 1–4 or touch.

The playfield uses adaptive 390×844 logical canvas scaling on modern portrait iPhones. Phone UI text uses a 16-point minimum. Build and Results use pinned navigation, short summaries and word-wrapped detail. iOS readability and performance still need real-device validation.

## iPhone and TestFlight delivery

**Latest upload: 0.9.0 (1015)** — [signed upload succeeded](https://github.com/killjoy00/EZTrivia/actions/runs/43745092188) from immutable source [`e3aa12c9`](https://github.com/killjoy00/StarRun/commit/e3aa12c9b5b3c9b4e71396f6ac37f8ece519d1d7) (merged [PR #21](https://github.com/killjoy00/StarRun/pull/21)). Star/Run 0.9.0 adds a redesigned branded title, 17 locally stored in-game achievements, and a UTC-seeded daily challenge with the same ship/pilot/no-Hangar starting setup for everyone, unlimited best-score retries and once-per-day Core rewards. Version 0.8.3's Worlds 2–4 balance pass and full-campaign CI remain included. Xcode explicitly reported *Upload succeeded* for 0.9.0 build 1015; Apple processing, TestFlight availability and physical-device acceptance remain separate from upload confirmation. Achievement and daily score data are local, not Apple Game Center, Steam or a public leaderboard.

StarRun's iPhone workflow compiles an unsigned app for CI. **Signed TestFlight distribution already exists in [EZTrivia's shared workflow](https://github.com/killjoy00/EZTrivia/blob/main/.github/workflows/starrun-testflight.yml)** using its existing Apple credentials. An immutable source SHA in [the release request](https://github.com/killjoy00/EZTrivia/blob/main/.github/starrun-release-request.json) triggers signing/upload. See [native delivery](docs/NATIVE_DELIVERY.md) for release verification and device checks.

## Building and running

Pinned to **Godot 4.6.3**, GDScript and the Compatibility renderer. GitHub Actions performs simulation and responsive UI checks, builds Web/Windows/Linux, and compiles an unsigned native iPhone application. Shared Apple signing credentials are in the companion TestFlight release workflow; no secrets are stored in this repo.

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/ui_smoke.gd
godot --headless --path . --script tests/run.gd
mkdir -p build/web build/windows build/linux
godot --headless --path . --export-release Web build/web/index.html
python3 tools/package-web.py build/web
godot --headless --path . --export-release Windows build/windows/StarRun.exe
godot --headless --path . --export-release Linux build/linux/StarRun.x86_64
```

Web requires WebGL2; Windows may show an unsigned application warning. Godot's 60 Hz simulation is independent of renderer and platform services, with deterministic seeds and exact checkpoint serialization.

## Files and remaining release gates

- [Hangar expansion, pilot portraits and two new actives](docs/HANGAR_EXPANSION.md)
- [Gameplay v0.8.1: rank-5 fusions and fusion artwork](docs/GAMEPLAY_V081.md)
- [Gameplay v0.8: world scaling, ten passives and iPhone input](docs/GAMEPLAY_V08.md)
- [Gameplay v0.7: fusions, milestones and mobile acceptance](docs/GAMEPLAY_V07.md)
- [Gameplay v0.6 and strategic UAT specification](docs/GAMEPLAY_V06.md) — boss phases, archetypes, Prototypes and routes
- [Historical v0.5 milestone](docs/GAMEPLAY_V05.md) — four stages, boss ceremonies, readable Build and Results
- [Historical v0.4 milestone](docs/GAMEPLAY_V04.md) — previous two-stage implementation
- [Original design document](docs/DESIGN.md) — longer-term vision, some proposed content not yet implemented
- [First playable v0.3 notes](docs/FIRST_PLAYABLE.md) — historical baseline, replaced by v0.4 for gameplay
- [Native delivery gates](docs/NATIVE_DELIVERY.md) — ads, purchases, real-device performance and Steam integration
- `scripts/simulation.gd` — deterministic combat, threat director, active effects, stage transitions and checkpoint state
- `scripts/main.gd` — menus, responsive HUD, draft, Hangar and controller input
- `data/content.json` — enemies, abilities and upgrade cards
- `tests/run.gd`, `tests/ui_smoke.gd` — simulation and responsive UI regression checks

**v0.8.1 adds 16 Hangar tracks, six pilot portraits, two actives, rank-5 fusion requirements and distinct fusion insignia and effects to v0.8’s stronger late worlds, ten passives, safe combat headers and held-card scrolling. Real-device UAT remains required.** Passing simulation, responsive UI and iOS compile does not establish human enjoyment, actual iPhone frame-time stability, ads or in-app purchase support. Signed TestFlight release status is checked separately.
