extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("HIJACKER FAIL: " + message)

func _setup(tier: int = 3) -> RefCounted:
	var sim := Sim.new(8191)
	sim.stage = 2
	sim.upgrades.jammer = 4 if tier == 1 else (5 if tier == 2 else 8)
	sim.upgrades.emp = 2 if tier < 3 else 5
	sim.upgrades.decoy = 0 if tier == 1 else (2 if tier == 2 else 5)
	sim.active_slots = ["jammer","emp"] if tier == 1 else ["jammer","emp","decoy"]
	return sim

func _enemy(sim: RefCounted, kind: String, fraction: float = 0.25) -> Dictionary:
	sim._add_enemy(kind, Vector2(270,350))
	var enemy: Dictionary = sim.enemies[-1]
	enemy.hp = float(enemy.max_hp) * fraction
	return enemy

func _run() -> void:
	var starter := _setup(1)
	_enemy(starter, "gunship")
	starter._update_build_engines()
	check(starter.hijacked_ships.is_empty(), "tier one is cast-driven")
	check(starter.activate("jammer") and starter.hijacked_ships.size() == 1, "first control cast captures a real ship")
	var standard := _setup(2)
	for kind in ["gunship","arc_spire","shieldguard"]:
		_enemy(standard,kind)
	standard._update_build_engines()
	check(standard.hijacked_ships.size() == 1 and standard.ability_uses == 0, "automatic tier two conversion")
	standard.time = standard.hijack_ready_at
	standard._update_build_engines()
	standard.time = standard.hijack_ready_at
	standard._update_build_engines()
	check(standard.hijacked_ships.size() == 2 and standard.enemies.size() == 1, "tier two is capped at two")
	var master := _setup()
	var original: Dictionary = _enemy(master,"gunship")
	var old_xp: float = master.xp
	var original_xp: float = float(original.xp)
	var old_kills: int = master.kills
	var old_cores: int = master.bonus_cores
	master.salvage_left = 30.0
	var initial_rng: int = master.rng.state
	check(master._try_hijack(), "master converts a weakened ship")
	check(not master.enemies.has(original) and master._nearest(Vector2.ZERO).is_empty(), "captured ship cannot be a hostile target")
	check(master.kills == old_kills and master.bonus_cores == old_cores and is_equal_approx(master.xp, old_xp + original_xp) and master.rng.state == initial_rng, "capture grants original XP once without kill, salvage, or RNG")
	check(not master._try_hijack(), "shared capture cooldown")
	for kind in ["shieldguard","carrier","void_lancer"]:
		_enemy(master,kind)
	for i in range(3):
		master.time = master.hijack_ready_at
		master._try_hijack()
	check(master.hijacked_ships.size() == 3 and master.enemies.size() == 1, "mastery is capped at three")
	var snapshot: Dictionary = master.snapshot()
	var resumed := Sim.new()
	check(resumed.restore(snapshot) and resumed.snapshot() == snapshot, "fleet and cooldown survive checkpoint")
	check(resumed.build_impact_rows().any(func(row): return str(row.id) == "hijacker"), "results credit actual captures")
	resumed._spawn_boss()
	check(resumed.hijacked_ships.size() == 3 and not resumed._try_hijack(true), "surviving fleet joins boss; bosses cannot be captured")
	var guard: Dictionary = resumed.hijacked_ships[1]
	guard.hp = 1.0
	var bullet := {"p":guard.p + Vector2(60,0),"kind":"chaff","damage":20.0,"hp":1}
	# Separate the guard from the other two intercept radii.
	resumed.hijacked_ships[0].p = Vector2(50,600)
	resumed.hijacked_ships[2].p = Vector2(480,600)
	check(resumed._hijack_intercept(bullet) and resumed.hijacked_ships.size() == 2 and resumed.hijack_lost == 1 and bullet.hp == 0.0, "guard intercepts hostile fire and can be destroyed")
	check(snapshot.hijacked_ships.size() == 3, "resumed damage cannot mutate checkpoint")
	for kind in ["gunship","missile_bomber","shieldguard","arc_spire","disruptor","carrier","void_lancer"]:
		var sim := _setup()
		_enemy(sim,kind)
		check(sim._try_hijack(), "capture " + kind)
		var victim: Dictionary = _enemy(sim,"ion_frigate",1.0)
		var before: float = float(victim.hp)
		victim.fire = 0.0
		sim.hijacked_ships[0].fire = 0.0
		sim._update_hijacker()
		check(sim.shots.any(func(shot): return shot.weapon == "engine_hijacker") or float(victim.hp) < before, kind + " uses a real attack")
		if kind == "disruptor":
			check(float(victim.fire) >= 1.8, "disruptor delays an actual enemy volley")
		if kind == "carrier":
			check(sim.shots.size() == 2 and float(sim.hijacked_ships[0].sortie_until) > sim.time, "carrier launches a visible two-fighter sortie")
		if kind == "arc_spire" or kind == "void_lancer":
			check(float(sim.damage_dealt.get("engine_hijacker",0.0)) > 0.0, "direct damage is attributed to captured ship")
	var burst := _setup(2)
	var incoming: Dictionary = _enemy(burst,"gunship",1.0)
	incoming.p.y = -35.0
	burst._damage_enemy(incoming,99999999.0,"pulse")
	check(burst.hijacked_ships.size() == 1 and incoming.hp == 0.0 and burst.kills == 0, "lethal automatic hits still capture incoming ships")
	var once: float = burst.xp
	burst._damage_enemy(incoming,99999999.0,"pulse")
	check(burst.xp == once and burst.hijacked_ships.size() == 1, "lethal-hit capture cannot repeat rewards")
	var protected := _setup()
	var leader: Dictionary = _enemy(protected,"gunship")
	leader["elite_role"] = "leader"
	var rival: Dictionary = _enemy(protected,"carrier")
	rival["rival"] = true
	var healthy: Dictionary = _enemy(protected,"disruptor",1.0)
	check(not protected._try_hijack(true), "healthy ships, rivals and elite leaders cannot be captured")
	for mode in ["daily","intro","archive","endless","legacy"]:
		var isolated := _setup()
		match mode:
			"daily": isolated.daily_day = "2026-11-26"
			"intro": isolated.intro_run = true
			"archive": isolated.secret_entered = true
			"endless": isolated.stage = 5
			"legacy": isolated.campaign_choreography_version = 0
		_enemy(isolated,"gunship")
		check(not isolated._try_hijack(true) and isolated.hijack_capacity() == 0, "isolated " + mode)
	var fused := _setup()
	fused.active_slots = ["ghost_signal","stasis_lock"]
	fused.upgrades.ghost_signal = 1
	fused.upgrades.stasis_lock = 1
	_enemy(fused,"gunship")
	check(fused.hijack_capacity() == 3 and fused.activate("ghost_signal") and fused.hijacked_ships.size() == 1, "control fusions retain capture functionality")
	print("HIJACKER_RESULT %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
