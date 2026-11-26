extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const Formations = preload("res://scripts/campaign_formations.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("CHOREOGRAPHY FAIL: " + message)

func _ready_core(sim: RefCounted) -> Dictionary:
	var core: Dictionary = sim._boss_core()
	core.erase("arrive_y")
	core.p.y = 135.0
	core.fire = 0.0
	sim.heavy_ready_at = 0.0
	return core

func _attack(sim: RefCounted, core: Dictionary) -> void:
	sim.bullets.clear()
	sim.charges.clear()
	core.fire = 0.0
	sim.heavy_ready_at = 0.0
	sim._update_enemies()

func _parts(sim: RefCounted, role: String) -> Array:
	return sim.enemies.filter(func(e): return e.kind == "boss_module" and str(e.role) == role and float(e.hp) > 0.0)

func _run() -> void:
	var catalog := Sim.new(1)
	for world in range(1, 5):
		var library: Array = Formations.WORLDS[world - 1]
		check(library.size() == 15, "15 formations in world %d" % world)
		var seen := {}
		for i in range(15):
			var entry: Array = Formations.pick(world, 200.0, 12, i)
			seen[str(entry[0])] = true
			check(entry[3].size() == 3, "three ordinary spawn slots")
			for slot in range(3):
				check(catalog.content.enemies.has(str(entry[3][slot])) and Formations.position(entry, slot).y < 0.0, "valid enemy and offscreen entry")
		check(seen.size() == 15, "all 15 are reachable per world")
		var wave := Sim.new(14, {}, "vanguard", "rookie", "hard")
		wave.stage = world
		wave.time = 200.0
		wave._spawn_encounter()
		check(wave.encounter_queue.size() == 3, "formation consumes three queued slots")
		var saved: Dictionary = wave.snapshot()
		var restored := Sim.new()
		check(restored.restore(saved) and restored.encounter_queue == wave.encounter_queue, "formation queue restores")
		for i in range(3):
			wave._spawn_enemy()
		check(wave.enemies.size() == 3 and wave.encounter_queue.is_empty(), "no extra wave slots")
		check(wave.enemies.all(func(e): return float(e.p.y) < 0.0 and int(e.xp) == int(wave.content.enemies[str(e.kind)].xp)), "entries are visible fly-ins with ordinary XP")
		for enemy in wave.enemies:
			enemy.fire = 0.0
		wave.heavy_ready_at = 0.0
		wave._update_enemies()
		check(wave.bullets.is_empty() and wave.charges.is_empty(), "formation enemies do not fire or charge while offscreen")
	for difficulty in ["normal", "hard", "insane"]:
		var harvester := Sim.new(15, {}, "vanguard", "rookie", difficulty)
		harvester._spawn_boss()
		var core: Dictionary = _ready_core(harvester)
		_attack(harvester, core)
		check(harvester.bullets.size() == 2 and harvester.bullets.all(func(b): return b.kind == "ordnance") and harvester.charges.is_empty(), "Harvester missiles only")
		_attack(harvester, core)
		check(harvester.bullets.size() == 11 and harvester.bullets.all(func(b): return b.kind == "chaff") and harvester.charges.is_empty(), "Harvester gunfire only")
		_attack(harvester, core)
		check(harvester.bullets.is_empty() and harvester.charges.size() == 1 and is_equal_approx(float(harvester.charges[0].duration), 1.8), "Harvester charged beam only")
		var saved: Dictionary = harvester.snapshot()
		var resumed := Sim.new()
		check(resumed.restore(saved) and resumed._boss_core().campaign_attack_index == 3, "attack cycle survives resume")
		_attack(resumed, resumed._boss_core())
		check(resumed.bullets.size() == 2 and resumed.kills == 0 and resumed.bonus_cores == 0, "cycle repeats with no rewards")
		var storm := Sim.new(15, {}, "vanguard", "rookie", difficulty)
		storm.stage = 2
		storm._spawn_boss()
		core = _ready_core(storm)
		var bays: Array = _parts(storm, "launch_bay")
		var armored: float = core.hp
		storm._damage_enemy(core, 100.0, "nova")
		check(is_equal_approx(armored - float(core.hp), 55.0), "two bays armor the carrier")
		storm._damage_enemy(bays[0], 99999999.0, "nova")
		armored = core.hp
		storm._damage_enemy(core, 100.0, "nova")
		check(is_equal_approx(armored - float(core.hp), 78.0), "one bay weakens armor")
		storm.time = 6.0
		_attack(storm, core)
		check(storm.enemies.filter(func(e): return e.kind == "storm_weaver").size() == 1 and storm.bullets.filter(func(b): return b.kind == "ordnance" and b.source == "boss2").size() == 2, "one bay launches one fighter and two missiles")
		storm._damage_enemy(bays[1], 99999999.0, "nova")
		storm.time = 12.0
		_attack(storm, core)
		check(storm.enemies.filter(func(e): return e.kind == "storm_weaver").size() == 1 and storm.bullets.filter(func(b): return b.kind == "ordnance" and b.source == "boss2").size() == 1, "no bays launch no extra fighter")
		var crucible := Sim.new(15, {}, "vanguard", "rookie", difficulty)
		crucible.stage = 3
		crucible._spawn_boss()
		crucible.heat_left = 3.5
		crucible._damage_enemy(_parts(crucible, "vent")[0], 99999999.0, "nova")
		check(crucible.heat_left == 0.0 and crucible._vent_cooling_active() and crucible.effects.any(func(e): return e.kind == "vent-release"), "vent visibly releases heat")
		crucible._hit(1.0, "heat", "test")
		check(crucible.heat_left == 0.0, "brief cooling prevents immediate heat reapplication")
		crucible.time += 2.6
		crucible._hit(1.0, "heat", "test")
		check(crucible.heat_left > 0.0, "heat resumes naturally")
		var regent := Sim.new(15, {}, "vanguard", "rookie", difficulty)
		regent.stage = 4
		regent._spawn_boss()
		core = _ready_core(regent)
		core.campaign_attack_index = 2
		_attack(regent, core)
		check(regent.charges.size() == 2, "two active pylons fire two beams")
		var pylons: Array = _parts(regent, "pylon")
		regent._damage_enemy(pylons[0], 99999999.0, "nova")
		check(regent.charges.size() == 1, "destroyed pylon cancels its own beam")
		core.campaign_attack_index = 0
		_attack(regent, core)
		check(regent.bullets.size() > 0 and regent.bullets.all(func(b): return b.kind == "void"), "right pylon alone fires void")
		regent._damage_enemy(core, 999999999.0, "nova")
		regent._damage_enemy(pylons[1], 99999999.0, "nova")
		check(regent.late_boss_phase == 1, "first pylon phase remains real")
		for part in _parts(regent, "pylon"):
			regent._damage_enemy(part, 99999999.0, "nova")
		regent._damage_enemy(core, 999999999.0, "nova")
		check(regent.late_boss_phase == 2 and regent.boss_phase_label() == "FINAL ONSLAUGHT", "final onslaught has no artificial wait")
		check(regent.bullets.any(func(b): return b.kind == "gravity") and regent.bullets.any(func(b): return b.kind == "void"), "final flank surge uses both statuses")
		regent._damage_enemy(core, 999999999.0, "nova")
		check(regent.stage_transition_queued, "completed build can finish the final phase immediately")
	var legacy := Sim.new()
	var legacy_saved: Dictionary = legacy.snapshot()
	legacy_saved.erase("campaign_choreography_version")
	check(legacy.restore(legacy_saved) and not legacy.campaign_choreography_active(), "old saves retain original combat")
	var daily := Sim.new()
	daily.daily_day = "2026-11-26"
	check(not daily.campaign_choreography_active(), "Daily stays on historic rules")
	var intro := Sim.new()
	intro.intro_run = true
	check(not intro.campaign_choreography_active(), "First Flight stays untouched")
	var archive := Sim.new()
	archive.secret_entered = true
	check(not archive.campaign_choreography_active(), "Archive stays untouched")
	var endless := Sim.new()
	endless.stage = 5
	check(not endless.campaign_choreography_active(), "post-campaign Endless stays untouched")
	print("CAMPAIGN_CHOREOGRAPHY_RESULT %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
