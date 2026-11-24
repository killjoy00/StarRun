extends "res://tests/balance_matrix.gd"
## Play the route from launch using real drafts, timed inputs and actual boss damage.
## Use --ship, --pilot and --difficulty to shard the full loadout matrix.
const Archive = preload("res://scripts/hidden_sector.gd")

func _run() -> void:
	var options := {}
	for arg in OS.get_cmdline_user_args():
		if arg.contains("="):
			options[arg.get_slice("=", 0)] = arg.get_slice("=", 1)
	var matched := "--matched" in OS.get_cmdline_user_args()
	var expedition := "--expedition" in OS.get_cmdline_user_args()
	var require_win := "--require-win" in OS.get_cmdline_user_args()
	var trials := 0
	var wins := 0
	var failed := false
	var minimum_boss_seconds: float = float(options.get("--min-boss-seconds", "0"))
	for ship in Catalog.SHIPS:
		if options.get("--ship", ship.id) != ship.id:
			continue
		for pilot in Catalog.PILOTS:
			if options.get("--pilot", pilot.id) != pilot.id:
				continue
			for difficulty in Catalog.DIFFICULTIES:
				if options.get("--difficulty", difficulty) != difficulty:
					continue
				var seed_offset := int(options.get("--seed-offset", "1"))
				var hangar_style: String = options.get("--hangar", "mid" if difficulty == "normal" else "max")
				var sim := Sim.new(810000 + (seed_offset + 1) * 7919, _hangar(hangar_style), ship.id, pilot.id, difficulty)
				if expedition and not sim.enable_expedition_rules():
					push_error("Production expedition rules refused")
					quit(2)
					return
				var result := _fly_campaign(sim)
				if expedition:
					result["fixture_ok"] = _redesigned_fixture(sim.seed_value, ship.id, pilot.id, difficulty, hangar_style)
					failed = failed or not bool(result.fixture_ok) or bool(result.get("fault",false))
				if sim.can_enter_secret():
					var gate := sim.snapshot()
					result.merge(_fly_archive(sim, true))
					if expedition:
						failed = failed or int(result.get("archive_version",0)) < 4 or not bool(result.get("economy_ok",false)) or bool(result.get("timeout",false))
					if matched:
						var control := Sim.new()
						control.restore(gate)
						result["control"] = _fly_archive(control, false)
						if expedition:
							failed = failed or int(result.control.get("archive_version",0)) < 4 or not bool(result.control.get("economy_ok",false)) or bool(result.control.get("timeout",false))
				result.merge({"ship":ship.id,"pilot":pilot.id,"difficulty":difficulty,"hangar":hangar_style,"seed":sim.seed_value})
				print("ARCHIVE_TRIAL ", JSON.stringify(result))
				trials += 1
				wins += int(result.get("won", false))
				failed = failed or (result.has("economy_ok") and not bool(result.economy_ok))
				if bool(result.get("won", false)):
					var saw_all: bool = result.get("patterns", []).size() == Archive.ATTACKS.size()
					failed = failed or not saw_all or int(result.get("max_phase", -1)) != 2
					if float(result.get("boss_seconds", -1.0)) < minimum_boss_seconds:
						push_error("Custodian cleared too quickly (%.1fs < %.1fs expected)" % [float(result.boss_seconds), minimum_boss_seconds])
						failed = true
	print("ARCHIVE MATRIX: %d / %d cleared" % [wins, trials])
	quit(0 if trials > 0 and not failed and (not require_win or wins == trials) else 1)

func _fly_campaign(sim: RefCounted) -> Dictionary:
	var citadel_boss_seconds := 0.0
	var fault := false
	var signals: Array[String] = []
	for frame in range(60 * 2500):
		if sim.ended or sim.time - sim.stage_start >= MAX_STAGE_SECONDS:
			break
		if sim.stage_transition_queued:
			if sim.stage == 4:
				citadel_boss_seconds = sim.time - sim.boss_spawn_time
				break
			if not _advance_campaign(sim):
				push_error("Campaign could not advance from world %d" % sim.stage)
				fault = true
				break
		elif not sim.pending_build_choices.is_empty():
			sim._auto_resolve_build_choices()
			if not sim.pending_build_choices.is_empty():
				fault = true
				break
		elif not sim.cards.is_empty():
			_pick_upgrade(sim, "focused")
		else:
			if sim.signal_status == "offer":
				var method := "courier" if sim.stage == 2 else "cast"
				sim.choose_signal(method)
				signals.append(method)
			if sim.signal_cast_window():
				_cast_one(sim)
			_cast(sim, "timed")
			sim.step()
	var campaign_timeout: bool = not sim.ended and not sim.stage_transition_queued
	fault = fault or campaign_timeout
	return {"campaign_timeout":campaign_timeout,"campaign_clears":sim.stage_clears, "eligible":sim.can_enter_secret(), "signals":sim.signal_count, "methods":signals, "citadel_boss_seconds":citadel_boss_seconds,"fault":fault}

func _advance_campaign(sim: RefCounted) -> bool:
	if not sim.begin_intermission():
		return false
	if sim.intermission_step == "prototype" and not sim.choose_prototype(_choose_prototype(sim,"focused")):
		return false
	var group := "overclock" if sim.hull >= sim.max_hull * 0.72 else "repair"
	if not sim.choose_route_policy(group):
		return false
	if sim.intermission_step == "mutation" and not sim.choose_lab_mutation("skip"):
		return false
	return sim.advance_stage()

