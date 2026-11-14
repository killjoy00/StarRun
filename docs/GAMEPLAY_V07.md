# StarRun v0.7: equipment pairs, stronger upgrades, easier phone controls

**State:** implemented on the v0.7 branch for testing. Keep separate from the public build until Godot, replay, UI and unsigned iPhone checks pass. Signed TestFlight and real-device acceptance are separate release gates.

## Player feedback addressed

- The gray turret with the yellow center looked like placeholder art. The Stage 1 stationary gun now has a layered armored silhouette with recognizable weapons, vents and the same outline language as enemy ships. No target behavior or balance was changed by the art update.
- Upgrade selection required too much vertical scrolling, particularly with a fourth choice unlocked. Phones now show two wide upgrade cards per page, with **Prev** and **Next** kept on screen. Each card has its own one-tap choice and optional removal action. A reroll creates a new hand; paging never does.
- The four ability buttons are on **one row** below the playfield on phones, using short names and prominent ready/cooldown labels. Touch targets remain at least 44 points. This frees more height for the moving playfield and leaves the buttons visible during combat.
- Copy is short, conversational and mechanical. Tell players what a choice does and what it costs. No generic encouragement, marketing claims, sales slogans or dramatic claims about how they should feel. Menu, drafts, route choices, Build and Results were rewritten accordingly.

## Ability fusions

StarRun still offers **20 original active abilities**. Each has one fixed partner. Learn both and they automatically become one stronger active on a single cooldown. The two source buttons are replaced by one fusion button; the freed slot can be used for another ability. The source tracks remain upgradable and are saved with the run. A full four-slot bar may still draft a matching fusion partner, since the fusion occurs in the same choice.

| Original abilities | New active | What one cast does |
|---|---|---|
| Aegis + Nova | Nova Guard | Block and blast; a timed counter makes the blast much stronger, repairs hull and shortens cooldown |
| Overdrive + Rail Strike | Railstorm | Faster guns plus three heavy hits |
| Chrono + EMP | Time Lock | Slow attacks, cancel beams and silence guns |
| Repair Drones + Capacitor | Repair Matrix | Hull repair, shield refill, chaff barrier, clear heat and corrosion |
| Barrage + Flak | Missile Grid | Clear ordnance and fire a larger rocket salvo |
| Salvage + Siphon | Scrap Converter | Drain for hull and start a longer salvage window |
| Focus + Prism | Prism Focus | Stronger guns and convert enemy bullets to guided shots |
| Barrier + Deflector | Reflector Wall | Block small shots, restore shield and fire back |
| Jammer + Decoy | Ghost Signal | Jam enemy guns, divert aim and clear missiles |
| Overload + Reboot | Reactor Surge | Detonate chaff and reduce other active cooldowns |

Fusions are automatic and deterministic. The existing four build archetypes still recognize their component abilities after a fusion. Fusion power depends on the source ranks, with additional gains at ranks 5 and 10. A fusion has **one** cast count, **one** cooldown, and neither source skill can be separately activated.

## Passive team-ups

Both required weapon/system upgrades must be installed; no extra button or slot is used.

| Pair | Joint bonus |
|---|---|
| Armor + Hull | More small-shot reduction and 10% less hull damage |
| Shield + Regenerator | 40% faster shield recharge and shorter shield-break downtime |
| Pulse + Targeting | More Pulse damage and a better Pulse critical chance |
| Seeker + Munitions | Stronger Seeker payloads plus a small all-gun bonus |
| Coolant + Amplifier | Shorter cooldowns and higher ability effects |
| Repair Bots + Data Collector | Stronger repair and more XP from kills |
| Arc + Autoloader | Faster lightning and another chain target |
| Lance + Targeting | Stronger Lance damage, including on boss modules, plus a higher critical chance |

## Rank 5 and rank 10 upgrades

All **35 original upgrade tracks** now have named milestones at rank 5 and rank 10. Cards preview the next milestone, not both in a giant paragraph. Weapon and system choices add two ranks per pick, so crossing rank 5 from rank 4 still triggers the bonus. New active abilities start at rank 1; later picks add two ranks. Every active's rank 5/10 milestones make its effect stronger and reduce cooldown. Some retain unique mechanics such as Aegis beam reflection.

Specific weapon unlocks: second and third Pulse barrels; second and third seeker missiles; extra Arc chains; faster and harder Lance. System tracks have additional armor, shield, hull, cooldown, repair, targeting, critical-hit, damage or XP bonuses. Hull and shield rank threshold capacity is granted **only once**, survives checkpoint restore, and is reconciled for older v0.6 saves already at rank 5.

## Acceptance criteria

1. A player can choose among four options on a 375x667 or 390x844 screen using the fixed Next/Prev controls without scrolling vertically.
2. Four active cast buttons remain in a single touchable row during combat and do not cover the playfield.
3. Learning either member of a fusion second always produces one genuinely new cast, removes the old component buttons and frees a slot; saving, resuming, draft rerolling and a full bar do not duplicate or lose abilities.
4. Every passive pair produces its claimed effect in the simulation. Rank 5 and 10 bonuses are real, explained and paid once if they change capacity.
5. Existing v0.6 saves, boss phases, Prototype offers, routes, and rewards still work.
6. A human tester can distinguish the new turret from placeholder geometry and understand what a fused ability does from the Build screen.

**Still required:** full CI, unsigned iPhone compile, signed TestFlight upload, physical iPhone readability/touch QA, and balance/fun testing. None is implied by creating this document.
