extends SceneTree
# Diagnostic, not a human-player win rate. Ships move and fire automatically.
# Strategies change only active ability use; all bots choose upgrades.
# The same seeds are used across strategies, but combat RNG can shift draft offers.
const Sim = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Progress = preload("res://scripts/meta_progress.gd")

# Targeted Shieldstorm check (2026-11-16): the shielded build only reorders
# naturally offered cards, never injects an ability, fusion, reward or enemy.
# Compare it under every route and against focused on identical start seeds.
const STRATEGIES := ["never", "on_cooldown", "timed"]
const MAX_STAGE_SECONDS := 540.0
# Long low-power boss fights are valid in a fresh-profile progression run.
# At 15 minutes in one world, model the actual player's abandon action:
# no settlement, no Cores, no achievements, and a new seed next attempt.
const PROGRESSION_STAGE_SECONDS := 900.0

## Experiment knobs: per-world multipliers on spawn rate, enemy health and
## enemy damage, e.g. --spawn=1,1.5,1.5,1.5. Applied to each run's own copy of
## the stage data, so experiments need no edits to data/content.json.
var world_tuning := {}
var start_world := 1 # --start-world=N: skip to World N with catch-up drafts.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var seeds := 1
	var progression_runs := 0
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
	var require_world1_clears := 0 # --require-world1-clears=N: Normal no-Hangar floor.
	var require_no_campaign_wins := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--progression-runs="):
			progression_runs = int(arg.get_slice("=", 1))
		elif arg.begins_with("--seeds="):
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
		elif arg.begins_with("--require-world1-clears="):
			require_world1_clears = maxi(0, int(arg.get_slice("=", 1)))
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
		elif arg.begins_with("--start-world="):
			start_world = clampi(int(arg.get_slice("=", 1)), 1, 4)
		elif arg == "--require-no-campaign-wins":
			require_no_campaign_wins = true
	if build_style not in ["baseline", "focused", "shielded"] or not (hangar_style in ["none", "mid", "half", "max"] or (hangar_style.begins_with("p") and hangar_style.substr(1).is_valid_int())) or route_policy not in ["adaptive", "repair", "overclock", "bounty"] or stage_limit < 1 or stage_limit > 4 or not Catalog.PILOTS.any(func(p): return p.id == pilot_id) or str(Catalog.artifact(artifact_id).id) != artifact_id:
		push_error("Invalid balance diagnostic build, hangar or pilot")
		quit(2)
		return
	if progression_runs != 0:
		if progression_runs < 1 or progression_runs > 200 or start_world != 1 or stage_limit != 4 or hangar_style != "none" or only_ship not in ["", "vanguard"] or pilot_id != "rookie" or artifact_id != "standard" or only_strategy not in STRATEGIES or only_difficulty not in ["", "normal"] or require_win or require_no_world1_clears or require_no_campaign_wins or require_world1_clears > 0:
			push_error("Progression mode requires fresh Normal Vanguard/Vale, a specified active strategy and full campaigns (1-200 runs)")
			quit(2)
			return
		_run_progression(progression_runs, seed_offset, only_strategy, build_style, route_policy)
		return
	if not world_tuning.is_empty():
		print("WORLD_TUNING ", JSON.stringify(world_tuning))
	if start_world > 1:
		print("START_WORLD ", start_world)
	if hangar_style == "half" or hangar_style.begins_with("p"):
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
	if require_world1_clears > 0 and world1_clears < require_world1_clears:
		push_error("World 1 floor: %d clears, need at least %d" % [world1_clears, require_world1_clears])
	quit(1 if cells == 0 or trials == 0 or faults > 0 or (require_win and campaign_wins == 0) or (require_no_world1_clears and world1_clears > 0) or (require_no_campaign_wins and campaign_wins > 0) or (require_world1_clears > 0 and world1_clears < require_world1_clears) else 0)

