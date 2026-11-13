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
var movement_version := 4
var difficulty := "normal"
var stage := 1
var stage_start := 0.0
var stage_clears := 0
var stage_transition_queued := false
var active_slots: Array = []
var ship_id := "vanguard"
var pilot_id := "rookie"
var next_hazard := 20.0
var tick := 0
var time := 0.0
var hull := 100.0
var max_hull := 100.0
var shield := 50.0
var max_shield := 50.0
var shield_offline := 0.0
var aegis_left := 0.0
var cooldowns := {"aegis": 0.0, "nova": 0.0, "barrage": 0.0, "overdrive": 0.0, "chrono": 0.0, "mend": 0.0}
var upgrades := {"pulse": 1, "seeker": 1, "armor": 0, "regen": 0, "hull": 0, "coolant": 0, "aegis": 0, "nova": 0}
var overdrive_left := 0.0
var chrono_left := 0.0
var emp_left := 0.0
var barrier_left := 0.0
var focus_left := 0.0
var decoy_left := 0.0
var jammer_left := 0.0
var salvage_left := 0.0
var corrosion_left := 0.0
var bonus_cores := 0
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
var damage_taken := {"chaff": 0.0, "heavy": 0.0, "ordnance": 0.0, "hazard": 0.0, "ion": 0.0, "corrosion": 0.0, "disrupt": 0.0}
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

func _init(run_seed: int = 1, hangar: Dictionary = {}, selected_ship: String = "vanguard", selected_pilot: String = "rookie", selected_difficulty: String = "normal") -> void:
	content = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
	for id in Catalog.ABILITIES:
		if not cooldowns.has(id):
			cooldowns[id] = 0.0
	for card in content.cards:
		if not upgrades.has(card.id):
			upgrades[card.id] = 0
	ship_id = Catalog.ship(selected_ship).id
	pilot_id = Catalog.pilot(selected_pilot).id
	difficulty = selected_difficulty if selected_difficulty in Catalog.DIFFICULTIES else "normal"
	seed_value = run_seed
	rng.seed = run_seed
	_build_course()
	for key in meta:
		meta[key] = int(hangar.get(key, 0))
	var chassis: Dictionary = Catalog.ship(ship_id)
	max_hull = float(chassis.hull) + meta.hull * 10.0
	hull = max_hull
	max_shield = float(chassis.shield) + meta.shield * 8.0 + (20.0 if pilot_id == "engineer" else 0.0)
	shield = max_shield
	upgrades.pulse = int(chassis.pulse) + meta.pulse_start
	upgrades.seeker = int(chassis.seeker) + meta.seeker_start
	upgrades.arc = int(chassis.arc)
	upgrades.mend = int(chassis.mend)
	var signature: String = chassis.signature
	upgrades[signature] = maxi(1, int(upgrades.get(signature, 0)))
	active_slots = [signature]
	rerolls_left = meta.rerolls + (1 if pilot_id == "tactician" else 0)
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
	while arrival < 1200.0:
		var movement: float = float(Catalog.ship(ship_id).movement) if movement_version >= 4 else 1.0
		arrival += (pilot.randf_range(1.65, 2.8) / movement if movement_version >= 4 else (pilot.randf_range(2.2, 4.0) if movement_version >= 3 else pilot.randf_range(3.8, 7.5)))
		var target: Vector2
		if movement_version >= 4:
			target = previous + Vector2(pilot.randf_range(-245, 245), pilot.randf_range(-115, 115))
		elif movement_version >= 3:
			target = previous + Vector2(pilot.randf_range(-220, 220), pilot.randf_range(-72, 72))
		else:
			target = previous + Vector2(pilot.randf_range(-115, 115), pilot.randf_range(-20, 20))
		if pilot.randf() < (0.05 if movement_version >= 4 else (0.10 if movement_version >= 3 else 0.24)):
			target = previous + Vector2(pilot.randf_range(-18, 18), pilot.randf_range(-8, 8))
		target.x = clampf(target.x, 80 if movement_version >= 4 else (100 if movement_version >= 3 else 125), 460 if movement_version >= 4 else (440 if movement_version >= 3 else 415))
		target.y = clampf(target.y, 610 if movement_version >= 4 else (665 if movement_version >= 3 else 755), 835 if movement_version >= 4 else (815 if movement_version >= 3 else 810))
		course.append({"t": arrival, "p": target})
		previous = target

