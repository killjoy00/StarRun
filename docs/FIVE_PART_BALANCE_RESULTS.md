# Five-part audit: measured results

Completed November 23, 2026 (Central Time). Frozen production baseline: `cd749fd5c490b7cf64aa32cea391784dd2553683` (#81). Tested diagnostic head: `9e8c90ac02fff911e5585c39e8d680fda6df38a1`.

Evidence: [audit workflow run 45330947200](https://github.com/killjoy00/StarRun/actions/runs/45330947200), [validated report job 138244582696](https://github.com/killjoy00/StarRun/actions/runs/45330947200/job/138244582696), [playable build](https://github.com/killjoy00/StarRun/actions/runs/45330947353), [iPhone build](https://github.com/killjoy00/StarRun/actions/runs/45330947273). Smoke, all 27 research jobs, the validating report and the two active ordinary CI workflows succeeded. Six other specialized workflows were skipped, not counted as passes. The report validator checked 624 distinct matched attempts, exact seeds and catalog counts, no diagnostic faults, no duplicate settlements, and identical pre-decision traces for route/endgame cohorts. No timeouts were reported.

## Decisions and priorities

1. **Difficulty rewards (highest economy priority):** zero-Hangar Normal cleared W1 in 11/28 attempts; Hard and Insane each cleared 0/28, as intended. However, the unsuccessful Hard and Insane attempts earned 43.75 and 111.35 Cores per simulated minute versus 15.58 on Normal (2.81x and 7.15x). Insane p0 even beat max-Hangar Normal's 68.69/min. This is a strong signal to check deliberate early-death farming, including settlement, difficulty access, fixed base payout, bonuses and actual wall-clock overhead. At 32% Hangar, campaign clears were Normal 5/28, Hard 10/28, Insane 3/28; at 100% they were 21/28, 13/28, 2/28. Hard p32's advantage over Normal and Insane p100's slight regression versus p32 warrant larger matched cohorts across draft/route policies before altering difficulty combat. Do not lower Normal rewards or reopen #81's balance just to fix a potential perverse incentive.
2. **Route choices:** at 32% Hangar with focused drafting, Redline Assault (overclock) finished 13/28 versus Shielded Passage (repair) 5/28 and Hunter Contract (bounty) 6/28; 10 matched seeds favored Redline only and two favored Shielded only. Redline also cleared W2 25/28 versus 16/28, even with its defensive tradeoff. Hunter earned 97.82 Cores/min versus 61.06 repair and 60.37 Redline. Adaptive took Redline almost every time (68/70 post-W1 stages), with the same 13 wins. There are two clear niches (clear speed/survival through DPS vs currency); Shielded needs a low-hull/defense-specific counterfactual before tuning. Cross Hangar levels, ship/pilot, draft policies and actual pre-route hull/shield in a held-out seed set; aim for distinct valuable niches, not identical win rates. No blanket Redline nerf from this study.
3. **Build variety (continue #60):** engine-seeking drafts activated an engine in 26/28 attempts (92.9%) vs 21/28 with focused drafting (75%), and completed 11 campaigns vs five. Baseline completed 14/28, alternate evolution 7/28 and shielded 8/28. All 140 arrived at W2 and acquired at least one evolution. Fusion incidence was only 23/140 (16.4%), with 10/28 shielded runs forming Shieldstorm; five mutations acquired across 140 runs (3.6%). Five mutation IDs were offered 222 times combined without a pick; all offered market mutations were rejected. However the bot priorities favor gun ranks and the policies do not actively pursue most mutations or fuse/keep comparisons. Storm Circuit formed in 105/140 attempts, Salvage Carrier only 7/140; the latter was absent from three policies. Confirm with targeted natural-offer mutation, fusion-pair and each-engine policies (including keep vs fuse and a zero-cast sample). Record opportunity, acquisition, actual procs, opportunity cost, damage and outcome before improving access or power; do not infer weak effects from low bot pick rates. All draft picks in this audit were identified.
4. **Hangar:** total 31,437 Cores, 214 ranks, 44 tracks. The equal-budget spread portfolio spent 2,471, cleared W2 7/12 and W4 1/12; salvage spent 2,514, cleared W2 7/12 and W4 3/12, and finished at mean level 46.2 vs 35.5. Weapons/hull/abilities prioritized portfolios each won 0/12; hull cleared W2 0/12. Spread without tools cleared W2 3/12 versus 7/12 with tools, though its paid Cores/min was higher (63.41 vs 39.67). Tactics total only 334 Cores, while some late rank cliffs are 12–20x. Prioritize inexpensive XP/draft/economy synergies and evaluate marginal spending at multiple budgets; distinguish value for completion from currency farming. No across-the-board price reduction or per-track conclusion from this small portfolio study.
5. **Endgame:** 9/12 matched max-Hangar attempts reached W4 clear in every path; all nine recovered the needed signals and entered their chosen extension. Endless cleared W5, W6 and W7 in 9/9, added a mean 1,524.4 paid Cores over 9.4 simulated minutes per entrant and unlocked Beyond the Chart for all nine. Archive cleared 9/9, added no Cores over 1.8 simulated minutes and awarded its achievement for all nine. Neither path lost W4 Cores or victory credit in these successful attempts. The suspected Endless-death credit bug is **not reproduced by this cohort** because nobody died after entering Endless; production settlement condition remains a plausible defect. Add a focused production settlement regression for W4-clear-then-Endless-defeat, including full campaign victory and difficulty credit, duplicate settlement and no extra victory for a late start. Extend held-out real campaigns past W7 until defeat or an explicit higher cap, and compare Archive challenge at partial Hangar; judge Archive's unique discovery payoff separately from rewards. Do not increase either boss globally on nine max-Hangar wins.

**No production tuning is warranted in this diagnostic PR.** The next step is narrowly targeted counterfactuals, starting with difficulty reward incentives and the potential Endless settlement defect. All estimates are automated timed-cast policy outcomes, not human win rates. Four seeds per ship and 12-run economy/endgame cohorts are exploratory; simulated seconds exclude real menu/loading time. Fixed route and budget results are conditional on the tested policies. No merchant trades, rival history or actual human preferences were modeled. Preserve the normal progression, save/resume, Daily and iOS gates.

## Full validated Actions report

### Star/Run five-part balance audit
**624 real campaign attempts** across matched seeds and actual catalog prices. All traces validated. Automated timed pilot, Vale, standard artifact; no player data, ads, merchant transactions or rival history. A 900-second per-world diagnostic cap reports timeouts separately with zero paid Cores. Four seeds per ship/label are exploratory, not precise estimates of human behavior.

### 1. Build variety
| Cohort | Attempts | W1 clear | W2 clear | W3 clear | W4 clear | Timeout | Avg paid Cores/attempt | Cores/sim min |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| baseline | 28 | 28/28 (100.0%) | 24/28 (85.7%) | 19/24 (79.2%) | 14/19 (73.7%) | 0 | 1317.0 | 110.20 |
| focused | 28 | 28/28 (100.0%) | 16/28 (57.1%) | 7/16 (43.8%) | 5/7 (71.4%) | 0 | 488.4 | 61.06 |
| shielded | 28 | 28/28 (100.0%) | 16/28 (57.1%) | 12/16 (75.0%) | 8/12 (66.7%) | 0 | 396.6 | 41.48 |
| focused_alt | 28 | 28/28 (100.0%) | 20/28 (71.4%) | 10/20 (50.0%) | 7/10 (70.0%) | 0 | 459.7 | 51.34 |
| engine | 28 | 28/28 (100.0%) | 22/28 (78.6%) | 16/22 (72.7%) | 11/16 (68.8%) | 0 | 525.0 | 49.68 |

Matched W4 outcomes versus focused (same ship and seed; success = cleared W4, not claim status).
| Comparison | Both clear | Candidate only | Baseline only | Neither |
|---|---:|---:|---:|---:|
| baseline | 3 | 11 | 2 | 12 |
| shielded | 2 | 6 | 3 | 17 |
| focused_alt | 4 | 3 | 1 | 20 |
| engine | 4 | 7 | 1 | 16 |

Actual attained build mechanics, including late evolutions and engine procs. Conditioning on W2 arrival controls for whether a run had access to advanced mechanics, not survivor bias within that world.
| Policy | W2 arrivals | Any fusion | Any evolution | Any full engine (tier 2+) | Any mastery (tier 3) | Any actual engine proc | Mutation | Unidentified picks |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| baseline | 28 | 17.9% | 100.0% | 75.0% | 60.7% | 75.0% | 0.0% | 0 |
| focused | 28 | 7.1% | 100.0% | 78.6% | 32.1% | 75.0% | 3.6% | 0 |
| shielded | 28 | 35.7% | 100.0% | 67.9% | 46.4% | 67.9% | 0.0% | 0 |
| focused_alt | 28 | 7.1% | 100.0% | 82.1% | 53.6% | 82.1% | 7.1% | 0 |
| engine | 28 | 14.3% | 100.0% | 92.9% | 71.4% | 92.9% | 7.1% | 0 |

Per engine by build policy (formed / proc runs / mastery / W4 clears among formed).
| Policy | Engine | Formed | Proc | Mastery | W4 clear of formed |
|---|---|---:|---:|---:|---:|
| baseline | execution_network | 11/28 | 11 | 9 | 10/11 |
| baseline | fortress_reactor | 12/28 | 12 | 10 | 10/12 |
| baseline | missile_siege | 12/28 | 12 | 9 | 10/12 |
| baseline | prism_hunter | 11/28 | 10 | 10 | 10/11 |
| baseline | salvage_carrier | 3/28 | 3 | 3 | 2/3 |
| baseline | storm_circuit | 20/28 | 20 | 17 | 12/20 |
| focused | execution_network | 13/28 | 13 | 5 | 5/13 |
| focused | fortress_reactor | 5/28 | 5 | 4 | 3/5 |
| focused | missile_siege | 10/28 | 6 | 6 | 5/10 |
| focused | prism_hunter | 7/28 | 6 | 5 | 5/7 |
| focused | salvage_carrier | 0/28 | 0 | 0 | 0/0 |
| focused | storm_circuit | 21/28 | 21 | 9 | 5/21 |
| shielded | execution_network | 10/28 | 10 | 6 | 5/10 |
| shielded | fortress_reactor | 12/28 | 10 | 7 | 8/12 |
| shielded | missile_siege | 4/28 | 4 | 2 | 3/4 |
| shielded | prism_hunter | 5/28 | 4 | 2 | 3/5 |
| shielded | salvage_carrier | 0/28 | 0 | 0 | 0/0 |
| shielded | storm_circuit | 19/28 | 19 | 12 | 8/19 |
| focused_alt | execution_network | 15/28 | 15 | 8 | 7/15 |
| focused_alt | fortress_reactor | 6/28 | 6 | 4 | 4/6 |
| focused_alt | missile_siege | 16/28 | 12 | 8 | 7/16 |
| focused_alt | prism_hunter | 12/28 | 9 | 6 | 7/12 |
| focused_alt | salvage_carrier | 0/28 | 0 | 0 | 0/0 |
| focused_alt | storm_circuit | 20/28 | 20 | 14 | 7/20 |
| engine | execution_network | 22/28 | 22 | 14 | 11/22 |
| engine | fortress_reactor | 16/28 | 16 | 9 | 11/16 |
| engine | missile_siege | 22/28 | 19 | 15 | 11/22 |
| engine | prism_hunter | 21/28 | 14 | 11 | 11/21 |
| engine | salvage_carrier | 4/28 | 4 | 3 | 3/4 |
| engine | storm_circuit | 25/28 | 25 | 18 | 11/25 |

Fusion, evolution, mutation and Prototype usage (raw run counts are observational; do not infer causal power from winning builds).
- baseline Fusions: scrap_converter 2, railstorm 1, shieldstorm 1, missile_grid 1
- baseline Evolutions: breacher 27, duelist 26, executioner 25, conductor 20, tempest 4
- baseline Mutations: none
- baseline prototype picks/offers: echo_coil 9/30, mirror_cell 14/26, emergency_safeguard 9/26, breach_optics 7/25, salvage_charter 11/24, volatile_core 7/23, null_harmonics 7/20, bastion_lattice 7/19, market:capacitor_lance 0/6, market:refracting_lance 0/4, market:piercing_pulse 0/3, market:arc_reactor 0/3, market:grounding_arc 0/2, market:ricochet_pulse 0/1, market:split_seeker 0/1
- focused Fusions: railstorm 1, prism_focus 1
- focused Evolutions: duelist 26, breacher 26, conductor 18, executioner 17, tempest 4
- focused Mutations: piercing_pulse 1
- focused prototype picks/offers: breach_optics 7/25, bastion_lattice 0/22, echo_coil 11/18, emergency_safeguard 8/16, mirror_cell 12/16, null_harmonics 1/14, volatile_core 12/12, salvage_charter 0/9, market:capacitor_lance 0/6, market:ricochet_pulse 0/5, market:piercing_pulse 0/2, market:refracting_lance 0/2, market:split_seeker 0/2, market:grounding_arc 0/2, market:breach_seeker 0/1, market:arc_reactor 0/1
- shielded Fusions: shieldstorm 10
- shielded Evolutions: executioner 25, breacher 24, duelist 23, conductor 17, tempest 3
- shielded Mutations: none
- shielded prototype picks/offers: salvage_charter 0/22, volatile_core 0/20, emergency_safeguard 13/19, echo_coil 3/19, null_harmonics 10/19, breach_optics 2/18, mirror_cell 17/17, bastion_lattice 11/15, market:refracting_lance 0/6, market:piercing_pulse 0/3, market:split_seeker 0/3, market:arc_reactor 0/2, market:capacitor_lance 0/2, market:grounding_arc 0/1, market:ricochet_pulse 0/1, market:breach_seeker 0/1
- focused_alt Fusions: railstorm 1, prism_focus 1
- focused_alt Evolutions: interceptor 27, spotter 23, lifeline 19, tempest 16, conductor 4
- focused_alt Mutations: grounding_arc 1, ricochet_pulse 1
- focused_alt prototype picks/offers: emergency_safeguard 12/22, breach_optics 3/21, bastion_lattice 2/21, null_harmonics 1/20, mirror_cell 15/19, salvage_charter 0/19, volatile_core 17/17, echo_coil 8/17, market:refracting_lance 0/4, market:ricochet_pulse 0/4, market:piercing_pulse 0/3, market:breach_seeker 0/2, market:capacitor_lance 0/2, market:grounding_arc 0/2, market:split_seeker 0/1
- engine Fusions: prism_focus 2, missile_grid 1, nova_aegis 1
- engine Evolutions: breacher 27, duelist 25, executioner 21, conductor 21, tempest 4
- engine Mutations: piercing_pulse 1, grounding_arc 1
- engine prototype picks/offers: echo_coil 10/26, bastion_lattice 3/26, breach_optics 4/25, null_harmonics 0/24, mirror_cell 19/20, emergency_safeguard 13/19, volatile_core 17/17, salvage_charter 0/16, market:capacitor_lance 0/5, market:grounding_arc 0/5, market:ricochet_pulse 0/4, market:refracting_lance 0/3, market:piercing_pulse 0/2, market:split_seeker 0/2, market:breach_seeker 0/2, market:arc_reactor 0/2

Draft opportunity audit (aggregate natural offers and selected cards across policies, not a player popularity measure).
| Card | Picks | Offers | Pick/offer |
|---|---:|---:|---:|
| split_seeker | 0 | 50 | 0.0% |
| capacitor_lance | 0 | 50 | 0.0% |
| refracting_lance | 0 | 46 | 0.0% |
| arc_reactor | 0 | 44 | 0.0% |
| breach_seeker | 0 | 32 | 0.0% |
| ion_mine | 3 | 300 | 1.0% |
| strike | 9 | 459 | 2.0% |
| ricochet_pulse | 1 | 45 | 2.2% |
| decoy | 7 | 243 | 2.9% |
| chrono | 10 | 310 | 3.2% |
| prism | 14 | 407 | 3.4% |
| reboot | 11 | 317 | 3.5% |
| barrier | 16 | 442 | 3.6% |
| guard_drones | 13 | 331 | 3.9% |
| grounding_arc | 2 | 47 | 4.3% |
| piercing_pulse | 2 | 43 | 4.7% |
| overload | 18 | 348 | 5.2% |
| emp | 28 | 335 | 8.4% |
| salvage | 26 | 305 | 8.5% |
| last_stand | 73 | 780 | 9.4% |
| barrage | 36 | 380 | 9.5% |
| field_medic | 70 | 720 | 9.7% |
| focus | 47 | 468 | 10.0% |
| jammer | 58 | 571 | 10.2% |
| wing_drones | 42 | 410 | 10.2% |
| siphon | 45 | 390 | 11.5% |
| mend | 51 | 378 | 13.5% |
| capacitor | 65 | 459 | 14.2% |
| deflector | 80 | 460 | 17.4% |
| flak | 99 | 563 | 17.6% |
| shield_focus | 145 | 820 | 17.7% |
| nova | 119 | 626 | 19.0% |
| harvester | 126 | 639 | 19.7% |
| opening_salvo | 152 | 720 | 21.1% |
| overdrive | 87 | 399 | 21.8% |
| targeting | 185 | 847 | 21.8% |
| afterburn | 132 | 576 | 22.9% |
| insulation | 143 | 622 | 23.0% |
| shield_surge | 137 | 587 | 23.3% |
| nova_aegis | 2 | 8 | 25.0% |
| ablative | 141 | 550 | 25.6% |
| aegis | 144 | 513 | 28.1% |
| amplifier | 198 | 667 | 29.7% |
| coolant | 189 | 628 | 30.1% |
| shieldstorm | 13 | 40 | 32.5% |
| finisher | 221 | 652 | 33.9% |
| armor | 216 | 601 | 35.9% |
| boss_hunter | 215 | 598 | 36.0% |
| repair_bots | 232 | 595 | 39.0% |
| shield | 257 | 653 | 39.4% |
| hull | 265 | 617 | 42.9% |
| railstorm | 7 | 15 | 46.7% |
| regen | 277 | 590 | 46.9% |
| lance | 309 | 569 | 54.3% |
| autoloader | 279 | 497 | 56.1% |
| munitions | 263 | 455 | 57.8% |
| repair | 90 | 136 | 66.2% |
| prism_focus | 6 | 9 | 66.7% |
| arc | 308 | 436 | 70.6% |
| missile_grid | 3 | 4 | 75.0% |
| pulse | 307 | 402 | 76.4% |
| core_cache | 43 | 54 | 79.6% |
| seeker | 343 | 399 | 86.0% |
| scrap_converter | 5 | 5 | 100.0% |

All fusion choices accept the offered fusion; baseline and focused use the original default evolution policy, focused_alt takes the opposite option. Engine policy prioritizes existing natural ingredients. Manual draft preferences and merchant/rival paths are not modeled.

### 2. Route balance
| Cohort | Attempts | W1 clear | W2 clear | W3 clear | W4 clear | Timeout | Avg paid Cores/attempt | Cores/sim min |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| repair | 28 | 28/28 (100.0%) | 16/28 (57.1%) | 7/16 (43.8%) | 5/7 (71.4%) | 0 | 488.4 | 61.06 |
| overclock | 28 | 28/28 (100.0%) | 25/28 (89.3%) | 17/25 (68.0%) | 13/17 (76.5%) | 0 | 624.6 | 60.37 |
| bounty | 28 | 28/28 (100.0%) | 14/28 (50.0%) | 6/14 (42.9%) | 6/6 (100.0%) | 0 | 700.6 | 97.82 |
| adaptive | 28 | 28/28 (100.0%) | 25/28 (89.3%) | 17/25 (68.0%) | 13/17 (76.5%) | 0 | 624.6 | 60.35 |

Matched W4 outcomes versus repair (same ship and seed; success = cleared W4, not claim status).
| Comparison | Both clear | Candidate only | Baseline only | Neither |
|---|---:|---:|---:|---:|
| overclock | 3 | 10 | 2 | 13 |
| bounty | 3 | 3 | 2 | 20 |
| adaptive | 3 | 10 | 2 | 13 |

Route-specific next-world outcomes (actual chosen routes; adaptive is not a randomized causal comparison).
| Policy | Actual route | World arrivals | Clears | Avg ending hull % | Mean level |
|---|---|---:|---:|---:|---:|
| repair | repair | 51 | 28 (54.9%) | 54.6% | 39.2 |
| overclock | overclock | 70 | 55 (78.6%) | 77.2% | 47.9 |
| bounty | bounty | 48 | 26 (54.2%) | 53.5% | 53.0 |
| adaptive | repair | 2 | 0 (0.0%) | 0.0% | 33.5 |
| adaptive | overclock | 68 | 55 (80.9%) | 79.5% | 48.4 |

### 3. Hard and Insane progression
| Cohort | Attempts | W1 clear | W2 clear | W3 clear | W4 clear | Timeout | Avg paid Cores/attempt | Cores/sim min |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| normal-p0 | 28 | 11/28 (39.3%) | 0/11 (0.0%) | — | — | 0 | 59.4 | 15.58 |
| normal-p32 | 28 | 28/28 (100.0%) | 16/28 (57.1%) | 7/16 (43.8%) | 5/7 (71.4%) | 0 | 488.4 | 61.06 |
| normal-p100 | 28 | 28/28 (100.0%) | 28/28 (100.0%) | 23/28 (82.1%) | 21/23 (91.3%) | 0 | 811.1 | 68.69 |
| hard-p0 | 28 | 0/28 (0.0%) | — | — | — | 0 | 77.0 | 43.75 |
| hard-p32 | 28 | 27/28 (96.4%) | 17/27 (63.0%) | 16/17 (94.1%) | 10/16 (62.5%) | 0 | 856.9 | 89.97 |
| hard-p100 | 28 | 28/28 (100.0%) | 19/28 (67.9%) | 14/19 (73.7%) | 13/14 (92.9%) | 0 | 1344.2 | 139.86 |
| insane-p0 | 28 | 0/28 (0.0%) | — | — | — | 0 | 103.4 | 111.35 |
| insane-p32 | 28 | 20/28 (71.4%) | 6/20 (30.0%) | 3/6 (50.0%) | 3/3 (100.0%) | 0 | 675.6 | 120.82 |
| insane-p100 | 28 | 24/28 (85.7%) | 7/24 (29.2%) | 2/7 (28.6%) | 2/2 (100.0%) | 0 | 685.9 | 120.21 |

Rewards are compared by actual paid Cores / total simulated time including unsuccessful and timed-out attempts; no automatic difficulty recommendation based on reward multiplier alone.
| Ship | Normal p32 | Hard p32 | Insane p32 | Normal max | Hard max | Insane max |
|---|---:|---:|---:|---:|---:|---:|
| arcwing | 0/4; 38.1/min | 2/4; 93.4/min | 1/4; 122.5/min | 3/4; 77.4/min | 2/4; 96.1/min | 0/4; 88.9/min |
| bulwark | 0/4; 38.8/min | 0/4; 95.1/min | 1/4; 126.2/min | 3/4; 56.3/min | 3/4; 359.2/min | 0/4; 173.1/min |
| haven | 1/4; 121.3/min | 0/4; 63.8/min | 0/4; 136.8/min | 2/4; 50.1/min | 2/4; 90.9/min | 1/4; 109.9/min |
| kestrel | 1/4; 52.1/min | 2/4; 99.9/min | 0/4; 141.4/min | 4/4; 61.2/min | 2/4; 98.5/min | 0/4; 107.0/min |
| lancer | 1/4; 84.7/min | 3/4; 99.0/min | 0/4; 91.4/min | 3/4; 58.4/min | 2/4; 101.0/min | 0/4; 104.8/min |
| vanguard | 1/4; 43.2/min | 1/4; 80.4/min | 1/4; 115.3/min | 3/4; 92.8/min | 2/4; 99.7/min | 0/4; 102.7/min |
| wraith | 1/4; 48.7/min | 2/4; 90.9/min | 0/4; 115.0/min | 3/4; 82.3/min | 0/4; 65.0/min | 1/4; 144.6/min |

### 4. Hangar value
| Cohort | Attempts | W1 clear | W2 clear | W3 clear | W4 clear | Timeout | Avg paid Cores/attempt | Cores/sim min |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| spread | 12 | 12/12 (100.0%) | 7/12 (58.3%) | 4/7 (57.1%) | 1/4 (25.0%) | 0 | 329.9 | 39.67 |
| weapons | 12 | 12/12 (100.0%) | 1/12 (8.3%) | 0/1 (0.0%) | — | 0 | 129.3 | 27.20 |
| hull | 12 | 12/12 (100.0%) | 0/12 (0.0%) | — | — | 0 | 106.4 | 21.95 |
| abilities | 12 | 12/12 (100.0%) | 2/12 (16.7%) | 0/2 (0.0%) | — | 0 | 121.1 | 22.11 |
| salvage | 12 | 12/12 (100.0%) | 7/12 (58.3%) | 6/7 (85.7%) | 3/6 (50.0%) | 0 | 415.6 | 45.67 |
| tools | 12 | 12/12 (100.0%) | 7/12 (58.3%) | 3/7 (42.9%) | 1/3 (33.3%) | 0 | 318.0 | 40.51 |
| spread-no-tools | 12 | 12/12 (100.0%) | 3/12 (25.0%) | 2/3 (66.7%) | 1/2 (50.0%) | 0 | 399.8 | 63.41 |

Matched W4 outcomes versus spread (same ship and seed; success = cleared W4, not claim status).
| Comparison | Both clear | Candidate only | Baseline only | Neither |
|---|---:|---:|---:|---:|
| weapons | 0 | 0 | 1 | 11 |
| hull | 0 | 0 | 1 | 11 |
| abilities | 0 | 0 | 1 | 11 |
| salvage | 1 | 2 | 0 | 9 |
| tools | 0 | 1 | 1 | 10 |
| spread-no-tools | 0 | 1 | 1 | 10 |

Equal spending ceiling, discrete actual prices, common 1% starting foundation for targeted profiles. These are portfolio comparisons, not individual-rank causal estimates. Spread-no-tools tests the cost of ignoring actual finite draft actions.
| Portfolio | Actual spend (range) | W4 clears | Rerolls / banishes / skips | Average final level |
|---|---:|---:|---|---:|
| spread | 2471–2471 | 1/12 | 67 / 18 / 0 | 35.5 |
| weapons | 2513–2513 | 0/12 | 36 / 7 / 0 | 16.7 |
| hull | 2505–2505 | 0/12 | 24 / 5 / 0 | 12.1 |
| abilities | 2512–2512 | 0/12 | 24 / 5 / 1 | 14.9 |
| salvage | 2514–2514 | 3/12 | 66 / 18 / 0 | 46.2 |
| tools | 2473–2473 | 1/12 | 70 / 20 / 0 | 34.2 |
| spread-no-tools | 2471–2471 | 1/12 | 0 / 0 / 0 | 27.7 |

Production catalog: 44 tracks, 214 ranks, **31,437 Cores** total. Price cliffs quantify cost, not usefulness.
| Track | Group | First rank | Last rank | Total | Biggest adjacent price ratio |
|---|---|---:|---:|---:|---:|
| Shield capacitor | Hull | 7 | 823 | 4565 | 13.3× |
| Siege targeting | Weapons | 19 | 1164 | 3972 | 12.4× |
| Flux amplifier | Abilities | 10 | 747 | 2812 | 13.7× |
| Munitions lab | Weapons | 7 | 596 | 2611 | 20.0× |
| Feed accelerator | Weapons | 10 | 697 | 2547 | 14.6× |
| Hull plating | Hull | 7 | 469 | 2385 | 16.4× |
| Reactor cooling | Abilities | 10 | 684 | 2243 | 13.1× |
| Maintenance bots | Hull | 11 | 621 | 1944 | 14.4× |
| Second wind | Hull | 285 | 665 | 1426 | 1.7× |
| Data harvester | Salvage | 8 | 405 | 1056 | 13.4× |
| Pulse tuning | Weapons | 90 | 241 | 826 | 1.4× |
| Coil tuning | Weapons | 90 | 241 | 826 | 1.4× |
| Lens tuning | Weapons | 90 | 241 | 826 | 1.4× |
| Shield lab | Hull | 7 | 267 | 805 | 16.4× |
| Ceramic mesh | Hull | 8 | 355 | 658 | 15.9× |
| Sealed systems | Hull | 19 | 38 | 113 | 1.3× |
| Ablative panels | Hull | 16 | 36 | 103 | 1.4× |
| Restart circuit | Hull | 16 | 36 | 103 | 1.4× |
| Warhead tooling | Weapons | 16 | 36 | 103 | 1.4× |
| Field patch kit | Abilities | 24 | 44 | 101 | 1.4× |
| Hot start | Abilities | 24 | 44 | 101 | 1.4× |
| Component salvage | Salvage | 24 | 44 | 101 | 1.4× |
| Clean contract | Salvage | 24 | 44 | 101 | 1.4× |
| Breach sensors | Weapons | 24 | 44 | 101 | 1.4× |
| Point defense | Hull | 21 | 39 | 90 | 1.4× |
| Docking crew | Hull | 19 | 37 | 84 | 1.5× |
| Rerolls | Tactics | 7 | 20 | 82 | 1.4× |
| Salvage rig | Salvage | 8 | 19 | 68 | 1.4× |
| Remove refill | Tactics | 26 | 41 | 67 | 1.6× |
| Cast capacitor | Abilities | 14 | 24 | 57 | 1.4× |
| Pilot drills | Abilities | 21 | 33 | 54 | 1.6× |
| Lance mount | Weapons | 51 | 51 | 51 | 1.0× |
| Guidance array | Weapons | 8 | 16 | 49 | 1.4× |
| Harvester bounty | Salvage | 11 | 21 | 48 | 1.5× |
| Repair stores | Tactics | 11 | 21 | 48 | 1.5× |
| Charged coil | Weapons | 46 | 46 | 46 | 1.0× |
| Focused rerolls | Tactics | 46 | 46 | 46 | 1.0× |
| Recovery contract | Salvage | 11 | 19 | 45 | 1.4× |
| Emergency field | Abilities | 16 | 26 | 42 | 1.6× |
| Removes | Tactics | 10 | 17 | 41 | 1.4× |
| Skips | Tactics | 7 | 13 | 30 | 1.4× |
| Pulse precharge | Weapons | 20 | 20 | 20 | 1.0× |
| Loaded pods | Weapons | 20 | 20 | 20 | 1.0× |
| Extra choice | Tactics | 20 | 20 | 20 | 1.0× |

Check weak portfolio results against usage and intended specialization; expensive ranks or unused tools are candidates for further isolated tests, not automatic nerfs.

### 5. Endgame
| Cohort | Attempts | W1 clear | W2 clear | W3 clear | W4 clear | Timeout | Avg paid Cores/attempt | Cores/sim min |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| finish | 12 | 12/12 (100.0%) | 12/12 (100.0%) | 11/12 (91.7%) | 9/11 (81.8%) | 0 | 766.9 | 59.51 |
| endless | 12 | 12/12 (100.0%) | 12/12 (100.0%) | 11/12 (91.7%) | 9/11 (81.8%) | 0 | 1910.2 | 95.71 |
| archive | 12 | 12/12 (100.0%) | 12/12 (100.0%) | 11/12 (91.7%) | 9/11 (81.8%) | 0 | 766.9 | 53.77 |

Only three selected ships at maximum Hangar. Same signal pursuit, seed, build and route before W4; Archive may legitimately be inaccessible if two signals were not recovered. Endless continues through at most W7; no fabricated completion.
| Path | W4 clears | Eligible Archive | Entered extension | W5 clear | W6 clear | W7 clear | Mean extra paid Cores vs W4 claim (settled entrants) | Mean extension min |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| finish | 9 | 9 | 0 | — | — | — | 0.0 | 0.0 |
| endless | 9 | 9 | 9 | 9/9 (100.0%) | 9/9 (100.0%) | 9/9 (100.0%) | 1524.4 | 9.4 |
| archive | 9 | 9 | 9 | 9/9 (100.0%) | — | — | 0.0 | 1.8 |

Settlement integrity and incentives after a legitimate World 4 victory.
| Path | Settled entrants | W4 clears with no recorded victory | Archive achievement | Beyond the Chart | Lost saved W4 Cores |
|---|---:|---:|---:|---:|---:|
| finish | 9 | 0 | 0 | 0 | 0 |
| endless | 9 | 0 | 0 | 9 | 0 |
| archive | 9 | 0 | 9 | 0 | 0 |

Archive has a locked-in payout by design; compare its discovery/achievement payoff separately from Endless' rising Core payout. Timeout is not a defeat or a paid run.

### Decision rule
Do not rebalance from raw popularity or a single four-seed ship cell. Prioritize matched outcome differences, mechanical evidence, and reproducible defects; follow each proposed product change with a scoped counterfactual and the existing Normal balance/progression gates.
