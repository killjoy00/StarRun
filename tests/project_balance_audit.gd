extends "res://tests/balance_matrix.gd"
## Opt-in research driver. No product changes, injected rewards, forced kills,
## or forced drafts. Inherit existing scripted pilot and three draft policies.
const AUDIT_STAGE_SECONDS := 900.0
const ENDLESS_STOP := 7

func _run() -> void:
	var suite := ""
	var ship := ""
	var seeds := 4
	var offset := 200
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--suite="): suite = arg.get_slice("=", 1)
		elif arg.begins_with("--ship="): ship = arg.get_slice("=", 1)
		elif arg.begins_with("--seeds="): seeds = int(arg.get_slice("=", 1))
		elif arg.begins_with("--seed-offset="): offset = int(arg.get_slice("=", 1))
	if suite not in ["build", "route", "difficulty", "economy", "endgame"] or not Catalog.SHIPS.any(func(item): return str(item.id) == ship) or seeds < 1 or seeds > 32 or offset < 0:
		push_error("Expected audit suite, real ship, and 1-32 seeds")
		quit(2)
		return
	var configs: Array = []
	match suite:
		"build":
			for style in ["baseline", "focused", "shielded", "focused_alt", "engine"]:
				configs.append({"label":style,"build":style})
		"route":
			for route in ["repair", "overclock", "bounty", "adaptive"]:
				configs.append({"label":route,"route":route,"build":"focused"})
		"difficulty":
			for difficulty in Catalog.DIFFICULTIES:
				for share in [0, 32, 100]:
					configs.append({"label":"%s-p%d" % [difficulty, share], "difficulty":difficulty,"share":share,"build":"focused"})
		"economy":
			for style in ["spread", "weapons", "hull", "abilities", "salvage", "tools"]:
				configs.append({"label":style,"share":8,"portfolio":style,"build":"focused","tools":true})
			configs.append({"label":"spread-no-tools","share":8,"portfolio":"spread","build":"focused","tools":false})
		"endgame":
			for mode in ["finish", "endless", "archive"]:
				configs.append({"label":mode,"share":100,"build":"focused","endgame":mode})
	print("AUDIT_CONFIG ", JSON.stringify({"suite":suite,"ship":ship,"seeds":seeds,"offset":offset,"labels":configs.map(func(item): return item.label)}))
	if suite == "economy":
		for item in Catalog.HANGAR:
			var prices: Array = []
			for rank in range(int(item.max)): prices.append(Catalog.price(str(item.id), rank))
			print("AUDIT_PRICE ", JSON.stringify({"id":item.id,"name":item.name,"group":item.group,"description":item.description,"prices":prices}))
	var faults := 0
	for config in configs:
		for index in range(seeds):
			var seed := 810000 + (offset + index + 1) * 7919
			var row := _audit_flight(seed, ship, config)
			row["suite"] = suite
			row["label"] = config.label
			print("AUDIT_RUN ", JSON.stringify(row))
			if str(row.status) == "fault": faults += 1
	print("AUDIT_DONE ", JSON.stringify({"suite":suite,"ship":ship,"runs":seeds * configs.size(),"faults":faults}))
	quit(1 if faults > 0 else 0)

func _audit_portfolio(share: int, style: String) -> Dictionary:
	var maxed := _hangar("max")
	var budget := floori(float(Catalog.refund(maxed)) * share / 100.0)
	if style == "spread":
		return Catalog.share_hangar(share)
	# Same ceiling, not identical spending (discrete prices). Preserve a
	# common 1% foundation, then prioritize a real group, including XP/Core
	# and draft-tool portfolios. No subsidized ranks.
	var owned := Catalog.share_hangar(1)
	var bank := budget - Catalog.refund(owned)
	var preferred := {"weapons":"Weapons", "hull":"Hull", "abilities":"Abilities", "salvage":"Salvage", "tools":"Tactics"}
	while bank > 0:
		var best := ""
		var best_priority := 2
		var best_price := 2147483647
		for item in Catalog.HANGAR:
			var id: String = str(item.id)
			var rank: int = int(owned.get(id, 0))
			if rank >= int(item.max): continue
			var price: int = Catalog.price(id, rank)
			if price > bank: continue
			var priority := 0 if str(item.group) == str(preferred.get(style, "")) else 1
			if priority < best_priority or (priority == best_priority and price < best_price):
				best = id
				best_priority = priority
				best_price = price
		if best.is_empty(): break
		owned[best] = int(owned.get(best, 0)) + 1
		bank -= best_price
	return owned

