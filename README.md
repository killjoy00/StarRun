# Star/Run

**Star/Run** is a four-world tactical space auto-shooter for iPhone, Web, Windows and Linux. The latest signed iPhone beta is **0.9.4 (build 1019)**, uploaded to TestFlight from merged [PR #27](https://github.com/killjoy00/StarRun/pull/27). The native Daily share sheet, local achievements and optional iPhone Game Center bridge are built, but Apple's Game Center review and actual on-device functionality are not yet verified. See [sharing and Game Center](docs/SHARING_GAME_CENTER.md) and [Daily rules](docs/DAILY_ACHIEVEMENTS.md).

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
- **Eight stronger Prototypes, optional.** Between stages, take one permanent, build-changing Prototype from three random, save-stable offers—or pass for **10 banked Cores**. Big effects include +55% weapon damage, -38% cooldowns, +60% shield capacity, +70% ability power, or an emergency shield-and-hull rebuild. Every Prototype still has a cost.
- **Choose your next route.** **Shielded passage** repairs 55% hull, refills shields and cuts incoming damage by 18%. **Redline assault** gives +35% automatic weapon damage and +20% fire rate, but repairs only 10%, starts at half shields and takes 20% more hull damage. **Hunter contract** raises enemy pressure 30% in exchange for +35% kill XP and a boss-clear Core bounty. Routes last one world and survive checkpoints.
- **Boss victories are earned moments.** Defeating a boss freezes combat for oversized explosions and shockwaves. Tap **Warp to next stage**, pick a Prototype and route, and receive an extra level-up before the next stage. After Stage 4, tap **Claim victory** for the full report.
- **Phone-first menus.** Title, Hangar, Ships & pilots, drafts, intermissions and results share one layout system: header on top, actions pinned to the bottom within thumb reach, and safe-area margins for the notch and home indicator. The whole card is the tap target; holding and dragging it scrolls when content overflows. Combat HUD and controls also respect the notch and home indicator. Permanent unlocks, Refund all and abandoning a saved flight take a second tap or a confirmation. The first flight opens with a four-step briefing.
- **Meaningful timing.** Aegis base cooldown is 14 seconds and Nova is 20 seconds. Chaff, heavy telegraphs, ordnance, mines and stage-specific suppression require different responses.
- **Real milestones at ranks 5 and 10.** All 47 base upgrade tracks and 11 fused tracks get breakpoint effects. Later picks add two ranks; crossing rank 5 or 10 triggers the effect immediately, even if the choice skipped that exact number.
- **Full-build rewards.** Once there are no eligible upgrades left, a level-up offers **Field repair (+30 hull)** or **5 banked Cores**. These fixed Core rewards pay out when the run ends and are not boosted by difficulty or other multipliers.
- **Ten more passives from world 2.** Siege rounds, Finisher rounds, First strike, Blast plating, Insulation, Shield reserve, Combat repairs, Last stand, Shield focus and Follow-through. Active, Passive and Auto weapon labels stay visible on every draft card. Consumed fusion components leave the pool; upgrade the combined ability directly.
- **Later worlds scale with growing builds.** Worlds 2–4 have substantially higher health, damage and firing pressure, stronger boss modules and longer boss fights. Aegis effects leave a vulnerability window between casts.
- **Six ships and six pilots.** Each ship has a distinct flight, weapon and signature-ability starting package. Pilots provide additional specialties and each has a painted face portrait.
- **Uncrowded combat HUD.** Build/speed/pause controls have their own row above Hull/Shield meters; ability names, ready/cooldown captions and icons no longer occupy the same space or give slot one an artificial highlight.
- **Readable threats.** Enemy rounds and beam warnings share a coral outline and render above friendly effects. A fractured shield ring and segmented shield bar make shield loss visible, including with reduced effects. Fusion and rank-5/10 picks get a thin accent border.
- **Persistent Hangar.** Thirty-eight refundable permanent upgrades enhance weapons, defense, ability power, draft tools and salvage. Reroll uplinks grant one reroll per rank each stage. Equipment and selected difficulty are retained in saves.

Current active pool: Aegis, Nova, Barrage, Overdrive, Chrono, Repair Drones, Flak Screen, EMP Blackout, Deflector, Rail Strike, Prism Reversal, Chaff Barrier, Capacitor, Precision Focus, Decoy Beacon, Signal Jammer, Energy Siphon, Chain Overload, Reactor Reboot, Salvage Surge, Wing Drones, Ion Mine.

## Controls

On iPhone, four compact on-screen buttons run left to right on one row. Fused abilities use just one button. On keyboard, use **1–4** (Space uses slot 1); **B** opens the build, **Tab** cycles play speed and **Esc/P** pauses. Controller **A / X / Y / B** activates slots 1–4; Start pauses. Level-up choices use keys 1–4 or touch.

The playfield uses adaptive 390×844 logical canvas scaling on modern portrait iPhones. Phone UI text uses a 16-point minimum. Build and Results use pinned navigation, short summaries and word-wrapped detail. iOS readability and performance still need real-device validation.

## iPhone and TestFlight delivery

**Latest upload: 0.9.4 (1019)** — [signed Apple upload succeeded](https://github.com/killjoy00/EZTrivia/actions/runs/43805524905) from immutable [merged source `fd5cb98e`](https://github.com/killjoy00/StarRun/commit/fd5cb98ebc78cbc957934e46cd0730fe9d5eaa82). The release strengthens warp routes and Prototypes, tests more four-world balance scenarios, and simplifies the home screen. The native Daily share sheet from 0.9.2, Game Center bridge and permanent progression remain included. The [post-merge playable CI](https://github.com/killjoy00/StarRun/actions/runs/43805461958) and [unsigned iPhone build](https://github.com/killjoy00/StarRun/actions/runs/43805462116) passed; Apple's upload log confirmed success. **Apple processing, tester installability, Game Center publication and actual iPhone performance remain separate checks.** No public App Store launch has been requested.

**Next work in progress (not in 0.9.4):** broader balance research (especially unupgraded Hard/Insane World 1), optional AdMob banner integration and the [draft App Store listing](docs/APP_STORE_LISTING.md). The new study does not lower Hard or Insane's intentionally punishing opening difficulty. Ad serving requires a real AdMob account, app/ad-unit IDs, consent configuration, privacy disclosures and native verification before it can be enabled. No live ads or ads-removal purchases are claimed.

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
- [Native delivery gates](docs/NATIVE_DELIVERY.md) — ad setup, real-device performance and Steam integration
- [App Store listing draft](docs/APP_STORE_LISTING.md) — title, subtitle, description, keywords, screenshots and owner steps
- `scripts/simulation.gd` — deterministic combat, threat director, active effects, stage transitions and checkpoint state
- `scripts/main.gd` — menus, responsive HUD, draft, Hangar and controller input
- `data/content.json` — enemies, abilities and upgrade cards
- `tests/run.gd`, `tests/ui_smoke.gd` — simulation and responsive UI regression checks

**v0.8.1 adds 16 Hangar tracks, six pilot portraits, two actives, rank-5 fusion requirements and distinct fusion insignia and effects to v0.8’s stronger late worlds, ten passives, safe combat headers and held-card scrolling. Real-device UAT remains required.** Passing simulation, responsive UI and iOS compile does not establish human enjoyment, actual iPhone frame-time stability, ads or in-app purchase support. Signed TestFlight release status is checked separately.
