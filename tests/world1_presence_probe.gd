extends SceneTree
# Both the previous and candidate revisions run this exact same no-Hangar
# controller. It buys only offered cards; no scripted kills, enemy injection,
# pre-installed weapons, or forced boss clears.
const Sim = preload("res://scripts/simulation.gd")
const WINDOW = {"early":45.0, "middle":120.0, "late":240.0}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var ship := "vanguard"
	var difficulty := "normal"
	var offset := 21
	var seeds := 3
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ship="): ship = arg.get_slice("=",1)
		if arg.begins_with("--difficulty="): difficulty = arg.get_slice("=",1)
		if arg.begins_with("--seed-offset="): offset = int(arg.get_slice("=",1))
		if arg.begins_with("--seeds="): seeds = int(arg.get_slice("=",1))
	for seed_index in range(seeds):
		var seed: int = 810000 + (offset + seed_index + 1) * 7919
		var sim = Sim.new(seed, {}, ship, "rookie", difficulty)
		var windows := {}
		for name in WINDOW:
			windows[name] = {"samples":0,"enemies":0,"empty":0,"crowded":0,"bullets":0,"max_enemies":0}
		var first_three := -1.0
		var first_enemy := -1.0
		var fault := false
		for frame in range(60 * 540):
			if sim.ended or sim.stage_transition_queued:
				break
			if not sim.cards.is_empty():
				if not _pick_upgrade(sim):
					fault = true
					break
				continue
			if sim.tick % 12 == 0 and not sim.boss_spawned:
				var elapsed: float = sim.time - sim.stage_start
				var window := "early" if elapsed < 45.0 else ("middle" if elapsed < 120.0 else "late")
				var visible := 0
				for enemy in sim.enemies:
					var p: Vector2 = enemy.p
					if enemy.hp > 0.0 and p.x >= 0.0 and p.x <= Sim.WIDTH and p.y >= 0.0 and p.y <= 920.0:
						visible += 1
				var shots_visible := 0
				for bullet in sim.bullets:
					var p: Vector2 = bullet.p
					if p.x >= 0.0 and p.x <= Sim.WIDTH and p.y >= 0.0 and p.y <= Sim.HEIGHT:
						shots_visible += 1
				if visible > 0 and first_enemy < 0.0: first_enemy = elapsed
				if visible >= 3 and first_three < 0.0: first_three = elapsed
				var record: Dictionary = windows[window]
				record.samples += 1
				record.enemies += visible
				record.empty += int(visible == 0)
				record.crowded += int(visible >= 3)
				record.bullets += shots_visible
				record.max_enemies = maxi(int(record.max_enemies), visible)
			_cast(sim)
			sim.step()
		var output := {"seed":seed, "ship":ship, "difficulty":difficulty, "hangar":"none",
			"won_world1":bool(sim.stage_clears >= 1), "died":bool(sim.ended and not sim.won),
			"elapsed":snappedf(sim.time, 0.1), "level":int(sim.level),
			"kills":int(sim.kills), "hull":snappedf(sim.hull, 0.1),
			"first_enemy":snappedf(first_enemy, 0.1),
			"first_three":snappedf(first_three, 0.1),
			"fault":fault}
		var total_damage := 0.0
		for amount in sim.damage_taken.values():
			total_damage += float(amount)
		output["damage_taken"] = snappedf(total_damage, 0.1)
		for name in windows:
			var record: Dictionary = windows[name]
			var n: float = maxf(1.0, float(record.samples))
			output[name] = {"samples":record.samples, "mean_enemies":snappedf(float(record.enemies)/n,0.01),
				"empty_pct":snappedf(100.0*float(record.empty)/n,0.1),
				"crowded_pct":snappedf(100.0*float(record.crowded)/n,0.1),
				"mean_bullets":snappedf(float(record.bullets)/n,0.01),
				"peak_enemies":record.max_enemies}
		print("WORLD1_PROBE ",JSON.stringify(output))
	quit()

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
		if card.tag == "ABILITY" and int(sim.upgrades.get(id,0)) == 0 and sim.active_slots.size() < 4:
			value = 0 if id in ["nova","emp","flak","capacitor"] else 7
		if sim.hull < sim.max_hull * 0.35 and id in ["hull","repair"]:
			value = -1
		if value < rank:
			rank = value
			best = i
	return sim.choose_card(best)

func _cast(sim: RefCounted) -> void:
	var imminent := sim.charges.any(func(c): return float(c.remaining) < 0.5)
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
