extends SceneTree
## Controlled, post-warp investment fixtures for all six ships, Worlds 2-4.
## These compare actual hit/shield/interrupt behavior with matched controls.
## They do NOT claim natural draft rates or measured human win rates.
const Sim = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/catalog.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("PAYOFF_MATRIX: " + message)

func _enemy(sim: RefCounted, priority: bool = false) -> Dictionary:
	sim._add_enemy("carrier", Vector2(270, 260))
	var enemy: Dictionary = sim.enemies[-1]
	enemy.hp = 10000.0
	enemy.max_hp = 10000.0
	if priority:
		enemy["elite_role"] = "leader"
	return enemy

func _setup(ship: String, stage: int, seed: int) -> RefCounted:
	var sim := Sim.new(seed, {}, ship)
	sim.stage = stage
	return sim

func _exercise_evolution(sim: RefCounted, target: Dictionary, evolution: String, weapon: String) -> void:
	if evolution == "interceptor":
		sim.charges.append({"source":int(target.id), "x":270.0, "remaining":0.9, "duration":1.4, "damage":24.0})
	for i in range(5):
		match evolution:
			"spotter":
				sim._damage_enemy(target, 18.0, "pulse")
				sim._damage_enemy(target, 20.0, "seeker")
			"conductor":
				sim._damage_enemy(target, 18.0, "arc")
				sim._damage_enemy(target, 20.0, "pulse")
			_:
				sim._damage_enemy(target, 24.0, weapon)
		sim.tick += 1

func _evolution_cell(ship: String, stage: int, weapon: String, evolution: String, seed: int) -> void:
	var control := _setup(ship, stage, seed)
	var chosen := _setup(ship, stage, seed)
	for sim in [control, chosen]:
		sim.upgrades[weapon] = 5
		if evolution == "lifeline":
			sim.shield = maxf(0.0, sim.max_shield - 40.0)
	chosen.weapon_evolutions[weapon] = evolution
	var priority: bool = evolution in ["breacher", "interceptor", "executioner"]
	var control_enemy: Dictionary = _enemy(control, priority)
	var chosen_enemy: Dictionary = _enemy(chosen, priority)
	_exercise_evolution(control, control_enemy, evolution, weapon)
	_exercise_evolution(chosen, chosen_enemy, evolution, weapon)
	var base_damage: float = control_enemy.max_hp - float(control_enemy.hp)
	var evolved_damage: float = chosen_enemy.max_hp - float(chosen_enemy.hp)
	var meaningful: bool = false
	match evolution:
		"duelist", "spotter", "breacher", "conductor", "tempest", "executioner":
			meaningful = evolved_damage > base_damage + 0.1
		"interceptor":
			meaningful = control.charges.size() == 1 and chosen.charges.is_empty() and chosen.beams_cancelled == 1
		"lifeline":
			meaningful = evolved_damage < base_damage and chosen.shield > control.shield
	check(meaningful, "%s W%d %s %s produces a genuine combat difference" % [ship, stage, weapon, evolution])
	check(chosen.effects.any(func(e): return str(e.kind) == "evolution-proc" and str(e.evolution) == evolution),
		"%s W%d %s presents visible %s payoff" % [ship, stage, weapon, evolution])
	check(chosen.ability_uses == 0 and control.ability_uses == 0 and chosen.kills == control.kills,
		"%s W%d %s requires no cast and creates no extra kills" % [ship, stage, evolution])
	var snapshot: Dictionary = chosen.snapshot()
	var resumed := Sim.new()
	check(resumed.restore(snapshot) and resumed.snapshot() == snapshot,
		"%s W%d %s saves evolution cue throttle and actual marks" % [ship, stage, evolution])
	print("PAYOFF_EVOLUTION ", JSON.stringify({
		"ship":ship, "stage":stage, "weapon":weapon, "evolution":evolution,
		"control_damage":snappedf(base_damage, 0.1), "chosen_damage":snappedf(evolved_damage, 0.1),
		"shield_delta":snappedf(chosen.shield - control.shield, 0.1),
		"interrupts":chosen.beams_cancelled, "visible":meaningful
	}))

