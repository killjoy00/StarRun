# Star/Run

**Star/Run** is a four-world tactical space auto-shooter for iPhone, Android, Web, Windows, Linux and macOS. **Version 1.4** adds difficulty targets, a longer Hangar, start-world select, a drone build, boss intros and a fairer Daily. The 1.3 release built on 1.1's clear red-beam interrupts and friendly Prism lance fix, plus 1.2's stronger bosses and expanded Hangar: selected slower ranged enemies in Worlds 2–4 now survive a little longer and fire their opening volley sooner, putting more readable enemy bullets on screen. The native Daily share sheet, local achievements and optional iPhone Game Center bridge are built, but Apple's first public review and actual on-device functionality still require verification. See [sharing and Game Center](docs/SHARING_GAME_CENTER.md), [Daily rules](docs/DAILY_ACHIEVEMENTS.md), [1.2 boss/Hangar review](docs/v12-boss-hangar-balance.md), and [1.3 screen-pressure tests](docs/shooter-hp-pressure-study.md).

StarRun is a no-steering, no-aiming roguelite autoshooter. The ship flies and fires automatically; the player chooses its build and *when* to use four equipped active abilities.

## Gameplay: four-world roguelite plus 0.9.0 progression and daily missions

- **Four active slots from 22 abilities.** Every ship starts with a signature ability. Each ability has a matching partner; upgrading both to rank 5 makes a stronger fused ability and frees a slot. Twelve fusions are available.
- **Normal, Hard, Insane.** Choose the difficulty before launch. Higher settings increase enemy health, damage and firing pressure, with respective core rewards of **1×, 1.75×, and 2.5×**.
- **Stage 1: Debris Belt.** Fly through changing scenery and enemy waves, then defeat the Harvester. A full Hangar can make this stage easy, by design.
- **Stage 2: Ion Storm.** A fully different cobalt lightning environment, new electrical silhouettes, ion shield suppression, corrosion, ability disruption and the Storm Carrier.
- **Stage 3: Solar Foundry.** Molten orange factory corridors, Forge Turrets, Slag Bombers, Ember Hunters and Splitters. Heat impairs automatic weapons; molten bombs are visible and shootable. The Crucible Engine is the boss.
- **Stage 4: Void Citadel.** Violet fortress architecture, blinking Phase Stalkers, Void Lancers, Gravity Sentinels and Echo Carriers. Gravity slows weapon fire; void shots partially bypass shields; the Void Regent fires twin telegraphed beams.
- **Tactical multi-part bosses.** Storm Carrier has targetable fighter-launch bays; Crucible Engine has cooling vents and alternating armored/exposed windows; Void Regent has shield pylons and a final onslaught. Autopilot weapons can prioritize these real weak points—no aiming or steering required.
- **Build bonuses.** Fortress, Glass Cannon, Control and Salvager remain meaningful, even if their source skills fuse. Eight weapon/system pairs grant additional passive effects, with no extra ability buttons.
- **Eight stronger Prototypes, optional.** Between stages, take one permanent, build-changing Prototype from three random, save-stable offers—or pass for **10 banked Cores**. Big effects include +55% weapon damage, -38% cooldowns, +60% shield capacity, +70% ability power, or an emergency shield-and-hull rebuild. Every Prototype still has a cost.
- **Choose your next route.** **Shielded passage** repairs 70% hull, restores full shields, cuts incoming damage by 35%, shortens active cooldowns by 15% and boosts automatic damage by 15% above half shields. **Redline assault** gives +35% automatic weapon damage and +20% fire rate, but repairs only 10%, starts at half shields and takes 20% more hull damage. **Hunter contract** raises enemy pressure 30% in exchange for +50% kill XP, an extra level-up and a boss-clear Core bounty. Routes last one world and survive checkpoints.
- **Boss victories are earned moments.** Defeating a boss freezes combat for oversized explosions and shockwaves. Tap **Warp to next stage**, pick a Prototype and route, then fly on (no free level-up between worlds; the Hunter contract route still adds one). After Stage 4, tap **Claim victory** for the full report.
- **Phone-first menus.** Title, Hangar, Ships & pilots, drafts, intermissions and results share one layout system: header on top, actions pinned to the bottom within thumb reach, and safe-area margins for the notch and home indicator. The whole card is the tap target; holding and dragging it scrolls when content overflows. Combat HUD and controls also respect the notch and home indicator. Permanent unlocks, Refund all and abandoning a saved flight take a second tap or a confirmation. The first flight launches straight into play; the first heavy beam teaches Aegis in context, and the How to play guide stays on the title screen.
- **Meaningful timing.** Aegis base cooldown is 14 seconds and Nova is 24 seconds. Chaff, heavy telegraphs, ordnance, mines and stage-specific suppression require different responses.
- **Real milestones at ranks 5 and 10.** All 47 base upgrade tracks and 12 fused tracks get breakpoint effects. Later picks add two ranks; crossing rank 5 or 10 triggers the effect immediately, even if the choice skipped that exact number.
- **Full-build rewards.** Once there are no eligible upgrades left, a level-up offers **Field repair (+30 hull)** or **5 banked Cores**. These fixed Core rewards pay out when the run ends and are not boosted by difficulty or other multipliers.
- **Ten more passives from world 2.** Siege rounds, Finisher rounds, First strike, Blast plating, Insulation, Shield reserve, Combat repairs, Last stand, Shield focus and Follow-through. Active, Passive and Auto weapon labels stay visible on every draft card. Consumed fusion components leave the pool; upgrade the combined ability directly.
- **Later worlds scale with growing builds.** Worlds 2–4 have substantially higher health, damage and firing pressure, stronger boss modules and longer boss fights. Aegis effects leave a vulnerability window between casts.
- **Seven ships and seven pilots.** Each ship has a distinct flight, weapon and signature-ability starting package. Pilots provide additional specialties. Vanguard and Vale are free; the Lancer and Kade are bought with Cores; the rest are earned in play (see below).
- **Uncrowded combat HUD.** Build/speed/pause controls have their own row above Hull/Shield meters; ability names, ready/cooldown captions and icons no longer occupy the same space or give slot one an artificial highlight.
- **Readable threats.** Enemy rounds and heavy-beam warnings use coral-red outlines above friendly effects. Red **CHARGING** rings identify emitters; destroying them produces a cyan **BEAM CANCELED** cue. A fractured shield ring and segmented shield bar make shield loss visible, including with reduced effects. Fusion and rank-5/10 picks get a thin accent border.
- **Persistent Hangar.** Forty refundable permanent upgrades enhance weapons, defense, ability power, draft tools and salvage. Rerolls give 1 per rank (up to 6) for the whole run. Equipment and selected difficulty are retained in saves.

