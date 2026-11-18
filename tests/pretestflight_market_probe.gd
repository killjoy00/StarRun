extends SceneTree
## Pre-TestFlight observational probe. Real combat, normal draft offers, no
## injected enemies, forced victories, mutation grants or test-only merchant calls.
## Compare seeded flights that ignore the merchant vs take one affordable pact
## or mutation. This is an automated bot proxy, not a human player win rate.
const Sim = preload("res://scripts/simulation.gd")
const MAX_FRAMES := 60 * 540 * 3

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var ship := "vanguard"
	var seeds := 6
	var offset := 71
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ship="): ship = arg.get_slice("=", 1)
		elif arg.begins_with("--seeds="): seeds = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--seed-offset="): offset = int(arg.get_slice("=", 1))
	var faults := 0
	var daily := Sim.new(8111)
	daily.daily_day = "2026-11-17"
	if daily.enable_merchant():
		push_error("Merchant must never be enabled for Daily")
		faults += 1
	for i in range(seeds):
		var seed: int = 810000 + (offset + i + 1) * 7919
		for policy in ["decline", "reactor", "mutation"]:
			var result: Dictionary = _trial(seed, ship, policy)
			print("MARKET_PROBE ", JSON.stringify(result))
			if bool(result.fault):
				faults += 1
	print("MARKET_PROBE_SUMMARY ", JSON.stringify({"ship":ship,"seeds":seeds,"policies":3,"faults":faults,"method":"natural campaign flight, deterministic offers; optional merchant UI choices made by bot"}))
	quit(1 if faults > 0 else 0)

func _trial(seed: int, ship: String, policy: String) -> Dictionary:
	# Mid-tier Hangar approximates a player who has earned upgrades; never
	# replace natural card choices or grant mutations via private APIs.
	var hangar := {"hull":3, "shield":3, "regen":2, "damage":2, "fire_rate":2, "repair":1, "lance_start":1}
	var sim := Sim.new(seed, hangar, ship, "rookie", "normal")
	var fault := not sim.enable_merchant()
	var observed_visits := 0
	var observed_stages: Array = []
	var accepted_ids: Array = []
	var pending_trade := ""
	var last_level := 1
	var timeout := false
	for _frame in range(MAX_FRAMES):
		if fault or sim.ended:
			break
		if not sim.merchant_state.is_empty():
			if sim.merchant_state == "signal":
				observed_visits += 1
				observed_stages.append(sim.stage)
				if policy == "decline":
					if not sim.merchant_leave(): fault = true
					continue
				if not sim.merchant_hail():
					fault = true
					break
			if sim.merchant_state == "shop":
				pending_trade = ""
				if policy == "reactor" and sim.merchant_can_afford("pact"):
					pending_trade = "pact"
				elif policy == "mutation":
					for offer in sim.merchant_offers:
						var id: String = str(offer.id)
						if id.begins_with("mutation:") and sim.merchant_can_afford(id):
							pending_trade = id
							break
				if pending_trade.is_empty():
					if not sim.merchant_leave(): fault = true
					continue
				if not sim.merchant_preview(pending_trade):
					fault = true
					break
			if sim.merchant_state == "confirm":
				if not sim.merchant_accept():
					fault = true
					break
				accepted_ids.append(pending_trade)
				if sim.merchant_trade_count != accepted_ids.size() or sim.merchant_state != "receipt" or not sim.merchant_acknowledge_receipt():
					fault = true
					break
			continue
		if sim.stage_transition_queued:
			if sim.stage >= 3:
				break
			if not sim.begin_intermission():
				fault = true
				break
			if sim.intermission_step == "prototype" and not sim.choose_prototype(0):
				fault = true
				break
			if not sim.choose_route("repair") or not sim.advance_stage():
				fault = true
				break
			continue
		if not sim.cards.is_empty():
			if not _pick_upgrade(sim):
				fault = true
				break
			continue
		_cast(sim)
		sim.step()
		last_level = sim.level
		if sim.time - sim.stage_start > 540.0:
			timeout = true
			break
	var harm := 0.0
	for amount in sim.damage_taken.values():
		harm += float(amount)
	return {"ship":ship,"seed":seed,"policy":policy,
		"reached_world2":sim.stage >= 2,"reached_world3":sim.stage >= 3,
		"worlds_cleared":sim.stage_clears,"died":sim.ended and not sim.won,
		"timeout":timeout,"fault":fault,"visits":observed_visits,
		"visit_stages":observed_stages,"trades":sim.merchant_trade_count,
		"trade_ids":accepted_ids,"hull":snappedf(sim.hull,0.1),
		"damage_taken":snappedf(harm,0.1),"level":last_level}

func _pick_upgrade(sim: RefCounted) -> bool:
	var order := ["seeker","pulse","arc","lance","regen","hull",
		"armor","munitions","autoloader","coolant","shield","targeting",
		"repair_bots","harvester","amplifier","nova","aegis","barrage",
		"overdrive","chrono","mend","repair"]
	var best := 0
	var rank := 999
	for i in range(sim.cards.size()):
		var card: Dictionary = sim.cards[i]
		var id: String = str(card.id)
		var value: int = order.find(id)
		if value < 0: value = 90
		if str(card.tag) == "ABILITY" and int(sim.upgrades.get(id,0)) == 0 and sim.active_slots.size() < 4:
			value = 0 if id in ["nova","emp","flak","capacitor"] else 7
		if sim.hull < sim.max_hull * 0.35 and id in ["hull","repair"]:
			value = -1
		if value < rank:
			rank = value
			best = i
	return sim.choose_card(best)

func _cast(sim: RefCounted) -> void:
	var imminent: bool = sim.charges.any(func(c): return float(c.remaining) < 0.5)
	if imminent:
		if not sim.activate("aegis"): sim.activate("nova")
	elif sim.enemies.size() >= 4:
		sim.activate("nova")
	if sim.enemies.size() >= 3 or sim.boss_spawned:
		sim.activate("barrage")
		sim.activate("overdrive")
	if sim.hull < sim.max_hull - 28:
		sim.activate("mend")
	if sim.shield < sim.max_shield - 25:
		sim.activate("capacitor")
	if sim.bullets.size() >= 10:
		sim.activate("flak")
		sim.activate("chrono")
