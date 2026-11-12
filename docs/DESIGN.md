> **Prototype update (2026-11-12, v0.3):** current playable behavior is defined in [FIRST_PLAYABLE.md](FIRST_PLAYABLE.md). It now has a smaller, faster, more mobile ship, gentle pulse homing, four weapons, six learnable active abilities, eleven passive systems and a 22-track Hangar. The slot limits and launch content below describe the broader release plan and do not cap the current prototype.

# StarRun: Game Design Document

Status: Draft v0.2, 2026-11-12. Working title is the repo name.

The review changes were accepted on 2026-11-12. [FIRST_PLAYABLE.md](FIRST_PLAYABLE.md) records the implemented first-playable rules and overrides older proposal numbers for that slice. [NATIVE_DELIVERY.md](NATIVE_DELIVERY.md) lists unpassed hardware and storefront gates.

How to read this doc: every item is tagged by where it came from.

- **Decided**: you chose it during kickoff.
- **Proposed**: my design proposal. Change freely.
- **Assumption**: I had to pick something to keep the doc coherent and you have not weighed in.
- **Inference**: a conclusion I drew that a source does not state directly.

All numbers are starting values for tuning, not tested balance.

---

## 1. Overview

StarRun is a roguelike autoshooter with bullet-hell density. A spaceship flies up the screen through four levels of enemies. The player does not steer and does not aim. The ship flies a predictable pattern and fires automatically. The player's job is to build the ship through level-up choices and to trigger active abilities at the right moment.

| Item | Value | Source |
|---|---|---|
| Genre | Roguelike autoshooter, vertical bullet hell | Decided |
| Ship control | None. Predictable autopilot, no dodging | Decided |
| Player input | Cooldown ability buttons, no aiming | Decided |
| In-run growth | XP from kills, pick 1 of 3 cards per level-up | Decided |
| Between-run growth | Permanent upgrades bought freely with points, including more card choices and rerolls | Decided |
| Run shape | One run is all 4 levels back to back, death restarts at level 1 | Decided |
| Platforms | iOS and Steam | Decided |
| iOS business model | Free with ads, one purchase removes them | Decided |
| Steam business model | Paid, with a free demo containing one level | Decided |
| Art style | Illustrated hard-surface ships, deep-space painting, neon combat effects | Revised by user, 2026-11-12 |
| Engine | Godot 4, gated by a tech spike (section 14) | Proposed |
| Full-clear run length | 24 to 28 minutes | Assumption |
| Team size | Solo or very small team | Assumption |

## 2. Design pillars

1. **Build, don't steer.** Skill is expressed through build decisions and ability timing. Nothing in the game should require or reward dodging.
2. **Readable chaos.** The screen can be full of bullets, but the player can always tell what is about to hurt and what they can do about it.
3. **Every death is explainable.** Because the ship cannot dodge, the game must never feel like it killed you arbitrarily. Damage is telegraphed, budgeted, and reported back after death.
4. **One thumb, one column.** The whole game plays in a portrait column with three or four buttons. Desktop gets the same column with extra information beside it.

## 3. Core loops

**Second to second.** The ship weaves and fires. Enemies arrive from the top. The player watches for telegraphed threats and presses an ability. Target: meaningful opportunities every 5 to 8 seconds. Holding a ready ability for a threat should outperform pressing it immediately; button frequency alone is not the fun gate.

**Minute to minute.** Kills grant XP. Each level-up pauses the game and offers cards. Target: one level-up roughly every 30 seconds, faster early and slower late (Proposed).

**Level to level.** Each level is about 5 minutes of waves, an elite at the midpoint, and a boss. Beating a boss grants a Prototype (a run-defining relic) and a partial hull repair.

**Run to run.** Death or victory pays out Cores. Cores buy permanent upgrades in the Hangar. Milestones unlock new weapons, abilities, Prototypes, and ships.

## 4. The ship and autopilot

### 4.1 Movement (Decided: predictable autopilot)