# Follow one fresh, offline profile through actual campaigns. Each result is
# settled by the production progression code, then affordable Hangar ranks
# are bought at the real catalog price. No injected XP, cores or fake victories.
# Keep Vanguard/Vale fixed so the matched control isolates balance and economy.
func _run_progression(count: int, offset: int, strategy: String, build_style: String, route_policy: String) -> void:
	var profile := {"cores":0, "hangar":Catalog.defaults(), "hangar_paid":{}, "ships_owned":["vanguard"], "pilots_owned":["rookie"], "last_paid_run":-1}
	Progress.prepare(profile)
	var total_cost := 0
	var total_ranks := 0
	for item in Catalog.HANGAR:
		total_ranks += int(item.max)
		for rank in range(int(item.max)):
			total_cost += Catalog.price(str(item.id), rank)
	var earned_total := 0
	var spent_total := 0
	var bought_total := 0
	var first_clears := [0, 0, 0, 0]
	var wins := 0
	var abandoned := 0
	var completed := 0
	var seconds := 0.0
	var no_buy_streak := 0
	var max_no_buy_streak := 0
	var first_max := 0
	print("PROGRESSION_CONFIG ", JSON.stringify({"runs":count, "seed_offset":offset, "strategy":strategy, "build":build_style, "route":route_policy, "ship":"vanguard", "pilot":"rookie", "hangar_cost":total_cost, "hangar_ranks":total_ranks, "world_tuning":world_tuning, "stage_timeout_seconds":PROGRESSION_STAGE_SECONDS}))
	for run_index in range(1, count + 1):
		var seed := 810000 + (offset + run_index) * 7919
		var before := int(profile.cores)
		var result := _trial(seed, "vanguard", "normal", strategy, build_style, "none", "rookie", route_policy, 4, false, "standard", profile)
		var status: String = str(result.final.status)
		var was_abandoned: bool = bool(result.timeout) and not bool(result.fault) and status == "timeout"
		if bool(result.fault) or (not was_abandoned and (result.settlement.is_empty() or status not in ["won", "dead"])):
			print("PROGRESSION_FAILURE ", JSON.stringify({"run":run_index, "seed":seed, "fault":result.fault, "timeout":result.timeout, "final":result.final, "stages":result.stages, "hangar":profile.hangar, "reason":result.fault_reason}))
			push_error("Unsettled or invalid progression run %d" % run_index)
			quit(1)
			return
		var earned := 0
		if was_abandoned:
			abandoned += 1
			if not result.settlement.is_empty() or bool(result.won):
				push_error("Abandoned progression run incorrectly settled")
				quit(1)
				return
			print("PROGRESSION_ABANDON ", JSON.stringify({"run":run_index,"seed":seed,"reason":"world exceeded 900 simulated seconds","stages":result.stages}))
		else:
			completed += 1
			earned = int(result.settlement.earned)
			if earned != int(result.final.cores):
				push_error("Production payout mismatch at run %d" % run_index)
				quit(1)
				return
		if int(profile.cores) != before + earned or int(profile.achievement_stats.finished_runs) != completed:
			push_error("Production settlement mismatch at run %d" % run_index)
			quit(1)
			return
		earned_total += earned
		seconds += float(result.final.seconds)
		wins += int(result.won)
		# First clears refer to settled runs, which actually advance the profile.
		if not was_abandoned:
			for world in range(4):
				if int(result.clears) > world and int(first_clears[world]) == 0:
					first_clears[world] = run_index
		var purchases := []
		while true:
			var best_id := ""
			var best_price := 1 << 30
			for item in Catalog.HANGAR:
				var id: String = str(item.id)
				var rank := int(profile.hangar[id])
				if rank >= int(item.max):
					continue
				var price := Catalog.price(id, rank)
				if price < best_price:
					best_id = id
					best_price = price
			if best_id.is_empty() or best_price > int(profile.cores):
				break
			profile.cores = int(profile.cores) - best_price
			profile.hangar[best_id] = int(profile.hangar[best_id]) + 1
			profile.hangar_paid[best_id] = int(profile.hangar_paid.get(best_id, 0)) + best_price
			spent_total += best_price
			bought_total += 1
			purchases.append({"id":best_id, "rank":profile.hangar[best_id], "price":best_price})
		if int(profile.cores) + spent_total != earned_total or Catalog.refund(profile.hangar, profile.hangar_paid) != spent_total:
			push_error("Progression Core ledger mismatch at run %d" % run_index)
			quit(1)
			return
		no_buy_streak = no_buy_streak + 1 if purchases.is_empty() and bought_total < total_ranks else 0
		max_no_buy_streak = maxi(max_no_buy_streak, no_buy_streak)
		if bought_total == total_ranks and first_max == 0:
			first_max = run_index
		print("PROGRESSION_RUN ", JSON.stringify({"run":run_index,"seed":seed,"clears":result.clears,"won":result.won,"status":"abandoned" if was_abandoned else status,"seconds":result.final.seconds,"casts":result.casts,"cores_earned":earned,"cores_banked":profile.cores,"cores_spent_total":spent_total,"cores_earned_total":earned_total,"ranks_owned":bought_total,"rank_pct":100.0 * bought_total / total_ranks,"cost_pct":100.0 * spent_total / total_cost,"purchases":purchases,"unlocked":result.settlement.get("unlocked", []),"achievements":result.settlement.get("awarded", []),"hangar":profile.hangar,"stages":result.stages}))
	print("PROGRESSION_SUMMARY ", JSON.stringify({"runs":count,"strategy":strategy,"seed_offset":offset,"completed":completed,"abandoned":abandoned,"wins":wins,"first_clears":first_clears,"first_win":first_clears[3],"first_max_hangar":first_max,"max_no_purchase_streak":max_no_buy_streak,"cores_earned":earned_total,"cores_spent":spent_total,"cores_banked":profile.cores,"ranks_owned":bought_total,"rank_pct":100.0 * bought_total / total_ranks,"cost_pct":100.0 * spent_total / total_cost,"combat_minutes":seconds / 60.0,"ships_owned":profile.ships_owned,"pilots_owned":profile.pilots_owned}))
	quit(0)

