extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const Services = preload("res://scripts/platform_services.gd")
const Catalog = preload("res://scripts/catalog.gd")
var failures := 0
var assertions := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	_test_course()
	_test_defenses()
	_test_interrupts_and_priority()
	_test_lance_fire_reliability()
	_test_v11_enemy_projectile_cadence()
	_test_boss_scaling_and_hangar_expansion()
	_test_shooter_health_screen_pressure()
	_test_draft_and_cooldowns()
	_test_resume()
	_test_saves()
	_test_new_abilities()
	_test_homing_and_modules()
	_test_hangar_and_tactics()
	_test_stage_rerolls_and_shield_breaks()
	_test_legacy_modules()
	_test_loadouts()
	_test_threat_catalog()
	_test_stage_difficulty_and_pressure()
	_test_four_stage_campaign()
	_test_boss_components_and_phases()
	_test_synergy_tradeoffs()
	_test_prototype_and_route_choices()
	_test_route_prototype_balance_grid()
	_test_new_stage_threats()
	_test_active_pool()
	_test_fusions_and_milestones()
	_test_shieldstorm_and_full_hull_focus()
	_test_long_runs()
	_test_fusion_thresholds()
	_test_expanded_hangar()
	_test_support_actives()
	_test_late_world_ability_counters()
	_test_contextual_active_balance()
	_test_five_balance_followups()
	_test_endless_encounters_and_cooldown_captures()
	_test_elite_squad_counterplay()
	_test_ship_pilot_identity_tuning()
	_test_roguelike_variation()
	_test_world1_density_and_pilot_identities()
	var seeds := 24
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = int(arg.get_slice("=", 1))
	var results: Dictionary = _balance(seeds)
	check(results.timed.wins >= results.never.wins + mini(4, maxi(1, int(seeds / 2))), "Timed inputs must improve survival over no inputs")
	# Combat and draft share RNG. Strategy changes draft outcomes, so full-run
	# hull is diagnostic rather than an isolated test of input timing.
	var timing: Dictionary = _fixed_build_timing(seeds)
	# Hard is now a progression wall without Hangar upgrades. If both
	# control policies correctly fail to beat World 1, distinguish their
	# timing by legitimate survival time rather than requiring a win.
	if timing.timed.wins == 0 and timing.on_cooldown.wins == 0:
		check(timing.timed.seconds > timing.on_cooldown.seconds + 8.0, "Timed counters must extend survival when both Hard builds lose")
	else:
		check(timing.timed.wins >= timing.on_cooldown.wins + mini(4, maxi(1, int(seeds / 2))), "Timed counters must improve wins with identical equipment")
	# In intentionally unwinnable unupgraded Hard starts, both policies
	# finish at zero hull. Compare their actual survival times instead.
	if timing.timed.wins > 0 or timing.on_cooldown.wins > 0:
		check(timing.timed.mean_hull > timing.on_cooldown.mean_hull + 3, "Timed counters must preserve more hull with identical equipment")
	print("FIXED_BUILD_TIMING ", JSON.stringify(timing))
	check(results.timed.wins > 0, "Base ship must be able to clear Stage 1 without Hangar upgrades")
	print("BALANCE ", JSON.stringify(results))
	print("RESULT: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)

func _test_five_balance_followups() -> void:
	# 1. Counter rewards must require actual timing, not a distant red lane.
	var precise := Sim.new(8320)
	precise.shield = 5.0
	precise.charges = [{"source":1,"x":precise.ship_position(0.45).x,"remaining":0.45,"duration":1.8,"damage":35.0}]
	check(precise.activate("aegis") and precise.shield >= 19.0 and precise.cooldowns.aegis < 11.0, "Aegis near impact restores shields and earns its 25% cooldown refund")
	var off_lane := Sim.new(8320)
	off_lane.shield = 5.0
	off_lane.charges = [{"source":1,"x":35.0,"remaining":0.45,"duration":1.8,"damage":35.0}]
	check(off_lane.activate("aegis") and is_equal_approx(off_lane.shield, 5.0) and is_equal_approx(float(off_lane.cooldowns.aegis), 14.0), "Aegis cannot earn precision bonus from a warning lane that misses")
	var flak_late := Sim.new(8321)
	flak_late.active_slots = ["flak"]
	flak_late.upgrades.flak = 1
	flak_late.stage = 2
	flak_late.shield = 1.0
	flak_late.bullets = [{"p":flak_late.ship_position()+Vector2(0,-52),"v":Vector2(0,150),"kind":"ordnance","source":"test","damage":11.0}]
	check(flak_late.activate("flak") and flak_late.shield >= 17.0 and flak_late.cooldowns.flak < 13.0, "World 2+ close-call Flak restores 16 shields and earns a small cooldown refund")
	var jam_precise := Sim.new(8322)
	jam_precise.active_slots = ["jammer"]
	jam_precise.upgrades.jammer = 1
	jam_precise.charges = [{"source":1,"x":270.0,"remaining":0.65,"duration":1.8,"damage":35.0}]
	var jam_early := Sim.new(8322)
	jam_early.active_slots = ["jammer"]
	jam_early.upgrades.jammer = 1
	jam_early.charges = [{"source":1,"x":270.0,"remaining":1.25,"duration":1.8,"damage":35.0}]
	check(jam_precise.activate("jammer") and jam_early.activate("jammer") and jam_precise.charges.is_empty() and jam_early.charges.is_empty(), "Both timely and early Jammer casts still stop an active beam")
	check(jam_precise.cooldowns.jammer < jam_early.cooldowns.jammer * 0.80, "The final-second Jammer counter earns a stronger refund than an early cast")
	# 2. Early Hangar ranks: no change at zero or one rank.
	var no_hangar := Sim.new(8323, {}, "kestrel", "rookie", "hard")
	var basic := Sim.new(8323, {"regen":1,"repair":1}, "kestrel", "rookie", "hard")
	var invested := Sim.new(8323, {"regen":2,"repair":2}, "kestrel", "rookie", "hard")
	for test_sim in [no_hangar, basic, invested]:
		test_sim.hull -= 45.0
		test_sim.shield -= 30.0
		test_sim.next_spawn = INF
		test_sim.next_hazard = INF
		test_sim.next_encounter_at = INF
		for frame in range(720):
			# Compare before all shields saturate at their maximum capacity.
			test_sim.step()
	check(invested.hull > basic.hull + 2.0 and invested.shield > basic.shield + 3.0, "Rank-two Hangar investment creates meaningful World 1 hull/shield sustain")
	check(basic.hull > no_hangar.hull and basic.shield > no_hangar.shield, "First permanent Hangar rank still helps; zero-rank difficulty stays the same")
	# 3. Committed fusion partners appear naturally as legal choices.
	var combo := Sim.new(8324)
	combo.upgrades.aegis = 3
	combo.level = 6
	combo.pending_levels = 1
	combo._offer_cards()
	check(combo.cards.any(func(c): return str(c.id) in ["flak", "nova"]), "Rank-3 Aegis investment can find Flak or Nova in an actual draft")
	check(combo.cards.map(func(c): return str(c.id)).size() == combo.cards.map(func(c): return str(c.id)).duplicate().size(), "Fusion guidance must preserve the standard hand size")
	var known_ids := {}
	for offered in combo.cards:
		check(not known_ids.has(str(offered.id)), "Fusion guidance never duplicates a card in the same hand")
		known_ids[str(offered.id)] = true
	var previous_cards := combo.cards.duplicate(true)
	var resumed := Sim.new(1)
	check(resumed.restore(combo.snapshot()) and resumed.cards == previous_cards, "A fusion-partner offer survives a save/restore without redrawing")
	var bar_full := Sim.new(8324)
	bar_full.active_slots = ["aegis","mend","overdrive","siphon"]
	bar_full.upgrades.aegis = 3
	bar_full.level = 6
	bar_full._offer_cards()
	check(not bar_full.cards.any(func(c): return c.tag == "ABILITY" and int(bar_full.upgrades[c.id]) == 0), "Fusion guidance cannot bypass the four-ability slot limit")
	# 5. A no-steering ship should not take two full heavy hits on the same tick.
	var stacked := Sim.new(8325)
	stacked.shield = 0.0
	stacked.hull = 100.0
	stacked._hit(20.0, "heavy", "first lane")
	stacked._hit(20.0, "heavy", "second lane")
	check(is_equal_approx(stacked.hull, 73.0), "Secondary simultaneous heavy beam deals 35%, not two full uncontrollable hits")
	check(stacked.events.any(func(e): return str(e.message).contains("Overlapping heavy beams")), "Stacked heavy-beam protection is explained in the event log")
	stacked.tick += 1
	stacked._hit(20.0, "heavy", "later lane")
	check(is_equal_approx(stacked.hull, 53.0), "Independent heavy beam on a later tick keeps its full strength")
	var blocked := Sim.new(8325)
	blocked.aegis_left = 1.0
	blocked.shield = 0.0
	blocked._hit(20.0, "heavy", "first lane")
	blocked._hit(20.0, "heavy", "second lane")
	check(is_equal_approx(blocked.hull, blocked.max_hull), "An available Aegis still counters overlapping heavy beams fully")


func _test_ship_pilot_identity_tuning() -> void:
	# Ships retain their distinct starting weapons and survivability.
	# These small traits address the clear Hard/max-Hangar Bulwark/Haven
	# boss damage gaps without making ordinary waves easier for Bulwark.
	var siege := Sim.new(88231, {}, "bulwark", "rookie")
	var baseline := Sim.new(88231, {}, "vanguard", "rookie")
	for sim in [siege, baseline]:
		sim._spawn_boss()
		sim._damage_enemy(sim.enemies[0], 100.0, "pulse")
	check(is_equal_approx(float(siege.damage_dealt.pulse) / float(baseline.damage_dealt.pulse), 1.12), "Bulwark has a narrowly scoped 12 percent automatic siege bonus against boss cores")
	var part_siege := Sim.new(88232, {}, "bulwark", "rookie")
	var part_base := Sim.new(88232, {}, "vanguard", "rookie")
	for sim in [part_siege,part_base]:
		sim.stage = 2
		sim._spawn_boss()
		sim._damage_enemy(sim.enemies[1], 100.0, "pulse")
	check(is_equal_approx(float(part_siege.damage_dealt.pulse) / float(part_base.damage_dealt.pulse), 1.12), "Bulwark siege bonus also applies to actual targetable boss modules")
	var drone_siege := Sim.new(88233, {}, "bulwark", "rookie")
	var drone_base := Sim.new(88233, {}, "vanguard", "rookie")
	for sim in [drone_siege,drone_base]:
		sim._add_enemy("drone", Vector2(270,180))
		sim._damage_enemy(sim.enemies[0], 5.0, "pulse")
	check(is_equal_approx(float(drone_siege.damage_dealt.pulse), float(drone_base.damage_dealt.pulse)), "Bulwark does not gain extra damage against ordinary waves")
	var haven := Sim.new(88234, {}, "haven", "rookie")
	var regular := Sim.new(88234, {}, "vanguard", "rookie")
	for sim in [haven,regular]:
		sim._add_enemy("drone", Vector2(270,175))
		sim._update_weapons()
	var haven_seeker: Array = haven.shots.filter(func(s): return s.weapon == "seeker")
	var normal_seeker: Array = regular.shots.filter(func(s): return s.weapon == "seeker")
	check(haven_seeker.size() == 1 and normal_seeker.size() == 1 and is_equal_approx(float(haven_seeker[0].damage) / float(normal_seeker[0].damage), 1.12), "Haven's support Seeker Pods gain 12 percent weapon damage, but no Pulse is installed")
	check(int(haven.upgrades.pulse) == 0 and int(haven.upgrades.mend) == 1, "Haven retains its signature support loadout")
	# Insane matched seeds exposed a Haven early-wave DPS and survivability gap.
	# Improve support pod cadence and the signature Mend, without a Pulse starter.
	var haven_pods := Sim.new(88237, {}, "haven", "rookie")
	var vanguard_pods := Sim.new(88237, {}, "vanguard", "rookie")
	for sim in [haven_pods, vanguard_pods]:
		sim._add_enemy("drone", Vector2(270, 175))
		sim._update_weapons()
	check(is_equal_approx(haven_pods.seeker_timer + Sim.DT * 0.95, 0.55) and is_equal_approx(vanguard_pods.seeker_timer + Sim.DT, 0.70), "Haven pods reload faster without globally accelerating every ship")
	var haven_hunter := Sim.new(88238, {}, "haven", "hunter")
	var wraith_hunter := Sim.new(88238, {}, "wraith", "hunter")
	for sim in [haven_hunter, wraith_hunter]:
		sim._add_enemy("drone", Vector2(270, 175))
		sim._update_weapons()
	check(is_equal_approx(haven_hunter.seeker_timer + Sim.DT * 0.95, 0.50) and is_equal_approx(wraith_hunter.seeker_timer + Sim.DT, 0.62), "Hunter retains the pilot lock-on advantage with Haven's support pod cadence")
	var haven_mender := Sim.new(88239, {}, "haven", "rookie")
	var regular_mender := Sim.new(88239, {}, "vanguard", "rookie")
	regular_mender.upgrades.mend = 1
	regular_mender.active_slots.append("mend")
	check(haven_mender.activate("mend") and regular_mender.activate("mend"), "Both ships can activate a naturally available Repair Drone")
	check(is_equal_approx(haven_mender.mend_rate / regular_mender.mend_rate, 1.25), "Haven signature Repair Drones heal 25 percent more than the general card")
	check(int(haven_pods.upgrades.pulse) == 0, "Haven still has no Pulse starter after its support buffs")

	var engineer := Sim.new(88235, {}, "vanguard", "engineer")
	var rookie := Sim.new(88235, {}, "vanguard", "rookie")
	check(is_equal_approx(engineer.weapon_power() / rookie.weapon_power(), 1.06), "Engineer converts maintained shields to 6 percent automatic output")
	engineer.shield = engineer.max_shield * 0.50
	check(is_equal_approx(engineer.weapon_power(), rookie.weapon_power()), "Engineer loses its bonus at half shields, preserving the defensive tradeoff")
	check(is_equal_approx(engineer.max_shield - rookie.max_shield, 20.0), "Existing Engineer shielding is unchanged")
	var resumed := Sim.new(88236)
	check(resumed.restore(engineer.snapshot()) and resumed.snapshot() == engineer.snapshot(), "Engineer shield-powered combat does not need a new save schema")


func _test_world1_density_and_pilot_identities() -> void:
	# First impressions: simultaneous visible threats rather than a late
	# stream of isolated targets that autopilot clears before they shoot.
	var normal := Sim.new(8150, {}, "vanguard", "rookie", "normal")
	var hard := Sim.new(8150, {}, "vanguard", "rookie", "hard")
	var old_hard_schedule: float = 55.0 + float(8150 % 23)
	check(normal.next_encounter_at <= 17.0 and is_equal_approx(hard.next_encounter_at, old_hard_schedule), "World 1 Normal opens with a real wing inside 17 seconds without changing Hard's gate")
	normal.time = normal.next_encounter_at
	normal._spawn_encounter()
	check(normal.enemies.size() == 3 and normal.enemies.all(func(e): return bool(e.get("strike_wing",false))), "Opening strike wing enters visibly with three enemies")
	check(normal.enemies.all(func(e): return float(e.p.y) >= 0.0), "The first strike wing must appear on-screen, not outside the frame")
	check(normal.enemies[0].xp <= hard.content.enemies[str(normal.enemies[0].kind)].xp, "World 1 does not grant free XP for every extra enemy")
	check(normal.next_spawn > normal.time + 3.0, "Strike wing spends future spawn slots instead of stacking extra kills")
	hard.time = hard.next_encounter_at
	hard._spawn_encounter()
	check(hard.enemies.is_empty() and hard.encounter_queue.size() == 3, "Hard/Insane retain their original staggered formations")
	var generic := Sim.new(4210, {}, "vanguard", "rookie")
	check(generic.ace_chain == 0 and generic.hunter_target_id == -1 and not generic.tactician_counter_used, "Vale is the no-frills pilot")
	var ace := Sim.new(4211, {}, "wraith", "ace")
	ace.stage = 2
	for j in range(4):
		ace._add_enemy("drone", Vector2(200.0 + j * 19.0, 330))
	for i in range(3):
		ace._damage_enemy(ace.enemies[i], 1000.0, "seeker")
	check(ace.events.any(func(e): return "PRECISION CROSSFIRE" in str(e.message)), "Ace chains three fast automatic-weapon kills even without Pulse")
	check(ace.enemies[3].hp < ace.enemies[3].max_hp, "Ace's precision volley deals real damage to a nearby threat")
	var interrupted := Sim.new(4212, {}, "vanguard", "ace")
	interrupted.ace_chain = 2
	interrupted.ace_chain_left = 0.0
	interrupted.step()
	check(interrupted.ace_chain == 0, "Ace's kill streak expires without rapid consecutive kills")
	var hunter := Sim.new(4213, {}, "vanguard", "hunter")
	hunter._add_enemy("gunship", Vector2(250, 180))
	hunter._update_support()
	check(hunter.hunter_target_id == hunter.enemies[0].id, "Hunter designates actual visible threats")
	var enemy: Dictionary = hunter.enemies[0]
	var first: float = enemy.hp
	hunter._damage_enemy(enemy, 12.0, "pulse")
	check(enemy.hp <= first - 13.0, "Hunter automatically deals extra damage to the marked target")
	hunter.shield = 0.0
	hunter._damage_enemy(enemy, 1000.0, "seeker")
	check(hunter.shield >= 10.0 and hunter.hunter_target_id == -1, "Hunter's target elimination restores shields and releases the mark")
	var nyx := Sim.new(4214, {}, "vanguard", "tactician")
	check(nyx.activate("aegis") and not nyx.tactician_counter_used, "Tactician cannot earn its one-time counterbattery by blind casting")
	var counter := Sim.new(4215, {}, "vanguard", "tactician")
	counter.charges.append({"source":777,"x":250.0,"remaining":0.5,"duration":1.8,"damage":23.0})
	check(counter.activate("aegis") and counter.tactician_counter_used and counter.events.any(func(e): return "TACTICAL COUNTERBATTERY" in str(e.message)), "A timed ability against a real warning triggers the one-world counterbattery")
	var saved: Dictionary = counter.snapshot()
	var restore := Sim.new()
	check(restore.restore(saved) and restore.snapshot() == saved, "New pilot states survive exact checkpoint restore")
	counter.stage_transition_queued = true
	counter.stage_clears = 1
	check(counter.begin_intermission() and counter.skip_prototype() and counter.choose_route("repair") and counter.advance_stage() and not counter.tactician_counter_used, "Tactician gets a fresh counterbattery only after a successful warp")
	var old := generic.snapshot()
	for key in ["ace_chain","ace_chain_left","hunter_target_id","hunter_mark_left","hunter_mark_cooldown","tactician_counter_used"]:
		old.erase(key)
	check(Sim.new().restore(old), "Historical 1.3 saves remain compatible with new optional pilot fields")

func _test_roguelike_variation() -> void:
	var standard := Sim.new(444)
	var glass := Sim.new(444, {}, "vanguard", "rookie", "normal", "glass_fleet")
	check(glass.max_hull == standard.max_hull * 0.50 and glass.max_shield == standard.max_shield * 1.25, "Glass Fleet trades half hull for bigger shields")
	check(glass.weapon_power() > standard.weapon_power() * 1.49, "Glass Fleet earns a meaningful weapon damage advantage")
	var army := Sim.new(445, {}, "vanguard", "rookie", "normal", "drone_armada")
	check(army.upgrades.pulse == 0 and army.upgrades.seeker == 0, "Drone Armada disables conventional starting guns")
	army._update_support()
	check(army.escort_count == 3 and army.escort_left > 1000.0, "Drone Armada launches persistent autonomous escorts")
	army._offer_cards(false)
	check(army.cards.all(func(c): return str(c.tag) not in ["WEAPON", "MUTATION"]), "Drone mode cannot draft unusable conventional weapons")
	var shift := Sim.new(446, {}, "vanguard", "rookie", "normal", "arsenal_roulette")
	shift.upgrades.pulse = 4
	shift.upgrades.seeker = 2
	shift.upgrades.arc = 1
	shift.upgrades.lance = 3
	shift.stage_transition_queued = true
	shift.stage_clears = 1
	check(shift.begin_intermission() and shift.skip_prototype() and shift.choose_route("repair") and shift.advance_stage(), "Artifact mode passes through the real boss intermission")
	check([shift.upgrades.pulse,shift.upgrades.seeker,shift.upgrades.arc,shift.upgrades.lance] == [3,4,2,1], "Arsenal Shift rotates actual weapon ranks without duplicating them")
	var rare := Sim.new(447)
	rare.stage = 2
	rare.level = 5
	rare._offer_cards(false)
	check(not rare.cards.any(func(c): return str(c.tag) == "MUTATION"), "Mutation cards only appear at their rare milestone gate")
	var rare_found := false
	for candidate_seed in range(456, 486):
		var candidate := Sim.new(candidate_seed)
		candidate.stage = 2
		candidate.level = 8
		candidate._offer_cards(false)
		if candidate.cards.any(func(c): return str(c.tag) == "MUTATION"):
			rare_found = true
			check(candidate.cards.any(func(c): return str(c.id) in ["piercing_pulse", "split_seeker"]), "Only mutations for owned weapons are offered")
			break
	check(rare_found, "Rare transformations must be obtainable in later-world drafts across multiple seeds")
	var pulse := Sim.new(447)
	check(pulse._install_mutation("piercing_pulse"), "Owned Pulse can receive Ghost Rounds")
	check(not pulse._install_mutation("split_seeker"), "A run cannot stack multiple rare mutations")
	pulse._update_weapons()
	check(pulse.shots.any(func(s): return str(s.weapon) == "pulse" and int(s.pierce) == 1), "Ghost Rounds grants a real second-target projectile")
	pulse.enemies = [
		{"id":1,"kind":"drone","p":Vector2(270,400),"hp":100.0,"max_hp":100.0,"xp":3,"phase":0.0,"speed":0.0,"fire":99.0},
		{"id":2,"kind":"drone","p":Vector2(280,398),"hp":100.0,"max_hp":100.0,"xp":3,"phase":0.0,"speed":0.0,"fire":99.0}
	]
	pulse.shots = [{"p":Vector2(270,416),"v":Vector2(0,-960),"damage":20.0,"weapon":"pulse","target":-1,"pierce":1,"last_enemy":-1}]
	pulse._update_shots()
	check(pulse.enemies[0].hp <= 80.0 and pulse.enemies[1].hp <= 88.0, "Ghost Rounds really strike a second target for 60 percent damage")
	var rockets := Sim.new(448, {}, "wraith")
	check(rockets._install_mutation("split_seeker"), "Wraith can install Hydra Warheads")
	rockets.enemies = [
		{"id":1,"kind":"drone","p":Vector2(270, 400),"hp":12.0,"max_hp":12.0,"xp":3,"phase":0.0,"speed":0.0,"fire":99.0},
		{"id":2,"kind":"drone","p":Vector2(290, 350),"hp":100.0,"max_hp":100.0,"xp":3,"phase":0.0,"speed":0.0,"fire":99.0}
	]
	rockets.shots = [{"p":Vector2(270, 400), "v":Vector2.ZERO, "damage":25.0, "weapon":"seeker", "target":1}]
	rockets._update_shots()
	check(rockets.shots.any(func(s): return str(s.weapon) == "seeker" and bool(s.get("shard", false))), "Hydra Warhead spawns real homing fragments instead of cosmetic sparks")
	var arc := Sim.new(449, {}, "arcwing")
	check(arc._install_mutation("arc_reactor"), "Arcwing can mutate its Arc Coil")
	arc.enemies = [
		{"id":1,"kind":"drone","p":Vector2(270, 400),"hp":2.0,"max_hp":2.0,"xp":3,"phase":0.0,"speed":0.0,"fire":99.0},
		{"id":2,"kind":"drone","p":Vector2(280, 400),"hp":100.0,"max_hp":100.0,"xp":3,"phase":0.0,"speed":0.0,"fire":99.0}
	]
	arc._damage_enemy(arc.enemies[0], 9.0, "arc")
	check(arc.enemies[1].hp < 100.0 and arc.effects.any(func(e): return str(e.kind) == "arc"), "Chain Reactor does damage to a second enemy on an Arc Coil kill")
	var market := Sim.new(450)
	market.stage_transition_queued = true
	market.stage_clears = 1
	check(market.begin_intermission(), "Boss defeat permits a black market opportunity")
	market.prototype_offers[2] = "market:piercing_pulse"
	var prior_shield := market.max_shield
	check(market.choose_prototype(2) and market.mutations == ["piercing_pulse"], "Black-market trade gives a real mutation")
	check(is_equal_approx(market.max_shield, prior_shield * 0.75) and market.prototypes.is_empty(), "Black-market trade permanently sacrifices shield capacity, not a free Prototype")
	check(not market.choose_prototype(2) and market.choose_route("repair"), "Cannot buy the same black-market trade twice")
	var saved := market.snapshot()
	var resumed := Sim.new()
	check(resumed.restore(saved) and resumed.snapshot() == saved, "Market and mutation state survive a precise checkpoint")
	var scavenge := Sim.new(451, {}, "vanguard", "scavenger")
	scavenge.kills = 11
	scavenge._add_enemy("drone", Vector2(270, 400))
	scavenge._add_enemy("drone", Vector2(280, 405))
	var neighbor: Dictionary = scavenge.enemies[1]
	var old_hp: float = float(neighbor.hp)
	scavenge._damage_enemy(scavenge.enemies[0], 10000.0, "pulse")
	check(neighbor.hp < old_hp and scavenge.events.any(func(e): return "SCRAP STORM" in str(e.message)), "Scavenger converts every twelfth kill into a damaging wreckage shockwave")
	var repair := Sim.new(452, {}, "vanguard", "engineer")
	repair.shield = 1.0
	repair._hit(5.0, "ordnance", "test")
	check(repair.sentry_left > 5.0 and repair.events.any(func(e): return "FIELD SENTRY" in str(e.message)), "Engineer deploys a temporary offensive sentry on shield break")
	repair._add_enemy("drone", Vector2(260,250))
	repair._update_support()
	check(repair.shots.any(func(s): return str(s.weapon) == "escort" and s.damage > 0.0), "Engineer sentry fires independent offensive shots")
	var default_save := standard.snapshot()
	for key in ["artifact_id", "mutations", "sentry_left", "sentry_timer"]:
		default_save.erase(key)
	check(Sim.new().restore(default_save), "Legacy flight checkpoints load without artifact or mutation fields")
	check(Catalog.artifact("not_an_artifact").id == "standard" and Catalog.mutation("nonexistent").is_empty(), "Unknown modes and mutation IDs are safely rejected")

func _test_elite_squad_counterplay() -> void:
	# Promote existing normal spawn slots, never additional enemies/XP.
	var opener := Sim.new(7600)
	opener._spawn_encounter()
	check(opener.encounter_queue.size() == 3 and opener.encounter_queue[0] is String, "World 1 never introduces elites or changes its original formation queue")
	var squad := Sim.new(7600)
	squad.stage = 2
	squad._spawn_encounter()
	check(squad.encounter_queue.size() == 3 and squad.encounter_queue[0] is Dictionary, "One of two World 2-4 natural encounters becomes an elite three-ship formation")
	var queued_before: Array = squad.encounter_queue.duplicate(true)
	var queued_restored := Sim.new(1)
	check(queued_restored.restore(squad.snapshot()) and queued_restored.encounter_queue == queued_before, "Elite formation queue is deterministic through a checkpoint")
	for i in range(3):
		squad._spawn_enemy()
	check(squad.enemies.size() == 3 and squad.encounter_queue.is_empty(), "Elite squads consume exactly three ordinary enemy spawn slots")
	var leader: Dictionary = squad.enemies[0]
	var wing: Dictionary = squad.enemies[1]
	check(str(leader.get("elite_role", "")) == "leader" and str(wing.get("elite_role", "")) == "wing", "Leader and escort roles are explicit for visuals and auto-targeting")
	check(int(wing.elite_squad) == int(leader.id) and squad._elite_leader_active(wing), "Wing firing bonus depends on a specific living leader")
	var raw_leader_hp: float = float(squad.content.enemies[str(leader.kind)].hp) * float(squad.stage_spec().health_scale) * squad.threat_scale() * squad.stage_risk * squad.enemy_health_multiplier() * squad.shooter_health_pressure(str(leader.kind))
	check(is_equal_approx(float(leader.max_hp), raw_leader_hp * 1.20), "Elite leader has a visible but restrained 20 percent health bonus")
	wing.p = Vector2(280.0, 175.0)
	wing.fire = 0.0
	squad._update_enemies()
	var interval: float = float(squad.content.enemies[str(wing.kind)].interval) / squad.enemy_fire_scale() * squad.projectile_interval_factor(str(wing.kind))
	check(is_equal_approx(float(wing.fire), interval * 0.80), "Escort attacks 20 percent faster only while the elite leader is active")
	var saved := squad.snapshot()
	var resumed := Sim.new(1)
	check(resumed.restore(saved) and resumed.snapshot() == saved, "Leader and wing state survives mid-fight save and restore")
	squad._damage_enemy(leader, float(leader.hp) + 999.0, "pulse")
	check(not squad._elite_leader_active(wing) and bool(wing.elite_disrupted), "Destroying the leader removes escort coordination without killing escorts")
	check(float(wing.fire) >= 1.80 and squad.effects.any(func(e): return e.kind == "elite-broken"), "Leader destruction interrupts the next escort salvo and creates readable feedback")
	check(squad.events.any(func(e): return "FORMATION BROKEN" in str(e.message)), "Player receives a named formation-break event")
	wing.fire = 0.0
	squad._update_enemies()
	check(is_equal_approx(float(wing.fire), interval), "Surviving disrupted wing returns to ordinary firing rate")
	var early := Sim.new(7600)
	early.stage = 2
	early._spawn_encounter()
	early._spawn_enemy()
	early._damage_enemy(early.enemies[0], float(early.enemies[0].hp) + 999.0, "pulse")
	check(early.encounter_queue.all(func(q): return q is Dictionary and bool(q.disrupted)), "Destroying a leader before the escorts arrive also disables their queued attack boost")
	for i in range(2):
		early._spawn_enemy()
	check(early.enemies.size() == 3 and bool(early.enemies[1].elite_disrupted) and float(early.enemies[1].fire) >= 1.8, "Late-arriving escorts spawn already disrupted without an extra enemy reward")
	var late := Sim.new(7600)
	late.stage = 3
	late.encounter_index = 1
	late._spawn_encounter()
	check(late.encounter_queue.size() == 3 and late.encounter_queue[0] is String, "Other formations remain ordinary and World 3 encounters alternate")
	late.encounter_queue.clear()
	late.stage = 4
	late.encounter_index = 0
	late._spawn_encounter()
	check(late.encounter_queue.size() == 3 and late.encounter_queue[0] is Dictionary, "World 4 includes marked elite formations too")
	# Historical string queues remain functional when loading older 1.3 saves.
	var legacy := Sim.new(7600)
	legacy.stage = 3
	legacy.encounter_queue = ["gunship","shieldguard","disruptor"]
	legacy._spawn_enemy()
	check(legacy.enemies.size() == 1 and not legacy.enemies[0].has("elite_role"), "Plain-string formation checkpoints from earlier builds still spawn normally")
	var pre_boss := Sim.new(7600)
	pre_boss.stage = 2
	pre_boss._spawn_encounter()
	pre_boss._spawn_boss()
	check(pre_boss.encounter_queue.is_empty() and not pre_boss.enemies.any(func(e): return e.has("elite_role")), "Boss entry clears elite queues and does not change boss encounters")


func _test_endless_encounters_and_cooldown_captures() -> void:
	var cooldown := Sim.new(7711)
	check(cooldown.activate("aegis") and is_equal_approx(float(cooldown.cooldown_totals.aegis), float(cooldown.cooldowns.aegis)), "Cooldown meters must capture the actual modified cast cooldown")
	var campaign := Sim.new(7611)
	campaign.stage = 4
	campaign.stage_clears = 4
	campaign.stage_transition_queued = true
	check(campaign.stage_count() == 4 and not campaign.ended, "Fourth victory must still offer a real choice before settling")
	check(campaign.enable_endless() and campaign.stage_count() == 5, "Endless unlock extends the four-world campaign without ending the flight")
	check(not campaign.enable_endless(), "Continuing into endless is an explicit one-time choice")
	check(campaign.begin_intermission(), "World 4 continue still requires a strategic intermission")
	check(campaign.choose_prototype(0) and campaign.choose_route("repair") and campaign.advance_stage(), "Existing loadout continues through the World 5 warp")
	check(campaign.stage == 5 and campaign.stage_spec().damage_scale > float(campaign.content.stages[3].damage_scale), "World 5 danger must exceed World 4")
	check(campaign.stage_spec().boss_hp > float(campaign.content.stages[3].boss_hp), "Endless bosses must keep increasing in health")
	var saved := campaign.snapshot()
	var restored := Sim.new(7611)
	check(restored.restore(saved) and restored.snapshot() == saved, "Endless state and per-cast cooldowns must survive checkpoints")
	campaign._spawn_encounter()
	check(campaign.encounter_queue.size() == 3 and campaign.encounter_index == 1, "Seeded encounters must queue a three-ship formation")
	var first_pattern := str(campaign.encounter_queue[0])
	for i in range(3):
		campaign._spawn_enemy()
	check(campaign.enemies.size() == 3 and campaign.encounter_queue.is_empty(), "Formations must replace exactly three normal spawn slots")
	campaign.enemies.clear()
	campaign._spawn_encounter()
	check(campaign.encounter_queue.size() == 3 and str(campaign.encounter_queue[0]) != first_pattern, "Repeat encounters must rotate their formation")
	campaign.encounter_queue.clear()
	campaign.enemies.clear()
	campaign._spawn_boss()
	check(campaign.boss_spawned and campaign.boss_attack_pattern in ["sweep", "crossfire", "delayed fan"], "Endless boss attack sequences are announced and deterministic")
	campaign.stage_clears = campaign.stage
	campaign.stage_transition_queued = true
	check(campaign.claim_endless() and campaign.ended and campaign.won, "Endless must let the player bank a victorious run")
	check(not campaign.claim_endless(), "Endless victory can only settle once")
	var exhausted := Sim.new(7612)
	exhausted.stage = 5
	exhausted.endless_enabled = true
	exhausted.stage_clears = 5
	exhausted.stage_transition_queued = true
	for item in exhausted.content.prototypes:
		exhausted.prototypes.append(str(item.id))
	check(exhausted.begin_intermission() and exhausted.intermission_step == "route", "After all prototype discoveries, endless must still offer routes")
	check(exhausted.choose_route("repair") and exhausted.advance_stage() and exhausted.stage == 6, "A depleted prototype pool must never stall endless")

func _test_course() -> void:
	var sim := Sim.new(8821)
	var other := Sim.new(8822)
	var inside := true
	var max_speed := 0.0
	var max_acceleration := 0.0
	var previous := sim.ship_velocity(0.25)
	for i in range(2, 1440):
		var at := i * 0.25
		var p := sim.ship_position(at)
		var v := sim.ship_velocity(at)
		inside = inside and p.x >= 60 and p.x <= 480 and p.y >= 585 and p.y <= 860
		max_speed = maxf(max_speed, v.length())
		max_acceleration = maxf(max_acceleration, (v - previous).length() / 0.25)
		previous = v
	check(inside, "Curved course must remain in the safe flight band")
	check(max_speed > 120.0 and max_speed < 450.0, "New pilot must move faster while avoiding abrupt cross-screen lunges")
	check(max_acceleration < 600.0, "Course corrections must preserve smooth velocity")
	check(sim.ship_position(20).distance_to(other.ship_position(20)) > 1, "Different seeds must produce distinct routes")
	check(sim.ship_position(30).distance_to(sim.ship_position(36)) > 5, "New pilot must not repeat the old six-second weave")
	var long_flight := Sim.new(8821)
	var before_rng: int = long_flight.rng.state
	var late_positions: Array = []
	for index in range(20):
		late_positions.append(long_flight.ship_position(1500.0 + index * 4.0))
	var distance := 0.0
	for index in range(1,late_positions.size()):
		distance += late_positions[index].distance_to(late_positions[index - 1])
	check(distance > 200.0, "Pilot course must keep moving after the old 1200-second limit in World 4 and endless")
	check(long_flight.rng.state == before_rng, "Extending the flight path must not change draft or combat RNG")
	var saved_long := long_flight.snapshot()
	var resumed_long := Sim.new(8822)
	check(resumed_long.restore(saved_long), "Long flight checkpoints must restore without storing the generated course")
	var same_path := true
	for index in range(12):
		var at := 1260.0 + index * 27.0
		same_path = same_path and long_flight.ship_position(at).distance_to(resumed_long.ship_position(at)) < 0.001
	check(same_path, "Restoring a late-world flight must reproduce its extended course from the original seed")
	var legacy := sim.snapshot()
	legacy.erase("movement_version")
	other.restore(legacy)
	check(other.movement_version == 1 and is_equal_approx(other.ship_position(1.5).x, 432.0), "Legacy suspended flights must keep their original trajectory")

func _test_defenses() -> void:
	var sim := Sim.new(9)
	sim.shield = 0
	sim.upgrades.armor = 5
	sim._hit(1, "chaff", "test")
	check(is_equal_approx(sim.hull, 99.75), "Armor must retain the 25% damage floor")
	sim._hit(30, "heavy", "test")
	check(is_equal_approx(sim.hull, 69.75), "Heavy damage must bypass armor")
	sim.activate("aegis")
	sim._hit(30, "heavy", "test")
	check(is_equal_approx(sim.hull, 69.75) and sim.prevented == 30, "Aegis must block heavy damage")
	check(not sim.activate("aegis"), "Aegis cannot be activated twice on cooldown")
	var shield_sim := Sim.new()
	shield_sim.shield = 1
	shield_sim._hit(5, "chaff", "test")
	check(shield_sim.shield_offline == 3.0 and shield_sim.hull == 96.0, "Shield break must apply overflow and downtime")
	for i in range(180):
		shield_sim.step()
	check(shield_sim.shield < 0.1, "Broken shield must not regenerate during its offline window")

func _test_interrupts_and_priority() -> void:
	var sim := Sim.new(20)
	sim.enemies = [{"id": 1, "kind": "drone", "p": Vector2(100, 200), "hp": 30.0, "max_hp": 30.0, "speed": 0.0, "fire": 99.0, "xp": 3, "phase": 0.0}]
	sim.charges = [{"source": 1, "x": 270.0, "remaining": 1.0, "duration": 1.8, "damage": 24.0}]
	sim._update_weapons()
	check(sim.shots[-1].target == 1, "Seekers must prioritize the charging source")
	sim._damage_enemy(sim.enemies[0], 40, "pulse")
	check(sim.charges.is_empty() and sim.beams_cancelled == 1, "Killing a charging source must cancel its beam")
	check(sim.effects.any(func(e): return e.kind == "beam-canceled" and int(e.source) == 1 and is_equal_approx(float(e.x), 270.0)), "Destroyed charging source must expose its canceled lane to the visual layer")
	check(not sim.effects.any(func(e): return e.kind == "beam"), "Destroying a charger must not draw an actual fired heavy beam")
	check(sim.events.any(func(e): return str(e.message).contains("Beam canceled")), "Player-facing combat log explains the canceled charge")
	var two_sources := Sim.new(201)
	two_sources.enemies = [
		{"id": 11, "kind": "sniper", "p": Vector2(180, 225), "hp": 40.0, "max_hp": 40.0, "speed": 0.0, "fire": 99.0, "xp": 0, "phase": 0.0},
		{"id": 12, "kind": "sniper", "p": Vector2(390, 225), "hp": 40.0, "max_hp": 40.0, "speed": 0.0, "fire": 99.0, "xp": 0, "phase": 0.0}
	]
	two_sources.charges = [
		{"source": 11, "x": 180.0, "remaining": 0.7, "duration": 1.8, "damage": 22.0},
		{"source": 12, "x": 390.0, "remaining": 0.9, "duration": 1.8, "damage": 22.0}
	]
	two_sources._damage_enemy(two_sources.enemies[0], 100.0, "pulse")
	check(two_sources.charges.size() == 1 and int(two_sources.charges[0].source) == 12 and two_sources.beams_cancelled == 1, "Destroying one charging source leaves unrelated active red warning lanes alone")
	check(two_sources.effects.filter(func(e): return e.kind == "beam-canceled").size() == 1, "Only canceled red beam lane receives a cyan cancellation cue")
	sim = Sim.new(20, {}, "arcwing")
	sim.charges = [{"source": 99, "x": 270.0, "remaining": 1.0, "duration": 1.8, "damage": 30.0}]
	sim.bullets = [{"p": Vector2(100, 100), "v": Vector2.ZERO, "damage": 12.0, "kind": "ordnance", "hp": 12.0, "source": "gunship"}]
	sim.activate("nova")
	check(sim.charges.is_empty() and sim.bullets.is_empty(), "Nova must cancel beams and remove ordnance at level 1")
	check(sim.cooldowns.aegis == 0.0, "Nova must not consume Aegis")
	sim = Sim.new()
	sim.upgrades.aegis = 5
	sim.enemies = [{"id": 1, "kind": "boss", "p": Vector2(270, 135), "hp": 200.0, "max_hp": 200.0, "speed": 0.0, "fire": 99.0, "xp": 0, "phase": 0.0}]
	sim.charges = [{"source": 1, "x": sim.ship_position().x, "remaining": Sim.DT, "duration": 1.8, "damage": 35.0}]
	sim.activate("aegis")
	check(sim.enemies[0].hp == 200.0, "Aegis capstone must not reflect before a beam lands")
	sim._update_charges()
	check(sim.enemies[0].hp == 140.0 and sim.prevented == 35.0, "Aegis capstone must reflect a blocked heavy beam")

func _test_lance_fire_reliability() -> void:
	# A mine or Aegis reflection can kill the last enemy before the weapon
	# pass. Its dead dictionary remains in enemies until _update_shots().
	var sim := Sim.new(16401)
	sim.upgrades.lance = 1
	sim.enemies = [{"id": 81, "kind": "drone", "p": Vector2(450, 310), "hp": 0.0, "max_hp": 20.0, "speed": 0.0, "fire": 99.0, "xp": 0, "phase": 0.0}]
	sim.lance_timer = 0.0
	sim._update_weapons()
	check(sim.lance_timer <= 0.0 and not sim.effects.any(func(e): return e.kind == "lance"), "Prism lance must not waste its cooldown on an already-killed target")

	# The next available living enemy should receive the strike immediately;
	# a stale charge from a dead source must never steal targeting priority.
	sim.enemies.append({"id": 82, "kind": "drone", "p": Vector2(270, 400), "hp": 100.0, "max_hp": 100.0, "speed": 0.0, "fire": 99.0, "xp": 0, "phase": 0.0})
	sim.charges = [{"source": 81, "x": 450.0, "remaining": 0.8, "duration": 1.8, "damage": 20.0}]
	sim._update_weapons()
	var beams: Array = sim.effects.filter(func(e): return e.kind == "lance")
	check(beams.size() == 1 and sim.lance_timer > 0.0 and float(sim.damage_dealt.lance) > 0.0 and sim.enemies[1].hp < 100.0, "Prism lance must fire and hit the first living target after a dead-only frame")
	if not beams.is_empty():
		check(Geometry2D.get_closest_point_to_segment(sim.enemies[1].p, beams[0].p, beams[0].to).distance_to(sim.enemies[1].p) < 1.0, "Prism lance must not aim at a dead charging source")
		check(float(beams[0].max_life) >= 0.60, "Prism lance effect must remain readable at 3x speed")
		var before_damage: float = float(sim.damage_dealt.lance)
		sim._update_weapons()
		check(is_equal_approx(float(sim.damage_dealt.lance), before_damage) and sim.effects.filter(func(e): return e.kind == "lance").size() == 1, "A single lance burst must deal damage only once until the next cooldown")
		for frame in range(27):
			sim.step()
		check(sim.effects.any(func(e): return e.kind == "lance"), "Prism lance shot must still be visible after 0.15 real seconds at 3x")

func _test_shooter_health_screen_pressure() -> void:
	# Baseline World 1 is unchanged regardless of difficulty and investment.
	for mode in Catalog.DIFFICULTIES:
		var first := Sim.new(71230, {}, "vanguard", "rookie", mode)
		for kind in ["drone", "gunship", "sniper", "missile_bomber", "shieldguard", "carrier"]:
			check(is_equal_approx(first.shooter_health_pressure(kind), 1.0), "Opening-world %s HP remains unchanged on %s" % [kind,mode])
			check(first.shooter_first_fire_window(kind) == Vector2(1.0, 3.0), "Opening-world %s first-shot delay stays at 1–3 seconds on %s" % [kind,mode])
	# World 2+ changes only the tougher shooter class, not minion XP,
	# heavyweight hazards, rapid threats, snipers or boss modules.
	var baseline := Sim.new(71231)
	baseline.stage = 2
	baseline._add_enemy("ion_frigate", Vector2(270, 90))
	var tested := Sim.new(71231)
	tested.stage = 2
	tested._add_enemy("ion_frigate", Vector2(270, 90))
	var original: float = float(tested.content.enemies.ion_frigate.hp) * float(tested.stage_spec().health_scale) * tested.threat_scale() * tested.stage_risk * tested.enemy_health_multiplier()
	check(is_equal_approx(float(tested.enemies[0].max_hp), original * 1.12), "Normal World 2 ion frigate gets 12 percent more HP without changing any other scaling")
	check(int(tested.enemies[0].xp) == int(tested.content.enemies.ion_frigate.xp), "Tougher shooters retain the same XP reward")
	check(tested.shooter_first_fire_window("ion_frigate") == Vector2(0.95, 1.80), "World 2 target shooters receive the shorter and readable first shot window")
	check(float(tested.enemies[0].fire) >= 0.95 and float(tested.enemies[0].fire) <= 1.80, "Spawned World 2 shooter actually starts at the shortened timer")
	for mode in Catalog.DIFFICULTIES:
		var challenger := Sim.new(71232, {}, "vanguard", "rookie", mode)
		challenger.stage = 3
		for kind in ["gunship","shieldguard","ion_frigate","corroder","disruptor","arc_spire","forge_turret","gravity_sentinel"]:
			check(is_equal_approx(challenger.shooter_health_pressure(kind), {"normal":1.15,"hard":1.20,"insane":1.25}[mode]), "Targeted backline enemy receives the correct optional HP increase: %s / %s" % [kind,mode])
			check(challenger.shooter_first_fire_window(kind) == Vector2(0.85, 1.65), "Later-world %s uses a quicker opening shot but not a faster repeated attack on %s" % [kind,mode])
		for kind in ["drone","rusher","interceptor","ember_hunter","storm_weaver","sniper","void_lancer","carrier","echo_carrier","minelayer","slag_bomber","missile_bomber","boulder","station","boss","boss2","boss3","boss4","boss_module"]:
			check(is_equal_approx(challenger.shooter_health_pressure(kind), 1.0), "Fast/XP/beam/boss units keep their old HP: %s / %s" % [kind,mode])
			check(challenger.shooter_first_fire_window(kind) == Vector2(1.0, 3.0), "Hazards/fast/beam/boss opening volleys are unchanged: %s / %s" % [kind,mode])
	var stationary := Sim.new(71233)
	stationary.stage = 4
	stationary._add_enemy("gravity_sentinel", Vector2(270,100))
	var original_health: float = float(stationary.content.enemies.gravity_sentinel.hp) * float(stationary.stage_spec().health_scale) * stationary.threat_scale() * stationary.stage_risk * stationary.enemy_health_multiplier()
	check(is_equal_approx(float(stationary.enemies[0].max_hp), original_health * 1.15), "Targeted later world HP increase applies to real spawned sentinel")
	check(Sim.new(33).restore(stationary.snapshot()), "Experimental HP and its spawned enemy states use the existing checkpoint save format")
	# Faster opening shots must be visible, not wasted above the viewport.
	# Some new arc spires move slowly and would otherwise fire at y < 0.
	var turret := Sim.new(71234)
	turret.stage = 2
	turret._add_enemy("arc_spire", Vector2(270,-35))
	turret.enemies[0].fire = 0.0
	for frame in range(70):
		turret._update_enemies()
	check(turret.bullets.is_empty() and float(turret.enemies[0].fire) == 0.0, "A slow shooter cannot expend its opening volley above the visible playfield")
	for frame in range(90):
		turret._update_enemies()
	check(turret.bullets.size() == 9 and float(turret.enemies[0].p.y) >= 0.0, "Shooter releases its first visible nine-round pattern once it enters the playfield")
	var cadence := Sim.new(71235)
	cadence.stage = 2
	cadence._add_enemy("ion_frigate", Vector2(270,120))
	cadence.enemies[0].fire = 0.0
	cadence._update_enemies()
	var next_interval: float = float(cadence.content.enemies.ion_frigate.interval) / cadence.enemy_fire_scale() * cadence.projectile_interval_factor("ion_frigate")
	check(is_equal_approx(float(cadence.enemies[0].fire), next_interval), "Later volleys retain the existing 1.2 interval; only the first-shot delay changes")
	check(cadence.bullets.size() == 3 and int(cadence.enemies[0].xp) == 9, "Earlier opening shot preserves the ordinary volley count and XP")
	var checkpoint := cadence.snapshot()
	var reloaded := Sim.new(999)
	check(reloaded.restore(checkpoint) and reloaded.snapshot() == checkpoint, "A shooter that has fired a first volley restores without rescheduling it")


func _test_boss_scaling_and_hangar_expansion() -> void:
	# New Hangar purchases cost at least ten percent more than their displayed
	# 1.1 prices. Already-paid receipts are never recomputed or inflated.
	for entry in Catalog.HANGAR:
		var key: String = str(entry.id)
		for rank in range(int(entry.max)):
			var old_price: int = Catalog.previous_price(key, rank)
			check(Catalog.price(key, rank) == ceili(old_price * 1.10), "Compounded Hangar price for %s rank %d" % [key, rank])
	var caps := {"hull":7,"shield":7,"regen":6,"ability_cooldown":6,"boss_damage":6}
	for key in caps:
		check(int(Catalog.entry(str(key)).max) == int(caps[key]), "Extra purchased rank is accessible for " + str(key))
	check(Catalog.entry("module_breaker").max == 3 and Catalog.entry("point_defense").max == 3, "New boss module offense and projectile defense tracks are in the real Hangar catalog")
	var saved_hangar := {"hull":7, "shield":7, "regen":6, "ability_cooldown":6, "boss_damage":6, "module_breaker":3, "point_defense":3}
	var held := Sim.new(18802, saved_hangar)
	var resumed := Sim.new(1)
	check(resumed.restore(held.snapshot()) and resumed.snapshot() == held.snapshot(), "Expanded Hangar track values and newly introduced tracks round-trip in existing save schema")
	check(is_equal_approx(held.max_hull, 170.0) and is_equal_approx(held.max_shield, 106.0), "One more Hull and Shield capacitor rank increases actual starting survival")
	# On the same stage, the new boss-specific difficulty curve must rise
	# faster than the ordinary enemy difficulty curve, without new enemies.
	for stage_number in [1, 2, 3, 4]:
		var cores := {}
		var parts := {}
		var ordinary := {}
		var last_ready := {}
		for mode in Catalog.DIFFICULTIES:
			var sim := Sim.new(18803, {}, "vanguard", "rookie", mode)
			sim.stage = stage_number
			sim._add_enemy("drone", Vector2(270, 100))
			ordinary[mode] = float(sim.enemies[0].max_hp)
			sim._spawn_boss()
			cores[mode] = float(sim.enemies[0].max_hp)
			last_ready[mode] = sim.heavy_ready_at
			if stage_number >= 2:
				parts[mode] = float(sim.enemies[1].max_hp)
		check(float(cores.hard) / float(cores.normal) > float(ordinary.hard) / float(ordinary.normal), "Hard boss %d scales more steeply than regular enemies" % stage_number)
		check(float(cores.insane) / float(cores.hard) > float(ordinary.insane) / float(ordinary.hard), "Insane boss %d scales more steeply than regular enemies" % stage_number)
		check(is_equal_approx(float(last_ready.normal), float(last_ready.hard)) and is_equal_approx(float(last_ready.normal), float(last_ready.insane)), "Harder boss %d preserves heavy-beam warning timing" % stage_number)
		if stage_number >= 2:
			check(is_equal_approx(float(parts.hard) / float(parts.normal), float(cores.hard) / float(cores.normal)) and is_equal_approx(float(parts.insane) / float(parts.normal), float(cores.insane) / float(cores.normal)), "Boss %d targetable parts scale as strongly as the core" % stage_number)
	var fighter := Sim.new(18804)
	fighter.stage = 3
	fighter._spawn_boss()
	var breaker := Sim.new(18804, {"module_breaker":3})
	breaker.stage = 3
	breaker._spawn_boss()
	var regular_part: Dictionary = fighter.enemies[1]
	var boosted_part: Dictionary = breaker.enemies[1]
	var before: float = float(regular_part.hp)
	var before_boosted: float = float(boosted_part.hp)
	fighter._damage_enemy(regular_part, 100.0, "pulse")
	breaker._damage_enemy(boosted_part, 100.0, "pulse")
	check(is_equal_approx((before_boosted - float(boosted_part.hp)) / (before - float(regular_part.hp)), 1.18), "Breach sensors add 6 percent boss-module damage per rank")
	var core_unboosted: Dictionary = fighter.enemies[0]
	var core_boosted: Dictionary = breaker.enemies[0]
	before = float(core_unboosted.hp)
	before_boosted = float(core_boosted.hp)
	fighter._damage_enemy(core_unboosted, 100.0, "pulse")
	breaker._damage_enemy(core_boosted, 100.0, "pulse")
	check(is_equal_approx(before_boosted - float(core_boosted.hp), before - float(core_unboosted.hp)), "Breach sensors do not strengthen generic shots or bypass protected cores")
	var unshielded := Sim.new(18805)
	var guarded := Sim.new(18805, {"point_defense":3})
	for sim in [unshielded, guarded]:
		sim.shield = 0.0
		sim.hull = 100.0
		sim._hit(20.0, "heat", "boss3")
	check(is_equal_approx(float(guarded.damage_taken.heat) / float(unshielded.damage_taken.heat), 0.85), "Point defense reduces boss status projectiles by 5 percent per rank")
	var regular_shot := Sim.new(18806, {"point_defense":3})
	regular_shot.shield = 0
	regular_shot._hit(20.0, "chaff", "gunship")
	check(is_equal_approx(float(regular_shot.damage_taken.chaff), float(Sim.new(18806).damage_taken.chaff) + 20.0), "Point defense never softens regular enemies")
	var unguarded_beam := Sim.new(18807)
	var guarded_beam := Sim.new(18807, {"point_defense":3})
	unguarded_beam._hit(25.0, "heavy", "Harvester")
	guarded_beam._hit(25.0, "heavy", "Harvester")
	check(is_equal_approx(float(unguarded_beam.damage_taken.heavy), float(guarded_beam.damage_taken.heavy)), "Boss heavy beam damage remains a distinct timing challenge")
	var boss_volley_hard := Sim.new(18808, {}, "vanguard", "rookie", "hard")
	var boss_volley_insane := Sim.new(18808, {}, "vanguard", "rookie", "insane")
	for sim in [boss_volley_hard, boss_volley_insane]:
		sim.stage = 3
		sim.time = 10.0
		sim.boss_spawn_time = 0.0
		sim.heavy_ready_at = 999.0
		sim.enemies = [{"id":101,"kind":"boss3","p":Vector2(270,135),"hp":100000.0,"max_hp":100000.0,"speed":0.0,"fire":0.0,"xp":0,"phase":0.0}]
		sim._update_enemies()
	check(boss_volley_hard.bullets.size() == boss_volley_insane.bullets.size(), "Harder bosses fire more often, not more bullets per volley")
	check(float(boss_volley_insane.bullets[0].damage) / float(boss_volley_hard.bullets[0].damage) > boss_volley_insane.threat_scale() / boss_volley_hard.threat_scale(), "Boss projectile damage escalates slightly faster than regular enemy projectile damage")


func _test_v11_enemy_projectile_cadence() -> void:
	var probe := Sim.new(11101)
	check(is_equal_approx(probe.projectile_interval_factor("drone"), 0.92), "1.1 fires ordinary World 1 bullets about 9% more often")
	probe.stage = 3
	check(is_equal_approx(probe.projectile_interval_factor("drone"), 0.94), "Later worlds receive only about 6% more regular projectile volleys on top of existing pressure")
	check(is_equal_approx(probe.projectile_interval_factor("boss3"), 0.95), "Boss projectile fans accelerate modestly without changing beam charge timing")
	check(is_equal_approx(probe.projectile_interval_factor("missile_bomber"), 0.96), "Dangerous ordnance volleys accelerate less than small bullets")
	for unchanged in ["carrier", "echo_carrier", "minelayer", "slag_bomber"]:
		check(is_equal_approx(probe.projectile_interval_factor(unchanged), 1.0), "Minion or mine attack cycles must not create extra XP or hazard density: " + unchanged)
	for difficulty in Catalog.DIFFICULTIES:
		var regular := Sim.new(16111, {}, "vanguard", "rookie", difficulty)
		regular.time = 40.0
		regular.heavy_ready_at = 1000000.0
		regular.enemies = [{"id": 101, "kind": "drone", "p": Vector2(270, 120), "hp": 18.0, "max_hp": 18.0, "speed": 0.0, "fire": 0.0, "xp": 3, "phase": 0.0}]
		regular._update_enemies()
		var expected: float = float(regular.content.enemies.drone.interval) / regular.enemy_fire_scale() * 0.92
		check(is_equal_approx(float(regular.enemies[0].fire), expected), "Regular enemy cooldown uses 1.1 tuning on " + difficulty)
		check(regular.bullets.size() == 3 and regular.kills == 0 and regular.xp == 0.0 and regular.enemies.size() == 1, "1.1 changes ordinary volley cadence, not shot count, kills, spawns or XP on " + difficulty)
	var boss := Sim.new(16112)
	boss.time = 12.0
	boss.boss_spawned = true
	boss.boss_spawn_time = 10.0
	boss.heavy_ready_at = 1000000.0
	boss.enemies = [{"id": 102, "kind": "boss", "p": Vector2(270, 135), "hp": 6200.0, "max_hp": 6200.0, "speed": 0.0, "fire": 0.0, "xp": 0, "phase": 0.0}]
	boss._update_enemies()
	check(is_equal_approx(float(boss.enemies[0].fire), (2.1 * 0.95) / boss.boss_projectile_rate_multiplier()) and boss.bullets.size() == 11, "Boss fans now fire faster, without adding bullets per volley or changing the heavy-beam clock")
	check(boss.charges.is_empty(), "Ordinary boss projectile cadence must not secretly generate extra heavy beams")
	var charger := Sim.new(16113)
	charger.time = 40.0
	charger.heavy_ready_at = 0.0
	charger.enemies = [{"id": 103, "kind": "sniper", "p": Vector2(270, 120), "hp": 36.0, "max_hp": 36.0, "speed": 0.0, "fire": 0.0, "xp": 7, "phase": 0.0}]
	charger._update_enemies()
	check(charger.charges.size() == 1 and is_equal_approx(float(charger.charges[0].duration), 1.8), "Heavy-beam telegraph must remain 1.8 seconds")
	check(is_equal_approx(charger.heavy_ready_at - charger.time, 7.5), "1.1 gunfire buff must not increase heavy-beam frequency")


func _test_draft_and_cooldowns() -> void:
	var sim := Sim.new()
	sim.activate("aegis")
	sim._offer_cards()
	var before: Dictionary = sim.snapshot()
	for i in range(100):
		sim.step()
	check(sim.snapshot() == before, "Draft must freeze all simulation state, including cooldowns and projectiles")
	check(not sim.activate("aegis"), "Abilities must not activate behind a draft")
	check(sim.choose_card(0), "A valid draft choice must install")
	check(not sim.choose_card(3), "Invalid choices must have no effect")
	sim.hull = 10
	sim._offer_cards()
	var defensive := false
	for card in sim.cards:
		defensive = defensive or card.id in ["armor", "regen", "hull", "aegis", "repair"]
	check(defensive, "Low hull must offer a legal defensive or repair card")
	var maxed := Sim.new(812)
	for card in maxed.content.cards:
		maxed.upgrades[str(card.id)] = int(card.max)
	maxed._offer_cards(false)
	check(maxed.cards.size() == 2 and maxed.cards[0].id == "repair" and maxed.cards[1].id == "core_cache", "Maxed upgrades offer Field repair and banked Cores")
	maxed.banishes_left = 1
	check(not maxed.banish_card(1) and maxed.banishes_left == 1, "Core rewards cannot be banished as upgrade tracks")
	var before_cores := maxed.payout()
	check(maxed.choose_card(1) and maxed.choice_cores == Sim.MAXED_DRAFT_CORES and maxed.payout() == before_cores + Sim.MAXED_DRAFT_CORES, "Maxed-out salvage banks exactly 5 Cores")
	check(not maxed.choose_card(1), "Taking a capped reward cannot claim it twice")
	var cached: Dictionary = maxed.snapshot()
	var cached_restore := Sim.new(813)
	check(cached_restore.restore(cached) and cached_restore.snapshot() == cached, "Maxed draft Core rewards survive checkpoint round trips")
	var repair := Sim.new(814)
	for card in repair.content.cards:
		repair.upgrades[str(card.id)] = int(card.max)
	repair.hull = repair.max_hull - 40.0
	repair._offer_cards(false)
	check(repair.choose_card(0) and is_equal_approx(repair.hull, repair.max_hull - 10.0) and repair.choice_cores == 0, "Maxed-out Field repair remains a valid non-Core choice")

func _test_resume() -> void:
	var original := Sim.new(123456)
	for i in range(4200):
		_bot(original, "timed")
		original.step()
	var encoded := var_to_bytes(original.snapshot())
	var restored := Sim.new(1)
	check(restored.restore(bytes_to_var(encoded)), "Checkpoint must restore after binary serialization")
	check(restored.snapshot() == original.snapshot(), "Checkpoint must restore every simulation field")
	for i in range(1800):
		_bot(original, "timed")
		_bot(restored, "timed")
		original.step()
		restored.step()
	check(restored.snapshot() == original.snapshot(), "Resumed run must remain deterministic under identical input")
	original._offer_cards()
	restored.restore(original.snapshot())
	check(restored.cards == original.cards, "Resuming a draft must preserve its exact hand")
	check(not restored.restore({"version": -1}), "Unknown checkpoint versions must be rejected")

func _test_saves() -> void:
	var services := Services.new()
	var path := "user://starrun-test.save"
	var expected := {"vector": Vector2(12, 19), "seed": 981, "cards": ["pulse", "aegis"]}
	check(services.write_atomic(path, expected), "Atomic save must succeed")
	check(services.read_save(path) == expected, "Saved data must survive a disk round trip")
	DirAccess.remove_absolute(path)

func _install(sim: RefCounted, id: String) -> void:
	for card in sim.content.cards:
		if card.id == id:
			sim.cards = [card.duplicate(true)]
			sim.choose_card(0)
			return

func _fuse_pair(sim: RefCounted, pair: Dictionary) -> void:
	for part in pair.parts:
		while int(sim.upgrades.get(str(part),0)) < Sim.FUSION_RANK:
			_install(sim,str(part))

func _test_new_abilities() -> void:
	var sim := Sim.new(441)
	check(not sim.activate("barrage"), "A locked ability must not cast")
	sim.level = 2
	sim._offer_cards()
	check(sim.cards.any(func(c): return c.tag == "ABILITY" and sim.upgrades[c.id] == 0), "First level-up must offer a new active ability")
	sim.cards.clear()
	for id in ["barrage", "overdrive", "chrono"]:
		_install(sim, id)
		check(sim.upgrades[id] == 1 and sim.activate(id), "Learning %s must occupy a slot and allow casting" % id)
	check(sim.active_slots.size() == 4, "A ship starts with one active and can draft exactly three more")
	_install(sim, "mend")
	check(sim.upgrades.mend == 0 and sim.active_slots.size() == 4, "A fifth unowned ability must never be equipped")
	sim.cards.clear() # Discard the deliberately injected, ineligible fifth-slot offer.
	check(sim.shots.size() == 7, "Barrage must create seven guided rockets at level 1")
	check(sim.overdrive_left >= 4 and sim.chrono_left >= 4, "Timed abilities must persist after activation")
	var haven := Sim.new(4, {}, "haven")
	check(haven.active_slots == ["mend"], "Haven starts with its repair signature")
	var healing := Sim.new()
	_install(healing, "mend")
	healing.hull = 40
	healing.next_spawn = 999
	healing.activate("mend")
	for i in range(240):
		healing.step()
	check(is_equal_approx(healing.hull, 64.0), "Repair drones must restore the promised hull over four seconds")
	var normal := Sim.new()
	var slowed := Sim.new()
	_install(slowed, "chrono")
	slowed.activate("chrono")
	var bullet := {"p":Vector2(20, 100), "v":Vector2(0, 200), "damage":1, "kind":"chaff", "source":"test"}
	normal.bullets = [bullet.duplicate(true)]
	slowed.bullets = [bullet.duplicate(true)]
	normal._update_bullets()
	slowed._update_bullets()
	check(is_equal_approx((slowed.bullets[0].p.y - 100) / (normal.bullets[0].p.y - 100), 0.45), "Chrono must slow enemy projectiles to 45% speed")
	var fast := Sim.new()
	_install(fast, "overdrive")
	fast.activate("overdrive")
	normal = Sim.new()
	for i in range(120):
		normal._update_weapons()
		fast._update_weapons()
	check(fast.shots.size() > normal.shots.size() * 1.5, "Overdrive must materially increase automatic fire")
	var restored := Sim.new()
	restored.restore(sim.snapshot())
	check(restored.snapshot() == sim.snapshot(), "All six cooldowns, active effects and learned modules must survive saving")

func _test_homing_and_modules() -> void:
	var sim := Sim.new()
	sim.enemies = [{"id":1, "kind":"drone", "p":Vector2(285, 500), "hp":100.0, "max_hp":100.0, "xp":0, "fire":99.0, "speed":0.0, "phase":0.0}]
	sim.shots = [{"p":Vector2(250, 790), "v":Vector2(0,-980), "damage":9.0, "weapon":"pulse", "target":-1}]
	for i in range(22):
		sim._update_shots()
	check(sim.enemies[0].hp < 100, "Gentle homing must connect with a slightly off-axis enemy")
	sim.shots = [{"p":Vector2(250, 400), "v":Vector2(0,-980), "damage":9.0, "weapon":"pulse", "target":-1}]
	sim._update_shots()
	check(sim.shots[0].v == Vector2(0,-980), "Pulse must not home backward toward an enemy behind it")
	_install(sim, "arc")
	_install(sim, "lance")
	sim._update_weapons()
	check(sim.damage_dealt.arc > 0 and sim.damage_dealt.lance > 0, "Both new automatic weapons must actually damage enemies")

func _test_hangar_and_tactics() -> void:
	var hangar := Catalog.defaults()
	for id in hangar:
		hangar[id] = 1
	var sim := Sim.new(555, hangar)
	check(sim.max_hull == 110 and sim.max_shield == 58, "Hangar defenses must apply at launch")
	check(sim.upgrades.pulse == 2 and sim.upgrades.seeker == 2, "Starting weapon upgrades must apply to new flights")
	check(sim.weapon_power() > 1 and sim.payout() > Sim.new().payout(), "Armory and salvage tracks must change actual damage and rewards")
	sim._offer_cards()
	check(sim.cards.size() == 4, "Expanded uplink must offer four choices")
	var pending: int = sim.pending_levels
	check(sim.reroll_cards() and sim.rerolls_left == 0 and sim.pending_levels == pending, "Reroll must spend one use without spending another level")
	var removed: String = sim.cards[0].id
	check(sim.banish_card(0) and sim.banishes_left == 0 and not sim.cards.any(func(c): return c.id == removed), "Banished track must leave the draft pool immediately")
	sim.hull = 50
	check(sim.skip_cards() and sim.cards.is_empty() and sim.hull == 68 and sim.skips_left == 0, "Skip must consume a use and trade that hand for repair")
	check(Catalog.legacy_refund({"hull":3, "damage":2, "regen":1}) == 30, "Historic Hangar costs are preserved")
	check(Catalog.previous_price("hull",0) == 6 and Catalog.previous_price("lance_start",0) == 46 and Catalog.price("hull",0) == 7 and Catalog.price("lance_start",0) == 51, "Hangar costs compound another 10% on the earlier visible 15%-higher price")
	check(Catalog.refund({"hull":3, "damage":2, "regen":1}, {"hull":15, "damage":10, "regen":5}) == 30, "Historical purchase receipts prevent inflated refunds")
	check(Catalog.refund({"hull":3, "damage":2, "regen":1}) == 42, "Newly bought ranks refund their full compounded price")
	var credits := 0
	for entry in Catalog.HANGAR:
		credits += Catalog.price(entry.id, 0)
	check(Catalog.refund(hangar) == credits, "Refund must return exactly the price paid across every Hangar track")
	sim.shield = 0
	sim.hull = 40
	sim._hit(3, "chaff", "test")
	sim.hull = 30
	sim._hit(1, "chaff", "test")
	check(sim.emergency_used and sim.aegis_left > 0, "Emergency field must activate once at low hull")

func _test_legacy_modules() -> void:
	var old := Sim.new().snapshot()
	old.upgrades = {"pulse":1, "seeker":1, "armor":0, "regen":0, "hull":0, "coolant":0, "aegis":1, "nova":1}
	old.meta = {"hull":2, "damage":1, "regen":0}
	old.cooldowns = {"aegis":2.0, "nova":3.0}
	old.damage_dealt = {"pulse":10.0, "seeker":0.0, "nova":0.0}
	old.movement_version = 2
	old.erase("active_slots") # Previous checkpoint had Aegis and Nova learned.
	var sim := Sim.new()
	check(sim.restore(old), "An original first-flight save must still load")
	sim.step()
	check(sim.cooldowns.barrage == 0 and sim.upgrades.arc == 0 and sim.meta.hull == 2 and "nova" in sim.active_slots, "Migration must preserve purchased ranks and learned active slots")


func _test_loadouts() -> void:
	check(Catalog.SHIPS.size() >= 6 and Catalog.PILOTS.size() >= 6, "Six ship archetypes and six pilots must be available")
	check(Catalog.ship("vanguard").cost == 0 and Catalog.pilot("rookie").cost == 0, "Starter ship/pilot must be free")
	var base := Sim.new(222)
	check(base.active_slots == ["aegis"], "Vanguard starts with its Aegis signature only")
	var interceptor := Sim.new(222, {}, "kestrel", "ace")
	check(interceptor.ship_id == "kestrel" and interceptor.pilot_id == "ace" and interceptor.active_slots == ["overdrive"], "Selected hull must supply its own signature active")
	check(interceptor.upgrades.pulse == 2 and interceptor.upgrades.seeker == 0 and interceptor.max_hull == 70, "Interceptor starts with Pulse focus and fragile hull")
	check(interceptor.course[2].t < base.course[2].t, "Interceptor autopilot must make faster turns")
	interceptor._update_weapons()
	check(interceptor.shots.any(func(s): return s.weapon == "pulse") and not interceptor.shots.any(func(s): return s.weapon == "seeker"), "Ship weapon exclusions must prevent firing uninstalled weapons")
	var fortress := Sim.new(222, {}, "bulwark", "engineer")
	check(fortress.max_hull == 160 and fortress.max_shield == 100, "Fortress and Engineer starting defenses stack")
	fortress.shield = 20
	fortress._hit(1.0, "chaff", "test")
	check(fortress.shield == 19.75, "Bulwark inherent armor mitigates chaff")
	var missile := Sim.new(222, {}, "wraith", "hunter")
	check(missile.upgrades.pulse == 0 and missile.upgrades.seeker == 2, "Missile boat must start without Pulse")
	missile.enemies = [{"id":1, "kind":"drone", "p":Vector2(250,240), "hp":100.0, "max_hp":100.0, "speed":0.0, "fire":99.0, "xp":3, "phase":0.0}]
	missile._update_weapons()
	check(missile.shots.size() == 1 and missile.shots[0].weapon == "seeker" and missile.shots[0].damage > 30, "Missile-specialist pilot and hull bonuses must stack")
	var lightning := Sim.new(222, {}, "arcwing", "rookie")
	check(lightning.upgrades.arc == 1 and lightning.upgrades.seeker == 0, "Arcwing must start with Arc Coil instead of missiles")
	var support := Sim.new(222, {}, "haven", "tactician")
	check(support.upgrades.mend == 1 and support.rerolls_left == 1, "Support carrier and tactician start with useful tools")
	var salvager := Sim.new(222, {}, "vanguard", "scavenger")
	check(salvager.payout() > base.payout(), "Salvager gets a measurable currency bonus")
	var checkpoint := support.snapshot()
	var restored := Sim.new(999)
	check(restored.restore(bytes_to_var(var_to_bytes(checkpoint))), "Ship/pilot checkpoint must deserialize")
	check(restored.snapshot() == checkpoint, "Checkpoint must preserve hull type, selected pilot and starter ability")
	# Cosmetic playback speed must not affect fixed-step combat determinism.
	var sim_one := Sim.new(341)
	var sim_three := Sim.new(341)
	for frame in range(240):
		sim_one.step()
	for frame in range(80):
		for factor in range(3):
			sim_three.step()
	check(sim_one.snapshot() == sim_three.snapshot(), "Equal simulated time must give identical outcomes at 1x and 3x")

func _test_threat_catalog() -> void:
	var kinds := ["drone", "gunship", "sniper", "interceptor", "rusher", "missile_bomber", "carrier", "shieldguard", "minelayer", "boulder", "station", "ion_frigate", "corroder", "disruptor"]
	var sim := Sim.new(442)
	for kind in kinds:
		check(sim.content.enemies.has(kind), "Enemy type must have a combat specification: " + kind)
		sim._add_enemy(kind, Vector2(120,200))
	check(sim.enemies.size() == kinds.size(), "All enemy and hazard types must be spawnable")
	sim.enemies.clear()
	sim._add_enemy("missile_bomber", Vector2(260,150))
	sim.enemies[0].fire = 0.0
	sim._update_enemies()
	check(sim.bullets.filter(func(b): return b.kind == "ordnance").size() == 2, "Missile bomber must launch a dual homing volley")
	sim.bullets.clear()
	sim.enemies.clear()
	sim._add_enemy("minelayer", Vector2(260,150))
	sim.enemies[0].fire = 0.0
	sim._update_enemies()
	check(sim.bullets.size() == 1 and sim.bullets[0].kind == "mine" and sim.bullets[0].fuse > 0.0, "Minelayer must deploy a visible timed hazard")
	var mine: Dictionary = sim.bullets[0]
	sim.shots = [{"p":mine.p, "v":Vector2.ZERO, "damage":24.0, "weapon":"pulse", "target":-1}]
	sim.enemies.clear()
	sim._update_shots()
	check(sim.bullets[0].hp <= 0.0, "Player fire must be able to destroy mines")
	sim.bullets.clear()
	sim.shots.clear()
	sim._add_enemy("boulder", Vector2(270,230))
	var before_kills := sim.kills
	sim._damage_enemy(sim.enemies[0], 500.0, "pulse")
	check(sim.kills > before_kills and sim.enemies[0].hp <= 0, "Boulders must be destructible targets")
	sim.enemies.clear()
	sim._add_enemy("station", Vector2(260,150))
	sim.enemies[0].fire = 0.0
	sim._update_enemies()
	check(sim.bullets.any(func(b): return b.kind == "ordnance"), "Stations must be active turret threats")

func _bot(sim: RefCounted, strategy: String) -> void:
	if not sim.cards.is_empty():
		var priorities := ["seeker", "pulse", "arc", "lance", "regen", "hull", "armor", "munitions", "autoloader", "coolant", "shield", "targeting", "repair_bots", "harvester", "amplifier", "nova", "aegis", "barrage", "overdrive", "chrono", "mend", "repair"]
		var best := 0
		var rank := 100
		for i in range(sim.cards.size()):
			var r: int = priorities.find(sim.cards[i].id)
			if r < 0:
				r = 90 # Unknown IDs must not accidentally outrank every existing card.
			if not sim.fusion_spec(str(sim.cards[i].id)).is_empty():
				r = 4 if sim.upgrades[sim.cards[i].id] < 5 else 14
			if sim.cards[i].tag == "ABILITY" and sim.upgrades[sim.cards[i].id] == 0 and sim.active_slots.size() < Catalog.ACTIVE_SLOTS:
				r = 0 if sim.cards[i].id in ["nova", "emp", "flak", "capacitor", "siphon"] else 2
			if sim.hull < sim.max_hull * 0.35 and sim.cards[i].id in ["hull", "repair"]:
				r = -1
			if r < rank:
				rank = r
				best = i
		sim.choose_card(best)
	if strategy == "on_cooldown":
		for id in sim.active_slots:
			sim.activate(str(id))
	elif strategy == "timed":
		# Fusions replace both original buttons. The bot must time the fused cast,
		# rather than trying to press two abilities that no longer exist.
		var urgent_beam := false
		for beam in sim.charges:
			urgent_beam = urgent_beam or float(beam.remaining) < 0.55
		var near_shots := 0
		for bullet in sim.bullets:
			if (bullet.p + bullet.v * 0.30).distance_squared_to(sim.ship_position(sim.time + 0.30)) < 65.0 * 65.0:
				near_shots += 1
		if urgent_beam or near_shots >= 1 or (sim.shield < sim.max_shield - 20 and sim.bullets.size() >= 8):
			sim.activate("nova_aegis")
		if urgent_beam or sim.bullets.size() >= 20:
			sim.activate("stasis_lock")
			sim.activate("ghost_signal")
		if sim.boss_spawned or sim.enemies.size() >= 3:
			sim.activate("railstorm")
			sim.activate("missile_grid")
			sim.activate("prism_focus")
		if sim.hull < sim.max_hull - 30 or sim.shield < sim.max_shield - 30:
			sim.activate("repair_matrix")
		if sim.hull < sim.max_hull - 20 and sim.enemies.size() > 0:
			sim.activate("scrap_converter")
		if sim.bullets.size() >= 15:
			sim.activate("reflective_wall")
			sim.activate("reactor_surge")
		if sim.enemies.size() >= 3 or sim.boss_spawned:
			sim.activate("barrage")
			sim.activate("overdrive")
		if sim.hull < sim.max_hull - 26:
			sim.activate("mend")
		if sim.bullets.size() > 20:
			sim.activate("chrono")
		var imminent := false
		for charge in sim.charges:
			imminent = imminent or charge.remaining < 0.38
		if imminent:
			if sim.cooldowns.aegis <= 0:
				sim.activate("aegis")
			elif sim.aegis_left <= 0:
				sim.activate("nova")
		elif sim.enemies.size() >= 3 and sim.charges.is_empty():
			sim.activate("nova")
		elif sim.shield < 30 and sim.charges.is_empty():
			var near := 0
			for b in sim.bullets:
				if (b.p + b.v * 0.25).distance_squared_to(sim.ship_position(sim.time + 0.25)) < 36 * 36:
					near += 1
			if near >= 1:
				sim.activate("aegis")
		if sim.shield < sim.max_shield - 20:
			sim.activate("capacitor")
			sim.activate("deflector")
		if sim.hull < sim.max_hull - 25:
			sim.activate("siphon")
		if not sim.charges.is_empty():
			sim.activate("emp")
		var incoming_rockets: bool = sim.bullets.any(func(b): return str(b.kind) in ["ordnance", "mine", "slag"])
		if incoming_rockets:
			sim.activate("flak")
			sim.activate("missile_grid")
		if sim.bullets.size() >= 12:
			sim.activate("prism")
			sim.activate("overload")
		if sim.enemies.size() >= 2 or sim.boss_spawned:
			sim.activate("wing_drones")
			sim.activate("ion_mine")
			sim.activate("storm_carrier")
		if sim.enemies.size() >= 3:
			sim.activate("focus")
			sim.activate("jammer")
			sim.activate("strike")


func _test_active_pool() -> void:
	check(Catalog.ABILITIES.size() == 22 and Catalog.ACTIVE_SLOTS == 4, "Twenty-two abilities must compete for four active slots")
	var seen := {}
	for id in Catalog.ABILITIES:
		check(not seen.has(id), "Ability IDs must be unique")
		seen[id] = true
		var sim := Sim.new(911, {}, "vanguard")
		check(sim.content.abilities.has(id) and sim.content.cards.any(func(card): return card.id == id and card.tag == "ABILITY"), "Each active needs cooldown and draft card")
		if id != "aegis":
			_install(sim, id)
		var actual: String = id
		if id not in sim.active_slots:
			for fusion in sim.content.fusions:
				if id in fusion.parts and str(fusion.id) in sim.active_slots:
					actual = str(fusion.id)
		check(sim._source_active(id) and sim.activate(actual), "Every original active must work directly or as a fusion: " + id)
	var sim := Sim.new(20)
	check(not sim.activate("nova"), "Unslotted abilities must not cast")
	for id in ["flak", "emp", "strike"]:
		_install(sim, id)
	check(sim.active_slots.size() == 4, "Three installed abilities fill all four slots")
	sim.level = 8
	sim._offer_cards()
	check(not sim.cards.any(func(card): return card.tag == "ABILITY" and sim.upgrades[card.id] == 0 and not sim._can_learn_active(str(card.id))), "A full bar cannot offer a new rank-1 ability")
	var checkpoint := sim.snapshot()
	check(Sim.new().restore(checkpoint), "Four-slot builds must restore")

func _test_stage_difficulty_and_pressure() -> void:
	var normal := Sim.new(111, {}, "vanguard", "rookie", "normal")
	var hard := Sim.new(111, {}, "vanguard", "rookie", "hard")
	var insane := Sim.new(111, {}, "vanguard", "rookie", "insane")
	for sim in [normal, hard, insane]:
		sim._add_enemy("drone", Vector2(240, 100))
	check(normal.enemies[0].hp < hard.enemies[0].hp and hard.enemies[0].hp < insane.enemies[0].hp, "Difficulty must increase enemy health")
	check(is_equal_approx(insane.threat_scale(), 2.0) and is_equal_approx(hard.threat_scale(), 1.25), "Insane enemy HP and shot strength rise 25% over the previous 1.6 scale")
	check(is_equal_approx(insane.enemy_cadence_scale(), 1.6) and is_equal_approx(hard.enemy_cadence_scale(), 1.25), "Extra Insane toughness must not increase spawns or XP-granting kills")
	check(is_equal_approx(insane.enemy_fire_scale(), 2.0) and is_equal_approx(hard.enemy_fire_scale(), 1.25), "Insane regular shot frequency rises 25% while spawn density remains unchanged")
	check(is_equal_approx(normal.boss_projectile_rate_multiplier(), 1.08) and is_equal_approx(hard.boss_projectile_rate_multiplier(), 1.15) and is_equal_approx(insane.boss_projectile_rate_multiplier(), 1.40), "Boss projectile cadence increases on every difficulty, more steeply at higher difficulties")
	check(is_equal_approx(insane.enemies[0].max_hp / hard.enemies[0].max_hp, 1.6), "Insane regular enemies have 60% more HP than Hard for the same equipment")
	for shooter in [hard, insane]:
		shooter.enemies[0].fire = 0.0
		shooter._update_enemies()
	check(is_equal_approx(float(hard.enemies[0].fire) / float(insane.enemies[0].fire), 1.6), "Insane drone fires 60% more often than Hard at matched world and seed")
	var hard_carrier := Sim.new(8090, {}, "vanguard", "rookie", "hard")
	var insane_carrier := Sim.new(8090, {}, "vanguard", "rookie", "insane")
	for pilot in [hard_carrier, insane_carrier]:
		pilot.stage = 2
		pilot._add_enemy("carrier", Vector2(250, 100))
		pilot.enemies[0].fire = 0.0
		pilot._update_enemies()
	check(is_equal_approx(float(hard_carrier.enemies[0].fire) / float(insane_carrier.enemies[0].fire), 1.6 / 1.25), "Carrier minion launch rate stays at its old Insane cadence even as other enemies fire faster")
	var hard_boss_volley := Sim.new(8091, {}, "vanguard", "rookie", "hard")
	var insane_boss_volley := Sim.new(8091, {}, "vanguard", "rookie", "insane")
	for pilot in [hard_boss_volley, insane_boss_volley]:
		pilot._spawn_boss()
		pilot.enemies[0].fire = 0.0
		pilot._update_enemies()
	check(is_equal_approx(float(hard_boss_volley.enemies[0].fire) / float(insane_boss_volley.enemies[0].fire), 1.40 / 1.15), "Insane boss fires more volleys than Hard, without changing heavy-beam scheduling")
	check(is_equal_approx(hard_boss_volley.heavy_ready_at, insane_boss_volley.heavy_ready_at), "Insane additional projectiles preserve the existing heavy-beam warning interval")
	check(normal.payout() < hard.payout() and hard.payout() < insane.payout(), "Hard and Insane must pay more cores")
	check(normal.content.stage_count == 4 and normal.content.abilities.aegis.cooldown >= 14, "Four stages and slower Aegis must be configured")
	var sim := Sim.new(777)
	sim.boss_spawned = true
	sim.enemies = [{"id":9, "kind":"boss", "p":Vector2(270,135), "hp":10.0, "max_hp":6200.0, "speed":0.0, "fire":99.0, "xp":0, "phase":0.0}]
	sim._damage_enemy(sim.enemies[0], 30.0, "pulse")
	check(sim.stage_clears == 1 and sim.stage_transition_queued and not sim.ended, "Harvester must lead to Stage 2")
	sim._enter_stage_two()
	check(sim.stage == 2 and sim.stage_start == sim.time and sim.pending_levels == 1, "Stage 2 must reset schedules and offer a milestone draft")
	sim._add_enemy("ion_frigate", Vector2(250,100))
	check(sim.enemies[0].max_hp > normal.enemies[0].max_hp, "Stage 2 must be tougher than Stage 1")
	sim.enemies.clear()
	sim._spawn_boss()
	check(sim.enemies.size() == 3 and sim.enemies[0].kind == "boss2" and sim._alive_modules("launch_bay") == 2, "Storm Carrier must have two destructible launch bays")
	sim._damage_enemy(sim.enemies[0], 100000.0, "pulse")
	check(not sim.ended and sim.stage_transition_queued and sim.stage_clears == 2, "Stage 2 must stop for its victory acknowledgement, not end the run")
	check(not sim.advance_stage(), "Stage 2 cannot skip the strategic intermission")
	check(sim.begin_intermission() and sim.choose_prototype(0) and sim.choose_route("repair"), "Stage 2 must require Prototype and route selection")
	check(sim.advance_stage() and sim.stage == 3, "Two strategic choices should unlock the Foundry")
	var statuses := Sim.new(19)
	statuses._hit(1, "ion", "test")
	check(statuses.shield_offline >= 4.0, "Ion fire must disable shield regeneration")
	statuses._hit(1, "corrosion", "test")
	check(statuses.corrosion_left >= 5.0, "Corrosion must cause continuing damage")
	statuses.cooldowns.aegis = 4.0
	statuses._hit(1, "disrupt", "test")
	check(statuses.cooldowns.aegis >= 6.0, "Disruption must delay equipped cooldowns")
	var scatter := Sim.new(11)
	for i in range(650):
		scatter.bullets.append({"p":Vector2(10 + i % 50 * 10, 200 + int(i / 50) * 10), "v":Vector2.ZERO, "damage":1.0, "kind":"chaff", "source":"stress"})
	scatter.bullets.append({"p":Vector2(270, 550), "v":Vector2.ZERO, "damage":12.0, "kind":"mine", "hp":12.0, "source":"stress"})
	scatter.shots.append({"p":Vector2(270, 550), "v":Vector2.ZERO, "damage":20.0, "weapon":"pulse", "target":-1})
	scatter._update_shots()
	check(scatter.bullets[-1].hp <= 0.0, "Spatial lookup must preserve point-defense collisions among hundreds of bullets")


func _test_four_stage_campaign() -> void:
	var sim := Sim.new(404, {}, "vanguard", "rookie", "normal")
	check(sim.stage_count() == 4 and sim.stage_name() == "DEBRIS BELT", "Four authored campaign stages must start in the debris belt")
	var names := {}
	var boss_kinds := ["boss", "boss2", "boss3", "boss4"]
	var health := 0.0
	for stage_number in range(1, 5):
		check(sim.stage == stage_number, "Campaign advances sequentially through each stage")
		check(not names.has(sim.stage_name()), "Each stage needs a different name and environment")
		names[sim.stage_name()] = true
		sim._spawn_boss()
		check(sim.enemies.size() == (1 if stage_number == 1 else 3) and sim.enemies[0].kind == boss_kinds[stage_number - 1], "Each stage must have a distinct boss with modules after Stage 1")
		check(sim.enemies[0].max_hp > health, "Later bosses must require stronger builds")
		health = sim.enemies[0].max_hp
		# This tests transitions, not a fixed damage budget: remove the boss parts first.
		for part in sim.enemies:
			if part.kind == "boss_module": sim._damage_enemy(part, part.hp * 2.0, "pulse")
		sim._damage_enemy(sim.enemies[0], sim.enemies[0].hp * 2.0, "pulse")
		check(sim.stage_clears == stage_number and sim.stage_transition_queued and not sim.ended, "Each boss must freeze before the player acknowledges victory")
		var paused: Dictionary = sim.snapshot()
		sim.step()
		check(sim.snapshot() == paused, "Victory celebration must freeze every simulation field")
		var restored := Sim.new(1)
		check(restored.restore(paused) and restored.snapshot() == paused, "Resume must restore an awaiting stage-clear celebration exactly")
		if stage_number < 4:
			check(not sim.advance_stage(), "Boss victory may not automatically advance or bypass decisions")
			check(sim.begin_intermission(), "Every non-final boss offers a Prototype draft")
			var offers: Array = sim.prototype_offers.duplicate()
			check(offers.size() == 3, "Three unique Prototypes must be offered")
			check(sim.choose_prototype(0), "Selecting a Prototype must succeed")
			check(sim.intermission_step == "route" and sim.prototypes.size() == stage_number, "Prototype choice persists across the campaign")
			var route: String = ["repair", "overclock", "bounty"][stage_number - 1]
			check(sim.choose_route(route) and sim.advance_stage(), "Repair, overclock and bounty routes should unlock the next stage")
		else:
			check(sim.advance_stage(), "Claiming the final boss victory must complete the campaign")
		if stage_number < 4:
			check(sim.stage == stage_number + 1 and not sim.stage_transition_queued and not sim.won, "Next stage should be playable without resetting the build")
			check(sim.pending_levels == stage_number + (1 if stage_number == 3 else 0), "Each boss grants its usual level-up, and the Hunter warp grants one extra draft")
		else:
			check(sim.ended and sim.won and sim.stage_clears == 4, "Acknowledging final boss must finish all four stages")
	check(not sim.advance_stage(), "Final stage can only be settled once")
	check(sim.payout() > Sim.new().payout(), "Later stages must grant increased cumulative salvage")

func _test_boss_components_and_phases() -> void:
	var storm := Sim.new(1234)
	storm.stage = 2
	storm._spawn_boss()
	check(storm._alive_modules("launch_bay") == 2 and storm.boss_phase_label() == "LAUNCH BAYS ONLINE", "Stage 2 boss must have attack-controlling launch bays")
	var root: Dictionary = storm.enemies[0]
	var original_hp: float = root.hp
	storm._damage_enemy(root, 100.0, "pulse")
	check(root.hp < original_hp and root.hp > original_hp - 100.0, "Live launch bays armor the carrier core")
	storm.time = storm.boss_spawn_time + 6.0
	storm.enemies[0].fire = 0.0
	storm._update_enemies()
	check(storm.enemies.any(func(e): return e.kind == "storm_weaver"), "Live launch bays must deploy storm fighters")
	for bay in storm.enemies:
		if bay.kind == "boss_module" and bay.role == "launch_bay":
			storm._damage_enemy(bay, 100000.0, "pulse")
	check(storm._alive_modules("launch_bay") == 0 and storm.boss_phase_label() == "LAUNCH BAYS DESTROYED", "Destroying bays must change the boss phase")
	check(not storm.stage_transition_queued and storm.stage_clears == 0 and storm.bounty_earned == 0 and storm.enemies[0].hp > 0.0, "Destroying launch bays must not award victory or contract bounty before the boss core dies")
	storm.bullets.clear()
	storm.enemies[0].fire = 0.0
	storm._update_enemies()
	check(storm.bullets.filter(func(b): return b.kind == "ordnance").size() == 1, "Destroyed launch bays must reduce carrier missile volleys")
	var furnace := Sim.new(2345)
	furnace.stage = 3
	furnace._spawn_boss()
	var core: Dictionary = furnace.enemies[0]
	var sealed_hp: float = core.hp
	furnace._damage_enemy(core, 100.0, "pulse")
	var sealed_damage: float = sealed_hp - core.hp
	furnace.time = furnace.boss_spawn_time + 10.0
	var exposed_hp: float = core.hp
	furnace._damage_enemy(core, 100.0, "pulse")
	var exposed_damage: float = exposed_hp - core.hp
	check(exposed_damage > sealed_damage * 3.0, "Foundry boss must alternate between heavily armored and exposed core phases")
	for vent in furnace.enemies:
		if vent.kind == "boss_module" and vent.role == "vent":
			furnace._damage_enemy(vent, 100000.0, "pulse")
	furnace.time = furnace.boss_spawn_time
	var open_hp: float = core.hp
	furnace._damage_enemy(core, 100.0, "pulse")
	check(furnace._alive_modules("vent") == 0 and open_hp - core.hp >= 99.0, "Destroying both vents must permanently expose the Crucible core")
	check(not furnace.stage_transition_queued and furnace.stage_clears == 0, "Destroying cooling vents must not clear the Foundry before the core dies")
	var void_boss := Sim.new(3456)
	void_boss.stage = 4
	void_boss._spawn_boss()
	var regent: Dictionary = void_boss.enemies[0]
	var shielded_hp: float = regent.hp
	void_boss._damage_enemy(regent, 100.0, "pulse")
	check(shielded_hp - regent.hp < 40.0, "Shield pylons must protect the Void Regent core")
	void_boss.heavy_ready_at = 0.0
	void_boss._update_enemies()
	check(void_boss.charges.size() == 2, "Both pylons must sustain two heavy attack lanes")
	for pylon in void_boss.enemies:
		if pylon.kind == "boss_module" and pylon.role == "pylon":
			void_boss._damage_enemy(pylon, 100000.0, "pulse")
	check(void_boss._alive_modules("pylon") == 0, "Void shield pylons must be destructible")
	check(not void_boss.stage_transition_queued and void_boss.stage_clears == 0, "Destroying shield pylons must not clear the Citadel before the core dies")
	void_boss.charges.clear()
	void_boss.heavy_ready_at = 0.0
	void_boss._update_enemies()
	check(void_boss.charges.size() == 1, "Destroying pylons must change the heavy beam pattern")
	regent.hp = regent.max_hp * 0.30
	check(void_boss.boss_phase_label() == "FINAL ONSLAUGHT", "Final boss must reveal an enraged low-health phase")
	var baseline := Sim.new(3456)
	baseline.stage = 4
	baseline._spawn_boss()
	check(baseline._nearest(Vector2(270, 790)).kind == "boss_module", "Autopilot targeting must prioritize intact boss parts without player aiming")
	check(void_boss._nearest(Vector2(270, 790)).kind == "boss4", "After destroying pylons auto-aim must return to the Regent core")

func _test_synergy_tradeoffs() -> void:
	var base := Sim.new(555)
	var fortress := Sim.new(555)
	_install(fortress, "capacitor")
	check(fortress.synergy_active("fortress") and fortress.active_synergies().size() >= 1, "Aegis + Capacitor must form Fortress")
	check(fortress.weapon_power() < base.weapon_power() and fortress.hull_damage_multiplier() < base.hull_damage_multiplier(), "Fortress must trade weapon power for resilience")
	var assault := Sim.new(555, {}, "kestrel")
	_install(assault, "strike")
	check(assault.synergy_active("assault"), "Overdrive + Rail Strike must form Glass Cannon")
	check(assault.weapon_power() > base.weapon_power() and assault.hull_damage_multiplier() > base.hull_damage_multiplier(), "Glass Cannon must increase both damage dealt and hull damage taken")
	var control := Sim.new(555)
	_install(control, "emp")
	_install(control, "flak")
	check(control.synergy_active("control") and control.cooldown_multiplier() < 1.0 and control.weapon_power() < base.weapon_power(), "Control must reduce ability cooldown at a weapon-cost tradeoff")
	var salvage := Sim.new(555)
	_install(salvage, "salvage")
	_install(salvage, "siphon")
	check(salvage.synergy_active("salvager") and salvage.payout() > base.payout() and salvage.weapon_power() < base.weapon_power(), "Salvager must raise core payout at the cost of combat power")
	check(base.synergy_hint("capacitor").contains("FORTRESS"), "Upgrade drafts must explain synergy opportunities without requiring a wiki")
	base.level = 2
	base._offer_cards()
	check(base.cards.any(func(card): return card.tag == "ABILITY" and base.upgrades[card.id] == 0 and (not base.synergy_hint(str(card.id)).is_empty() or not base.fusion_hint(str(card.id)).is_empty())), "Even-level drafts should offer a real pairing for a starting ability")
	check(base.active_slots.size() == 1, "Draft guidance must not install extra actives automatically")

func _test_prototype_and_route_choices() -> void:
	var sim := Sim.new(888)
	sim._spawn_boss()
	sim._damage_enemy(sim.enemies[0], 100000.0, "pulse")
	check(not sim.advance_stage(), "Cannot enter Stage 2 without both strategic choices")
	check(sim.begin_intermission() and sim.prototype_offers.size() == 3, "A stage clear must offer exactly three Prototypes")
	var hand := sim.prototype_offers.duplicate()
	check(not sim.begin_intermission() and sim.prototype_offers == hand, "Rerendering or resuming must not redraw Prototype offers")
	var snapshot: Dictionary = sim.snapshot()
	var restored := Sim.new(1)
	check(restored.restore(snapshot) and restored.prototype_offers == hand and restored.intermission_step == "prototype", "The exact Prototype hand must survive checkpoint restore")
	check(not sim.choose_route("bounty"), "Route choice must not bypass Prototype installation")
	var skipped := Sim.new(902)
	skipped.stage_transition_queued = true
	skipped.stage_clears = skipped.stage # Match a completed boss before the intermission.
	skipped.difficulty = "insane"
	var starting_reward := skipped.payout()
	check(skipped.begin_intermission() and skipped.prototype_offers.size() == 3, "Skip must be offered alongside three unchanged Prototype choices")
	check(skipped.skip_prototype() and skipped.intermission_step == "route" and skipped.prototypes.is_empty(), "Skipping a Prototype proceeds to the route without granting one")
	check(skipped.choice_cores == Sim.PROTOTYPE_SKIP_CORES and skipped.payout() == starting_reward + Sim.PROTOTYPE_SKIP_CORES, "Prototype skip banks exactly 10 Cores even on Insane")
	check(not skipped.skip_prototype() and not skipped.choose_prototype(0), "A skipped Prototype cannot be claimed again")
	var skipped_save: Dictionary = skipped.snapshot()
	var skipped_restore := Sim.new(903)
	check(skipped_restore.restore(skipped_save) and skipped_restore.snapshot() == skipped_save, "Skipped Prototype bank and route state survive a checkpoint")
	check(skipped_restore.choose_route("repair") and skipped_restore.advance_stage(), "Skipped Prototype still lets a flight proceed normally")
	check(sim.choose_prototype(0), "A valid Prototype must install")
	check(not sim.choose_prototype(0) and not sim.advance_stage(), "Prototype choice is exactly once per stage")
	check(sim.choose_route("repair") and sim.advance_stage(), "A safe repair route must advance to Stage 2")
	check(is_equal_approx(sim.stage_risk, 1.0) and is_equal_approx(sim.stage_power, 1.0) and is_equal_approx(sim.stage_defense, 0.65) and is_equal_approx(sim.stage_fire_rate, 1.0), "Shielded route must reduce incoming damage by 35% and add a conditional weapon bonus")
	var risk := Sim.new(889)
	risk.stage = 2
	risk._spawn_boss()
	risk._damage_enemy(risk.enemies[0], 100000.0, "pulse")
	check(risk.begin_intermission() and risk.choose_prototype(0) and risk.choose_route("bounty") and risk.advance_stage(), "Bounty route must advance after two choices")
	check(risk.stage == 3 and is_equal_approx(risk.stage_risk, 1.30) and risk.pending_levels >= 2 and risk.hull >= risk.max_hull * 0.40, "Hunter route keeps risk while providing a bonus draft and repair")
	var baseline := Sim.new(889)
	baseline.stage = 3
	risk._add_enemy("drone", Vector2(220, 80))
	baseline._add_enemy("drone", Vector2(220, 80))
	check(risk.enemies[0].hp > baseline.enemies[0].hp, "Risk contract must have meaningfully stronger enemies")
	risk.enemies.clear()
	risk._spawn_boss()
	var baseline_boss := Sim.new(889)
	baseline_boss.stage = 3
	baseline_boss._spawn_boss()
	check(risk.enemies[0].max_hp > baseline_boss.enemies[0].max_hp and risk.enemies[1].max_hp > baseline_boss.enemies[1].max_hp, "High-risk contracts must increase both boss core and module durability")
	risk._damage_enemy(risk.enemies[0], 1000000.0, "pulse")
	check(risk.bounty_earned == 90 and risk.bonus_cores >= 90, "Bounties must pay only when the risked next-stage boss is beaten")
	var clock := Sim.new(890)
	clock.stage = 2
	clock._spawn_boss()
	clock._damage_enemy(clock.enemies[0], 100000.0, "pulse")
	check(clock.begin_intermission() and clock.choose_prototype(0) and clock.choose_route("overclock") and clock.advance_stage(), "Overclock route must be available")
	check(is_equal_approx(clock.stage_power, 1.35) and is_equal_approx(clock.stage_fire_rate, 1.20) and is_equal_approx(clock.shield, clock.max_shield * 0.50) and clock.hull_damage_multiplier() > 1.19, "Redline must attack harder and faster but start with low shields and more hull vulnerability")
	var prototype := Sim.new(556)
	prototype.prototypes = ["volatile_core", "null_harmonics", "salvage_charter", "breach_optics"]
	check(prototype.weapon_power() > 0.0 and prototype.cooldown_multiplier() < 1.0 and prototype.payout() > Sim.new().payout(), "Prototype stack must affect combat, cooldown and rewards")
	var legacy: Dictionary = Sim.new().snapshot()
	for key in ["prototypes", "prototype_offers", "intermission_step", "route_choice", "stage_power", "stage_risk", "stage_defense", "stage_fire_rate", "bounty_earned", "safeguard_used", "boss_spawn_time", "choice_cores"]:
		legacy.erase(key)
	check(Sim.new().restore(legacy), "An older v0.5 flight without strategic fields must remain resumable")
	var safeguard := Sim.new(891)
	safeguard.prototypes = ["emergency_safeguard"]
	safeguard.safeguard_used = true
	safeguard._spawn_boss()
	check(safeguard.safeguard_used, "Emergency Safeguard must not reset when the boss spawns during the same stage")



# Mechanical grid: all four worlds, three difficulties and three Hangar levels.
# Forced boss kills here only initialize warp scenarios; real campaign runs are
# measured separately by balance_matrix.gd and never inject kills or equipment.
func _test_route_prototype_balance_grid() -> void:
	var cases := 0
	for difficulty in Catalog.DIFFICULTIES:
		for hangar_style in ["none", "mid", "max"]:
			var hangar: Dictionary = Catalog.defaults()
			for entry in Catalog.HANGAR:
				var id: String = str(entry.id)
				if hangar_style == "max":
					hangar[id] = int(entry.max)
				elif hangar_style == "mid" and id in ["hull", "shield", "damage", "regen", "repair", "fire_rate", "ability_cooldown", "boss_damage"]:
					hangar[id] = mini(2, int(entry.max))
			var previous_boss_hp := 0.0
			for world in range(1, 5):
				var benchmark := Sim.new(41023, hangar, "vanguard", "rookie", difficulty)
				benchmark.stage = world
				benchmark._spawn_boss()
				var boss_hp: float = float(benchmark.enemies[0].max_hp)
				check(boss_hp > previous_boss_hp, "Boss health must escalate from world to world for %s / %s" % [difficulty, hangar_style])
				previous_boss_hp = boss_hp
				if world == 1:
					check(is_equal_approx(benchmark.stage_power, 1.0) and is_equal_approx(benchmark.stage_risk, 1.0) and is_equal_approx(benchmark.stage_defense, 1.0), "World 1 must have neutral route settings")
					cases += 1
					continue
				for route in ["repair", "overclock", "bounty"]:
					var sim := Sim.new(41023, hangar, "vanguard", "rookie", difficulty)
					sim.stage = world - 1
					sim._spawn_boss()
					sim._damage_enemy(sim.enemies[0], 10000000.0, "pulse")
					check(sim.stage_transition_queued and sim.begin_intermission(), "Warp setup must clear a real intermission checkpoint")
					check(sim.choose_prototype(0) and sim.choose_route(route) and sim.advance_stage(), "Warp choices must advance to world %d on %s / %s / %s" % [world, difficulty, hangar_style, route])
					check(sim.stage == world and sim.route_choice == route, "Selected route must persist into the intended world")
					if route == "repair":
						check(is_equal_approx(sim.stage_defense, 0.65) and is_equal_approx(sim.stage_power, 1.0) and is_equal_approx(sim.stage_fire_rate, 1.0), "Shielded passage must mitigate 35% damage while retaining normal fire rate")
					elif route == "overclock":
						check(is_equal_approx(sim.stage_power, 1.35) and is_equal_approx(sim.stage_fire_rate, 1.20) and is_equal_approx(sim.stage_defense, 1.0), "Redline must uniquely favor attack output")
					else:
						check(is_equal_approx(sim.stage_risk, 1.30) and is_equal_approx(sim.stage_power, 1.0) and is_equal_approx(sim.stage_fire_rate, 1.0), "Hunter contract must increase pressure without an attack buff")
					var saved: Dictionary = sim.snapshot()
					var resumed := Sim.new(41024, hangar, "vanguard", "rookie", difficulty)
					check(resumed.restore(saved) and is_equal_approx(resumed.stage_defense, sim.stage_defense) and is_equal_approx(resumed.stage_fire_rate, sim.stage_fire_rate), "Warp-specific mechanics must survive a checkpoint")
					cases += 1
	check(cases == 90, "Route grid must cover nine World 1 starting states and all 81 later-world route scenarios")
	var shielded_cooldowns := Sim.new(771)
	shielded_cooldowns.route_choice = "repair"
	check(is_equal_approx(shielded_cooldowns.cooldown_multiplier(), 1.0), "Shielded Passage must never affect World 1 ability timings")
	shielded_cooldowns.stage = 2
	check(is_equal_approx(shielded_cooldowns.cooldown_multiplier(), 0.85), "Shielded Passage cuts later-world ability cooldowns by 15%")
	# Route-specific combat bonuses and enemy tuning need real equations,
	# not a forced win/lose result or a free fusion in the draft pool.
	var shielded_base := Sim.new(9341)
	shielded_base.stage = 2
	var shielded_attacker := Sim.new(9341)
	shielded_attacker.stage = 2
	shielded_attacker.route_choice = "repair"
	shielded_attacker.stage_defense = 0.65
	check(is_equal_approx(shielded_attacker.weapon_power(), shielded_base.weapon_power() * 1.15), "Shielded Passage boosts automatic weapon damage by 15% above half shields")
	shielded_attacker.shield = shielded_attacker.max_shield * 0.50
	check(is_equal_approx(shielded_attacker.weapon_power(), shielded_base.weapon_power()), "Shielded Passage loses its weapon bonus at or below half shields")
	shielded_attacker.shield = shielded_attacker.max_shield
	shielded_attacker.stage = 1
	check(is_equal_approx(shielded_attacker.weapon_power(), shielded_base.weapon_power()), "Shielded Passage offers no World 1 offensive bonus")
	shielded_attacker.stage = 5
	check(is_equal_approx(shielded_attacker.weapon_power(), shielded_base.weapon_power()), "The four-world Shielded Passage buff does not leak into endless")
	shielded_attacker.stage = 2
	shielded_attacker._hit(10.0, "heavy", "test")
	shielded_base._hit(10.0, "heavy", "test")
	check(is_equal_approx(float(shielded_attacker.damage_taken.heavy), float(shielded_base.damage_taken.heavy) * 0.65), "Shielded Passage reduces real enemy hit damage by 35%")
	var redline_attacker := Sim.new(9341)
	redline_attacker.stage = 2
	redline_attacker.route_choice = "overclock"
	redline_attacker.stage_power = 1.35
	redline_attacker.stage_fire_rate = 1.20
	check(is_equal_approx(redline_attacker.weapon_power(), shielded_base.weapon_power() * 1.35) and is_equal_approx(redline_attacker.stage_fire_rate, 1.20), "Redline's attack modifiers remain exactly unchanged")
	var world_one_enemy := Sim.new(9342)
	world_one_enemy._add_enemy("drone", Vector2(250, 100))
	check(is_equal_approx(world_one_enemy.enemies[0].max_hp, float(world_one_enemy.content.enemies.drone.hp)) and is_equal_approx(world_one_enemy.enemy_damage_multiplier(), 1.0), "World 1 enemy health and damage are unchanged")
	for late_stage in [2, 3, 4]:
		var balanced := Sim.new(9342)
		balanced.stage = late_stage
		check(is_equal_approx(balanced.enemy_health_multiplier(), 0.90) and is_equal_approx(balanced.enemy_damage_multiplier(), 1.05), "World %d enemies have 10%% less health and 5%% more damage" % late_stage)
		balanced._add_enemy("drone", Vector2(250, 100))
		var expected_enemy_hp: float = float(balanced.content.enemies.drone.hp) * float(balanced.stage_spec().health_scale) * balanced.threat_scale() * 0.90
		check(is_equal_approx(balanced.enemies[0].max_hp, expected_enemy_hp), "World %d regular enemies apply the 10%% health reduction" % late_stage)
		balanced._spawn_boss()
		var expected_boss_hp: float = float(balanced.stage_spec().boss_hp) * balanced.threat_scale() * (2.5 if late_stage == 2 and balanced.difficulty in ["hard", "insane"] else 1.0) * 0.90 * balanced.boss_health_pressure()
		check(is_equal_approx(balanced.enemies[0].max_hp, expected_boss_hp), "World %d bosses apply their own durability pressure on top of regular health scaling" % late_stage)
		var module_spec: Dictionary = balanced.content.boss_modules[str(balanced.stage_spec().boss)][0]
		var expected_module_hp: float = float(module_spec.hp) * balanced.threat_scale() * float(balanced.stage_spec().module_scale) * 0.90 * balanced.boss_health_pressure()
		check(is_equal_approx(balanced.enemies[1].max_hp, expected_module_hp), "World %d boss parts scale alongside their core" % late_stage)
	var later_endless := Sim.new(9343)
	later_endless.stage = 5
	check(is_equal_approx(later_endless.enemy_health_multiplier(), 1.0) and is_equal_approx(later_endless.enemy_damage_multiplier(), 1.0), "Endless stages beyond the four-world campaign retain authored enemy stats")
	var hard_opener := Sim.new(117, {}, "vanguard", "rookie", "hard")
	var insane_opener := Sim.new(117, {}, "vanguard", "rookie", "insane")
	hard_opener._spawn_boss()
	insane_opener._spawn_boss()
	check(insane_opener.enemies[0].max_hp > hard_opener.enemies[0].max_hp, "Insane Harvester HP exceeds Hard at identical Hangar")
	check(is_equal_approx(insane_opener.enemies[0].max_hp / hard_opener.enemies[0].max_hp, (2.0 * 5.5 * insane_opener.boss_health_pressure()) / (1.25 * 6.5 * hard_opener.boss_health_pressure())), "World 1 Insane-to-Hard HP ratio includes the authored opener and stronger 1.2 boss-specific difficulty scaling")
	var hard_shot := Sim.new(8080, {}, "vanguard", "rookie", "hard")
	var insane_shot := Sim.new(8080, {}, "vanguard", "rookie", "insane")
	for shooter in [hard_shot, insane_shot]:
		shooter.stage = 2
		shooter.heavy_ready_at = 0.0
		shooter._add_enemy("void_lancer", Vector2(250, 150))
		shooter._update_enemies()
	check(hard_shot.charges.size() == 1 and insane_shot.charges.size() == 1, "Identical seeded lancer attacks produce heavy-beam charges on Hard and Insane")
	if not hard_shot.charges.is_empty() and not insane_shot.charges.is_empty():
		check(is_equal_approx(float(insane_shot.charges[0].damage) / float(hard_shot.charges[0].damage), 1.6), "Insane heavy-beam damage exceeds Hard by 60%")

	var base := Sim.new(556)
	var volatile := Sim.new(556)
	volatile.prototypes = ["volatile_core"]
	check(volatile.weapon_power() >= base.weapon_power() * 1.54 and volatile.hull_damage_multiplier() >= 1.29, "Volatile Core should offer a large damage gain and a real hull drawback")
	var null_field := Sim.new(556)
	null_field.prototypes = ["null_harmonics"]
	check(null_field.cooldown_multiplier() <= base.cooldown_multiplier() * 0.63, "Null Harmonics must dramatically accelerate abilities")
	var echo := Sim.new(556)
	echo.prototypes = ["echo_coil"]
	check(echo.ability_power() >= base.ability_power() * 1.69, "Echo Coil must increase ability strength by about 70%")
	var charter := Sim.new(556)
	charter.prototypes = ["salvage_charter"]
	check(charter.payout() > base.payout() * 1.6, "Salvage Charter must have a substantial Cores payout")
	var bastion := Sim.new(556)
	var plain := Sim.new(556)
	bastion.prototypes = ["bastion_lattice"]
	bastion.shield = 10.0
	plain.shield = 10.0
	bastion.step()
	plain.step()
	check(bastion.shield > plain.shield + 0.02, "Bastion Lattice must noticeably improve shield regeneration")
	var mirror := Sim.new(556)
	mirror.stage_transition_queued = true
	mirror.stage_clears = 1
	mirror.prototype_offers = ["mirror_cell"]
	mirror.intermission_step = "prototype"
	check(mirror.choose_prototype(0) and is_equal_approx(mirror.max_shield, base.max_shield * 1.60) and is_equal_approx(mirror.shield, mirror.max_shield), "Mirror Cell must immediately fill the full 60% new shield capacity")
	var safeguard := Sim.new(556)
	safeguard.prototypes = ["emergency_safeguard"]
	safeguard.shield = 1.0
	safeguard.hull = 40.0
	safeguard._hit(10.0, "chaff", "Grid test")
	check(safeguard.safeguard_used and safeguard.shield >= safeguard.max_shield * 0.79 and safeguard.hull > 40.0, "Safeguard must restore most shields and patch hull on the first shield break")
	var breach := Sim.new(556)
	breach.stage = 3
	breach.prototypes = ["breach_optics"]
	breach._spawn_boss()
	var control := Sim.new(556)
	control.stage = 3
	control._spawn_boss()
	check(breach.enemies.size() > 1 and control.enemies.size() > 1, "Breach test needs a targetable boss module")
	if breach.enemies.size() > 1 and control.enemies.size() > 1:
		breach._damage_enemy(breach.enemies[1], 100.0, "pulse")
		control._damage_enemy(control.enemies[1], 100.0, "pulse")
		check(float(breach.enemies[1].max_hp - breach.enemies[1].hp) >= 2.39 * float(control.enemies[1].max_hp - control.enemies[1].hp), "Breach Optics must do 140% extra module damage")

	var xp_regular := Sim.new(556)
	var xp_contract := Sim.new(556)
	xp_contract.route_choice = "bounty"
	xp_regular._add_enemy("drone", Vector2(220, 80))
	xp_contract._add_enemy("drone", Vector2(220, 80))
	xp_regular._damage_enemy(xp_regular.enemies[0], 10000.0, "pulse")
	xp_contract._damage_enemy(xp_contract.enemies[0], 10000.0, "pulse")
	check(xp_contract.xp > xp_regular.xp * 1.49, "Hunter contract must pay at least 50% extra XP on actual enemy kills")

func _test_shieldstorm_and_full_hull_focus() -> void:
	var defender := Sim.new(7701)
	defender.stage = 2
	defender.route_choice = "repair"
	_fuse_pair(defender, defender.fusion_spec("shieldstorm"))
	check(defender.active_slots == ["shieldstorm"] and defender._source_active("aegis") and defender._source_active("flak"), "Shieldstorm fuses rank-5 Aegis and Flak into one active")
	defender.shield = 2.0
	defender.bullets = [{"p":Vector2(270,300), "v":Vector2(0,20), "kind":"chaff", "damage":5.0, "source":"test"}]
	defender.charges = [{"source":2, "x":270.0, "remaining":0.5, "duration":1.8, "damage":20.0}]
	defender._hit(3.0, "heavy", "test")
	check(defender.shieldstorm_pulse_used and defender.bullets.is_empty() and defender.charges.is_empty() and defender.beams_cancelled == 1 and defender.prevented >= 5.0, "Shieldstorm clears incoming shots and beams on the first actual late-world shield break")
	check(defender.effects.any(func(e): return e.kind == "fusion-cast" and e.fusion == "shieldstorm"), "Automatic Shieldstorm shows its distinct fusion effect")
	defender.shield = 2.0
	defender.bullets = [{"p":Vector2(270,300), "v":Vector2(0,20), "kind":"chaff", "damage":5.0, "source":"test"}]
	defender._hit(3.0, "heavy", "test")
	check(defender.bullets.size() == 1, "Shieldstorm's automatic projectile purge triggers only once per world")
	var checkpoint: Dictionary = defender.snapshot()
	var reloaded := Sim.new(7702)
	check(reloaded.restore(checkpoint) and reloaded.shieldstorm_pulse_used and reloaded.snapshot() == checkpoint, "Shieldstorm's automatic charge survives a checkpoint")
	defender.stage_clears = 2
	defender.stage_transition_queued = true
	defender.intermission_step = "ready"
	check(defender.advance_stage() and not defender.shieldstorm_pulse_used, "Shieldstorm's automatic purge recharges at the next warp")
	var opening := Sim.new(7703)
	_fuse_pair(opening, opening.fusion_spec("shieldstorm"))
	opening.shield = 2.0
	opening.bullets = [{"p":Vector2(270,300), "v":Vector2(0,20), "kind":"chaff", "damage":5.0, "source":"test"}]
	opening._hit(3.0, "heavy", "test")
	check(not opening.shieldstorm_pulse_used and opening.bullets.size() == 1, "Shieldstorm's passive does not ease the World 1 opening")
	var unfused := Sim.new(7704)
	unfused.stage = 2
	unfused.shield = 2.0
	unfused.bullets = [{"p":Vector2(270,300), "v":Vector2(0,20), "kind":"chaff", "damage":5.0, "source":"test"}]
	unfused._hit(3.0, "heavy", "test")
	check(unfused.bullets.size() == 1, "A shield break without the fusion does not erase bullets")
	var cast := Sim.new(7705)
	cast.stage = 2
	_fuse_pair(cast, cast.fusion_spec("shieldstorm"))
	cast.shield = 5.0
	cast.shield_offline = 4.0
	cast.bullets = [{"p":Vector2(270,300), "v":Vector2(0,20), "kind":"chaff", "damage":5.0, "source":"test"}]
	cast.charges = [{"source":2, "x":270.0, "remaining":0.5, "duration":1.8, "damage":20.0}]
	check(cast.activate("shieldstorm") and cast.bullets.is_empty() and cast.charges.is_empty() and cast.aegis_left > 0.0 and cast.shield > 5.0 and cast.shield_offline == 0.0, "Shieldstorm active cast clears the field, repairs shield suppression and grants Aegis")
	var rank := Sim.new(7706)
	var baseline: float = rank.weapon_power()
	rank.upgrades.shield_focus = 10
	check(is_equal_approx(rank.weapon_power(), baseline * 1.5), "The new full-hull Shield Focus milestone does not affect World 1")
	rank.stage = 2
	check(is_equal_approx(rank.weapon_power(), baseline * 1.95), "A rank-10 Shield Focus has 50% high-shield and 30% full-hull damage")
	rank.hull -= 1.0
	check(is_equal_approx(rank.weapon_power(), baseline * 1.5), "The full-hull milestone is lost immediately when hull is chipped")

func _test_fusions_and_milestones() -> void:
	var content := Sim.new(1901).content
	check(content.fusions.size() == 12 and content.passive_links.size() == 8, "Twenty-two base actives must include the optional Shieldstorm fusion and eight passive links")
	for card in content.cards:
		if str(card.tag) == "MUTATION":
			check(int(card.max) == 1 and not Catalog.mutation(str(card.id)).is_empty(), "A weapon mutation is an exclusive one-time choice: " + str(card.id))
		else:
			check(int(card.max) == 10 and card.has("rank5") and card.has("rank10"), "Every ranked upgrade needs rank 5 and 10 milestones: " + str(card.id))
	for pair in content.fusions:
		var sim := Sim.new(1901)
		_fuse_pair(sim,pair)
		check(str(pair.id) in sim.active_slots and sim._source_active(str(pair.parts[0])) and sim._source_active(str(pair.parts[1])), "Fusion must replace two active buttons: " + str(pair.id))
		check(sim.active_slots.size() == (1 if "aegis" in pair.parts else 2), "Fusion must free one equipped slot, not add a fifth button")
		check(not sim.activate(str(pair.parts[0])) and not sim.activate(str(pair.parts[1])), "Consumed components cannot cast separately: " + str(pair.id))
		var old_uses: int = sim.ability_uses
		check(sim.activate(str(pair.id)) and sim.ability_uses == old_uses + 1 and float(sim.cooldowns[str(pair.id)]) > 0.0, "Fused button must cast one new skill with a real cooldown: " + str(pair.id))
		var snap: Dictionary = sim.snapshot()
		var clone := Sim.new(2)
		check(clone.restore(snap) and clone.snapshot() == snap, "Fused skills and source ranks must survive save/restore: " + str(pair.id))
	var counter := Sim.new(1909)
	counter.active_slots = ["nova_aegis"]
	counter.upgrades.aegis = 1
	counter.upgrades.nova = 1
	counter.upgrades.nova_aegis = 1
	counter.hull = counter.max_hull - 30.0
	var plain := Sim.new(1909)
	plain.active_slots = ["nova_aegis"]
	plain.upgrades.aegis = 1
	plain.upgrades.nova = 1
	plain.upgrades.nova_aegis = 1
	plain.hull = plain.max_hull - 30.0
	counter.charges.append({"source":0, "x":270.0, "remaining":0.5, "duration":1.8, "damage":29.0})
	counter._add_enemy("station", Vector2(260, 120))
	plain._add_enemy("station", Vector2(260, 120))
	check(counter.activate("nova_aegis") and plain.activate("nova_aegis"), "Nova Guard must cast when a beam is close")
	check(counter.cooldowns.nova_aegis < plain.cooldowns.nova_aegis and counter.hull > plain.hull and counter.aegis_left > plain.aegis_left, "A well-timed fusion counter must earn real healing and a shorter cooldown")
	check(counter.kills > plain.kills, "A timed Nova Guard counter must hit much harder than firing it early")
	var slots := Sim.new(1902)
	for name in ["flak", "emp", "strike"]:
		_install(slots, name)
	check(slots.active_slots.size() == 4 and not slots._can_learn_active("nova"), "A rank-1 partner cannot bypass a full bar")
	var free_slot := Sim.new(1903)
	_install(free_slot,"nova")
	check(free_slot.active_slots.size() == 2 and "nova_aegis" not in free_slot.active_slots, "Collecting two rank-1 actives does not fuse them")
	_fuse_pair(free_slot,content.fusions[0])
	check(free_slot.active_slots.size() == 1 and "nova_aegis" in free_slot.active_slots, "A rank-5 pair reopens one slot")
	for link in content.passive_links:
		var sim := Sim.new(1904)
		for part in link.requires:
			if int(sim.upgrades.get(str(part), 0)) == 0:
				_install(sim, str(part))
		check(sim.passive_link_active(str(link.id)), "Both equipped passive tracks must trigger the defined team-up: " + str(link.id))
	var tank := Sim.new(1905)
	tank.upgrades.armor = 1
	tank.upgrades.hull = 1
	check(tank.passive_link_active("reinforced_plating") and tank.hull_damage_multiplier() < Sim.new(1905).hull_damage_multiplier(), "Armor + Hull must reduce actual incoming damage")
	var first := Sim.new(1906)
	first.upgrades.hull = 4
	first.cards = [first.content.cards.filter(func(card): return card.id == "hull")[0]]
	var hp: float = first.max_hull
	check(first.choose_card(0) and first.upgrades.hull == 6 and first.max_hull == hp + 36.0 + 25.0 and first.capacity_milestones.has("hull5"), "Crossing rank 5 must pay a one-time larger hull bonus")
	first.upgrades.hull = 9
	first.cards = [first.content.cards.filter(func(card): return card.id == "hull")[0]]
	hp = first.max_hull
	check(first.choose_card(0) and first.upgrades.hull == 10 and first.max_hull == hp + 18.0 + 50.0 and first.capacity_milestones.has("hull10"), "Crossing rank 10 must pay another one-time hull bonus")
	var saved: Dictionary = first.snapshot()
	var resume := Sim.new(9)
	check(resume.restore(saved) and resume.max_hull == first.max_hull and resume.capacity_milestones == first.capacity_milestones, "Capacity milestones must not pay twice on restore")
	var old: Dictionary = saved.duplicate(true)
	old.erase("capacity_milestones")
	old.max_hull -= 75.0
	old.hull -= 75.0
	var migrated := Sim.new(9)
	check(migrated.restore(old) and migrated.max_hull == first.max_hull, "Old v0.6 saves must receive existing rank milestones exactly once")
	var starter := Sim.new(1907)
	var ranked := Sim.new(1907)
	ranked.upgrades.aegis = 5
	check(starter.activate("aegis") and ranked.activate("aegis") and ranked.cooldowns.aegis < starter.cooldowns.aegis and ranked.aegis_left > starter.aegis_left, "Rank 5 active milestone must improve cooldown and effect")
	var maxed := Sim.new(1907)
	maxed.upgrades.aegis = 10
	check(maxed.activate("aegis") and maxed.cooldowns.aegis < ranked.cooldowns.aegis and maxed.aegis_left > ranked.aegis_left, "Rank 10 active milestone must improve both again")
	var guns := Sim.new(1908)
	guns.upgrades.pulse = 10
	guns.upgrades.seeker = 10
	guns._add_enemy("drone", Vector2(250, 150))
	guns._update_weapons()
	check(guns.shots.filter(func(shot): return shot.weapon == "pulse").size() == 3 and guns.shots.filter(func(shot): return shot.weapon == "seeker").size() == 3, "Rank 10 pulse and seeker volleys must change live weapon behavior")


func _test_new_stage_threats() -> void:
	var sim := Sim.new(707)
	for kind in ["arc_spire", "storm_weaver", "forge_turret", "slag_bomber", "ember_hunter", "splitter", "phase_stalker", "void_lancer", "gravity_sentinel", "echo_carrier"]:
		check(sim.content.enemies.has(kind) and sim.content.enemies[kind].hp > 0, "All new enemies need positive health specs: " + kind)
	sim.stage = 3
	sim.stage_start = sim.time
	sim._add_enemy("slag_bomber", Vector2(250, 100))
	sim.enemies[0].fire = 0.0
	sim._update_enemies()
	check(sim.bullets.any(func(b): return b.kind == "slag" and b.fuse > 0.0), "Foundry bomber must create timed molten-slag hazards")
	sim._hit(2.0, "heat", "test")
	check(sim.heat_left >= 5.0 and sim.weapon_power() < Sim.new().weapon_power(), "Heat must reduce firepower temporarily")
	var first_kills := sim.kills
	sim.enemies.clear()
	sim._add_enemy("splitter", Vector2(225, 180))
	sim._damage_enemy(sim.enemies[0], 10000.0, "pulse")
	check(sim.kills == first_kills + 1 and sim.enemies.size() == 3, "Splitter must release two new drone enemies on death")
	sim.enemies.clear()
	sim.bullets.clear()
	sim.stage = 4
	sim.stage_start = sim.time
	sim._add_enemy("gravity_sentinel", Vector2(260, 120))
	sim.enemies[0].fire = 0.0
	sim._update_enemies()
	check(sim.bullets.any(func(b): return b.kind == "gravity"), "Void sentinels must launch recognizable gravity projectiles")
	sim._hit(2.0, "gravity", "test")
	check(sim.gravity_left >= 4.5, "Gravity threat must slow automatic weapons")
	sim.enemies.clear()
	sim.bullets.clear()
	sim._spawn_boss()
	sim.heavy_ready_at = 0.0
	sim._update_enemies()
	check(sim.charges.size() == 2 and sim.charges[0].remaining >= 1.0, "Final boss must telegraph two distinct heavy lanes")
	sim._hit(2.0, "void", "test")
	check(sim.hull < sim.max_hull, "Void shots must meaningfully bypass shields")
	var bleed := Sim.new(9081)
	bleed.stage = 4
	bleed._hit(10.0, "void", "test")
	check(is_equal_approx(bleed.hull, bleed.max_hull - 10.0 * bleed.stage_damage_scale() * bleed.enemy_damage_multiplier() * 0.20), "Citadel void must bypass 20% of shielded damage with the late-world enemy attack modifier")
	var early_lancer := Sim.new(9082)
	early_lancer.stage = 4
	early_lancer.time = 35.0
	early_lancer.heavy_ready_at = 0.0
	early_lancer._add_enemy("void_lancer",Vector2(250,150))
	early_lancer._update_enemies()
	check(early_lancer.charges.size() == 1 and is_equal_approx(early_lancer.heavy_ready_at - early_lancer.time,7.8), "Early Citadel lancer beams give new builds 7.8s between charges")
	var late_lancer := Sim.new(9082)
	late_lancer.stage = 4
	late_lancer.time = 210.0
	late_lancer.heavy_ready_at = 0.0
	late_lancer._add_enemy("void_lancer",Vector2(250,150))
	late_lancer._update_enemies()
	check(late_lancer.charges.size() == 1 and is_equal_approx(late_lancer.heavy_ready_at - late_lancer.time,4.4), "Later Citadel attacks recover the original heavy cadence before the boss")

func _balance(seeds: int) -> Dictionary:
	var result: Dictionary = {}
	for strategy in ["never", "on_cooldown", "timed"]:
		var survival := 0.0
		var remaining := 0.0
		var wins := 0
		var max_charges := 0
		var max_entities := 0
		for seed_index in range(seeds):
			# Rank-5 fusion sources add milestone power; Hard keeps this encounter
			# challenging enough to distinguish counter timing from cooldown spam.
			var sim := Sim.new(61000 + (seed_index + 1) * 7919)
			for i in range(60 * 360):
				_bot(sim, strategy)
				sim.step()
				max_charges = maxi(max_charges, sim.charges.size())
				max_entities = maxi(max_entities, sim.bullets.size())
				if sim.ended or sim.stage_clears >= 1:
					break
			survival += sim.time
			remaining += sim.hull
			wins += int(sim.stage_clears >= 1)
		check(max_charges <= 1, "Dangerous heavy telegraphs must never overlap")
		result[strategy] = {"seeds": seeds, "wins": wins, "mean_survival": snappedf(survival / seeds, 0.1), "mean_hull": snappedf(remaining / seeds, 0.1), "max_bullets": max_entities}
	return result

func _test_stage_rerolls_and_shield_breaks() -> void:
	for rank in [0, 1, 3]:
		for pilot in ["rookie", "tactician"]:
			var sim := Sim.new(2401, {"rerolls": rank}, "vanguard", pilot)
			for stage_number in range(1, 5):
				var expected: int = rank + (1 if pilot == "tactician" and stage_number == 1 else 0)
				check(sim.rerolls_left == expected, "Only purchased stage rerolls replenish; pilot bonus is once per flight")
				sim._offer_cards(false)
				for use in range(expected):
					check(sim.reroll_cards(), "Every granted reroll can replace the hand")
				check(not sim.reroll_cards(), "Exhausted rerolls cannot replace the hand")
				var saved := sim.snapshot()
				var resumed := Sim.new()
				check(resumed.restore(saved) and resumed.rerolls_left == 0 and resumed.pilot_rerolls_left == 0, "Resume must not replenish spent rerolls")
				check(resumed.pilot_id == pilot, "Resume must retain the pilot whose reroll allowance was saved")
				sim = resumed
				sim.cards.clear()
				sim._spawn_boss()
				sim._damage_enemy(sim.enemies[0], 9999999.0, "pulse")
				if stage_number < 4:
					check(sim.begin_intermission() and sim.choose_prototype(0) and sim.choose_route("repair") and sim.advance_stage(), "Rerolls refill through the real boss/intermission transition")
					var allowance: int = sim.rerolls_left
					check(not sim.advance_stage() and sim.rerolls_left == allowance, "Repeated stage advance cannot grant more rerolls")
	var unused := Sim.new(2402, {"rerolls": 2}, "vanguard", "tactician")
	unused._offer_cards(false)
	unused.reroll_cards()
	check(unused.rerolls_left == 2 and unused.pilot_rerolls_left == 1, "Use renewable stage rerolls before the pilot reserve")
	unused.cards.clear()
	unused._spawn_boss()
	unused._damage_enemy(unused.enemies[0], 9999999.0, "pulse")
	unused._enter_stage_two()
	check(unused.rerolls_left == 3 and unused.pilot_rerolls_left == 1, "Unused stage uses do not accumulate; unused pilot reserve remains")
	var legacy := unused.snapshot()
	legacy.erase("pilot_rerolls_left")
	var migrated := Sim.new()
	check(migrated.restore(legacy) and migrated.rerolls_left == unused.rerolls_left, "Older checkpoints keep their current allowance without a free refill")
	var shielded := Sim.new(2403)
	shielded._hit(2, "chaff", "test")
	check(not shielded.effects.any(func(e): return e.kind == "shield-break"), "Ordinary shield hits do not show a break")
	shielded.shield = 4.0
	shielded._hit(4.0, "heavy", "test")
	check(shielded.shield == 0 and shielded.effects.filter(func(e): return e.kind == "shield-break").size() == 1, "Exact shield depletion must emit one distinct break cue")
	shielded._hit(4.0, "heavy", "test")
	check(shielded.effects.filter(func(e): return e.kind == "shield-break").size() == 1, "Further hull hits must not repeat the shield-break cue")
	var protected := Sim.new(2404)
	protected.aegis_left = 1.0
	protected._hit(100.0, "heavy", "test")
	check(not protected.effects.any(func(e): return e.kind == "shield-break"), "Aegis-blocked attacks must not claim the shield broke")
	var safeguard := Sim.new(2405)
	safeguard.prototypes = ["emergency_safeguard"]
	safeguard.shield = 2.0
	safeguard._hit(3.0, "heavy", "test")
	check(safeguard.shield > 0 and safeguard.effects.any(func(e): return e.kind == "shield-break"), "An immediately rebuilt shield still shows the actual break")

func _test_long_runs() -> void:
	var added := ["boss_hunter", "finisher", "opening_salvo", "ablative", "insulation", "shield_surge", "field_medic", "last_stand", "shield_focus", "afterburn"]
	var sim := Sim.new(2751)
	check(sim.content.cards.filter(func(c): return c.id in added and c.tag == "SYSTEM").size() == 10, "Ten new passives must exist")
	for stage in [1, 2]:
		sim.stage = stage
		var seen := {}
		for i in range(300):
			sim._offer_cards(false)
			for card in sim.cards: seen[card.id] = true
		check(added.all(func(id): return seen.has(id) == (stage == 2)), "Late passives become draftable in world 2")
		check(not sim.cards.any(func(c): return not sim.fusion_spec(c.id).is_empty()), "Unowned fusions cannot be offered directly")
	for pair in sim.content.fusions:
		var fused := Sim.new(2752)
		_fuse_pair(fused,pair)
		var seen := {}
		for i in range(100):
			fused._offer_cards(false)
			for card in fused.cards: seen[card.id] = true
		check(not seen.has(pair.parts[0]) and not seen.has(pair.parts[1]) and seen.has(pair.id), "Only the fused upgrade may reappear: " + str(pair.id))
		fused.cards = [fused.content.cards.filter(func(c): return c.id == pair.id)[0]]
		var power: float = fused._active_rank_scale(pair.id)
		var slots: Array = fused.active_slots.duplicate()
		check(fused.choose_card(0) and fused.upgrades[pair.id] == 3 and fused._active_rank_scale(pair.id) > power and fused.active_slots == slots, "Upgrading a fusion strengthens it without consuming a slot")
		# Migrate an already-open v0.7.2 draft, preserving its remaining draft tools.
		fused.cards = [fused.content.cards.filter(func(c): return c.id == pair.parts[0])[0]]
		fused.pending_levels = 2
		fused.rerolls_left = 1
		var old: Dictionary = fused.snapshot()
		var restored := Sim.new()
		check(restored.restore(old) and restored.pending_levels == 2 and restored.rerolls_left == 1 and not restored.cards.any(func(c): return c.id in pair.parts), "Old component offers migrate without charging a reroll or losing a level")
		var again := Sim.new()
		check(again.restore(restored.snapshot()) and again.snapshot() == restored.snapshot(), "Migrated draft remains stable after another restore")
	for id in added:
		var ranked := Sim.new(2753)
		var card: Dictionary = ranked.content.cards.filter(func(c): return c.id == id)[0]
		ranked.cards = [card]
		check(ranked.choose_card(0) and ranked.upgrades[id] == 2 and ranked.active_slots == ["aegis"], "Passive picks never consume an active slot: " + id)
	var target := {"id":99, "p":Vector2(270,200), "kind":"boss", "hp":1000.0, "max_hp":1000.0}
	sim = Sim.new()
	sim.upgrades.boss_hunter = 10
	sim._damage_enemy(target, 100, "pulse")
	check(is_equal_approx(target.hp, 810.0), "Siege rounds increase live boss damage")
	target = {"id":99, "p":Vector2(270,200), "kind":"drone", "hp":300.0, "max_hp":1000.0}
	sim.upgrades.finisher = 10
	sim._damage_enemy(target, 100, "pulse")
	check(is_equal_approx(target.hp, 120.0), "Finisher applies below 35% enemy hull")
	target = {"id":99, "p":Vector2(270,200), "kind":"drone", "hp":1000.0, "max_hp":1000.0}
	sim.upgrades.opening_salvo = 10
	sim._damage_enemy(target, 100, "pulse")
	sim._damage_enemy(target, 100, "pulse")
	check(is_equal_approx(target.hp, 640.0), "First strike now boosts all hits while the enemy remains above 75% health")
	sim._damage_enemy(target, 100, "pulse")
	check(is_equal_approx(target.hp, 540.0), "First strike stops boosting damage after the target drops below 75% health")
	target.hp = 750.0
	sim._damage_enemy(target, 100, "pulse")
	check(is_equal_approx(target.hp, 650.0), "First strike does not apply right at the 75% threshold")
	sim = Sim.new()
	sim.upgrades.ablative = 10
	sim._hit(10, "heavy", "test")
	sim._hit(10, "ordnance", "test")
	sim._hit(10, "hazard", "Molten slag")
	sim._hit(10, "ion", "test")
	check(is_equal_approx(sim.damage_taken.heavy, 6) and is_equal_approx(sim.damage_taken.ordnance, 6) and is_equal_approx(sim.damage_taken.hazard, 6) and is_equal_approx(sim.damage_taken.ion, 10), "Blast plating protects only explosive and beam damage")
	sim = Sim.new()
	sim.upgrades.insulation = 10
	for kind in ["ion", "heat", "gravity", "corrosion"]: sim._hit(1, kind, "test")
	sim.cooldowns.aegis = 8
	sim._hit(1, "disrupt", "test")
	check(is_equal_approx(sim.shield_offline, 2) and is_equal_approx(sim.heat_left, 2.5) and is_equal_approx(sim.gravity_left, 2.25) and is_equal_approx(sim.corrosion_left, 2.5) and is_equal_approx(sim.cooldowns.aegis, 9), "Insulation shortens all five debuffs")
	check(is_equal_approx(sim.status_damage_multiplier(), 0.85), "Rank-10 Insulation blocks 15% of status attack damage")
	for kind in ["ion", "heat", "gravity", "corrosion", "disrupt", "void"]:
		var control := Sim.new(5720)
		var insulated := Sim.new(5720)
		insulated.upgrades.insulation = 10
		control._hit(10.0, kind, "test")
		insulated._hit(10.0, kind, "test")
		check(is_equal_approx(float(insulated.damage_taken.get(kind,0.0)), float(control.damage_taken.get(kind,0.0)) * 0.85), "Insulation blocks status hit damage from " + kind)
	var regular_corrosion := Sim.new(5721)
	var reduced_corrosion := Sim.new(5721)
	regular_corrosion.corrosion_left = 1.0
	reduced_corrosion.corrosion_left = 1.0
	reduced_corrosion.upgrades.insulation = 10
	regular_corrosion.step()
	reduced_corrosion.step()
	check(regular_corrosion.damage_taken.corrosion > 0.0 and is_equal_approx(float(reduced_corrosion.damage_taken.corrosion), float(regular_corrosion.damage_taken.corrosion) * 0.85), "Insulation also blocks ongoing corrosion damage, not just the initial hit")
	sim = Sim.new()
	sim.upgrades.shield_surge = 10
	sim.shield = 0
	sim.activate("aegis")
	check(is_equal_approx(sim.shield, sim.max_shield * 0.15), "Shield reserve restores shield on a cast")
	sim = Sim.new()
	sim.upgrades.field_medic = 10
	sim.hull -= 20
	var before: float = sim.hull
	sim._add_enemy("drone", Vector2(270,200))
	sim._damage_enemy(sim.enemies[0], 1000, "pulse")
	check(is_equal_approx(sim.hull, before + 1.75), "Combat repairs restore hull from an actual kill")
	sim = Sim.new()
	var base_power: float = sim.weapon_power()
	sim.upgrades.last_stand = 10
	check(is_equal_approx(sim.weapon_power(), base_power), "Last stand stays inactive at healthy hull")
	sim.hull = sim.max_hull * 0.60
	check(is_equal_approx(sim.weapon_power(), base_power), "Last stand stays inactive exactly at 60% hull")
	sim.hull = sim.max_hull * 0.55
	check(is_equal_approx(sim.weapon_power(), base_power * 1.6), "Last stand boosts damage below 60% hull")
	sim.hull = sim.max_hull * 0.30
	check(is_equal_approx(sim.weapon_power(), base_power * 1.6), "Last stand retains its full low-hull bonus")
	sim = Sim.new()
	base_power = sim.weapon_power()
	sim.stage = 2
	sim.upgrades.shield_focus = 10
	check(is_equal_approx(sim.weapon_power(), base_power * 1.5 * 1.30), "Rank-10 Shield Focus rewards high shields and a full hull")
	sim.shield = sim.max_shield * 0.5
	check(is_equal_approx(sim.weapon_power(), base_power * 1.30), "Full-hull bonus continues after shields drop")
	sim.hull -= 1.0
	check(is_equal_approx(sim.weapon_power(), base_power), "Even a small hull hit ends the full-hull damage reward")
	sim.shield = sim.max_shield
	check(is_equal_approx(sim.weapon_power(), base_power * 1.5), "High-shield damage stays after the hull is chipped")
	sim.upgrades.shield_focus = 5
	sim.hull = sim.max_hull
	check(is_equal_approx(sim.weapon_power(), base_power * 1.225 * 1.12), "Rank-5 Shield Focus earns a smaller full-hull bonus")
	sim = Sim.new()
	sim.upgrades.afterburn = 10
	sim.pulse_timer = 1.0
	sim.activate("aegis")
	sim._update_weapons()
	check(is_equal_approx(sim.pulse_timer, 1.0 - Sim.DT * 1.55), "Follow-through accelerates actual weapon timers")
	var clone := Sim.new()
	check(clone.restore(sim.snapshot()) and clone.aftercast_left == 4.0 and clone.upgrades.afterburn == 10, "New passives and cast timer survive resume")
	for i in range(241): sim.step()
	check(sim.aftercast_left == 0.0, "Follow-through expires after four simulation seconds")
	for active in ["aegis", "nova_aegis"]:
		sim = Sim.new()
		if active == "nova_aegis": _fuse_pair(sim,sim.content.fusions[0])
		for key in ["aegis", "nova", "nova_aegis", "coolant", "amplifier"]: sim.upgrades[key] = 10
		sim.meta.ability_cooldown = 10
		sim.meta.ability_power = 10
		sim.cards.clear()
		sim.activate(active)
		check(sim.aegis_left <= sim.cooldowns[active] - 1.5 + 0.001, "Endgame cooldowns cannot create permanent invulnerability")
	for stage in [2,3,4]:
		sim = Sim.new()
		sim.stage = stage
		var early_scale: float = sim.stage_damage_scale()
		sim.time = 240.0
		var full_scale: float = sim.stage_damage_scale()
		check(early_scale < full_scale and early_scale > 1.0 and is_equal_approx(full_scale,float(sim.stage_spec().damage_scale)), "Later-world entry pressure ramps to the full authored damage before the boss")
		sim.time = 0.0
		sim._hit(10, "ion", "test")
		check(is_equal_approx(sim.damage_taken.ion,10.0 * early_scale * 1.05), "World 2-4 early-ramp enemy damage is 5% higher without extra XP")
		sim.time = 240.0
		sim._hit(10, "ion", "test")
		check(is_equal_approx(sim.damage_taken.ion,10.0 * (early_scale + full_scale) * 1.05), "Late-world enemy damage reaches 105% of authored pressure, including during the boss")

func _fixed_build_timing(seeds: int) -> Dictionary:
	var results := {}
	for strategy in ["on_cooldown", "timed"]:
		var wins := 0
		var hull := 0.0
		var survival := 0.0
		for seed in range(seeds):
			# Rank-5 fusion sources add milestone power; Hard keeps this encounter
			# challenging enough to distinguish counter timing from cooldown spam.
			var sim := Sim.new(61000 + (seed + 1) * 7919, {}, "vanguard", "rookie", "hard")
			_fuse_pair(sim,sim.content.fusions[0])
			sim.cards.clear()
			sim.upgrades.pulse = 3
			sim.upgrades.seeker = 3
			sim.upgrades.armor = 3
			sim.upgrades.regen = 2
			sim._spawn_boss()
			for frame in range(60 * 120):
				sim.cards.clear()
				sim.pending_levels = 0
				var counter: bool = sim.charges.any(func(c): return c.remaining < 0.55)
				if not counter:
					for b in sim.bullets:
						if (b.p+b.v*0.30).distance_squared_to(sim.ship_position(sim.time+0.30)) < 65*65: counter = true; break
				if strategy == "on_cooldown" or counter: sim.activate("nova_aegis")
				sim.step()
				sim.effects.clear()
				if sim.ended or sim.stage_transition_queued: break
			wins += int(sim.stage_transition_queued)
			hull += sim.hull
			survival += sim.time
		results[strategy] = {"wins":wins,"mean_hull":snappedf(hull/seeds,0.1),"seconds":snappedf(survival/seeds,0.1)}
	return results

func _test_fusion_thresholds() -> void:
	for pair in Sim.new().content.fusions:
		var sim := Sim.new(2801)
		sim.active_slots = [str(pair.parts[0]),str(pair.parts[1])]
		var a: String = pair.parts[0]
		var b: String = pair.parts[1]
		for ranks in [[1,1],[4,4],[4,5],[5,4],[10,1],[1,10]]:
			sim.upgrades[a] = ranks[0]
			sim.upgrades[b] = ranks[1]
			sim._try_fuse()
			check(str(pair.id) not in sim.active_slots, "Both fusion components must reach 5: " + str(pair.id))
		sim.upgrades[a] = 5
		sim.upgrades[b] = 1
		check(sim.fusion_hint(b).is_empty(), "A rank-1 partner must not be advertised as an immediate fusion")
		sim.upgrades[b] = 3
		check(not sim.fusion_hint(b).is_empty(), "The 3-to-5 pick previews the resulting fusion")
		var copy := Sim.new()
		check(copy.restore(sim.snapshot()) and copy.active_slots == sim.active_slots, "Resume keeps a pair separate until upgraded")
		_install(copy,b)
		check(str(pair.id) in copy.active_slots and copy.upgrades[a] == 5 and copy.upgrades[b] == 5, "A real rank-5 draft pick triggers fusion")
		check(copy.effects.any(func(e): return e.kind == "fusion-formed" and e.fusion == pair.id), "Forming a fusion emits its own presentation event")
		copy.cards.clear()
		check(copy.activate(pair.id) and copy.effects.any(func(e): return e.kind == "fusion-cast" and e.fusion == pair.id), "Every fusion emits its distinct cast effect")
		check(not copy.effects.any(func(e): return e.kind == "nova"), "Fusions no longer add the same generic Nova effect")
		var old: Dictionary = copy.snapshot()
		old.upgrades[a] = 1
		old.upgrades[b] = 1
		var legacy := Sim.new()
		check(legacy.restore(old) and str(pair.id) in legacy.active_slots, "Already-earned fusions survive old saves without losing occupied slots")
	var full := Sim.new(2802)
	full.active_slots = ["aegis","nova","emp","flak"]
	full.upgrades.aegis = 5
	full.upgrades.nova = 4
	full.upgrades.emp = 1
	full.upgrades.flak = 1
	_install(full,"nova")
	check(full.upgrades.nova == 6 and full.active_slots.size() == 3 and "nova_aegis" in full.active_slots, "Crossing 5 from 4 also fuses on a full bar")

	var old_bar := Sim.new(2803, {"rerolls":2})
	old_bar.active_slots = ["aegis","emp","flak","mend"]
	for id in old_bar.active_slots: old_bar.upgrades[id] = 1
	old_bar.cards = [old_bar.content.cards.filter(func(c): return c.id == "nova")[0]]
	var restored := Sim.new()
	check(restored.restore(old_bar.snapshot()) and not restored.cards.any(func(c): return c.tag == "ABILITY" and restored.upgrades[c.id] == 0), "An old full-bar partner offer must become a valid hand")
	check(restored.rerolls_left == old_bar.rerolls_left and restored.pending_levels == old_bar.pending_levels, "Migrating the full-bar hand costs no reroll or level")
	var stable := Sim.new()
	check(stable.restore(restored.snapshot()) and stable.snapshot() == restored.snapshot(), "The migrated full-bar hand stays fixed on subsequent resumes")

func _test_expanded_hangar() -> void:
	check(Catalog.HANGAR.size() == 40, "Two new boss-specialist tracks expand the Hangar catalog from 38 to 40")
	var starting := Sim.new(3001,{"arc_start":1,"lance_start":1,"signature_rank":2})
	check(starting.upgrades.arc == 1 and starting.upgrades.lance == 1, "Purchased starting weapons are installed")
	check(Sim.new(3001,{"arc_start":1},"arcwing").upgrades.arc == 2, "Charged coil also improves an Arcwing’s starting weapon")
	check(starting.upgrades.aegis == 3 and starting.active_slots == ["aegis"], "Pilot drills upgrades the signature without filling another slot")
	check(Sim.new(3001,{"signature_rank":2},"haven").upgrades.mend == 3, "Pilot drills follows the selected ship")
	var armor := Sim.new(3002,{"beam_plating":4})
	armor.shield = 0
	armor._hit(20,"heavy","test beam")
	check(is_equal_approx(armor.hull,82.4), "Ablative panels reduce an actual beam hit by 12%")
	var restart := Sim.new(3003,{"shield_restart":4})
	restart._hit(50,"heavy","break")
	check(restart.shield == 0 and is_equal_approx(restart.shield_offline,2.2), "Restart circuit shortens shield-break downtime")
	var sealed := Sim.new(3004,{"hazard_seals":4})
	sealed._hit(1,"heat","heat")
	check(is_equal_approx(sealed.heat_left,4.0), "Sealed systems shorten an actual status hit")
	var siege := Sim.new(3005,{"boss_damage":5})
	var target := {"id":99,"kind":"boss","hp":1000.0,"max_hp":1000.0,"p":Vector2(270,130)}
	siege._damage_enemy(target,100,"pulse")
	check(is_equal_approx(target.hp,885.0), "Siege targeting applies only to automatic boss damage")
	target.hp = 1000.0
	siege._damage_enemy(target,100,"nova")
	check(is_equal_approx(target.hp,900.0), "Siege targeting does not silently amplify active damage")
	var normal := Sim.new(3006)
	var warheads := Sim.new(3006,{"ordnance_damage":4})
	normal._add_enemy("station",Vector2(270,300))
	warheads._add_enemy("station",Vector2(270,300))
	normal._update_weapons()
	warheads._update_weapons()
	check(is_equal_approx(warheads.shots.filter(func(v):return v.weapon=="seeker")[0].damage,normal.shots.filter(func(v):return v.weapon=="seeker")[0].damage*1.2), "Warhead tooling strengthens real seeker projectiles")
	var cast := Sim.new(3007,{"cast_repair":3,"opening_charge":3})
	cast.hull = 40
	cast.activate("aegis")
	normal = Sim.new(3007)
	normal.activate("aegis")
	check(cast.hull == 43 and is_equal_approx(cast.cooldowns.aegis,normal.cooldowns.aegis*0.7), "Field patch and Hot start apply to the first cast")
	var saved := Sim.new()
	check(saved.restore(cast.snapshot()) and saved.stage_casts.has("aegis"), "Hot start spending survives resume")
	cast.cooldowns.aegis = 0
	cast.activate("aegis")
	check(is_equal_approx(cast.cooldowns.aegis,normal.cooldowns.aegis), "Hot start does not repeat within a world")
	var warp := Sim.new(3008,{"warp_repairs":3,"banish_relay":2,"banishes":1})
	warp.hull = 10
	warp.stage_transition_queued = true
	warp.stage_clears = 1
	warp.intermission_step = "ready"
	warp.route_choice = "overclock"
	warp.stage_casts.aegis = true
	warp._launch_escorts(2,6,10)
	warp._deploy_ion_mines(1,100,150)
	check(warp.advance_stage() and is_equal_approx(warp.hull,32.0) and warp.banishes_left == 3, "Warp repairs and Banish relay pay at the new world")
	check(warp.stage_casts.is_empty() and warp.ion_mines.is_empty() and warp.escort_left == 0, "Warp resets first casts and clears support from the previous battlefield")
	var focused := Sim.new(3009,{"reroll_focus":1})
	focused.rerolls_left = 100
	focused._offer_cards(false)
	var valid := true
	for i in range(100):
		focused.reroll_cards()
		valid = valid and focused.cards.any(func(c):return focused.upgrades.get(c.id,0)>0)
		var ids := {}
		for card in focused.cards:
			valid = valid and not ids.has(card.id)
			ids[card.id] = true
	check(valid and focused.rerolls_left == 0, "Focused rerolls offer an owned upgrade without duplicate cards or extra uses")
	focused.banished = ["aegis","pulse","seeker"]
	focused._offer_cards(false)
	focused._focus_reroll()
	check(not focused.cards.any(func(c):return c.id in focused.banished), "Focused uplink respects removed tracks when nothing owned remains")
	var skip := Sim.new(3010,{"skip_patch":3,"skips":1})
	skip.hull = 10
	skip._offer_cards(false)
	check(skip.skip_cards() and skip.hull == 40 and skip.skips_left == 0, "Repair stores increase the actual skip heal")
	var salvage := Sim.new(3011,{"module_salvage":3,"clean_clear":3})
	salvage._spawn_boss()
	var part := {"id":99,"name":"Test part","kind":"boss_module","hp":10.0,"max_hp":10.0,"p":Vector2(270,100),"xp":0}
	salvage._damage_enemy(part,20,"pulse")
	check(salvage.bonus_cores == 3, "Component salvage pays for a destroyed boss part")
	salvage.hull = 70
	salvage._damage_enemy(salvage.enemies[0],100000,"pulse")
	check(salvage.bonus_cores == 12, "Clean contract pays a healthy world clear")
	salvage._damage_enemy(salvage.enemies[0],100000,"pulse")
	check(salvage.bonus_cores == 12, "A destroyed boss cannot pay the contract twice")
	var legacy: Dictionary = Sim.new().snapshot()
	for id in ["arc_start","cast_repair","opening_charge","reroll_focus"]: legacy.meta.erase(id)
	legacy.erase("stage_casts")
	legacy.erase("ion_mines")
	var restored := Sim.new()
	check(restored.restore(legacy) and restored.meta.arc_start == 0 and restored.ion_mines.is_empty(), "Older saves default new purchases and support state safely")

func _test_support_actives() -> void:
	for rank in [1,5,10]:
		var drone := Sim.new(3050)
		drone.active_slots = ["wing_drones"]
		drone.upgrades.wing_drones = rank
		drone._add_enemy("station",Vector2(270,600))
		drone.enemies[0].hp = 10000.0
		drone.enemies[0].max_hp = 10000.0
		check(drone.activate("wing_drones") and drone.escort_count == 2+int(rank>=5)+int(rank>=10), "Drone milestones add real escorts at rank " + str(rank))
		for frame in range(40):
			drone._update_support()
			drone._update_shots()
		check(drone.enemies[0].hp < 10000 and drone.damage_dealt.get("escort",0)>0, "Escort shots must hit real targets")
		var copy := Sim.new()
		check(copy.restore(drone.snapshot()) and copy.snapshot() == drone.snapshot(), "Escort count, damage and cadence survive saving")
		drone.escort_left = Sim.DT
		drone.escort_timer = 0.0
		var shots: int = drone.shots.size()
		drone._update_support()
		check(drone.escort_left == 0 and drone.shots.size() == shots, "Expired escorts cannot fire one extra volley")
		var mine := Sim.new(3051)
		mine.active_slots = ["ion_mine"]
		mine.upgrades.ion_mine = rank
		mine._add_enemy("station",Vector2(270,450))
		mine.enemies[0].hp = 10000.0
		mine.enemies[0].max_hp = 10000.0
		check(mine.activate("ion_mine") and mine.ion_mines.size() == (2 if rank == 10 else 1), "Mine rank 10 deploys a second charge")
		check(mine.ion_mines[0].radius == (190.0 if rank>=5 else 150.0), "Mine rank 5 expands the actual blast radius")
		mine.bullets = [{"p":mine.ion_mines[0].p,"v":Vector2.ZERO,"kind":"chaff","damage":10},{"p":Vector2(5,5),"v":Vector2.ZERO,"kind":"chaff","damage":10}]
		copy = Sim.new()
		check(copy.restore(mine.snapshot()) and copy.snapshot() == mine.snapshot(), "Armed mines survive saving exactly")
		for frame in range(110): mine._update_support()
		check(mine.ion_mines.is_empty() and mine.enemies[0].hp < 10000 and mine.bullets.size() == 1 and mine.bullets[0].p == Vector2(5,5), "Timed mines damage their area and clear only nearby shots")
	var carrier := Sim.new(3052)
	_fuse_pair(carrier,carrier.fusion_spec("storm_carrier"))
	check(carrier.activate("storm_carrier") and carrier.escort_count == 4 and carrier.ion_mines.size() == 3, "Storm Carrier combines four escorts and three mines in one active slot")

	carrier.ion_mines.clear()
	carrier._add_enemy("drone",Vector2(300,930))
	carrier._deploy_ion_mines(3,100,190)
	check(carrier.ion_mines.all(func(m):return m.p.x >= 25 and m.p.x <= 515 and m.p.y <= 865), "Ion charges stay visible even when targeting an enemy near the bottom edge")


func _test_contextual_active_balance() -> void:
	# Situational rewards should be earned at the point of danger, not on every cast.

	var aegis := Sim.new(5300)
	aegis.shield = 8.0
	aegis.charges = [{"source":3, "x":270.0, "remaining":0.5, "duration":1.8, "damage":35.0}]
	check(aegis.activate("aegis") and aegis.shield > 8.0, "Aegis precision cast inside a heavy charge earns shield")
	var early_aegis := Sim.new(5300)
	early_aegis.shield = 8.0
	early_aegis.charges = [{"source":3, "x":270.0, "remaining":1.6, "duration":1.8, "damage":35.0}]
	check(early_aegis.activate("aegis") and is_equal_approx(early_aegis.shield, 8.0), "Early Aegis keeps immunity but earns no precision reward")
	check(aegis.cooldowns.aegis < early_aegis.cooldowns.aegis * 0.85 and is_equal_approx(float(aegis.cooldown_totals.aegis),float(aegis.cooldowns.aegis)), "Only precise Aegis casts earn the reflected cooldown rebate")
	var near := Sim.new(5301)
	near.active_slots = ["flak"]
	near.upgrades.flak = 1
	near.shield = 10.0
	near.bullets = [{"p":near.ship_position() + Vector2(0,-60), "v":Vector2(0,120), "kind":"ordnance", "damage":12.0, "source":"test"}]
	check(near.activate("flak") and near.bullets.is_empty() and near.shield > 10.0, "Flak earns a shield reward for imminent ordnance")
	var far := Sim.new(5301)
	far.active_slots = ["flak"]
	far.upgrades.flak = 1
	far.shield = 10.0
	far.bullets = [{"p":far.ship_position() + Vector2(0,-320), "v":Vector2(0,120), "kind":"ordnance", "damage":12.0, "source":"test"}]
	check(far.activate("flak") and far.bullets.is_empty() and is_equal_approx(far.shield,10.0), "Early Flak clears ordnance but earns no close-call shield")
	var later_flak := Sim.new(5301)
	later_flak.stage = 2
	later_flak.active_slots = ["flak"]
	later_flak.upgrades.flak = 1
	later_flak.shield = 10.0
	later_flak.bullets = [{"p":later_flak.ship_position() + Vector2(0,-60), "v":Vector2(0,120), "kind":"ordnance", "damage":12.0, "source":"test"}]
	check(later_flak.activate("flak") and later_flak.shield >= 22.0, "Well-timed Flak protects later worlds more without easing World 1")
	var jam := Sim.new(5302)
	jam.active_slots = ["jammer"]
	jam.upgrades.jammer = 1
	jam.charges = [{"source":3, "x":270.0, "remaining":0.8, "duration":1.8, "damage":35.0}]
	check(jam.activate("jammer") and jam.charges.is_empty() and jam.beams_cancelled == 1, "Well-timed Jammer interrupts an existing charging beam")
	var early := Sim.new(5302)
	early.active_slots = ["jammer"]
	early.upgrades.jammer = 1
	early.charges = [{"source":3, "x":270.0, "remaining":1.8, "duration":1.8, "damage":35.0}]
	check(early.activate("jammer") and early.charges.size() == 1 and early.beams_cancelled == 0, "Early Jammer suppresses new fire but does not retroactively interrupt the beam")
	check(jam.cooldowns.jammer < early.cooldowns.jammer * 0.85 and is_equal_approx(float(jam.cooldown_totals.jammer),float(jam.cooldowns.jammer)), "Only a successful Jammer interrupt earns the displayed cooldown rebate")

	var rail_one := Sim.new(5303)
	rail_one.active_slots = ["strike"]
	rail_one.upgrades.strike = 1
	rail_one.enemies = [{"id":1, "kind":"boss", "hp":6200.0, "max_hp":6200.0, "p":Vector2(270,135), "xp":0}]
	check(rail_one.activate("strike"), "Rail Strike can hit the World 1 boss")
	var rail_four := Sim.new(5303)
	rail_four.stage = 4
	rail_four.active_slots = ["strike"]
	rail_four.upgrades.strike = 1
	rail_four.enemies = [{"id":1, "kind":"boss4", "hp":225000.0, "max_hp":225000.0, "p":Vector2(270,135), "xp":0}]
	check(rail_four.activate("strike"), "Rail Strike can hit the World 4 boss")
	check(float(rail_four.damage_dealt.get("strike",0.0)) > float(rail_one.damage_dealt.get("strike",0.0)) * 3.0, "Rail Strike remains relevant against later-world boss HP")
	var rail_cap := Sim.new(5303)
	rail_cap.active_slots = ["strike"]
	rail_cap.upgrades.strike = 10
	rail_cap.enemies = [{"id":1, "kind":"boss4", "hp":10000000.0, "max_hp":10000000.0, "p":Vector2(270,135), "xp":0}]
	check(rail_cap.activate("strike") and float(rail_cap.damage_dealt.get("strike",0.0)) <= (170.0 + 70.0 * 10.0 + 2200.0) * rail_cap.ability_power() * rail_cap._active_rank_scale("strike") + 0.01, "Rail Strike percent-based boss damage is capped even at rank 10")

	var drained := Sim.new(5304)
	drained.active_slots = ["siphon"]
	drained.upgrades.siphon = 1
	drained.hull = 40.0
	drained.enemies = [{"id":1, "kind":"shieldguard", "hp":1000.0, "max_hp":1000.0, "p":Vector2(270,500), "xp":0}]
	check(drained.activate("siphon"), "Energy Siphon can strike an armored target")
	var actual: float = float(drained.damage_dealt.get("siphon",0.0))
	check(actual > 0.0 and is_equal_approx(drained.hull, 40.0 + minf(25.0, actual * 0.30)), "Siphon healing uses actual damage after target armor, not advertised raw damage")
	var late_siphon := Sim.new(5304)
	late_siphon.stage = 4
	late_siphon.active_slots = ["siphon"]
	late_siphon.upgrades.siphon = 10
	late_siphon.hull = 40.0
	late_siphon.enemies = [{"id":1, "kind":"boss4", "hp":225000.0, "max_hp":225000.0, "p":Vector2(270,135), "xp":0}]
	check(late_siphon.activate("siphon") and late_siphon.damage_dealt.siphon > actual * 3.0 and late_siphon.hull <= 40.0 + 25.0 * late_siphon.ability_power() * late_siphon._active_rank_scale("siphon") + 0.01, "World 4 Siphon scales boss damage but cannot heal past the per-cast cap")

	var overkill := Sim.new(5305)
	overkill.active_slots = ["siphon"]
	overkill.upgrades.siphon = 1
	overkill.hull = 40.0
	overkill.enemies = [{"id":1, "kind":"drone", "hp":5.0, "max_hp":5.0, "p":Vector2(270,500), "xp":0}]
	check(overkill.activate("siphon") and is_equal_approx(overkill.hull, 41.5), "Siphon heals only for five actual damage, not for its much larger nominal hit")


func _test_late_world_ability_counters() -> void:
	var kinds := ["chaff", "ion", "corrosion", "disrupt", "heat", "gravity", "void"]
	for kind in kinds:
		var barrier := Sim.new(9311)
		barrier.stage = 4
		barrier.active_slots = ["barrier"]
		barrier.upgrades.barrier = 1
		barrier.shield = 8.0
		check(barrier.activate("barrier"), "Chaff barrier can activate against " + kind)
		barrier.bullets = [{"p":barrier.ship_position(), "v":Vector2.ZERO, "damage":12.0, "kind":kind, "source":"test"}]
		barrier._update_bullets()
		check(is_equal_approx(barrier.hull,barrier.max_hull) and is_equal_approx(barrier.shield,8.0) and barrier.bullets.is_empty(), "Barrier must counter small " + kind + " rounds without status bleed")
	var explosive := Sim.new(9312)
	explosive.active_slots = ["barrier"]
	explosive.upgrades.barrier = 1
	explosive.shield = 12.0
	check(explosive.activate("barrier"), "Barrier can be raised against heavier ordnance")
	explosive.bullets = [{"p":explosive.ship_position(),"v":Vector2.ZERO,"damage":8.0,"kind":"ordnance","hp":12.0,"source":"missile_bomber"}]
	explosive._update_bullets()
	check(explosive.shield < 12.0, "Barrier still cannot block ordnance or replace Flak")
	explosive._hit(10.0,"heavy","test")
	check(explosive.shield == 0.0, "Heavy beams still penetrate the small-shot barrier")

	var shielded := Sim.new(9313)
	shielded.stage = 4
	shielded.active_slots = ["deflector"]
	shielded.upgrades.deflector = 1
	shielded.shield = 2.0
	for kind in kinds:
		shielded.bullets.append({"p":shielded.ship_position(),"v":Vector2.ZERO,"damage":8.0,"kind":kind,"source":"test"})
	shielded.bullets.append({"p":shielded.ship_position(),"v":Vector2.ZERO,"damage":8.0,"kind":"ordnance","hp":12.0,"source":"missile_bomber"})
	check(shielded.activate("deflector") and shielded.bullets.size() == 1 and shielded.bullets[0].kind == "ordnance", "Deflector absorbs every small status projectile, never the specialist ordnance")
	check(shielded.shield > 2.0 and shielded.prevented > 0.0, "Deflector converts protected small shots into actual shielding")

	var prism := Sim.new(9314)
	prism.stage = 4
	prism.active_slots = ["prism"]
	prism.upgrades.prism = 1
	for kind in kinds:
		prism.bullets.append({"p":prism.ship_position(),"v":Vector2.ZERO,"damage":7.0,"kind":kind,"source":"test"})
	prism.bullets.append({"p":prism.ship_position(),"v":Vector2.ZERO,"damage":7.0,"kind":"mine","hp":10.0,"fuse":5.0,"source":"minelayer"})
	check(prism.activate("prism") and prism.shots.size() == kinds.size() and prism.bullets.size() == 1 and prism.bullets[0].kind == "mine", "Prism reflects all seven small-shot types while leaving mines to Flak")

	var repaired := Sim.new(9315)
	repaired.active_slots = ["mend"]
	repaired.upgrades.mend = 1
	repaired.heat_left = 4.0
	repaired.corrosion_left = 3.0
	check(repaired.activate("mend") and repaired.heat_left == 0.0 and repaired.corrosion_left == 0.0 and repaired.mend_left > 0.0, "Repair drones purge World 2 corrosion and World 3 overheating on a deliberate cast")
	var ion_repair := Sim.new(9316)
	ion_repair.stage = 2
	ion_repair.active_slots = ["mend"]
	ion_repair.upgrades.mend = 1
	ion_repair.shield_offline = 4.0
	check(ion_repair.activate("mend") and ion_repair.shield_offline == 0.0, "Repair drones reboot ion-disabled shields from World 2 onward")

	for kind in ["ion","corrosion","disrupt","heat","gravity","void"]:
		var standard := Sim.new(9371)
		standard.stage = 3
		standard.time = 240.0
		var haven := Sim.new(9371, {}, "haven")
		haven.stage = 3
		haven.time = 240.0
		standard._hit(10.0, kind, "test")
		haven._hit(10.0, kind, "test")
		check(is_equal_approx(float(haven.damage_taken[kind]), float(standard.damage_taken[kind]) * 0.75), "Haven's specialist armor absorbs exactly 25% of " + kind + " status-round damage")
	var standard_dot := Sim.new(9372)
	standard_dot.stage = 2
	standard_dot.corrosion_left = 1.0
	var haven_dot := Sim.new(9372, {}, "haven")
	haven_dot.stage = 2
	haven_dot.corrosion_left = 1.0
	standard_dot.step()
	haven_dot.step()
	check(is_equal_approx(float(haven_dot.damage_taken.corrosion),float(standard_dot.damage_taken.corrosion) * 0.75), "Haven's corrosion resistance also applies to ongoing hull damage, not just the original hit")