- The ship holds a lower flight band, roughly 79–84% down the playfield, with gentle vertical drift.
- Position follows a seeded flight plan with variable-length legs, smooth course corrections and occasional straight stretches. It never reacts to threats. Banking and differential exhaust sell forward flight; periodic edge-to-edge oscillation was rejected in playtest.
- A faint **flight path preview** shows where the ship will be over the next 2 seconds. This is the single most important readability feature: it lets the player see that the ship is about to sweep into a laser lane and press a defensive ability in time.
- The world scrolls downward to sell forward motion.

Each ship has its own pattern, which is a large part of its identity (Proposed):

| Ship | Flight pattern | Profile | Starts with |
|---|---|---|---|
| Vanguard (default) | Smooth seeded arcs and steady stretches, gently banked turns | Balanced | Pulse Cannon, Aegis |
| Bulwark (unlock) | Steady heading with small, slow corrections | High hull and armor, low fire rate | Flak Screen, Nanite Repair |
| Wraith (unlock) | Brisk, wider banked course changes | Low hull, high shield regen | Arc Coil, Chrono Field |

Three ships at launch is an assumption. One ship is enough for the first playable.

### 4.2 Defense model (Proposed)

"Make the ship tankier" needs more than one stat or every defensive card is the same card. Three layers:

| Layer | Behavior | Good against |
|---|---|---|
| **Armor** | Flat reduction per hit. Cannot reduce a hit by more than 75%. | Chaff (many small hits) |
| **Shield** | Absorbs damage first. Regenerates continuously. If it hits zero it goes offline for 3 seconds, then restarts from empty. | Bursts |
| **Hull** | The run's long-term health. No passive regen by default. | Nothing. Losing it is the cost of mistakes. |

Order of operations: armor reduces the hit, shield absorbs what is left, overflow goes to hull.

Starting values: Hull 100, Shield 50, Shield regen 5 per second, Armor 0.

There are no invulnerability frames after a hit. Being hit is normal here, and i-frames would make chaff meaningless.

### 4.3 Bullet taxonomy (Proposed)

Since the ship cannot dodge, bullet hell has to mean something other than "weave through gaps". Every enemy projectile belongs to one of four classes, each with a distinct shape and color, and each with a different answer in the build.

| Class | Look | Behavior | How the player answers it |
|---|---|---|---|
| **Chaff** | Small dots, cool color | Low damage, high volume, mostly unavoidable | Armor and shield regen |
| **Heavy** | Large, hot color, preceded by a charge ring or lane marker for at least 1.0 second | High damage, ignores armor | Time Aegis or another defensive ability. Or kill or stun the charging enemy to cancel the shot. |
| **Ordnance** | Outlined missiles and mines with visible hit points | Slow, homing or placed on the flight path, medium to high damage | Shoot it down. Flak Screen and EMP specialize in this. |
| **Hazard** | Lane lasers, asteroids, storm strikes | Environmental, telegraphed by lane | Ability timing. Some are destructible. |

The rule that makes offense a form of defense: **a charging Heavy attack is cancelled if its source dies or is stunned.** A damage-focused build therefore has a real answer to Heavy shots, not just a tank build.

## 5. Offense: autoshots

The player never aims, so each weapon's **targeting rule** is a core part of its design. Weapons level from 1 to 5. At level 5 the player picks one of two **Overclocks**, a capstone that changes how the weapon behaves.

Weapon slots: 3 at base, 4 with a Hangar upgrade.

