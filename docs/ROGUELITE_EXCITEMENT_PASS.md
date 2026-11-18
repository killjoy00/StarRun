# Incremental roguelike excitement pass — no new twitch requirements

Star/Run is a **build-first, incremental roguelike**. Your choices of ships, pilots, automatic weapons, fusions, upgrades, Prototypes, routes and one rare mutation shape how a run plays out. Using active abilities at just the right moment can help, but players can also watch their deliberately built ship perform and play casually at 3x.

## 1. Encounter pacing: let strong builds look strong

Ordinary Worlds 2–4 non-Daily arrivals now alternate between a **surge of existing spawn opportunities** and a **recovery stretch**. The six faster slots run at 80% of normal spacing, the next two at 90%, and the following eight at 117.5%. Those sixteen intervals sum to exactly sixteen old intervals. The result should feel more like **challenge → payoff → room to breathe**, without mandatory waiting or artificially empty screens.

- No new enemies, XP, Cores, enemy HP, damage, elite affixes, hazards or boss gates.
- The same crowd limit, formation queue and per-slot RNG govern enemies.
- No changes in World 1 (including the intended Hard/Insane **empty-Hangar no-clear** gate), fixed Daily, or secret Archive spawns.
- Stage rhythm progress is saved and restored exactly; the next stage resets its own pattern.
- Real campaign simulation may still diverge after any shifted attack or kill; the fixed per-cycle time budget is **not** a guarantee of identical rewards or clear outcomes. Match seeds and review actual XP/level/crowd distributions.

## 2. Mutation excitement — automatic weapons do the work

All eight existing mutations keep **their same combat stats and costs**. Each now produces a one-time visual installation event, and a capped distinctive visual highlight when its *actual* effect triggers:
- Pulse: Ghost Rounds penetration and Bank Shot secondary hits
- Seeker: Hydra Warheads splits and Siege Torpedoes' nearby splash
- Arc: Chain Reactor's kill chains and Static Lock's beam suppression
- Lance: Prism Echo refracted beam and Capacitor Lance's kill-based cooldown reduction

Highlights use weapon-family palettes/shapes, with reduced-effects alternatives and a real-time presentation hold so they remain readable at 3x. Effects are capped to one every 90 simulated ticks. No passive damage, attack rate, projectile count, ability button or purchase is added.

## 3. Boss spectacle, not artificial pacing

A destroyed boss component now gets an unmistakable, short **component down** cue. Genuine damage-driven World 3/4 phase transitions and the Custodian's actual phase changes generate a brief phase-break ring and label, plus a restrained existing audio/haptic accent. No extra lock time, cinematic pause, invulnerability, boss HP, Core or salvage reward is introduced.

The new cue layer is composited **under hostile shots and threat lanes**, and supports reduced effects.

## 4. Less upgrade copy, clearer choices

On ordinary upgrade cards, stop repeating future rank-5/rank-10 explanations. The cards still show:
- name and short effect description,
- relevant card type/current rank,
- a **Now:** line when the selected card actually crosses the next breakpoint,
- fusion completion and slot freed when relevant.

No extra card panels, paragraphs or combat-button tutorials. Build identity matters more than extra instructions.

## 5. Code-first validation

The new `tests/roguelite_excitement.gd` asserts exact sixteen-slot interval conservation, seed/RNG isolation, unchanged World 1 and Daily clocks, snapshot persistence, mutation-effect rate limits without XP or reward changes, actual targetable World 3/4 phase transitions, and the Custodian. The regular playable/visual suite now captures mutation and phase cues at 540x960 in both full and reduced effects.

The `roguelite-excitement.yml` workflow also runs observational **chill-play build comparisons** (no manual ability casts) for Vanguard, Arcwing, Haven using focused versus shielded natural draft policies, mid Hangar, Normal, three fixed seeds each, through World 2. It records per-seed progression and damage; scripted outcomes are **not human win rates**. This is an audit of whether build choices matter without active timing, not an equal-win-rate mandate.

## Remaining acceptance

Physical iPhone testing still decides whether the peaks/recovery feel compelling, visual effects survive real hardware and 3x speed, and cards are genuinely easier to scan. Keep issues #23/#49/#51 open. Do not change published Daily rules, activate ads/IAP, publish to App Store or issue TestFlight without a separate release action. Version remains 1.3.