func ship_position(at: float = -1.0) -> Vector2:
	if at < 0.0:
		at = time
	# Keep an old suspended flight's original trajectory; all new flights use the new pilot.
	if movement_version == 1:
		return Vector2(WIDTH * 0.5 + sin(at * TAU / 6.0) * WIDTH * 0.30, 790.0)
	# Binary search avoids re-scanning the growing two-stage course for every projectile.
	var lo := 1
	var hi := course.size() - 2
	while lo < hi:
		var mid := (lo + hi) / 2
		if at > float(course[mid + 1].t):
			lo = mid + 1
		else:
			hi = mid
	var index := lo
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
	# Cubic Bezier is equivalent to Hermite until the control points reach
	# the safety envelope. Keeping handles within it prevents overshooting
	# the gameplay boundary, without snapping the ship or changing old saves.
	var u := weight
	if movement_version >= 4:
		var handle1: Vector2 = start + velocity0 * duration / 3.0
		var handle2: Vector2 = end - velocity1 * duration / 3.0
		handle1.x = clampf(handle1.x, 75.0, 465.0)
		handle2.x = clampf(handle2.x, 75.0, 465.0)
		handle1.y = clampf(handle1.y, 600.0, 850.0)
		handle2.y = clampf(handle2.y, 600.0, 850.0)
		return start * pow(1.0-u, 3) + 3.0 * handle1 * pow(1.0-u, 2) * u + 3.0 * handle2 * (1.0-u) * u*u + end * u*u*u
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
	for timer in ["emp_left", "barrier_left", "focus_left", "decoy_left", "jammer_left", "salvage_left", "corrosion_left"]:
		set(timer, maxf(0.0, float(get(timer)) - DT))
	if corrosion_left > 0.0:
		var corrosion_damage := DT * 1.4
		hull = maxf(0.0, hull - corrosion_damage)
		damage_taken.corrosion += corrosion_damage
		if hull <= 0.0:
			ended = true
			_log("Hull lost to corrosion")
			return
	if mend_left > 0.0:
		hull = minf(max_hull, hull + mend_rate * minf(DT, mend_left))
		mend_left = maxf(0.0, mend_left - DT)
	hull = minf(max_hull, hull + (upgrades.repair_bots * 0.15 + meta.repair * 0.15 + (0.25 if ship_id == "haven" else 0.0)) * DT)
	if shield_offline > 0.0:
		shield_offline = maxf(0.0, shield_offline - DT)
	else:
		shield = minf(max_shield, shield + (1.5 + upgrades.regen * 0.35 + meta.regen * 0.25 + (0.8 if pilot_id == "engineer" else 0.0)) * DT)
	for effect in effects:
		effect.life -= DT
	effects = effects.filter(func(e): return e.life > 0.0)
	if not boss_spawned and time - stage_start >= float(content.boss_at):
		_spawn_boss()
	if time >= next_spawn and not boss_spawned:
		_spawn_enemy()
		var stage_time := time - stage_start
		var pace := maxf(0.55, 1.65 - stage_time / 260.0)
		next_spawn = time + pace / ((1.45 if stage > 1 else 1.0) * threat_scale())
	if time >= next_hazard and not boss_spawned:
		_spawn_hazard()
		next_hazard = time + rng.randf_range(15.0, 23.0)
	_update_enemies()
	_update_charges()
	_update_weapons()
	_update_bullets()
	_update_shots()
	if stage_transition_queued:
		_enter_stage_two()
	if pending_levels > 0 and not ended:
		_offer_cards()

func threat_scale() -> float:
	return {"normal": 1.0, "hard": 1.25, "insane": 1.6}[difficulty]

