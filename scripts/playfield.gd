extends Node2D
## Material ship art, parallax debris, banking and layered combat VFX.
const FusionArt = preload("res://scripts/fusion_art.gd")
const CYAN := Color("66f5df")
const AMBER := Color("ffc078")
const DANGER := Color("ff727b")
const THREAT_INK := Color("080e1c")
const SHIELD := Color("80aaff")
const SHIPS := {
	"vanguard": preload("res://assets/art/vanguard.png"),
	"kestrel": preload("res://assets/art/kestrel.svg"),
	"bulwark": preload("res://assets/art/bulwark.svg"),
	"wraith": preload("res://assets/art/wraith.svg"),
	"arcwing": preload("res://assets/art/arcwing.svg"),
	"haven": preload("res://assets/art/haven.svg"),
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
var feedback_sim: RefCounted
var feedback_stage := 0
var shield_break_clock := 0.0
var last_shield_break_tick := -1
var formation_clock := 0.0
var formation: Dictionary = {}
var seen_formations := {}

func _process(delta: float) -> void:
	if host == null or host.sim == null:
		return
	if feedback_sim != host.sim or feedback_stage != host.sim.stage:
		feedback_sim = host.sim
		feedback_stage = host.sim.stage
		shield_break_clock = 0.0
		last_shield_break_tick = -1
		formation_clock = 0.0
		formation.clear()
		seen_formations.clear()
	if host.mode == "playing":
		shield_break_clock = maxf(0.0, shield_break_clock - delta)
		formation_clock = maxf(0.0, formation_clock - delta)
	for effect in host.sim.effects:
		if effect.kind == "fusion-formed":
			var key := "%s:%s" % [effect.fusion,effect.born]
			if not seen_formations.has(key):
				seen_formations[key] = true
				formation = effect.duplicate(true)
				formation_clock = 1.2
		if effect.kind == "shield-break" and int(effect.born) > last_shield_break_tick:
			last_shield_break_tick = int(effect.born)
			shield_break_clock = 0.75


func _draw() -> void:
	sim = host.sim
	profile = host.profile
	visual_time = host.visual_time
	var ship: Vector2 = sim.ship_position()
	var velocity: Vector2 = sim.ship_velocity()
	var drift := Vector2((270 - ship.x) * 0.13, sin(visual_time * 0.035) * 22)
	var sector := _sector(sim.time)
	var visual_stage := ((sim.stage - 1) % 4) + 1
	if visual_stage == 1:
		draw_rect(Rect2(0, 0, 540, 960), Color("050913"))
		var scroll := visual_time * 105.0
		var tints := [Color("9db7c9"), Color("6caeb4"), Color("9a82be"), Color("7669a4"), Color("d3a66e")]
		for tile in range(-1, 2):
			var y := tile * 1070.0 + fposmod(scroll, 1070.0) - 55
			var flipped := posmod(tile - floori(scroll / 1070.0), 2) == 1
			draw_set_transform(Vector2(-35 + drift.x, y + (1070 if flipped else 0)), 0, Vector2(1, -1 if flipped else 1))
			draw_texture_rect(SPACE, Rect2(0, 0, 610, 1070), false, tints[sector])
		draw_set_transform(Vector2.ZERO)
	else:
		_draw_stage_backdrop()
	_draw_environment(sector, drift)
	# Three depths of moving starlight sell forward flight without steering the player.
	for i in range(90):
		var depth := 0.35 + (i % 4) * 0.24
		var p := Vector2(fposmod(i * 137.51 + drift.x * depth, 540), fposmod(i * 97.13 + visual_time * (85 + depth * 180), 960))
		var color := Color(0.82, 0.86, 1.0, 0.16 + depth * 0.25) if sector != 4 else Color(1.0, 0.76, 0.45, 0.16 + depth * 0.25)
		draw_line(p, p + Vector2(-velocity.x * 0.025, 5.0 + depth * 11), color, 1)
	for i in range(9 if sim.stage == 1 else (3 if sim.stage == 2 else 0)):
		var depth := 0.35 + (i % 3) * 0.3
		var p := Vector2(fposmod(i * 173.7 + 35 + drift.x * depth, 600) - 30, fposmod(i * 231.2 + visual_time * (95 + depth * 110), 1120) - 80)
		_asteroid(p, 10 + (i % 3) * 13, i, depth)
	# Exact two-second preview remains fair on curved flight paths.
	for i in range(2, 25):
		var p: Vector2 = sim.ship_position(sim.time + i / 12.0)
		draw_circle(p, 1.7, Color(0.4, 0.95, 0.85, (24 - i) / 90.0))
	for shot in sim.shots:
		var color := CYAN if shot.weapon in ["pulse", "escort"] else (Color("d8a4ff") if shot.weapon == "barrage" else AMBER)
		if shot.has("fusion"):
			color = FusionArt.PALETTES[str(shot.fusion)][0]
		var direction: Vector2 = shot.v.normalized()
		if not profile.reduced:
			draw_line(shot.p - direction * 27, shot.p, Color(color, 0.12), 8, true)
		draw_line(shot.p - direction * 17, shot.p, color, 3, true)
		draw_line(shot.p - direction * 9, shot.p, Color.WHITE, 1.4, true)
		if shot.has("fusion"):
			var tail: Vector2 = shot.p - direction * 7
			draw_polyline(PackedVector2Array([tail + direction.orthogonal()*3,shot.p + direction*3,tail - direction.orthogonal()*3]),color,1.4,true)
	for enemy in sim.enemies:
		_draw_enemy(enemy)
	_draw_player(ship, velocity)
	_draw_support()
	# Friendly effects can be bright; all live threats are composited above them.
	for effect in sim.effects:
		if effect.kind not in ["beam", "shield-break", "fusion-formed"]:
			_draw_effect(effect)
	if formation_clock > 0.0:
		_draw_fusion_formed(formation, formation_clock/1.2, 1.0-formation_clock/1.2)
	for effect in sim.effects:
		if effect.kind == "beam":
			_draw_effect(effect)
	_draw_threats()
	_draw_shield_feedback(ship)
	for bullet in sim.bullets:
		_draw_projectile(bullet)
	if host.mode == "stage_clear":
		_draw_boss_ceremony(host.stage_clear_clock)
	elif host.mode == "warp":
		_draw_warp(host.warp_clock)
	# Minimal edge framing lets the artwork breathe while bars stay readable.
	for edge in [0, 1]:
		draw_rect(Rect2(edge * 520, 0, 20, 960), Color(0.01, 0.025, 0.04, 0.18))
	draw_rect(Rect2(0, 906, 540, 54), Color(0.015, 0.03, 0.05, 0.85))
	_bar(Rect2(18, 925, 244, 6), sim.hull / sim.max_hull, CYAN)
	var shield_down: bool = sim.shield <= 0.0 and sim.max_shield > 0.0
	_bar(Rect2(278, 925, 244, 6), sim.shield / maxf(1.0, sim.max_shield), SHIELD)
	if shield_down:
		draw_string(ThemeDB.fallback_font, Vector2(278, 920), "SHIELD DOWN", HORIZONTAL_ALIGNMENT_LEFT, 244, 15, DANGER)
		for segment in range(8):
			draw_line(Vector2(278 + segment * 31, 928), Vector2(298 + segment * 31, 928), DANGER, 3, true)
	_bar(Rect2(18, 941, 504, 3), float(sim.xp) / sim.xp_needed(), AMBER)
	if host.banner_clock > 0:
		draw_string(ThemeDB.fallback_font, Vector2(28, 880), host.banner_text, HORIZONTAL_ALIGNMENT_LEFT, 480, 18, CYAN)

func _visual_theme_id() -> String:
	return ["debris", "storm", "forge", "void"][(sim.stage - 1) % 4]

func _sector(at: float) -> int:
	if sim.stage > 1:
		return sim.stage + 3
	if at < 65.0:
		return 0
	if at < 125.0:
		return 1
	if at < 190.0:
		return 2
	if at < 240.0:
		return 3
	return 4

func _draw_stage_backdrop() -> void:
	# Endless sectors reuse the authored visual ecologies rather than a flat backdrop.
	var visual_stage := ((sim.stage - 1) % 4) + 1
	var base := Color("041c32") if visual_stage == 2 else (Color("26110a") if visual_stage == 3 else Color("0d071b"))
	var high := Color("064e64") if visual_stage == 2 else (Color("632512") if visual_stage == 3 else Color("261448"))
	draw_rect(Rect2(0, 0, 540, 960), base)
	for band in range(24):
		draw_rect(Rect2(0, band * 40, 540, 42), base.lerp(high, 0.15 + 0.55 * (1.0 - absf(11.5 - band) / 12.0)))
	match visual_stage:
		2:
			# Jagged cyan plasma rivers, pale cloud masses, electric ribs.
			for i in range(10):
				var x := 35.0 + i * 58.0 + sin(visual_time * 0.45 + i) * 22.0
				draw_line(Vector2(x, -60), Vector2(x - 55, 1020), Color("116d90", 0.16), 28.0)
				for part in range(8):
					var y := fposmod(part * 161.0 + i * 91.0 + visual_time * (42 + i * 2), 1070.0) - 55.0
					var points := PackedVector2Array([Vector2(x - 16, y), Vector2(x + 12, y + 28), Vector2(x - 8, y + 53), Vector2(x + 19, y + 92)])
					draw_polyline(points, Color("87e8ff", 0.22 + i % 3 * 0.06), 2.1, true)
			for i in range(5):
				var p := Vector2(fposmod(i * 213.0, 620.0) - 40, fposmod(i * 317.0 + visual_time * 32.0, 1120.0) - 80)
				draw_circle(p, 90 + i % 3 * 32, Color("39bbf0", 0.04))
		3:
			# Furnace ceiling and molten orange trenches, moving as distinct structures.
			for edge in [-1, 1]:
				var side_x: float = 270.0 + edge * 222.0
				draw_rect(Rect2(side_x - 40, 0, 80, 960), Color("4d2116", 0.82))
				for i in range(9):
					var y := fposmod(i * 148.0 + visual_time * 72.0, 1100.0) - 80.0
					draw_rect(Rect2(side_x - 40, y, 80, 20), Color("db5926", 0.50))
					draw_circle(Vector2(side_x, y + 8), 5, Color("ffe288", 0.7))
			for lane in range(4):
				var x: float = 110.0 + lane * 105.0
				draw_line(Vector2(x, -50), Vector2(x + sin(visual_time * 0.6) * 15, 1010), Color("ff7131", 0.16), 17)
				for i in range(9):
					var y := fposmod(i * 133.0 + lane * 81.0 + visual_time * 125.0, 1060.0) - 50.0
					draw_rect(Rect2(x - 21, y, 42, 9), Color("ffb75d", 0.18))
		4:
			# A black-violet architectural void, symmetrical towers and rotating gates.
			for side in [-1, 1]:
				var x: float = 270.0 + side * 225.0
				draw_colored_polygon(PackedVector2Array([Vector2(x - 46, -50), Vector2(x + 46, -50), Vector2(x + 31, 1030), Vector2(x - 31, 1030)]), Color("23123e", 0.9))
				for i in range(10):
					var y := fposmod(i * 136.0 + visual_time * 56.0, 1100.0) - 70.0
					draw_colored_polygon(PackedVector2Array([Vector2(x, y - 25), Vector2(x + 18, y), Vector2(x, y + 25), Vector2(x - 18, y)]), Color("8753d8", 0.25))
			for gate in range(6):
				var y := fposmod(gate * 210.0 + visual_time * 65.0, 1220.0) - 170.0
				draw_arc(Vector2(270, y), 102 + gate % 3 * 14, 0.14, PI - 0.14, 34, Color("ac84ff", 0.22), 3.0)
				draw_arc(Vector2(270, y), 102 + gate % 3 * 14, PI + 0.14, TAU - 0.14, 34, Color("ac84ff", 0.22), 3.0)

func _draw_boss_ceremony(elapsed: float) -> void:
	var origin: Vector2 = sim.last_boss_position
	var progress := clampf(elapsed / 2.2, 0, 1)
	var warm := Color("ffbb55") if sim.stage in [1, 3] else Color("89dfff") if sim.stage == 2 else Color("d5a1ff")
	if not profile.reduced:
		draw_circle(origin, 155.0 * maxf(0, 1.0 - elapsed / 1.6), Color(warm, 0.28 * maxf(0, 1.0 - elapsed / 1.6)))
		for pulse in range(4):
			var t := elapsed - pulse * 0.24
			if t >= 0 and t < 1.7:
				var radius := 20.0 + t * 285.0
				draw_arc(origin, radius, 0, TAU, 72, Color(warm, (1.0 - t / 1.7) * 0.80), 5.0 - pulse * 0.55, true)
	for spark in range(18 if profile.reduced else 85):
		var angle: float = spark * 2.399963 + sin(spark * 0.54) * 0.12
		var speed: float = 75.0 + fposmod(spark * 73.0, 360.0)
		var distance: float = minf(elapsed, 2.8) * speed
		var position := origin + Vector2.from_angle(angle) * distance
		var tint := warm.lerp(Color.WHITE, fposmod(spark * 0.37, 0.6))
		var alpha: float = 0.90 * maxf(0.08, 1.0 - elapsed / 3.4)
		draw_line(position, position - Vector2.from_angle(angle) * (5 + progress * 30), Color(tint, alpha), 1.5 if profile.reduced else 3.0, true)
		if spark % 5 == 0:
			draw_circle(position, 4.0, Color(tint, alpha * 0.75))

func _draw_warp(elapsed: float) -> void:
	var progress := clampf(elapsed / 1.45, 0, 1)
	var center := Vector2(270, 470)
	var color := Color("65dfff") if sim.stage == 1 else (Color("ffb36a") if sim.stage == 2 else Color("bf83ff"))
	draw_circle(center, 125.0 * (1.0 - progress * 0.7), Color(color, 0.10 + 0.14 * progress))
	for beam in range(38 if profile.reduced else 82):
		var angle: float = beam * 2.399963
		var radial: float = (22.0 + fposmod(beam * 47.0, 210.0)) * (1.0 + progress * 3.0)
		var direction := Vector2.from_angle(angle)
		var p := center + direction * radial
		draw_line(p, p + direction * (20.0 + progress * 190.0), Color(color, 0.3 + progress * 0.6), 2.0, true)
	for ring in range(4):
		var radius := 45.0 + ring * 48.0 + progress * 140.0
		draw_arc(center, radius, 0, TAU, 68, Color(color, 0.40 * (1.0 - progress)), 2.5, true)

func _draw_environment(sector: int, drift: Vector2) -> void:
	# Procedural layers provide distinct vistas without interrupting continuous scrolling.
	match sector:
		0:
			for i in range(12):
				var p := Vector2(fposmod(i*131.7 + drift.x*0.3,620)-40,fposmod(i*199.1 + visual_time*140,1050)-45)
				draw_line(p,p+Vector2(18,66),Color(0.66,0.49,0.34,0.13),2)
		1:
			for i in range(11):
				var p := Vector2(fposmod(i*183.3 + drift.x,740)-120,fposmod(i*209.7 + visual_time*60,1200)-120)
				draw_circle(p,65+i%4*22,Color(0.15,0.85,0.74,0.045))
				draw_arc(p,78+i%3*13,0,TAU,26,Color(0.5,1.0,0.85,0.065),2)
		2:
			for i in range(8):
				var p := Vector2(fposmod(i*251.1+drift.x,650)-50,fposmod(i*177.3+visual_time*100,1150)-90)
				draw_line(p,p+Vector2(42,78),Color(0.8,0.72,1.0,0.20),5)
				draw_line(p+Vector2(42,78),p+Vector2(88,34),Color(0.8,0.72,1.0,0.16),3)
				draw_circle(p+Vector2(42,78),5,Color("b3a3ff"))
		3:
			for i in range(8):
				var x := 42+i*73+sin(visual_time*0.2+i)*12
				draw_line(Vector2(x,-40),Vector2(x+32,1000),Color(0.53,0.27,0.9,0.11),6)
				draw_arc(Vector2(270,450),160+i*17,PI*0.42,PI*1.58,24,Color(0.8,0.49,1.0,0.065),2)
		4:
			for i in range(14):
				var y := fposmod(i*93+visual_time*160,1100)-70
				draw_line(Vector2(20,y),Vector2(520,y+15),Color(1,0.48,0.21,0.12),2)
			for side in [-1,1]:
				draw_rect(Rect2(270+side*220-16,0,32,960),Color(0.40,0.21,0.12,0.22))
				for i in range(10):
					draw_circle(Vector2(270+side*220,fposmod(i*117+visual_time*95,960)),4,Color("f3ab6c"))

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
	# Each unlocked chassis now uses its own silhouette and detailed sprite.
	draw_texture_rect(SHIPS.get(sim.ship_id, SHIPS.vanguard), Rect2(-40, -45, 80, 80), false)
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
	var kind: String = enemy.kind
	if kind == "boss_module":
		_draw_boss_module(enemy)
		return
	var boss := kind.begins_with("boss")
	if kind == "boulder":
		_asteroid(p, 36, int(enemy.id), 1.0)
	elif kind == "station":
		# Old gray box with a yellow dot was placeholder art. Keep the station's
		# broad turret silhouette, but give it the same layered hull as the ships.
		draw_set_transform(p, sin(visual_time * 0.25 + enemy.phase) * 0.045)
		draw_colored_polygon(PackedVector2Array([Vector2(0,-51),Vector2(51,-33),Vector2(67,11),Vector2(43,43),Vector2(-43,43),Vector2(-67,11),Vector2(-51,-33)]), Color("10283c"))
		for side in [-1, 1]:
			draw_colored_polygon(PackedVector2Array([Vector2(side*20,-30),Vector2(side*68,-36),Vector2(side*77,2),Vector2(side*48,31),Vector2(side*24,13)]),Color("2a5064"))
			draw_colored_polygon(PackedVector2Array([Vector2(side*37,-17),Vector2(side*65,-22),Vector2(side*57,15),Vector2(side*34,8)]),Color("426f83"))
			draw_line(Vector2(side*48,-25),Vector2(side*60,11),Color("8dcbd4",0.78),2.5,true)
			draw_circle(Vector2(side*52,17),4,Color("ef9a60"))
		draw_colored_polygon(PackedVector2Array([Vector2(0,-40),Vector2(20,-17),Vector2(15,27),Vector2(0,43),Vector2(-15,27),Vector2(-20,-17)]),Color("36576c"))
		draw_rect(Rect2(-8,-57,16,42),Color("133044"))
		draw_rect(Rect2(-4,-64,8,30),Color("78aec0"))
		draw_line(Vector2(-15,27),Vector2(15,27),Color("aacbd4"),2,true)
		draw_set_transform(Vector2.ZERO)
	else:
		var size := Vector2(190,190) if boss else Vector2(66,66)
		if kind in ["sniper", "missile_bomber", "carrier", "shieldguard"]:
			size = Vector2(82,82)
		if kind in ["interceptor", "rusher"]:
			size = Vector2(52,64)
		var art_key := ("boss" if boss else (kind if SHIPS.has(kind) else ("gunship" if kind in ["missile_bomber", "carrier", "shieldguard", "minelayer", "ion_frigate", "corroder", "disruptor"] else "drone")))
		var tint := Color.WHITE
		match kind:
			"interceptor": tint = Color("66f5df")
			"rusher": tint = Color("ff938e")
			"missile_bomber": tint = Color("ffb76c")
			"carrier": tint = Color("a6e2f0")
			"shieldguard": tint = Color("b7b2ff")
			"minelayer": tint = Color("e9bd83")
			"ion_frigate": tint = Color("55d8ff")
			"corroder": tint = Color("a8ff70")
			"disruptor": tint = Color("bc8cff")
			"boss2": tint = Color("7cc4ff")
			"boss3": tint = Color("ff8f48")
			"boss4": tint = Color("cda8ff")
		var bank := sin(sim.time * (2.2 if kind == "interceptor" else 0.7) + enemy.phase) * (0.035 if boss else 0.11)
		draw_set_transform(p, bank)
		if _custom_enemy(kind):
			_draw_custom_enemy(kind)
		else:
			draw_texture_rect(SHIPS[art_key], Rect2(-size/2, size), false, tint)
		if kind == "missile_bomber":
			for side in [-1,1]:
				draw_circle(Vector2(side*32,14),9,Color("ffb057"))
				draw_line(Vector2(side*32,14),Vector2(side*32,-8),Color("ffe1a3"),3)
		if kind == "shieldguard":
			draw_arc(Vector2.ZERO,45,0,TAU,40,Color("b3a3ff"),3,true)
		if kind == "minelayer":
			draw_rect(Rect2(-22,22,44,13),Color("dc9c5e"))
			for i in range(3):
				draw_circle(Vector2((i-1)*12,28),4,Color("ffcf7c"))
		if kind == "interceptor":
			for side in [-1,1]:
				draw_line(Vector2(side*8,-15),Vector2(side*35,28),Color("76fff2"),3)
		if boss:
			_glow(Vector2(0,-18),14 + sin(visual_time*4)*2,Color(tint,0.3))
		draw_set_transform(Vector2.ZERO)
	if boss:
		draw_rect(Rect2(65,11,410,82),Color(0.03,0.035,0.05,0.86))
		_bar(Rect2(80,21,380,7),enemy.hp/enemy.max_hp,AMBER)
		draw_string(ThemeDB.fallback_font, Vector2(80,52), sim.boss_name().to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 380, 16, AMBER)
		draw_string(ThemeDB.fallback_font, Vector2(80,78), sim.boss_phase_label(), HORIZONTAL_ALIGNMENT_CENTER, 380, 13, CYAN if sim.stage == 2 else AMBER)
	elif enemy.hp < enemy.max_hp:
		_bar(Rect2(p.x-20,p.y-(44 if kind == "station" else 50),40,3),enemy.hp/enemy.max_hp,AMBER)

func _draw_boss_module(enemy: Dictionary) -> void:
	var p: Vector2 = enemy.p
	var role: String = str(enemy.role)
	var pulse: float = 0.75 + 0.25 * sin(visual_time * 5.0 + float(enemy.id))
	var tint := Color("6ce5ff") if role == "launch_bay" else (Color("ffae65") if role == "vent" else Color("bb8dff"))
	draw_set_transform(p, sin(visual_time * 0.8 + enemy.phase) * 0.05)
	if role == "launch_bay":
		draw_colored_polygon(PackedVector2Array([Vector2(0,-25), Vector2(26,-14),Vector2(33,19),Vector2(0,33),Vector2(-33,19),Vector2(-26,-14)]),Color("245479"))
		draw_rect(Rect2(-18,-13,36,23),Color("0a283d"))
		for i in range(3):
			draw_line(Vector2(-12+i*12,-11),Vector2(-12+i*12,11),Color(tint,pulse),3,true)
	elif role == "vent":
		draw_rect(Rect2(-33,-24,66,48),Color("5c2f24"))
		for i in range(4):
			draw_rect(Rect2(-23+i*12,-18,7,36),Color("ff782f",pulse))
		draw_arc(Vector2.ZERO,37,-PI,0,26,Color(tint,0.7),3,true)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(0,-45),Vector2(28,-4),Vector2(0,40),Vector2(-28,-4)]),Color("3d2368"))
		draw_colored_polygon(PackedVector2Array([Vector2(0,-32),Vector2(14,0),Vector2(0,27),Vector2(-14,0)]),Color(tint,pulse))
		draw_arc(Vector2.ZERO,34,visual_time,visual_time+PI*1.4,35,Color(tint,0.7),2,true)
	draw_set_transform(Vector2.ZERO)
	draw_arc(p, 36, 0, TAU, 42, Color(tint, 0.48), 1.7, true)
	_bar(Rect2(p.x-31,p.y+43,62,5),enemy.hp/enemy.max_hp,tint)
	# Every module is a real auto-targeted enemy, not a decorative weak point.

