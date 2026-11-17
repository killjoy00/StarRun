# Star/Run 1.2 — tougher bosses and a longer Hangar progression curve

## Release discipline
This is a **new 1.2 candidate** built after the five-part 1.1 balance pass
(PR #35). The existing 1.1 private TestFlight release request stays pinned
to its previously reviewed commit. This PR is **not** an App Store submission
and does not activate live/sample ads or the Remove Ads purchase.

## Boss tuning
Bosses receive their own health-pressure multiplier **in addition to**
the existing difficulty threat scale and their authored early-world bridging.
Targetable modules gain the identical multiplier so it remains possible to
open real mechanics such as Storm launch bays, Crucible cooling vents and
Regent pylons. Regular enemies, spawn density, XP and their health do not
change.

| World | Normal boss HP vs 1.1 | Hard boss HP vs 1.1 | Insane boss HP vs 1.1 |
| --- | ---: | ---: | ---: |
| 1, Harvester | ×1.10 | ×1.12 | ×1.35 |
| 2, Storm Carrier | ×1.18 | ×1.34 | ×1.55 |
| 3, Crucible Engine | ×1.30 | ×1.55 | ×1.85 |
| 4, Void Regent | ×1.30 | ×1.55 | ×1.85 |

The boss-specific **increment** on Hard/Insane is bigger than the increment
for the ordinary enemy. In particular, previous Harvester Hard/Insane HP was
already raised substantially; this revision does not repeat that full jump
at the opening boss, while Insane gets a larger increase to overcome the legacy World-1 Hard-to-Insane scaling inversion. Stage 2 maintains the existing World-1-to-2 boss-HP
bridge. Endless uses the same World-3+ additional multiplier without
changing the authored endless growth curve.

The interval between ordinary boss projectile fans is divided by:

| Difficulty | Before | Now |
| --- | ---: | ---: |
| Normal | 1.00 | 1.08 |
| Hard | 1.00 | 1.15 |
| Insane | 1.25 | 1.40 |

The base 1.1 fan cadence multiplier is retained. Boss *non-beam* projectile
strength gets an additional ×1.00 / ×1.05 / ×1.12 for Normal / Hard / Insane;
the existing global threat damage multiplier still applies. The user still
sees exactly the same number of projectiles in each fan, boss minion launch
schedule, multi-lane warning duration, timed heavy-beam damage and heavy-beam
cadence. No unannounced invulnerability, boss maximum-HP cap or hidden
automatic boss kill was added. The full visual boss phase redesign
remains a separate task in issue #36.

## Hangar economy: another 10%
The old 1.1 Hangar tier cost was already
`ceil((base + step × rank) × 1.15)`. New **future** purchases use
`ceil(previous displayed price × 1.10)`. This intentionally compounds
the increase (not simply changing 15% to 25%).
For example, first Hull plating is now **7 Cores** (previously 6)
and Lance mount is **51 Cores** (previously 46).
Refund All credits existing per-rank purchase **receipts**, not new
higher prices; the older baseline price migration is unchanged.
Ship/pilot unlock pricing and post-run Core income are unchanged.

Five extra rank endpoints:
- Hull plating 6→7 (+10 more starting hull)
- Shield capacitor 6→7 (+8 more starting shield)
- Shield lab 5→6 (existing rank-two regeneration progression continues)
- Reactor cooling 5→6 (another 3% per-rank base recharge discount)
- Siege targeting 5→6 (another 3% bonus vs boss cores *and* parts)

Two new specialized options (both optional, cost Cores and respec normally):
- **Breach sensors** (Weapons): 3 ranks, +6% damage per rank against
  *targetable boss modules*, not cores or normal enemies. Base cost 18,
  additional cost 8 per rank before the two price increases.
- **Point defense** (Hull): 3 ranks, -5% damage per rank from boss rounds
  and missiles only, **not** heavy beams, slag, or non-boss attackers.
  Base cost 16, additional cost 7 per rank before the two price increases.

Their icons reuse visible existing anti-boss targeting and deflection shapes.
Both are inactive at rank 0, so free starter and daily unupgraded runs do not
receive any unearned defensive or offensive benefit.

## Checks before merge
- A fixed Godot test suite asserts compounding and receipts, rank caps,
  boss-vs-ordinary HP growth, modular boss health scaling, non-beam bullet
  attack changes, targeting-only Breach damage, Point Defense specificity,
  current save schema compatibility and unchanged beam timings.
- Run headless full gameplay/UI/screenshot and iPhone compiler jobs.
- Compare matched seed bot runs from the immutable *1.1 baseline*
  (merged PR #35 SHA `52f0daf6467744e37f2e5c7c30bcbf7d322d4a55`)
  against the candidate for Normal, Hard and Insane, including a full
  max-Hangar boss-focused build.
- Measure full-campaign wins and *actual cleared boss fight seconds*.
  Report no-Hangar progression separately; difficulty might legitimately
  require Hangar upgrades, but the Normal baseline should remain playable.
- Automated bots are **not** human win-rate measurements; combat RNG can
  diverge after the first changed kill or draft outcome.

If the ordinary Normal full-campaign completion fixture fails, reduce boss
health pressure (especially World 2+) before merging. Any signed TestFlight
build must follow final CI and require a new 1.2 request, not silently replace
the currently pinned 1.1 request.

## Matched-seed outcomes (Actions 44007759643)

All seven paired cases ran from the immutable merged 1.1 baseline with
identical starting seeds, timed active use and normally offered draft cards.
Total campaign clears: **9/21 baseline; 9/21 candidate**. This is not a
human-player win percentage; gameplay and draft RNG diverge after changes.

| Test configuration | 1.1 wins | 1.2 wins |
| --- | ---: | ---: |
| Vanguard Normal/no Hangar | 0/3 | 0/3 |
| Arcwing Normal/mid Hangar, Shielded | 2/3 | 2/3 |
| Arcwing Normal/mid Hangar, Redline | 2/3 | 3/3 |
| Kestrel Hard/mid Hangar | 1/3 | 1/3 |
| Bulwark Hard/max Hangar | 1/3 | 1/3 |
| Haven Insane/mid Hangar | 0/3 | 0/3 |
| Wraith Insane/max Hangar | 3/3 | 2/3 |

Measured defeated-boss examples (seconds, average among cleared bosses):
- Vanguard Normal/no Hangar World 1: 56.6→62.0; 3/3 bosses beaten both.
- Arcwing Normal/mid, Shielded World 2: 7.8→22.4, World 3:
  16.1→20.8, World 4: 12.7→14.6; full campaign wins still 2/3.
- Kestrel Hard/mid World 1: 75.6→83.2; 1/3 campaigns won in each.
- Bulwark Hard/max World 4: 4.6→6.6; 1/3 campaigns won in each.
- Wraith Insane/max World 3: 3.5→5.2, World 4: 2.0→3.5; its
  3/3 original campaign wins fell to 2/3.

**Decision:** the stronger boss encounter values create longer fights and
reduce the dominance of max-Hangar Insane builds, without eliminating
Normal four-world completion or materially reducing total scripted wins.
Late boss phases can still collapse in a few seconds for an exceptionally
strong build. Visible phase-specific boss design remains issue #36 rather
than hidden invulnerability in this release.

The new optional Hangar tracks were included in fully maxed build simulations
because they are purchasable. The mid-Hangar test configurations remain
built using the existing core track whitelist. This matched study does
**not** measure how many flights players need to afford more expensive
upgrades; that requires economy-specific telemetry or user playtesting.

All initial parser and UI checks passed. The 24-seed regression required
only two corrections to stale test expectations: the old World-1
Hard/Insane boss-health ratio and the previous 38-track Hangar count.
Neither correction changes mechanics or the numbers above.