func _spawn_enemy() -> void:
	if enemies.size() >= (26 if stage > 1 else 20):
		return
	# Gradually broaden the roster rather than throwing every threat at a new player.
	var pool: Array = ["drone", "drone", "drone", "rusher"]
	var stage_time := time - stage_start
	if stage_time > 25:
		pool.append_array(["interceptor", "gunship", "drone"])
	if stage_time > 65:
		pool.append_array(["sniper", "missile_bomber", "interceptor"])
	if stage_time > 110:
		pool.append_array(["carrier", "shieldguard", "minelayer", "missile_bomber"])
	if stage_time > 170:
		pool.append_array(["shieldguard", "minelayer", "carrier"])
	if stage > 1 or (difficulty == "insane" and stage_time > 120):
		pool.append_array(["ion_frigate", "corroder", "disruptor", "ion_frigate", "missile_bomber", "minelayer"])
	var kind: String = pool[rng.randi_range(0, pool.size() - 1)]
	_add_enemy(kind, Vector2(rng.randf_range(55, 485), -35))

func _add_enemy(kind: String, position: Vector2) -> void:
	var spec: Dictionary = content.enemies[kind]
	var scaling := (1.0 + (time - stage_start) / 340.0) * (1.55 if stage > 1 else 1.0) * threat_scale()
	enemies.append({"id": next_id, "kind": kind, "p": position, "hp": float(spec.hp) * scaling, "max_hp": float(spec.hp) * scaling, "speed": float(spec.speed), "fire": rng.randf_range(1.0, 3.0), "xp": int(spec.xp), "phase": rng.randf_range(0, TAU)})
	next_id += 1

func _spawn_hazard() -> void:
	if enemies.size() >= (25 if stage > 1 else 19):
		return
	var kind := "station" if stage > 1 and rng.randf() < 0.6 else ("boulder" if rng.randf() < 0.65 else "station")
	_add_enemy(kind, Vector2(rng.randf_range(85, 455), -65))
	_log("Incoming debris" if kind == "boulder" else "Hostile station detected")

func _spawn_boss() -> void:
	boss_spawned = true
	enemies.clear()
	bullets.clear()
	charges.clear()
	shield = max_shield
	hull = minf(max_hull, hull + 15)
	heavy_ready_at = time + 3.0
	var boss_kind := "boss2" if stage > 1 else "boss"
	var hp := (10000.0 if stage > 1 else 6200.0) * threat_scale()
	enemies.append({"id": next_id, "kind": boss_kind, "p": Vector2(270, 135), "hp": hp, "max_hp": hp, "speed": 0.0, "fire": 1.0, "xp": 0, "phase": 0.0})
	next_id += 1
	_log(("Storm Carrier" if stage > 1 else "Harvester") + " arrived · shield refilled, +15 hull")

func _enter_stage_two() -> void:
	stage = 2
	stage_start = time
	stage_transition_queued = false
	boss_spawned = false
	enemies.clear()
	bullets.clear()
	shots.clear()
	charges.clear()
	shield = max_shield
	hull = minf(max_hull, hull + 20.0)
	next_spawn = time + 1.5
	next_hazard = time + 15.0
	heavy_ready_at = time + 10.0
	pending_levels += 1 # One substantial stage-clear build choice.
	_log("STAGE 2 · ION STORM · NEW THREATS")