# This isolated phase/restore fixture is intentionally NOT a natural campaign
# or a win-rate observation. It covers the redesigned boss even for a loadout
# that fails to qualify naturally in the sampled seeds.
func _redesigned_fixture(seed: int, ship: String, pilot: String, difficulty: String, hangar: String) -> bool:
	var fixture := Sim.new(seed,_hangar(hangar),ship,pilot,difficulty)
	if not fixture.enable_expedition_rules():
		return false
	fixture.stage = 4
	fixture.stage_clears = 4
	fixture.signal_count = 2
	fixture.stage_transition_queued = true
	var locked: int = fixture.payout()
	if not fixture.enter_secret() or fixture.archive_challenge_version < 4:
		return false
	fixture.dismiss_secret_intro()
	fixture._spawn_boss()
	fixture.dismiss_secret_intro()
	var core: Dictionary = fixture._boss_core()
	if core.is_empty() or fixture._alive_modules("archive_emitter") != 2:
		return false
	var xp: float = fixture.xp
	var kills: int = fixture.kills
	fixture._damage_enemy(core,999999999.0,"nova")
	fixture._damage_enemy(core,999999999.0,"nova")
	if fixture._alive_modules("archive_emitter") != 0 or fixture.xp != xp or fixture.kills != kills:
		return false
	fixture.archive_next_attack = fixture.time
	fixture._update_archive_attack()
	if fixture.archive_attack.is_empty():
		return false
	fixture.time = fixture.archive_attack_until - 1.0
	var before: int = fixture.beams_cancelled
	_cast_one(fixture)
	if fixture.beams_cancelled != before + 1 or not fixture.archive_attack.is_empty() or fixture.payout() != locked:
		return false
	var snap: Dictionary = fixture.snapshot()
	var restored := Sim.new()
	return restored.restore(snap) and restored.snapshot() == snap and restored.archive_challenge_version == fixture.archive_challenge_version

func _fly_archive(sim: RefCounted, timed: bool) -> Dictionary:
	if not sim.enter_secret():
		return {"won":false}
	var xp: float = sim.xp
	var level: int = sim.level
	var payout: int = sim.payout()
	var fired: int = sim.beams_fired
	var cancelled: int = sim.beams_cancelled
	var max_phase: int = -1
	var patterns: Array[String] = []
	var min_boss_hull := 1.0
	var boss_damage_start := -1.0
	var damage_total := 0.0
	for frame in range(60 * 550):
		if sim.ended or sim.time - sim.stage_start >= MAX_STAGE_SECONDS:
			break
		if sim.secret_intro_pending:
			sim.dismiss_secret_intro()
		if sim.boss_spawned:
			damage_total = 0.0
			for value in sim.damage_taken.values():
				damage_total += float(value)
			if boss_damage_start < 0.0:
				boss_damage_start = damage_total
			min_boss_hull = minf(min_boss_hull, sim.hull / sim.max_hull)
			max_phase = maxi(max_phase, sim.archive_phase)
			if not sim.archive_attack.is_empty() and sim.archive_attack not in patterns:
				patterns.append(sim.archive_attack)
		if sim.stage_transition_queued:
			sim.advance_stage()
			break
		if not sim.pending_build_choices.is_empty():
			sim._auto_resolve_build_choices()
			continue
		if not sim.cards.is_empty():
			_pick_upgrade(sim, "focused")
		var reserve: bool = timed and sim.boss_spawned and sim.archive_challenge_version >= 4 and (not sim.archive_attack.is_empty() or sim.archive_next_attack - sim.time <= 1.8)
		if timed and not sim.archive_attack.is_empty() and (not reserve or sim.archive_precise_counter_window()):
			_cast_one(sim)
		# Keep a ready active for the next warning. Cooldown-only does not
		# respond to the precise timing cue.
		if not timed:
			_cast(sim, "on_cooldown")
		elif not reserve and _ready_count(sim) > 1:
			_cast_one(sim)
		sim.step()
	damage_total = 0.0
	for value in sim.damage_taken.values():
		damage_total += float(value)
	var remaining_core: Dictionary = sim._boss_core()
	return {"won":sim.won,"hull_fraction":sim.hull / sim.max_hull, "min_boss_hull_fraction":minf(min_boss_hull, sim.hull / sim.max_hull),"boss_damage":maxf(0.0,damage_total-boss_damage_start) if boss_damage_start >= 0.0 else 0.0,"core_fraction":float(remaining_core.hp)/maxf(1.0,float(remaining_core.max_hp)) if not remaining_core.is_empty() else 0.0,"boss_seconds":sim.time - sim.boss_spawn_time if sim.boss_spawned else -1.0,
		"archive_version":sim.archive_challenge_version,"remaining_emitters":sim._alive_modules("archive_emitter"),"timeout":not sim.ended and not sim.stage_transition_queued,
		"interrupts":sim.beams_cancelled - cancelled, "beams_fired":sim.beams_fired - fired,
		"max_phase":max_phase, "patterns":patterns,
		"economy_ok":sim.payout() == payout and sim.xp == xp and sim.level == level}

func _cast_one(sim: RefCounted) -> void:
	for ability in sim.active_slots:
		if sim.activate(str(ability)):
			return

func _ready_count(sim: RefCounted) -> int:
	return sim.active_slots.filter(func(id): return sim.cooldowns[str(id)] <= 0.0).size()