func _trial(seed: int, ship_id: String, difficulty: String, strategy: String, build_style: String = "baseline", hangar_style: String = "none", pilot_id: String = "rookie", route_policy: String = "adaptive", stage_limit: int = 4, track_density: bool = false, artifact_id: String = "standard", progression_profile: Variant = null) -> Dictionary:
	var hangar: Dictionary = _hangar(hangar_style) if progression_profile == null else progression_profile.hangar
	var sim := Sim.new(seed, hangar, ship_id, pilot_id, difficulty, artifact_id)
	for knob in world_tuning:
		var key: String = {"spawn": "spawn_scale", "health": "health_scale", "damage": "damage_scale"}[knob]
		for world in range(4):
			var spec: Dictionary = sim.content.stages[world]
			spec[key] = float(spec.get(key, 1.0)) * float(world_tuning[knob][world])
	if start_world > 1 and not sim.begin_at_world(start_world):
		push_error("begin_at_world(%d) refused" % start_world)
	var timed_out := false
	var fault := false
	var fault_reason := ""
	var stage_reports: Array = []
	var routes: Array = []
	var status := "dead"
	var pristine_focus_seconds := 0.0
	var overlap_seconds := 0.0
	var unanswered_overlap_seconds := 0.0
	var density_by_phase := {}
	var stage_seconds := PROGRESSION_STAGE_SECONDS if progression_profile != null else MAX_STAGE_SECONDS
	var frame_budget := 4 * 60 * (int(stage_seconds) + 60)
	var old_watchdog_reported_stage := 0
	var frame_count := 0
	for _frame in range(frame_budget):
		frame_count += 1
		if sim.ended:
			status = "won" if sim.won else "dead"
			break
		if sim.stage_transition_queued and sim.skipping_worlds():
			# Skipped at launch: Prototype picks only, then the one route.
			if sim.intermission_step == "prototype":
				if not sim.choose_prototype(_choose_prototype(sim, build_style)):
					fault = true
					break
				continue
			if sim.intermission_step == "route":
				if not sim.choose_route("repair") or not sim.advance_stage():
					fault = true
					break
				routes.append("repair")
				continue
			fault = true
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
			if progression_profile != null and not sim.cards.is_empty():
				fault = true
				fault_reason = "Draft choice failed to clear cards: %s" % str(sim.cards)
				break
			continue
		_cast(sim, strategy)
		# An active can finish the boss, end the run, or open a draft before
		# the next simulation tick. Those are valid gameplay transitions,
		# not stalled combat. Let the next iteration handle them explicitly.
		if sim.ended or sim.stage_transition_queued or not sim.cards.is_empty():
			continue
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
					"enemy_sum":0, "empty_enemy_samples":0, "max_visible_enemies":0,
					"fill_sum":0.0, "flow_sum":0.0
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
			record.fill_sum += float(sim._crowd_count()) / maxf(1.0, float(sim._enemy_limit()))
			record.flow_sum += float(sim.spawn_flow()) if sim.has_method("spawn_flow") else 1.0
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
		var before_tick: int = sim.tick
		sim.step()
		if progression_profile != null and sim.tick == before_tick and not sim.ended and not sim.stage_transition_queued and sim.cards.is_empty():
			fault = true
			fault_reason = "Combat clock stalled: stage=%d tick=%d transition=%s intermission=%s merchant=%s secret_intro=%s pending_build_choices=%s" % [sim.stage, sim.tick, sim.stage_transition_queued, sim.intermission_step, sim.merchant_state, sim.secret_intro_pending, sim.pending_build_choices]
			break
		if progression_profile != null and sim.time - sim.stage_start > MAX_STAGE_SECONDS and old_watchdog_reported_stage != sim.stage:
			old_watchdog_reported_stage = sim.stage
			print("PROGRESSION_LONG_FIGHT ", JSON.stringify({"seed":seed,"stage":sim.stage,"at_previous_timeout":_stage_report(sim,"long_fight")}))
		if sim.time - sim.stage_start > stage_seconds and not sim.ended and not sim.stage_transition_queued:
			timed_out = true
			status = "timeout"
			break
	if progression_profile != null and frame_count >= frame_budget and not sim.ended and not timed_out:
		fault = true
		fault_reason = "Frame budget exhausted without a settled campaign"
	if fault and fault_reason.is_empty():
		fault_reason = "Transition or intermission action failed"
	if stage_reports.is_empty() or int(stage_reports[-1].stage) != sim.stage:
		stage_reports.append(_stage_report(sim, status))
	var settlement := {}
	if progression_profile != null and sim.ended and not fault and not timed_out:
		settlement = Progress.settle(progression_profile, sim)
	return {
		"settlement":settlement,
		"clears":int(sim.stage_clears), "won":bool(sim.won), "pilot_procs":sim.pilot_procs.duplicate(),
		"hull":float(sim.hull), "casts":int(sim.ability_uses),
		"timeout":timed_out, "fault":fault, "fault_reason":fault_reason, "stages":stage_reports, "routes":routes,
		"shieldstorm":int(sim.upgrades.get("shieldstorm",0)) > 0,
		"focus5":sim.rank_at("shield_focus",5), "focus10":sim.rank_at("shield_focus",10),
		"shieldstorm_trigger_worlds":stage_reports.filter(func(report): return bool(report.shieldstorm_triggered)).size(),
		"pristine_focus_seconds":snappedf(pristine_focus_seconds,0.1),
		"overlap_seconds":snappedf(overlap_seconds,0.1),
		"unanswered_overlap_seconds":snappedf(unanswered_overlap_seconds,0.1),
		"density":density_by_phase,
		"final":{"level":sim.level,"kills":sim.kills,"status":status, "build":build_style, "cores":sim.payout(), "seconds":snappedf(sim.time,1.0)}
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
		elif ability in ["prism", "overload", "chrono", "reactor_surge", "guard_drones"]:
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
	elif style == "half" or (style.begins_with("p") and style.substr(1).is_valid_int()):
		# A share of the Cores of a full Hangar ("half" = 50%, "p25" = 25%),
		# spent the way a player spreading upgrades would: always buy the
		# cheapest next rank available.
		result = Catalog.share_hangar(50 if style == "half" else int(style.substr(1)))
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
