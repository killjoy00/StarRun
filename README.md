# StarRun

StarRun is a no-steering, no-aiming roguelite autoshooter. The ship flies and fires automatically; the player chooses its build and *when* to use four equipped active abilities.

## Gameplay — v0.4 draft milestone

- **Four active slots from a pool of 20.** Every ship begins with one signature active. Draft up to three more, then improve the abilities you kept. The available actives range from time shields, missile flak and EMP to offensive strikes, decoys, siphons and salvage buffs.
- **Normal, Hard, Insane.** Choose the difficulty before launch. Higher settings increase enemy health, damage and firing pressure, with respective core rewards of **1×, 1.75×, and 2.5×**.
- **Stage 1: Debris Belt.** Fly through changing scenery and enemy waves, then defeat the Harvester. A full Hangar can make this stage easy, by design.
- **Stage 2: Ion Storm.** After Harvester, keep the same run and build. Stage 2 has tougher, faster waves, ion shots that halt shield regeneration, corrosion that bleeds hull, disruption that delays actives, and a new Storm Carrier boss. A stage-clear draft and partial repair separate the stages.
- **Meaningful timing.** Aegis base cooldown is 14 seconds and Nova is 20 seconds. Chaff, heavy telegraphs, ordnance, mines, shield suppression, corrosion and cooldown disruption require different answers.
- **Fewer, stronger level-ups.** XP thresholds rise faster than before, weapon and passive picks can grant two ranks, and each even-numbered early level offers an opportunity to draft an active until all four slots are filled.
- **Six ships and six pilots.** Each ship has a distinct flight, weapon and signature-ability starting package. Pilots provide additional specialties.
- **Persistent Hangar.** Twenty-two refundable permanent upgrades enhance weapons, defense, ability power, draft tools and salvage. Equipment and selected difficulty are retained in saves.

Current active pool: Aegis, Nova, Barrage, Overdrive, Chrono, Repair Drones, Flak Screen, EMP Blackout, Deflector, Rail Strike, Prism Reversal, Chaff Barrier, Capacitor, Precision Focus, Decoy Beacon, Signal Jammer, Energy Siphon, Chain Overload, Reactor Reboot, Salvage Surge.

## Controls

On iPhone, four large on-screen buttons match equipped abilities from left to right and top to bottom. On keyboard, use **1–4** (Space uses slot 1); **B** opens the build, **Tab** cycles play speed and **Esc/P** pauses. Controller **A / X / Y / B** activates slots 1–4; Start pauses. Level-up choices use keys 1–4 or touch.

The playfield uses adaptive 390×844 logical canvas scaling on modern portrait iPhones. Phone UI text uses a 16-point minimum, with scrolling upgrade cards and Hangar. iOS readability and performance still need real-device validation.

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

- [Gameplay milestone and validation plan](docs/GAMEPLAY_V04.md) — new four-active, two-stage and tiered-difficulty design
- [Original design document](docs/DESIGN.md) — longer-term vision, some proposed content not yet implemented
- [First playable v0.3 notes](docs/FIRST_PLAYABLE.md) — historical baseline, replaced by v0.4 for gameplay
- [Native delivery gates](docs/NATIVE_DELIVERY.md) — ads, purchases, real-device performance and Steam integration
- `scripts/simulation.gd` — deterministic combat, threat director, active effects, stage transitions and checkpoint state
- `scripts/main.gd` — menus, responsive HUD, draft, Hangar and controller input
- `data/content.json` — enemies, abilities and upgrade cards
- `tests/run.gd`, `tests/ui_smoke.gd` — simulation and responsive UI regression checks

**This v0.4 gameplay pass is not yet merged or released.** A passing simulator or unsigned iOS compile does not establish human enjoyment, device frame-time stability, ads or in-app purchase support. The signed v0.3.x TestFlight delivery is separate.