func _audit_engine_pick(sim: RefCounted) -> void:
	# Prefer a naturally offered missing engine ingredient; no card injection.
	# Select the engine with strongest existing investment, then let normal
	# focused choices handle hands without an ingredient.
	if sim.hull < sim.max_hull * 0.35:
		_pick_focused(sim)
		return
	var target: Array = []
	var best_score := -1.0
	for spec in sim.content.build_engines:
		var primary: String = str(spec.primary)
		var secondary: String = str(spec.secondary)
		var third: String = str(spec.get("third", ""))
		for option in spec.get("third_any", []):
			if third.is_empty() or int(sim.upgrades.get(option, 0)) > int(sim.upgrades.get(third, 0)): third = str(option)
		var score := float(mini(5, int(sim.upgrades.get(primary, 0))) * 2 + mini(2, int(sim.upgrades.get(secondary, 0))) + mini(2, int(sim.upgrades.get(third, 0))))
		if sim.engine_tier(str(spec.id)) >= 2: score -= 12.0
		if score > best_score:
			best_score = score
			target = [primary, secondary, third]
	var best := -1
	var best_priority := 999
	for index in range(sim.cards.size()):
		var id: String = str(sim.cards[index].id)
		var rank: int = int(sim.upgrades.get(id, 0))
		var priority := target.find(id)
		if priority >= 0 and rank < (5 if priority == 0 else 2) and priority < best_priority:
			best = index
			best_priority = priority
	if best >= 0:
		sim.choose_card(best)
	else:
		_pick_focused(sim)

func _audit_draft(sim: RefCounted, style: String, use_tools: bool, counts: Dictionary) -> bool:
	var hand: Array = sim.cards.duplicate(true)
	for card in hand: _audit_increment(counts.offers, str(card.id))
	if use_tools:
		var desirable := ["pulse","seeker","arc","lance","munitions","autoloader","hull","shield","regen","repair","boss_hunter","finisher"]
		var good: bool = sim.cards.any(func(card): return str(card.id) in desirable)
		# Spend real finite tools only on a poor hand, never roll indefinitely.
		if not good and sim.hull < sim.max_hull * 0.25 and sim.skips_left > 0 and sim.skip_cards():
			_audit_increment(counts.tools, "skip")
			return true
		if not good and sim.banishes_left > 0:
			for index in range(sim.cards.size()):
				if str(sim.cards[index].id) in ["salvage", "harvester"] and sim.banish_card(index):
					_audit_increment(counts.tools, "banish")
					break
		good = sim.cards.any(func(card): return str(card.id) in desirable)
		if not good and sim.rerolls_left > 0 and sim.reroll_cards():
			_audit_increment(counts.tools, "reroll")
		if sim.cards != hand:
			hand = sim.cards.duplicate(true)
			for card in hand: _audit_increment(counts.offers, str(card.id))
	var prior_events: Array = sim.events.duplicate(true)
	if style == "engine": _audit_engine_pick(sim)
	else: _pick_upgrade(sim, "focused" if style == "focused_alt" else style)
	if not sim.cards.is_empty(): return false
	# Production choose_card logs the exact installed card name. It is not
	# safe to infer a choice from an unchanged hull or a consumed fusion.
	for index in range(sim.events.size() - 1, maxi(-1, sim.events.size() - 8), -1):
		var message: String = str(sim.events[index].message)
		if not message.begins_with("Installed "): continue
		for card in hand:
			if message == "Installed " + str(card.name):
				_audit_increment(counts.picks, str(card.id))
				return true
		break
	# Treat absent instrumentation as missing, not as a fabricated selection.
	counts["unidentified_picks"] = int(counts.unidentified_picks) + 1
	return true

