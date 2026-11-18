extends SceneTree
## Fast, deterministic 6 ships x 3 difficulties x 3 Hangar levels x 2 bosses.
## This verifies actual combat/targeting and phase gates, not human win rates.
const Sim = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/catalog.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("LATE BOSS PHASE: " + message)

func _hangar(style: String) -> Dictionary:
	var result := {}
	for entry in Catalog.HANGAR:
		var id: String = str(entry.id)
		var maximum: int = int(entry.max)
		if style == "max":
			result[id] = maximum
		elif style == "mid":
			result[id] = mini(2, maximum)
	return result

func _alive_parts(sim: RefCounted, role: String) -> Array:
	return sim.enemies.filter(func(e): return e.kind == "boss_module" and e.hp > 0.0 and str(e.role) == role)

func _destroy_parts(sim: RefCounted, role: String) -> void:
	# The array of initial targets is fixed, even when destroying the final
	# one immediately spawns new phase objectives into sim.enemies.
	var batch: Array = _alive_parts(sim, role)
	for part in batch:
		sim._damage_enemy(part, 999999999.0, "nova")

func _case(ship_id: String, difficulty: String, hangar_style: String, stage: int) -> void:
	var sim := Sim.new(362000 + stage, _hangar(hangar_style), ship_id, "rookie", difficulty)
	sim.stage = stage
	sim._spawn_boss()
	var core: Dictionary = sim._boss_core()
	var role: String = "vent" if stage == 3 else "pylon"
	var heading: String = "%s/%s/%s/W%d" % [ship_id, difficulty, hangar_style, stage]
	var initial: int = sim._alive_modules(role)
	_check(initial == 2 and sim.late_boss_phase == 0, heading + " begins with two targetable parts")
	var selected: Dictionary = sim._nearest(sim.ship_position())
	_check(not selected.is_empty() and selected.kind == "boss_module", heading + " auto-targets objectives")

	# Even shots colliding with the wide core should do useful module damage.
	var pre: float = core.hp
	var part: Dictionary = _alive_parts(sim, role)[0]
	var part_hp: float = part.hp
	sim._damage_enemy(core, 100.0, "pulse")
	_check(is_equal_approx(float(core.hp), pre) and part.hp < part_hp, heading + " shots reach modules, not the core")
	sim._damage_enemy(core, 999999999.0, "nova")
	_check(sim.late_boss_phase == 0 and is_equal_approx(float(core.hp / core.max_hp), 0.65), heading + " first overkill stops at 65%")

	var beginning: float = sim.time
	_destroy_parts(sim, role)
	_check(sim.time == beginning and sim.late_boss_phase == 1 and sim._alive_modules(role) == 2, heading + " new modules spawn immediately")
	_check(sim.bullets.any(func(b): return str(b.source) == str(core.kind)), heading + " instant surge is a real combat attack")
	var checkpoint: Dictionary = sim.snapshot()
	var pristine: Dictionary = checkpoint.duplicate(true)
	var restored := Sim.new()
	_check(restored.restore(checkpoint) and restored.late_boss_phase == 1 and restored._alive_modules(role) == 2, heading + " new phase survives save/resume")
	# Reconfigured parts must stay reward-neutral even with Salvage active and
	# the Hangar module-salvage perk purchased. Otherwise new phases mint Cores.
	restored.salvage_left = 10.0
	restored.meta.module_salvage = 3
	var kills: int = restored.kills
	var cores: int = restored.bonus_cores
	_destroy_parts(restored, role)
	_check(restored.kills == kills and restored.bonus_cores == cores, heading + " reconfigured modules yield no duplicate kills or Cores, even with Salvage active")
	_check(restored._nearest(restored.ship_position()).kind == str(core.kind), heading + " auto-target returns to open core")
	restored._damage_enemy(restored._boss_core(), 999999999.0, "nova")
	_check(restored.late_boss_phase == 2 and not restored.stage_transition_queued and restored.time == beginning, heading + " last phase starts from 30%/35% damage, not a timer")
	if stage == 3:
		_check(restored._alive_modules("vent") == 1, heading + " final vent is a real target")
		restored._damage_enemy(restored._boss_core(), 999999999.0, "nova")
		_check(not restored.stage_transition_queued and restored._boss_core().hp > 0.0, heading + " final vent cannot be bypassed by overkill")
		var last_kills: int = restored.kills
		var last_cores: int = restored.bonus_cores
		_destroy_parts(restored, "vent")
		_check(restored.kills == last_kills and restored.bonus_cores == last_cores, heading + " final vent adds no rewards")
	else:
		_check(restored.boss_phase_label() == "FINAL ONSLAUGHT" and restored._alive_modules("pylon") == 0, heading + " final onslaught is immediately exposed")
	restored._damage_enemy(restored._boss_core(), 999999999.0, "nova")
	_check(restored.stage_transition_queued and restored.stage_clears == stage, heading + " final victory has no mandatory delay")
	_check(checkpoint == pristine, heading + " saved checkpoint remains immutable")
	print("BOSS_PHASE_CASE ", JSON.stringify({"ship":ship_id, "difficulty":difficulty, "hangar":hangar_style, "world":stage, "phases":restored.late_boss_phase, "cleared":restored.stage_transition_queued}))

func _run() -> void:
	var selected_ship := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ship="):
			selected_ship = arg.get_slice("=", 1)
	var cells := 0
	for ship in Catalog.SHIPS:
		if not selected_ship.is_empty() and str(ship.id) != selected_ship:
			continue
		for difficulty in Catalog.DIFFICULTIES:
			for hangar in ["none", "mid", "max"]:
				for stage in [3, 4]:
					_case(str(ship.id), str(difficulty), hangar, stage)
					cells += 1
	print("BOSS_PHASE_MATRIX %d cells, %d checks, %d failures" % [cells, checks, failures])
	quit(0 if cells > 0 and failures == 0 else 1)