| Weapon | Targeting | Role | Overclock A | Overclock B |
|---|---|---|---|---|
| Pulse Cannon | Fixed forward | Reliable baseline | Twin-Link: two parallel streams | Hot Rounds: bolts pierce 2 enemies |
| Scatter Array | Fixed forward cone | Swarm clear at short range | Wide Choke: more bolts, wider cone | Slug: tight burst with knockback |
| Seeker Pods | Nearest enemy, homing | Fire and forget, splash | Swarm: twice the missiles, half the splash | Warhead: one large missile, big splash |
| Lance Beam | Fixed forward, continuous | Single-target damage that ramps on one target | Prism: splits into 3 beams | Focus: double ramp, finishes non-boss enemies under 10% |
| Arc Coil | Nearest, chains to 3 more | Formation clear | Storm: 4 extra jumps | Overload: last target explodes |
| Flak Screen | Ordnance first, then nearest enemy | Point defense | Interceptor: also deletes chaff in a small radius | Shrapnel: destroyed ordnance explodes on enemies |
| Rail Driver | Highest max-HP enemy | Elite and boss killer, pierces | Capacitor: charges up while idle | Ricochet: bounces to a second target |
| Orbit Drones | Each drone shoots nearest | Sustained damage, drones body-block some chaff | Bulwark: drones project a chaff-blocking arc | Hunter: drones leave orbit to chase |

Launch target: 8 weapons. Four are available from the first run; four unlock through milestones.

## 6. Active abilities

Decided: cooldown buttons with no aiming. Each ability levels 1 to 5 through cards. The level-5 upgrade adds a new effect.

Ability slots: 2 at base, 3 with a Hangar upgrade. A ship starts with its signature ability and a complementary second ability; additional options come from cards. Start with two usable buttons so the core interaction is present in the first flight. In the first playable these are Aegis and Nova; the third slot remains a later Hangar purchase.

| Ability | Role | Level 1 effect | Base cooldown | Level 5 addition |
|---|---|---|---|---|
| Aegis | Defense | Bubble absorbs all damage for 2 seconds | 18 s | Blocked Heavy shots are reflected |
| Nova Pulse | Clear | Shockwave damages all enemies on screen and deletes chaff | 30 s | Also deletes ordnance and cancels charging attacks |
| Overdrive | Offense | +100% fire rate for 5 seconds | 25 s | Kills extend the duration |
| Chrono Field | Utility | Enemies and their projectiles move at 40% speed for 4 seconds | 35 s | Shield regen is tripled during the field |
| EMP Burst | Control | Stuns non-boss enemies for 2.5 seconds, cancels charging attacks, destroys ordnance | 28 s | Stunned enemies take +30% damage |
| Nanite Repair | Sustain | Restores 20% hull over 5 seconds | 60 s | Overheal becomes temporary shield |

Launch target: 6 abilities, 3 available from the first run.

Feedback requirements: every ability has a distinct ready chime, a cooldown ring on its button, and a light haptic on iPhone when it comes off cooldown. The player should be able to track cooldowns without looking at the buttons.

## 7. Systems (passive upgrades)

Systems are passive modules, level 1 to 5. Slots: 4 at base, 6 with Hangar upgrades.

| Group | Systems |
|---|---|
| Defense | Hull Plating (max hull), Shield Capacitor (max shield), Regenerator (shield regen), Reactive Armor (armor), Repair Bots (slow hull regen), Feedback Field (shield damage zaps the attacker) |
| Offense | Munitions (damage), Autoloader (fire rate), Targeting Computer (crit chance), Amplifier (area and duration) |
| Utility | Coolant Loop (ability cooldown), Data Harvester (XP gain) |

Launch target: 12 systems.

## 8. Level-ups and cards

### 8.1 XP

XP is granted on kill. Orbs fly to the ship automatically as a visual only. There is no pickup mechanic because the player cannot steer toward anything.

### 8.2 Card draft (Decided: pick 1 of 3)

- A level-up pauses the simulation and shows 3 cards (4 with the Hangar upgrade). Play resumes with a short slow-motion ramp so the player can re-read the screen.
- The pool contains new weapons, abilities, and systems (only when a slot is free) and upgrades to items already owned.
- Upgrades to owned items are weighted about twice as heavily as new items, so builds deepen rather than sprawl (Proposed).
- **Mercy slot**: if hull is below 40%, at least one card is defensive (Proposed).
- If the pool is empty, cards offer a hull repair or bonus Cores.

Card economy tools, all bought in the Hangar (Decided in principle, details Proposed):

