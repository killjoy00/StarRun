# StarRun v0.8: later worlds and iPhone controls

November 14, 2026 (Central). This builds on the separately merged menu redesign and combat readability pass. It addresses the feedback from TestFlight 0.7.2 build 1008.

## World scaling

Stage 1 retains its original enemy numbers. Subsequent worlds use fixed authored multipliers, rather than dynamically matching the player's build. Enemy collision damage, corrosion damage, firing cadence, wave health and boss modules all follow the world curve. The existing telegraph durations, readable projectile layers and entity limits remain in force.

| World | Wave health | Spawn pressure | Incoming damage | Firing cadence | Boss hull | Boss module hull |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 1× | 1× | 1× | 1× | 6,200 | — |
| 2 | 4.8× | 1.6× | 1.8× | 1.15× | 24,000 | 2× |
| 3 | 11× | 1.9× | 2.8× | 1.35× | 80,000 | 3.25× |
| 4 | 22× | 2.2× | 4.2× | 1.6× | 225,000 | 5× |

Difficulty and route modifiers still apply. Compared with 0.7.2, world 2/3/4 boss hull increased from 10,000/15,500/22,000. Ordinary enemy health was previously only 1.55×/2.15×/2.95×, while most damage did not scale at all.

Aegis and Nova Guard had a permanent invulnerability loop once duration bonuses exceeded the reduced cooldown. Their invulnerability now ends at least 1.5 seconds before that cast's cooldown finishes. Ordinary early casts keep their full duration. Stronger blasts, healing and other effects still benefit from upgrades. Nova Guard blocks for 2.4 base seconds on an early cast and 3.8 on a counter; a timed counter also earns the stronger blast, healing and cooldown rebate. This leaves actual windows where the player needs another defense.

## Ten new passive upgrades

These enter the draft pool in world 2, leaving the opening pool focused. Each has ten ranks and bonuses at ranks 5 and 10. All effects below are passive and consume no active slot.

| Upgrade | Per-rank effect | Additional rank 5 / rank 10 bonus |
|---|---|---|
| Siege rounds | +5% automatic-weapon damage to bosses and their parts | +15% / +25% |
| Finisher rounds | +4% automatic-weapon damage below 35% enemy hull | +15% / +25% |
| First strike | +4% automatic-weapon damage to undamaged enemies | +15% / +25% |
| Blast plating | 3% less beam, missile, mine and slag damage | 5% / 5% less |
| Insulation | 3% shorter ion, heat, gravity, corrosion and cooldown disruption | 10% / 10% shorter |
| Shield reserve | Casting an active restores 0.75% of maximum shield | +2.5% / +5% |
| Combat repairs | Each kill repairs 0.1 hull | +0.25 / +0.5 hull |
| Last stand | +3% automatic-weapon damage below 40% player hull | +10% / +20% |
| Shield focus | +2.5% automatic-weapon damage above 75% shield | +10% / +15% |
| Follow-through | Casting an active speeds automatic weapons by 3% for four seconds | +10% / +15% |

## Fusions and labels

Once two actives fuse, both consumed component tracks leave future drafts and rerolls. The fused ability gets its own upgrade card, starts at rank 1 and gains two ranks per pick, capped at 10. Each subsequent rank adds 4% effect strength, with extra strength and cooldown bonuses at 5 and 10. The source ranks retain their inherited milestone bonuses without appearing as separately equipped skills. Unowned fusions cannot be drafted directly.

An old checkpoint with an already-consumed component in its open draft is rebuilt once, without spending another reroll or consuming another pending level. The rebuilt hand is then save-stable. Fused source skills still count toward existing build synergies.

Every card retains an **Active**, **Passive** or **Auto weapon** label, even when it highlights a fusion or milestone. Fused skills show their own rank in Build. No extra explanatory paragraph is added to the menu.

## iPhone layout and input

The combat header now uses the same native safe-area margins as menus, plus a small top cushion. HUD and toolbar occupy separate rows; the playfield gives up the required height. Four ability buttons remain above the home indicator.

Scrollable content allows input to pass from cards, labels, icons and purchase buttons to the native ScrollContainer. Dragging beyond its 8-point threshold cancels the pending tap. Hold-and-drag works in both directions, and a stationary tap still chooses or buys normally. Keyboard/controller focus behavior remains intact.

## Evidence

`tests/stage_scaling_probe.gd` holds progressively stronger builds fixed to isolate world scaling from draft luck. It uses two seeds, half/full Hangar profiles, 90 seconds of waves followed by the actual boss, and a defensive pilot using Nova Guard and Repair Matrix. No invulnerability is injected. The deliberately strong world-4 fixture has rank-10 automatic weapons and extensive passive upgrades.

| World | Mean boss fight, before | Mean boss fight, after | Mean damage received, before | Mean damage received, after |
|---|---:|---:|---:|---:|
| 2 | 26.6 s | 59.1 s | 103.4 | 477.1 |
| 3 | 16.3 s | 73.8 s | 25.9 | 716.7 |
| 4 | 6.3 s | 64.5 s | 0 | 1,347.0 |

All 12 strong defensive fixtures cleared; healing can restore hull after substantial incoming damage, so ending hull alone is a misleading pressure measure. Six additional runs with abilities unused all failed: world 2 at 125–137 seconds, world 3 at 106–118 seconds, and world 4 at 42–73 seconds. Six runs also stacked the new passives at progressively higher ranks and remained clearable. These are deterministic comparisons, not human win-rate targets.

A separate natural-draft campaign probe uses full-length worlds and no injected upgrades. In a four-run curve check, the half-Hangar pilots died in world 2; both full-Hangar pilots cleared worlds 1–3 and one cleared world 4. This checks that pressure also rises during real progression; the small sample does not establish final balance.

Simulation regression tests cover each new passive's actual effect, all ten fusion offer pools, saved-hand migration, fusion ranks, invulnerability gaps and stage damage. Responsive and rendered tests cover phone layouts, retained combat readability, actual held-button dragging and notch clearance. Physical-device feel and difficulty tuning still depend on the next TestFlight playtest.

The full-run Stage 1 benchmark remains a survival/draft diagnostic (12 seeds per strategy). Because combat and drafts share RNG, different input strategies also receive different draft hands and builds; its ending-hull comparison cannot isolate timing. The timing regression now uses 12 matched seeds **with identical fixed equipment**, an immediate real boss encounter, and no upgrades selected during the fight. Timed counters cleared all 12 fights at 100 average hull; cooldown spam cleared 2 at 3.5 average hull. Both win-count and hull advantages are required. The separate full-run checks still require a no-Hangar Stage 1 clear and a clear survival benefit over never activating abilities.