Current active pool: Aegis, Nova, Barrage, Overdrive, Chrono, Repair Drones, Flak Screen, EMP Blackout, Deflector, Rail Strike, Prism Reversal, Chaff Barrier, Capacitor, Precision Focus, Decoy Beacon, Signal Jammer, Energy Siphon, Chain Overload, Reactor Reboot, Salvage Surge, Wing Drones, Ion Mine.

## Roguelike variations (candidate)

Regular flights now have three optional **Artifact** rule sets: Glass Fleet, Arsenal Shift, and Drone Armada. Daily challenges always use Standard. Later-world drafts offer rare one-per-run **weapon mutations**: Ghost Rounds (Pulse penetration), Hydra Warheads (Seeker splits), and Chain Reactor (Arc death chains). After boss defeats a black-market trade can replace a Prototype offer, sacrificing hull or shield capacity for one of these mutations. Engineer and Scavenger now also have additional distinctive combat mechanics.

See [roguelike variation implementation](docs/ROGUELIKE_VARIATION.md). Version remains **1.3**; this work is not signed for TestFlight or submitted to the App Store.

## Deliberate World 1 opener, eight mutations, and traveling Quartermaster

Normal World 1 now starts with a recognizable rhythm: scouts from 0–8s, warning at 8–12s, a coordinated three-ship strike wing at 12–18s, a recovery beat at 18–21s, then a counterattack to 30s. Hard/Insane and fixed-seed Daily opening schedules remain unchanged. CI compares actual, empty-Hangar 30-second fights against the previous source for all six ships and verifies natural World 1 outcomes.