| Tool | Effect |
|---|---|
| Extra card | Level-ups show 4 cards |
| Reroll | Redraw the current hand. Limited uses per run. |
| Banish | Remove a card from the pool for the rest of the run. Limited uses per run. |
| Skip | Take a small hull repair in place of any card |
| Hold | Keep one card to reappear at the next level-up |

### 8.3 Build capacity

At full slots there are 63 pickable levels (4 weapons, 3 abilities, 6 systems, 5 levels each, minus the original two starting items; the revised start includes a third item). The base-slot ship has 43 available picks before accounting for starting a second ability (42 with that change); the expanded ship has 62 with three starting items. Forty picks would nearly fill the base capacity. Target separate base and expanded budgets before implementing the full game. The first playable uses a smaller explicit 36-pick pool and approximately 14–20 draft choices; see FIRST_PLAYABLE.md.

### 8.4 Prototypes (Proposed)

After the bosses of levels 1, 2, and 3 the player picks 1 of 3 Prototypes. These change rules rather than add stats, and give each run an identity. Examples:

- **Capacitor Bank**: abilities hold two charges, cooldowns are 30% longer.
- **Volatile Shields**: when the shield breaks, it fires a free Nova Pulse (20 second lockout).
- **Kill Switch**: destroying an elite resets all ability cooldowns.
- **Glass Reactor**: +40% damage, 30% less max hull.
- **Point Defense Net**: every weapon can target ordnance.
- **Second Wind**: once per level, lethal damage leaves hull at 1 and triggers Aegis.

Launch target: 12 Prototypes.

## 9. Enemies

Because the player does not aim, enemy roles exist to stress different parts of a build.

| Enemy | Behavior | What it tests |
|---|---|---|
| Drone | Basic chaff shooter | Baseline damage |
| Swarmer | Rushes the ship, contact damage | Area damage |
| Gunship | Fires chaff fans | Armor |
| Spinner | Rotating spiral patterns | Shield regen |
| Missile Frigate | Launches homing ordnance | Point defense |
| Minelayer | Drops mines on the flight path | Point defense, flight path reading |
| Sniper | Charges a Heavy beam | Ability timing or burst damage |
| Shieldbearer | Shields its neighbors | Target priority, piercing |
| Splitter | Splits on death | Area damage |
| Cloaker | Untargetable until it fires | Reaction, area damage |
| Tender | Repairs other enemies | Target priority |
| Turret | Fixed to scrolling structures (level 4) | Sustained defense |

**Elites** are regular enemies with one affix (Armored, Volatile, Rapid, Shielded). This multiplies variety without new art.

Launch target: 12 enemy types, 4 elite affixes, 4 bosses.

## 10. Levels

Each level is a seeded sequence of about 9 wave segments of roughly 30 seconds, drawn from that level's segment pool, with an elite encounter at the midpoint and a boss at the end. Each segment has a **threat budget** (expected incoming damage per second) so difficulty is tuned by number, not by feel alone.

Each boss tests a different part of the build, so a one-dimensional build hits a wall somewhere.

| # | Level | Theme and new mechanic | Boss | Boss tests |
|---|---|---|---|---|
| 1 | Debris Belt | Destructible asteroids that drop XP. Drones, Swarmers, Gunships. | **Harvester**: mining rig that charges a telegraphed laser across the flight path | Ability timing. Teaches Aegis and cancel-by-kill. |
| 2 | Picket Line | Fleet formations. Introduces ordnance and Shieldbearers. | **Carrier**: launches fighter wings and missile salvos; hangar bays are weak points | Point defense and swarm clear |
| 3 | Ion Storm | Telegraphed lightning lanes that suppress shield regen for 3 seconds. Snipers, Cloakers, Spinners. | **Twin Tempest**: two linked ships; the survivor enrages | Target priority and shield management |
| 4 | Citadel | Fortress trench with wall Turrets and timed laser gates. All enemy types. | **Dreadnought Core**: shield generators, then a spiral chaff phase, then a doomsday charge that must be interrupted or absorbed | Everything, plus a damage race |