func _custom_enemy(kind: String) -> bool:
	return kind in ["ion_frigate", "corroder", "disruptor", "arc_spire", "storm_weaver", "forge_turret", "slag_bomber", "ember_hunter", "splitter", "phase_stalker", "void_lancer", "gravity_sentinel", "echo_carrier", "boss2", "boss3", "boss4"]

func _draw_custom_enemy(kind: String) -> void:
	# Procedural silhouettes at native size, not a color tint of one shared sprite.
	if kind == "boss2":
		draw_colored_polygon(PackedVector2Array([Vector2(-105,-4), Vector2(-58,-49), Vector2(0,-74), Vector2(58,-49), Vector2(105,-4), Vector2(67,48), Vector2(-67,48)]), Color("173e62"))
		for side in [-1,1]:
			draw_colored_polygon(PackedVector2Array([Vector2(side*43,-25),Vector2(side*118,-20),Vector2(side*96,18),Vector2(side*47,24)]),Color("309ac6"))
			draw_line(Vector2(side*44,-20),Vector2(side*100,4),Color("9deaff"),4,true)
		draw_circle(Vector2.ZERO, 27, Color("66dfff"))
		draw_circle(Vector2.ZERO, 14, Color.WHITE)
		draw_arc(Vector2.ZERO, 60 + sin(visual_time * 4) * 6, 0, TAU, 48, Color("8fe4ff",0.7),3,true)
		return
	if kind == "boss3":
		draw_rect(Rect2(-94,-78,188,146),Color("4b2618"))
		draw_rect(Rect2(-74,-64,148,124),Color("934328"))
		for side in [-1,1]:
			draw_rect(Rect2(side*96-19,-55,38,120),Color("783323"))
			for i in range(4):
				draw_line(Vector2(side*100-10,i*29-45),Vector2(side*100+12,i*29-45),Color("ffab58"),3,true)
		draw_circle(Vector2.ZERO,48,Color("2c1415"))
		draw_circle(Vector2.ZERO,34+sin(visual_time*6)*4,Color("ff6d2c"))
		draw_circle(Vector2.ZERO,19,Color("ffda83"))
		for i in range(12):
			var angle: float = i * TAU / 12
			draw_line(Vector2.from_angle(angle) * 47,Vector2.from_angle(angle)*74,Color("ff8f42"),4,true)
		return
	if kind == "boss4":
		draw_colored_polygon(PackedVector2Array([Vector2(0,-104),Vector2(79,-50),Vector2(97,41),Vector2(0,92),Vector2(-97,41),Vector2(-79,-50)]),Color("231446"))
		draw_colored_polygon(PackedVector2Array([Vector2(0,-92),Vector2(47,-22),Vector2(36,49),Vector2(0,76),Vector2(-36,49),Vector2(-47,-22)]),Color("794dbb"))
		for side in [-1,1]:
			var x: float = side * (115 + sin(visual_time*2) * 10)
			draw_colored_polygon(PackedVector2Array([Vector2(x,-52),Vector2(x+side*25,0),Vector2(x,56),Vector2(x-side*20,0)]),Color("5c3b90"))
			draw_line(Vector2(x,-48),Vector2(x,46),Color("c9a2ff"),3,true)
		draw_circle(Vector2.ZERO,20+sin(visual_time*5)*3,Color("f0b7ff"))
		draw_arc(Vector2.ZERO,86,visual_time,visual_time+PI*1.4,55,Color("d5a6ff",0.7),3,true)
		return
	if kind in ["ion_frigate", "corroder", "disruptor", "arc_spire", "storm_weaver"]:
		var color := Color("58dbff") if kind in ["ion_frigate", "storm_weaver"] else (Color("a4ff74") if kind == "corroder" else Color("bba3ff"))
		draw_colored_polygon(PackedVector2Array([Vector2(0,-37),Vector2(25,-12),Vector2(31,25),Vector2(0,39),Vector2(-31,25),Vector2(-25,-12)]),Color("123348"))
		draw_polyline(PackedVector2Array([Vector2(0,-37),Vector2(25,-12),Vector2(31,25),Vector2(0,39),Vector2(-31,25),Vector2(-25,-12),Vector2(0,-37)]),color,2.5,true)
		for side in [-1,1]:
			draw_line(Vector2(side*7,-17),Vector2(side*28,15),Color(color,0.55),3,true)
		if kind in ["arc_spire", "storm_weaver"]:
			for side in [-1,1]:
				draw_line(Vector2(side*23,-17),Vector2(side*45,-30),color,3,true)
				draw_circle(Vector2(side*44,-29),5,color)
		draw_circle(Vector2.ZERO,8+sin(visual_time*5)*2,color)
		return
	if kind in ["forge_turret", "slag_bomber", "ember_hunter", "splitter"]:
		var metal := Color("6f3422") if kind != "ember_hunter" else Color("a04426")
		draw_colored_polygon(PackedVector2Array([Vector2(0,-37),Vector2(32,-20),Vector2(30,28),Vector2(-30,28),Vector2(-32,-20)]),metal)
		for side in [-1,1]:
			draw_rect(Rect2(side*30-5,-14,10,43),Color("dc6a31"))
			draw_line(Vector2(side*27,-7),Vector2(side*15,20),Color("ffbe6b"),3,true)
		draw_circle(Vector2.ZERO,13,Color("33171a"))
		draw_circle(Vector2.ZERO,7+sin(visual_time*7)*2,Color("ffc066"))
		if kind == "splitter":
			for side in [-1,1]:
				draw_colored_polygon(PackedVector2Array([Vector2(side*16,-20),Vector2(side*41,-10),Vector2(side*41,15),Vector2(side*16,21)]),Color("d95f30"))
		return
	# Stage 4 void ships are angular, symmetric, and visibly unlike the foundry.
	var purple := Color("ad79fa") if kind != "gravity_sentinel" else Color("8cb9ff")
	draw_colored_polygon(PackedVector2Array([Vector2(0,-43),Vector2(37,-5),Vector2(0,43),Vector2(-37,-5)]),Color("1c143e"))
	draw_polyline(PackedVector2Array([Vector2(0,-43),Vector2(37,-5),Vector2(0,43),Vector2(-37,-5),Vector2(0,-43)]),purple,3,true)
	for side in [-1,1]:
		draw_colored_polygon(PackedVector2Array([Vector2(side*19,-13),Vector2(side*45,-30),Vector2(side*38,27)]),Color(purple,0.65))
	if kind in ["void_lancer", "gravity_sentinel"]:
		draw_arc(Vector2.ZERO,35,0,TAU,32,Color(purple,0.55),2,true)
	draw_circle(Vector2.ZERO,10+sin(visual_time*5)*2,Color("f2d7ff"))

