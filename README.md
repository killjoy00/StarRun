# StarRun

A roguelite autoshooter where you build the ship and time its abilities. The ship steers and fires itself.

## First playable

One five-minute Debris Belt flight: Vanguard, Pulse Cannon, Seeker Pods, Aegis, Nova, three enemy types, eight upgrade tracks, the Harvester boss, a small Hangar, and a flight recorder. Illustrated metal ships, a painted debris belt, parallax rocks, banking, engine trails, layered combat effects, and an original stereo synth score give the flight its atmosphere. No external asset or service is needed to play.

- **Flight:** a seeded course of smooth arcs, gentle vertical drift, and straight stretches; the ship banks and uses its thrusters through turns. The dotted path remains an exact two-second preview.
- **Audio:** independent music/effects toggles, a cruise score that crossfades into a more intense boss arrangement, weapon and engine audio, layered explosions, and distinct ready cues. Threat warnings duck the music.
- **Aegis:** 1 / Space / controller A. Blocks damage. Hold it for the beam.
- **Nova:** 2 / controller X. Clears projectiles, damages enemies, and interrupts charging beams.
- **Upgrades:** tap or click, 1–3, or controller navigation and confirm.
- **Pause:** Escape / P / controller Start. Pauses on interruption too.
- **Resume:** exact fixed-step state, random generator, card hand, and cooldowns persist. Saved automatically every ten seconds and on pause/exit. Web saves are local to that browser and origin.
- **Hangar:** modest permanent upgrades with a free full refund. Every completed or failed flight pays at least five cores. The base ship can clear the belt.

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

See [the updated design](docs/DESIGN.md), [first-playable decisions](docs/FIRST_PLAYABLE.md), and [native delivery gates](docs/NATIVE_DELIVERY.md).
