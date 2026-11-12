extends RefCounted
## Fixed-step simulation: no rendering, platform services, wall clock, or input polling.
const DT := 1.0 / 60.0
const WIDTH := 540.0
const HEIGHT := 960.0
const SAVE_VERSION := 1
const Catalog = preload("res://scripts/catalog.gd")
var content: Dictionary
var rng := RandomNumberGenerator.new()
var seed_value := 1
# A separate seeded course never consumes the combat/draft random stream.
var course: Array[Dictionary] = []
var movement_version := 3
var tick := 0
var time := 0.0
var hull := 100.0
var max_hull := 100.0
var shield := 50.0
var max_shield := 50.0
var shield_offline := 0.0
var aegis_left := 0.0
var cooldowns := {"aegis": 0.0, "nova": 0.0, "barrage": 0.0, "overdrive": 0.0, "chrono": 0.0, "mend": 0.0}
var upgrades := {"pulse": 1, "seeker": 1, "armor": 0, "regen": 0, "hull": 0, "coolant": 0, "aegis": 1, "nova": 1}
var overdrive_left := 0.0
var chrono_left := 0.0
var mend_left := 0.0
var mend_rate := 0.0
var emergency_used := false
var arc_timer := 0.0
var lance_timer := 0.0
var rerolls_left := 0
var banishes_left := 0
var skips_left := 0
var banished: Array = []
var enemies: Array = []
var bullets: Array = []
var shots: Array = []
var effects: Array = []
var charges: Array = []
var events: Array = []
var damage_taken := {"chaff": 0.0, "heavy": 0.0, "ordnance": 0.0, "hazard": 0.0}
var damage_dealt := {"pulse": 0.0, "seeker": 0.0, "nova": 0.0, "barrage": 0.0, "arc": 0.0, "lance": 0.0}
var xp := 0.0
var level := 1
var kills := 0
var cards: Array = []
var pending_levels := 0
var ended := false
var won := false
var next_spawn := 1.0
var pulse_timer := 0.0
var seeker_timer := 0.0
var heavy_ready_at := 10.0
var boss_spawned := false
var next_id := 1
var ability_uses := 0
var prevented := 0.0
var beams_fired := 0
var beams_cancelled := 0
var meta := Catalog.defaults()

func _init(run_seed: int = 1, hangar: Dictionary = {}) -> void:
	content = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
	for card in content.cards:
		if not upgrades.has(card.id):
			upgrades[card.id] = 0
	seed_value = run_seed
	rng.seed = run_seed
	_build_course()
	for key in meta:
		meta[key] = int(hangar.get(key, 0))
	max_hull += meta.hull * 10.0
	hull = max_hull
	max_shield += meta.shield * 8.0
	shield = max_shield
	upgrades.pulse += meta.pulse_start
	upgrades.seeker += meta.seeker_start
	rerolls_left = meta.rerolls
	banishes_left = meta.banishes
	skips_left = meta.skips

func _build_course() -> void:
	var pilot := RandomNumberGenerator.new()
	pilot.seed = seed_value ^ 0x53746172
	course.clear()
	course.append({"t": -6.0, "p": Vector2(270, 790)})
	course.append({"t": 0.0, "p": Vector2(270, 790)})
	var arrival := 0.0
	var previous := Vector2(270, 790)
	while arrival < 420.0:
		arrival += pilot.randf_range(2.2, 4.0) if movement_version >= 3 else pilot.randf_range(3.8, 7.5)
		var target := previous + Vector2(pilot.randf_range(-220, 220), pilot.randf_range(-72, 72)) if movement_version >= 3 else previous + Vector2(pilot.randf_range(-115, 115), pilot.randf_range(-20, 20))
		if pilot.randf() < (0.10 if movement_version >= 3 else 0.24):
			target = previous + Vector2(pilot.randf_range(-18, 18), pilot.randf_range(-8, 8))
		target.x = clampf(target.x, 100 if movement_version >= 3 else 125, 440 if movement_version >= 3 else 415)
		target.y = clampf(target.y, 665 if movement_version >= 3 else 755, 815 if movement_version >= 3 else 810)
		course.append({"t": arrival, "p": target})
		previous = target