func _threat_outline(points: PackedVector2Array) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_colored_polygon(points, THREAT_INK)
	draw_polyline(closed, THREAT_INK, 6.0, true)
	draw_polyline(closed, DANGER, 2.2, true)

func _draw_projectile(bullet: Dictionary) -> void:
	var p: Vector2 = bullet.p
	var kind: String = bullet.kind
	# Shape says what it does. The dark rim and coral edge always mean hostile,
	# including ion/void rounds whose inner colors also occur in friendly FX.
	if kind in ["mine", "slag"]:
		var radius := 10.0 if kind == "slag" else 8.0
		var points := PackedVector2Array([p + Vector2(0, -radius), p + Vector2(radius, 0), p + Vector2(0, radius), p + Vector2(-radius, 0)])
		_threat_outline(points)
		draw_circle(p, 3.0, AMBER)
		var fuse: float = clampf(float(bullet.fuse) / (3.2 if kind == "slag" else 3.4), 0, 1)
		draw_arc(p, radius + 5, 0, TAU, 24, THREAT_INK, 5.0, true)
		draw_arc(p, radius + 5, -PI / 2, -PI / 2 + TAU * fuse, 24, DANGER, 2.5, true)
	elif kind == "ordnance":
		var direction: Vector2 = bullet.v.normalized()
		var wing := Vector2(-direction.y, direction.x)
		draw_line(p - direction * 24, p, THREAT_INK, 7, true)
		draw_line(p - direction * 24, p, DANGER, 2, true)
		_threat_outline(PackedVector2Array([p + direction * 13, p + wing * 7 - direction * 5, p - direction * 10, p - wing * 7 - direction * 5]))
		draw_line(p - direction * 5, p + direction * 5, Color("fff0d6"), 2, true)
	elif kind == "chaff":
		draw_circle(p, 6.0, THREAT_INK)
		draw_circle(p, 3.8, DANGER)
		draw_circle(p, 1.5, Color("fff0d6"))
	else:
		var tint := DANGER
		match kind:
			"ion": tint = Color("55d8ff")
			"corrosion": tint = Color("a8ff70")
			"disrupt": tint = Color("bc8cff")
			"heat": tint = Color("ffb35d")
			"gravity": tint = Color("b887ff")
			"void": tint = Color("fa6fff")
		_threat_outline(PackedVector2Array([p + Vector2(0, -7), p + Vector2(7, 0), p + Vector2(0, 7), p + Vector2(-7, 0)]))
		draw_circle(p, 3.0, tint)
		draw_circle(p, 1.1, Color("fff0d6"))

