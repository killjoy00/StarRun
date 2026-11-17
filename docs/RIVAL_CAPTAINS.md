# Star/Run 1.3 — Persistent rival captain, issue #43

An enemy that genuinely destroyed the player's ship can become a personal captain, return in a later ordinary flight and retire after a real combat victory. No manufactured deaths or mandatory rival encounters. Daily and default balance fixtures remain unchanged.

## Core loop

1. On actual defeat to a supported enemy attack, create one local captain record only if the player has no active rival. Environmental hazards don't generate a captain.
2. Generate a deterministic original captain name, portrait seed, source enemy, originating world, signature ability and defeat history. Record version 1.
3. The immediately following flight cannot contain that captain. After a different completed flight, 38% of eligible seeded ordinary runs can contain one encounter, in the original world or World 3 for World 4 sources, never in a boss phase or already crowded wave.
4. The combat ship arrives with a bright RIVAL CAPTAIN ring, HP bar and exclamation marker. A RIVAL SIGHTED! cutscene freezes simulation for up to 3.6 real seconds, displays the original seeded helmet/visor drawing, the captain name, past defeat count, signature and counterplay, and includes a thumb-friendly Continue button. It survives app resume without duplicating encounters.
5. Five unique signature tactics, each with a combat counter, distinguish the captain from a mere high-HP elite:
   - Charged Barrage: two telegraphed heavy beams
   - Interceptor Screen: two attackable, non-XP escort fighters
   - Reactive Shield: burst damage triggers a brief protective barrier
   - Hunter Lock: short telegraphed heavy shot
   - Mine Scatter: a three-lane field of destroyable mines
6. If the captain escapes, the next completed flight settlement records an escape. If they kill the player again, their limited-strength rank advances, up to three. Defeating them pauses gameplay for RIVAL DEFEATED!, archives the captain and grants one cosmetic journal trophy.
7. The title's Rivals button opens a local roster of an active captain and up to 24 retired captains, with portraits, histories, signatures and tactics.

## Save integrity and Daily exclusion

- Local profile: rival_active, rival_archive, rival_trophies. Sanitization ignores corrupted/unsupported records. No server storage or online user data.
- Flight snapshot: rival_record, rival_stage, rival_spawn_at, rival_spawned, rival_intro_pending, rival_retire_pending, rival_outcome, last_killing_source, all optional for older v1 saves.
- Repeated results settlement uses the existing last_settled_run_key guard. Individual sightings, escapes and rival defeats are also deduplicated by flight seed. Retirement matches active captain ID, awards one trophy, and saves immediately before showing the victory stinger.
- No rival can be configured for a Daily run. New Sim.new fixtures and existing full campaign bot studies never receive a rival unless expressly configured by a test.
- XP for captain and summoned escorts is zero. No direct permanent combat bonus, payout multiplier, advertisements or IAP added.

## QA

- Simulation tests cover real enemy-source creation, environmental/Daily isolation, delayed return, deterministic recurrence, one-per-run spawn, each combat signature, checkpoint resume, escape, revenge defeat, retirement once, and old save migration.
- Headless UI tests cover reveal, portrait, exclamation, retirement, journal and touch-safe dimensions.
- Screenshot matrix includes rival-intro, rival-retired, rival-journal at 375x667, 390x844 and 1280x800.
- Run all original campaign/simulation/export CI and unsigned iPhone compilation before merge. A human iPhone playtest is still needed to assess drama, pacing and combat fairness.
- Keep Apple marketing version 1.3. Do not sign, upload or publish a release.
