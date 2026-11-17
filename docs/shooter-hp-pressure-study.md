# Shooter lifetime versus screen pressure (exploratory; not a release)

**Status:** Research-only draft PR #39. The already merged 1.2 game and its
signed TestFlight request are unchanged. Source data are in [Actions
#44106741711](https://github.com/killjoy00/StarRun/actions/runs/44106741711).

## The test

Version 1.2's on-screen wave averages were extremely low for highly upgraded
builds despite faster enemy fire (Bulwark Hard/max: 1.45 on all waves;
Wraith Insane/max: 1.49; see `docs/projectile-density-review.md`).
Some fast enemy deaths happen before the first 1–3-second shot windup.

Challenger raises only eight slower ranged shooters: gunship, shieldguard,
ion_frigate, corroder, disruptor, arc_spire, forge_turret, gravity_sentinel.
On World 2, health increases +12% Normal/+16% Hard/+20% Insane; Worlds 3+
+15%/+20%/+25%. It changes no World 1 enemies, bosses, beam chargers,
fast rushers, carriers, mine layers, slag bombers, spawn frequency,
projectile rates, projectile damage, or XP payout.

Each baseline and challenger simulation used identical starting seeds and
the same auto-weapons, actual offered upgrade cards, and timed abilities.
Three seeds per ship/difficulty/Hangar cohort. Projectile positions within
the 540×960 playfield were sampled every 0.2s of non-paused gameplay.
Combined winner and density statistics are **bot screening**, not human wins.

## Measured screen pressure in Worlds 2–4 enemy waves

| Ship, difficulty, Hangar | 1.2 average visible bullets | HP challenger | Change | Four-world wins |
| --- | ---: | ---: | ---: | --- |
| Vanguard, Normal, none | 23.69 | 25.08 | +5.9% | 0/3 → 0/3 |
| Arcwing, Normal, mid | 9.19 | 16.84 | +83.2% | 2/3 → 3/3 |
| Bulwark, Hard, max | 1.64 | 2.48 | +51.2% | 1/3 → 1/3 |
| Wraith, Insane, max | 2.09 | 2.53 | +21.1% | 2/3 → 2/3 |

All four comparisons completed successfully. World 1 wave density remained
identical within each matched cohort, by design. The normal real four-world
campaign completion check passed, as did the seed-24 main balance suite.
After adding targeted assertions, that test reported **1,860 assertions,
zero failures** (run #44106741745).

**Interpretation:**
- HP increases materially raise visible gunfire in *some* builds, especially
  Arcwing mid-Hangar. That 83% figure is not an isolated causal estimate:
  altered kill timing changes later combat RNG and draft outcomes.
- Even with the HP change, the hardest fully upgraded wave samples remain
  quiet: only ~2.5 enemy shots in view on average. HP **alone** does not
  deliver the desired crowded late-game bullet patterns.
- No sample lost a complete-campaign win. The sample is much too small to
  establish the absence of progression problems or XP-delay/escape costs.
- Higher durability can reduce kills per minute, delay XP, raise collisions
  and escaping enemy hazard damage. Those economy effects need expanded
  seeds and human playtesting before rolling this into a signed release.

## Next decision
Keep this as a **draft** and compare a separate late-world,
slower-shooter *first-shot windup* challenger. Currently spawned enemies
randomly wait 1–3 seconds for their first shot; shortening that delay
could raise visible pressure without making enemies more sponge-like.
However, early untelegraphed shots can also feel unfair—especially on
Hard/Insane—so test warning readability and actual incoming damage.

Neither this research nor a next windup study should silently update
the already pinned 1.2 iPhone TestFlight build. A future accepted gameplay
change should receive its own candidate and on-device QA.
