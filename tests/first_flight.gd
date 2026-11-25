extends SceneTree

const Main = preload("res://scripts/main.gd")
const Sim = preload("res://scripts/simulation.gd")
const Intro = preload("res://scripts/first_flight.gd")
const Services = preload("res://scripts/platform_services.gd")

class MemoryServices extends "res://scripts/platform_services.gd":
	var values: Dictionary = {}
	var refuse_profile := false
	var refuse_run := false

	func read_save(path: String) -> Dictionary:
		return values.get(path, {}).duplicate(true)

	func write_atomic(path: String, value: Dictionary) -> bool:
		if (path == PROFILE and refuse_profile) or (path == RUN and refuse_run):
			return false
		values[path] = value.duplicate(true)
		return true

	func delete_run() -> void:
		values.erase(RUN)

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _scene(storage: MemoryServices) -> Node:
	var scene := Main.new()
	scene.services = storage
	root.add_child(scene)
	scene.set_process(false)
	scene.world.set_process(false)
	scene.sound.enabled = false
	scene.sound.music_enabled = false
	return scene

func _restored(sim: RefCounted, label: String) -> RefCounted:
	var state: Dictionary = sim.snapshot()
	var resumed := Sim.new()
	check(resumed.restore(state) and resumed.snapshot() == state, label + " round-trips exactly")
	return resumed

