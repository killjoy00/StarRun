# Star/Run 1.3 — 30-second opener, eight mutations, traveling Quartermaster

## Opening choreography

Normal World 1 uses five purposeful beats:
- 0–8s: a few scouts, to establish the ordinary weapons and targeting.
- 8–12s: a warning banner and audible incoming-formation cue.
- 12–18s: three attackable strike-wing enemies enter from different lanes.
- 18–21s: a brief reprieve in ordinary spawning after the wing.
- 21–30s: counterattack; the existing bounded screen-presence director resumes.

The wing consumes future ordinary spawn slots rather than giving free kill XP. Slower ships retain an on-screen crowd cap. Hard, Insane and Daily do not receive this timing change.

## Exactly two distinct mutations for each weapon

The original three mutations are unchanged. Five new mechanics extend the pool to eight. Only one may be installed in a run, and it must be for an owned conventional weapon.

| Weapon | Option A | Option B |
| --- | --- | --- |
| Pulse | Ghost Rounds: pierces and carries 60% damage | Bank Shot: one secondary 35% hit nearby |
| Seeker | Hydra Warheads: up to three homing shards | Siege Torpedoes: 25% more damage to bosses plus up to two 25%-damage splash hits |
| Arc | Chain Reactor: chained shock on kill | Static Lock: delays firing and cancels that enemy's charging beam |
| Lance | Prism Echo: first lance impact refracts a secondary 35% beam | Capacitor Lance: first real kill per firing cycle reduces the cooldown 0.65 seconds |

Market sacrifices are catalog-defined hull and shield capacity multipliers, with the three original mutation costs preserved.

## Quartermaster encounter

An independent seeded check may produce up to one visit in World 2 and another in World 3, or none. No manual steering, pickups, or aiming. The game pauses for an illustrated freighter with a hail-or-ignore choice. The Quartermaster won't appear during Daily, a boss, a rival, heavy warning or an overcrowded screen.

One deal at most per visit; no rerolling the inventory. The player can:
- Take an exotic eligible mutation for an explicit permanent-for-this-flight hull/shield capacity sacrifice.
- Take Hot Reactor (+35% automatic gun damage, -22% maximum shield for this flight).
- Exchange a nonsignature active for one new rank-1 ability, surrendering the old investment.
- Spend eight already banked Cores on meaningful in-flight hull/shield repair.
- Sell 18% maximum hull capacity for 16 flat banked Cores at final payout.

Prices and benefits are repeated on a distinct confirmation screen. Preview/back does not charge the player. The receipt records an accepted transaction, and no second trade can apply during the same visit.

The merchant signal, inventory, selected confirmation, encounter history, transaction ledger and capacity sacrifices are saved in the existing version-1 snapshot format. Existing suspended flights load with merchant disabled. Daily cannot opt in even with an accidentally corrupted flag.

## Acceptance

A six-ship Actions workflow runs exactly the same observation/control logic against the preceding main commit and the candidate: four matched-seed no-Hangar Normal first-30-second trials, two each Hard and Insane controls, and a natural complete World 1. It reports visible enemy density, empty time, hostile projectiles, first-three timing, XP levels and damage. The controller uses ordinary draft offers and never forces enemies to die or a run to win. These are automated proxy results, not a physical-device or human fun assessment.

Deterministic simulation tests verify every new mutation's real damage/counter effect, the merchant transaction types, signal rejection and repeat suppression, price integrity, old-save migration, Daily exclusion and exact save/resume behavior. UI tests and screenshots cover all merchant panels and opening captions on narrow iPhone and desktop sizes. All existing gameplay, Web/Windows/Linux export and unsigned native iPhone CI checks must remain green.

No marketing version bump, signed TestFlight delivery, App Store publication, ad or IAP changes are authorized.