Between levels: Prototype pick, shield refilled, 30% of max hull repaired.

**After the first clear**: Threat tiers 1 to 10, each adding a modifier (more elites, faster chaff, shorter telegraphs down to the 1.0 second floor). This is where long-term players spend their Hangar power.

## 11. Fairness rules

These are constraints on all content, not suggestions.

1. Heavy attacks always telegraph for at least 1.0 second with both a visual and an audio cue.
2. Bullet classes are distinguishable by shape, not only by color.
3. The flight path preview is always visible.
4. No single unavoidable hit may deal more than 35% of base hull at the level it appears in.
5. The results screen shows damage by class and weapon plus the final ten seconds: damage sources, shield breaks, ability use, and cooldown availability at death.
6. Limit simultaneous heavy threats and budget burst windows as well as average damage. The first playable allows one heavy charge at a time, globally spaced by 8.5 seconds or more. Every prototype threat has a specified available counter.
7. Target-priority challenges must be answerable through documented weapon priorities or abilities. Seekers prioritize charging sources, then ordnance, then nearest enemies. Nova interrupts boss charges.

## 12. Meta-progression: the Hangar

Decided: permanent upgrades between runs, bought freely with points, including the card economy.

**Currency**: Cores. Earned from kills (small), levels cleared, bosses, and first-time milestones. Target: every run, even a bad one, affords at least one purchase early on (Proposed).

**Respec is free and unlimited** (Proposed). You said points are spent freely, and free respec encourages trying builds.

| Track | Upgrades |
|---|---|
| Hull Bay | Max hull, max shield, armor, between-level repair amount, 5th and 6th system slots |
| Armory | Damage, fire rate, 4th weapon slot, starting weapon begins at level 2 |
| Flight Deck | Ability cooldown, 3rd ability slot |
| Tactics | Extra card, rerolls, banishes, skip, hold |
| Salvage | XP gain, Core gain |

**Unlocks** come from milestones, not Cores: weapons, abilities, Prototypes, and ships are added to the pool for doing specific things (clear level 2, kill a boss without losing shield, and so on). This keeps the first-run pool small and readable.

**Power budget** (Proposed): level 4 at Threat 0 should be clearable with roughly one third of the Hangar filled. The rest of the Hangar is for Threat tiers. A roguelite where the first clear requires a full grind would be a mistake for a paid Steam game.

## 13. Monetization

### 13.1 iOS (Decided: ads, pay to remove)

| Placement | Type | Rule |
|---|---|---|
| After a run, between results and Hangar | Interstitial | Never in the first session. At most one per 5 minutes. Never during a run or a level-up. |
| On death, once per run | Rewarded, opt-in | **Emergency Reboot**: revive with 50% hull and a 3 second Aegis |
| On the results screen | Rewarded, opt-in | **Salvage Bonus**: +50% Cores for that run |

No banner ads during play. They would cover part of a playfield whose readability is a pillar.

**Remove Ads** is a single non-consumable purchase. It removes interstitials and grants both rewarded bonuses automatically without watching anything.

### 13.2 Parity rule (Proposed, important)

The paid Steam game and the iOS game with ads removed are **the same game**: one free revive per run and the Salvage Bonus built in. Balance is tuned against that version. A free iOS player can reach the same state by opting into rewarded ads but can never exceed it. Without this rule you end up balancing two different games.

### 13.3 Steam (Decided: paid, one-level demo)

- The demo contains level 1 including the Harvester, the starting content pool, and the first tier of each Hangar track.
- Demo progress carries into the full game.
- Achievements are disabled in the demo and granted retroactively on first launch of the full game.

### 13.4 Store rules that constrain the design (verified)