func _equip_engine(sim: RefCounted, id: String) -> void:
	for spec in sim.content.build_engines:
		if str(spec.id) != id:
			continue
		sim.upgrades[str(spec.primary)] = 5
		sim.upgrades[str(spec.secondary)] = 2
		var third: String = str(spec.third_any[0]) if spec.has("third_any") else str(spec.third)
		sim.upgrades[third] = 2
		if third == "wing_drones" and third not in sim.active_slots:
			sim.active_slots.append(third)
		return

func _engine_cell(ship: String, stage: int, id: String, seed: int) -> void:
	var sim := _setup(ship, stage, seed)
	_equip_engine(sim, id)
	check(sim.engine_tier(id) >= 2, "%s W%d %s begins from exactly earned recipe thresholds" % [ship, stage, id])
	var target: Dictionary = _enemy(sim, id in ["missile_siege", "prism_hunter"])
	match id:
		"execution_network":
			for i in range(6):
				sim._damage_enemy(target, 14.0, "pulse")
		"missile_siege":
			for i in range(3):
				sim._damage_enemy(target, 25.0, "seeker")
		"storm_circuit":
			sim._damage_enemy(target, 25.0, "arc")
			sim._damage_enemy(target, 25.0, "pulse")
		"prism_hunter":
			for i in range(3):
				sim._damage_enemy(target, 30.0, "lance")
		"fortress_reactor":
			for i in range(490):
				sim._update_build_engines()
		"salvage_carrier":
			# Earn all six support charges from real, damageable enemies.
			for i in range(6):
				var victim: Dictionary = _enemy(sim)
				victim.hp = 15.0
				victim.max_hp = 15.0
				sim._damage_enemy(victim, 20.0, "pulse")
			sim._update_build_engines()
	var count: int = int(sim.engine_procs.get(id, 0))
	check(count > 0, "%s W%d %s has a real no-cast payoff" % [ship, stage, id])
	check(sim.ability_uses == 0 and sim.choice_cores == 0, "%s W%d %s does not require timing or create a reward" % [ship, stage, id])
	check(sim.effects.any(func(e): return str(e.kind) == "engine-proc" and str(e.engine) == id),
		"%s W%d %s emits a matching visible cue" % [ship, stage, id])
	check(sim.build_impact_rows(2).any(func(row): return str(row.id) == id),
		"%s W%d %s is credited in the final build report" % [ship, stage, id])
	if id == "salvage_carrier":
		check(sim.shots.any(func(s): return str(s.weapon) == "escort"), "Salvage generates real support shots")
	else:
		check(float(target.hp) < float(target.max_hp), "%s W%d %s affects a real enemy" % [ship, stage, id])
	var sources := {
		"execution_network":"engine_execution", "storm_circuit":"engine_storm",
		"prism_hunter":"engine_prism", "fortress_reactor":"engine_fortress"
	}
	var source: String = str(sources.get(id, ""))
	print("PAYOFF_ENGINE ", JSON.stringify({
		"ship":ship, "stage":stage, "engine":id, "procs":count,
		"direct_damage":snappedf(float(sim.damage_dealt.get(source, 0.0)), 0.1)
	}))