func _audit_increment(target: Dictionary, id: String) -> void:
	target[id] = int(target.get(id, 0)) + 1

func _audit_choices(sim: RefCounted, style: String, counts: Dictionary) -> bool:
	while not sim.pending_build_choices.is_empty():
		var choice: Dictionary = sim.pending_build_choices[0]
		var id: String = str(choice.id)
		var answer := "fuse"
		if str(choice.kind) == "evolution":
			var options: Array = sim.content.weapon_evolutions[id]
			var preferred := 1 if style == "focused_alt" or (id == "arc" and sim.ship_id == "arcwing") else 0
			if style == "focused_alt" and id == "arc" and sim.ship_id == "arcwing": preferred = 0
			answer = str(options[preferred].id)
			for option in options: _audit_increment(counts.evolution_offers, str(option.id))
		else:
			_audit_increment(counts.fusion_offers, id)
		if not sim.resolve_build_choice(answer): return false
	return true

func _audit_snapshot(sim: RefCounted, status: String) -> Dictionary:
	var row := _stage_report(sim, status)
	var tiers := {}
	for spec in sim.content.build_engines: tiers[str(spec.id)] = sim.engine_tier(str(spec.id))
	var fusions: Array = []
	for spec in sim.content.fusions:
		if int(sim.upgrades.get(str(spec.id), 0)) > 0: fusions.append(str(spec.id))
	row["tiers"] = tiers
	row["engine_procs"] = sim.engine_procs.duplicate(true)
	row["fusions"] = fusions
	row["evolutions"] = sim.weapon_evolutions.duplicate(true)
	row["mutations"] = sim.mutations.duplicate(true)
	row["all_ranks"] = sim.upgrades.duplicate(true)
	row["cores_if_claimed"] = sim.payout()
	row["signals"] = sim.signal_count
	return row