func _update_enemies() -> void:
	var pace := 0.45 if chrono_left > 0 else 1.0
	var minions: Array = []
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		var kind: String = enemy.kind
		if kind in ["boss", "boss2"]:
			enemy.p.x = 270.0 + sin(time * (0.9 if stage > 1 else 0.7)) * 105.0
		else:
			enemy.p.y += enemy.speed * DT * pace
			if kind == "interceptor":
				enemy.p.x += cos(time * 4.2 + enemy.phase) * 135.0 * DT * pace
			elif kind == "rusher":
				enemy.p.x = move_toward(enemy.p.x, ship_position().x, 28.0 * DT * pace)
			elif kind == "minelayer":
				enemy.p.x += sin(time * 3.0 + enemy.phase) * 48.0 * DT * pace
			else:
				enemy.p.x += sin(time * 1.8 + enemy.phase) * 12.0 * DT * pace
			enemy.p.x = clampf(enemy.p.x, 35, 505)
		if kind == "boulder":
			if enemy.p.y > 945.0:
				enemy.hp = -1.0
			elif enemy.p.distance_to(ship_position()) < 44.0:
				_hit(17.0, "hazard", "Boulder collision")
				enemy.hp = -1.0
			continue
		enemy.fire -= DT * pace
		if kind in ["sniper", "boss", "boss2"] and time >= heavy_ready_at and charges.is_empty() and jammer_left <= 0.0 and emp_left <= 0.0:
			var lead := 1.8
			charges.append({"source": enemy.id, "x": ship_position(time + lead).x, "remaining": lead, "duration": lead, "damage": (45.0 if kind == "boss2" else (35.0 if kind == "boss" else 28.0)) * threat_scale()})
			heavy_ready_at = time + (6.0 if stage > 1 else (7.5 if kind == "boss" else 10.0))
			_log("Heavy beam charging")
		if enemy.fire <= 0.0:
			if jammer_left > 0.0 or emp_left > 0.0:
				enemy.fire = 0.5
				continue
			enemy.fire = (1.6 if stage > 1 else 2.1) if kind in ["boss", "boss2"] else float(content.enemies[kind].interval) / threat_scale()
			var flight_time: float = enemy.p.distance_to(ship_position()) / 215.0
			flight_time = enemy.p.distance_to(ship_position(time + flight_time)) / 215.0
			var aim := ship_position(time + flight_time)
			if decoy_left > 0.0:
				aim = Vector2(70 if ship_position().x > 270 else 470, 700)
			var direction: Vector2 = (aim - enemy.p).normalized()
			if kind == "carrier":
				if enemies.size() + minions.size() < 19:
					minions.append({"p": enemy.p + Vector2(rng.randf_range(-30, 30), 28)})
				bullets.append({"p": enemy.p, "v": direction * 165.0, "damage": 2.0, "kind": "chaff", "source": kind})
			elif kind == "minelayer":
				bullets.append({"p": enemy.p, "v": Vector2(0, 62), "damage": 12.0, "kind": "mine", "hp": 14.0, "fuse": 3.4, "source": kind})
			else:
				var count := (13 if kind == "boss2" else 9) if kind in ["boss", "boss2"] else (5 if kind == "gunship" else (2 if kind in ["interceptor", "rusher"] else 3))
				for i in range(count):
					var angle := (i - (count - 1) / 2.0) * 0.15
					var bullet_kind := ("ion" if kind == "ion_frigate" else ("corrosion" if kind == "corroder" else ("disrupt" if kind == "disruptor" else "chaff")))
					bullets.append({"p": enemy.p, "v": direction.rotated(angle) * (245.0 if kind == "interceptor" else 215.0), "damage": (2.1 if kind in ["boss", "boss2"] else (1.25 if kind in ["rusher", "interceptor"] else 1.6)) * threat_scale(), "kind": bullet_kind, "source": kind})
				if kind in ["gunship", "missile_bomber", "station", "boss2"]:
					var volley := 3 if kind == "boss2" else (2 if kind == "missile_bomber" else 1)
					for i in range(volley):
						bullets.append({"p":enemy.p + Vector2((i * 2 - volley + 1) * 13, 0), "v": direction.rotated((i * 2 - volley + 1) * 0.10) * (175.0 if kind == "missile_bomber" else 140.0), "damage": (11.0 if kind == "missile_bomber" else 12.0) * threat_scale(), "kind":"ordnance", "hp":12.0, "source":kind})
		if enemy.p.y > 885:
			enemy.hp = -1.0
			if kind not in ["boulder", "station"]:
				_hit(5.0, "hazard", "Escaped " + kind)
	enemies = enemies.filter(func(e): return e.hp > 0.0)
	for minion in minions:
		if enemies.size() < (26 if stage > 1 else 20):
			_add_enemy("drone", minion.p)

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
				_hit(charge.damage, "heavy", "Storm Carrier" if stage > 1 and boss_spawned else ("Harvester" if boss_spawned else "Sniper"))
	charges = charges.filter(func(c): return c.remaining > 0.0)

