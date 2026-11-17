# Five-part balance pass (after the 1.1 release candidate)

**Scope:** Later update only. The existing signed 1.1 TestFlight request is
untouched. No ad, IAP, App Store Connect or Apple signing changes.

## 1. Reward timing, not button spam
- Aegis precision: target lane must actually approach the ship; at 0.7 seconds
  or less, grant +14 shield (World 1) or +18 (later worlds) times ability power,
  with a 25% cooldown rebate. Previously any simultaneous beam, even a distant
  harmless lane, could grant +10 shield and a 20% rebate.
- Flak: within real ordnance/mine/slag impact windows, grant +10/+16 shield and a
  10% cooldown rebate, instead of +8/+12 shield and no rebate.
- Jammer: a charge interrupted in the final 0.9 seconds earns a 30% cooldown
  rebate. Interrupting in the earlier 0.9–1.5-second window still works but
  earns just 10%; casting before a charge begins still suppresses future shots.
- No flat power or duration buff for using abilities blindly.

## 2. Give purchased Hangar ranks a more noticeable progression step
- Rank 0 and rank 1 remain unchanged, to preserve beginner Normal and
  the no-Hangar Hard/Insane difficulty contract.
- Beginning at rank 2: Maintenance bots repair 0.20 hull/s/rank (was 0.15);
  Shield lab regenerates 0.30 shield/s/rank (was 0.25).
- They still cost Cores. The effect is gradual; it cannot guarantee Hard wins.
  Compare Kestrel Hard and Haven Insane under none, mid and max Hangar.

## 3. Make invested fusion plans discoverable
- With a rank-3+ equipped active ability and a free slot, every third level
  can offer one not-yet-known, legal, non-banished partner as a normal card.
- The offer is chosen from the existing pool. It can replace an ordinary card
  only; it does not auto-install or create an extra pick, active slot, or Core.
- Unique cards and save/restore determinism are tested. We check Shieldstorm
  formation under actual offered cards and an existing shield-first bot policy.
  The bot might still prefer another card; formation is not guaranteed.

## 4. Recheck route choices before touching their values
Shielded Passage has recently received a major buff (35% incoming reduction,
15% automatic damage while shields are high, 15% ability cooldown reduction,
70% warp repair). Earlier studies favoring Redline predate the final changes.
A new matched 1.1-vs-challenger route study covers Shielded, Redline and Hunter
on Arcwing Normal/mid Hangar, Bulwark Hard/max Hangar and Wraith Insane/max
Hangar. Test outcome stability and distinct trade-offs, then tune only if a
clear systematic imbalance remains. Do not nerf a route based on 2–3 seeds.

## 5. Make overlapping threats fair and measure late boss pacing
- A beam that hits simultaneously with another on the *same simulation frame*
  deals 35% of its ordinary damage. The first impact remains full strength,
  both beams still fire, and Aegis still protects fully if timed.
- The combat log explicitly records the reduced stacked impact.
- The campaign simulator samples every 0.2 seconds, recording time when a red
  charge and an incoming projectile demand a simultaneous response, and time
  when no relevant counter is ready. This is diagnostic only.
- Per-world stage reports now expose **boss seconds** from boss arrival to
  fight end. Analyze surviving stage clears separately to avoid confusing
  early death with a short boss fight.
- The experiment copies the same diagnostic code into its pinned 1.1 baseline
  worktree, so comparisons have the same measurement definitions.
- No wholesale HP or spawn increases, no hidden guaranteed wins or invulnerability.

## Acceptance and interpretation
- Strict Godot parser, UI/screenshot regression, save/replay tests and iPhone
  compile must pass.
- Twenty-four-seed World 1: compare never/on-cooldown/timed outcomes;
  protect the genuine timed-input advantage.
- Verify real four-world Normal campaign completion.
- Keep the established no-Hangar Hard/Insane World 1 gate by running actual
  encounters (not a difficulty-specific artificial loss condition).