func _draw_threats() -> void:
	for charge in sim.charges:
		var progress: float = clampf(1.0 - charge.remaining / charge.duration, 0, 1)
		# The 66px lane matches the existing 33px collision half-width exactly.
		draw_rect(Rect2(charge.x - 33, 0, 66, 900), Color(THREAT_INK, 0.20))
		draw_rect(Rect2(charge.x - 33, 0, 66, 900), Color(DANGER, 0.04 + progress * 0.10))
		for side in [-1, 1]:
			var x: float = charge.x + side * 33
			draw_line(Vector2(x, 0), Vector2(x, 900), THREAT_INK, 5, true)
			for y in range(0, 900, 30):
				draw_line(Vector2(x, y), Vector2(x, y + 12 + progress * 12), DANGER, 2, true)
		# A fixed countdown stays readable with reduced effects and overlapping FX.
		var label_x: float = clampf(charge.x - 48, 6, 428)
		draw_rect(Rect2(label_x - 5, 658, 109, 28), THREAT_INK)
		draw_string(ThemeDB.fallback_font, Vector2(label_x, 679), "BEAM %.1fs" % charge.remaining, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, DANGER)

func _draw_shield_feedback(ship: Vector2) -> void:
	# Presentation uses real time so the break remains visible even at 3x speed.
	var age := 1.0 - shield_break_clock / 0.75 if shield_break_clock > 0.0 else -1.0
	var down: bool = sim.shield <= 0.0 and sim.max_shield > 0.0
	if age < 0.0 and not down:
		return
	# Short broken arcs, rather than a full-screen flash. Follow the ship.
	var burst := maxf(0.0, age)
	var radius := 43.0 + (0.0 if profile.reduced else burst * 18.0)
	var tint := SHIELD.lerp(DANGER, minf(1.0, burst * 3.0)) if age >= 0.0 else DANGER
	var alpha := 1.0 - burst * 0.45 if age >= 0.0 else 0.55
	for segment in range(6):
		var start: float = segment * TAU / 6 + 0.12
		var end: float = start + (0.53 if age >= 0.0 else 0.30)
		draw_arc(ship, radius, start, end, 10, Color(THREAT_INK, alpha), 6, true)
		draw_arc(ship, radius, start, end, 10, Color(tint, alpha), 2.8, true)