func _update_weapons() -> void:
	var rate: float = (1.0 + upgrades.autoloader * 0.08 + meta.fire_rate * 0.05 + (0.75 if overdrive_left > 0 else 0.0)) * float(Catalog.ship(ship_id).fire_rate)
	pulse_timer -= DT * rate
	seeker_timer -= DT * rate
	arc_timer -= DT * rate
	lance_timer -= DT * rate
	var bank := clampf(ship_velocity().x * 0.004, -0.32, 0.32)
	var origin := ship_position() + Vector2(0, -34).rotated(bank)
	if upgrades.pulse > 0 and pulse_timer <= 0.0:
		pulse_timer += 0.19
		var barrels := 2 if upgrades.pulse >= 5 else 1
		for n in range(barrels):
			shots.append({"p": origin + Vector2((n * 2 - barrels + 1) * 8, 0), "v": Vector2(0, -980).rotated(bank), "damage": (7.0 + (upgrades.pulse - 1) * 1.68) * weapon_power() * (1.25 if pilot_id == "ace" else 1.0), "weapon": "pulse", "target": -1})
	if upgrades.seeker > 0 and seeker_timer <= 0.0:
		seeker_timer += (0.62 if pilot_id == "hunter" else 0.70)
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
				if bullet.kind in ["ordnance", "mine"]:
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
			shots.append({"p": origin, "v": (target_pos - origin).normalized() * 650.0, "damage": (14.0 + (upgrades.seeker - 1) * 4.2) * weapon_power() * (1.35 if ship_id == "wraith" else 1.0) * (1.3 if pilot_id == "hunter" else 1.0), "weapon": "seeker", "target": target_id})
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
			_damage_enemy(target, (10 + upgrades.arc * 3) * weapon_power() * (1.3 if ship_id == "arcwing" else 1.0), "arc")
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
	return (1.0 + meta.damage * 0.08 + upgrades.munitions * 0.08) * (1.85 if focus_left > 0.0 else 1.0)

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
			var target := Vector2(70 if ship.x > 270 else 470, 700) if decoy_left > 0.0 else ship
			bullet.v = bullet.v.lerp((target - bullet.p).normalized() * (185.0 if bullet.source == "missile_bomber" else 155.0), DT * 0.9)
		if bullet.kind == "mine":
			bullet.fuse -= DT * (0.45 if chrono_left > 0 else 1.0)
			if bullet.fuse <= 0.0:
				effects.append({"kind":"explosion", "p":bullet.p, "life":0.38, "max_life":0.38, "born":tick})
				if bullet.p.distance_to(ship) < 83.0:
					_hit(bullet.damage, "hazard", "Proximity mine")
				bullet.hp = 0.0
		bullet.p += bullet.v * DT * (0.45 if chrono_left > 0 else 1.0)
		var hit_radius := 18.0 if bullet.kind == "ordnance" else (13.0 if bullet.kind == "mine" else 10.0)
		if bullet.p.distance_squared_to(ship) < hit_radius * hit_radius and int(bullet.get("hp", 1)) > 0:
			if not (barrier_left > 0.0 and bullet.kind == "chaff"):
				_hit(bullet.damage, "hazard" if bullet.kind == "mine" else bullet.kind, bullet.source)
			bullet.p.y = HEIGHT + 100
	bullets = bullets.filter(func(b): return b.p.y < HEIGHT + 35 and b.p.y > -100 and b.p.x > -60 and b.p.x < WIDTH + 60 and b.get("hp", 1) > 0)