func _audit_flight(seed: int, ship: String, config: Dictionary) -> Dictionary:
	var difficulty: String = str(config.get("difficulty", "normal"))
	var style: String = str(config.get("build", "baseline"))
	var route: String = str(config.get("route", "repair"))
	var endgame: String = str(config.get("endgame", ""))
	var share: int = int(config.get("share", 32))
	var portfolio: String = str(config.get("portfolio", "spread"))
	var hangar := _audit_portfolio(share, portfolio)
	var sim := Sim.new(seed, hangar, ship, "rookie", difficulty)
	var counts := {"offers":{},"picks":{},"prototype_offers":{},"prototype_picks":{},"evolution_offers":{},"fusion_offers":{},"tools":{},"unidentified_picks":0}
	var stages: Array = []
	var status := "fault"
	var reason := "frame budget exhausted"
	var entry_cores := -1
	var archive_eligible := false
	var endgame_entered := false
	var limit := ENDLESS_STOP if endgame == "endless" else (5 if endgame == "archive" else 4)
	for frame in range(limit * 60 * (int(AUDIT_STAGE_SECONDS) + 90)):
		if sim.ended:
			status = "won" if sim.won else "dead"
			reason = ""
			break
		if sim.secret_intro_pending:
			if not sim.dismiss_secret_intro():
				reason = "archive intro rejected"
				break
			continue
		if sim.stage_transition_queued:
			stages.append(_audit_snapshot(sim, "cleared"))
			if sim.stage == 4:
				entry_cores = sim.payout()
				archive_eligible = sim.can_enter_secret()
				if endgame == "archive" and archive_eligible:
					if not sim.enter_secret():
						reason = "eligible Archive entry refused"
						break
					endgame_entered = true
					continue
				if endgame == "endless":
					if not sim.enable_endless():
						reason = "Endless entry refused"
						break
					endgame_entered = true
			if sim.stage >= limit or (sim.stage == 4 and not endgame_entered):
				var finished: bool = sim.claim_endless() if sim.endless_enabled else sim.advance_stage()
				if not finished:
					reason = "finish refused"
					break
				status = "won" if sim.won else "dead"
				reason = ""
				break
			if not sim.begin_intermission():
				reason = "intermission refused"
				break
			if sim.intermission_step == "prototype":
				for offer in sim.prototype_offers: _audit_increment(counts.prototype_offers, str(offer))
				var idx := _choose_prototype(sim, "focused" if style in ["focused_alt", "engine"] else style)
				var picked: String = str(sim.prototype_offers[idx])
				if not sim.choose_prototype(idx):
					reason = "prototype refused"
					break
				_audit_increment(counts.prototype_picks, picked)
			var choice := route
			if choice == "adaptive":
				choice = "overclock" if sim.hull >= sim.max_hull * 0.72 else "repair"
			if not sim.choose_route(choice) or not sim.advance_stage():
				reason = "route refused"
				break
			continue
		if not sim.pending_build_choices.is_empty():
			if not _audit_choices(sim, style, counts):
				reason = "build choice refused"
				break
			continue
		if not sim.cards.is_empty():
			if not _audit_draft(sim, style, bool(config.get("tools", false)), counts):
				reason = "draft refused"
				break
			continue
		# The finish, Endless and Archive branches all pursue the same
		# two legitimate signals before W4, so pre-branch play is paired.
		if not endgame.is_empty() and sim.signal_status == "offer":
			if not sim.choose_signal("cast"):
				reason = "signal refused"
				break
		if sim.signal_cast_window() or (sim.secret_entered and not sim.archive_attack.is_empty()):
			for ability in sim.active_slots:
				if sim.activate(str(ability)): break
		_cast(sim, "timed")
		if sim.ended or sim.stage_transition_queued or not sim.cards.is_empty(): continue
		var before: int = sim.tick
		sim.step()
		if sim.tick == before and not sim.ended and not sim.stage_transition_queued and sim.cards.is_empty() and not sim.secret_intro_pending:
			reason = "combat clock stalled"
			break
		if sim.time - sim.stage_start > AUDIT_STAGE_SECONDS and not sim.ended and not sim.stage_transition_queued:
			status = "timeout"
			reason = "900-second diagnostic cap, not an in-game defeat"
			break
	if stages.is_empty() or int(stages[-1].stage) != sim.stage: stages.append(_audit_snapshot(sim, status))
	var settlement := {}
	if sim.ended and status in ["won", "dead"]:
		var profile := {"cores":0,"hangar":hangar,"ships_owned":["vanguard"],"pilots_owned":["rookie"],"last_paid_run":-1}
		Progress.prepare(profile)
		var result := Progress.settle(profile, sim)
		var repeated := Progress.settle(profile, sim)
		settlement = {"earned":result.earned,"awards":result.awarded,"victories":profile.achievement_stats.victories,"hard_wins":profile.achievement_stats.hard_wins,"insane_wins":profile.achievement_stats.insane_wins,"archive_cleared":profile.achievement_stats.archive_cleared,"max_world_clears":profile.achievement_stats.max_world_clears,"finished_runs":profile.achievement_stats.finished_runs}
		if int(result.earned) != sim.payout() or int(profile.cores) != int(result.earned) or int(repeated.earned) != 0 or int(profile.achievement_stats.finished_runs) != 1:
			status = "fault"
			reason = "production settlement or duplicate payment mismatch"
	return {"seed":seed,"ship":ship,"difficulty":difficulty,"style":style,"route_policy":route,"portfolio":portfolio,"share":share,"hangar_cost":Catalog.refund(hangar),"hangar":hangar,"endgame":endgame,"status":status,"reason":reason,"won":sim.won,"clears":sim.stage_clears,"seconds":sim.time,"cores_if_claimed":sim.payout(),"settlement":settlement,"entry_cores":entry_cores,"archive_eligible":archive_eligible,"endgame_entered":endgame_entered,"counts":counts,"stages":stages}
