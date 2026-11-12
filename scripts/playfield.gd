extends Node2D
## Material ship art, parallax debris, banking and layered combat VFX.
const CYAN := Color("66f5df")
const AMBER := Color("ffc078")
const SHIPS := {
	"vanguard": preload("res://assets/art/vanguard.png"),
	"drone": preload("res://assets/art/drone.png"),
	"gunship": preload("res://assets/art/gunship.png"),
	"sniper": preload("res://assets/art/sniper.png"),
	"boss": preload("res://assets/art/harvester.png")
}
const SPACE = preload("res://assets/art/debris-belt.png")
var host: Node
var sim: RefCounted
var profile: Dictionary
var visual_time := 0.0

func _draw() -> void:
	sim = host.sim
	profile = host.profile
	visual_time = host.visual_time
	var ship: Vector2 = sim.ship_position()
	var velocity: Vector2 = sim.ship_velocity()
	var drift := Vector2((270 - ship.x) * 0.13, sin(visual_time * 0.035) * 22)
	draw_rect(Rect2(0, 0, 540, 960), Color("050913"))
	var scroll := visual_time * 65.0
	for tile in range(-1, 2):
		var y := tile * 1070.0 + fposmod(scroll, 1070.0) - 55
		var flipped := posmod(tile - floori(scroll / 1070.0), 2) == 1
		draw_set_transform(Vector2(-35 + drift.x, y + (1070 if flipped else 0)), 0, Vector2(1, -1 if flipped else 1))
		draw_texture_rect(SPACE, Rect2(0, 0, 610, 1070), false, Color(0.72, 0.79, 0.90))
	draw_set_transform(Vector2.ZERO)
	# Three depths of moving starlight sell forward flight without steering the player.
	for i in range(90):
		var depth := 0.35 + (i % 4) * 0.24
		var p := Vector2(fposmod(i * 137.51 + drift.x * depth, 540), fposmod(i * 97.13 + visual_time * (85 + depth * 180), 960))
		var color := Color(0.65, 0.82, 1.0, 0.16 + depth * 0.25)
		draw_line(p, p + Vector2(-velocity.x * 0.025, 5.0 + depth * 11), color, 1)
	for i in range(9):
		var depth := 0.35 + (i % 3) * 0.3
		var p := Vector2(fposmod(i * 173.7 + 35 + drift.x * depth, 600) - 30, fposmod(i * 231.2 + visual_time * (95 + depth * 110), 1120) - 80)
		_asteroid(p, 10 + (i % 3) * 13, i, depth)
	_draw_threats()
	# Exact two-second preview remains fair on curved flight paths.
	for i in range(2, 25):
		var p: Vector2 = sim.ship_position(sim.time + i / 12.0)
		draw_circle(p, 1.7, Color(0.4, 0.95, 0.85, (24 - i) / 90.0))
	for bullet in sim.bullets:
		if bullet.kind == "ordnance":
			var direction: Vector2 = bullet.v.normalized()
			draw_line(bullet.p - direction * 20, bullet.p, Color(1, 0.6, 0.25, 0.25), 5, true)
			var points := PackedVector2Array([bullet.p + Vector2(0, -10), bullet.p + Vector2(7, 0), bullet.p + Vector2(0, 10), bullet.p + Vector2(-7, 0), bullet.p + Vector2(0, -10)])
			draw_colored_polygon(points, Color("6e3824"))
			draw_polyline(points, AMBER, 2, true)
			_glow(bullet.p, 2, Color.WHITE)
		else:
			_glow(bullet.p, 3.0, Color("ff738f"))
			draw_circle(bullet.p, 1.1, Color("fff0d6"))
	for shot in sim.shots:
		var color := CYAN if shot.weapon == "pulse" else (Color("d8a4ff") if shot.weapon == "barrage" else AMBER)
		var direction: Vector2 = shot.v.normalized()
		if not profile.reduced:
			draw_line(shot.p - direction * 27, shot.p, Color(color, 0.12), 8, true)
		draw_line(shot.p - direction * 17, shot.p, color, 3, true)
		draw_line(shot.p - direction * 9, shot.p, Color.WHITE, 1.4, true)
	for enemy in sim.enemies:
		_draw_enemy(enemy)
	_draw_player(ship, velocity)
	for effect in sim.effects:
		_draw_effect(effect)
	# Minimal edge framing lets the artwork breathe while bars stay readable.
	for edge in [0, 1]:
		draw_rect(Rect2(edge * 520, 0, 20, 960), Color(0.01, 0.025, 0.04, 0.18))
	draw_rect(Rect2(0, 906, 540, 54), Color(0.015, 0.03, 0.05, 0.85))
	_bar(Rect2(18, 925, 244, 6), sim.hull / sim.max_hull, CYAN)
	_bar(Rect2(278, 925, 244, 6), sim.shield / sim.max_shield, Color("80aaff"))
	_bar(Rect2(18, 941, 504, 3), float(sim.xp) / sim.xp_needed(), AMBER)
	if host.banner_clock > 0:
		draw_string(ThemeDB.fallback_font, Vector2(28, 880), host.banner_text, HORIZONTAL_ALIGNMENT_LEFT, 480, 18, CYAN)