func _run() -> void:
	var catalog := Sim.new(970000)
	var ships: Array = []
	for record in Catalog.SHIPS:
		ships.append(str(record.id))
	check(ships.size() == 7 and "lancer" in ships, "all seven current ship chassis are in the matrix")
	var evolution_cells := 0
	var engine_cells := 0
	for ship_index in range(ships.size()):
		var ship: String = str(ships[ship_index])
		for stage in [2, 3, 4]:
			for weapon in ["pulse", "seeker", "arc", "lance"]:
				for option in catalog.content.weapon_evolutions[weapon]:
					_evolution_cell(ship, stage, weapon, str(option.id),
						970000 + ship_index * 10000 + stage * 1000 + evolution_cells)
					evolution_cells += 1
			for spec in catalog.content.build_engines:
				_engine_cell(ship, stage, str(spec.id),
					980000 + ship_index * 10000 + stage * 1000 + engine_cells)
				engine_cells += 1
	check(evolution_cells == ships.size() * 3 * 8 and engine_cells == ships.size() * 3 * 6, "%d ships × 3 worlds × 8 evolutions and 6 engines" % ships.size())
	# The debrief credits observed mechanisms only and never attributes
	# generic escort damage to the Salvage engine.
	var recap := Sim.new(990000)
	recap.engine_procs.storm_circuit = 5
	recap.engine_procs.fortress_reactor = 3
	recap.engine_procs.salvage_carrier = 1
	recap.damage_dealt.engine_storm = 245.0
	recap.damage_dealt.escort = 9999.0
	var rows: Array = recap.build_impact_rows(2)
	check(rows.size() == 2 and rows[0].id == "storm_circuit" and rows[1].id == "fortress_reactor",
		"debrief shows two top observed engine activations in stable order")
	check("245 direct damage" in str(rows[0].detail) and not ("9999" in str(rows[0].detail)),
		"debrief includes actual engine damage, never unrelated escort damage")
	check(Sim.new(990001).build_impact_rows(2).is_empty(),
		"debrief does not claim progress for engines that never triggered")
	# Relevance text must describe the best actual completion, not merely
	# the first recipe in JSON order.
	var hints := Sim.new(990002)
	hints.stage = 2
	hints.upgrades.pulse = 5
	hints.upgrades.lance = 5
	hints.upgrades.opening_salvo = 2
	check(hints.engine_hint_for_pick("targeting").begins_with("Completes Prism Hunter"),
		"a completed Prism Hunter overrides a weaker Execution Network hint")
	# A zero-damage follow-up must not erase a pending cross-weapon mark.
	var spotter := Sim.new(990003)
	spotter.stage = 2
	spotter.upgrades.pulse = 5
	spotter.weapon_evolutions.pulse = "spotter"
	var spot_target: Dictionary = _enemy(spotter)
	spotter._damage_enemy(spot_target, 20.0, "pulse")
	var mark_until: float = float(spot_target.evo_spotter_until)
	spotter._damage_enemy(spot_target, 0.0, "seeker")
	check(float(spot_target.evo_spotter_until) == mark_until,
		"Spotter mark survives zero-damage hits, including sealed phases")
	var hp_before: float = spot_target.hp
	spotter._damage_enemy(spot_target, 20.0, "seeker")
	check(float(spot_target.hp) < hp_before - 20.1 and float(spot_target.evo_spotter_until) < 0.0,
		"Spotter mark pays out once when the next weapon actually deals damage")
	var conductor := Sim.new(990004)
	conductor.stage = 2
	conductor.upgrades.arc = 5
	conductor.weapon_evolutions.arc = "conductor"
	var charged: Dictionary = _enemy(conductor)
	conductor._damage_enemy(charged, 20.0, "arc")
	var charged_until: float = float(charged.evo_conductor_until)
	conductor._damage_enemy(charged, 0.0, "pulse")
	check(float(charged.evo_conductor_until) == charged_until,
		"Conductor charge survives a zero-damage pulse")
	conductor._damage_enemy(charged, 20.0, "pulse")
	check(float(charged.evo_conductor_until) < 0.0,
		"Conductor charge is consumed by a real cross-weapon follow-up")
	print("BUILD_PAYOFF_MATRIX_RESULT %d checks, %d failures" % [checks, failures])
	print("BUILD_PAYOFF_MATRIX_COUNTS ", JSON.stringify({
		"ships":ships.size(), "stages":[2, 3, 4],
		"evolution_cells":evolution_cells, "engine_cells":engine_cells,
		"method":"matched direct-hit comparisons and equipped post-warp recipe fixtures; no natural win-rate claim"
	}))
	quit(0 if failures == 0 else 1)
