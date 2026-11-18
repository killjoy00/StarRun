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
				var result := _fly_campaign(sim)
				if sim.can_enter_secret():
					var gate := sim.snapshot()
					result.merge(_fly_archive(sim, true))
					if matched:
						var control := Sim.new()
						control.restore(gate)
						result["control"] = _fly_archive(control, false)
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
	var signals: Array[String] = []
	for frame in range(60 * 2500):
		if sim.ended or sim.time - sim.stage_start >= MAX_STAGE_SECONDS:
			break
		if sim.stage_transition_queued:
			if sim.stage == 4:
				citadel_boss_seconds = sim.time - sim.boss_spawn_time
				break
			if not sim.begin_intermission() or not sim.choose_prototype(_choose_prototype(sim, "focused")) or not sim.choose_route("overclock" if sim.hull >= sim.max_hull * 0.72 else "repair") or not sim.advance_stage():
				push_error("Campaign could not advance from world %d" % sim.stage)
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
	return {"campaign_clears":sim.stage_clears, "eligible":sim.can_enter_secret(), "signals":sim.signal_count, "methods":signals, "citadel_boss_seconds":citadel_boss_seconds}

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
	for frame in range(60 * 550):
		if sim.ended or sim.time - sim.stage_start >= MAX_STAGE_SECONDS:
			break
		if sim.secret_intro_pending:
			sim.dismiss_secret_intro()
		if sim.boss_spawned:
			max_phase = maxi(max_phase, sim.archive_phase)
			if not sim.archive_attack.is_empty() and sim.archive_attack not in patterns:
				patterns.append(sim.archive_attack)
		if sim.stage_transition_queued:
			sim.advance_stage()
			break
		if not sim.cards.is_empty():
			_pick_upgrade(sim, "focused")
		if timed and not sim.archive_attack.is_empty():
			_cast_one(sim)
		# Keep a ready active for the next warning. The control spends every
		# active as it comes up, including casts that accidentally hit a lock.
		if not timed:
			_cast(sim, "on_cooldown")
		elif _ready_count(sim) > 1:
			_cast_one(sim)
		sim.step()
	return {"won":sim.won,"hull_fraction":sim.hull / sim.max_hull, "boss_seconds":sim.time - sim.boss_spawn_time if sim.boss_spawned else -1.0,
		"interrupts":sim.beams_cancelled - cancelled, "beams_fired":sim.beams_fired - fired,
		"max_phase":max_phase, "patterns":patterns,
		"economy_ok":sim.payout() == payout and sim.xp == xp and sim.level == level}

func _cast_one(sim: RefCounted) -> void:
	for ability in sim.active_slots:
		if sim.activate(str(ability)):
			return

func _ready_count(sim: RefCounted) -> int:
	return sim.active_slots.filter(func(id): return sim.cooldowns[str(id)] <= 0.0).size()