- Steam demos use a separate App ID linked to the full game, can optionally have their own store page, and their saves can be stored in the full game's cloud storage. Valve recommends disabling achievements in demos and granting them in the full game. [S11]
- Steam Direct charges $100.00 per product, recoupable after $1,000.00 in adjusted gross revenue. [S12]
- Apple guideline 3.1.1 requires a restore mechanism for restorable in-app purchases, so Remove Ads needs a Restore Purchases button. [S13]
- Apple guideline 2.5.18 requires interstitials to be clearly marked as ads with an easy close or skip button, and requires apps with ads to let users report inappropriate ads. [S13]
- Apple guideline 5.1.2 requires permission through App Tracking Transparency before tracking, and forbids requiring tracking in exchange for functionality or compensation. Rewarded ads must therefore still pay out when the user declines tracking. [S13]

Not researched: price points, ad network choice beyond plugin availability, and expected ad revenue.

## 14. Platforms and UX

### 14.1 Playfield

Gameplay happens in a fixed 9:16 logical playfield, identical on every device, so balance is the same everywhere (Proposed).

- **iPhone** (taller than 9:16): the extra height holds the HUD above (hull, shield, XP, level progress) and the ability bar below, inside thumb reach and the safe areas.
- **iPad, desktop, Steam Deck** (wider than 9:16): the playfield is a centered column. Side panels show what a build game wants visible: weapons and levels with live damage meters on the left, abilities with key hints, Prototypes, and boss info on the right.

### 14.2 Input

| Platform | Abilities | Cards |
|---|---|---|
| iOS | Tap buttons | Tap |
| Keyboard | 1, 2, 3 (rebindable) | Number keys or arrows and Enter |
| Mouse | Click buttons | Click |
| Controller, Steam Deck | Face buttons | D-pad and confirm |

### 14.3 Sessions

A 25 minute run is long for a phone. Save the exact run state every ten seconds and on pause or interruption, including the random generator, current card hand, pending choices, projectiles, and cooldowns. Resume that state without redrawing cards. The app auto-pauses on interruption.

### 14.4 Accessibility

Shape-coded bullets, screen shake and flash toggles, reduced glow mode, scalable text, full remapping on desktop, audio cues for every telegraph.

## 15. Art and audio

**Art (revised after first playtest).** Illustrated metallic ships and industrial enemies over a dark painted debris belt, with neon weapon, shield, and engine effects. Color is reserved for meaning: one hue family for the player, one for chaff, one for Heavy, one for ordnance. Backgrounds stay low-contrast so they never compete with bullets. Glow is a style choice that must degrade gracefully, because readability rule 2 requires shapes to carry the information.

**Audio (Proposed).** Synth-driven soundtrack that adds layers as threat rises. The sound design priority order is: Heavy telegraph, ability ready, shield break, low hull, then everything else. Weapon fire is constant, so it sits low in the mix.

## 16. Technology

### 16.1 Engine recommendation: Godot 4 (Proposed)