func ship_position(at: float = -1.0) -> Vector2:
	if at < 0.0:
		at = time
	# Keep an old suspended flight's original trajectory; all new flights use the new pilot.
	if movement_version == 1:
		return Vector2(WIDTH * 0.5 + sin(at * TAU / 6.0) * WIDTH * 0.30, 790.0)
	var index := 1
	while index < course.size() - 2 and at > float(course[index + 1].t):
		index += 1
	var current: Dictionary = course[index]
	var next: Dictionary = course[index + 1]
	var duration: float = next.t - current.t
	var weight := clampf((at - current.t) / duration, 0, 1)
	var start: Vector2 = current.p
	var end: Vector2 = next.p
	var p0: Vector2 = course[index - 1].p
	var p3: Vector2 = course[mini(index + 2, course.size() - 1)].p
	var velocity0: Vector2 = (end - p0) / float(next.t - course[index - 1].t)
	var velocity1: Vector2 = (p3 - start) / float(course[mini(index + 2, course.size() - 1)].t - current.t)
	# Time-aware cubic Hermite interpolation keeps turns and banking continuous.
	var u := weight
	return (2*u*u*u - 3*u*u + 1) * start + (u*u*u - 2*u*u + u) * velocity0 * duration + (-2*u*u*u + 3*u*u) * end + (u*u*u - u*u) * velocity1 * duration

func ship_velocity(at: float = -1.0) -> Vector2:
	if at < 0.0:
		at = time
	return (ship_position(at + 0.025) - ship_position(maxf(0, at - 0.025))) / 0.05

func step() -> void:
	if ended or not cards.is_empty():
		return
	tick += 1
	time = tick * DT
	for key in cooldowns:
		cooldowns[key] = maxf(0.0, cooldowns[key] - DT)
	aegis_left = maxf(0.0, aegis_left - DT)
	overdrive_left = maxf(0.0, overdrive_left - DT)
	chrono_left = maxf(0.0, chrono_left - DT)
	if mend_left > 0.0:
		hull = minf(max_hull, hull + mend_rate * minf(DT, mend_left))
		mend_left = maxf(0.0, mend_left - DT)
	hull = minf(max_hull, hull + (upgrades.repair_bots * 0.15 + meta.repair * 0.15) * DT)
	if shield_offline > 0.0:
		shield_offline = maxf(0.0, shield_offline - DT)
	else:
		shield = minf(max_shield, shield + (1.5 + upgrades.regen * 0.35 + meta.regen * 0.25) * DT)
	for effect in effects:
		effect.life -= DT
	effects = effects.filter(func(e): return e.life > 0.0)
	if not boss_spawned and time >= float(content.boss_at):
		_spawn_boss()
	if time >= next_spawn and not boss_spawned:
		_spawn_enemy()
		next_spawn = time + maxf(0.72, 1.65 - time / 260.0)
	_update_enemies()
	_update_charges()
	_update_weapons()
	_update_bullets()
	_update_shots()
	if pending_levels > 0 and not ended:
		_offer_cards()

func _spawn_enemy() -> void:
	if enemies.size() >= 18:
		return
	var kind := "drone"
	var roll := rng.randf()
	if time > 30.0 and roll < 0.30:
		kind = "gunship"
	elif time > 55.0 and roll > 0.77:
		kind = "sniper"
	var spec: Dictionary = content.enemies[kind]
	var scaling := 1.0 + time / 280.0
	enemies.append({"id": next_id, "kind": kind, "p": Vector2(rng.randf_range(55, 485), -35), "hp": float(spec.hp) * scaling, "max_hp": float(spec.hp) * scaling, "speed": float(spec.speed), "fire": rng.randf_range(1, 3), "xp": int(spec.xp), "phase": rng.randf_range(0, TAU)})
	next_id += 1

