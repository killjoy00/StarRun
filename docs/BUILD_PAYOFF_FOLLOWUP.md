# Star/Run build payoff and clarity follow-up

This change follows the Phase 2+3 build overhaul in [PR #62](https://github.com/killjoy00/StarRun/pull/62). It deliberately **does not add a new combat control, currency, progression gate, mandatory active casting or new damage multipliers**.

## What players see

1. **Your build at work** on the results screen: the two most frequently activated automatic engines, their real event counts, and direct engine damage where it can be attributed unambiguously. This is a frequency recap, **not a power ranking**. Salvage Carrier's escort damage overlaps other escort sources and is therefore *not* claimed as direct engine damage. No panel appears if nothing activated.
2. **Evolution payoff cues**: a single ring and short word near the impact when a rank-5 specialization actually matters (focused hits, consumed marks, beam interruption, burst, or shield repair). The labels use real-time decay for 3x legibility, are rate-limited, respect reduced-effects mode, and do not consume the game RNG.
3. **Meaningful choice labels**: eight compact role descriptors next to the existing evolution names and descriptions (e.g., Boss & module damage vs Beam interruption). The fusion panel also correctly says two rank-5 abilities form a **new rank-1 fusion** and free one slot; it no longer implies rank values are combined.
4. **More trustworthy diagnostics**: a new dedicated six-ship × Worlds 2/3/4 fixture measures both evolution choices for all four weapons (144 cells), all six earned engine signatures (108 cells), and matching baseline combat impact with zero manual casts.

## Test limitations

The new matrix uses **post-warp, preinvested loadouts** built from *real, legal upgrade thresholds*, identical starting seeds for baseline and specialized actions, real enemy health and damage functions, shields and charged attack cancellation. It is designed to test whether each option makes a measurable difference once obtained, even for ships whose usual no-cast bot dies before reaching World 2.

It is **not** a claim that those builds were organically drafted, that their paths are equally likely or equally strong, or that scripted play demonstrates player fun. The existing natural-campaign, zero-cast, multi-ship, boss-phase, Archive, UI and unsigned iPhone checks stay enabled. Human TestFlight acceptance is still required before balance changes or an App Store release.

## Regression expectations

- Daily, existing saved runs and World 1 do not gain new evolved effects or engine behavior.
- Rank-5 choices and chosen feedback remain deterministic across save/resume.
- Mark consumption occurs only after positive actual damage; sealed boss phases cannot waste a mark on a zero-damage hit.
- No extra XP, Cores, enemy kills, or combat choices are injected.
- Physical iPhone should verify both reduced effects and normal effects at 1x/3x, plus small-screen legibility of the new debrief and choice labels.

**Delivery:** gameplay code and CI PR only. No TestFlight upload, version change or public App Store submission.