- Compare real cleared boss times, unanswered warnings and 4-world victories
  across routes using identical starting seeds. Report raw trial counts, never
  claim they're actual human success rates.
- If values fail one of these gates, amend the PR and rerun; do not ship the
  analysis branch to TestFlight before verifying the result.

Baseline: immutable Star/Run 1.1 main commit
`1509dcad9092cf9a2d4660886bfecb121662df64`.

## Matched study results (GitHub Actions 44003018896)

All 14 jobs passed at the behavior-measuring commit; a subsequent test-only change corrected a test fixture that had accidentally let every shield recharge to maximum. The simulator's combat behavior did not change between those two commits.

| Timed-ability build / route | Baseline four-world clears | Challenger |
| --- | ---: | ---: |
| Arcwing Normal / mid Hangar / Shielded | 2/3 | 2/3 |
| Arcwing Normal / mid Hangar / Redline | 3/3 | 2/3 |
| Arcwing Normal / mid Hangar / Hunter | 3/3 | 3/3 |
| Bulwark Hard / max Hangar / Shielded | 1/3 | 1/3 |
| Bulwark Hard / max Hangar / Redline | 2/3 | 1/3 |
| Bulwark Hard / max Hangar / Hunter | 1/3 | 1/3 |
| Wraith Insane / max Hangar / Shielded | 3/3 | 3/3 |
| Wraith Insane / max Hangar / Redline | 3/3 | 3/3 |
| Wraith Insane / max Hangar / Hunter | 3/3 | 3/3 |

**Route decision:** No consistent three-route domination after the latest Shielded buffs. Hold numerical route powers, HP and rewards unchanged. Redline lost one clear in two three-seed comparisons, but the result is too sparse to justify an across-the-board nerf or buff.

**Progression:** Kestrel Hard/mid Hangar and Haven Insane/mid Hangar both cleared World 1 in **0/5** timed focused-build trials before and after. In one Kestrel seed, boss HP remaining decreased from about 16,343 to 2,298 and survival extended by 15 seconds, but changing draft RNG prevents attributing that entirely to the purchased sustain. No-Hangar Kestrel Hard and Haven Insane both passed separate no-clear gates. The additional rank-two sustain is a modest progression improvement, not a solution to the entire difficulty gap.

**Fusion availability:** Shielded-build Arcwing Normal/mid Hangar with Shielded Passage cleared World 2 in 2/5 baseline vs 4/5 challenger runs, and World 3 in 1/5 vs 3/5. Neither configuration cleared World 4. Shieldstorm formation was 3/5 baseline vs 2/5 challenger; the new targeted offer increases the opportunity to draft a missing partner, but it is **not proven** to improve actual fusion completion or win rates. Avoid extra automatic fusion power until broader seeds or human UAT.

**Overlapping warnings:** Defensive-readiness and charge/bullet overlap seconds vary with build and survival length; they did not decrease consistently. The actual secondary heavy-beam hit reduction is separately unit-tested and does not depend on winning a scripted campaign.

**Boss pacing finding:** The well-equipped Wraith on Insane demolished the World 3 Crucible boss in roughly 1.4–4.5 simulated seconds and World 4 Void Regent in roughly 1.3–2.8 seconds in challenger victorious runs. This is a real late-build pacing issue. Do **not** add a hidden boss HP multiplier, artificial victory gate, or blanket invulnerability in this balance patch: those would devalue Hangar investment and might make ordinary builds unable to clear. A later visible boss-phase redesign with tested counterplay is more appropriate.

**World 1 24-seed benchmark:** 9/24 no-actives, 18/24 on-cooldown, 17/24 timed (older 1.1: 9/24, 17/24, 17/24). Timed play preserved higher average ending hull but did not consistently outperform spam in raw clears. The exact active-use bot and the small fixture are limitations; next iteration should target dangerous windows and usability instead of blindly inflating damage/cooldown bonuses.

All statistics are scripted samples; none are human win rates. The release must still pass the full CI suite and on-device QA.
