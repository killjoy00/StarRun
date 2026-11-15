extends SceneTree
# Diagnostic, not a human-player win rate. Ships move and fire automatically.
# Strategies change only active ability use; all bots choose upgrades.
# The same seeds are used across strategies, but combat RNG can shift draft offers.
const Sim = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/catalog.gd")
const STRATEGIES := ["never", "on_cooldown", "timed"]
const MAX_STAGE_SECONDS := 540.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var seeds := 1
	var only_ship := ""
	var only_difficulty := ""
	var only_strategy := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--ship="):
			only_ship = arg.get_slice("=", 1)
		elif arg.begins_with("--difficulty="):
			only_difficulty = arg.get_slice("=", 1)
		elif arg.begins_with("--strategy="):
			only_strategy = arg.get_slice("=", 1)
	var cells := 0
	var trials := 0
	var faults := 0
	for ship in Catalog.SHIPS:
		var ship_id: String = str(ship.id)
		if not only_ship.is_empty() and only_ship != ship_id:
			continue
		for difficulty in Catalog.DIFFICULTIES:
			if not only_difficulty.is_empty() and only_difficulty != difficulty:
				continue
			cells += 1
			for strategy in STRATEGIES:
				if not only_strategy.is_empty() and only_strategy != strategy:
					continue
				var clears := [0, 0, 0, 0]
				var campaigns := 0
				var timeouts := 0
				var casts := 0
				var hull := 0.0
				for seed_index in range(seeds):
					var seed := 810000 + (seed_index + 1) * 7919
					var result: Dictionary = _trial(seed, ship_id, difficulty, strategy)
					trials += 1
					faults += int(result.get("fault", false))
					timeouts += int(result.timeout)
					casts += int(result.casts)
					hull += float(result.hull)
					campaigns += int(result.won)
					for stage_index in range(4):
						if int(result.clears) > stage_index:
							clears[stage_index] += 1
				print("BALANCE_MATRIX ", JSON.stringify({
					"ship":ship_id, "difficulty":difficulty, "policy":strategy,
					"seeds":seeds, "world_clears":clears, "campaign_wins":campaigns,
					"timeouts":timeouts, "casts":casts,
					"mean_final_hull":snappedf(hull / seeds, 0.1)
				}))
	print("BALANCE_MATRIX_SUMMARY ", JSON.stringify({
		"cells":cells, "seeds_per_cell":seeds, "trials":trials, "faults":faults,
		"method":"scripted autopilot and auto-weapons, automated upgrades, active policy only"
	}))
	quit(1 if cells == 0 or trials == 0 or faults > 0 else 0)

func _trial(seed: int, ship_id: String, difficulty: String, strategy: String) -> Dictionary:
	var sim := Sim.new(seed, {}, ship_id, "rookie", difficulty)
	var timed_out := false
	var fault := false
	for frame in range(4 * 60 * 600):
		if sim.ended:
			break
		if sim.stage_transition_queued:
			if sim.stage >= 4:
				if not sim.advance_stage():
					fault = true
				break
			if not sim.begin_intermission():
				fault = true
				break
			if sim.intermission_step == "prototype":
				if not sim.choose_prototype(0):
					fault = true
					break
			if not sim.choose_route("repair") or not sim.advance_stage():
				fault = true
				break
			continue
		if not sim.cards.is_empty():
			_pick_upgrade(sim)
			continue
		_cast(sim, strategy)
		sim.step()
		if sim.time - sim.stage_start > MAX_STAGE_SECONDS:
			timed_out = true
			break
	return {
		"clears":int(sim.stage_clears), "won":bool(sim.won),
		"hull":float(sim.hull), "casts":int(sim.ability_uses),
		"timeout":timed_out, "fault":fault
	}

