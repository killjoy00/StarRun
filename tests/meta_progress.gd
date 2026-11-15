extends SceneTree
const Progress = preload("res://scripts/meta_progress.gd")
const Sim = preload("res://scripts/simulation.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var d1 := "2026-11-15"
	var d2 := "2026-11-16"
	var setup: Dictionary = Progress.daily_setup(d1)
	check(setup == Progress.daily_setup(d1), "Daily configuration is stable across repeated requests")
	check(int(setup.seed) != int(Progress.daily_setup(d2).seed), "Adjacent UTC days have different run seeds")
	check(setup.difficulty == "normal" and not str(setup.ship).is_empty() and not str(setup.pilot).is_empty(), "Daily runs have one fixed common ship, pilot and difficulty")
	check(Progress.daily_seed(d1) == 628096306, "Seed must match a known cross-platform YYYYMMDD mapping")
	var profile := {"cores":0,"runs":3,"last_paid_run":-1,"hangar":{"damage":5,"hull":6}}
	Progress.prepare(profile)
	check(profile.achievements is Dictionary and profile.daily_records is Dictionary and profile.achievement_stats is Dictionary, "Old profiles gain daily and achievement fields without altering Hangar")
	check(profile.hangar.damage == 5 and profile.hangar.hull == 6, "Profile migration must not erase existing Hangar investments")

	var attempt: int = Progress.start_daily(profile,d1)
	check(attempt == 1, "First daily launch counts the first attempt")
	var sim := Sim.new(int(setup.seed),{},str(setup.ship),str(setup.pilot),str(setup.difficulty))
	sim.daily_day = d1
	sim.daily_attempt = attempt
	check(sim.meta.damage == 0 and sim.meta.hull == 0, "Daily ignores normal Hangar purchases")
	var state: Dictionary = sim.snapshot()
	var restored := Sim.new(4)
	check(restored.restore(state) and restored.snapshot() == state and restored.daily_day == d1 and restored.daily_attempt == 1, "Daily date, exact RNG and attempt survive an application resume")

	sim.kills = 90
	sim.level = 12
	sim.stage_clears = 1
	sim.prevented = 100.0
	sim.ended = true
	var first_reward: int = sim.payout()
	var score: int = Progress.daily_score(sim)
	var first: Dictionary = Progress.settle(profile,sim)
	check(int(first.earned) == first_reward and int(profile.cores) == first_reward, "First completed daily pays earned Cores exactly once")
	check(first.new_best and int(first.best_score) == score, "First finished attempt establishes the local best")
	check("first_finish" in first.awarded and "first_boss" in first.awarded and "daily_first" in first.awarded, "Run and Daily achievements unlock from settled gameplay")
	var again: Dictionary = Progress.settle(profile,sim)
	check(int(again.earned) == 0 and profile.achievement_stats.finished_runs == 1 and profile.daily_records[d1].completed == 1, "Repeating settlement after a crash cannot duplicate Cores, achievements or stats")

	attempt = Progress.start_daily(profile,d1)
	check(attempt == 2 and profile.daily_records[d1].attempts == 2, "Same date allows a replay without changing the shared seed")
	var replay := Sim.new(int(setup.seed),{},str(setup.ship),str(setup.pilot),"normal")
	replay.daily_day = d1
	replay.daily_attempt = attempt
	replay.kills = 190
	replay.level = 22
	replay.stage_clears = 2
	replay.ended = true
	var improvement: Dictionary = Progress.settle(profile,replay)
	check(int(improvement.earned) == 0 and int(profile.cores) == first_reward, "Daily replays cannot farm unlimited Core payouts")
	check(improvement.new_best and int(improvement.best_score) > score and profile.daily_records[d1].completed == 2, "Replay improves the local best without spending or resetting the first reward")
	check(profile.achievement_stats.daily_days.size() == 1, "Repeating a UTC day does not multiply unique-day achievements")
	var third_attempt: int = Progress.start_daily(profile,d1)
	var weaker := Sim.new(int(setup.seed),{},str(setup.ship),str(setup.pilot),"normal")
	weaker.daily_day = d1
	weaker.daily_attempt = third_attempt
	weaker.kills = 1
	weaker.ended = true
	var weaker_result: Dictionary = Progress.settle(profile,weaker)
	check(not weaker_result.new_best and int(weaker_result.best_score) == int(improvement.best_score), "A worse daily attempt must not overwrite the best score")

	var next: Dictionary = Progress.daily_setup(d2)
	var next_attempt: int = Progress.start_daily(profile,d2)
	var tomorrow := Sim.new(int(next.seed),{},str(next.ship),str(next.pilot),"normal")
	tomorrow.daily_day = d2
	tomorrow.daily_attempt = next_attempt
	tomorrow.stage_clears = 4
	tomorrow.won = true
	tomorrow.kills = 500
	tomorrow.ended = true
	var second_day: Dictionary = Progress.settle(profile,tomorrow)
	check(second_day.earned > 0 and profile.achievement_stats.daily_days.size() == 2, "The next UTC day grants its own first reward and unique participation")
	check("fourth_boss" in second_day.awarded and Progress.progress(profile,"second_boss") >= 2, "Genuine World 4 settlement also earns earlier stage achievements")
	check(Progress.progress(profile,"daily_seven") == 2, "Daily series progress counts unique dates, not attempts")

	var normal := Sim.new(617919, {"damage":5}, "vanguard", "rookie", "hard")
	normal.kills = 50
	normal.stage_clears = 4
	normal.won = true
	normal.ended = true
	var standard: Dictionary = Progress.settle(profile,normal)
	check(standard.earned == normal.payout() and profile.last_paid_run == 617919, "Normal flights still pay the full Hangar-based reward")
	check("hard_win" in standard.awarded and Progress.progress(profile,"hard_win") == 1, "Hard victory unlocks independent of Daily difficulty")
	var dup_normal: Dictionary = Progress.settle(profile,normal)
	check(dup_normal.earned == 0 and profile.achievement_stats.hard_wins == 1, "Repeated normal settlement cannot double count a win")

	for id in ["wraith","bulwark"]:
		var victory := Sim.new(70000 + id.length(), {}, id, "rookie", "normal")
		victory.stage_clears = 4
		victory.won = true
		victory.ended = true
		Progress.settle(profile,victory)
	check(Progress.progress(profile,"three_ships") >= 3 and profile.achievements.has("three_ships"), "At least three distinct winning ships earn the Fleet Commander milestone")

	# A newly constructed profile cannot inherit progress from another test.
	var fresh := {"cores":0,"runs":0,"last_paid_run":-1}
	Progress.prepare(fresh)
	check(fresh.achievements.is_empty() and Progress.progress(fresh,"daily_first") == 0, "New profiles start with locked, not accidentally awarded, achievements")
	print("META RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
