extends SceneTree
## Contracts for the incremental-roguelike excitement pass.
## Verify spawn budgeting, Daily isolation, persistent visual-only highlights,
## and real boss objectives. No forced victories, extra XP or player-rate claims.
const Sim = preload("res://scripts/simulation.gd")
const Hidden = preload("res://scripts/hidden_sector.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("ROGUELITE_EXCITEMENT: " + message)

func _count_fx(sim: RefCounted, kind: String) -> int:
	return sim.effects.filter(func(e): return str(e.kind) == kind).size()

func _run() -> void:
	for stage in [2, 3, 4]:
		var sim := Sim.new(430001 + stage)
		sim.stage = stage
		var rng_before: int = sim.rng.state
		var total := 0.0
		var fast := 0.0
		var recovery := 0.0
		for slot in range(16):
			var factor: float = sim._spawn_rhythm_factor()
			total += factor
			if slot < 6:
				fast += factor
			if slot >= 8:
				recovery += factor
			sim.spawn_rhythm_slot += 1
		check(is_equal_approx(total, 16.0), "W%d redistributes exactly 16 ordinary slots with no aggregate spawn gain" % stage)
		check(fast / 6.0 < recovery / 8.0, "W%d has actual pressure and recovery beats" % stage)
		check(sim.rng.state == rng_before, "W%d rhythm uses no combat or draft random draws" % stage)
		check(is_equal_approx(sim._spawn_rhythm_factor(), 0.70), "W%d cycle repeats deterministically" % stage)
		var checkpoint: Dictionary = sim.snapshot()
		var duplicate: Dictionary = checkpoint.duplicate(true)
		var resumed := Sim.new()
		check(resumed.restore(checkpoint) and resumed.spawn_rhythm_slot == 16, "W%d preserves the next rhythm slot after restart" % stage)
		check(resumed.snapshot() == checkpoint and checkpoint == duplicate, "W%d rhythm checkpoint is exact and immutable" % stage)
		var daily := Sim.new(430001 + stage)
		daily.stage = stage
		daily.daily_day = "2026-11-18"
		check(is_equal_approx(daily._spawn_rhythm_factor(), 1.0), "W%d Daily cadence remains unchanged" % stage)
		daily.spawn_rhythm_slot = 15
		check(is_equal_approx(daily._spawn_rhythm_factor(), 1.0), "W%d Daily ignores restored rhythm slots" % stage)
	var opener := Sim.new(431001, {}, "kestrel", "rookie", "hard")
	check(is_equal_approx(opener._spawn_rhythm_factor(), 1.0), "World 1 Hard keeps the intended empty-Hangar progression gate")
	var archive := Sim.new(431002)
	archive.stage = Hidden.WORLD
	archive.secret_entered = true
	check(is_equal_approx(archive._spawn_rhythm_factor(), 1.0), "Secret sector combat remains untouched")
	var mutation := Sim.new(433001)
	mutation.upgrades.seeker = 1
	check(mutation._install_mutation("split_seeker"), "Owned automatic weapon can install its real mutation")
	check(_count_fx(mutation, "mutation-installed") == 1, "Mutation installation has one distinct non-combat presentation event")
	var from_snapshot := Sim.new()
	check(from_snapshot.restore(mutation.snapshot()) and from_snapshot.mutations == mutation.mutations, "Mutation installation survives exact checkpoint restore")
	check(not mutation._install_mutation("breach_seeker"), "Spectacle does not permit an extra mutation")
	mutation._mutation_feedback("split_seeker", Vector2(210, 310))
	mutation._mutation_feedback("split_seeker", Vector2(230, 320))
	check(_count_fx(mutation, "mutation-proc") == 1, "Repeated automatic hits cannot flood the presentation")
	mutation.tick += 90
	mutation._mutation_feedback("split_seeker", Vector2(230, 320))
	check(_count_fx(mutation, "mutation-proc") == 2, "A genuine later mutation proc can be highlighted again")
	check(mutation.kills == 0 and mutation.xp == 0.0 and mutation.choice_cores == 0, "Mutation presentation cannot create XP, kills or Cores")
	for stage in [3, 4]:
		var boss := Sim.new(47000 + stage)
		boss.stage = stage
		boss._spawn_boss()
		var role := "vent" if stage == 3 else "pylon"
		var core: Dictionary = boss._boss_core()
		boss._damage_enemy(core, 9999999.0, "nova")
		check(boss.late_boss_phase == 0, "W%d cannot skip targetable parts" % stage)
		var parts: Array = boss.enemies.filter(func(e): return e.kind == "boss_module" and e.hp > 0.0 and str(e.role) == role)
		check(parts.size() == 2, "W%d starts with actual breakable parts" % stage)
		for part in parts:
			boss._damage_enemy(part, 9999999.0, "nova")
		check(boss.late_boss_phase == 1, "W%d really advances through a broken objective" % stage)
		check(_count_fx(boss, "boss-module-break") >= 2, "W%d module destruction produces a cue" % stage)
		check(_count_fx(boss, "boss-phase-break") == 1, "W%d phase transition produces a single celebration" % stage)
		check(not boss.stage_transition_queued, "W%d spectacle does not automatically kill the boss" % stage)
	var custodian := Sim.new(47105)
	custodian.secret_entered = true
	custodian.stage = Hidden.WORLD
	custodian._spawn_boss()
	custodian.archive_phase_released = true
	custodian._boss_core().hp = custodian._boss_core().max_hp * Hidden.PHASE_FLOORS[0]
	custodian._update_archive_attack()
	check(custodian.archive_phase == 1 and _count_fx(custodian, "boss-phase-break") == 1,
		"Custodian actual phase progress has the same non-blocking celebration")
	print("ROGUELITE_EXCITEMENT_RESULT %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