func _draw_player(ship: Vector2, velocity: Vector2) -> void:
	var bank := clampf(velocity.x * 0.004, -0.32, 0.32)
	var thrust := 30.0 + minf(velocity.length(), 120) * 0.20
	if not profile.reduced:
		for side in [-1, 1]:
			for i in range(12, 0, -1):
				var age := i * 0.035
				var past: Vector2 = sim.ship_position(maxf(0, sim.time - age))
				var p := past + Vector2(side * 10, 26 + age * 290)
				draw_circle(p, maxf(1, 5 - i * 0.3), Color(0.35, 0.85, 1.0, (13 - i) * 0.012))
	draw_set_transform(ship, bank)
	for side in [-1, 1]:
		var nozzle := Vector2(side * 10, 26)
		var flicker := 1.0 + sin(visual_time * 59 + side) * 0.13
		_glow(nozzle + Vector2(0, thrust * 0.2), 11, Color(0.2, 0.7, 1.0, 0.18))
		var flame := PackedVector2Array([nozzle + Vector2(-5, 0), nozzle + Vector2(0, thrust * flicker), nozzle + Vector2(5, 0)])
		draw_colored_polygon(flame, Color(0.24, 0.75, 1.0, 0.65))
		draw_line(nozzle, nozzle + Vector2(0, thrust * 0.55 * flicker), Color("e5fcff"), 3, true)
	draw_texture_rect(SHIPS.vanguard, Rect2(-38, -42, 76, 76), false)
	if sim.pulse_timer > 0.15:
		_glow(Vector2(0, -35), 6, Color(0.6, 1, 0.9, 0.8))
	draw_set_transform(Vector2.ZERO)
	if sim.aegis_left > 0:
		var alpha := minf(1, sim.aegis_left * 3)
		draw_circle(ship, 47, Color(0.16, 0.7, 0.9, 0.06 * alpha))
		for ring in range(3):
			draw_arc(ship, 45 + ring * 3, 0, TAU, 64, Color(0.3, 0.95, 0.95, (0.55 - ring * 0.18) * alpha), 1.8, true)
		for segment in range(6):
			var angle := visual_time * 0.3 + segment * TAU / 6
			draw_arc(ship, 43, angle, angle + 0.65, 8, Color(0.7, 1.0, 1.0, 0.75 * alpha), 2.5, true)
	if sim.overdrive_left > 0:
		draw_arc(ship, 40, visual_time * 5, visual_time * 5 + 4.7, 32, Color("ff9f78"), 2, true)
	if sim.chrono_left > 0:
		draw_circle(ship, 90, Color(0.55, 0.35, 1.0, 0.07))
		draw_arc(ship, 90, -visual_time, TAU - visual_time, 64, Color(0.7, 0.55, 1.0, 0.45), 1.5, true)
	if sim.mend_left > 0:
		for i in range(3):
			var bot := ship + Vector2.from_angle(visual_time * 2 + i * TAU / 3) * 48
			_glow(bot, 3, Color("91ffc0"))
			draw_line(bot, ship, Color(0.5, 1.0, 0.75, 0.25), 1, true)