func _spawn_boss() -> void:
	boss_spawned = true
	enemies.clear()
	bullets.clear()
	charges.clear()
	shield = max_shield
	hull = minf(max_hull, hull + 15)
	heavy_ready_at = time + 3.0
	enemies.append({"id": next_id, "kind": "boss", "p": Vector2(270, 135), "hp": 6200.0, "max_hp": 6200.0, "speed": 0.0, "fire": 1.0, "xp": 0, "phase": 0.0})
	next_id += 1
	_log("Harvester arrived · shield refilled, +15 hull")

func _update_enemies() -> void:
	var pace := 0.45 if chrono_left > 0 else 1.0
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		if enemy.kind == "boss":
			enemy.p.x = 270.0 + sin(time * 0.7) * 105.0
		else:
			enemy.p.y += enemy.speed * DT * pace
			enemy.p.x += sin(time * 1.8 + enemy.phase) * 12.0 * DT * pace
		enemy.fire -= DT * pace
		if enemy.kind in ["sniper", "boss"] and time >= heavy_ready_at and charges.is_empty():
			var lead := 1.8
			charges.append({"source": enemy.id, "x": ship_position(time + lead).x, "remaining": lead, "duration": lead, "damage": 35.0 if enemy.kind == "boss" else 28.0})
			heavy_ready_at = time + (7.5 if enemy.kind == "boss" else 10.0)
			_log("Heavy beam charging")
		if enemy.fire <= 0.0:
			enemy.fire = 2.1 if enemy.kind == "boss" else float(content.enemies[enemy.kind].interval)
			var flight_time: float = enemy.p.distance_to(ship_position()) / 215.0
			flight_time = enemy.p.distance_to(ship_position(time + flight_time)) / 215.0
			var direction: Vector2 = (ship_position(time + flight_time) - enemy.p).normalized()
			var count := 9 if enemy.kind == "boss" else (5 if enemy.kind == "gunship" else 3)
			for i in range(count):
				var angle := (i - (count - 1) / 2.0) * 0.15
				bullets.append({"p": enemy.p, "v": direction.rotated(angle) * 215.0, "damage": 2.1 if enemy.kind == "boss" else 1.6, "kind": "chaff", "source": enemy.kind})
			if enemy.kind == "gunship":
				bullets.append({"p": enemy.p, "v": direction * 140.0, "damage": 12.0, "kind": "ordnance", "hp": 12.0, "source": "gunship"})
		if enemy.p.y > 880:
			enemy.hp = -1.0
			_hit(5.0, "hazard", "Escaped " + enemy.kind)
	enemies = enemies.filter(func(e): return e.hp > 0.0)

func _update_charges() -> void:
	for charge in charges:
		charge.remaining -= DT
		if charge.remaining <= 0.0:
			beams_fired += 1
			effects.append({"kind": "beam", "p": Vector2(charge.x, 0), "life": 0.32, "max_life": 0.32, "born": tick})
			if absf(ship_position().x - charge.x) < 33:
				if aegis_left > 0.0 and upgrades.aegis >= 5:
					for enemy in enemies:
						if enemy.id == charge.source:
							_damage_enemy(enemy, 60.0, "nova")
							_log("Aegis reflected the heavy beam")
				_hit(charge.damage, "heavy", "Harvester" if boss_spawned else "Sniper")
	charges = charges.filter(func(c): return c.remaining > 0.0)

