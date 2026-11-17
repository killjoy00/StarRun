# Star/Run 1.3 — World 1 and pilot identities

The November 17, 2026 owner report: **Normal World 1 is too sparse and feels trivial with an empty Hangar.** Initial extra-spawn experiments proved why simply accelerating everything doesn't work: Vanguard could clear the crowd while Haven and Bulwark were overrun. A full before/after experiment uses the same seed and a controller that purchases only legitimately offered cards.

## Current approach
- A first visible three-enemy **strike wing** appears about 12–16 seconds into a Normal run if the screen isn't already crowded. Other three-ship engagements recur but only when fewer than three enemies remain visible.
- Every 3.25 seconds a bounded **presence director** checks actual visible enemies. It fills up to three visible enemies, at most two additional reinforcements per pulse, without targeting ship IDs or Hangar rank. If slow fire has already left several enemies on screen, it does nothing.
- Reinforcement attackers have a distinctive cyan wing marker, damageable hull, and a telegraphed initial attack delay; **they grant zero XP**. They are still actual enemies rather than a cosmetic background effect. Normal ordinary enemy cadence/XP and Hard/Insane stage rules are unchanged.
- A normal strike wing replaces three future normal spawn slots. Its encounters do not create a separate reward farm.
- World 1 Normal uses a conservative maximum live enemy cap of 11, so even slow ships don't accumulate unlimited overlapping squads.

## Five distinct pilots, one deliberately generic pilot
- **Vale / Rookie:** deliberately no special mechanics or bonus.
- **Vega / Ace:** three rapid automatic-weapon kills produce a precision crossfire effect against up to two nearby enemies, even on ships that don't start with Pulse.
- **Patch / Engineer:** a four-second proactive sentry after 25 seconds of flight if shields are healthy (once per world); shield breaks also deploy the original six-second emergency sentry.
- **Orion / Hunter:** visible mark on a priority enemy; autopilot targets it, automatic weapons deal +15%, elimination restores 10 shield. A real cooldown prevents endlessly refilling shield every few kills.
- **Scrap / Scavenger:** existing every-twelfth-kill scrap shockwave.
- **Nyx / Tactician:** once per world, a precisely timed ability into incoming fire suppresses up to three projectiles and refunds 18% of active cooldowns. Blind button use doesn't trigger it.

## Validation and release guards
- All changes are on a PR until matched-seed World 1 presence, empty-screen %, crowd %, hostile bullet density, actual survival, earned level/XP, and 36 loadouts are reviewed. Test bots aren't human win rates.
- Normal/mid, Hard/max and Insane/max cross ship/pilot samples, plus Standard, Glass Fleet, Arsenal Shift and Drone Armada artifacts; full 4-world nonforced campaign tests.
- Existing save format still version 1; all new fields optional in old checkpoints, and chosen artifact/Daily remain intact.
- Marketing version remains **1.3**; no signed upload or public App Store release.
