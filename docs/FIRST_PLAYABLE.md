# Historical first playable — v0.3

2026-11-12. This records the earlier one-stage, six-button prototype. For current four-active gameplay, Stage 2 and difficulty tiers, see [the v0.4 gameplay milestone](GAMEPLAY_V04.md). DESIGN.md contains longer-term proposals.

## Flight and combat

The Vanguard sprite is 76 logical pixels across rather than 98, with a smaller collision core (10 for chaff, 16 for missiles). The new seeded pilot takes 2.2–4.0 seconds between wider horizontal and vertical course changes, retaining continuous Hermite interpolation and an exact two-second path preview. Saves tagged with older movement versions retain their old courses.

The painted background now scrolls. Stars and debris move roughly three times as fast, enemies move about 65% faster, enemy chaff travels at 215 rather than 155, pulse shots at 980 rather than 750, and seekers at 650 rather than 450. Pulse fires every 0.19 seconds and seekers every 0.70 before upgrades. Pulse steering is restricted to a forward cone and a bounded turn rate; it never turns backward. Seekers and Barrage rockets can reacquire a target after a kill.

Waves end at 04:00 and Harvester follows. Only one heavy charge can exist. Heavy warnings remain 1.8 seconds; base heavy hits remain at most 35. Wave heavies are spaced 10 seconds apart; Harvester uses 7.5 seconds. Aegis starts at 7 seconds, Nova at 10. More motion must not make the decision window disappear.

## Build choices

There are 21 tracks: four weapons, six active abilities and eleven passive systems. All reach level 5. Four tracks start at level 1, giving 101 remaining picks in the full pool; this five-minute slice intentionally provides far fewer choices. The old 36-pick pool no longer describes this build.

Aegis and Nova start installed. Barrage launches guided rockets, Overdrive accelerates every automatic weapon, Chrono slows enemy movement/fire and projectiles to 45%, and Repair Drones heal over four seconds. New actives come from drafts, not permanent purchases. Six fixed controls prevent newly learned abilities from changing existing bindings. Level 2 and subsequent levels divisible by 3 offer a new active if any remain available.

New passive systems add shield capacity, fire rate, weapon damage, continuous hull repair, XP gain, critical hits and ability amplification. Arc Coil chains among targets; Prism Lance pierces along an automatically targeted line and favors a charging source.

## Between flights

The Hangar has 22 tracks in Hull, Weapons, Abilities, Tactics and Salvage. Its ship bay shares the in-flight Vanguard artwork. All tracks have actual gameplay effects. Prices are centralized in catalog.gd, with a full exact-cost refund. Original Hull/Armory/Shield Lab purchases still cost five cores per rank, so existing refunds remain valid.

Draft tools include a fourth card, finite rerolls, track-wide banishes and skips that repair hull. They spend a use but never consume a second pending level. A replacement hand and all remaining uses are checkpointed. Purchases affect only newly launched flights.

## Delivery and verification

Simulation checks cover movement bounds, mild homing, both new weapons, learning/casting all new actives, healing, slowing, Overdrive, Hangar effects, pricing/refunds, draft tools and old-save migration. The matched-seed harness compares identical card policies with no casts, immediate casts and reactive casts. Responsive UI checks cover all six controls, all five Hangar categories, purchases/refunds, four-card drafts and the flight recorder at 375×667, 390×844 and 1280×800.

GitHub builds Web, Windows and Linux automatically. Human fun, physical-device performance, Windows-hardware execution, TestFlight, ads/purchases and Steam remain unverified gates. Automated outcomes are regression measurements, not a prediction of human difficulty.

Current local result: **63 simulation assertions and 60 layout checks passed**. On 12 fixed seeds with no Hangar purchases, no-activation runs cleared 5/12 (15.3 mean hull); immediate activation cleared 12/12 (117.7 mean hull); reactive activation cleared 12/12 (131.5 mean hull). This cohort uses one shared upgrade policy across the three input strategies. Native visual checks exercised the Hangar categories, smaller moving ship, the first ability draft and learning/casting Chrono Field.