func _update_weapons() -> void:
	var rate: float = 1.0 + upgrades.autoloader * 0.08 + meta.fire_rate * 0.05 + (0.75 if overdrive_left > 0 else 0.0)
	pulse_timer -= DT * rate
	seeker_timer -= DT * rate
	arc_timer -= DT * rate
	lance_timer -= DT * rate
	var bank := clampf(ship_velocity().x * 0.004, -0.32, 0.32)
	var origin := ship_position() + Vector2(0, -34).rotated(bank)
	if pulse_timer <= 0.0:
		pulse_timer += 0.19
		var barrels := 2 if upgrades.pulse >= 5 else 1
		for n in range(barrels):
			shots.append({"p": origin + Vector2((n * 2 - barrels + 1) * 8, 0), "v": Vector2(0, -980).rotated(bank), "damage": (7.0 + (upgrades.pulse - 1) * 1.68) * weapon_power(), "weapon": "pulse", "target": -1})
	if seeker_timer <= 0.0:
		seeker_timer += 0.70
		# Priority is readable and build-controlled: charging source, missile, nearest enemy.
		var target_id := -1
		var target_pos := Vector2(270, -100)
		if not charges.is_empty():
			target_id = charges[0].source
		for enemy in enemies:
			if enemy.id == target_id:
				target_pos = enemy.p
		if target_id < 0:
			for bullet in bullets:
				if bullet.kind == "ordnance":
					target_pos = bullet.p
					target_id = -2
					break
		if target_id == -1 and not enemies.is_empty():
			var distance := INF
			for enemy in enemies:
				var d: float = origin.distance_squared_to(enemy.p)
				if d < distance:
					distance = d
					target_id = enemy.id
					target_pos = enemy.p
		if target_id != -1:
			shots.append({"p": origin, "v": (target_pos - origin).normalized() * 650.0, "damage": (14.0 + (upgrades.seeker - 1) * 4.2) * weapon_power(), "weapon": "seeker", "target": target_id})
	if upgrades.arc > 0 and arc_timer <= 0.0 and not enemies.is_empty():
		arc_timer = 1.7
		var visited: Array = []
		var start := origin
		for chain in range(2 + int(upgrades.arc) / 2):
			var target := _nearest(start, visited)
			if target.is_empty() or start.distance_to(target.p) > 640:
				break
			visited.append(target.id)
			effects.append({"kind":"arc", "p":start, "to":target.p, "life":0.22, "max_life":0.22, "born":tick})
			start = target.p
			_damage_enemy(target, (10 + upgrades.arc * 3) * weapon_power(), "arc")
	if upgrades.lance > 0 and lance_timer <= 0.0 and not enemies.is_empty():
		lance_timer = 2.4
		var target := _nearest(origin)
		for enemy in enemies:
			if not charges.is_empty() and enemy.id == charges[0].source:
				target = enemy
		if not target.is_empty():
			var end: Vector2 = origin + (target.p - origin).normalized() * 1200
			effects.append({"kind":"lance", "p":origin, "to":end, "life":0.28, "max_life":0.28, "born":tick})
			for enemy in enemies:
				var closest := Geometry2D.get_closest_point_to_segment(enemy.p, origin, end)
				if closest.distance_to(enemy.p) < (68 if enemy.kind == "boss" else 28):
					_damage_enemy(enemy, (22 + upgrades.lance * 7) * weapon_power(), "lance")

func weapon_power() -> float:
	return 1.0 + meta.damage * 0.08 + upgrades.munitions * 0.08

func ability_power() -> float:
	return 1.0 + meta.ability_power * 0.06 + upgrades.amplifier * 0.06

func _nearest(origin: Vector2, excluded: Array = []) -> Dictionary:
	var best: Dictionary = {}
	var distance := INF
	for enemy in enemies:
		if enemy.hp > 0 and enemy.id not in excluded:
			var d := origin.distance_squared_to(enemy.p)
			if d < distance:
				distance = d
				best = enemy
	return best

func _update_bullets() -> void:
	var ship := ship_position()
	for bullet in bullets:
		if bullet.kind == "ordnance":
			bullet.v = bullet.v.lerp((ship - bullet.p).normalized() * 155.0, DT * 0.75)
		bullet.p += bullet.v * DT * (0.45 if chrono_left > 0 else 1.0)
		if bullet.p.distance_squared_to(ship) < (16.0 if bullet.kind == "ordnance" else 10.0) ** 2:
			_hit(bullet.damage, bullet.kind, bullet.source)
			bullet.p.y = HEIGHT + 100
	bullets = bullets.filter(func(b): return b.p.y < HEIGHT + 35 and b.p.y > -100 and b.p.x > -60 and b.p.x < WIDTH + 60 and b.get("hp", 1) > 0)