Two rare transformations are available for each automatic weapon. Pulse: Ghost Rounds and Bank Shot. Seeker: Hydra Warheads and Siege Torpedoes. Arc: Chain Reactor and Static Lock. Lance: Prism Echo and Capacitor Lance. The existing one-mutation-per-flight and owned-weapon requirements are retained.

An illustrated Quartermaster freighter may hail in ordinary Worlds 2–3. Players can ignore the signal, or examine optional exotic mutations, shield-for-offense pacts, ability exchanges, and repair or salvage trades. Every sacrifice is shown again on a separate confirmation screen. Offers, transaction receipts, and merchant history survive checkpoints; Daily never uses the merchant.

More detail: [Opening, mutations and merchant](docs/OPENING_MUTATIONS_MERCHANT.md). Apple version remains 1.3; no signed TestFlight submission is included.

## Persistent rival captains

A real named enemy attack can create a **locally saved rival captain** when the ship is destroyed in an ordinary flight. After a different completed flight, the captain may return (seed-deterministic chance) as a recognizable attackable ship with a distinctive signature tactic. The game freezes briefly for a **RIVAL SIGHTED!** warning featuring an original seeded helmet portrait and large exclamation badge, and displays a second reveal when the captain is defeated.

Five signatures: Charged Barrage, Interceptor Screen, Reactive Shield, Hunter Lock and Mine Scatter. Defeating a rival awards exactly one **cosmetic dossier trophy**, saved in the title's **Rivals** journal along with encounter history. This is local-only, needs no account, does not introduce combat upgrades or change Daily. Version remains **1.3**; no signed TestFlight/App Store submission is included.

See [rival design and testing](docs/RIVAL_CAPTAINS.md).

## More on-screen action, same balance budget

