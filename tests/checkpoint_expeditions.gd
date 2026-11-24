extends "res://tests/balance_matrix.gd"
## Compare only naturally offered destinations, from identical actual
## intermission checkpoints. Continue one seeded branch for later samples.
## For Archive, compare old/new challenge versions from the same earned entry.
const STAGE_CAP := 900.0
const SEED_OFFSET := 430
const SEED_COUNT := 8

func _run() -> void:
	var ship := ""
	var budget := ""
	var policy := ""
	var suite := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ship="): ship = arg.get_slice("=", 1)
		elif arg.begins_with("--hangar="): budget = arg.get_slice("=", 1)
		elif arg.begins_with("--strategy="): policy = arg.get_slice("=", 1)
		elif arg.begins_with("--suite="): suite = arg.get_slice("=", 1)
	if ship not in ["vanguard","bulwark","haven","arcwing","wraith","kestrel","lancer"] or budget not in ["p8","p32","max"] or policy not in ["timed","on_cooldown"] or suite not in ["routes","archive"]:
		push_error("Invalid checkpoint audit cohort")
		quit(2)
		return
	print("CHECKPOINT_CONFIG ", JSON.stringify({"suite":suite,"ship":ship,"budget":budget,"policy":policy,"seeds":SEED_COUNT,"offset":SEED_OFFSET}))
	var faults := 0
	for i in range(SEED_COUNT):
		var seed := 810000 + (SEED_OFFSET + i + 1) * 7919
		var style := "focused" if i % 2 == 0 else "shielded"
		var row := _campaign(seed, ship, budget, policy, style, suite, i)
		print("CHECKPOINT_RUN ", JSON.stringify(row))
		if row.status == "fault": faults += 1
	print("CHECKPOINT_DONE ", JSON.stringify({"runs":SEED_COUNT,"faults":faults}))
	quit(1 if faults else 0)

func _take_draft(sim: RefCounted, style: String) -> bool:
	# Use actual finite tools, including the Corridor's extra rerolls. Only
	# reroll poor hands; an extra reroll is never automatically a free rank.
	var good_ids := ["pulse","seeker","arc","lance","munitions","autoloader","hull","shield","regen","repair","boss_hunter","finisher"]
	if sim.rerolls_left > 0 and not sim.cards.any(func(c): return str(c.id) in good_ids):
		sim.reroll_cards()
	_pick_upgrade(sim, style)
	if not sim.pending_build_choices.is_empty():
		sim._auto_resolve_build_choices()
	return sim.cards.is_empty()