func _draw_enemy(enemy: Dictionary) -> void:
	var p: Vector2 = enemy.p
	var boss: bool = enemy.kind == "boss"
	var size := Vector2(190, 190) if boss else (Vector2(75, 75) if enemy.kind == "gunship" else Vector2(62, 62))
	if enemy.kind == "sniper":
		size = Vector2(74, 92)
	var bank := sin(sim.time * 0.7 + enemy.phase) * (0.035 if boss else 0.07)
	draw_set_transform(p, bank)
	draw_texture_rect(SHIPS[enemy.kind], Rect2(-size / 2, size), false)
	if boss:
		_glow(Vector2(0, -18), 14 + sin(visual_time * 4) * 2, Color(1, 0.4, 0.07, 0.3))
	draw_set_transform(Vector2.ZERO)
	if boss:
		draw_rect(Rect2(65, 14, 410, 55), Color(0.03, 0.035, 0.05, 0.8))
		_bar(Rect2(80, 24, 380, 6), enemy.hp / enemy.max_hp, AMBER)
		draw_string(ThemeDB.fallback_font, Vector2(195, 56), "H A R V E S T E R", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, AMBER)
	elif enemy.hp < enemy.max_hp:
		_bar(Rect2(p.x - 20, p.y - size.y * 0.5 - 7, 40, 3), enemy.hp / enemy.max_hp, AMBER)

func _draw_threats() -> void:
	for charge in sim.charges:
		var progress: float = 1.0 - charge.remaining / charge.duration
		draw_rect(Rect2(charge.x - 32, 0, 64, 900), Color(1, 0.48, 0.1, 0.045 + progress * 0.13))
		for side in [-1, 1]:
			draw_line(Vector2(charge.x + side * 32, 0), Vector2(charge.x + side * 32, 900), Color(1, 0.62, 0.25, 0.45 + progress * 0.4), 1.5)
		for i in range(13):
			var y := fposmod(i * 75 + visual_time * 90, 900)
			draw_polyline(PackedVector2Array([Vector2(charge.x - 8, y), Vector2(charge.x, y + 9), Vector2(charge.x + 8, y)]), Color(1, 0.68, 0.27, 0.45), 1.5, true)
		draw_string(ThemeDB.fallback_font, Vector2(clampf(charge.x - 50, 5, 430), 680), "BEAM %.1fs" % charge.remaining, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, AMBER)