func _draw_effect(effect: Dictionary) -> void:
	var alpha: float = effect.life / effect.max_life
	var age := 1.0 - alpha
	var p: Vector2 = effect.p
	if effect.kind in ["ion-burst","ion_mine"]:
		var radius: float = float(effect.get("radius",60.0))*age
		for i in range(6):
			var angle: float = i*TAU/6
			draw_arc(p,radius,angle,angle+TAU/9,20,Color("bba5ef",alpha),2.5,true)
			var point := p+Vector2.from_angle(angle)*radius*0.75
			draw_circle(point,2,Color(CYAN,alpha))
	elif effect.kind == "wing_drones":
		for side in [-1,1]:
			draw_arc(p+Vector2(side*46,8),18+age*24,-PI,0,24,Color(CYAN,alpha),2,true)
	elif effect.kind == "fusion-cast":
		_draw_fusion_cast(effect, alpha, age)
	elif effect.kind == "fusion-formed":
		_draw_fusion_formed(effect, alpha, age)
	elif effect.kind in ["arc", "lance"]:
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
	elif effect.kind == "phase":
		draw_arc(p, 10 + age * 65, 0, TAU, 42, Color("d8a4ff", alpha * 0.8), 4, true)
		draw_circle(p, 7 + age * 23, Color("b784ff", alpha * 0.12))
	elif effect.kind == "nova":
		var radius := age * 790
		if not profile.reduced:
			draw_arc(p, radius, 0, TAU, 100, Color(0.2, 0.9, 1, alpha * 0.08), 65, true)
		draw_arc(p, radius, 0, TAU, 100, Color(0.4, 1, 0.9, alpha), 5, true)
		draw_arc(p, radius * 0.83, 0, TAU, 90, Color(0.8, 1, 1, alpha * 0.4), 2, true)
	elif effect.kind == "beam":
		draw_line(p, p + Vector2(0, 920), Color(THREAT_INK, alpha), 70, true)
		if not profile.reduced:
			draw_line(p, p + Vector2(0, 920), Color(DANGER, alpha * 0.12), 72, true)
		draw_line(p, p + Vector2(0, 920), Color(DANGER, alpha * 0.8), 64, true)
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

