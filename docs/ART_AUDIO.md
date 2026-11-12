# Art, audio and flight pass — 2026-11-12

The user rejected the mechanical side-to-side movement and requested richer graphics and audio. They approved the new illustrated art and authorized publishing and merging the implementation.

## Flight

New flights use a seed-derived course, separate from combat/draft randomness. Variable 3.8–7.5 second legs include steady stretches and modest changes of course. Time-aware cubic Hermite interpolation keeps positions and velocity continuous. The ship banks into turns, with animated exhaust and persistent trails; the star field and foreground debris add forward motion. The existing two-second preview evaluates the exact same course used for collision and beam scheduling. Old suspended flights retain their old movement version rather than silently changing an imminent collision after resume.

## Art assets and final prompt set

The six files in `assets/art/` are original generated raster assets; transparent sprites preserve their alpha. They replace the prototype's geometric ship placeholders. Generated source images are copied directly into the project; no externally hosted image is needed at runtime.

Shared sprite prompt: one production spaceship sprite for a premium top-down arcade shooter, exactly top-down, centered and fully isolated with true transparency and margin. Layered metallic hard-surface construction, bevelled charcoal titanium, crisp readable silhouette, pre-rendered 3D game rendering, strong edge highlights. No text, no symbols, no UI, no background, no ground shadow or external exhaust.

- `vanguard.png`: nose points up; tapered interceptor with swept wings, long armored nose, two separated rear nacelles, cyan cockpit and running lights, copper nozzles, subtle wear.
- `harvester.png`: weapons point down; wide industrial mining dreadnought, central molten amber reactor, massive side pods, cutters, laser emitters, battered titanium, copper machinery and orange lights.
- `drone.png`: points down; compact swept-wing attack drone, claw-like wings, narrow spine, red sensor and two rear thrusters; industrial mining fleet materials.
- `gunship.png`: points down; broad squat armored hull, cylindrical missile pods, four armored wings, copper plates and red-orange lights.
- `sniper.png`: points down; long narrow frigate, needle laser barrel, triangular rear fins and an amber charging crystal.
- `debris-belt.png`: portrait 9:16 background painting, very dark deep space, fragmented burnt-copper planet curving beyond the right edge, rust dust and indigo gas, distant asteroids, broad nearly-black central flight corridor; no ships, UI, lettering or central bright source.

The material illustrations are combined with programmatic parallax, asteroids, engine exhaust, muzzle flashes, shield rings, impacts, debris sparks, shockwaves and layered beams. Reduced-glow mode also reduces particles and camera shake. The ship's collision radius is unchanged; decorative wings and exhaust do not enlarge it.

## Original audio

`tools/compose_audio.py` creates the committed assets in `assets/audio/` using mathematical synthesis, filtered noise and original musical patterns; it uses no recorded samples or third-party music. It requires numpy, scipy and ffmpeg only when regenerating the assets, not when running or building the game.

- Two 112 BPM, sixteen-bar stereo arrangements: restrained cruise and driving boss combat. Crossfade on the Harvester's arrival.
- Synth bass, chord pads, stereo arpeggios, kick/snare/hat percussion and a boss lead with fills; dotted-eighth stereo delay.
- Engine loop, plasma shots, missile launch, layered explosions, shield activation/break, Nova bass shockwave, hull impact, rising charge warning, low-hull cue, upgrade, launch and outcome sounds.
- Distinct Aegis/Nova ready motifs; lower music level during heavy telegraphs; independent effects and music toggles.
- Headless verification imports assets but does not start audio-device playback.

Human listening and real-device frame-time, heat, memory and mobile audio-interruption checks remain external QA gates. The source retains the automated simulation, course continuity, checkpoint and responsive-layout checks.