func _pick_upgrade(sim: RefCounted) -> void:
	var priorities := ["seeker", "pulse", "arc", "lance", "regen", "hull",
		"armor", "munitions", "autoloader", "coolant", "shield", "targeting",
		"repair_bots", "harvester", "amplifier", "nova", "aegis",
		"barrage", "overdrive", "chrono", "mend", "repair"]
	var best := 0
	var best_priority := 100
	for index in range(sim.cards.size()):
		var card: Dictionary = sim.cards[index]
		var id: String = str(card.id)
		var priority: int = priorities.find(id)
		if priority < 0:
			priority = 90
		if not sim.fusion_spec(id).is_empty():
			priority = 4 if int(sim.upgrades.get(id, 0)) < 5 else 14
		if card.tag == "ABILITY" and int(sim.upgrades.get(id, 0)) == 0 and sim.active_slots.size() < Catalog.ACTIVE_SLOTS:
			priority = 0 if id in ["nova", "emp", "flak", "capacitor", "siphon", "jammer"] else 2
		if sim.hull < sim.max_hull * 0.35 and id in ["hull", "repair"]:
			priority = -1
		if priority < best_priority:
			best = index
			best_priority = priority
	sim.choose_card(best)

func _cast(sim: RefCounted, strategy: String) -> void:
	if strategy == "never":
		return
	if strategy == "on_cooldown":
		for active_id in sim.active_slots:
			sim.activate(str(active_id))
		return
	var urgent := sim.charges.any(func(c): return float(c.remaining) <= 0.7)
	var charge_ready := sim.charges.any(func(c): return float(c.remaining) <= 1.5)
	var near_hit := false
	var close_ordnance := false
	var ordnance_count := 0
	for bullet in sim.bullets:
		var future: Vector2 = bullet.p + bullet.v * 0.45
		var future_ship: Vector2 = sim.ship_position(sim.time + 0.45)
		if future.distance_squared_to(future_ship) < 65.0 * 65.0:
			near_hit = true
		if bullet.kind in ["ordnance", "mine", "slag"]:
			ordnance_count += 1
			if future.distance_squared_to(future_ship) < 90.0 * 90.0:
				close_ordnance = true
			if bullet.kind in ["mine", "slag"] and float(bullet.get("fuse", 10.0)) <= 0.75 and bullet.p.distance_squared_to(sim.ship_position()) < 110.0 * 110.0:
				close_ordnance = true
	var injured := sim.hull < sim.max_hull - 25.0
	var vulnerable := sim.shield < sim.max_shield * 0.55
	var crowd := sim.enemies.size() >= 3
	var boss := sim.boss_spawned
	for active_id in sim.active_slots:
		var ability: String = str(active_id)
		var use_now := false
		if ability in ["aegis", "nova_aegis"]:
			use_now = urgent or near_hit
		elif ability == "flak":
			use_now = close_ordnance or (ordnance_count >= 3 and sim.bullets.size() >= 14)
		elif ability == "jammer":
			use_now = charge_ready
		elif ability in ["emp", "stasis_lock", "ghost_signal"]:
			use_now = urgent or (boss and sim.bullets.size() >= 12)
		elif ability == "nova":
			use_now = urgent or (crowd and sim.bullets.size() >= 12)
		elif ability in ["mend", "siphon", "repair_matrix", "scrap_converter"]:
			use_now = injured and (boss or crowd)
		elif ability in ["capacitor", "deflector", "barrier", "reflective_wall"]:
			use_now = vulnerable or near_hit
		elif ability in ["prism", "overload", "chrono", "reactor_surge"]:
			use_now = sim.bullets.size() >= 12
		elif ability in ["decoy", "focus", "wing_drones", "ion_mine",
			"barrage", "overdrive", "strike", "railstorm",
			"missile_grid", "prism_focus", "storm_carrier"]:
			use_now = boss or crowd
		elif ability == "reboot":
			use_now = sim.active_slots.any(func(id): return id != "reboot" and float(sim.cooldowns.get(id,0.0)) >= 5.0)
		elif ability == "salvage":
			use_now = not boss and crowd
		else:
			use_now = boss or crowd
		if use_now:
			sim.activate(ability)