func _draw_fusion_formed(effect: Dictionary, alpha: float, age: float) -> void:
	var id: String = effect.fusion
	var colors: Array = FusionArt.PALETTES[id]
	var p: Vector2 = effect.p + Vector2(0, -100)
	p.x = clampf(p.x, 115, 425)
	var fade := minf(1.0, alpha * 3.0)
	var converge := clampf(age / 0.4, 0.0, 1.0)
	var offset := 55.0 * pow(1.0 - converge, 2)
	for side in [-1,1]:
		var node := p + Vector2(side * offset, 0)
		FusionArt.outline(self,FusionArt.polygon(node,22 + converge*5),Color(colors[0 if side<0 else 1],fade*(1.0-converge)),2)
	if not profile.reduced:
		draw_arc(p,30 + age*38,0,TAU,48,Color(colors[0],alpha*0.28),2,true)
	draw_set_transform(p,0,Vector2.ONE*(1.2 + minf(0.2,converge*0.2)))
	FusionArt.badge(self,id,fade)
	draw_set_transform(Vector2.ZERO)
	draw_string(ThemeDB.fallback_font,p+Vector2(-110,48),str(sim.fusion_spec(id).name),HORIZONTAL_ALIGNMENT_CENTER,220,20,Color("edf5ff",fade))