func _update_shots() -> void:
	# Only interceptor-capable projectiles belong in collision buckets.
	# Avoid the former every-player-shot x every-enemy-bullet scan.
	const CELL := 64.0
	var ordnance_cells: Dictionary = {}
	for bullet in bullets:
		if bullet.kind not in ["ordnance", "mine"] or float(bullet.get("hp", 1)) <= 0.0:
			continue
		var cell := Vector2i(floori(bullet.p.x / CELL), floori(bullet.p.y / CELL))
		if not ordnance_cells.has(cell):
			ordnance_cells[cell] = []
		ordnance_cells[cell].append(bullet)
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
				if enemy.hp <= 0 or offset.y >= -8 or absf(Vector2.UP.angle_to(offset)) > 0.58 + meta.guidance * 0.035 + (0.12 if pilot_id == "ace" else 0.0):
					continue
				var candidate_score := absf(offset.x) + offset.length() * 0.10
				if candidate_score < score:
					score = candidate_score
					candidate = enemy
			if not candidate.is_empty():
				var desired: Vector2 = (candidate.p - shot.p).normalized()
				shot.v = shot.v.rotated(clampf(shot.v.angle_to(desired), -DT * (0.85 + meta.guidance * 0.12 + (0.25 if pilot_id == "ace" else 0.0)), DT * (0.85 + meta.guidance * 0.12)))
		if shot.weapon in ["seeker", "barrage"] and shot.target >= 0:
			for enemy in enemies:
				if enemy.id == shot.target:
					shot.v = shot.v.lerp((enemy.p - shot.p).normalized() * 650, DT * 8.0)
		if shot.weapon == "seeker" and shot.target == -2:
			for bullet in bullets:
				if bullet.kind in ["ordnance", "mine"]:
					shot.v = shot.v.lerp((bullet.p - shot.p).normalized() * 650, DT * 8.0)
					break
		shot.p += shot.v * DT
		var struck := false
		if shot.weapon in ["seeker", "barrage", "pulse"]:
			var center := Vector2i(floori(shot.p.x / CELL), floori(shot.p.y / CELL))
			for dx in range(-1, 2):
				if struck:
					break
				for dy in range(-1, 2):
					if struck:
						break
					for bullet in ordnance_cells.get(center + Vector2i(dx, dy), []):
						if float(bullet.get("hp", 1)) > 0.0 and bullet.p.distance_squared_to(shot.p) < 28.0 * 28.0:
							bullet.hp -= shot.damage
							if bullet.hp <= 0.0:
								effects.append({"kind":"explosion", "p":bullet.p, "life":0.30, "max_life":0.30, "born":tick})
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
	if enemy.kind == "shieldguard":
		amount *= 0.72
	if upgrades.targeting > 0 and weapon in ["pulse", "seeker", "arc", "lance"] and rng.randf() < upgrades.targeting * 0.05:
		amount *= 2.0
	damage_dealt[weapon] = float(damage_dealt.get(weapon, 0.0)) + minf(amount, enemy.hp)
	enemy.hp -= amount
	effects.append({"kind": "impact", "p": enemy.p, "life": 0.16, "max_life": 0.16, "born": tick})
	if enemy.hp > 0:
		return
	kills += 1
	if salvage_left > 0.0:
		bonus_cores += 1 + int(upgrades.salvage / 2)
	effects.append({"kind": "explosion", "p": enemy.p, "life": 0.72 if enemy.kind == "boss" else 0.5, "max_life": 0.72 if enemy.kind == "boss" else 0.5, "born": tick, "boss": enemy.kind == "boss"})
	var before := charges.size()
	charges = charges.filter(func(c): return c.source != enemy.id)
	beams_cancelled += before - charges.size()
	xp += enemy.xp * (1.0 + meta.xp * 0.06 + upgrades.harvester * 0.08 + (0.25 if pilot_id == "scavenger" else 0.0))
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		pending_levels += 1
	if enemy.kind == "boss":
		stage_clears = 1
		stage_transition_queued = true
		_log("Harvester destroyed · Stage 2 unlocked")
	elif enemy.kind == "boss2":
		stage_clears = 2
		ended = true
		won = true
		_log("Storm Carrier destroyed · full clear")

func xp_needed() -> int:
	return 25 + (level - 1) * 9