func _draw_effect(effect: Dictionary) -> void:
	var alpha: float = effect.life / effect.max_life
	var age := 1.0 - alpha
	var p: Vector2 = effect.p
	if effect.kind in ["arc", "lance"]:
		var end: Vector2 = effect.to
		var color := Color("bba5ff") if effect.kind == "arc" else Color("ffdb96")
		if effect.kind == "arc":
			var points := PackedVector2Array([p])
			for i in range(1, 8):
				points.append(p.lerp(end, i / 8.0) + Vector2(sin(i * 19 + effect.born) * 13, 0))
			points.append(end)
			draw_polyline(points, Color(color, alpha), 2.5, true)
		else:
			draw_line(p, end, Color(color, alpha * 0.12), 16, true)
			draw_line(p, end, Color(color, alpha), 4, true)
			draw_line(p, end, Color(1, 1, 1, alpha), 1.5, true)
	elif effect.kind in ["barrage", "overdrive", "chrono", "mend"]:
		var color := Color("a7a1ff") if effect.kind in ["chrono", "barrage"] else Color("a9ffc9")
		draw_arc(p, 25 + age * 130, 0, TAU, 48, Color(color, alpha * 0.8), 3, true)
	elif effect.kind == "nova":
		var radius := age * 790
		if not profile.reduced:
			draw_arc(p, radius, 0, TAU, 100, Color(0.2, 0.9, 1, alpha * 0.08), 65, true)
		draw_arc(p, radius, 0, TAU, 100, Color(0.4, 1, 0.9, alpha), 5, true)
		draw_arc(p, radius * 0.83, 0, TAU, 90, Color(0.8, 1, 1, alpha * 0.4), 2, true)
	elif effect.kind == "beam":
		if not profile.reduced:
			draw_line(p, p + Vector2(0, 920), Color(1, 0.32, 0.08, alpha * 0.18), 80, true)
		draw_line(p, p + Vector2(0, 920), Color(1, 0.6, 0.17, alpha * 0.7), 38, true)
		draw_line(p, p + Vector2(0, 920), Color(1, 0.97, 0.8, alpha), 9, true)
	elif effect.kind in ["impact", "shield-hit", "hull-hit"]:
		var color := CYAN if effect.kind == "shield-hit" else AMBER
		_glow(p, 3 + age * 10, Color(color, alpha * 0.7))
		for i in range(5):
			var angle: float = i * TAU / 5 + effect.get("born", 0) * 0.17
			var direction := Vector2.from_angle(angle)
			draw_line(p + direction * age * 7, p + direction * age * 26, Color(color, alpha), 1.8, true)
	else:
		var big: bool = effect.get("boss", false)
		var radius := (115 if big else 48) * age
		_glow(p, maxf(1, (32 if big else 15) * alpha), Color(1.0, 0.75, 0.3, alpha))
		draw_arc(p, radius + 5, 0, TAU, 48, Color(1, 0.6, 0.2, alpha * 0.65), 2.0, true)
		var count := 14 if profile.reduced else 25
		for i in range(count):
			var angle: float = i * 2.39996 + effect.get("born", 0) * 0.11
			var direction := Vector2.from_angle(angle)
			var distance := radius * (0.4 + fposmod(i * 0.173, 0.7))
			var tail := p + direction * distance
			draw_line(tail, tail + direction * (3 + alpha * 12), Color(1, 0.45 + (i % 3) * 0.15, 0.2, alpha), 1.5, true)

func _asteroid(p: Vector2, radius: float, index: int, depth: float) -> void:
	var vertices := PackedVector2Array()
	for i in range(8):
		var a := i * TAU / 8 + index + visual_time * 0.04
		vertices.append(p + Vector2.from_angle(a) * radius * (0.8 + fposmod(i * 0.371 + index * 0.13, 0.4)))
	draw_colored_polygon(vertices, Color(0.12 + depth * 0.08, 0.105 + depth * 0.055, 0.10 + depth * 0.05))
	for i in range(vertices.size()):
		var next := vertices[(i + 1) % vertices.size()]
		draw_colored_polygon(PackedVector2Array([p, vertices[i], next]), Color(0.1 + i % 3 * 0.025, 0.10 + i % 3 * 0.018, 0.11 + i % 3 * 0.012))
	draw_circle(p + Vector2(-radius * 0.2, -radius * 0.12), radius * 0.24, Color(0.055, 0.06, 0.07))
	draw_arc(p + Vector2(-radius * 0.2, -radius * 0.12), radius * 0.24, 0, PI, 10, Color(0.27, 0.20, 0.14, 0.45), 1.0)

func _glow(p: Vector2, radius: float, color: Color) -> void:
	if not profile.reduced:
		draw_circle(p, radius * 3, Color(color, color.a * 0.055))
		draw_circle(p, radius * 1.8, Color(color, color.a * 0.14))
	draw_circle(p, radius, color)

func _bar(rect: Rect2, fraction: float, color: Color) -> void:
	draw_rect(rect, Color("1d2a3b"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(fraction, 0, 1), rect.size.y)), color)
