# StarRun

A roguelite autoshooter where you build the ship and time its abilities. The ship steers and fires itself.

## First playable

One five-minute Debris Belt flight with Vanguard, four automatic weapons, six active abilities, eleven passive systems, Harvester, a 22-track Hangar, exact saves, and a flight recorder.

- **Flight:** the player ship is 22% smaller. Faster, broader banked course changes cover more horizontal and vertical space, while the dotted path remains an exact two-second preview. New flights use this course; old suspended flights keep theirs.
- **Pace:** scrolling painted space, faster star streaks and debris, faster enemies and projectiles, quicker automatic fire. The five-minute encounter schedule and 1.8-second heavy warnings remain readable.
- **Weapons:** Pulse Cannon now gently steers toward nearby forward targets. Seekers still prioritize charging sources and missiles. Arc Coil chains lightning; Prism Lance pierces enemies along an automatically aimed beam. Both new weapons are learned through cards.
- **Abilities:** start with Aegis and Nova. Learn Barrage, Overdrive, Chrono Field and Repair Drones in level-up drafts. The first draft always offers a new active; later drafts regularly offer more. All six can be carried at once, and none require a Hangar purchase.
- **Controls:** keys **1–6** use the six fixed ability slots; **Space** always uses Aegis. Controller **A / X / Y / B / LB / RB** matches slots 1–6. Click/tap also works. Keys 1–4 choose draft cards. Escape/P/Start pauses.
- **Hangar:** illustrated ship-service bay, category tabs, rank indicators and scrolling upgrade cards. Twenty-two permanent tracks cover hull, shields, damage, fire rate, guidance, starting weapons, cooldowns, ability strength, emergency protection, draft tools and salvage. Free refunds return the exact total paid. Purchases affect new flights; suspended flights retain their loadout.
- **Draft tools:** buy a fourth card choice, up to three rerolls, banishes and repair skips per flight. A banish removes that entire track from the current flight's pool. Draft hands and remaining tools survive saving.
- **Saves:** existing cores and the original Hull/Armory/Shield Lab ranks carry forward. Saves retain fixed-step state, RNG, the exact card hand, all six cooldowns, healing/time-field/overdrive effects, and draft tools. Web saves belong to that browser and origin.
- **Audio:** independent music/effects toggles, original cruise/boss scores, weapon and engine audio, and distinct activation/ready cues for every active ability.

## Builds

Pinned to **Godot 4.6.3 standard**, GDScript and the Compatibility renderer. Open `project.godot` in that version. GitHub Actions runs simulation checks and automatically produces web, Windows, and Linux playtest artifacts on pushes and pull requests. See the **Playable build** workflow's artifacts.

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/run.gd
mkdir -p build/web build/windows build/linux
godot --headless --path . --export-release Web build/web/index.html
python3 tools/package-web.py build/web
godot --headless --path . --export-release Windows build/windows/StarRun.exe
godot --headless --path . --export-release Linux build/linux/StarRun.x86_64
```

Serve the web folder over HTTP(S); it needs WebGL2. It is single-threaded and does not require cross-origin isolation. The Windows download also includes the complete source and design notes. Native downloads contain the game executable; Windows may show an unsigned application notice.

## Structure

- `scripts/simulation.gd`: fixed 60 Hz combat, draft, targeting, threat director, and serializable state. No rendering or platform SDK dependencies.
- `scripts/main.gd`: responsive presentation and input. The 9:16 playfield scales into the space left after HUD and controls, including on 16:9 phones.
- `data/content.json`: enemy, ability, and card definitions.
- `scripts/platform_services.gd`: atomic save adapter. Ads and store methods honestly report unavailable until native integrations are proven.
- `tests/run.gd`: defense, interruption, targeting, frozen drafts, deterministic disk/checkpoint round trips, and 12 matched seeds for three input policies.

## Scope and remaining gates

This is the first playable, not the full four-level release. iOS/TestFlight, Steam SDK integration, ads, purchases/restoration, real-device performance, and external player fun tests remain unverified gates. No store purchase or ad SDK is simulated as working. A passing bot check does not establish that human play is fun or accessible.

Saved flights from v0.1 preserve their original course; launch a new flight to use the new pilot. Original art prompts and the reproducible score are documented in [art/audio notes](docs/ART_AUDIO.md).

See [the updated design](docs/DESIGN.md), [current prototype decisions](docs/FIRST_PLAYABLE.md), and [native delivery gates](docs/NATIVE_DELIVERY.md).