func _run() -> void:
	for first in range(3):
		for second in range(3):
			_play_drafts(first, second)
			_check_passive_ejection(first, second)
	_check_legacy_checkpoint()
	_check_harvester_entrance()
	_check_eligibility()
	_check_real_scene()
	print("FIRST FLIGHT: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func _play_drafts(first: int, second: int) -> void:
	var sim: RefCounted = Sim.new(Intro.SEED)
	sim.configure_first_flight(true)
	var first_kill := -1.0
	var first_cast := -1.0
	var first_draft := -1.0
	var first_payoff := -1.0
	var first_weapon := ""
	var damage_before := 0.0
	var boss_at := -1.0
	var first_chain := 0
	var second_chain := 0
	var aegis_at_impact := false
	var all_entered := true
	var early_peak := 0
	var late_peak := 0
	var early := first == 1 and second == 2
	var missed := first == 2 and second == 2
	if early:
		# Deliberately consume Aegis before the first sniper ever starts charging.
		while sim.tick < 360:
			sim.step()
			if first_kill < 0.0 and sim.kills > 0:
				first_kill = sim.time
		check(sim.activate("aegis"), "Early cast is accepted by the ordinary ability engine")
		first_cast = sim.time
	var steps := 0
	while not sim.ended and steps < 16000:
		steps += 1
		if sim.intro_aegis_prompt:
			var tick: int = sim.tick
			sim.step()
			check(sim.tick == tick, "Reading the beam lesson freezes combat")
			sim = _restored(sim, "Aegis lesson")
			if early:
				check(sim.time > 29.0, "Second sniper offers a lesson after the early cast")
			if missed:
				sim.intro_aegis_prompt = false
			else:
				check(sim.activate("aegis"), "Real Aegis is usable in the lesson")
				if first_cast < 0.0:
					first_cast = sim.time
		if not sim.cards.is_empty():
			check(sim.cards.size() == 3, "Both drafts offer three real cards")
			sim = _restored(sim, "Draft")
			var first_draft_open: bool = sim.intro_picks.is_empty()
			if first_draft_open:
				check(sim.cards[0].id == "arc" and Intro.recommendation(sim).begins_with("Pick Arc coil"), "The first draft points to Arc coil")
			else:
				check(sim.time == Intro.DRAFT_AT[1] and Intro.recommendation(sim).begins_with("Pick " + str(sim.cards[0].name) + " again"), "The second draft recommends the chosen weapon upgrade")
			var index := first if first_draft_open else second
			var card: Dictionary = sim.cards[index]
			var id: String = str(card.id)
			var rank: int = int(sim.upgrades[id])
			if first_draft_open:
				first_draft = sim.time
				first_weapon = id
				damage_before = float(sim.damage_dealt.get(id, 0.0))
			else:
				check(str(sim.cards[0].id) == first_weapon, "Draft two includes the first weapon")
			check(sim.choose_card(index), "The authored card installs through the existing draft API")
			check(sim.upgrades[id] == rank + Sim.rank_gain(card, rank), "The picked upgrade grants its real ranks")
			sim = _restored(sim, "Installed upgrade")
		# After the lesson, use ordinary warnings. A missed lesson should
		# remain survivable with later casts and no cooldown forgiveness.
		if not sim.charges.is_empty() and sim.charges[0].remaining <= 0.65:
			if not missed or sim.time >= 29.0:
				if sim.activate("aegis") and first_cast < 0.0:
					first_cast = sim.time
		if first == 0 and second == 0 and not aegis_at_impact and sim.time >= Intro.BOSS_AT + Intro.EJECT_AFTER - 0.25:
			aegis_at_impact = sim.activate("aegis")
		var first_new_id: int = sim.next_id
		sim.step()
		if sim.next_id > first_new_id:
			for enemy in sim.enemies:
				if int(enemy.id) >= first_new_id:
					all_entered = all_entered and enemy.p.y < 0.0 and enemy.has("arrive_y")
		if sim.tick % 15 == 0:
			var on_screen: int = sim.enemies.filter(func(e): return e.hp > 0.0 and e.p.y >= 0.0 and e.p.y < Sim.HEIGHT).size()
			if sim.time <= 12.0:
				early_peak = maxi(early_peak, on_screen)
			elif sim.time >= 45.0:
				late_peak = maxi(late_peak, on_screen)
		if first_kill < 0.0 and sim.kills > 0:
			first_kill = sim.time
		if first_payoff < 0.0 and not first_weapon.is_empty() and float(sim.damage_dealt[first_weapon]) > damage_before:
			first_payoff = sim.time
		if boss_at < 0.0 and sim.boss_spawned:
			boss_at = sim.time
			sim = _restored(sim, "Harvester arrival")
		if first == 0 and second == 0:
			var chain: int = sim.effects.filter(func(effect): return effect.kind == "arc" and effect.born == sim.tick).size()
			if sim.time >= 24.0 and sim.time < 29.0:
				first_chain = maxi(first_chain, chain)
			elif sim.time >= 49.0 and sim.time < 55.5:
				second_chain = maxi(second_chain, chain)
	check(sim.intro_ejected and sim.ended and not sim.won and sim.hull == 0.0 and sim.stage_clears == 0 and not sim.stage_transition_queued, "The Harvester destroys the ship on branch %d/%d" % [first, second])
	check(sim.intro_beam_blocked or (early and sim.beams_cancelled > 0), "A well-timed Aegis or destruction of the charging ship still stops a beam")
	check(all_entered, "Launch ships, reinforcements and draft formations all enter from offscreen")
	check(early_peak >= 7 and late_peak >= 8, "Crowded waves on path %d/%d, early peak %d, late peak %d" % [first, second, early_peak, late_peak])
	if first == 0 and second == 0:
		check(first_chain >= 3 and second_chain > first_chain, "The recommended Arc upgrade visibly chains to more targets")
		check(aegis_at_impact and sim.intro_ejected, "A cast immediately before the main gun still ends in ejection")
	check(first_kill >= 0.0 and first_kill < 3.0 and first_cast > 0.0, "A kill and a cast happen in the opening")
	check(first_draft == Intro.DRAFT_AT[0] and first_payoff >= first_draft and first_payoff < first_draft + 10.0, "First pick does damage in the next wave")
	check(boss_at == Intro.BOSS_AT and absf(sim.time - Intro.BOSS_AT - Intro.EJECT_AFTER) <= Sim.DT + 0.001, "Harvester arrival and ejection meet the scripted timing")
	if missed:
		check(sim.damage_taken.heavy > 0.0 and first_cast > 29.0, "A missed cast deals real damage and a later cast recovers")
	print("TRACE %s: kill %.2fs, first cast %.2fs, first draft %.2fs, first weapon damage %.2fs, boss %.2fs, finish %.2fs" % [
		sim.intro_picks, first_kill, first_cast, first_draft, first_payoff, boss_at, sim.time,
	])

func _check_passive_ejection(first: int, second: int) -> void:
	var sim := Sim.new(Intro.SEED)
	sim.configure_first_flight(true)
	for tick in range(4600):
		if sim.ended:
			break
		sim.intro_aegis_prompt = false
		if not sim.cards.is_empty():
			sim.choose_card(first if sim.intro_picks.is_empty() else second)
		sim.step()
	check(sim.intro_ejected and sim.ability_uses == 0, "Without Aegis, branch %d/%d still reaches the ejection" % [first, second])

func _check_legacy_checkpoint() -> void:
	var legacy := Sim.new(Intro.SEED)
	legacy.intro_run = true
	legacy.intro_reward_eligible = true
	for tick in range(2300):
		legacy.intro_aegis_prompt = false
		legacy.step()
		if not legacy.cards.is_empty():
			break
	var state := legacy.snapshot()
	state.erase("intro_scripted")
	state.erase("intro_ejected")
	var restored := Sim.new()
	check(restored.restore(state) and not restored.intro_scripted, "A saved original flight keeps the earlier encounter schedule")
	check(restored.time == Intro.LEGACY_DRAFT_AT[0] and restored.cards.size() == 3 and Intro.boss_at(restored) == Intro.LEGACY_BOSS_AT, "The original first draft and boss timing survive the update")
	for tick in range(13000):
		if restored.ended:
			break
		restored.intro_aegis_prompt = false
		if not restored.cards.is_empty():
			restored.choose_card(0)
		if restored.charges.any(func(charge): return charge.remaining <= 0.65):
			restored.activate("aegis")
		restored.step()
	check(restored.won and not restored.intro_ejected, "An original flight can still defeat the Harvester")
	var profile := {"cores": 0, "intro_status": "available"}
	Main.Progress.settle_first_flight(profile, restored)
	check(profile.cores == Intro.REWARD and profile.intro_status == "complete", "Winning an old suspended intro still earns its reward")

func _check_harvester_entrance() -> void:
	var sim := Sim.new(Intro.SEED)
	sim.configure_first_flight(true)
	sim._add_enemy("gunship", Vector2(150, 320))
	var escort_id: int = int(sim.enemies[0].id)
	sim.time = Intro.BOSS_AT
	Intro.spawn(sim)
	check(sim.enemies.any(func(e): return int(e.id) == escort_id), "The Harvester arrives while the remaining escort is still flying")
	var boss := sim._boss_core()
	check(not boss.is_empty() and boss.p.y < 0.0 and boss.has("arrive_y"), "The Harvester also enters from above the playfield")

func _check_eligibility() -> void:
	var unopened := MemoryServices.new()
	var fresh := _scene(unopened)
	check(fresh.profile.intro_status == "available", "New profiles are offered the intro")
	fresh._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(not fresh.flight_started and unopened.read_save(Services.RUN).is_empty(), "An untouched title has no flight to checkpoint")
	fresh._launch_daily()
	check(not fresh.sim.intro_run and not fresh.sim.daily_day.is_empty(), "The Daily bypasses the intro for a new profile")
	fresh.free()

	var prior := MemoryServices.new()
	prior.write_atomic(Services.PROFILE, {"cores": 14, "runs": 0, "sound": false})
	var legacy := _scene(prior)
	check(legacy.profile.intro_status == "legacy", "A pre-feature profile with zero runs is still a returning profile")
	legacy._launch()
	check(not legacy.sim.intro_run and legacy.sim.expedition_active(), "Returning players launch the ordinary campaign")
	legacy.free()

	var suspended := MemoryServices.new()
	var regular := Sim.new(581337)
	for i in range(60):
		regular.step()
	suspended.write_atomic(Services.RUN, regular.snapshot())
	var returning := _scene(suspended)
	check(returning.profile.intro_status == "legacy", "A suspended regular run wins over onboarding even without a profile")
	returning._resume_run()
	check(returning.sim.snapshot() == regular.snapshot(), "Resuming a regular save stays exact")
	returning.free()

	var skipped := MemoryServices.new()
	var bypass := _scene(skipped)
	bypass._launch()
	bypass._show_pause()
	var lost_race := skipped.read_save(Services.RUN)
	bypass._new_run()
	check(not bypass.sim.intro_run and bypass.profile.intro_status == "skipped" and bypass.profile.cores == 0, "Skipping an active intro launches regular play with no payment")
	skipped.write_atomic(Services.RUN, lost_race)
	bypass.free()
	var after_skip := _scene(skipped)
	check(after_skip._saved_flight().is_empty(), "A stale intro checkpoint cannot undo a committed skip")
	after_skip._launch()
	check(not after_skip.sim.intro_run, "The next Launch stays regular after the skip")
	after_skip.free()

func _check_real_scene() -> void:
	var storage := MemoryServices.new()
	var scene := _scene(storage)
	scene._launch()
	check(scene.sim.intro_run and scene.sim.intro_reward_eligible and scene.game_speed == 1.0, "The title starts a fresh Vanguard first flight at 1×")
	scene._cycle_speed()
	scene._cycle_speed()
	var original: Dictionary = scene.sim.snapshot()
	scene._show_pause()
	scene.free()
	scene = _scene(storage)
	scene._resume_run()
	check(scene.sim.snapshot() == original and scene.game_speed == 3.0, "Fresh process restores intro checkpoint and speed")
	_run_scene(scene, false)
	check(scene.mode == "intro_crash" and scene.sim.intro_ejected and not scene.sim.won, "The first flight reaches the ejection animation without a win")
	var terminal: Dictionary = storage.read_save(Services.RUN)
	check(terminal.ended and terminal.intro_ejected and not terminal.won, "The ejection checkpoint is durable before the debrief")
	storage.refuse_run = true
	scene._process(Intro.CRASH_SECONDS + 0.1)
	check(scene.mode == "intro_results" and scene.intro_save_pending and scene.profile.cores == 0, "A failed checkpoint write defers settlement")
	storage.refuse_run = false
	storage.refuse_profile = true
	scene._finish_intro_run()
	check(scene.intro_save_pending and scene.profile.cores == 0, "Failed profile write does not credit Cores in memory")
	scene.free()
	storage.refuse_profile = false
	scene = _scene(storage)
	scene._new_run()
	check(scene.mode == "intro_results" and scene.profile.cores == Intro.REWARD and scene.result_earned_cores == Intro.REWARD, "Launching after a restart recovers the unpaid ejection before starting the campaign")
	var labels: Array = scene.find_children("*", "Label", true, false)
	check(labels.any(func(label): return label.text == "Pilot recovered"), "The scripted ending shows the pilot recovery debrief")
	scene._resume_run()
	check(scene.profile.cores == Intro.REWARD and int(scene.profile.achievement_stats.finished_runs) == 0 and scene.profile.codex.is_empty(), "Repeated settlement grants no extra Cores, awards or Codex progress")
	var price: int = scene.Catalog.price("hull", 0)
	scene._buy_intro_plating()
	check(scene.profile.cores == Intro.REWARD - price and scene.profile.hangar.hull == 1, "Debrief plating spends real Cores")
	scene._new_intro_run(true)
	check(not scene.sim.intro_reward_eligible, "Guide replay uses the same opening with no reward eligibility")
	scene._cycle_speed()
	scene._cycle_speed()
	_run_scene(scene, true)
	scene._process(Intro.CRASH_SECONDS + 0.1)
	check(scene.mode == "intro_results" and scene.sim.intro_ejected and scene.sim.intro_beam_blocked and scene.result_earned_cores == 0 and scene.profile.cores == Intro.REWARD - price, "A successful Aegis lesson still ends at the ejection and a replay pays no duplicate Cores")
	scene._new_run()
	check(scene.mode == "playing" and not scene.sim.intro_run and scene.sim.stage == 1 and scene.sim.expedition_active() and scene.sim.meta.hull == 1 and scene.game_speed == 1.0, "Debrief Launch starts the seeded campaign with the purchased plating")
	print("TRACE second flight: seed %d, world %d, campaign launches %d" % [scene.sim.seed_value, scene.sim.stage, scene.profile.runs])
	scene.free()

func _run_scene(scene: Node, timed: bool) -> void:
	var checked_pause := false
	var checked_boss := false
	for i in range(1250):
		if scene.mode in ["intro_results", "intro_clear", "intro_crash"]:
			return
		if scene.mode == "intro_aegis":
			if not checked_pause:
				checked_pause = true
				var state: Dictionary = scene.sim.snapshot()
				scene._resume_run()
				check(scene.mode == "intro_aegis" and scene.sim.snapshot() == state, "Resuming reveals the exact paused Aegis opportunity")
				check(not scene.ability_a.disabled, "The real Aegis button is actionable in the lesson")
				check(scene.intro_popup_layer.visible and scene.intro_popup_buttons.visible and scene.intro_popup_title.text == "Block the beam", "Resuming the lesson shows the centered actionable popup")
			if timed:
				scene.intro_popup_aegis.pressed.emit()
			else:
				scene.intro_continue.pressed.emit()
		elif scene.mode == "boss_intro" and not checked_boss:
			checked_boss = true
			var state: Dictionary = scene.sim.snapshot()
			scene._resume_run()
			check(scene.mode == "boss_intro" and scene.sim.snapshot() == state, "An interrupted boss entrance resumes before combat")
		elif scene.mode == "playing" and timed and not scene.sim.charges.is_empty() and scene.sim.charges[0].remaining <= 0.66:
			scene.ability_a.pressed.emit()
		elif scene.mode == "cards" and scene.draft_guard <= 0.0:
			var labels: Array = scene.find_children("*", "Label", true, false)
			check(labels.any(func(label): return label.text == Intro.recommendation(scene.sim)), "The live draft tells the player which card to pick")
			scene._choose(0)
		scene._process(0.2)
	check(false, "Scene does not reach a terminal state")