func _fly_world(sim: RefCounted, strategy: String, style: String, signals: bool) -> Dictionary:
	var world: int = sim.stage
	var casts_before: int = sim.ability_uses
	var counters_before: int = sim.beams_cancelled
	var fired_before: int = sim.beams_fired
	var level_before: int = sim.level
	var kills_before: int = sim.kills
	var hull_start: float = sim.hull
	var shield_start: float = sim.shield
	var rerolls_used := 0
	var curated_picks := 0
	var damage_before := _total_damage(sim.damage_taken)
	var boss_damage_before := -1.0
	var boss_counters_before := -1
	var status := "fault"
	var reason := "frame budget"
	for _frame in range(60 * (int(STAGE_CAP) + 90)):
		if sim.stage != world:
			reason = "unexpected world transition"
			break
		if sim.ended or sim.stage_transition_queued:
			status = "cleared" if sim.stage_transition_queued and sim.stage_clears == world else "dead"
			reason = ""
			break
		if sim.boss_spawned and boss_damage_before < 0.0:
			boss_damage_before = _total_damage(sim.damage_taken)
			boss_counters_before = sim.beams_cancelled
		if sim.secret_intro_pending:
			if not sim.dismiss_secret_intro():
				reason = "intro refused"
				break
			continue
		if not sim.pending_build_choices.is_empty():
			sim._auto_resolve_build_choices()
			if not sim.pending_build_choices.is_empty():
				reason = "build choice stalled"
				break
			continue
		if not sim.cards.is_empty():
			var rerolls_before: int = sim.rerolls_left
			var curated: bool = sim.smuggler_draft_open
			if not _take_draft(sim, style):
				reason = "draft refused"
				break
			rerolls_used += maxi(0, rerolls_before - int(sim.rerolls_left))
			if curated: curated_picks += 1
			continue
		if signals and not sim.secret_entered and sim.signal_status == "offer":
			if not sim.choose_signal("cast"):
				reason = "signal rejected"
				break
		if signals and sim.signal_cast_window():
			for ability in sim.active_slots:
				if sim.activate(str(ability)): break
		# Timed policy reserves a ready cast for actual Archive warnings.
		# Cooldown-only does NOT special-case the boss's lock.
		if strategy == "timed" and sim.secret_entered and not sim.archive_attack.is_empty():
			for ability in sim.active_slots:
				if sim.activate(str(ability)): break
		_cast(sim, strategy)
		if sim.ended or sim.stage_transition_queued or not sim.cards.is_empty(): continue
		var before: int = sim.tick
		sim.step()
		if before == sim.tick and not sim.ended and not sim.stage_transition_queued and sim.cards.is_empty() and sim.pending_build_choices.is_empty() and not sim.secret_intro_pending:
			reason = "combat clock stalled"
			break
		if sim.time - sim.stage_start > STAGE_CAP and not sim.ended and not sim.stage_transition_queued:
			status = "timeout"
			reason = "unpaid diagnostic cap"
			break
	var row := _stage_report(sim, status)
	row.merge({"reason":reason,"start_hull":hull_start,"start_shield":shield_start,"level_gain":sim.level-level_before,"kill_gain":sim.kills-kills_before,"casts":sim.ability_uses-casts_before,"counters":sim.beams_cancelled-counters_before,"beams":sim.beams_fired-fired_before,"cores_if_claimed":sim.payout(),"archive_phase":sim.archive_phase,"mutations":sim.mutations.duplicate(),"rerolls_left":sim.rerolls_left,"rerolls_used":rerolls_used,"curated_picks":curated_picks,"route_version":sim.destination_rules_version,"stage_damage":_total_damage(sim.damage_taken)-damage_before,"boss_damage":maxf(0.0,_total_damage(sim.damage_taken)-boss_damage_before) if boss_damage_before >= 0.0 else 0.0,"boss_counters":sim.beams_cancelled-boss_counters_before if boss_counters_before >= 0 else 0}, true)
	return row

func _total_damage(receipts: Dictionary) -> float:
	var total := 0.0
	for value in receipts.values():
		total += float(value)
	return total

func _select_destination(sim: RefCounted, id: String) -> bool:
	if not sim.choose_route(id):
		return false
	if sim.intermission_step == "mutation":
		if sim.mutation_offers.is_empty() or not sim.choose_lab_mutation(str(sim.mutation_offers[0])):
			return false
	return sim.advance_stage()

