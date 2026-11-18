extends SceneTree
## Fast, isolated safety checks for boss-only damage and phase transitions.
## Real gameplay outcomes are still checked by archive_campaign.gd and balance_matrix.gd.
const Sim = preload("res://scripts/simulation.gd")
const Archive = preload("res://scripts/hidden_sector.gd")

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func assert_game(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("BOSS PRESSURE: " + message)

func _run() -> void:
	var factors := {"normal":1.85, "hard":1.95, "insane":2.05}
	for difficulty in ["normal", "hard", "insane"]:
		var factor: float = float(factors[difficulty])
		for world in range(1, 5):
			var sim := Sim.new(6101, {}, "vanguard", "rookie", difficulty)
			sim.stage = world
			sim._spawn_boss()
			var core: Dictionary = sim._boss_core()
			assert_game(not core.is_empty(), "World %d should create a targetable boss" % world)
			core.fire = 0.0
			sim.time = sim.heavy_ready_at
			sim._update_enemies()
			var expected_beam: float = (29.0 + float(world) * 6.0) * sim.threat_scale() * factor
			assert_game(not sim.charges.is_empty() and is_equal_approx(float(sim.charges[0].damage), expected_beam),
				"World %d %s heavy must use boss-only damage scaling" % [world, difficulty])
			var boss_round: Dictionary = {}
			for bullet in sim.bullets:
				if str(bullet.get("source","")).begins_with("boss") and bullet.kind not in ["ordnance", "slag"]:
					boss_round = bullet
					break
			assert_game(not boss_round.is_empty() and is_equal_approx(float(boss_round.damage), 2.1 * sim.threat_scale() * factor * (sim.opener_boss_enrage() if world == 1 else 1.0)),
				"World %d %s regular boss volley must be significantly stronger" % [world, difficulty])
			if world == 2:
				var missiles := sim.bullets.filter(func(b): return b.kind == "ordnance" and str(b.source) == "boss2")
				assert_game(not missiles.is_empty() and is_equal_approx(float(missiles[0].damage), 12.0 * sim.threat_scale() * factor),
					"World 2 boss missiles must inherit increased boss damage")
			if world == 3:
				var slag := sim.bullets.filter(func(b): return b.kind == "slag" and str(b.source) == "boss3")
				assert_game(not slag.is_empty() and is_equal_approx(float(slag[0].damage), 18.0 * sim.threat_scale() * factor),
					"World 3 boss slag mines must inherit increased boss damage")
		var archive := Sim.new(6101, {}, "vanguard", "rookie", difficulty)
		archive.stage = Archive.WORLD
		archive.secret_entered = true
		archive._spawn_boss()
		var archive_core: Dictionary = archive._boss_core()
		archive_core.fire = 0.0
		archive._update_enemies()
		assert_game(archive.bullets.size() == 2 * Archive.VOLLEY_COUNTS[0] and is_equal_approx(float(archive.bullets[0].damage), Archive.VOLLEY_DAMAGE * archive.threat_scale() * factor),
			"Custodian %s index volleys must inherit stronger boss damage" % difficulty)
		# The saved state must remain unchanged after any resumed combat.
		var checkpoint: Dictionary = archive.snapshot()
		var original: Dictionary = checkpoint.duplicate(true)
		var restored := Sim.new()
		assert_game(restored.restore(checkpoint), "Boss checkpoint restores before damage")
		restored._damage_enemy(restored._boss_core(), 10000.0, "nova")
		assert_game(checkpoint == original, "Restored boss combat cannot mutate its saved checkpoint")
		archive.archive_phase_released = true
		archive_core.hp = archive_core.max_hp * Archive.PHASE_FLOORS[0]
		archive.archive_next_attack = archive.time + 90.0
		var initial_bullets: int = archive.bullets.size()
		archive._update_archive_attack()
		assert_game(archive.archive_phase == 1 and archive.archive_next_attack - archive.time <= Archive.PHASE_TRANSITION_SECONDS + 0.001,
			"Phase two starts a lock quickly without 16-second forced rearm")
		assert_game(archive.bullets.size() - initial_bullets == Archive.PHASE_SURGE_SHOTS[1],
			"Phase two launches an actual projectile surge")
		archive.time = archive.archive_next_attack
		archive._update_archive_attack()
		assert_game(archive.archive_attack == "lattice" and archive.archive_attack_until > archive.time + 3.0,
			"Phase two has a fair and readable lattice telegraph")
	print("BOSS_PRESSURE_RESULT %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