func _draw_fusion_cast(effect: Dictionary, alpha: float, age: float) -> void:
	var id: String = effect.fusion
	var colors: Array = FusionArt.PALETTES[id]
	var a := Color(colors[0],alpha)
	var b := Color(colors[1],alpha)
	var white := Color("edf8ff",alpha*0.85)
	var p: Vector2 = effect.p
	if id in ["nova_aegis","repair_matrix","reflective_wall","ghost_signal"]:
		p = sim.ship_position()
	var spread := 1.0 - pow(1.0-age,3)
	var count := 6 if profile.reduced else 12
	match id:
		"storm_carrier":
			for i in range(4):
				var node: Vector2 = sim.escort_position(i)
				draw_line(p,node,Color(a,alpha*0.5),1.6,true)
				FusionArt.outline(self,FusionArt.polygon(node,18+age*16,4),b,1.8)
			FusionArt.outline(self,FusionArt.polygon(p+Vector2(0,-45),22,4),a,2)
		"nova_aegis":
			var r := 48.0 + spread * (210.0 if effect.get("counter",false) else 140.0)
			FusionArt.outline(self,FusionArt.polygon(p,54),a,2.5)
			for i in range(count):
				var angle: float = i*TAU/count
				draw_arc(p,r,angle,angle+TAU/count*0.7,10,a,3,true)
				draw_line(p+Vector2.from_angle(angle)*r,p+Vector2.from_angle(angle)*(r+13),b,2,true)
			if not profile.reduced: draw_arc(p,r*0.87,0,TAU,64,Color(a,alpha*0.22),7,true)
		"railstorm":
			var targets: Array = effect.get("targets",[])
			for i in range(3):
				var origin := p+Vector2((i-1)*18,-28)
				var target: Vector2 = targets[i] if i < targets.size() else p+Vector2((i-1)*58,-350)
				if not profile.reduced: draw_line(origin,target,Color(a,alpha*0.12),14,true)
				draw_line(origin,target,a,3.2,true)
				draw_line(origin,target,white,1.2,true)
				var v := (target-origin).normalized()
				var point := origin.lerp(target,minf(1.0,age*2.4))
				draw_line(point-v*20,point,b,5,true)
				draw_arc(target,6+spread*18,0,TAU,24,b,1.6,true)
		"stasis_lock":
			var r := 65.0+spread*110
			for ring in [0.75,1.0]:
				draw_arc(p,r*ring,0,TAU,64,Color(a,alpha*0.6),1.8,true)
			for i in range(count):
				var v := Vector2.from_angle(i*TAU/count)
				draw_line(p+v*(r-9),p+v*r,b,2.5,true)
			for x in [-1,1]:
				for y in [-1,1]:
					var corner := p+Vector2(x,y)*r*0.56
					draw_polyline(PackedVector2Array([corner-Vector2(x*14,0),corner,corner-Vector2(0,y*14)]),white,2,true)
		"repair_matrix":
			var r := 48.0+sin(age*PI)*15
			FusionArt.outline(self,FusionArt.polygon(p,44),Color(a,alpha*0.5),1.4)
			for i in range(4):
				var angle: float = PI/4+i*TAU/4+(0.0 if profile.reduced else age*0.35)
				var node := p+Vector2.from_angle(angle)*r
				draw_line(node,p,Color(a,alpha*0.5),1.5,true)
				FusionArt.outline(self,FusionArt.polygon(node,9,4),b,1.5)
				draw_rect(Rect2(node+Vector2(-1.5,-5),Vector2(3,10)),white)
				draw_rect(Rect2(node+Vector2(-5,-1.5),Vector2(10,3)),white)
		"missile_grid":
			for side in [-1,1]:
				FusionArt.outline(self,FusionArt.polygon(p+Vector2(side*35,-12),12),b,2)
			for i in range(7):
				var v := Vector2.from_angle(-PI/2+(i-3)*0.17)
				var point := p+v*(35+spread*150)
				draw_line(point-v*30,point,Color(a,alpha*0.65),2,true)
				draw_polyline(PackedVector2Array([point-v*9+v.orthogonal()*4,point,point-v*9-v.orthogonal()*4]),white,2,true)
		"scrap_converter":
			for target in effect.get("targets",[]):
				draw_line(p,target,Color(b,alpha*0.4),1.5,true)
				for i in range(5):
					var shard: Vector2 = target.lerp(p,fposmod(age*1.5+i*0.17,1.0))
					draw_colored_polygon(FusionArt.polygon(shard,3+i%2,4),a if i%2==0 else b)
			for i in range(3):
				var angle: float = i*TAU/3 + (0 if profile.reduced else age)
				draw_arc(p,85-spread*40,angle,angle+1.4,16,b,2.5,true)
		"prism_focus":
			var center := p+Vector2(0,-40)
			var crystal := PackedVector2Array([center+Vector2(0,-38),center+Vector2(26,0),center+Vector2(0,32),center+Vector2(-26,0)])
			if not profile.reduced: draw_colored_polygon(crystal,Color(a,alpha*0.12))
			FusionArt.outline(self,crystal,b,2.2)
			draw_line(crystal[0],crystal[2],white,1.7,true)
			draw_line(crystal[1],crystal[3],a,1.5,true)
			for i in [-1,0,1]:
				var v := Vector2.from_angle(-PI/2+i*0.33)
				draw_line(center+v*40,center+v*(90+spread*120),a if i==0 else b,2,true)
		"reflective_wall":
			for i in range(5):
				var v := Vector2.from_angle(-PI/2+(i-2)*0.39)
				var tile := FusionArt.polygon(p+v*62,16)
				if not profile.reduced: draw_colored_polygon(tile,Color(a,alpha*0.1))
				FusionArt.outline(self,tile,a,2)
				draw_line(p+v*(85+spread*22),p+v*(98+spread*40),b,2,true)
		"ghost_signal":
			for side in [-1,1]:
				var echo := p+Vector2(side*(30+spread*65),10)
				var hull := PackedVector2Array([echo+Vector2(0,-25),echo+Vector2(12,8),echo+Vector2(26,22),echo+Vector2(0,14),echo+Vector2(-26,22),echo+Vector2(-12,8)])
				FusionArt.outline(self,hull,Color(a,alpha*0.7),1.6)
				for ring in [70.0,100.0]: draw_arc(p,ring+spread*30,(-0.55 if side==1 else PI-0.55),(0.55 if side==1 else PI+0.55),20,b,1.6,true)
		"reactor_surge":
			var r := 42.0+spread*105
			FusionArt.outline(self,FusionArt.polygon(p,32+spread*12),b,2.4)
			for i in range(count):
				var v := Vector2.from_angle(i*TAU/count)
				var side := v.orthogonal()
				var bolt := PackedVector2Array([p+v*38,p+v*(r*0.65)+side*9,p+v*(r*0.78)-side*5,p+v*r])
				draw_polyline(bolt,a,2,true)
				draw_circle(p+v*r,2,white)

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