func _campaign(seed: int, ship: String, budget: String, policy: String, style: String, suite: String, index: int) -> Dictionary:
	var sim := Sim.new(seed, _hangar(budget), ship, "rookie", "normal")
	if not sim.enable_expedition_rules():
		return {"seed":seed,"status":"fault","reason":"new rules refused"}
	var stages: Array = []
	var forks: Array = []
	var archives: Array = []
	var status := "fault"
	var reason := "unsettled"
	for world in range(1,5):
		var row := _fly_world(sim, policy, style, suite == "archive")
		stages.append(row)
		status = str(row.status)
		reason = str(row.reason)
		if status != "cleared" or world == 4: break
		if not sim.begin_intermission():
			status = "fault"
			reason = "intermission refused"
			break
		if sim.intermission_step == "prototype" and not sim.choose_prototype(_choose_prototype(sim, style)):
			status = "fault"
			reason = "prototype refused"
			break
		var hand: Array = sim.available_destinations()
		if hand.size() != 3:
			status = "fault"
			reason = "invalid offered hand"
			break
		# Rotate the continuation slot across seeds and worlds, independent
		# of outcomes, so the sample is not biased toward assault successes.
		var continuation: String = str(hand[(index + world - 1) % 3])
		if suite == "routes":
			var checkpoint: Dictionary = sim.snapshot()
			var start := {"hull_fraction":sim.hull/sim.max_hull,"shield_fraction":sim.shield/sim.max_shield,"level":sim.level,"cores":sim.payout(),"ranked_weapons":sim.active_slots.duplicate(),"mutation":not sim.mutations.is_empty(),"lab_seen":sim.mutation_lab_seen,"rerolls":sim.rerolls_left,"prototype":sim.prototypes.duplicate()}
			var variants: Array = []
			for id in hand:
				var fork := Sim.new(seed, _hangar(budget), ship, "rookie", "normal")
				if not fork.restore(checkpoint) or fork.snapshot() != checkpoint or not _select_destination(fork, str(id)):
					status = "fault"
					reason = "checkpoint clone or actual offered choice failed"
					break
				var result := _fly_world(fork, policy, style, false)
				result["id"] = str(id)
				result["incremental_cores"] = int(result.cores_if_claimed) - int(start.cores)
				variants.append(result)
				if result.status == "fault":
					status = "fault"
					reason = str(result.reason)
					break
			if status == "fault": break
			var controls: Array = []
			# Use the actual previous route spec through the same API. Never
			# replace a naturally offered ID or inject a different loadout.
			for id in hand:
				if id not in ["shipyard","graveyard","smugglers","uncharted"]:
					continue
				var probe := Sim.new(seed, _hangar(budget), ship, "rookie", "normal")
				if not probe.restore(checkpoint) or probe.snapshot() != checkpoint:
					status = "fault"
					reason = "matched control restore failed"
					break
				probe.destination_rules_version = 0
				if not _select_destination(probe, str(id)):
					status = "fault"
					reason = "actual control destination refused"
					break
				var control := _fly_world(probe, policy, style, false)
				control["id"] = str(id)
				control["incremental_cores"] = int(control.cores_if_claimed) - int(start.cores)
				controls.append(control)
				if control.status == "fault":
					status = "fault"
					reason = str(control.reason)
					break
			if status == "fault": break
			forks.append({"world":world+1,"offered":hand,"continued":continuation,"start":start,"variants":variants,"controls":controls})
		if not _select_destination(sim, continuation):
			status = "fault"
			reason = "continuation rejected"
			break
	# Archive: preserve the actual run and its earned payout. Only the
	# newly-entered boss version is varied, not its weapons or phase state.
	if suite == "archive" and status == "cleared" and sim.stage == 4 and sim.can_enter_secret():
		var decision := sim.snapshot()
		var entry: int = sim.payout()
		for revision in ["control","initial","candidate"]:
			var fork := Sim.new(seed, _hangar(budget), ship, "rookie", "normal")
			if not fork.restore(decision) or fork.snapshot() != decision or not fork.enter_secret():
				status = "fault"
				reason = "earned Archive entry rejected"
				break
			if revision == "control": fork.archive_challenge_version = 0
			elif revision == "initial": fork.archive_challenge_version = 2
			elif not fork.archive_boss_reworked() or fork.archive_challenge_version != 3:
				status = "fault"
				reason = "candidate challenge not enabled on real entry"
				break
			var row := _fly_world(fork, policy, style, true)
			row["revision"] = revision
			row["archive_version"] = fork.archive_challenge_version
			row["remaining_emitters"] = fork._alive_modules("archive_emitter")
			row["entry_cores"] = entry
			row["locked_cores"] = fork.payout()
			archives.append(row)
			if row.status == "fault" or fork.payout() != entry:
				status = "fault"
				reason = "Archive combat or locked payout defect: " + str(row.reason)
				break
	return {"seed":seed,"ship":ship,"budget":budget,"policy":policy,"style":style,"suite":suite,"status":status,"reason":reason,"stages":stages,"forks":forks,"archive_eligible":sim.can_enter_secret(),"signals":sim.signal_count,"archives":archives}
