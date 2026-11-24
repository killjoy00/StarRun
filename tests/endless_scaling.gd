extends "res://tests/balance_matrix.gd"
## Matched real campaigns; only the Endless tuning changes between revisions.
const DEEP_LIMIT := 12
const DEEP_TIMEOUT := 900.0

func _run() -> void:
	var ship := ""
	var hangar := ""
	var strategy := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ship="): ship = arg.get_slice("=", 1)
		elif arg.begins_with("--hangar="): hangar = arg.get_slice("=", 1)
		elif arg.begins_with("--strategy="): strategy = arg.get_slice("=", 1)
	if ship not in ["vanguard", "bulwark", "haven"] or hangar not in ["p32", "max"] or strategy not in ["timed", "on_cooldown"]:
		push_error("Invalid deep Endless cohort")
		quit(2)
		return
	print("DEEP_CONFIG ", JSON.stringify({"ship":ship,"hangar":hangar,"strategy":strategy,"limit":DEEP_LIMIT,"seeds":4,"offset":310}))
	var faults := 0
	for index in range(4):
		var row := _deep_flight(810000 + (310 + index + 1) * 7919, ship, hangar, strategy)
		print("DEEP_RUN ", JSON.stringify(row))
		if row.status == "fault": faults += 1
	print("DEEP_DONE ", JSON.stringify({"runs":4,"faults":faults}))
	quit(1 if faults else 0)

func _deep_flight(seed: int, ship: String, hangar: String, strategy: String) -> Dictionary:
	var ranks := _hangar(hangar)
	var sim := Sim.new(seed, ranks, ship, "rookie", "normal")
	var stages: Array = []
	var status := "fault"
	var reason := "frame budget exhausted"
	var entry_cores := -1
	for _frame in range(DEEP_LIMIT * 60 * (int(DEEP_TIMEOUT) + 90)):
		if sim.ended:
			status = "won" if sim.won else "dead"
			reason = ""
			break
		if sim.stage_transition_queued:
			stages.append(_stage_report(sim, "cleared"))
			if sim.stage == 4:
				entry_cores = sim.payout()
				if not sim.enable_endless():
					reason = "Endless entry rejected"
					break
			if sim.stage >= DEEP_LIMIT:
				if not sim.claim_endless():
					reason = "Endless claim rejected"
					break
				status = "cap"
				reason = "claimed victory at diagnostic World 12 cap"
				break
			if not sim.begin_intermission():
				reason = "intermission rejected"
				break
			if sim.intermission_step == "prototype" and not sim.choose_prototype(_choose_prototype(sim, "focused")):
				reason = "prototype rejected"
				break
			var route := "overclock" if sim.hull >= sim.max_hull * 0.72 else "repair"
			if not sim.choose_route(route) or not sim.advance_stage():
				reason = "warp rejected"
				break
			continue
		if not sim.pending_build_choices.is_empty():
			sim._auto_resolve_build_choices()
			if not sim.pending_build_choices.is_empty():
				reason = "build choice unresolved"
				break
			continue
		if not sim.cards.is_empty():
			_pick_upgrade(sim, "focused")
			if not sim.cards.is_empty():
				reason = "draft rejected"
				break
			continue
		_cast(sim, strategy)
		if sim.ended or sim.stage_transition_queued or not sim.cards.is_empty(): continue
		var before: int = sim.tick
		sim.step()
		if sim.tick == before and not sim.ended and not sim.stage_transition_queued and sim.cards.is_empty() and sim.pending_build_choices.is_empty():
			reason = "combat clock stalled"
			break
		if sim.time - sim.stage_start > DEEP_TIMEOUT and not sim.ended and not sim.stage_transition_queued:
			status = "timeout"
			reason = "900-second diagnostic limit"
			break
	if stages.is_empty() or int(stages[-1].stage) != sim.stage:
		stages.append(_stage_report(sim, status))
	var settlement := {}
	if sim.ended and status in ["won","dead","cap"]:
		var profile := {"cores":0,"hangar":ranks,"ships_owned":["vanguard"],"pilots_owned":["rookie"],"last_paid_run":-1}
		Progress.prepare(profile)
		var result := Progress.settle(profile, sim)
		var repeated := Progress.settle(profile, sim)
		settlement = {"earned":result.earned,"victories":profile.achievement_stats.victories,"finished_runs":profile.achievement_stats.finished_runs}
		if int(result.earned) != sim.payout() or int(repeated.earned) != 0 or int(profile.achievement_stats.finished_runs) != 1:
			status = "fault"
			reason = "settlement mismatch"
	return {"seed":seed,"ship":ship,"hangar":hangar,"strategy":strategy,"status":status,"reason":reason,"clears":sim.stage_clears,"entry_cores":entry_cores,"seconds":sim.time,"settlement":settlement,"stages":stages}
