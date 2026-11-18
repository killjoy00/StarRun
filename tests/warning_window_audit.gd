extends SceneTree
## Mechanical warning-time audit only. A 3x report is not a substitute for
## human thumb/visual reaction time or a claim that an attack is unfair.
const Sim = preload("res://scripts/simulation.gd")
const Hidden = preload("res://scripts/hidden_sector.gd")
const REVIEW_SECONDS := 0.80
var checks := 0
var failures := 0
var flagged := 0

func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("WARNING_WINDOW_AUDIT: " + message)

func _record(attack: String, difficulty: String, game_seconds: float, speed: float, kind: String) -> void:
	var wall: float = game_seconds / speed
	var review: bool = wall < REVIEW_SECONDS
	flagged += int(review)
	check(game_seconds > 0.0 and wall > 0.0, "Warning must have a positive duration: " + attack)
	print("WARNING_WINDOW ", JSON.stringify({
		"attack":attack, "difficulty":difficulty, "speed":speed,
		"category":kind, "game_seconds":snappedf(game_seconds, 0.01),
		"wall_seconds":snappedf(wall, 0.01), "review_under_0_8s":review
	}))

func _run() -> void:
	for difficulty in ["normal", "hard", "insane"]:
		for stage in range(1, 5):
			var sim := Sim.new(70102 + stage, {}, "vanguard", "rookie", difficulty)
			sim.stage = stage
			sim._spawn_boss()
			sim.heavy_ready_at = sim.time
			sim._update_enemies()
			check(not sim.charges.is_empty(), "World %d boss has a charge lane" % stage)
			if sim.charges.is_empty():
				continue
			var charge: Dictionary = sim.charges[0]
			var warning: float = float(charge.remaining)
			for speed in [1.0, 3.0]:
				_record("world_%d_heavy_beam" % stage, difficulty, warning, speed, "charged_warning")
			# Actual surge projectiles are dodgeable; this travel estimate is
			# explicitly NOT a warning or a guarantee of on-screen visibility.
			if stage in [3, 4]:
				var core: Dictionary = sim._boss_core()
				sim._late_boss_phase_surge(core)
				var shot: Dictionary = sim.bullets[-1]
				var travel: float = shot.p.distance_to(sim.ship_position()) / shot.v.length()
				for speed in [1.0, 3.0]:
					_record("world_%d_phase_surge" % stage, difficulty, travel, speed, "estimated_projectile_travel")
		for phase in range(3):
			var archive := Sim.new(72011 + phase, {}, "vanguard", "rookie", difficulty)
			archive.stage = Hidden.WORLD
			archive.secret_entered = true
			archive._spawn_boss()
			archive.archive_phase = phase
			archive.archive_next_attack = archive.time
			archive.archive_attack = ""
			archive._update_archive_attack()
			var name: String = str(Hidden.ATTACKS[phase])
			check(archive.archive_attack == name, "Custodian produces " + name + " warning")
			for speed in [1.0, 3.0]:
				_record("custodian_" + name, difficulty,
					archive.archive_attack_until - archive.time, speed, "charged_warning")
	print("WARNING_WINDOW_AUDIT_RESULT %d checks, %d failures, %d review flags (not gameplay failures)" % [checks, failures, flagged])
	quit(0 if failures == 0 else 1)
