extends SceneTree
## Matched-seed, controlled mutation balance experiment. Each seed reaches
## World 2 through actual World 1 combat and offered drafts. All four weapons
## are unlocked through a deliberately strong HANGAR fixture (not free cards).
## At the World 2 checkpoint, restore the identical state for baseline + eight
## counterfactual mutations, charging their actual permanent-flight costs.
## Not an estimate of natural mutation offer rates or human win rates.
const Sim = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/catalog.gd")
const MAX_STAGE_FRAMES := 60 * 540

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var ship := "vanguard"
	var seeds := 4
	var offset := 91
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ship="): ship = arg.get_slice("=", 1)
		elif arg.begins_with("--seeds="): seeds = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--seed-offset="): offset = int(arg.get_slice("=", 1))
	var faults := 0
	var usable := 0
	for i in range(seeds):
		var seed: int = 810000 + (offset + i + 1) * 7919
		var prepared: Dictionary = _prepare_world2(seed, ship)
		if prepared.is_empty():
			print("MUTATION_SKIP ", JSON.stringify({"ship":ship,"seed":seed,"reason":"failed to enter World 2 naturally"}))
			continue
		usable += 1
		var baseline: Dictionary = _test_world2(prepared, ship, seed, "")
		print("MUTATION_PROBE ", JSON.stringify(baseline))
		faults += int(baseline.fault)
		for spec in Catalog.MUTATIONS:
			var item: Dictionary = _test_world2(prepared, ship, seed, str(spec.id))
			item["baseline_kills"] = baseline.kills
			item["baseline_damage"] = baseline.damage_taken
			item["baseline_clear"] = baseline.cleared_world2
			print("MUTATION_PROBE ", JSON.stringify(item))
			faults += int(item.fault)
	print("MUTATION_PROBE_SUMMARY ", JSON.stringify({"ship":ship,"seeds":seeds,"usable":usable,"faults":faults,"method":"real World 1 to matching World 2 snapshot; 4 paid-for Hangar starting weapons; one mutation and its true capacity cost"}))
	quit(1 if faults > 0 or usable == 0 else 0)

func _prepare_world2(seed: int, ship: String) -> Dictionary:
	var hangar := {"hull":3,"shield":3,"regen":2,"damage":2,
		"pulse_start":1,"seeker_start":1,"arc_start":1,"lance_start":1}
	var sim := Sim.new(seed, hangar, ship, "rookie", "normal")
	for _frame in range(MAX_STAGE_FRAMES):
		if sim.ended:
			return {}
		if sim.stage_transition_queued:
			if sim.stage != 1 or not sim.begin_intermission():
				return {}
			if sim.intermission_step == "prototype" and not sim.choose_prototype(0):
				return {}
			if not sim.choose_route("repair") or not sim.advance_stage():
				return {}
			if not sim.mutations.is_empty():
				return {}
			return sim.snapshot()
		if not sim.cards.is_empty():
			if not _pick_upgrade(sim): return {}
			continue
		_cast(sim)
		sim.step()
		if sim.time - sim.stage_start > 540.0:
			return {}
	return {}

func _test_world2(checkpoint: Dictionary, ship: String, seed: int, mutation_id: String) -> Dictionary:
	var sim := Sim.new()
	# Each restore must own its arrays; otherwise the previous mutation leaks into the next case.
	var fault := not sim.restore(checkpoint.duplicate(true))
	var name := mutation_id if not mutation_id.is_empty() else "unmutated"
	if fault:
		return {"ship":ship,"seed":seed,"mutation":name,"fault":true,"kills":0,"damage_taken":0,"cleared_world2":false}
	if not mutation_id.is_empty():
		fault = not sim._install_mutation(mutation_id)
		if not fault:
			sim._apply_mutation_cost(mutation_id)
	var started := sim.time
	var kills_before: int = sim.kills
	var damage_before := _damage(sim)
	var timeout := false
	if not fault:
		for _frame in range(MAX_STAGE_FRAMES):
			if sim.ended or sim.stage_transition_queued: break
			if not sim.cards.is_empty():
				if not _pick_upgrade(sim):
					fault = true
					break
				continue
			_cast(sim)
			sim.step()
			if sim.time - sim.stage_start > 540.0:
				timeout = true
				break
	return {"ship":ship,"seed":seed,"mutation":name,"fault":fault,
		"cleared_world2":sim.stage_clears >= 2,"died":sim.ended and not sim.won,
		"timeout":timeout,"elapsed":snappedf(sim.time-started,0.1),
		"kills":sim.kills-kills_before,"damage_taken":snappedf(_damage(sim)-damage_before,0.1),
		"hull_fraction":snappedf(sim.hull/maxf(sim.max_hull,1.0),0.001),
		"shield_fraction":snappedf(sim.shield/maxf(sim.max_shield,1.0),0.001),
		"max_hull":snappedf(sim.max_hull,0.1),"max_shield":snappedf(sim.max_shield,0.1)}

func _damage(sim: RefCounted) -> float:
	var total := 0.0
	for amount in sim.damage_taken.values():
		total += float(amount)
	return total

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
	elif sim._crowd_count() >= 4:
		sim.activate("nova")
	if sim._crowd_count() >= 3 or sim.boss_spawned:
		sim.activate("barrage")
		sim.activate("overdrive")
	if sim.hull < sim.max_hull - 28:
		sim.activate("mend")
	if sim.shield < sim.max_shield - 25:
		sim.activate("capacitor")
	if sim.bullets.size() >= 10:
		sim.activate("flak")
		sim.activate("chrono")
