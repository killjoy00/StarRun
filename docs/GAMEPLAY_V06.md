# StarRun v0.6 — Tactical bosses, build identities and strategic warps

**Status:** implemented gameplay design for PR #9, pending automated verification and physical iPhone UAT. This supersedes [v0.5](GAMEPLAY_V05.md) for boss, synergy and between-stage rules. The baseline remains four stages, four active slots, twenty available abilities, six ships and six pilots, and Normal/Hard/Insane (1×/1.75×/2.5× core payout).

## Design problem addressed

StarRun deliberately removes steering and aiming. To compensate, it needs deeper **build decisions**, **timing decisions**, **automatic targeting strategy**, and **consequential campaign choices**—not simply bigger enemy health bars.

User-approved priorities (Nov. 13, 2026):
1. Four bosses must be distinct tactical fights with destroyable components and combat phases.
2. Ability pairings and run-long Prototypes should create identifiable build styles with explicit advantages and disadvantages.
3. Transitions between stages should require choices about Prototypes, safety, damage and risk/reward, not just a routine level-up.

## Boss encounters and targeting

| Stage | Boss | Destructible components | Mechanic and phases | Player counterplay |
|---|---|---|---|---|
| 1 — Debris Belt | Harvester | None; teaches the baseline | Visibly charges the heavy laser; normal weapons and Nova/EMP can disrupt by damage or cancel | Preserve Aegis/interrupt for impending beam, instead of spamming |
| 2 — Ion Storm | Storm Carrier | **Port and starboard launch bays** | While bays survive, the core has partial armor, the boss deploys Storm Weavers roughly every five seconds, and fires three-missile salvos. Destroy both bays to stop launches and reduce salvos to one missile | Auto-target bays first; intercept missiles; choose when to disable the launch capacity |
| 3 — Solar Foundry | Crucible Engine | **Two cooling vents** | With vents active, core alternates in nine-second sealed/exposed windows: sealed phase sharply reduces core damage and releases molten slag. Destroy both vents to expose the core permanently | Choose attack/burst windows or take out the vents; defend against heat and slag |
| 4 — Void Citadel | Void Regent | **Two shield pylons** | Pylons reduce damage to the core and sustain two simultaneous telegraphed beam lanes. Destroy pylons to remove the armor and reduce the attack to one faster beam. Under 35% core hull, the Regent enters a distinct **Final Onslaught** phase | Break pylons, plan defensive cooldown windows and finish the core during escalating pressure |

Each component has its **own hit points, position tied to the moving boss, distinguishable silhouette, health bar, and separate death event**. The boss HUD names the current phase. Auto-aim Seeker/Pulse and target-seeking abilities prioritize modules appropriately, because players cannot steer or click targets. The goal is not to force manual aiming through a hidden UI.

## Four active synergies

Automatic activation: own the required paired active abilities, within the four-slot cap. No separate skill tree or fifth button. Level-up drafts **highlight cards that complete a synergy**, while retaining other independent choices.

| Identity | Requires | Advantage | Real cost |
|---|---|---|---|
| **Fortress** | Aegis plus Capacitor, Barrier, Deflector or Mend | +60% shield regeneration, -15% hull damage | -18% automatic weapon damage |
| **Glass Cannon** | Overdrive or Focus plus Strike, Barrage or Overload | +28% automatic weapon damage, +20% active power | +28% hull damage |
| **Control** | EMP, Chrono or Jammer plus Nova, Flak, Prism or Decoy | -18% ability cooldown, 12% slower enemy projectiles | -12% automatic weapon damage |
| **Salvager** | Salvage plus Siphon, Reboot or Mend | +25% end-of-run core payout and an extra core on salvage-window kills | -18% automatic weapon damage |

Multiple synergies can be active if a four-slot combination legitimately satisfies them; their benefits and costs stack. **Build** displays active synergies and the exact tradeoffs; **Results** includes the run's final combination.

## Prototypes — one after each of the first three bosses