func _update_shots() -> void:
	for shot in shots:
		if shot.weapon in ["seeker", "barrage"] and shot.target >= 0:
			var alive := enemies.any(func(e): return e.id == shot.target and e.hp > 0)
			if not alive:
				var replacement := _nearest(shot.p)
				shot.target = int(replacement.get("id", -1))
		if shot.weapon == "pulse":
			# Mild forward-only steering: no U-turns or seeker-style pursuit.
			var candidate: Dictionary = {}
			var score := INF
			for enemy in enemies:
				var offset: Vector2 = enemy.p - shot.p
				if enemy.hp <= 0 or offset.y >= -8 or absf(Vector2.UP.angle_to(offset)) > 0.58 + meta.guidance * 0.035:
					continue
				var candidate_score := absf(offset.x) + offset.length() * 0.10
				if candidate_score < score:
					score = candidate_score
					candidate = enemy
			if not candidate.is_empty():
				var desired: Vector2 = (candidate.p - shot.p).normalized()
				shot.v = shot.v.rotated(clampf(shot.v.angle_to(desired), -DT * (0.85 + meta.guidance * 0.12), DT * (0.85 + meta.guidance * 0.12)))
		if shot.weapon in ["seeker", "barrage"] and shot.target >= 0:
			for enemy in enemies:
				if enemy.id == shot.target:
					shot.v = shot.v.lerp((enemy.p - shot.p).normalized() * 650, DT * 8.0)
		if shot.weapon == "seeker" and shot.target == -2:
			for bullet in bullets:
				if bullet.kind == "ordnance":
					shot.v = shot.v.lerp((bullet.p - shot.p).normalized() * 650, DT * 8.0)
					break
		shot.p += shot.v * DT
		var struck := false
		if shot.weapon in ["seeker", "barrage"]:
			for bullet in bullets:
				if bullet.kind == "ordnance" and bullet.p.distance_squared_to(shot.p) < 28 ** 2:
					bullet.hp -= shot.damage
					struck = true
					break
		if not struck:
			for enemy in enemies:
				if enemy.hp <= 0.0:
					continue
				var radius := 68.0 if enemy.kind == "boss" else 25.0
				if shot.p.distance_squared_to(enemy.p) < radius * radius:
					_damage_enemy(enemy, shot.damage, shot.weapon)
					struck = true
					break
		if struck:
			shot.p.y = -200
	shots = shots.filter(func(s): return s.p.y > -100 and s.p.y < HEIGHT and s.p.x > -50 and s.p.x < WIDTH + 50)
	enemies = enemies.filter(func(e): return e.hp > 0.0)

func _damage_enemy(enemy: Dictionary, amount: float, weapon: String) -> void:
	if enemy.hp <= 0.0:
		return
	if upgrades.targeting > 0 and weapon in ["pulse", "seeker", "arc", "lance"] and rng.randf() < upgrades.targeting * 0.05:
		amount *= 2.0
	damage_dealt[weapon] += minf(amount, enemy.hp)
	enemy.hp -= amount
	effects.append({"kind": "impact", "p": enemy.p, "life": 0.16, "max_life": 0.16, "born": tick})
	if enemy.hp > 0:
		return
	kills += 1
	effects.append({"kind": "explosion", "p": enemy.p, "life": 0.72 if enemy.kind == "boss" else 0.5, "max_life": 0.72 if enemy.kind == "boss" else 0.5, "born": tick, "boss": enemy.kind == "boss"})
	var before := charges.size()
	charges = charges.filter(func(c): return c.source != enemy.id)
	beams_cancelled += before - charges.size()
	xp += enemy.xp * (1.0 + meta.xp * 0.06 + upgrades.harvester * 0.08)
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		pending_levels += 1
	if enemy.kind == "boss":
		ended = true
		won = true
		_log("Harvester destroyed")

func xp_needed() -> int:
	return 12 + (level - 1) * 4