- **Swarm packs (Normal, World 1).** World 1's light ships arrive as a pack of smaller ships: four drones, or three rushers or interceptors (also in Endless, which reuses World 1's ships). The scripted World 1 opener (scouts, strike wings, reinforcements) uses packs too. Every pack is real and shoots back, but carries exactly one ship's budget: one XP payout and one kill (only the lead rewards), one ship's escape damage, one shared volley timer that slows as members fall, and 108% of one ship's health split across members (offsetting the shots lost to overkill on small targets). Crowd limits, the opening director and the World 1 fire throttle count a pack as one ship, and only the lead draws combat RNG.
- **Background battle and wreckage.** A dim, distant skirmish plays behind the playfield, and kills throw tumbling hull fragments. Both are cosmetic and switch off with Calmer visuals.
- Packs run on Normal only. Chain lightning and other splash clear tight packs slightly faster, and Hard/Insane must keep their no-Hangar World 1 gate exactly; their simulation traces are byte-identical to before. Daily keeps its historical spawns.
- **Measured (scripted bot, Normal, no Hangar, same 16 seeds per ship, two runs of the final design):** real enemies on screen in World 1's opening rose from 1.4 → 3.8–4.1 (Vanguard), 1.8 → 4.2–4.5 (Kestrel) and 3.1 → 8.1–8.2 (Bulwark); mid-phase from 2.4 → 4.1–5.1, 1.3 → 2.9 and 5.4 → 10.8–11.8. World 1 clears were 31 of 48 before and 27 and 33 of 48 in the two runs (draft order swings single seeds both ways); kills stayed within 3% and reaching the World 1 boss without upgrades stays near-certain (14–16 of 16). The Arcwing Archive route (mid Hangar, 16 seeds) cleared 10 before and 8 after; that is within noise but leans slightly harder, so it is worth watching.
- **Ships fly in.** Scouts, strike wings, director wings, rival captains, bosses and the Archive courier start above the screen and ease down into position instead of appearing in place. Ships that are still flying in count toward the crowd limits.
- **Tried and rejected: tougher enemies.** More enemy health (with slower fire, so incoming damage per ship is unchanged) was measured three ways. A flat increase for every ship buried slow builds: at 1.5x Bulwark reached the World 1 boss 7 of 16 times instead of 16. Extra health only on near-empty screens (up to 1.6x, Normal World 1) made Vanguard's World 1 busier (3.4 → 6.5 enemies on screen, empty 23% → 6%) but barely helped Kestrel, cost Bulwark kills, and lost later-world wins on mid-Hangar campaigns (10 of 15 against 13 of 15 on the same seeds) plus the Arcwing Archive regression seed. Applying it in all four worlds was worse. None of it shipped.
- **More particles.** Engine exhaust on ordinary enemies, streaks on enemy bullets, more hit sparks and bigger explosions with smoke. All of it is cosmetic and off with Calmer visuals.
- **Layout guard.** `tests/layout_fuzz.gd` opens real upgrade drafts (40 seeds × 4 worlds), every single card, every Hangar tab and every loadout tab at 320, 375, 390 and 430 point widths, and fails if anything leaves the screen or a label is wider than its box. It runs in CI. It caught the mutation card label that pushed a draft off the side on 390-wide phones.
- **Plain text.** Cards, ships, pilots, Hangar upgrades, menus, warnings and achievements were rewritten in short, plain sentences, and the game says "run" instead of mixing "run" and "flight".
- **Limits.** Very strong builds (for example mid-Hangar Kestrel) still clear later-world waves almost as fast as they arrive; packs cannot fix that without adding XP or health. Worlds 2–4 packs were tried and held back: the Arcwing Archive route won 5 of 8 seeds with them against 7 of 8 without. Two rejected designs: larger packs on empty screens (every member needs a shot, so packs outlived the ship they replaced and Kestrel's World 1 clears fell from 8 to 2 of 16), and overkill that spills between packmates (packs died too fast and kills rose).

## Codex, earned ships, faster spawns and bigger level-ups

- **Codex.** A new title-screen page lists every upgrade, mutation, fusion, weapon evolution, passive pair, synergy and build engine (95 entries) in four tabs. Entries stay hidden ("???") until a run offers or activates them; finds are saved when the run ends.
- **Earned ships and pilots.** Kestrel (beat World 1), Bulwark (block 500 damage in one run), Wraith (Seeker pods rank 10 in one run), Arcwing (Arc coil rank 10 in one run), Haven (turn on SWARM), Patch (finish 5 runs), Vega (destroy 1,000 enemies in total), Orion (defeat a rival captain), Nyx (stop 5 beams in one run) and Scrap (finish the Daily on 3 days) unlock through play. Loadout shows each condition with progress, and the results screen announces new unlocks. Ships and pilots already owned stay owned, and past runs count.
- **Buy-only: Lancer and Kade.** The Lancer (beam frigate, 120 Cores) starts with Prism lance instead of Pulse; its lance hits 35% harder and fires 15% more often, and it starts with Prism reversal. Kade (daredevil, 90 Cores): below half hull, +25% gun damage and abilities recharge 20% faster. Neither is in the Daily rotation, so no day's ship or pilot changes. Kade's portrait is a vector placeholder.
- **Adaptive spawn pace.** Each world sends the same ships, XP and enemy health. When the field is nearly clear, the schedule runs up to 1.6x faster, so a player mowing through gets more ships and reaches the boss sooner. It never slows below real time. Worlds 2-4 open gently (0.6x rising to 1x over 35 s). World 1's scripted 30 s opener is unchanged.
- **Fewer, bigger level-ups.** A pick adds 3 ranks (0-3-6-10) instead of 2. A new ability starts at rank 1 (1-4-7-10) and is 25% stronger at rank 1. XP per level is 28 + 21 (was 25 + 9): World 1 has about 12 level-ups instead of 17. No free level-up between worlds.
- **Fixes.** The boss name and phase line draw above beam lanes (the Harvester's lane could cover "INTERRUPT"). No achievement popup over the results header; the results list new achievements. Back/Escape leaves the Codex and Achievements pages.

## Bosses, Dailies, ships and plainer screens

- **Boss intro.** When a world's boss arrives the game pauses for about 2.6 s (1.4 s with Calmer visuals): the screen dims, WARNING stripes grow in from both edges, and the boss name and a one-line description drop in. Tap, Space, Enter or Esc skips it; it does not replay on resume.
- **Daily Hangar.** Each Daily generates its own Hangar from the date: the same for everyone that day, different every day. A grade sets its size: Light (3-7% of a full Hangar's cost), Standard (9-16%), Heavy (22-40%) or Elite (50-80%); the original ranks are about 21% of the cost. Ranks are bought in a seeded random order with cheaper ranks more likely, so days lean different ways. Core-payout upgrades are left out. Owned upgrades never apply, so there is one leaderboard. The title shows the grade, for example "Heavy Hangar".
- **Daily: fair offers.** Daily upgrade offers come from their own random sequence (saved with the run), so kills, timing and ability use never change them: the same picks see the same offers. Before, only the first two hands matched between players.
- **Rerolls.** 1 per Hangar rank for the whole run, up to 6 ranks, cheaper (was 1 per rank refilled each world, 3 ranks). Tactics items are renamed Rerolls, Removes, Skips, Extra choice, Focused rerolls and Remove refill.
- **Wraith** Seekers reload faster (0.62 s, was 0.70). No-Hangar Normal World 1 clears (bot, 12 seeds): 4 to 8 of 12, against 5 to 10 for other ships. Mid Hangar campaign wins 4/8 to 6/8.
- **Bulwark** starts with Deflector instead of Aegis (two ships started with Aegis) and takes 30% less beam and missile damage (was 20%) and fires at the normal rate (was 10% slower). Mid Hangar campaign wins 4/8 (bot, 8 seeds; 2/8 without the fire rate change). Hard and Insane no-Hangar World 1 stay at zero clears.
- **Screens.** Run end: Cores first, stat tiles, bar charts for damage dealt and taken, a short build list. Between worlds: "World 1 of 4 cleared", "Pick a prototype", "Pick a route". Achievements: "Earned Nov 22, 2026". Rivals: one line of made-up backstory per captain (300 lines) instead of a tip. How to play no longer mentions the hidden signals.

## Start at a later world

After you clear a world on a difficulty, runs on that difficulty can start at the next world. The **Start at** picker on the title screen appears once World 1 is cleared; clears on a harder difficulty unlock the easier ones too. The Daily always starts at World 1.

- **Catch-up.** Each skipped world still gives what clearing it would: a Prototype pick, the warp, and its level-ups. The level-ups match what a mid-Hangar player has on arrival (bot: level 18 / 47 / 85 at the start of Worlds 2 / 3 / 4) and are drafted before the first wave. **Pick the rest for me** finishes them for you (guns first, then a free ability slot, then defense; the same order as the balance bot). You choose one route, into the world you start in.
- **Rewards.** Skipped worlds pay no Cores; worlds you play pay what they would in a full run. Only runs from World 1 count as beating all four worlds (Star Runner, Hard and Insane wins, Fleet Commander).
- **Measured** (bot, Normal, 4 seeds per ship). Deaths in the start world at mid Hangar: World 2 8%, World 3 12%, World 4 12%, against 17% / 15% / 15% for runs that reach those worlds from World 1. Later starts are slightly easier, most clearly at World 2; with 24 runs each that gap is near the noise. A World 2 start pays about 506 Cores at mid Hangar against 925 for a full run.
- **Experiments.** The difficulty experiment takes a `start_world` input; `balance_matrix --start-world=N` runs the same from the command line.

## Difficulty targets and a longer Hangar

The game is meant to be hard, and the Hangar is how you get through it. Targets for Normal, full four-world campaign:

| Hangar | Target |
|---|---|
| None | Never finishes the campaign |
| Mid (what a player owns at the midpoint of progression, about run 50: 32% of the full Hangar cost) | Wins 40–60% |
| Max | Wins most runs (70%+) |

- **Progression length.** Target: a full Hangar in about 100 runs, a first win around runs 25–35. There is no published industry figure for this; community and wiki numbers for Hades (about 35,000 Darkness to max the Mirror, 90–100 hours to complete) and Vampire Survivors (roughly 170,000–200,000 coins for all PowerUps) suggest similar games take something like 50–150 runs, and 25 felt short. `tools/progression_model.py` simulates a player from zero using the bot's measured Cores per run.
- **Cores per run.** 30 per run, plus 1 per 30 kills, plus 20 per world cleared (and 5 × clears²), times the Salvage rig bonus. A World 1 loss pays about 60 and a full win about 400, so early runs still move the Hangar forward and winning does not finish it in a few runs. Salvage's bonus Cores are capped per use (20 + 4 per rank); in dense later worlds one Salvage window was paying thousands.
- **Hangar prices.** Original ranks keep their price. Extended ranks (past each upgrade's old cap) cost 10x, about a win each; Second wind and the three weapon tunings cost 5x. A full Hangar costs 31,437 Cores.
- **Longer Hangar.** Eleven core upgrades have extra ranks (for example hull 7 → 15, damage 5 → 12). Ranks up to the old cap keep their old price; extended ranks cost more the higher they go. New options: Second wind (once per run, survive a killing blow with 25% hull) and Pulse, Coil and Lens tuning (+5% damage per rank for that gun). 
- **Harder Worlds 2–4, even steps.** Compared with the 1.3 release: World 2 has 1.8x spawns and 3x enemy health, World 3 2.2x spawns, 4.9x health and 3.1x enemy damage, World 4 2x spawns and 3x health. World 1 and boss health are unchanged. The shape was chosen so a mid-Hangar player dies about equally often in each later world (bot, 8 seeds per ship: World 2 19%, World 3 15%, World 4 12% of the runs that reach it; mid Hangar wins 60%, max 85%, no Hangar never); before, World 3 killed almost nobody and World 2 was a wall (46%). World 3 needed more enemy damage rather than health: 60% more health only crowded the screen. On Hard and Insane, ordinary enemies in Worlds 2–4 have 15% less health than Normal's values.
- **Ships.** Vanguard: 108 hull and 52 shield, and its veteran bonus after each world is +10% / +15% / +20% weapon and ability power (was 115 / 55 and +15% / +20% / +25%). Haven, the drone carrier: 125 hull (was 115), Seekers hit 30% harder (was 12%), drones are 25% stronger and Wing and Guard drones launch one extra drone.
- **Drone build.** Three drone abilities: Repair drones (heal), Wing drones (attack) and the new Guard drones (each drone shoots down one small bullet near the ship every 0.3 s; missiles, mines, slag and beams get through). Any two of them start the SWARM synergy: drones last 40% longer and drone abilities recharge 15% faster, guns do 10% less damage. Haven starts with Repair drones, so one more drone ability starts SWARM. Guard drones are left out of the Daily so a Daily seed draws the same hands on every version.
- **Measured** (bot, Normal, 8 seeds per ship, with the drone build): no Hangar 0/48, mid 28/48 (58%), max 43/48 (90%). Mid Hangar per ship: Kestrel 7/8, Arcwing 6/8, Bulwark, Vanguard and Wraith 4/8, Haven 3/8; max Hangar 7/8 for every ship except Kestrel (8/8). Haven is still the weakest ship at mid Hangar; across the last three runs it won 3, 4 and 3 of 8. Adding a card shuffles every ship's drafts, so single-ship swings of 1-2 wins are within noise.
- **Experiments.** `.github/workflows/difficulty-experiment.yml` runs all seven ships at none / half / max Hangar in parallel (about 10 minutes) with per-world spawn, health and damage multipliers and a difficulty input, and reports win rates against the targets plus density per world. Start it from the Actions tab (Run workflow).
- **CI gates.** A full-Hangar Arcwing must win the campaign and clear the Archive; no Hangar must never finish Normal (six ships × 2 seeds).

## Reliability and balance pass

- **Ships:** Kestrel now has 85 hull / 40 shield (was 70 / 30). Bulwark takes 20% less beam and missile damage and gets +20% automatic damage against bosses (was +12%). Vanguard gains *veteran systems* after each cleared world: +15% / +20% / +25% weapon and ability power and 10% / 15% / 20% status resistance. In scripted no-Hangar Normal World 1 runs on the same 8 seeds, Kestrel went from 2 to 4 clears and Bulwark from 1 to 4, against Vanguard's 5; the Hard/Insane no-Hangar World 1 gate still records zero clears for all six pilots.
- **Heat (World 3):** -15% automatic damage for 3.5 s per hit (was -25% for 5 s).
- **Fixes:** Reflector Wall now absorbs World 3–4 heat, gravity and void rounds. Aegis blocks corrosion ticks, and corrosion can trigger the Emergency Field. Arsenal Shift no longer rotates ranks away from a mutated weapon. Damage-over-time no longer fires a hit sound and vibration every frame.
- **Saves:** every save is verified before it replaces the old one, the previous good copy is kept as a backup, an interrupted Windows replace is recovered, and an unreadable profile is set aside rather than overwritten.
- **Platforms:** Game Center skips a failing item instead of stalling the queue and retries in the background; Remove Ads is revoked when Apple no longer lists the purchase.

## Controls

On iPhone, four compact on-screen buttons run left to right on one row. Fused abilities use just one button. On keyboard, use **1–4** (Space uses slot 1); **B** opens the build, **Tab** cycles play speed and **Esc/P** pauses. Controller **A / X / Y / B** activates slots 1–4; Start pauses; menus and drafts follow controller focus. Level-up choices use keys 1–4 or touch. On desktop, **F11** or **Alt+Enter** toggles fullscreen (also in Settings), and the window shrinks to fit smaller screens such as Steam Deck. On Android, **Back** pauses a flight or steps back a screen; only the title screen exits.

The playfield uses adaptive 390×844 logical canvas scaling on modern portrait iPhones. Phone UI text uses a 16-point minimum. Build and Results use pinned navigation, short summaries and word-wrapped detail. iOS readability and performance still need real-device validation.

## iPhone and TestFlight delivery

**Release version policy:** Keep the Apple marketing version at **1.4** for all subsequent TestFlight updates unless the owner expressly requests a new version (1.4 started with build 1034; the owner approved it). Increment only the build number for each new signed upload. The shared EZTrivia TestFlight workflow already sets `MARKETING_VERSION` from the release request and `CURRENT_PROJECT_VERSION` to a distinct incrementing CI build number. Do not edit `project.godot` or the iOS export's short version for routine balance updates. No App Store public submission, ad activation, or IAP offer is implied by a new build.

**Current version: 1.4** (TestFlight build 1034 onward) adds the difficulty targets, the longer Hangar and start-world select described above. **1.3** shipped the 1.1 beam/Prism fixes, the stronger 1.2 boss and Hangar progression, and the new selective ranged HP plus shorter first-shot delay in Worlds 2+. The [1.3 matched density study](docs/shooter-hp-pressure-study.md) found more visible later-wave enemy bullets in all four tested ship/difficulty cohorts, with 5/12 full-campaign clears before and after the change. Replay/save tests, responsive UI, 24-seed World 1 balance, genuine four-world Normal completion and an unsigned iPhone build all passed. These are automated bot checks, not human player win rates or proof of on-device enjoyment.

For initial App Store approval, Star/Run remains **free and ad-free**; it does not show Google sample/live ads or offer a Remove Ads purchase until AdMob approval and later on-device purchase testing. The actual signed TestFlight version/build should be checked using the [shared release workflow](https://github.com/killjoy00/EZTrivia/actions/workflows/starrun-testflight.yml) and Apple App Store Connect. Public App Store review and Game Center publication are separate steps.

StarRun's iPhone workflow compiles an unsigned app for CI. **Signed TestFlight distribution already exists in [EZTrivia's shared workflow](https://github.com/killjoy00/EZTrivia/blob/main/.github/workflows/starrun-testflight.yml)** using its existing Apple credentials. An immutable source SHA in [the release request](https://github.com/killjoy00/EZTrivia/blob/main/.github/starrun-release-request.json) triggers signing/upload. See [native delivery](docs/NATIVE_DELIVERY.md) for release verification and device checks.

## Building and running

Pinned to **Godot 4.6.3**, GDScript and the Compatibility renderer. GitHub Actions performs simulation and responsive UI checks, builds Web/Windows/Linux/macOS (macOS is ad-hoc signed for playtesting, not notarized), builds a CI-signed Android App Bundle, and compiles an unsigned native iPhone application. Steam integration (Steamworks achievements and cloud saves) is not built yet. Shared Apple signing credentials are in the companion TestFlight release workflow; no secrets are stored in this repo.

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/ui_smoke.gd
godot --headless --path . --script tests/run.gd
mkdir -p build/web build/windows build/linux
godot --headless --path . --export-release Web build/web/index.html
python3 tools/package-web.py build/web
godot --headless --path . --export-release Windows build/windows/StarRun.exe
godot --headless --path . --export-release Linux build/linux/StarRun.x86_64
```

Web requires WebGL2; Windows may show an unsigned application warning. Godot's 60 Hz simulation is independent of renderer and platform services, with deterministic seeds and exact checkpoint serialization.

## Files and remaining release gates

- [Hangar expansion, pilot portraits and two new actives](docs/HANGAR_EXPANSION.md)
- [Gameplay v0.8.1: rank-5 fusions and fusion artwork](docs/GAMEPLAY_V081.md)
- [Gameplay v0.8: world scaling, ten passives and iPhone input](docs/GAMEPLAY_V08.md)
- [Gameplay v0.7: fusions, milestones and mobile acceptance](docs/GAMEPLAY_V07.md)
- [Gameplay v0.6 and strategic UAT specification](docs/GAMEPLAY_V06.md) — boss phases, archetypes, Prototypes and routes
- [Historical v0.5 milestone](docs/GAMEPLAY_V05.md) — four stages, boss ceremonies, readable Build and Results
- [Historical v0.4 milestone](docs/GAMEPLAY_V04.md) — previous two-stage implementation
- [Original design document](docs/DESIGN.md) — longer-term vision, some proposed content not yet implemented
- [First playable v0.3 notes](docs/FIRST_PLAYABLE.md) — historical baseline, replaced by v0.4 for gameplay
- [Native delivery gates](docs/NATIVE_DELIVERY.md) — ad setup, real-device performance and Steam integration
- [App Store listing draft](docs/APP_STORE_LISTING.md) — title, subtitle, description, keywords, screenshots and owner steps
- `scripts/simulation.gd` — deterministic combat, threat director, active effects, stage transitions and checkpoint state
- `scripts/main.gd` — menus, responsive HUD, draft, Hangar and controller input
- `data/content.json` — enemies, abilities and upgrade cards
- `tests/run.gd`, `tests/ui_smoke.gd` — simulation and responsive UI regression checks

**v0.8.1 adds 16 Hangar tracks, six pilot portraits, two actives, rank-5 fusion requirements and distinct fusion insignia and effects to v0.8’s stronger late worlds, ten passives, safe combat headers and held-card scrolling. Real-device UAT remains required.** Passing simulation, responsive UI and iOS compile does not establish human enjoyment, actual iPhone frame-time stability, ads or in-app purchase support. Signed TestFlight release status is checked separately.