func _hit(amount: float, kind: String, source: String) -> void:
	if ended:
		return
	if aegis_left > 0:
		prevented += amount
		effects.append({"kind": "shield-hit", "p": ship_position(), "life": 0.16, "max_life": 0.16, "born": tick})
		return
	var reduced := amount
	if kind == "ion":
		shield_offline = maxf(shield_offline, 4.0)
	elif kind == "corrosion":
		corrosion_left = maxf(corrosion_left, 5.0)
	elif kind == "disrupt":
		for id in active_slots:
			if cooldowns[id] > 0.0:
				cooldowns[id] = minf(60.0, cooldowns[id] + 2.0)
	if kind == "chaff":
		reduced = maxf(amount * 0.25, amount - upgrades.armor * 0.35 - meta.armor * 0.12 - (0.75 if ship_id == "bulwark" else 0.0))
	var shield_damage := minf(shield, reduced)
	var had_shield := shield > 0.0
	shield -= shield_damage
	var hull_damage := reduced - shield_damage
	hull = maxf(0.0, hull - hull_damage)
	effects.append({"kind": "hull-hit" if hull_damage > 0 else "shield-hit", "p": ship_position(), "life": 0.22, "max_life": 0.22, "born": tick})
	damage_taken[kind] = float(damage_taken.get(kind, 0.0)) + reduced
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
	if ended or not cards.is_empty() or ability not in active_slots or not cooldowns.has(ability) or int(upgrades.get(ability, 0)) <= 0 or cooldowns[ability] > 0.0:
		return false
	ability_uses += 1
	cooldowns[ability] = float(content.abilities[ability].cooldown) * maxf(0.4, 1.0 - upgrades.coolant * 0.08 - meta.ability_cooldown * 0.03 - (0.15 if pilot_id == "tactician" else 0.0))
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
	elif ability == "flak":
		var stopped := bullets.filter(func(b): return b.kind in ["ordnance", "mine"]).size()
		bullets = bullets.filter(func(b): return b.kind not in ["ordnance", "mine"])
		prevented += stopped * 12.0
		for enemy in enemies:
			if enemy.kind in ["missile_bomber", "minelayer", "boss2"]:
				_damage_enemy(enemy, 30.0 * ability_power(), "flak")
	elif ability == "emp":
		beams_cancelled += charges.size()
		charges.clear()
		emp_left = (3.0 + upgrades.emp * 0.25) * ability_power()
	elif ability == "deflector":
		var remaining: Array = []
		var absorbed := 0
		for bullet in bullets:
			if bullet.kind == "chaff" and bullet.p.distance_squared_to(ship_position()) < 300.0 * 300.0:
				absorbed += 1
			else:
				remaining.append(bullet)
		bullets = remaining
		shield = minf(max_shield, shield + absorbed * (2.0 + upgrades.deflector * 0.5))
		prevented += absorbed * 1.5
	elif ability == "strike":
		var target: Dictionary = {}
		for enemy in enemies:
			if target.is_empty() or enemy.hp > target.hp:
				target = enemy
		for charge in charges:
			for enemy in enemies:
				if enemy.id == charge.source:
					target = enemy
		if not target.is_empty():
			_damage_enemy(target, (170.0 + 70.0 * upgrades.strike) * ability_power(), "strike")
	elif ability == "prism":
		var remaining: Array = []
		var reflected := 0
		for bullet in bullets:
			if reflected < 18 and bullet.kind in ["chaff", "ion", "corrosion", "disrupt"] and bullet.p.distance_squared_to(ship_position()) < 310.0 * 310.0:
				var target := _nearest(bullet.p)
				shots.append({"p": bullet.p, "v": Vector2.UP * 630.0, "damage": (15.0 + upgrades.prism * 4.0) * ability_power(), "weapon": "barrage", "target": int(target.get("id", -1))})
				reflected += 1
			else:
				remaining.append(bullet)
		bullets = remaining
		prevented += reflected * 1.5
	elif ability == "barrier":
		barrier_left = (6.0 + upgrades.barrier * 0.75) * ability_power()
	elif ability == "capacitor":
		shield_offline = 0.0
		shield = minf(max_shield, shield + (30.0 + upgrades.capacitor * 15.0) * ability_power())
	elif ability == "focus":
		focus_left = (6.0 + upgrades.focus * 0.6) * ability_power()
	elif ability == "decoy":
		decoy_left = (5.0 + upgrades.decoy * 0.6) * ability_power()
	elif ability == "jammer":
		jammer_left = (5.0 + upgrades.jammer * 0.5) * ability_power()
	elif ability == "siphon":
		var target := _nearest(ship_position())
		if not target.is_empty():
			var dealt := minf(target.hp, (75.0 + upgrades.siphon * 38.0) * ability_power())
			_damage_enemy(target, dealt, "siphon")
			hull = minf(max_hull, hull + dealt * 0.30)
	elif ability == "overload":
		var remaining: Array = []
		var detonated := 0
		for bullet in bullets:
			if bullet.kind == "chaff" and bullet.p.distance_squared_to(ship_position()) < 450.0 * 450.0:
				detonated += 1
			else:
				remaining.append(bullet)
		bullets = remaining
		for enemy in enemies:
			_damage_enemy(enemy, minf(250.0, 35.0 + detonated * 5.0 + upgrades.overload * 14.0) * ability_power(), "overload")
	elif ability == "reboot":
		for id in active_slots:
			if id != "reboot":
				cooldowns[id] = maxf(0.0, cooldowns[id] * 0.4 - 2.0 * upgrades.reboot)
	elif ability == "salvage":
		salvage_left = (10.0 + upgrades.salvage * 1.0) * ability_power()
	if ability not in ["aegis", "nova"]:
		effects.append({"kind":ability, "p":ship_position(), "life":0.6, "max_life":0.6, "born":tick})
	return true