func _hit(amount: float, kind: String, source: String) -> void:
	if ended:
		return
	if aegis_left > 0:
		prevented += amount
		effects.append({"kind": "shield-hit", "p": ship_position(), "life": 0.16, "max_life": 0.16, "born": tick})
		return
	var reduced := amount
	if kind == "chaff":
		reduced = maxf(amount * 0.25, amount - upgrades.armor * 0.35 - meta.armor * 0.12)
	var shield_damage := minf(shield, reduced)
	var had_shield := shield > 0.0
	shield -= shield_damage
	var hull_damage := reduced - shield_damage
	hull = maxf(0.0, hull - hull_damage)
	effects.append({"kind": "hull-hit" if hull_damage > 0 else "shield-hit", "p": ship_position(), "life": 0.22, "max_life": 0.22, "born": tick})
	damage_taken[kind] += reduced
	if had_shield and shield <= 0:
		shield_offline = 3.0
		_log("Shield broke · offline for 3 seconds")
	if kind != "chaff" or hull_damage > 0.0:
		_log("%s · %.1f %s damage%s" % [source, reduced, kind, " to hull" if hull_damage > 0 else " to shield"])
	if hull <= 0:
		ended = true
		var availability := PackedStringArray()
		for id in Catalog.ABILITIES:
			if upgrades[id] > 0:
				availability.append("%s %.1fs" % [content.abilities[id].name, cooldowns[id]])
		_log("Hull lost · " + " / ".join(availability))
	elif hull < max_hull * 0.35 and meta.emergency > 0 and not emergency_used:
		emergency_used = true
		aegis_left = maxf(aegis_left, 1.0 + meta.emergency * 0.5)
		_log("Emergency field deployed")

func activate(ability: String) -> bool:
	if ended or not cards.is_empty() or not cooldowns.has(ability) or int(upgrades.get(ability, 0)) <= 0 or cooldowns[ability] > 0.0:
		return false
	ability_uses += 1
	cooldowns[ability] = float(content.abilities[ability].cooldown) * maxf(0.4, 1.0 - upgrades.coolant * 0.08 - meta.ability_cooldown * 0.03)
	shield = minf(max_shield, shield + meta.reserve_shield * 5)
	_log(ability.capitalize() + " activated")
	if ability == "aegis":
		aegis_left = (1.8 + (upgrades.aegis - 1) * 0.25) * ability_power()
	elif ability == "nova":
		beams_cancelled += charges.size()
		charges.clear()
		prevented += bullets.reduce(func(total, b): return total + b.damage if b.p.distance_squared_to(ship_position()) < 160 * 160 else total, 0.0)
		bullets.clear()
		effects.append({"kind": "nova", "p": ship_position(), "life": 0.65, "max_life": 0.65, "born": tick})
		for enemy in enemies:
			_damage_enemy(enemy, 65.0 * (1 + (upgrades.nova - 1) * 0.25) * ability_power(), "nova")
		enemies = enemies.filter(func(e): return e.hp > 0.0)
	elif ability == "barrage":
		var targets := enemies.filter(func(e): return e.hp > 0)
		for i in range(7 + (int(upgrades.barrage) - 1) * 2):
			var target: Dictionary = targets[i % targets.size()] if not targets.is_empty() else {}
			shots.append({"p":ship_position() + Vector2(0, -30), "v":Vector2.UP.rotated((i - 3) * 0.14) * 650, "damage":(24 + upgrades.barrage * 5) * ability_power(), "weapon":"barrage", "target":int(target.get("id", -1))})
	elif ability == "overdrive":
		overdrive_left = (4.0 + (upgrades.overdrive - 1) * 0.6) * ability_power()
	elif ability == "chrono":
		chrono_left = (4.0 + (upgrades.chrono - 1) * 0.5) * ability_power()
	elif ability == "mend":
		mend_left = 4.0
		mend_rate = (24 + (upgrades.mend - 1) * 6) * ability_power() / 4.0
		if upgrades.mend >= 5:
			shield = minf(max_shield, shield + 15)
	if ability not in ["aegis", "nova"]:
		effects.append({"kind":ability, "p":ship_position(), "life":0.6, "max_life":0.6, "born":tick})
	return true

