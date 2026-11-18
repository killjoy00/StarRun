extends SceneTree
## A real 30-second bot flight, not an injected enemy or forced win.
## Copy this one observer/controller to BOTH baseline and candidate revisions.
const Sim = preload("res://scripts/simulation.gd")
const PHASES := ["0–8 scouts", "8–12 warning", "12–18 wing", "18–21 break", "21–30 push"]

func _initialize() -> void:
	call_deferred("_run")

func _phase(t: float) -> String:
	if t < 8.0: return PHASES[0]
	if t < 12.0: return PHASES[1]
	if t < 18.0: return PHASES[2]
	if t < 21.0: return PHASES[3]
	return PHASES[4]

func _run() -> void:
	var ship := "vanguard"
	var difficulty := "normal"
	var seed_offset := 21
	var seeds := 4
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ship="): ship = arg.get_slice("=",1)
		if arg.begins_with("--difficulty="): difficulty = arg.get_slice("=",1)
		if arg.begins_with("--seeds="): seeds = int(arg.get_slice("=",1))
		if arg.begins_with("--seed-offset="): seed_offset = int(arg.get_slice("=",1))
	for i in range(seeds):
		var seed: int = 810000 + (seed_offset + i + 1) * 7919
		var sim := Sim.new(seed, {}, ship, "rookie", difficulty)
		var windows: Dictionary = {}
		for phase in PHASES:
			windows[phase] = {"samples":0,"enemy_sum":0,"empty":0,"crowded":0,"bullet_sum":0,"max_enemies":0}
		var first_three := -1.0
		var first_bullet := -1.0
		var fault := false
		for frame in range(2050):
			if sim.ended or sim.time >= 30.0:
				break
			if not sim.cards.is_empty():
				if not _draft(sim):
					fault = true
					break
				continue
			_cast(sim)
			sim.step()
			if sim.tick % 12 != 0:
				continue
			var t: float = sim.time - sim.stage_start
			if t >= 30.0:
				break
			var name := _phase(t)
			var visible := 0
			for enemy in sim.enemies:
				var p: Vector2 = enemy.p
				if float(enemy.hp) > 0.0 and p.x >= 0.0 and p.x <= Sim.WIDTH and p.y >= 0.0 and p.y <= 920.0:
					visible += 1
			var bullets := 0
			for bullet in sim.bullets:
				var p: Vector2 = bullet.p
				if p.x >= 0.0 and p.x <= Sim.WIDTH and p.y >= 0.0 and p.y <= Sim.HEIGHT:
					bullets += 1
			if visible >= 3 and first_three < 0.0: first_three = t
			if bullets > 0 and first_bullet < 0.0: first_bullet = t
			var row: Dictionary = windows[name]
			row.samples += 1
			row.enemy_sum += visible
			row.empty += int(visible == 0)
			row.crowded += int(visible >= 3)
			row.bullet_sum += bullets
			row.max_enemies = maxi(int(row.max_enemies),visible)
		var phase_rows := {}
		for name in PHASES:
			var row: Dictionary = windows[name]
			var n: float = maxf(1.0,float(row.samples))
			phase_rows[name] = {"samples":row.samples,
				"mean_enemies":snappedf(float(row.enemy_sum)/n,0.01),
				"empty_pct":snappedf(100.0*float(row.empty)/n,0.1),
				"crowded_pct":snappedf(100.0*float(row.crowded)/n,0.1),
				"mean_bullets":snappedf(float(row.bullet_sum)/n,0.01),
				"peak_enemies":row.max_enemies}
		var harm := 0.0
		for amount in sim.damage_taken.values():
			harm += float(amount)
		print("OPENING_PLAYTEST ",JSON.stringify({
			"seed":seed,"ship":ship,"difficulty":difficulty,"hangar":"empty",
			"first_three":snappedf(first_three,0.1),"first_bullet":snappedf(first_bullet,0.1),
			"level":sim.level,"kills":sim.kills,"hull":snappedf(sim.hull,0.1),
			"shield":snappedf(sim.shield,0.1),"damage_taken":snappedf(harm,0.1),
			"died":sim.ended,"elapsed":snappedf(sim.time,0.1),"fault":fault,
			"phases":phase_rows
		}))
	quit()

func _draft(sim: RefCounted) -> bool:
	var favorites := ["seeker","pulse","arc","lance","regen","hull","armor","munitions","autoloader","coolant","shield","targeting","repair_bots","amplifier","nova","aegis","barrage","overdrive","chrono","mend","repair"]
	var best := 0
	var priority := 999
	for i in range(sim.cards.size()):
		var card: Dictionary = sim.cards[i]
		var rank: int = favorites.find(str(card.id))
		if rank < 0: rank = 90
		if sim.hull < sim.max_hull*0.35 and str(card.id) in ["hull","repair"]:
			rank = -1
		if rank < priority:
			best = i
			priority = rank
	return sim.choose_card(best)

func _cast(sim: RefCounted) -> void:
	var imminent: bool = sim.charges.any(func(c): return float(c.remaining) <= 0.6)
	if imminent:
		sim.activate("aegis")
		sim.activate("nova")
	if sim.enemies.size() >= 3:
		sim.activate("nova")
		sim.activate("barrage")
		sim.activate("overdrive")
	if sim.hull < sim.max_hull-30:
		sim.activate("mend")
	if sim.bullets.size() >= 12:
		sim.activate("flak")
