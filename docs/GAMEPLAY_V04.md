# StarRun v0.4 gameplay milestone — historical two-stage implementation

This document records the earlier version. The current four-stage implementation, visual direction and mobile UAT requirements live in [GAMEPLAY_V05.md](GAMEPLAY_V05.md).

This document describes proposed gameplay implemented on the v0.4 feature branch. It is **not** verified as fun, device-performant, or App Store ready until CI and real iPhone playtesting pass.

## Core loop

- **Two stages**, each with a 4-minute wave director followed by its own boss. Stage 1 is Debris Belt / Harvester. Clearing it restores shields, repairs 20 hull, awards an extra upgrade draft and enters Stage 2 / Ion Storm. Stage 2 uses faster, tougher waves and the Storm Carrier boss. Stage 2 is deliberately harder than Stage 1 even on Normal.
- **Normal / Hard / Insane** is chosen before a flight and carried through checkpoints. Base enemy health, damage and spawn frequency scale by difficulty. Cores earned use **1× / 1.75× / 2.5×** multipliers, plus stage-clear rewards. Hangar growth is intentionally allowed to trivialize earlier stages.
- **Four active buttons only.** Each ship launches with one signature: Vanguard and Bulwark = Aegis, Kestrel = Overdrive, Wraith = Barrage, Arcwing = Nova, Haven = Repair Drones. Three remaining slots are filled through drafts from **20 mechanically distinct abilities**. Once all four are filled, unowned abilities disappear from draft offers; installed abilities can be upgraded.
- The 20 active abilities: Aegis, Nova, Barrage, Overdrive, Chrono, Repair Drones, Flak Screen, EMP Blackout, Deflector, Rail Strike, Prism Reversal, Chaff Barrier, Capacitor, Precision Focus, Decoy Beacon, Signal Jammer, Energy Siphon, Chain Overload, Reactor Reboot, and Salvage Surge.
- **Pressure is more varied, not just bigger numbers.** Existing chaff, charging beams, missiles and mines remain. Stage 2 adds ion shots that suppress shield regeneration, corrosion that damages hull over time, and disruption that extends equipped ability cooldowns. Their bullets have distinct visual colors and shapes. Insane can introduce them late in Stage 1.
- **Longer cooldowns:** base Aegis 14s (was 7s); base Nova 20s (was 10s). They still counter different pressure patterns, but cannot answer every threat on demand.
- **Fewer, stronger draft interruptions:** XP needed increases to `25 + 9 × (level − 1)`, compared with `12 + 4 × (level − 1)`. Passive and automatic-weapon cards grant up to two ranks in one selection; active ability cards grant one. Drafts at even levels guarantee an opportunity to learn a new ability until all four slots are filled. Stage-clear drafts are extra.

## Technical changes

- Course sampling is binary searched rather than linear, supporting two stages with a long seeded flight path.
- Player-shot collisions against interceptable enemy ordnance use 64-unit spatial buckets rather than scanning every bullet for every shot.
- This is **not** yet a full compact projectile store; dictionary allocation, pooling, render batching and sustained iPhone p95 frame time still need profiling before targeting thousands of bullets.
- Save/resume retains exact RNG state, stage, difficulty, cooldowns, draft hand, active-slot order, status effects and bonus rewards. Older saves without active slots reconstruct their equipped learned abilities, up to four.

## Test and release gates

1. CI tests for every active, four-slot enforcement, stage transitions, three difficulty rewards, three new status hazards, old saves, dense point-defense collisions, responsive iPhone UI and all current platform exports.
2. Matched-seed bot comparison on Stage 1, by ship and difficulty: non-input, on-cooldown, and deliberate timing. Evaluate Stage 2 separately, including fully upgraded ships.
3. Real iPhone test: verify readability, all four buttons reachable, card choice impact, projectile/telegraph clarity, performance, save/resume and 3× speed.
4. Human playtest: meaningful decisions, reaction to pressure, upgrade interest, and voluntary next run. Numerical bot wins are not a substitute.
5. Only after these gates, bump the app version and send an iOS TestFlight build.

## Deferred

Ads and StoreKit purchase/restore integration are still unproven and must be evaluated on-device. Full compact projectile data layout and 2,000-bullet sustained benchmark remain separate engineering work.