func _offer_cards(consume_level: bool = true) -> void:
	var pool: Array = []
	for card in content.cards:
		if upgrades[card.id] < int(card.max) and card.id not in banished:
			pool.append(card.duplicate(true))
	cards.clear()
	# Draw once, checkpoint the exact hand. RNG state is part of the save.
	while cards.size() < 3 + int(meta.extra_card) and not pool.is_empty():
		var index := rng.randi_range(0, pool.size() - 1)
		cards.append(pool.pop_at(index))
	# Put a new active on the first draft, then every third level until learned.
	if level == 2 or level % 3 == 0:
		var has_new := cards.any(func(c): return c.tag == "ABILITY" and upgrades[c.id] == 0)
		var learnable := pool.filter(func(c): return c.tag == "ABILITY" and upgrades[c.id] == 0)
		if not has_new and not learnable.is_empty():
			cards[-1] = learnable[rng.randi_range(0, learnable.size() - 1)]
	if hull < max_hull * 0.40 and not cards.is_empty():
		var has_defense := false
		for card in cards:
			has_defense = has_defense or card.id in ["armor", "regen", "hull", "aegis"]
		if not has_defense:
			cards[0] = {"id": "repair", "name": "Emergency repair", "tag": "RECOVERY", "description": "Restore 30 hull immediately.", "max": 99}
	if cards.is_empty():
		cards.append({"id": "repair", "name": "Field repair", "tag": "RECOVERY", "description": "Restore 30 hull.", "max": 99})
	if consume_level:
		pending_levels -= 1

func reroll_cards() -> bool:
	if cards.is_empty() or rerolls_left <= 0:
		return false
	rerolls_left -= 1
	_offer_cards(false)
	return true

func banish_card(index: int) -> bool:
	if index < 0 or index >= cards.size() or banishes_left <= 0 or cards[index].id == "repair":
		return false
	banishes_left -= 1
	banished.append(cards[index].id)
	_offer_cards(false)
	return true

func skip_cards() -> bool:
	if cards.is_empty() or skips_left <= 0:
		return false
	skips_left -= 1
	hull = minf(max_hull, hull + 12)
	cards.clear()
	return true

func choose_card(index: int) -> bool:
	if index < 0 or index >= cards.size():
		return false
	var id: String = cards[index].id
	if id == "repair":
		hull = minf(max_hull, hull + 30)
	else:
		upgrades[id] += 1
		if id == "hull":
			max_hull += 18
			hull = minf(max_hull, hull + 18)
		if id == "shield":
			max_shield += 10
			shield = minf(max_shield, shield + 10)
	_log("Installed " + cards[index].name)
	cards.clear()
	return true

func _log(message: String) -> void:
	events.append({"time": time, "message": message})
	if events.size() > 120:
		events.pop_front()

func payout() -> int:
	return int((5 + int(kills / 6) + meta.stipend * 2 + (15 + meta.bounty * 5 if won else 0)) * (1.0 + meta.cores * 0.08))

func snapshot() -> Dictionary:
	var state: Dictionary = {"version": SAVE_VERSION, "rng": rng.state}
	for key in ["seed_value", "movement_version", "tick", "time", "hull", "max_hull", "shield", "max_shield", "shield_offline", "aegis_left", "cooldowns", "upgrades", "enemies", "bullets", "shots", "effects", "charges", "events", "damage_taken", "damage_dealt", "xp", "level", "kills", "cards", "pending_levels", "ended", "won", "next_spawn", "pulse_timer", "seeker_timer", "heavy_ready_at", "boss_spawned", "next_id", "ability_uses", "prevented", "beams_fired", "beams_cancelled", "meta"]:
		state[key] = get(key)
	for key in ["overdrive_left", "chrono_left", "mend_left", "mend_rate", "emergency_used", "arc_timer", "lance_timer", "rerolls_left", "banishes_left", "skips_left", "banished"]:
		state[key] = get(key)
	return state.duplicate(true)

func restore(state: Dictionary) -> bool:
	if state.get("version", -1) != SAVE_VERSION:
		return false
	for key in state:
		if key not in ["version", "rng"]:
			if key in ["upgrades", "cooldowns", "meta", "damage_dealt"]:
				var merged: Dictionary = get(key).duplicate(true)
				merged.merge(state[key], true)
				set(key, merged)
			else:
				set(key, state[key])
	movement_version = int(state.get("movement_version", 1))
	_build_course()
	rng.state = state.rng
	return true
