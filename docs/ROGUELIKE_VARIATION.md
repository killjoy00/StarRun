# Star/Run — roguelike variation workstream (November 2026)

Approved directions: #2 weapon mutations, #3 pilot gameplay identities, #5 black market, #8 hidden sectors, #9 artifacts, #10 recurring rivals. This first PR implements playable versions of #2, #5, #9, and an initial slice of #3. Hidden sectors and persistent rivals require their own follow-up issues.

## Rare weapon mutations (#2)
- **Ghost Rounds:** Pulse bolts penetrate one enemy and continue with 60% damage. They do not hit the same enemy twice.
- **Hydra Warheads:** Seeker impacts launch up to three homing mini-missiles at 35% damage, targeting other enemies. Secondary shards do not split.
- **Chain Reactor:** Arc Coil kills discharge lightning at up to two nearby enemies, for 35% of the killing hit. Secondary kills do not recursively trigger Chain Reactor.
- Each mutation requires the installed weapon; a run can have exactly one. In Worlds 2+, milestone-level drafts (multiples of four) have a one-in-three chance to replace one normal offer with an eligible mutation. Players choose it instead of a normal upgrade; no forced mutation or extra card choice.

## Black market (#5)
- On warp after Worlds 1–3, a seeded one-in-three check can replace the third Prototype offer with a black-market mutation trade if the player owns its prerequisite weapon and has no mutation.
- The trade costs **25% maximum shield** (Ghost Rounds), **20% maximum hull** (Hydra Warheads), or **15% both** (Chain Reactor) for the rest of the flight. Exact offer and modified capacities survive saves.
- The player can instead take a regular Prototype or skip all offers for 10 Cores; there is **no additional free pick** or intermission menu. The initial implementation deliberately reuses the intermission rather than adding an unrelated NPC encounter.

## Artifact challenge modes (#9)
- **Standard:** unchanged campaign.
- **Glass Fleet:** 50% max hull, +25% shields, +50% automatic gun output.
- **Arsenal Shift:** each warp moves actual Pulse->Seeker->Arc->Lance->Pulse upgrade ranks, neither duplicating nor discarding invested ranks.
- **Drone Armada:** conventional auto weapons start at 0 and cannot be drafted, three persistent drone escorts replace them and scale with the ship's level and weapon power; active skills remain usable.
- These options are selected on the regular-flight title screen, preserved in player profile and in-flight checkpoints. Daily runs always use Standard, regardless of the selected regular mode. Old saves default to Standard.

## Pilot gameplay identities (#3): first two
- **Engineer:** on shield break, deploys a six-second independently firing defensive sentry, in addition to its existing regeneration and shield bonuses. Doesn't overwrite Wing Drones.
- **Scavenger:** every twelfth defeated enemy triggers a scrap explosion, damaging up to two nearby enemies. Scrap-caused kills cannot recursively trigger it. Original experience and Core bonuses remain.
- Follow-up: distinctive mechanics for the remaining four pilots, animations, balancing and human playtesting.

## Follow-up — two mutations per weapon and a separate in-flight merchant

A follow-up extends the original three transformations to eight: two per Pulse, Seeker, Arc and Lance. The original post-boss Prototype mutation offer remains, and the Quartermaster now adds a separate, genuinely optional mid-flight merchant encounter in Worlds 2 and 3. Inventories and prices are deterministic, stored in checkpoints, and charged only after separate confirmation. The merchant is not enabled for Daily or existing headless balance fixtures.

See [Opening and Quartermaster implementation](OPENING_MUTATIONS_MERCHANT.md).

## Deferred ideas
- **Hidden sectors and alternate endings (#8):** requires discoverable clues and a new secret encounter route, new boss/ending content, safe checkpoints and clear opt-in. Separate issue.
- **Recurring rival captain (#10):** requires persistently named nemesis identity, death/kill history, enemy capabilities, a return encounter, payout/retirement rules, privacy-preserving local saves and artwork. Separate issue.

## Validation / release
- Tests cover mutation prerequisites and one-at-a-time rule, physical projectile effects, market sacrifices, rule modes, new pilot behaviors, and legacy save compatibility.
- Full campaign simulation, phone UI smoke, export and native unsigned iPhone build must pass before merge. Headless bots cannot establish fun or iOS device performance.
- Keep Apple marketing version **1.3**. No signed TestFlight build or App Store submission is triggered by this branch.