Three randomly selected, **nonduplicated offers** appear after each boss; the chosen Prototype persists for the remainder of that flight. The player cannot reroll the hand by leaving and resuming.

| Prototype | Benefit | Cost |
|---|---|---|
| Bastion Lattice | +40% shield regeneration | -12% automatic weapon damage |
| Volatile Core | +30% automatic weapon damage | +25% incoming hull damage |
| Null Harmonics | -22% cooldown duration | -12% automatic weapon damage |
| Salvage Charter | +35% run payout | -15% automatic weapon damage |
| Breach Optics | +70% damage to destructible boss components | -10% damage to other targets |
| Mirror Cell | +30% shield capacity immediately | +15% ability cooldown |
| Echo Coil | +40% ability damage/power | +18% ability cooldown |
| Emergency Safeguard | 30 shield instantly on the first shield break each stage | -10% automatic weapon damage |

These are not small stat-only handouts: they reinforce different build archetypes, sometimes competing for the same combat resource.

## Between-stage strategic flow

1. **Defeat boss.** Fixed-step simulation freezes. Show cinematic explosion and a player-confirmed **Warp to next stage** button (Stage 4 instead ends with **Claim victory**).
2. **Warp animation.** No combat, settlement or automatic advancement.
3. **Prototype draft.** Choose one of three with a clear benefit and cost. The other two are lost. Hand and RNG are checkpointed before display.
4. **Choose next route.** One of three mutually exclusive choices:
   - **Safe Passage:** repair 55% of maximum hull; shields fully recharged. No bonus power or bounty.
   - **Redline Jump:** automatic weapon damage ×1.25 for the **next** stage; repair 10% of maximum hull; start on 60% shield.
   - **High-Risk Contract:** enemy health, damage and spawn pressure ×1.30 for the **next** stage; repair 30% hull and fully recharge shield. Kill the next boss to bank **20 × next-stage number** base cores, which then receive the selected difficulty and payout multipliers. Dying before the boss grants no contract bounty.
5. **Enter the next stage.** Begin at the same absolute simulation time; reset stage wave director and hazards, preserve build and Prototype selections; award the normal extra milestone upgrade draft.

**Exactly-once rule:** Neither a resize, resume, repeated button press nor a stale checkpoint can grant duplicate Prototypes, stage advances or contract payouts. The save includes `prototypes`, `prototype_offers`, `intermission_step`, `route_choice`, `stage_power`, `stage_risk`, `bounty_earned`, and boss phase/module state.

## UX and accessibility

- Every Prototype and route choice explicitly displays **BENEFIT** and **TRADEOFF** on a separate wrapped line. Touch targets remain >=44 logical points; phone displays use scrolling content without horizontal movement. Important choices never depend on color alone.
- The Build screen shows active archetypes, installed Prototypes, their costs, and the current route, ahead of weapon and system details.
- The Results screen displays final build identity and earned bounty cores, alongside total payout and the established damage/flight-recorder detail.
- Boss modules are visually distinct from the core, have individual health bars, and the boss HUD states which mechanic is active.
- No new steering/aiming, fifth button or mandatory account actions.

## Automated and device gates

Automated tests: module destruction changes attacks, core vulnerability varies with phase, automatic targeting hits parts first, four synergy trigger conditions and drawbacks, Prototype benefits/costs, three exclusive route rewards, deterministic three-card choice, interruption and checkpoint restore during stage transitions, legacy save compatibility, full four-stage sequencing, 375×667/390×844 phone wrapping and sticky navigation, and Web/Windows/Linux and unsigned iPhone exports.

Physical/human tests remain required: whether boss component behavior is intuitive without manual aiming; if risk/reward really changes decisions; Prototype legibility on the smallest supported screen; and actual balance of Stages 2–4. No numerical simulator score is proof of fun.

**Deferred deliberately:** veteran direct-stage deployment with proportionately reduced rewards, formal threat budget and advanced boss subphase scripting, extra player classes, ads, StoreKit and Steam Deck device verification. These are separate scopes, not secretly treated as passed or shipped.
