# Build Synergy Overhaul — combined phases 2 and 3 (#60)

This change builds on the six automatic engines merged in PR #61. It keeps the core game **build first, not steering or aim**, and introduces real, permanent-in-run tradeoffs using the existing four automatic guns, abilities, pilots, Prototypes, routes and rare mutations.

## Player decisions

### Rank-5 weapon specializations

The first time a weapon reaches rank 5 in a **new regular flight**, the player chooses one of two evolutions. All existing rank-5 and rank-10 barrel/volley/chain/cadence upgrades still apply; evolutions are additional behavior, not purchased stats.

| Weapon | Option A | Option B |
| --- | --- | --- |
| Pulse | **Duelist**: successive Pulse hits ramp +5% damage per stored stack (up to five, 3s timeout) | **Spotter**: Pulse tags a target for a +20% hit from Seeker, Arc or Lance |
| Seeker | **Breacher**: +22% to boss modules, +15% to other elite/boss targets; composes with existing Siege mutation and engine caps | **Interceptor**: a genuine Seeker hit cancels its target's charged beam; 7s cooldown *only after a real cancellation* |
| Arc | **Conductor**: Arc marks targets for a +23% next Pulse/Seeker/Lance hit within 3s | **Tempest**: one additional Arc chain and +14% Arc damage to ordinary swarms |
| Lance | **Executioner**: focus one elite/boss for increasing +11% damage per previous hit (four stacks, 7s timeout) | **Lifeline**: -12% Lance damage but restores up to 8 shield on a real hit, once per weapon firing tick |

These options are intentionally **not equivalent**. Different enemies, loadouts and partner weapons reward different specializations. Some perform better against bosses; some clear swarms or improve survival. Marks are stored in enemy dictionaries, so pause/save/restore preserves actual target stacks and expirations. Evolution choices are stored in the regular version-1 checkpoint.

An earned World-1 rank-5 weapon is offered at the beginning of World 2; **World 1 opening is untouched**. Published Daily runs retain the old draft, fusion and combat rules. Pre-overhaul suspended runs are restored with new build-choice features disabled, so players are not forced into a surprise choice.

### Fuse or keep abilities

When *both* true equipped components of one fusion reach rank 5 in World 2+, the player gets a single noncombat decision: **Fuse (one new ability, free one slot)** or **Keep separate (two individual cooldowns and effects)**. A kept pair is never offered that same fusion again in the run. Overlapping fusion offers are pruned after an accepted fusion consumes one component. Historical Dailies, World 1 and pre-overhaul saves keep the original automatic-fusion behavior.

On real iPhone this appears as a short two-choice screen; it introduces **no new combat button** or timed action. Headless scripted clients that do not own an interactive UI resolve any pending choice deterministically at the next step, not by consuming extra combat/draft RNG.

### Draft changes, not an exhaustive catalog overhaul

On two out of every three eligible regular-flight levels (in World 2+), the draft **may** insert one eligible engine-supporting upgrade if:
- the player has begun investing in the primary weapon or system;
- that real card exists in the already-legal draw pool (respecting rank caps, banishes, fusion components and active slot limits);
- none of the offered cards is already relevant;
- a non-recovery, non-mutation card can be replaced.

It does **not** guarantee an engine, pull an illegal card, add a free extra pick, or change the Daily. Existing reroll, skip, banish, low-hull emergency repair and rare mutation controls remain. The even-level forced *new active ability* offer is disabled in this new mode because it frequently competes with developing a real build. A subsequent missing-fusion partner can still appear naturally.

The draft card shows one succinct **Engine 2/3** or **Completes Engine** line when the offered pick genuinely crosses a recipe threshold. The existing pause/build panel shows online engines, earned weapon evolutions and in-progress recipes without adding a separate screen full of instructions.

## Build/pilot/Prototype balance interactions

| Engine | Build identity interaction | Tradeoff |
| --- | --- | --- |
| Execution Network | Ace and installed Overdrive each reduce the hits needed for a precision payoff (never below 3). Volatile Core increases that burst a little | Volatile Core's hull vulnerability and Pulse's narrower targeting remain |
| Missile Siege | Hunter marks build breach stacks faster. Breach Optics improves module payoff a little | Weaker against scattered swarms; cannot bypass boss sealed phases |
| Storm Circuit | Tactician/Null Harmonics slightly shorten discharge throttle; Arcwing gets one extra jump | Requires hits from more than one real weapon; arc alone cannot cause discharges |
| Prism Hunter | Having Precision Focus installed modestly improves the automatic focus strike | Requires repeated Lance hits against one priority target |
| Fortress Reactor | Engineer, installed Aegis and shielded passage shorten the *high-shield* buildup modestly. Bastion Lattice strengthens a successful counterbattery | Falling below 75% shield still wipes charge; Bastion retains -12% ordinary weapon damage |
| Salvage Carrier | Scavenger and Salvage Charter fill limited escort charge a little faster; Engineer improves the small repair payoff | Support shots still require genuine kills/boss damage, face a cooldown and use the same XP/loot rules |

Existing rare mutations remain one per run, with all their capacity sacrifices and real combat effects. Their genuine Pulse/Seeker/Arc/Lance hits interact with engines and evolutions, but mutation-generated secondary hits **cannot infinitely recurse**. Overclock's faster guns naturally benefit rate-dependent weapon builds; bounty raises risk as already specified. Manual casting can provide tactical bonuses but is never required for an automatic build identity.

## Verification plan

1. The `tests/build_synergy_overhaul.gd` contract exercises all eight specializations using real enemy HP, every player choice and refusal path, exact checkpoint hand restoration, old-save/Daily/W1 isolation, draft legality, overlapping fusion offers, bot fallback, and modest pilot-driven tradeoffs.
2. The `build-synergy-overhaul.yml` CI matrix runs six ship/pilot pairings at representative difficulties, all at **zero manual active casts** for two natural seeded trials each, recording detailed campaign events. These are diagnostics, not human win rates or targets for equal results.
3. Preserve all existing full 4-world and real Silent Archive completion, boss module gates, iPhone safe area, accessibility, save/replay, reliability and unsigned native iPhone export tests.
4. Physical iPhone TestFlight QA in #51/#49/#23 remains necessary for readability, fun and Game Center. Do **not** launch TestFlight or submit the app to Apple from this branch.

## Explicit limits

No new enemies, XP, Core rewards, permanent currency, steering, extra active button, hidden boss invulnerability, Daily scoring adjustment or new App Store metadata. Preserve the intentionally extremely low no-Hangar Hard/Insane World 1 clear probability. Never equate a fixed-seed bot result with player satisfaction.

A successful merge completes the **code implementation** of phases 2+3 of #60, but not real-device/human fun acceptance.
