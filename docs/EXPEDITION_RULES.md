# Expedition destinations, build access and earned recovery

New regular launches enable an explicitly checkpointed rules version. Suspended legacy runs keep their original routes, draft behavior and rewards; Daily is isolated. Production UI and the shared campaign/progression matrix enable the same new rules. Historical diagnostic fixtures that deliberately instantiate the legacy simulation remain unchanged.

## Destinations

Each intermission draws one of two recovery destinations, one of two assault destinations, and one of four opportunity destinations from an independent seeded RNG. Offers persist across suspend/resume and cannot be rerolled. All eight destination cards state actual effects on next-world hull/shield, combat, XP, bounty, or earned choices. Elite destinations change the existing natural encounter formations (no additional forced kills). The chosen group remains available to existing engine behavior and diagnostics, while the concrete destination is saved and shown by the UI.

## Specialized builds

- On two of every three eligible later-world drafts, guarantee a genuine relevant offered card when available; preserve at least one independent choice and any emergency recovery or rare mutation. Favor rank-invested fusion partners and actual recipe progress.
- A full active bar may learn an eligible missing fusion partner if another existing component is invested to rank 3+. The player explicitly replaces an unrelated non-fused active or backs out to the same hand. Replaced ranks are lost, new partner starts at rank 1; normal rank-5 fusion requirements remain. No fifth slot or free ranks.
- A separate optional workshop at the W2 transition (or earlier on Research Station or Smuggler's Corridor) offers up to three eligible mutations on owned weapons. Once per run, with the existing one-mutation limit. It neither replaces the Prototype nor requires sacrificing a normal upgrade. No workshop on skipped worlds, weaponless artifacts, or Daily.
- Use the actual rank increment when previewing recipe progress. Existing mechanical engine behavior, effects and debrief measurements remain intact.

## Advanced recovery

Normal and Daily payout, Hangar prices, Salvage multipliers, and successful advanced boss-clear rewards remain unchanged. Before a played boss clear, a new regular Hard/Insane run earns one recovery Core per 12 kills (capped at the original flat base of 30), a proportional recovery-contract stipend, and the existing difficulty multiplier on actually earned kill and bonus Cores. No automatic launch stipend for zero kills; a defeated run can still earn rewards through play. The regular 30% Core multiplier and actual earned salvage bonuses remain.

Replaying the original #82 zero-Hangar kill/time traces with the simplified recovery formula gave estimated Core/min: Normal 15.58 (unchanged), Hard 43.75 → 12.68, Insane 111.35 → 13.81. These are estimates from recorded traces, not fresh measured payout results; verify using the matched recovery workflow.

## Validation

- New route/workshop/swap and reward fixtures test exact selection, resume, invalid selections, no duplicate reward, actual rank loss, one-mutation limit and Daily/legacy isolation.
- The regular campaign matrix uses the new launch version when available, and resolves only real offered destinations and workshop choices.
- All active ordinary CI and matched 50-run progression cohorts must pass. Run the 168-campaign fleet experiment on the final ready PR; preserve zero-Hangar zero campaign victories, p32 40–60%, max at least 70%. Adjust only narrowly justified new destination/draft incentives if those gates miss; do not reduce previous campaign difficulty targets.
- The recovery comparison verifies all 168 attempts (seven ships, three difficulties, four matched seeds, two revisions), unchanged advanced opener combat and no superior early-failure Core/min compared with Normal in the tested cohort.
- PR #88 is separate and covers increased Endless scaling. Land it first, integrate the approved change without overwriting either PR, and validate the combined revision before merging. No release/deployment is authorized.


## Combined validation

#88 was merged at e8e967d739db8022ff43e5466eb22b929c6dc110 and incorporated with both original parents, preserving its exact Endless scale and strict isolation experiment. The new `Expedition Endless compatibility` workflow runs 48 actual candidate flights (same 3 ships, 2 budgets, 2 cast policies and 4 seeds per cell used in #88); verifies real offered destination groups, selections, mutation/swap use, compounding damage, genuine W4-to-W12 continuation, and no lost earned payout. It is not an isolated before/after tuning experiment. Additional UI fixtures check narrow-phone layout and actual save/resume for replacement and workshop choices.
