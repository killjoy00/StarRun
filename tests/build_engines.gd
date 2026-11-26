extends SceneTree
## Build-first contracts. No manual ability casts; tests use genuine enemy
## health/damage paths, not forced stage clears or synthetic rewards.
const Sim = preload("res://scripts/simulation.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("BUILD_ENGINE: " + message)

func _equip(sim: RefCounted, id: String, primary_rank: int = 5, secondary_rank: int = 2, third_rank: int = 2) -> void:
	for spec in sim.content.build_engines:
		if str(spec.id) == id:
			sim.upgrades[str(spec.primary)] = primary_rank
			sim.upgrades[str(spec.secondary)] = secondary_rank
			var third: String = str(spec.third_any[0]) if spec.has("third_any") else str(spec.third)
			sim.upgrades[third] = third_rank
			if third == "wing_drones" and third not in sim.active_slots:
				sim.active_slots.append(third)
			return

func _target(sim: RefCounted, id: int = 1, elite: bool = false) -> Dictionary:
	sim._add_enemy("carrier", Vector2(270 + 22 * (id - 1), 290 + 22 * (id - 1)))
	var enemy: Dictionary = sim.enemies[-1]
	enemy.hp = 10000.0
	enemy.max_hp = 10000.0
	if elite:
		enemy["elite_role"] = "leader"
	return enemy

func _run() -> void:
	var catalog := Sim.new(71000)
	check(catalog.content.build_engines.size() == 7, "seven engines defined in the live content catalog")
	var ids: Array = []
	for spec in catalog.content.build_engines:
		var id: String = str(spec.id)
		check(id not in ids, "distinct engine ID: " + id)
		ids.append(id)
		var sim := Sim.new(71001)
		sim.stage = 2
		check(sim.engine_tier(id) == 0, id + " cannot activate for free")
		_equip(sim, id, 4, 2, 0)
		check(sim.engine_tier(id) == 1, id + " earns a two-part precursor")
		_equip(sim, id, 5, 2, 2)
		check(sim.engine_tier(id) == 2, id + " earns signature at three-piece threshold")
		_equip(sim, id, 8, 5, 5)
		check(sim.engine_tier(id) == 3, id + " earns mastery at deep ranks")
		sim.stage = 1
		check(sim.engine_tier(id) == 0, id + " does not change the original World 1 opener")
		sim.stage = 2
		sim.daily_day = "2026-11-18"
		check(sim.engine_tier(id) == 0, id + " cannot change published Daily rules")
		sim.daily_day = ""
		var checkpoint: Dictionary = sim.snapshot()
		var clone := Sim.new()
		check(clone.restore(checkpoint) and clone.engine_tier(id) == 3, id + " mastery survives checkpoint")
		check(clone.snapshot() == checkpoint, id + " checkpoint round-trips exactly")
		var old := checkpoint.duplicate(true)
		for k in ["engine_execution_target", "engine_execution_hits", "engine_execution_ready_tick", "engine_siege_target", "engine_siege_stacks", "engine_siege_expires", "engine_storm_marks", "engine_storm_ready_tick", "engine_prism_target", "engine_prism_hits", "engine_prism_ready_tick", "engine_fortress_charge", "engine_salvage_charge", "engine_salvage_ready_tick", "engine_procs"]:
			old.erase(k)
		var migrated := Sim.new()
		check(migrated.restore(old) and migrated.engine_procs.size() == 7, id + " accepts older save without engine state")
	var execution := Sim.new(72001)
	execution.stage = 2
	_equip(execution, "execution_network")
	var execution_target: Dictionary = _target(execution)
	for i in range(6):
		execution._damage_enemy(execution_target, 12.0, "pulse")
	check(int(execution.engine_procs.execution_network) == 1, "Pulse produces a single throttled precision volley")
	check(float(execution.damage_dealt.get("engine_execution", 0.0)) > 0.0, "Execution Network changes actual target health")
	check(execution.ability_uses == 0, "Execution Network needs no manual cast")
	var siege := Sim.new(72002)
	siege.stage = 2
	_equip(siege, "missile_siege")
	var siege_target: Dictionary = _target(siege, 1, true)
	var before: float = siege_target.hp
	siege._damage_enemy(siege_target, 25.0, "seeker")
	var first_hit: float = before - float(siege_target.hp)
	before = siege_target.hp
	siege._damage_enemy(siege_target, 25.0, "seeker")
	var second_hit: float = before - float(siege_target.hp)
	check(second_hit > first_hit, "Missile Siege increases real damage on repeated priority-target hits")
	check(int(siege.engine_procs.missile_siege) == 1, "Siege shows a real charged breach")
	var storm := Sim.new(72003)
	storm.stage = 2
	_equip(storm, "storm_circuit")
	var charged: Dictionary = _target(storm)
	var nearby: Dictionary = _target(storm, 2)
	var neutral_rng: int = storm.rng.state
	storm._engine_on_weapon_hit(charged, 20.0, "arc")
	storm._engine_on_weapon_hit(charged, 20.0, "pulse")
	check(storm.rng.state == neutral_rng, "Engine charge/trigger uses no extra combat or draft RNG")
	check(int(storm.engine_procs.storm_circuit) == 1, "Arc charge discharges on a different automatic weapon")
	check(float(storm.damage_dealt.get("engine_storm", 0.0)) > 0.0 and nearby.hp < nearby.max_hp, "Storm Circuit has actual cross-target chained damage")
	storm._engine_on_weapon_hit(charged, 20.0, "pulse")
	check(int(storm.engine_procs.storm_circuit) == 1, "Storm discharge is not recursive or infinite")
	var prism := Sim.new(72004)
	prism.stage = 2
	_equip(prism, "prism_hunter")
	var prism_target: Dictionary = _target(prism, 1, true)
	for i in range(3):
		prism._damage_enemy(prism_target, 30.0, "lance")
	check(int(prism.engine_procs.prism_hunter) == 1 and float(prism.damage_dealt.get("engine_prism", 0.0)) > 0.0, "Prism Hunter earns a heavy focused automatic strike")
	var fortress := Sim.new(72005)
	fortress.stage = 2
	_equip(fortress, "fortress_reactor")
	var fort_target: Dictionary = _target(fortress)
	for i in range(485):
		fortress._update_build_engines()
	check(int(fortress.engine_procs.fortress_reactor) >= 1 and fort_target.hp < fort_target.max_hp, "Fortress converts maintained shield uptime to automatic damage")
	fortress.engine_fortress_charge = 4.0
	fortress.shield = fortress.max_shield * 0.50
	fortress._update_build_engines()
	check(fortress.engine_fortress_charge == 0.0, "Fortress charge collapses when shields fall")
	var salvage := Sim.new(72006)
	salvage.stage = 2
	_equip(salvage, "salvage_carrier")
	var salvage_target: Dictionary = _target(salvage)
	salvage.hull = salvage.max_hull - 12.0
	salvage._engine_charge_salvage(6.0)
	salvage._update_build_engines()
	check(int(salvage.engine_procs.salvage_carrier) == 1, "Salvage charges autonomous escort fire")
	check(salvage.shots.size() > 0 and str(salvage.shots[0].weapon) == "escort" and salvage.hull > salvage.max_hull - 12.0, "Salvage grants actual support shots and bounded repair")
	check(salvage.ability_uses == 0, "Salvage Carrier requires no ability press")
	var checkpoint: Dictionary = salvage.snapshot()
	var resumed := Sim.new()
	check(resumed.restore(checkpoint) and resumed.engine_salvage_charge == salvage.engine_salvage_charge and resumed.engine_procs == salvage.engine_procs, "Engine proc/charge history survives restore without extra payouts")
	var daily := Sim.new(72007)
	daily.stage = 2
	daily.daily_day = "2026-11-18"
	_equip(daily, "execution_network")
	var daily_target: Dictionary = _target(daily)
	for i in range(7):
		daily._damage_enemy(daily_target, 12.0, "pulse")
	check(int(daily.engine_procs.execution_network) == 0, "Daily cannot trigger new build engine output")
	check(daily.kills == 0 and daily.choice_cores == 0, "Engine checks do not award free kills or Cores")
	print("BUILD_ENGINE_RESULT %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
