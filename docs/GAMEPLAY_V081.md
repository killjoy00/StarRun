# StarRun v0.8.1: rank-5 fusions

Both component abilities must reach rank 5 before combining. This is an ability-rank requirement, not the overall player level. The upgrade that reaches or crosses 5 previews the resulting fusion; earlier cards remain ordinary active upgrades. The preview uses the new fusion icon and description, and identifies the component rank change and freed slot. Banish mode shows the component actually removed.

New abilities start at rank 1, so a matching partner cannot bypass four occupied slots. Upgrading an already-equipped pair still works at a full bar and frees one slot when both qualify. Consumed components remain excluded from drafts, and the fused ability retains its own upgrade track. Already-earned fusions in older saves are preserved. Older saved hands containing a now-ineligible full-bar partner are rebuilt once without charging a reroll or consuming a level.

## Fusion art

The original ten fusions have individual vector insignia, shared by draft cards, Build and ability buttons. The shared hexagonal frame and two-tone palette connect them to the existing interface. Each cast has its own geometry: a faceted shield and shockwave, three rail beams, a locking clock ring, repair drones, a missile fan, returning scrap, split prism rays, reflecting shield tiles, ghost ships or a reactor discharge. Fusion-produced projectiles use the matching palette.

Forming a fusion has a brief converging emblem and its name above the ship. The cue lasts 1.2 real seconds regardless of game speed, and repeated draft choices cannot restart old cues. Reduced effects retains identifying shapes while trimming glow, fills and decorative motion. All friendly effects remain below live enemy projectiles and beam warnings. Damage, collision geometry and cast cooldowns are unchanged by the artwork.

## Verification

Tests cover every pair threshold, 3→5 and 4→6 crossings, full bars, save/resume and old-hand migration. Rendered checks verify distinct phone-size icons, full/reduced casts, hostile-projectile visibility, formation timing and qualifying/early/banish card labels. The existing touch, safe-area and menu checks remain part of release CI.

The natural-draft Stage 1 comparison now uses 24 seeds per strategy to reduce sensitivity to individual draft paths. Its existing survival and no-Hangar clear gates are unchanged. The separate fixed-equipment timing test uses real rank-5 components and a Hard boss encounter: the source-rank milestones now apply, so a Normal boss no longer distinguishes survival between timed counters and cooldown spam. No equipment changes occur during those fights, and both win-count and hull advantages are still required. These are deterministic regression checks, not estimates of human win rates.

Local results: the 24-seed natural-draft benchmark cleared Stage 1 in 14/24 runs
with abilities unused, 21/24 on cooldown and 21/24 with the timed pilot. Mean
ending hull was 45.8, 105.6 and 124.4 respectively. The fixed-build Hard boss
comparison cleared 5/24 with cooldown spam (8.7 mean hull) and 24/24 with timed
counters (98.9 mean hull). Six later-world fixed-loadout checks also cleared,
using separate abilities whenever their ranks were below the fusion threshold.
The natural-draft result includes draft variance; only the fixed-build comparison
isolates timing.

The same release also includes [16 Hangar tracks, pilot portraits, Wing Drones, Ion Mine and their Storm Carrier fusion](HANGAR_EXPANSION.md). The 24-seed numbers above describe the initial fusion-only pass; the expanded-pool results are recorded with the later changes.
