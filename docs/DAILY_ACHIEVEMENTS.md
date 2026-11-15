# Star/Run 0.9.0 — achievements, daily challenge, and title

This release keeps the existing roguelite balance and four-world campaign intact. It adds **reasons to keep returning** rather than making an unsuccessful run easier. The game still flies and fires for the pilot; players choose drafts, builds, routes, Prototypes, and when to cast their abilities.

## Title screen

The home screen is now branded **Star/Run** (the repository and app bundle identifiers remain StarRun). The wordmark uses an amber slash between white and cyan halves. The existing selected ship and pilot remain visible as the live hero. The screen also shows today's UTC daily mission, its fixed ship and pilot, the Normal/Hard/Insane selector for *regular* flights, a large launch/resume control and separate Hangar, Awards and Guide navigation. The title and controls use the existing safe-area and scrolling system for compact phones.

## Achievements (local)

Seventeen achievements appear under **Awards**: completed flights, each of the four campaign bosses, victories on Hard and Insane, winning with three ships, bringing a fusion into a flight, collecting Prototypes, cancelling enemy heavy charges, preventing damage, completing daily challenges on distinct UTC dates, and exploring endless World 6.

Milestones come from settled game results rather than UI-only actions. An achievement is written into the existing profile with an unlock date. A completed flight can unlock multiple milestones; earlier campaign bosses still count if later bosses have been defeated. The screen shows the requirement and current progress for locked awards. Unlocks are permanent and cosmetic: **no Core or combat-power bonuses** are attached to achievements.

Old profile files gain the new fields without discarding purchased Hangar ranks, ships, pilots or saved flights. Runs already completed on older builds do not get speculative retroactive boss/difficulty achievements, since their historical details were not saved. First-run and later-run milestones accumulate as new flights settle.

These are **in-app achievements only**. They are not yet mirrored to Apple Game Center, Steam or any cloud service.

## Daily challenge

- **Shared daily configuration**: the UTC date determines a stable seed and a fixed ship/pilot pair for all players. The difficulty is always Normal and Hangar bonuses are set to zero for the Daily flight only. Purchased upgrades and regular-flight preferences remain untouched.
- **Reset convention**: a new date begins at **00:00 UTC**, not at local midnight. The date is printed on the title and daily results. The date, RNG, ship, pilot and attempt number are serialized in the existing run checkpoint, so resuming across midnight finishes the original challenge.
- **Unlimited tries**: the first daily attempt does not lock out repeats. Each finished attempt updates a device-local best score when better. Replays can be used to learn builds or practice ability timing.
- **One Core reward per UTC day**: only the day's **first completed attempt** earns the normal run payout. Subsequent finishes improve the record, not currency, and cannot be used to farm permanent upgrades. Abandoned flights award no Cores.
- **Score**: \`10,000 × worlds cleared + 3 × kills + 50 × level + 5,000 for a victory + remaining hull\`. World clears dominate the other factors; no time-spent score, purchase-based multiplier, or endless-farming path. After World 4, a daily run must claim victory; Endless remains available in regular runs.
- **Same save slot**: the game can suspend one flight at a time. Starting a daily run with a regular/daily checkpoint present requires the same explicit abandonment confirmation as starting a new ordinary flight. Cancelling or resizing the confirmation must never abandon or change the prior checkpoint. A finished Daily can be replayed from the results screen.

Local scores are **not** a global ranking or synchronized cross-device leaderboard. Players can compare scores socially, but the app does not submit them to a server or independently verify other devices' score claims.

## Acceptance and automation

\`tests/meta_progress.gd\` verifies stable date-based seeds and daily ship/pilot choices, Hangar isolation, save/restore, first-completion payment, duplicate-finish safety, retry best-score updates, new-day payment and achievement progress. \`tests/ui_smoke.gd\` verifies wordmark, Daily availability, Awards readability, saved daily/resume/abandon routing, daily result scoring, and the ban on entering Endless through a Daily.

The existing simulation suite and untouched first-world difficulty baseline still run. Screenshot CI now captures **23 screens × three aspect ratios** (including branded title, Awards and Daily results) in addition to all six full-campaign smoke pairs, a legitimate four-world victory and iPhone/Web/Windows/Linux build validation.

## Explicitly deferred

Public leaderboards, account synchronization, signed or server-verified daily submissions, Apple Game Center and Steam achievement mirroring, time-limited daily rewards beyond one per UTC day, new monetization SDKs, and additional encounter difficulty changes are not included.
