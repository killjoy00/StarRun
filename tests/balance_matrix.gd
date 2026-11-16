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
	var build_style := "baseline"
	var hangar_style := "none"
	var route_policy := "adaptive"
	var pilot_id := "rookie"
	var trace := false
	var require_win := false
	var seed_offset := 0
	var stage_limit := 4
	var require_no_world1_clears := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--ship="):
			only_ship = arg.get_slice("=", 1)
		elif arg.begins_with("--difficulty="):
			only_difficulty = arg.get_slice("=", 1)
		elif arg.begins_with("--strategy="):
			only_strategy = arg.get_slice("=", 1)
		elif arg.begins_with("--build="):
			build_style = arg.get_slice("=", 1)
		elif arg.begins_with("--hangar="):
			hangar_style = arg.get_slice("=", 1)
		elif arg.begins_with("--route="):
			route_policy = arg.get_slice("=", 1)
		elif arg.begins_with("--pilot="):
			pilot_id = arg.get_slice("=", 1)
		elif arg.begins_with("--seed-offset="):
			seed_offset = maxi(0, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--stage-limit="):
			stage_limit = int(arg.get_slice("=", 1))
		elif arg == "--require-no-world1-clears":
			require_no_world1_clears = true
		elif arg == "--trace":
			trace = true
		elif arg == "--require-win":
			require_win = true
	if build_style not in ["baseline", "focused"] or hangar_style not in ["none", "mid", "max"] or route_policy not in ["adaptive", "repair", "overclock", "bounty"] or stage_limit < 1 or stage_limit > 4 or not Catalog.PILOTS.any(func(p): return p.id == pilot_id):
		push_error("Invalid balance diagnostic build, hangar or pilot")
		quit(2)
		return
	if require_no_world1_clears and (stage_limit != 1 or hangar_style != "none" or only_difficulty not in ["hard", "insane"]):
		push_error("No-Hangar World 1 gate applies only to Hard/Insane with stage-limit=1")
		quit(2)
		return
	var cells := 0
	var trials := 0
	var faults := 0
	var campaign_wins := 0
	var world1_clears := 0
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
					var seed := 810000 + (seed_offset + seed_index + 1) * 7919
					var result: Dictionary = _trial(seed, ship_id, difficulty, strategy, build_style, hangar_style, pilot_id, route_policy, stage_limit)
					if trace:
						print("CAMPAIGN_TRACE ", JSON.stringify({
							"seed":seed,"ship":ship_id,"difficulty":difficulty,"strategy":strategy,
							"build":build_style,"hangar":hangar_style,"route":route_policy,
							"routes":result.routes,"stages":result.stages,"final":result.final
						}))
					trials += 1
					world1_clears += int(result.clears) >= 1
					faults += int(result.get("fault", false))
					timeouts += int(result.timeout)
					casts += int(result.casts)
					hull += float(result.hull)
					campaigns += int(result.won)
					campaign_wins += int(result.won)
					for stage_index in range(4):
						if int(result.clears) > stage_index:
							clears[stage_index] += 1
				print("BALANCE_MATRIX ", JSON.stringify({
					"ship":ship_id, "difficulty":difficulty, "policy":strategy, "build":build_style, "hangar":hangar_style, "route":route_policy, "pilot":pilot_id,
					"seeds":seeds, "world_clears":clears, "campaign_wins":campaigns,
					"timeouts":timeouts, "casts":casts,
					"mean_final_hull":snappedf(hull / seeds, 0.1)
				}))
	print("BALANCE_MATRIX_SUMMARY ", JSON.stringify({
		"cells":cells, "seeds_per_cell":seeds, "trials":trials, "faults":faults, "world1_clears":world1_clears, "stage_limit":stage_limit, "campaign_wins":campaign_wins, "build":build_style, "hangar":hangar_style, "route":route_policy,
		"method":"scripted autopilot and auto-weapons, automated upgrades, active policy only"
	}))
	if require_win and campaign_wins == 0:
		push_error("Expected at least one genuine four-world victory using real combat, cards and bosses")
	if require_no_world1_clears and world1_clears > 0:
		push_error("%d of %d unupgraded Hard/Insane attempts cleared World 1 (ship %s, pilot %s). Investigate and rebalance before merging." % [world1_clears, trials, only_ship, pilot_id])
	quit(1 if cells == 0 or trials == 0 or faults > 0 or (require_win and campaign_wins == 0) or (require_no_world1_clears and world1_clears > 0) else 0)

func _trial(seed: int, ship_id: String, difficulty: String, strategy: String, build_style: String = "baseline", hangar_style: String = "none", pilot_id: String = "rookie", route_policy: String = "adaptive", stage_limit: int = 4) -> Dictionary:
	var sim := Sim.new(seed, _hangar(hangar_style), ship_id, pilot_id, difficulty)
	var timed_out := false
	var fault := false
	var stage_reports: Array = []
	var routes: Array = []
	var status := "dead"
	for _frame in range(4 * 60 * 600):
		if sim.ended:
			status = "won" if sim.won else "dead"
			break
		if sim.stage_transition_queued:
			stage_reports.append(_stage_report(sim, "cleared"))
			if sim.stage >= stage_limit:
				status = "stage_limit"
				break
			if sim.stage >= 4:
				if not sim.advance_stage():
					fault = true
				status = "won" if sim.won else "transition_failed"
				break
			if not sim.begin_intermission():
				fault = true
				break
			if sim.intermission_step == "prototype":
				var prototype_index := _choose_prototype(sim, build_style)
				if not sim.choose_prototype(prototype_index):
					fault = true
					break
			var route := route_policy
			if route == "adaptive":
				route = "overclock" if build_style == "focused" and sim.hull >= sim.max_hull * 0.72 else "repair"
			if not sim.choose_route(route) or not sim.advance_stage():
				fault = true
				break
			routes.append(route)
			continue
		if not sim.cards.is_empty():
			_pick_upgrade(sim, build_style)
			continue
		_cast(sim, strategy)
		sim.step()
		if sim.time - sim.stage_start > MAX_STAGE_SECONDS:
			timed_out = true
			status = "timeout"
			break
	if stage_reports.is_empty() or int(stage_reports[-1].stage) != sim.stage:
		stage_reports.append(_stage_report(sim, status))
	return {
		"clears":int(sim.stage_clears), "won":bool(sim.won),
		"hull":float(sim.hull), "casts":int(sim.ability_uses),
		"timeout":timed_out, "fault":fault, "stages":stage_reports, "routes":routes,
		"final":{"level":sim.level,"kills":sim.kills,"status":status, "build":build_style}
	}

func _pick_upgrade(sim: RefCounted, build_style: String = "baseline") -> void:
	if build_style == "focused":
		_pick_focused(sim)
		return
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
	var urgent: bool = sim.charges.any(func(c): return float(c.remaining) <= 0.7)
	var charge_ready: bool = sim.charges.any(func(c): return float(c.remaining) <= 1.5)
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
	var injured: bool = sim.hull < sim.max_hull - 25.0
	var vulnerable: bool = sim.shield < sim.max_shield * 0.55
	var crowd: bool = sim.enemies.size() >= 3
	var boss: bool = sim.boss_spawned
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


# Diagnostic choices only: no fake damage, forced kills, injected cards or stages.
# Full Hangar is a *ceiling* check, not a normal new-player starting build.
func _hangar(style: String) -> Dictionary:
	var result := {}
	if style == "max":
		for item in Catalog.HANGAR:
			result[str(item.id)] = int(item.max)
	elif style == "mid":
		for item in Catalog.HANGAR:
			var id: String = str(item.id)
			if id in ["hull","shield","armor","regen","repair","damage","fire_rate","ability_cooldown","ability_power","xp","boss_damage","beam_plating","shield_restart","warp_repairs"]:
				result[id] = mini(2,int(item.max))
			elif id in ["extra_card","pulse_start","seeker_start","signature_rank","reroll_focus"]:
				result[id] = 1
	return result

func _choose_prototype(sim: RefCounted, build_style: String) -> int:
	if build_style != "focused":
		return 0
	var preferred := ["mirror_cell","emergency_safeguard","volatile_core","echo_coil","breach_optics","bastion_lattice","null_harmonics","salvage_charter"]
	if sim.hull >= sim.max_hull * 0.75:
		preferred = ["volatile_core","mirror_cell","emergency_safeguard","echo_coil","breach_optics","bastion_lattice","null_harmonics","salvage_charter"]
	var best := 0
	var rank := 999
	for idx in range(sim.prototype_offers.size()):
		var choice: String = str(sim.prototype_offers[idx])
		var priority: int = preferred.find(choice)
		if priority >= 0 and priority < rank:
			rank = priority
			best = idx
	return best

func _pick_focused(sim: RefCounted) -> void:
	var best := 0
	var best_priority := 999
	# Select only real offered cards. Unlike the baseline bot, avoid occupying
	# all four active slots before getting a damage build off the ground.
	var weapon_order := ["seeker","pulse","arc","lance"]
	if sim.ship_id == "arcwing":
		weapon_order = ["arc","pulse","seeker","lance"]
	elif sim.ship_id == "kestrel" or sim.ship_id == "bulwark":
		weapon_order = ["pulse","seeker","arc","lance"]
	elif sim.ship_id == "haven":
		weapon_order = ["seeker","lance","pulse","arc"]
	var has_counter: bool = sim.active_slots.any(func(id): return id in ["aegis","nova","emp","capacitor","flak","jammer","nova_aegis"])
	for idx in range(sim.cards.size()):
		var card: Dictionary = sim.cards[idx]
		var id: String = str(card.id)
		var rank: int = int(sim.upgrades.get(id,0))
		var priority := 85
		if id == "repair":
			priority = 3 if sim.hull < sim.max_hull * 0.48 else 90
		elif id in weapon_order:
			var position: int = weapon_order.find(id)
			priority = 7 + position * 4 if rank < 5 else (16 + position * 3 if rank < 10 else 80)
		elif id in ["munitions","autoloader"]:
			priority = 12 if rank < 5 else 23
		elif id in ["boss_hunter","finisher"]:
			priority = 9 if rank < 5 and sim.stage >= 2 else 27
		elif id in ["regen","hull","shield","repair_bots"]:
			priority = (8 if sim.hull < sim.max_hull * 0.65 else 20) if rank < 5 else 30
		elif id in ["harvester","targeting"]:
			priority = 17 if sim.stage == 1 and rank < 5 else 32
		elif id in ["armor","coolant","amplifier","ablative","shield_surge","opening_salvo","insulation","afterburn"]:
			priority = 26
		elif card.tag == "ABILITY":
			if rank > 0:
				priority = 18 if rank < 5 else 40
			elif sim.active_slots.size() < Catalog.ACTIVE_SLOTS and not has_counter and id in ["aegis","nova","emp","capacitor"]:
				priority = 12
			elif sim.active_slots.size() < 3 and id in ["overdrive","focus","siphon","mend","wing_drones"]:
				priority = 34
			else:
				priority = 95
		if priority < best_priority:
			best_priority = priority
			best = idx
	sim.choose_card(best)

func _stage_report(sim: RefCounted, status: String) -> Dictionary:
	var boss_hp := -1.0
	var modules_alive := 0
	for enemy in sim.enemies:
		if str(enemy.kind).begins_with("boss") and enemy.kind != "boss_module" and enemy.hp > 0.0:
			boss_hp = float(enemy.hp)
		if enemy.kind == "boss_module" and enemy.hp > 0.0:
			modules_alive += 1
	var levels := {}
	for id in ["pulse","seeker","arc","lance","aegis","nova","mend","flak","siphon","emp","overdrive","capacitor","munitions","autoloader","boss_hunter","shield","hull","regen","repair_bots"]:
		if int(sim.upgrades.get(id,0)) > 0:
			levels[id] = int(sim.upgrades.get(id,0))
	var tail_events: Array = []
	for idx in range(maxi(0,sim.events.size()-4),sim.events.size()):
		tail_events.append(str(sim.events[idx].message))
	return {
		"stage":int(sim.stage), "status":status, "elapsed":snappedf(float(sim.time-sim.stage_start),0.1),
		"hull":snappedf(float(sim.hull),0.1),"max_hull":snappedf(float(sim.max_hull),0.1),
		"shield":snappedf(float(sim.shield),0.1),"level":int(sim.level),
		"kills":int(sim.kills), "boss_spawned":bool(sim.boss_spawned),
		"boss_hp_remaining":snappedf(boss_hp,0.1),"modules_alive":modules_alive,
		"prototypes":sim.prototypes.duplicate(), "route":sim.route_choice, "upgrades":levels,
		"abilities":sim.active_slots.duplicate(), "damage_taken":sim.damage_taken.duplicate(),
		"damage_dealt":sim.damage_dealt.duplicate(), "events":tail_events
	}
