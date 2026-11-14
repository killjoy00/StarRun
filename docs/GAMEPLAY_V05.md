# StarRun v0.5 — Historical four-stage campaign milestone

**Superseded for the current strategic rules by [v0.6 gameplay](GAMEPLAY_V06.md)**, which adds boss subcomponents/phases, synergies, Prototypes and strategic routes. This file preserves the earlier v0.5 release design.

**Status:** gameplay implementation and automated UAT in PR #8. These are the intended rules for the next iOS playtest, not a claim that human balance or real-device readability has passed. This replaces [v0.4 gameplay notes](GAMEPLAY_V04.md) as the current implemented direction.

## User decisions accepted November 13, 2026

1. **Build Stages 3 and 4.** The run should continue from 1 through 4, retaining the same loadout and permanent Hangar progression.
2. **Make Stages 2–4 visually and mechanically different.** Different backdrop composition, dominant colors, enemy silhouettes, attack shapes, boss identities and stage-specific warnings—not a single background recolored.
3. **Make boss defeats a major moment.** Multi-burst explosion, rings and debris; pause and allow a deliberate acknowledgment; player taps **Warp to next stage** (or **Claim victory** after Stage 4). Warp animation precedes the next stage's upgrade choice.
4. **Fix Build and Results usability.** The text must wrap on an actual narrow phone; status must be quickly scannable; details may scroll but the essential navigation must remain visible. Build has **Resume flight** and **Main menu** without scrolling. Results has **Fly again** and **Main menu**, with Hangar available in the report.
5. Preserve the four-active-slot system from a pool of twenty, one signature ability per ship, and Normal/Hard/Insane rewards. A fully upgraded ship is allowed to dominate Stage 1; the late stages provide the more demanding challenge.

## Four stages

The authored director lasts four minutes before a boss on each stage. Time until boss defeat is player-dependent. Combat simulation remains deterministic and does not grant stages automatically.

| Stage | Location and visual identity | Distinct enemies | Boss | New gameplay pressure |
|---|---|---|---|---|
| 1 | **Debris Belt** — painted wreckage, asteroids, steel and amber | Drones, gunships, snipers, bombers, carriers and mines | **Harvester** | Understand shields, heavy beam telegraphs and Aegis timing |
| 2 | **Ion Storm** — cobalt plasma, electric columns, blue clouds, lightning ribs | Ion Frigate, Corroder, Disruptor, **Arc Spire**, **Storm Weaver** | **Storm Carrier** — extended cyan wings and an electric core | Ion disables regeneration, corrosion bleeds hull, disruption delays cooldowns |
| 3 | **Solar Foundry** — industrial rust-orange pylons, furnace rails, bright molten trenches | **Forge Turret**, **Slag Bomber**, **Ember Hunter**, **Splitter** | **Crucible Engine** — huge furnace with hot core and vents | Heat temporarily reduces damage output, larger shootable timed molten slag zones, Splitters release two drones |
| 4 | **Void Citadel** — black/violet monoliths, symmetric towers, portal arches | **Phase Stalker**, **Void Lancer**, **Gravity Sentinel**, **Echo Carrier** | **Void Regent** — geometric fortress with orbiting pylons | Phasing attackers reposition, gravity slows automatic fire, void fire partially bypasses shielding, final boss telegraphs two beam lanes |

All ten new standard enemies have their own simulation specs, authored attack patterns, and vector silhouettes. All three later bosses use unique shapes, names and attacks, not the Harvester sprite with a new tint. Later stages scale health, spawns and boss strength independently of difficulty mode; Normal, Hard and Insane retain their established **1×, 1.75×, and 2.5×** core multipliers.

## Boss defeat and transition contract

- On killing a boss, the simulation records the clear and **freezes**, without granting the next stage or settling a run automatically. A checkpoint during celebration restores into the exact same state.
- A larger explosion sequence plays for roughly two seconds with secondary bursts, shockwaves and fragments. Reduced-glow mode lowers particle counts. At least 1.2 seconds elapse before the button activates.
- **Warp to [next location]** is a deliberate click/tap or Enter/Space, not an auto-advance. Then a roughly 1.45-second warp animation plays and the next stage begins.
- Between stages the same build persists. Shields refill, 30% max hull is repaired, and the player receives one milestone upgrade draft.
- **Stage 4:** the Void Regent defeat also pauses for celebration. **Claim victory & see report** finalizes the run, pays earned cores once, and opens the report. Death before a boss still goes directly to Results.
- App interruption/resume must not skip a stage, duplicate rewards, or lose a pending choice.

## UX and UAT specification — Build

**User's job:** “What abilities, weapons, systems and Hangar modules do I have, and how do I get back?”

- Fixed header: **YOUR BUILD**, ship/pilot, stage and difficulty.
- Above the fold: hull, shield, number of equipped abilities, then four clear active-slot cards showing ability name, rank, base cooldown and meaning.
- Separate headings for automatic weapons, systems and Hangar support. Systems initially show a short summary; **Show all** expands details only when requested.
- Long labels and card text use word-smart wrapping, never horizontal scrolling. The screen is vertically scrollable.
- **Resume flight** (or **Back to pause**) and **Main menu** remain fixed at the bottom at phone sizes. Main menu saves the exact suspended flight; the menu offers Resume flight.
- Touch targets are at least 44 logical points; mobile font sizes are at least 16 logical points.

## UX and UAT specification — Results

**User's job:** “Did I win, how far did I get, what did I earn, what went wrong, and what now?”

- Fixed header: **FOUR STAGES CLEARED** or **FLIGHT ENDED**, current stage/difficulty and duration.
- Scannable, wrapped sections: earned cores; kills, stages and ability uses; final hull/shields, blocked damage and beams canceled; incoming damage categories; top damage-dealing weapons; and the last ten seconds of the flight recorder.
- Keep **Fly again** and **Main menu** fixed at the bottom. Hangar is a visible action in the scrollable report. Do not present an undifferentiated monospaced wall of numbers.
- Payout is settled once, before the result screen; resizing, navigating or reopening results cannot pay twice.

## Test and acceptance gates

Automated tests must cover four sequential stages, escalating boss health, Stage 2–4 enemies/projectiles, splitters, dual-beam telegraphs, stage-clear freeze and save/restore, acknowledgment, warp, final settlement, distinct procedural visual-theme IDs, text wrapping, no horizontal scroll, visible sticky navigation at 375×667, 390×844 and desktop sizes, plus all platform compiles.

**Still requires device and player testing:** artwork contrast and performance on a real iPhone; readable explosions and telegraphs on reduced effects; reaching and beating Stages 2–4 with realistic builds; stability at 2×/3×; difficulty-mode fairness and voluntary replay. The 20 active abilities and Hangar balance remain a separate tuning gate. Ads, purchases, restore and Steam SDK are still unresolved native-delivery gates; do not mark them passed based on an unsigned compile or TestFlight upload.
