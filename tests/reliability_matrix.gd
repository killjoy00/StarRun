extends SceneTree
## Crash/restart and collision-order regression. These are actual simulation
## transitions, not prefilled visual mockups or guaranteed bot victories.
const Sim = preload("res://scripts/simulation.gd")
const Progress = preload("res://scripts/meta_progress.gd")
const Hidden = preload("res://scripts/hidden_sector.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("RELIABILITY_MATRIX: " + message)

func _unchanged_after_restore(source: RefCounted, label: String) -> RefCounted:
	var checkpoint: Dictionary = source.snapshot()
	var original: Dictionary = checkpoint.duplicate(true)
	var resumed := Sim.new()
	check(resumed.restore(checkpoint), label + " can restore its checkpoint")
	check(resumed.snapshot() == checkpoint, label + " restores byte-equivalent logical state")
	check(checkpoint == original, label + " keeps checkpoint immutable")
	return resumed

func _merchant(seed: int) -> RefCounted:
	var sim := Sim.new(seed)
	sim.enable_merchant()
	sim.stage = 2
	sim.time = 86.0
	sim.stage_start = 10.0
	sim.merchant_next_at = 80.0
	return sim

func _run() -> void:
	for seed in [21011, 21012, 21013, 21014]:
		var sim := _merchant(seed)
		var name := "seed " + str(seed)
		sim.signal_status = "offer"
		sim.signal_until = sim.time + 40.0
		check(not sim._try_merchant_signal() and sim.merchant_visits == 0,
			name + " does not cover an active Archive coordinate offer with a Quartermaster")
		var before: Dictionary = sim.snapshot()
		var reload := Sim.new()
		check(reload.restore(before) and reload.signal_status == "offer" and reload.signal_until == sim.signal_until,
			name + " pending signal and merchant clock survive restart")
		check(reload.choose_signal("ignore") and reload._try_merchant_signal() and reload.merchant_state == "signal",
			name + " deferred Quartermaster hail becomes available after the signal decision")
		var paused_tick: int = reload.tick
		reload.step()
		check(reload.tick == paused_tick, name + " the hail actually pauses combat")
		reload = _unchanged_after_restore(reload, name + " hail")
		check(reload.merchant_hail() and reload.merchant_state == "shop", name + " hailing opens persistent inventory")
		reload = _unchanged_after_restore(reload, name + " inventory")
		check(reload.merchant_preview("sell_hull") and reload.merchant_state == "confirm", name + " trade preview is explicit")
		var max_before: float = reload.max_hull
		var cores_before: int = reload.choice_cores
		reload = _unchanged_after_restore(reload, name + " confirmation")
		check(is_equal_approx(reload.max_hull, max_before) and reload.choice_cores == cores_before,
			name + " pending confirmation cannot apply the trade")
		check(reload.merchant_accept() and reload.merchant_state == "receipt" and reload.merchant_trade_count == 1,
			name + " accepting once creates a durable paused receipt")
		var paid_hull: float = reload.max_hull
		var paid_cores: int = reload.choice_cores
		reload = _unchanged_after_restore(reload, name + " receipt")
		reload.step()
		check(reload.merchant_state == "receipt" and reload.tick == paused_tick, name + " receipt remains paused on resume")
		check(not reload.merchant_accept() and is_equal_approx(reload.max_hull, paid_hull)
			and reload.choice_cores == paid_cores and reload.merchant_trade_count == 1,
			name + " receipt cannot be charged a second time")
		check(reload.merchant_acknowledge_receipt() and reload.merchant_state.is_empty(),
			name + " closing the saved receipt resumes combat")
		check(not reload.merchant_acknowledge_receipt(), name + " a second receipt acknowledgement is harmless")
		var previous_visits: int = reload.merchant_visits
		check(not reload._try_merchant_signal() and reload.merchant_visits == previous_visits,
			name + " replay cannot refresh stage-specific offers")

		# Rival, signal and merchant are independently pending but must not
		# create simultaneous modal transactions.
		var rival := _merchant(seed + 100)
		rival.rival_intro_pending = true
		check(not rival._try_merchant_signal(), name + " rival introduction takes precedence over merchant")
		rival.rival_intro_pending = false
		rival.rival_retire_pending = true
		check(not rival._try_merchant_signal(), name + " rival retirement takes precedence over merchant")
		rival.rival_retire_pending = false
		check(rival._try_merchant_signal(), name + " deferred merchant appears once the rival notice clears")

		var daily := _merchant(seed + 200)
		daily.daily_day = "2026-11-18"
		check(not daily._try_merchant_signal(), name + " Daily never receives Quartermaster")
		daily._update_signal()
		check(daily.signal_status.is_empty(), name + " Daily never receives secret coordinates")

	# Preserve the full Archive attack state across a crash during a warning.
	for difficulty in ["normal", "hard", "insane"]:
		var archive := Sim.new(9911, {}, "arcwing", "rookie", difficulty)
		archive.stage = Hidden.WORLD
		archive.secret_entered = true
		archive._spawn_boss()
		if archive.secret_intro_pending:
			archive.dismiss_secret_intro()
		archive.time = archive.archive_next_attack
		archive._update_archive_attack()
		check(not archive.archive_attack.is_empty(), difficulty + " Archive genuinely starts an attack warning")
		var attack: String = archive.archive_attack
		var deadline: float = archive.archive_attack_until
		var record: Dictionary = archive.snapshot()
		var resumed := Sim.new()
		check(resumed.restore(record) and resumed.archive_attack == attack and resumed.archive_attack_until == deadline,
			difficulty + " keeps the precise Custodian windup and attack during save/resume")
		check(resumed.snapshot() == record, difficulty + " Archive warning restores without changing the timer")

	# A completed Archive settlement can never award Cores/achievements twice.
	var profile := {"cores":0, "last_paid_run":-1, "hangar":{}, "runs":1}
	var finish := Sim.new(64283)
	finish.secret_entered = true
	finish.stage = 5
	finish.stage_clears = 5
	finish.ended = true
	finish.won = true
	var first: Dictionary = Progress.settle(profile, finish)
	var cores: int = int(profile.cores)
	var repeat: Dictionary = Progress.settle(profile, finish)
	check("open_frequency" in first.awarded and Progress.progress(profile, "open_frequency") == 1,
		"Completed Archive grants its local discovery achievement")
	check(repeat.awarded.is_empty() and int(repeat.earned) == 0 and int(profile.cores) == cores,
		"Repeating Archive result after restart never duplicates awards or payouts")
	print("RELIABILITY_MATRIX_RESULT %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