| Need | Godot 4 | Unity |
|---|---|---|
| iOS and desktop from one codebase | Yes. iOS export requires macOS with Xcode. [S1] | Yes (not separately verified here; Google's ads plugin targets Unity on iOS, [S10]) |
| Cost | MIT licensed. [S2] | Unity Personal is available up to $200,000 in revenue and funding; the Runtime Fee was cancelled on 2024-09-12. [S9] |
| Thousands of bullets | Docs recommend calling the servers directly for thousands of constantly processed instances, and MultiMesh for larger counts. They state GDScript should be fine for a few thousand objects. [S3] [S4] | Mature options exist. Not verified here. |
| Neon glow in 2D | Supported. Full control needs HDR 2D, available in the Forward+ and Mobile renderers, at a stated performance cost. [S5] | Not verified here. |
| iOS ads | Third-party plugin from Poing Studios: interstitial and rewarded, Godot 4.5 or higher, iOS 15.0 or higher. Not a Google product. [S7] | Google publishes its own Mobile Ads plugin for Unity on iOS and Android. [S10] |
| iOS in-app purchase | Plugin-based. The Godot 4.4 docs describe an `InAppStore` singleton with `purchase` and `restore_purchases`, sourced from the godot-ios-plugins repository, but that page is marked as possibly outdated, and the current stable (4.7) docs list only "Creating iOS plugins" under iOS. [S6] [S1] | Not verified here. |
| Steam | GodotSteam, a community wrapper, MIT licensed, for Windows, Linux, and Mac. [S8] | Community wrappers exist. Not verified here. |
| Language | GDScript. C# export to iOS is supported since 4.2 but documented as experimental, so avoid C#. [S1] | C# |

**Why Godot.** The game is 2D with simple shapes, the engine is free with no revenue thresholds, and Godot's own documentation describes the exact technique this game needs for bullets. Godot projects are also plain text files, which suits development with an AI coding assistant and review by diff. That last point is an inference about your workflow, not something you told me.

**Why this is a gated recommendation, not a final one.** Unity is clearly stronger in one area that matters to your business model: Google ships and maintains the ads plugin for Unity, while on Godot both ads and in-app purchase depend on third-party or loosely documented plugins. I could not confirm the current state of Godot's in-app purchase support for 4.7 from official docs. That is the largest technical risk in this document.

**Swift and SpriteKit** are ruled out by the Steam requirement. SpriteKit runs only on Apple platforms, so Steam would be limited to macOS or need a second codebase. This is from my own knowledge, not checked against a source in this pass.

### 16.2 Tech spike (Milestone 0, go or no-go on Godot)

All five must pass on real hardware. If 3 or 4 fail, switch to Unity before any game code is written.

1. 2,000 enemy bullets plus 500 player projectiles at 60 fps on the oldest iPhone to be supported (target is Proposed, device is an open question).
2. Glow at 60 fps on that device, with an acceptable reduced-glow fallback.
3. An interstitial and a rewarded ad displayed on device, with and without tracking consent.
4. A non-consumable purchase and a restore, in the App Store sandbox.
5. A Steam build with an achievement and a cloud save through GodotSteam.

### 16.3 Architecture notes (Proposed)

- **Deterministic simulation** on a fixed timestep with a seeded random generator. This enables checkpoint resume, daily seeded runs later, and reproducible bug reports.
- **Data-driven content**: weapons, enemies, cards, waves, and bosses are data files, not code.
- **Bullet manager**: bullets are pooled data in arrays, drawn in batches, with simple circle collision. No scene node per bullet.
- **Platform service layer**: Ads, Store, Achievements, Cloud Save, and Haptics sit behind one interface with iOS, Steam, and no-op implementations. Game code never calls a plugin directly, which also contains the cost of an engine or plugin change.
- **Balance harness**: because the ship is not steered and inputs are a few discrete buttons, a run can be simulated headlessly by a simple bot (never press, press on cooldown, press on telegraph). Run thousands of seeded simulations per build to tune threat budgets. This is a real advantage of the no-steering design and worth building early.

## 17. Launch scope

| Content | Count |
|---|---|
| Levels and bosses | 4 |
| Enemy types | 12, plus 4 elite affixes |
| Weapons | 8, each with 2 Overclocks |
| Abilities | 6 |
| Systems | 12 |
| Prototypes | 12 |
| Ships | 3 |
| Threat tiers | 10 |

Counts assume a solo or very small team. If that assumption is wrong in either direction, this table is the first thing to change.

## 18. Milestones

No dates, because team size and availability are unknown.

| # | Milestone | Exit criteria |
|---|---|---|
| 0 | Tech spike | Section 16.2 passes, or the engine changes |
| 1 | First playable | 1 ship, 2 weapons, 2 abilities from launch, 3 enemies, card draft, one boss, causal death recap, exact saves, early matched-seed balance harness and automated playable exports. Passes the human fun gate below. |
| 2 | Vertical slice | Level 1 complete with boss, final art direction, audio, Hangar skeleton. This is also the Steam demo content. |
| 3 | Content complete | All four levels, full launch scope |
| 4 | Platform and monetization | Ads, purchase, restore, Steam features, saves, controller support |
| 5 | Balance and beta | Balance harness tuned, external playtests on both platforms |
| 6 | Launch | |

**Fun gate for Milestone 1.** The whole premise is unproven until this passes. Testers who have never seen the game should:

- recognize and act on meaningful ability opportunities, with deliberate timing improving outcomes over immediate activation,
- be able to say why they died,
- start another run unprompted.

If they describe the game as "watching", the fix is more frequent and more consequential ability decisions, not adding steering.

## 19. Risks

| Risk | Why it matters | Mitigation |
|---|---|---|
| No-steering play feels passive | It is the core premise | Fun gate at Milestone 1 before any content is built |
| Unavoidable damage feels unfair | Players cannot dodge | Fairness rules in section 11, flight path preview, death recap |
| Godot plugin gaps for iOS ads and purchases | Blocks the iOS business model | Milestone 0 spike, platform service layer, Unity as fallback |
| Two balance targets (ad-supported and paid) | Doubles tuning work | Parity rule in section 13.2 |
| Portrait game on landscape monitors | Could look like a phone port on Steam | Side panels designed as real features, not letterboxing |
| Meta-progression becomes a grind wall | Hurts reviews of a paid game | Power budget in section 12, Threat tiers absorb excess power |
| Scope | 8 weapons with 16 Overclocks, 12 enemies, 4 bosses is a lot for one person | Milestone 2 doubles as the demo, so there is a shippable artifact early |

## 20. Open questions

1. **Team and timeline.** Who is building this and by when? Drives every count in section 17.
2. **Prices.** Steam price and Remove Ads price, and whether they should match. A large gap invites complaints from Steam buyers.
3. **Ship count at launch.** Three is assumed.
4. **Assist mode.** Should there be an option that auto-casts abilities at reduced effectiveness for players who want a near-idle game? It broadens the audience and undercuts pillar 1.
5. **Focus fire.** Should tapping an enemy mark it as a priority target? Adds agency against Shieldbearers and Tenders, but it is aiming by another name, which you chose against for abilities.
6. **Game speed toggle.** 1.5x speed is common in auto-play games. Not included.
7. **Cross-progression** between iOS and Steam. Assumed no.
8. **Minimum iPhone.** Sets the performance target. The ads plugin already implies iOS 15.0 or higher. [S7]
9. **Leaderboards and a daily seeded run.** Assumed post-launch.
10. **Story.** Assumed none beyond flavor text.
11. **Title.** StarRun is the repo name. No trademark or store-name check has been done.
12. **Competitive scan.** Not done. I have not checked what similar no-steering shooters already exist on either store.

## Sources

All retrieved 2026-11-12.

- [S1] Godot docs (stable, 4.7), Exporting for iOS: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html and iOS platform index: https://docs.godotengine.org/en/stable/tutorials/platform/ios/index.html
- [S2] Godot license: https://godotengine.org/license/
- [S3] Godot docs, Optimization using MultiMeshes: https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html
- [S4] Godot docs, Optimization using Servers: https://docs.godotengine.org/en/stable/tutorials/performance/using_servers.html
- [S5] Godot docs, Environment and post-processing: https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html
- [S6] Godot docs (4.4), Plugins for iOS: https://docs.godotengine.org/en/4.4/tutorials/platform/ios/plugins_for_ios.html
- [S7] Poing Studios, Godot AdMob Plugin docs: https://poingstudios.github.io/godot-admob-plugin/stable/
- [S8] Godot Asset Library, GodotSteam GDExtension listing: https://godotengine.org/asset-library/asset/1768 (this listing is for Godot 4.0 and marked deprecated; I could not load godotsteam.com to confirm the current release)
- [S9] Unity, pricing updates: https://unity.com/products/pricing-updates
- [S10] Google, AdMob Unity quick start: https://developers.google.com/admob/unity/quick-start
- [S11] Steamworks docs, Demos: https://partner.steamgames.com/doc/store/application/demos
- [S12] Steam Direct: https://partner.steamgames.com/steamdirect
- [S13] Apple, App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