func _offer_cards(consume_level: bool = true) -> void:
	var pool: Array = []
	for card in content.cards:
		if upgrades[card.id] < int(card.max) and card.id not in banished:
			if card.tag == "ABILITY" and upgrades[card.id] == 0 and active_slots.size() >= Catalog.ACTIVE_SLOTS:
				continue
			pool.append(card.duplicate(true))
	cards.clear()
	# Draw once, checkpoint the exact hand. RNG state is part of the save.
	while cards.size() < 3 + int(meta.extra_card) and not pool.is_empty():
		var index := rng.randi_range(0, pool.size() - 1)
		cards.append(pool.pop_at(index))
	# Offer a new active at levels 2, 4 and 6 until all four slots are filled.
	if active_slots.size() < Catalog.ACTIVE_SLOTS and level % 2 == 0:
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
		var card: Dictionary = cards[index]
		if card.tag == "ABILITY" and int(upgrades[id]) == 0:
			if active_slots.size() >= Catalog.ACTIVE_SLOTS:
				return false
			active_slots.append(id)
		var before: int = int(upgrades[id])
		var increment: int = 2 if card.tag in ["WEAPON", "SYSTEM"] else 1
		upgrades[id] = mini(int(card.max), before + increment)
		var gained := int(upgrades[id]) - before
		if id == "hull":
			max_hull += 18 * gained
			hull = minf(max_hull, hull + 18 * gained)
		if id == "shield":
			max_shield += 10 * gained
			shield = minf(max_shield, shield + 10 * gained)
	_log("Installed " + cards[index].name)
	cards.clear()
	return true

func _log(message: String) -> void:
	events.append({"time": time, "message": message})
	if events.size() > 120:
		events.pop_front()

func payout() -> int:
	var base: int = int((5 + int(kills / 6) + meta.stipend * 2 + (15 * stage_clears + meta.bounty * 5 * stage_clears) + bonus_cores) * (1.0 + meta.cores * 0.08) * float(Catalog.REWARD_MULTIPLIERS[difficulty]))
	if pilot_id == "scavenger":
		base += maxi(1, int(round(base * 0.15)))
	return base

func snapshot() -> Dictionary:
	var state: Dictionary = {"version": SAVE_VERSION, "rng": rng.state}
	for key in ["seed_value", "movement_version", "difficulty", "stage", "stage_start", "stage_clears", "stage_transition_queued", "active_slots", "next_hazard", "tick", "time", "hull", "max_hull", "shield", "max_shield", "shield_offline", "aegis_left", "cooldowns", "upgrades", "enemies", "bullets", "shots", "effects", "charges", "events", "damage_taken", "damage_dealt", "xp", "level", "kills", "cards", "pending_levels", "ended", "won", "next_spawn", "pulse_timer", "seeker_timer", "heavy_ready_at", "boss_spawned", "next_id", "ability_uses", "prevented", "beams_fired", "beams_cancelled", "meta"]:
		state[key] = get(key)
	for key in ["overdrive_left", "chrono_left", "emp_left", "barrier_left", "focus_left", "decoy_left", "jammer_left", "salvage_left", "corrosion_left", "bonus_cores", "mend_left", "mend_rate", "emergency_used", "arc_timer", "lance_timer", "rerolls_left", "banishes_left", "skips_left", "banished"]:
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
	if not state.has("active_slots"):
		active_slots.clear()
		for id in Catalog.ABILITIES:
			if int(upgrades.get(id, 0)) > 0 and active_slots.size() < Catalog.ACTIVE_SLOTS:
				active_slots.append(id)
	if difficulty not in Catalog.DIFFICULTIES:
		difficulty = "normal"
	_build_course()
	rng.state = state.rng
	return true
