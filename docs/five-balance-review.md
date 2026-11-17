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
