# Star/Run 1.3 — targeted ranged durability and faster first volleys

**Status:** accepted combined gameplay tuning from PR #39 following CI and a matched four-cohort A/B. The original 1.2 signed TestFlight request stays pinned until a separate 1.3 signed build is requested. No live ads or App Store submission changes are implied.

## Change

Only gunship, shieldguard, ion_frigate, corroder, disruptor, arc_spire, forge_turret and gravity_sentinel receive both changes in Worlds 2+:

| Parameter | World 2 | Worlds 3–4 and endless |
| --- | --- | --- |
| Normal HP | +12% | +15% |
| Hard HP | +16% | +20% |
| Insane HP | +20% | +25% |
| Initial randomized shot window | 0.95–1.80 s | 0.85–1.65 s |
| Repeated volleys | Unchanged | Unchanged |

Old initial shot delay for every enemy: random 1–3 seconds. Slow shooters hold their initial volley until their *center* reaches the visible top edge (y ≥ 0); this avoids firing into the unseen region without delaying until 16 pixels deep into the playfield.

World 1, all bosses and boss parts, heavy-beam chargers, fast interceptors/rushers, minion-generating carriers, mines/slag specialists and static hazards are unchanged. No extra enemies, bullet damage, loot, XP or pickup rates. Faster initial shots do not accelerate any subsequent cooldown.

## Combined, independently executed A/B (Actions #44127618898)

Each case used exactly three identical start seeds in 1.2 main and the candidate, authentic enemy spawn/aim/collision, real card offers, timed active ability use and 0.2-second samples of bullet centers within the actual 540×960 view. The metric is time-weighted visible enemy bullets in *Worlds 2–4 enemy waves* (excluding boss phases).

| Ship / difficulty / Hangar | Previous 1.2 | Combined HP + first-shot | Relative change | Four-world wins |
| --- | ---: | ---: | ---: | --- |
| Vanguard / Normal / no Hangar | 23.69 | 26.94 | +13.7% | 0/3 → 0/3 |
| Arcwing / Normal / mid Hangar | 9.19 | 10.74 | +16.9% | 2/3 → 2/3 |
| Bulwark / Hard / max Hangar | 1.64 | 2.45 | +49.4% | 1/3 → 1/3 |
| Wraith / Insane / max Hangar | 2.09 | 2.20 | +5.3% | 2/3 → 2/3 |

**Total victories:** 5/12 baseline and 5/12 challenger. World 1 wave counts remain identical. The baseline can be more crowded than the challenger in individual seeds or with different upgrade outcomes, so do not claim this guarantees more projectiles at every moment.

The first combined prototype held slow shooters until y ≥ 16. It actually reduced visible density in three cohorts; the code was revised to hold only until y ≥ 0 and all four cohorts then showed a positive later-wave density difference. That initial failure and correction matter for future windup adjustments.

**Gameplay validation:** 1,966 simulation/assertion checks, zero failures (Actions #44127618643), existing 24-seed World 1 (8/24 never actives, 17/24 immediate, 17/24 timed), genuine four-world Normal fixture, six ship campaign smokes, the UI/screenshot matrix, save/replay and unsigned iPhone compile (#44127618597) all passed before the documentation/version-only edits.

**Limitations:** This is 12 scripted starting seeds, not human-player win-rate evidence. Enemy survival changes draft RNG, kills per minute, XP acquisition, offscreen escapes, and the distribution of game phases. Long-term progression pace and shot readability on a physical iPhone require playtesting. Heavily upgraded waves remain much quieter than boss fights even after the change. Do not blindly add more HP or make every first shot instantaneous.

---

# Earlier HP-only screen-pressure experiment (archive)

**Status:** HP-only baseline experiment retained as a comparison, not the accepted combined version. Source data are in [Actions
#44106741711](https://github.com/killjoy00/StarRun/actions/runs/44106741711).

## HP-only test

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