func _draw_support() -> void:
	if sim.escort_left > 0.0:
		for i in range(sim.escort_count):
			var p: Vector2 = sim.escort_position(i)
			var hull := PackedVector2Array([p+Vector2(0,-14),p+Vector2(10,9),p+Vector2(3,5),p+Vector2(0,10),p+Vector2(-3,5),p+Vector2(-10,9)])
			draw_colored_polygon(hull,Color("244450"))
			FusionArt.outline(self,hull,Color("a9d8e1"),1.4)
			draw_line(p+Vector2(0,-7),p+Vector2(0,3),CYAN,2.2,true)
			draw_line(p+Vector2(0,10),p+Vector2(0,19),Color("badcf4"),2,true)
	for mine in sim.ion_mines:
		var p: Vector2 = mine.p
		var progress: float = clampf(1.0-mine.fuse/1.8,0.0,1.0)
		FusionArt.outline(self,FusionArt.polygon(p,12,4),Color("c3a8f3"),2)
		draw_circle(p,3,CYAN)
		draw_arc(p,19,-PI/2,-PI/2+TAU*progress,32,CYAN,1.5,true)
		for i in range(4):
			var v := Vector2.from_angle(i*TAU/4)
			draw_line(p+v*13,p+v*18,Color("c3a8f3"),1.5,true)
