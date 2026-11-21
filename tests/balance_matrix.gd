extends SceneTree
# Diagnostic, not a human-player win rate. Ships move and fire automatically.
# Strategies change only active ability use; all bots choose upgrades.
# The same seeds are used across strategies, but combat RNG can shift draft offers.
const Sim = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/catalog.gd")

# Targeted Shieldstorm check (2026-11-16): the shielded build only reorders
# naturally offered cards, never injects an ability, fusion, reward or enemy.
# Compare it under every route and against focused on identical start seeds.
const STRATEGIES := ["never", "on_cooldown", "timed"]
const MAX_STAGE_SECONDS := 540.0

## Experiment knobs: per-world multipliers on spawn rate, enemy health and
## enemy damage, e.g. --spawn=1,1.5,1.5,1.5. Applied to each run's own copy of
## the stage data, so experiments need no edits to data/content.json.
var world_tuning := {}

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
	var artifact_id := "standard"
	var trace := false
	var density := false
	var require_win := false
	var seed_offset := 0
	var stage_limit := 4
	var require_no_world1_clears := false
	var require_no_campaign_wins := false
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
		elif arg.begins_with("--artifact="):
			artifact_id = arg.get_slice("=", 1)
		elif arg.begins_with("--seed-offset="):
			seed_offset = maxi(0, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--stage-limit="):
			stage_limit = int(arg.get_slice("=", 1))
		elif arg == "--require-no-world1-clears":
			require_no_world1_clears = true
		elif arg == "--trace":
			trace = true
		elif arg == "--density":
			density = true
		elif arg == "--require-win":
			require_win = true
		elif arg.begins_with("--spawn=") or arg.begins_with("--health=") or arg.begins_with("--damage="):
			var values := PackedFloat64Array()
			for part in arg.get_slice("=", 1).split(","):
				values.append(float(part))
			if values.size() != 4 or values.has(0.0):
				push_error("%s needs four non-zero per-world values" % arg.get_slice("=", 0))
				quit(2)
				return
			world_tuning[arg.get_slice("=", 0).trim_prefix("--")] = values
		elif arg == "--require-no-campaign-wins":
			require_no_campaign_wins = true
	if build_style not in ["baseline", "focused", "shielded"] or hangar_style not in ["none", "mid", "half", "max"] or route_policy not in ["adaptive", "repair", "overclock", "bounty"] or stage_limit < 1 or stage_limit > 4 or not Catalog.PILOTS.any(func(p): return p.id == pilot_id) or str(Catalog.artifact(artifact_id).id) != artifact_id:
		push_error("Invalid balance diagnostic build, hangar or pilot")
		quit(2)
		return
	if not world_tuning.is_empty():
		print("WORLD_TUNING ", JSON.stringify(world_tuning))
	if hangar_style == "half":
		print("HANGAR_PROFILE ", JSON.stringify(_hangar("half")))
	if require_no_world1_clears and (stage_limit != 1 or hangar_style != "none" or only_difficulty not in ["hard", "insane"]):
		push_error("No-Hangar World 1 gate applies only to Hard/Insane with stage-limit=1")
		quit(2)
		return
	var cells := 0
	var trials := 0
	var faults := 0
	var campaign_wins := 0
	var world1_clears := 0
	var shieldstorm_runs := 0
	var focus5_runs := 0
	var focus10_runs := 0
	var shieldstorm_trigger_worlds := 0
	var pristine_focus_seconds := 0.0
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
				var route_shieldstorm := 0
				var route_focus5 := 0
				var route_focus10 := 0
				var route_triggers := 0
				var route_pristine_seconds := 0.0
				var route_overlap_seconds := 0.0
				var route_unanswered_seconds := 0.0
				var route_boss_seconds := 0.0
				var route_boss_clears := 0
				var enemy_samples := 0
				var enemy_sum := 0
				var empty_samples := 0
				var max_visible_enemies := 0
				var opening_samples := 0
				var opening_enemy_sum := 0
				var total_pilot_procs := 0
				var total_kills := 0
				var total_levels := 0
				for seed_index in range(seeds):
					var seed := 810000 + (seed_offset + seed_index + 1) * 7919
					var result: Dictionary = _trial(seed, ship_id, difficulty, strategy, build_style, hangar_style, pilot_id, route_policy, stage_limit, density, artifact_id)
					if density:
						print("DENSITY_TRACE ", JSON.stringify({
							"seed":seed, "ship":ship_id, "difficulty":difficulty, "artifact":artifact_id, "pilot":pilot_id,
							"hangar":hangar_style, "build":build_style, "route":route_policy,
							"strategy":strategy, "phases":result.density
						}))
					if trace:
						print("CAMPAIGN_TRACE ", JSON.stringify({
							"seed":seed,"ship":ship_id,"difficulty":difficulty,"artifact":artifact_id,"pilot":pilot_id,"strategy":strategy,
							"build":build_style,"hangar":hangar_style,"route":route_policy,
							"routes":result.routes,"stages":result.stages,"final":result.final
						}))
					if build_style == "shielded":
						print("SHIELDED_TRIAL ", JSON.stringify({"seed":seed,"ship":ship_id,"pilot":pilot_id,"difficulty":difficulty,"hangar":hangar_style,"route":route_policy,"won":result.won,"world_clears":result.clears,"shieldstorm":result.shieldstorm,"focus5":result.focus5,"focus10":result.focus10,"shieldstorm_trigger_worlds":result.shieldstorm_trigger_worlds,"pristine_focus_seconds":result.pristine_focus_seconds,"final_level":result.final.level}))
					trials += 1
					world1_clears += 1 if int(result.clears) >= 1 else 0
					faults += int(result.get("fault", false))
					shieldstorm_runs += int(result.shieldstorm)
					focus5_runs += int(result.focus5)
					focus10_runs += int(result.focus10)
					shieldstorm_trigger_worlds += int(result.shieldstorm_trigger_worlds)
					pristine_focus_seconds += float(result.pristine_focus_seconds)
					route_shieldstorm += int(result.shieldstorm)
					route_focus5 += int(result.focus5)
					route_focus10 += int(result.focus10)
					route_triggers += int(result.shieldstorm_trigger_worlds)
					route_pristine_seconds += float(result.pristine_focus_seconds)
					route_overlap_seconds += float(result.overlap_seconds)
					route_unanswered_seconds += float(result.unanswered_overlap_seconds)
					for stage_report in result.stages:
						if str(stage_report.status) == "cleared" and bool(stage_report.boss_spawned):
							route_boss_seconds += float(stage_report.boss_seconds)
							route_boss_clears += 1
					timeouts += int(result.timeout)
					casts += int(result.casts)
					hull += float(result.hull)
					total_kills += int(result.final.kills)
					total_levels += int(result.final.level)
					total_pilot_procs += int(result.pilot_procs.get(pilot_id, 0))
					for density_phase in result.density:
						var stats: Dictionary = result.density[density_phase]
						if not str(density_phase).begins_with("W1/") or str(density_phase) == "W1/boss":
							continue
						enemy_samples += int(stats.samples)
						enemy_sum += int(stats.enemy_sum)
						empty_samples += int(stats.empty_enemy_samples)
						max_visible_enemies = maxi(max_visible_enemies, int(stats.max_visible_enemies))
						if str(density_phase) == "W1/opening":
							opening_samples += int(stats.samples)
							opening_enemy_sum += int(stats.enemy_sum)
					campaigns += int(result.won)
					campaign_wins += int(result.won)
					for stage_index in range(4):
						if int(result.clears) > stage_index:
							clears[stage_index] += 1
				print("BALANCE_MATRIX ", JSON.stringify({
					"ship":ship_id, "difficulty":difficulty, "policy":strategy, "build":build_style, "hangar":hangar_style, "route":route_policy, "pilot":pilot_id, "artifact":artifact_id,
					"seeds":seeds, "world_clears":clears, "campaign_wins":campaigns,
					"timeouts":timeouts, "casts":casts,
					"pilot_procs":total_pilot_procs, "mean_level":snappedf(float(total_levels) / seeds, 0.1), "mean_kills":snappedf(float(total_kills) / seeds, 0.1),
					"w1_mean_visible_enemies":snappedf(float(enemy_sum) / maxf(1.0, float(enemy_samples)), 0.01),
					"w1_opening_visible_enemies":snappedf(float(opening_enemy_sum) / maxf(1.0, float(opening_samples)), 0.01),
					"w1_empty_screen_pct":snappedf(100.0 * float(empty_samples) / maxf(1.0, float(enemy_samples)), 0.1),
					"w1_peak_visible_enemies":max_visible_enemies,
					"mean_final_hull":snappedf(hull / seeds, 0.1),
					"shieldstorm_runs":route_shieldstorm,"focus5_runs":route_focus5,"focus10_runs":route_focus10,"shieldstorm_trigger_worlds":route_triggers,
					"pristine_focus_seconds":snappedf(route_pristine_seconds,0.1),
					"overlap_seconds":snappedf(route_overlap_seconds,0.1),
					"unanswered_overlap_seconds":snappedf(route_unanswered_seconds,0.1),
					"mean_cleared_boss_seconds":snappedf(route_boss_seconds / maxf(1.0, float(route_boss_clears)), 0.1),
					"bosses_cleared":route_boss_clears
				}))
	print("BALANCE_MATRIX_SUMMARY ", JSON.stringify({
		"cells":cells, "seeds_per_cell":seeds, "trials":trials, "faults":faults, "world1_clears":world1_clears, "stage_limit":stage_limit, "campaign_wins":campaign_wins, "build":build_style, "hangar":hangar_style, "route":route_policy,
		"shieldstorm_runs":shieldstorm_runs,"focus5_runs":focus5_runs,"focus10_runs":focus10_runs,"shieldstorm_trigger_worlds":shieldstorm_trigger_worlds,"pristine_focus_seconds":snappedf(pristine_focus_seconds,0.1),
		"method":"scripted autopilot and auto-weapons, automated upgrades, active policy only"
	}))
	if require_win and campaign_wins == 0:
		push_error("Expected at least one genuine four-world victory using real combat, cards and bosses")
	if require_no_world1_clears and world1_clears > 0:
		push_error("%d of %d unupgraded Hard/Insane attempts cleared World 1 (ship %s, pilot %s). Investigate and rebalance before merging." % [world1_clears, trials, only_ship, pilot_id])
	# Difficulty target: with no Hangar upgrades, Normal must never be finished.
	if require_no_campaign_wins and campaign_wins > 0:
		push_error("A run without Hangar upgrades finished the campaign (%d wins)" % campaign_wins)
	quit(1 if cells == 0 or trials == 0 or faults > 0 or (require_win and campaign_wins == 0) or (require_no_world1_clears and world1_clears > 0) or (require_no_campaign_wins and campaign_wins > 0) else 0)

func _trial(seed: int, ship_id: String, difficulty: String, strategy: String, build_style: String = "baseline", hangar_style: String = "none", pilot_id: String = "rookie", route_policy: String = "adaptive", stage_limit: int = 4, track_density: bool = false, artifact_id: String = "standard") -> Dictionary:
	var sim := Sim.new(seed, _hangar(hangar_style), ship_id, pilot_id, difficulty, artifact_id)
	for knob in world_tuning:
		var key: String = {"spawn": "spawn_scale", "health": "health_scale", "damage": "damage_scale"}[knob]
		for world in range(4):
			var spec: Dictionary = sim.content.stages[world]
			spec[key] = float(spec.get(key, 1.0)) * float(world_tuning[knob][world])
	var timed_out := false
	var fault := false
	var stage_reports: Array = []
	var routes: Array = []
	var status := "dead"
	var pristine_focus_seconds := 0.0
	var overlap_seconds := 0.0
	var unanswered_overlap_seconds := 0.0
	var density_by_phase := {}
	for _frame in range(4 * 60 * 600):
		if sim.ended:
			status = "won" if sim.won else "dead"
			break
		if sim.stage_transition_queued:
			stage_reports.append(_stage_report(sim, "cleared"))
			if stage_limit < 4 and sim.stage >= stage_limit:
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
		# Every 0.2 simulated seconds, sample only enemy projectiles inside
		# the actual 540x960 playfield. Pause time, intermissions and drafts
		# contribute no samples. Heavy-beam charge lanes are counted separately.
		# This is read-only instrumentation: no RNG, damage or input changes.
		if track_density and sim.tick % 12 == 0:
			var phase: String = "W%d/%s" % [sim.stage, "boss" if sim.boss_spawned else ("opening" if sim.stage == 1 and sim.time - sim.stage_start < 45.0 else ("mid" if sim.stage == 1 and sim.time - sim.stage_start < 120.0 else "waves"))]
			if not density_by_phase.has(phase):
				density_by_phase[phase] = {
					"samples":0, "bullet_sum":0, "boss_bullet_sum":0,
					"charge_sum":0, "max_visible":0, "over_20":0, "over_40":0,
					"enemy_sum":0, "empty_enemy_samples":0, "max_visible_enemies":0
				}
			var visible := 0
			var boss_owned := 0
			for bullet in sim.bullets:
				var p: Vector2 = bullet.p
				if p.x >= 0.0 and p.x <= Sim.WIDTH and p.y >= 0.0 and p.y <= Sim.HEIGHT:
					visible += 1
					if str(bullet.get("source", "")).begins_with("boss"):
						boss_owned += 1
			var visible_enemies := 0
			for enemy in sim.enemies:
				var enemy_p: Vector2 = enemy.p
				if enemy.hp > 0.0 and enemy_p.x >= 0.0 and enemy_p.x <= Sim.WIDTH and enemy_p.y >= 0.0 and enemy_p.y <= 920.0:
					visible_enemies += 1
			var record: Dictionary = density_by_phase[phase]
			record.enemy_sum += visible_enemies
			record.empty_enemy_samples += int(visible_enemies == 0)
			record.max_visible_enemies = maxi(int(record.max_visible_enemies), visible_enemies)
			record.samples += 1
			record.bullet_sum += visible
			record.boss_bullet_sum += boss_owned
			record.charge_sum += sim.charges.size()
			record.max_visible = maxi(int(record.max_visible), visible)
			record.over_20 += int(visible >= 20)
			record.over_40 += int(visible >= 40)
		# Sample every 0.2s: are bullet and heavy-beam warnings competing
		# for a defensive action that is currently unavailable?
		if sim.tick % 12 == 0 and _danger_overlap(sim):
			overlap_seconds += 12.0 * Sim.DT
			if not _ready_overlap_counter(sim):
				unanswered_overlap_seconds += 12.0 * Sim.DT
		# Measure actual uptime, not just whether the rank was purchased.
		if sim.stage >= 2 and sim.rank_at("shield_focus", 5) and sim.hull >= sim.max_hull - 0.01:
			pristine_focus_seconds += Sim.DT
		sim.step()
		if sim.time - sim.stage_start > MAX_STAGE_SECONDS:
			timed_out = true
			status = "timeout"
			break
	if stage_reports.is_empty() or int(stage_reports[-1].stage) != sim.stage:
		stage_reports.append(_stage_report(sim, status))
	return {
		"clears":int(sim.stage_clears), "won":bool(sim.won), "pilot_procs":sim.pilot_procs.duplicate(),
		"hull":float(sim.hull), "casts":int(sim.ability_uses),
		"timeout":timed_out, "fault":fault, "stages":stage_reports, "routes":routes,
		"shieldstorm":int(sim.upgrades.get("shieldstorm",0)) > 0,
		"focus5":sim.rank_at("shield_focus",5), "focus10":sim.rank_at("shield_focus",10),
		"shieldstorm_trigger_worlds":stage_reports.filter(func(report): return bool(report.shieldstorm_triggered)).size(),
		"pristine_focus_seconds":snappedf(pristine_focus_seconds,0.1),
		"overlap_seconds":snappedf(overlap_seconds,0.1),
		"unanswered_overlap_seconds":snappedf(unanswered_overlap_seconds,0.1),
		"density":density_by_phase,
		"final":{"level":sim.level,"kills":sim.kills,"status":status, "build":build_style}
	}

# Count only overlapping threats aimed near the autopilot's future lane.
# This is a diagnostic, not a forced counter or a source of bonus damage.
func _danger_overlap(sim: RefCounted) -> bool:
	var beam_relevant := false
	for charge in sim.charges:
		var remaining: float = float(charge.remaining)
		if remaining > 0.0 and remaining <= 0.8 and absf(sim.ship_position(sim.time + remaining).x - float(charge.x)) < 45.0:
			beam_relevant = true
			break
	if not beam_relevant:
		return false
	var predicted: Vector2 = sim.ship_position(sim.time + 0.4)
	for bullet in sim.bullets:
		if (bullet.p + bullet.v * 0.4).distance_squared_to(predicted) < 90.0 * 90.0:
			return true
	return false

func _ready_overlap_counter(sim: RefCounted) -> bool:
	if sim.aegis_left > 0.0:
		return true
	for active_id in sim.active_slots:
		if str(active_id) in ["aegis", "nova", "emp", "jammer", "flak", "capacitor", "shieldstorm", "nova_aegis", "stasis_lock", "ghost_signal"] and float(sim.cooldowns.get(str(active_id), 999.0)) <= 0.0:
			return true
	return false


func _pick_upgrade(sim: RefCounted, build_style: String = "baseline") -> void:
	if build_style == "focused":
		_pick_focused(sim)
		return
	if build_style == "shielded":
		_pick_shielded(sim)
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
	# Bots judge a crowd by threat, not body count: a swarm pack reads as one
	# ship (the same rule the simulation uses).
	var crowd: bool = (sim._crowd_count() if sim.has_method("_crowd_count") else sim.enemies.size()) >= 3
	var boss: bool = sim.boss_spawned
	for active_id in sim.active_slots:
		var ability: String = str(active_id)
		var use_now := false
		if ability in ["aegis", "nova_aegis", "shieldstorm"]:
			use_now = urgent or near_hit or (ability == "shieldstorm" and vulnerable and sim.bullets.size() >= 6)
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
	elif style == "half":
		# Half the Cores of a full Hangar, spent the way a player spreading
		# upgrades would: always buy the cheapest next rank available.
		var total := 0
		for item in Catalog.HANGAR:
			for rank in range(int(item.max)):
				total += Catalog.price(str(item.id), rank)
		var budget := total / 2
		for item in Catalog.HANGAR:
			result[str(item.id)] = 0
		while true:
			var best_id := ""
			var best_price := 1 << 30
			for item in Catalog.HANGAR:
				var id: String = str(item.id)
				if int(result[id]) < int(item.max):
					var next_price := Catalog.price(id, int(result[id]))
					if next_price < best_price:
						best_price = next_price
						best_id = id
			if best_id.is_empty() or best_price > budget:
				break
			budget -= best_price
			result[best_id] = int(result[best_id]) + 1
	elif style == "mid":
		for item in Catalog.HANGAR:
			var id: String = str(item.id)
			if id in ["hull","shield","armor","regen","repair","damage","fire_rate","ability_cooldown","ability_power","xp","boss_damage","beam_plating","shield_restart","warp_repairs"]:
				result[id] = mini(2,int(item.max))
			elif id in ["extra_card","pulse_start","seeker_start","signature_rank","reroll_focus"]:
				result[id] = 1
	return result

func _choose_prototype(sim: RefCounted, build_style: String) -> int:
	if build_style not in ["focused", "shielded"]:
		return 0
	if build_style == "shielded":
		return _prototype_by_order(sim, ["mirror_cell","bastion_lattice","emergency_safeguard","null_harmonics","breach_optics","echo_coil","volatile_core","salvage_charter"])
	var preferred := ["mirror_cell","emergency_safeguard","volatile_core","echo_coil","breach_optics","bastion_lattice","null_harmonics","salvage_charter"]
	if sim.hull >= sim.max_hull * 0.75:
		preferred = ["volatile_core","mirror_cell","emergency_safeguard","echo_coil","breach_optics","bastion_lattice","null_harmonics","salvage_charter"]
	return _prototype_by_order(sim, preferred)

func _prototype_by_order(sim: RefCounted, preferred: Array) -> int:
	var best := 0
	var rank := 999
	for idx in range(sim.prototype_offers.size()):
		var choice: String = str(sim.prototype_offers[idx])
		var priority: int = preferred.find(choice)
		if priority >= 0 and priority < rank:
			rank = priority
			best = idx
	return best

func _pick_shielded(sim: RefCounted) -> void:
	# A realistic defensive build: purchase only cards in the actual hand.
	# Secure enough automatic DPS for the opener, then invest in Aegis + Flak
	# and Shield Focus. Avoid accidentally fusing Nova/Aegis or Barrage/Flak
	# before the intended components both reach rank 5.
	var formed: bool = int(sim.upgrades.get("shieldstorm", 0)) > 0
	var order := ["seeker","pulse","arc","lance"]
	if sim.ship_id == "arcwing":
		order = ["arc","pulse","seeker","lance"]
	elif sim.ship_id in ["kestrel","bulwark"]:
		order = ["pulse","seeker","arc","lance"]
	elif sim.ship_id == "haven":
		order = ["seeker","lance","pulse","arc"]
	var best := 0
	var best_priority := 999
	for index in range(sim.cards.size()):
		var card: Dictionary = sim.cards[index]
		var id: String = str(card.id)
		var rank: int = int(sim.upgrades.get(id, 0))
		var priority := 85
		if id == "repair":
			priority = 0 if sim.hull < sim.max_hull * 0.35 else (28 if sim.stage >= 2 and sim.hull < sim.max_hull * 0.75 else 95)
		elif id == "shield_focus":
			priority = 3 if rank < 5 else (6 if rank < 10 else 95)
		elif not formed and id in ["aegis", "flak"] and rank < 5:
			# Claim the second component before filling the four-slot bar.
			priority = 6 if rank == 0 else 5
			if not sim.fusion_target(id).is_empty():
				priority = 1
		elif id in order:
			var position: int = order.find(id)
			priority = 4 + position * 2 if rank < 5 else (16 + position * 3 if rank < 10 else 90)
		elif id in ["munitions","autoloader"]:
			priority = 11 if rank < 5 else 25
		elif id in ["shield","regen","repair_bots","hull"]:
			priority = (11 if sim.hull < sim.max_hull * 0.7 else 18) if rank < 5 else 29
		elif id in ["boss_hunter","finisher"]:
			priority = 18 if rank < 5 else 34
		elif id in ["harvester","targeting"]:
			priority = 20 if sim.stage == 1 and rank < 5 else 40
		elif id in ["armor","coolant","amplifier","ablative","shield_surge","insulation","afterburn"]:
			priority = 30
		elif card.tag == "ABILITY":
			# Nova+Aegis and Barrage+Flak are competing fusions; preserve
			# the starting active's effectiveness without prematurely fusing.
			if not formed and id in ["nova", "barrage"] and rank >= 3:
				priority = 98
			elif rank > 0:
				priority = 39 if rank < 5 else 55
			elif sim.active_slots.size() < 3 and id in ["mend","capacitor","deflector"]:
				priority = 45
			else:
				priority = 98
		if priority < best_priority:
			best_priority = priority
			best = index
	sim.choose_card(best)

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
	for id in ["pulse","seeker","arc","lance","aegis","nova","mend","flak","siphon","emp","overdrive","capacitor","munitions","autoloader","boss_hunter","shield_focus","shieldstorm","shield","hull","regen","repair_bots"]:
		if int(sim.upgrades.get(id,0)) > 0:
			levels[id] = int(sim.upgrades.get(id,0))
	var tail_events: Array = []
	for idx in range(maxi(0,sim.events.size()-4),sim.events.size()):
		tail_events.append(str(sim.events[idx].message))
	return {
		"stage":int(sim.stage), "status":status, "elapsed":snappedf(float(sim.time-sim.stage_start),0.1),
		"boss_seconds":snappedf(maxf(0.0, float(sim.time - sim.boss_spawn_time)), 0.1) if sim.boss_spawned else 0.0,
		"hull":snappedf(float(sim.hull),0.1),"max_hull":snappedf(float(sim.max_hull),0.1),
		"shield":snappedf(float(sim.shield),0.1),"level":int(sim.level),
		"shieldstorm_triggered":bool(sim.shieldstorm_pulse_used),
		"shield_focus_rank":int(sim.upgrades.get("shield_focus",0)),
		"kills":int(sim.kills), "boss_spawned":bool(sim.boss_spawned),
		"boss_hp_remaining":snappedf(boss_hp,0.1),"modules_alive":modules_alive,
		"late_boss_phase":int(sim.late_boss_phase) if sim.stage in [3,4] and sim.boss_spawned else -1,
		"prototypes":sim.prototypes.duplicate(), "route":sim.route_choice, "upgrades":levels,
		"abilities":sim.active_slots.duplicate(), "damage_taken":sim.damage_taken.duplicate(),
		"damage_dealt":sim.damage_dealt.duplicate(), "events":tail_events
	}
