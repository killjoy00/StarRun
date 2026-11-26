extends Node2D
## Material ship art, parallax debris, banking and layered combat VFX.
const FirstFlight = preload("res://scripts/first_flight.gd")
const HiddenSector = preload("res://scripts/hidden_sector.gd")
const ArchiveIllustration = preload("res://scripts/archive_illustration.gd")
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
	"lancer": preload("res://assets/art/lancer.webp"),
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
# Charge cancellation cues use real screen time; sim time can run at 3x.
var beam_cancel_feedback: Array = []
var seen_beam_cancel_ids := {}
var seen_beam_cancel_order: Array = []
# Formation interruptions must remain readable at 3x game speed: cache
# once and hold the feedback in real presentation seconds.
var elite_break_feedback: Array = []
var seen_elite_break_ids := {}
var seen_elite_break_order: Array = []
# Brief real-time spectacle cues remain visible at 3x, independently of
# fixed-step simulation; these never cover enemy projectiles or hitboxes.
var spectacle_feedback: Array = []
var seen_spectacle_ids := {}
var seen_spectacle_order: Array = []

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
		beam_cancel_feedback.clear()
		seen_beam_cancel_ids.clear()
		seen_beam_cancel_order.clear()
		elite_break_feedback.clear()
		seen_elite_break_ids.clear()
		seen_elite_break_order.clear()
		spectacle_feedback.clear()
		seen_spectacle_ids.clear()
		seen_spectacle_order.clear()
	if host.mode == "playing":
		shield_break_clock = maxf(0.0, shield_break_clock - delta)
		formation_clock = maxf(0.0, formation_clock - delta)
		for feedback in beam_cancel_feedback:
			feedback.remaining = float(feedback.remaining) - delta
		beam_cancel_feedback = beam_cancel_feedback.filter(func(fx): return float(fx.remaining) > 0.0)
		for feedback in elite_break_feedback:
			feedback.remaining = float(feedback.remaining) - delta
		elite_break_feedback = elite_break_feedback.filter(func(fx): return float(fx.remaining) > 0.0)
	if host.mode in ["playing", "stage_clear", "warp"]:
		for cue in spectacle_feedback:
			cue.remaining = float(cue.remaining) - delta
		spectacle_feedback = spectacle_feedback.filter(func(fx): return float(fx.remaining) > 0.0)
	for effect in host.sim.effects:
		if effect.kind == "beam-canceled":
			var cue_id := "%d:%d:%d" % [int(effect.born), int(effect.source), roundi(float(effect.x))]
			if not seen_beam_cancel_ids.has(cue_id):
				seen_beam_cancel_ids[cue_id] = true
				seen_beam_cancel_order.append(cue_id)
				if seen_beam_cancel_order.size() > 128:
					seen_beam_cancel_ids.erase(seen_beam_cancel_order.pop_front())
				beam_cancel_feedback.append({"p":effect.p, "x":float(effect.x), "remaining":0.85, "duration":0.85})
		if effect.kind == "elite-broken":
			var elite_key := "%d:%d" % [int(effect.born), int(effect.get("source",-1))]
			if not seen_elite_break_ids.has(elite_key):
				seen_elite_break_ids[elite_key] = true
				seen_elite_break_order.append(elite_key)
				if seen_elite_break_order.size() > 64:
					seen_elite_break_ids.erase(seen_elite_break_order.pop_front())
				elite_break_feedback.append({"p":effect.p, "remaining":1.05, "duration":1.05})
		if effect.kind in ["mutation-installed", "mutation-proc", "boss-module-break", "boss-phase-break", "engine-online", "engine-proc", "evolution-proc", "custodian-shield", "archive-feedback"]:
			var key := "%s:%d:%d:%d:%s:%s:%s" % [str(effect.kind), int(effect.born), roundi(float(effect.p.x)), roundi(float(effect.p.y)), str(effect.get("mutation", "")), str(effect.get("role", "")), str(effect.get("evolution", ""))]
			if effect.kind == "custodian-shield":
				key += ":" + str(effect.get("ability",""))
			if not seen_spectacle_ids.has(key):
				seen_spectacle_ids[key] = true
				seen_spectacle_order.append(key)
				if seen_spectacle_order.size() > 96:
					seen_spectacle_ids.erase(seen_spectacle_order.pop_front())
				var duration := 1.00 if effect.kind in ["boss-phase-break","custodian-shield","archive-feedback"] else (0.85 if effect.kind in ["mutation-installed", "engine-online"] else (0.72 if effect.kind == "evolution-proc" else (0.68 if effect.kind == "boss-module-break" else 0.53)))
				spectacle_feedback.append({"kind":effect.kind, "p":effect.p, "mutation":str(effect.get("mutation","")), "role":str(effect.get("role","")), "engine":str(effect.get("engine","")), "evolution":str(effect.get("evolution","")), "phase":int(effect.get("phase",0)), "amount":float(effect.get("amount",0.0)), "remaining":duration, "duration":duration})
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
	var visual_stage: int = ((int(sim.stage) - 1) % 4) + 1
	if sim.secret_entered:
		_draw_archive_backdrop()
	elif visual_stage == 1:
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
	if not sim.secret_entered:
		_draw_environment(sector, drift)
	# Three depths of moving starlight sell forward flight without steering the player.
	for i in range(90):
		var depth := 0.35 + (i % 4) * 0.24
		var p := Vector2(fposmod(i * 137.51 + drift.x * depth, 540), fposmod(i * 97.13 + visual_time * (85 + depth * 180), 960))
		var color := Color(0.82, 0.86, 1.0, 0.16 + depth * 0.25) if sector != 4 else Color(1.0, 0.76, 0.45, 0.16 + depth * 0.25)
		draw_line(p, p + Vector2(-velocity.x * 0.025, 5.0 + depth * 11), color, 1)
	for i in range(0 if sim.secret_entered else (9 if visual_stage == 1 else (3 if visual_stage == 2 else 0))):
		var depth := 0.35 + (i % 3) * 0.3
		var p := Vector2(fposmod(i * 173.7 + 35 + drift.x * depth, 600) - 30, fposmod(i * 231.2 + visual_time * (95 + depth * 110), 1120) - 80)
		_asteroid(p, 10 + (i % 3) * 13, i, depth)
	if not sim.secret_entered and not profile.reduced:
		_draw_distant_battle(visual_stage)
	# Exact two-second preview remains fair on curved flight paths.
	for i in range(2, 25):
		var p: Vector2 = sim.ship_position(sim.time + i / 12.0)
		draw_circle(p, 1.7, Color(0.4, 0.95, 0.85, (24 - i) / 90.0))
	for shot in sim.shots:
		var color := CYAN if shot.weapon in ["pulse", "escort", "engine_hijacker"] else (Color("d8a4ff") if shot.weapon == "barrage" else AMBER)
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
	var crashing: bool = host.mode == "intro_crash"
	if not crashing or host.intro_end_clock < FirstFlight.IMPACT_AT:
		_draw_player(ship, velocity)
	if sim.intro_run and sim.time < 2.1 and not profile.reduced:
		_draw_first_flight_launch(ship)
	_draw_support()
	_draw_hijacked_ships()
	# Friendly effects can be bright; all live threats are composited above them.
	for effect in sim.effects:
		if effect.kind not in ["beam", "shield-break", "fusion-formed", "beam-canceled", "elite-broken", "mutation-installed", "mutation-proc", "boss-module-break", "boss-phase-break", "engine-online", "engine-proc", "evolution-proc", "custodian-shield", "archive-feedback"]:
			_draw_effect(effect)
	_draw_spectacle_feedback()
	if formation_clock > 0.0:
		_draw_fusion_formed(formation, formation_clock/1.2, 1.0-formation_clock/1.2)
	for effect in sim.effects:
		if effect.kind == "beam":
			_draw_effect(effect)
	_draw_threats()
	if not sim.archive_attack.is_empty():
		_draw_archive_threat()
	_draw_beam_cancel_feedback()
	_draw_elite_break_feedback()
	_draw_shield_feedback(ship)
	for bullet in sim.bullets:
		_draw_projectile(bullet)
	if host.mode == "stage_clear":
		_draw_boss_ceremony(host.stage_clear_clock)
	elif host.mode == "intro_clear" and not profile.reduced:
		_draw_boss_ceremony(host.intro_end_clock)
	elif crashing:
		_draw_first_flight_crash(ship, host.intro_end_clock)
	elif host.mode == "warp":
		_draw_warp(host.warp_clock)
	if not crashing:
		_draw_boss_panel()
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
	if not sim.intro_run:
		_bar(Rect2(18, 941, 504, 3), float(sim.xp) / sim.xp_needed(), AMBER)
	if host.banner_clock > 0:
		draw_string(ThemeDB.fallback_font, Vector2(28, 880), host.banner_text, HORIZONTAL_ALIGNMENT_LEFT, 480, 18, CYAN)

func _draw_first_flight_crash(ship: Vector2, elapsed: float) -> void:
	var core: Dictionary = sim._boss_core()
	var gun: Vector2 = core.get("p", Vector2(270, 135)) + Vector2(0, 27)
	var after_impact := elapsed - FirstFlight.IMPACT_AT
	if after_impact < 0.0:
		draw_line(gun, ship, Color(AMBER, 0.62), 2.0, true)
		draw_arc(gun, 22.0, 0.0, TAU, 32, AMBER, 2.0, true)
		return
	if not profile.reduced:
		if after_impact < 0.22:
			var intensity := 1.0 - after_impact / 0.22
			draw_line(gun, ship, Color(AMBER, 0.35 * intensity), 48.0, true)
			draw_line(gun, ship, Color(AMBER, intensity), 16.0, true)
			draw_line(gun, ship, Color(Color.WHITE, intensity), 5.0, true)
		var glow := maxf(0.0, 1.0 - after_impact / 1.15)
		draw_arc(ship, 24.0 + after_impact * 155.0, 0.0, TAU, 48, Color(AMBER, glow), 3.0, true)
		for i in range(28):
			var direction := Vector2.from_angle(i * 2.39996)
			var debris := ship + direction * (16.0 + after_impact * (56.0 + float(i % 7) * 19.0))
			draw_line(debris, debris - direction * 11.0, Color(AMBER, glow), 2.0, true)
	var side := 1.0 if ship.x < 270.0 else -1.0
	var direction := Vector2(side, -0.45).normalized()
	var distance := 38.0 if profile.reduced else 24.0 + after_impact * 108.0
	var pod := ship + direction * distance
	if not profile.reduced:
		draw_line(pod, pod - direction * 42.0, Color(CYAN, 0.6), 3.0, true)
	draw_set_transform(pod, direction.angle(), Vector2.ONE * 1.25)
	draw_colored_polygon(PackedVector2Array([Vector2(14, 0), Vector2(3, -8), Vector2(-11, -6),
		Vector2(-11, 6), Vector2(3, 8)]), Color("eafcff"))
	draw_circle(Vector2(3, 0), 4.0, Color("29657d"))
	draw_set_transform(Vector2.ZERO)

func _draw_first_flight_launch(ship: Vector2) -> void:
	# A brief thrust flare uses the live ship position and fades into normal flight.
	var progress := clampf(sim.time / 2.1, 0.0, 1.0)
	var power := sin(progress * PI) * (1.0 - progress)
	for side in [-1.0, 1.0]:
		var engine_mount := ship + Vector2(side * 15, 27)
		draw_colored_polygon(PackedVector2Array([
			engine_mount + Vector2(-7, 0),
			engine_mount + Vector2(7, 0),
			engine_mount + Vector2(side * 16, 110.0 * power + 24.0),
		]), Color(CYAN, 0.25 * power))
		draw_line(engine_mount, engine_mount + Vector2(side * 8, 94.0 * power + 16.0), Color(CYAN, power), 2.0, true)
	for i in range(12):
		var x := fposmod(i * 57.7, 540.0)
		var y := fposmod(i * 137.0 + sim.time * 730.0, 960.0)
		draw_line(Vector2(x, y), Vector2(x, y + 42.0), Color(CYAN, power * 0.65), 1.5, true)

## The boss health bar, name and phase line sit above every lane and shot.
## Beam lanes used to be drawn over it and could cover the phase text.
func _draw_boss_panel() -> void:
	for enemy in sim.enemies:
		var kind: String = str(enemy.kind)
		if not kind.begins_with("boss") or kind == "boss_module":
			continue
		draw_rect(Rect2(40,11,460,86),Color(0.03,0.035,0.05,0.92))
		_bar(Rect2(60,21,420,7),enemy.hp/enemy.max_hp,AMBER)
		draw_string(ThemeDB.fallback_font, Vector2(60,52), sim.boss_name().to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 420, 17, AMBER)
		var phase_label: String = sim.boss_phase_label()
		if kind in ["boss3", "boss4"]:
			phase_label = "PHASE %d/3 · %s" % [sim.late_boss_phase + 1, phase_label]
		var phase_color: Color = ArchiveIllustration.phase_tint(sim.archive_phase) if kind == HiddenSector.BOSS and sim.archive_boss_reworked() else (CYAN if sim.stage == 2 else AMBER)
		draw_string(ThemeDB.fallback_font, Vector2(60,80), phase_label, HORIZONTAL_ALIGNMENT_CENTER, 420, 15, phase_color)
		return

func _visual_theme_id() -> String:
	return ["debris", "storm", "forge", "void"][(sim.stage - 1) % 4]

func _sector(at: float) -> int:
	var visual_stage: int = ((int(sim.stage) - 1) % 4) + 1
	if visual_stage > 1:
		return visual_stage + 3
	var elapsed: float = at - float(sim.stage_start)
	if elapsed < 65.0:
		return 0
	if elapsed < 125.0:
		return 1
	if elapsed < 190.0:
		return 2
	if elapsed < 240.0:
		return 3
	return 4

func _draw_archive_backdrop() -> void:
	draw_rect(Rect2(0, 0, 540, 960), Color("071719"))
	for side in [-1, 1]:
		var x: float = 270.0 + side * 213.0
		draw_rect(Rect2(x - 37.0, 0, 74.0, 960), Color("142b2d"))
		draw_line(Vector2(x - side * 30.0, 0), Vector2(x - side * 30.0, 960), Color(HiddenSector.COLOR, 0.27), 2)
		for i in range(13):
			var y := fposmod(i * 96.0 + visual_time * 65.0, 1040.0) - 40.0
			ArchiveIllustration.shape(self, PackedVector2Array([Vector2(-19,-24), Vector2(19,-24), Vector2(28,0), Vector2(19,24), Vector2(-19,24), Vector2(-28,0)]), Vector2(x,y), Color("1c3736"), Color(HiddenSector.MINT, 0.27))
	for i in range(7):
		var y := fposmod(i * 168.0 + visual_time * 58.0, 1180.0) - 100.0
		var center := Vector2(270, y)
		for side in [-1, 1]:
			var a: float = PI * 0.5 if side == -1 else -PI * 0.5
			draw_arc(center, 135.0, a + 0.23, a + PI - 0.23, 32, Color(HiddenSector.COLOR, 0.17), 2.0, true)
		draw_line(Vector2(265, y), Vector2(275, y), Color(HiddenSector.MINT, 0.33), 2.0, true)

func _draw_archive_threat() -> void:
	var x: float = sim.archive_attack_x
	var attack: String = sim.archive_attack
	var phase: float = clampf((sim.archive_attack_until - sim.time) / 3.6, 0.0, 1.0)
	var tint: Color = ArchiveIllustration.phase_tint(sim.archive_phase) if sim.archive_boss_reworked() and sim.boss_spawned else DANGER
	# Keep the danger lane coral; use phase-specific shapes on top of the original telegraph.
	if sim.archive_boss_reworked() and sim.boss_spawned:
		var core: Dictionary = sim._boss_core()
		if not core.is_empty():
			var radius: float = 91.0 + 20.0 * (1.0 - phase)
			var spin: float = 0.0 if profile.reduced else visual_time * 0.7
			for i in range(sim.archive_phase + 2):
				var a: float = TAU * float(i) / float(sim.archive_phase + 2) + spin
				draw_arc(core.p, radius, a, a + 0.65, 18, Color(tint,0.78), 3.0, true)
			if sim.archive_phase == 0:
				for e in sim.enemies:
					if str(e.get("role","")) == "archive_emitter" and float(e.hp) > 0:
						draw_line(core.p, e.p, Color(tint,0.55), 2.0, true)
			elif sim.archive_phase == 1:
				for side in [-1,1]:
					draw_line(core.p + Vector2(side*115.0,18.0),Vector2(x-side*90.0,730.0),Color(tint,0.48),2.0,true)
			else:
				draw_arc(core.p,radius+13.0,0,TAU,48,Color(tint,0.40),3.0,true)
	if attack != "lattice":
		draw_rect(Rect2(x - 38.0, 97.0, 76.0, 803.0), Color(DANGER, 0.14 + 0.13 * (1.0 - phase)))
		for side in [-1, 1]:
			var edge: float = x + side * 38.0
			for y in range(100, 900, 27):
				draw_line(Vector2(edge, y), Vector2(edge, y + 16), DANGER, 2, true)
	if attack != "lock":
		var core: Dictionary = sim._boss_core()
		if not core.is_empty():
			for side in [-1, 1]:
				var source: Vector2 = core.p + Vector2(side * 115.0, 18.0)
				draw_arc(source, 13 + 17 * phase, 0, TAU, 24, DANGER, 3.0, true)
				draw_line(source, Vector2(x, 730), Color(DANGER, 0.50), 2, true)

func _draw_archive_enemy(enemy: Dictionary) -> void:
	var p: Vector2 = enemy.p
	var kind: String = enemy.kind
	var accent := HiddenSector.COLOR if kind == "archive_courier" else HiddenSector.MINT
	var radius := 35.0 if kind != "archive_shard" else 21.0
	var shape := PackedVector2Array([Vector2(0,-radius), Vector2(radius * 0.8, radius * 0.17), Vector2(radius * 0.48, radius * 0.67), Vector2(0, radius), Vector2(-radius * 0.48, radius * 0.67), Vector2(-radius * 0.8, radius * 0.17)])
	ArchiveIllustration.shape(self, shape, p, Color("294a44"), accent)
	draw_circle(p, 4.0, accent)
	if kind == "archive_courier":
		draw_arc(p, radius + 7, 0, TAU, 32, accent, 2.5, true)
	elif kind == "archive_relay":
		for escort in sim.enemies:
			if int(escort.get("archive_relay", -1)) == int(enemy.id):
				draw_line(p, escort.p, Color(accent, 0.44), 2.0, true)

func _draw_stage_backdrop() -> void:
	# Endless sectors reuse the authored visual ecologies rather than a flat backdrop.
	var visual_stage: int = ((int(sim.stage) - 1) % 4) + 1
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

## A distant skirmish behind the playfield: small, dim allied and hostile
## craft trade tracer fire and some are shot down. Purely cosmetic: it uses
## visual time only (no simulation state or RNG), is never targetable, avoids
## the coral threat colour, and is off with Calmer visuals.
func _draw_distant_battle(visual_stage: int) -> void:
	var lanes := 8 if visual_stage == 1 else 6
	var ally := Color(0.45, 0.90, 0.86)
	var hostile := Color(0.70, 0.64, 0.92)
	var positions: Array = []
	for i in range(lanes):
		var period := 8.0 + fposmod(i * 3.7, 6.0)
		var clock := visual_time + i * 2.3
		var cycle := floori(clock / period)
		var t := fposmod(clock, period) / period
		var left_to_right := (i + cycle) % 2 == 0
		var y0 := 110.0 + fposmod(i * 83.0 + cycle * 47.0, 520.0)
		var start := Vector2(-40.0 if left_to_right else 580.0, y0)
		var finish := Vector2(580.0 if left_to_right else -40.0, y0 + (60.0 if i % 2 == 0 else -45.0))
		var p := start.lerp(finish, t) + Vector2(0.0, sin(clock * 1.7 + i) * 9.0)
		var is_ally := i % 2 == 0
		var downed := not is_ally and cycle % 3 == 0 and t > 0.62
		positions.append({"p": p, "ally": is_ally, "alive": not downed})
		if downed:
			# A brief distant burst, then nothing until the next pass.
			var burst := (t - 0.62) / 0.12
			if burst < 1.0:
				draw_arc(p, 4.0 + burst * 16.0, 0, TAU, 18, Color(1.0, 0.82, 0.55, 0.35 * (1.0 - burst)), 1.5, true)
				draw_circle(p, 3.0 * (1.0 - burst), Color(1.0, 0.9, 0.7, 0.4 * (1.0 - burst)))
			continue
		var heading := (finish - start).normalized()
		var side := heading.orthogonal()
		var size := 5.0 + (i % 3)
		var color := Color(ally if is_ally else hostile, 0.30)
		draw_colored_polygon(PackedVector2Array([p + heading * size, p - heading * size + side * size * 0.7, p - heading * size * 0.5, p - heading * size - side * size * 0.7]), color)
		draw_line(p - heading * size, p - heading * (size + 7.0), Color(color, 0.18), 2.0, true)
	# Allies trade short tracer bursts with the nearest hostile.
	for i in range(0, positions.size() - 1, 2):
		var a: Dictionary = positions[i]
		var b: Dictionary = positions[i + 1]
		if not a.alive or not b.alive or fposmod(visual_time * 1.6 + i, 1.0) > 0.35:
			continue
		var from: Vector2 = a.p
		var to: Vector2 = b.p
		if from.distance_to(to) > 360.0:
			continue
		var along := fposmod(visual_time * 3.0 + i * 0.37, 1.0)
		draw_line(from.lerp(to, along), from.lerp(to, minf(1.0, along + 0.12)), Color(1.0, 0.86, 0.6, 0.22), 1.2, true)

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
	if not profile.reduced and not kind.begins_with("boss") and kind not in ["boss_module", "boulder", "station"] and not HiddenSector.ENEMIES.has(kind):
		_draw_enemy_exhaust(enemy)
	if kind == "boss_module":
		_draw_boss_module(enemy)
		_draw_evolution_marks(enemy)
		return
	var boss := kind.begins_with("boss")
	if kind == HiddenSector.BOSS:
		draw_set_transform(p)
		ArchiveIllustration.custodian(self, visual_time if not profile.reduced else 0.0, sim.time < sim.archive_exposed_until, sim.archive_phase if sim.archive_boss_reworked() else -1)
		draw_set_transform(Vector2.ZERO)
	elif HiddenSector.ENEMIES.has(kind):
		_draw_archive_enemy(enemy)
	elif kind == "boulder":
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
		var size := Vector2(190,190) if boss else (Vector2(98,98) if bool(enemy.get("rival",false)) else Vector2(66,66))
		if kind in ["sniper", "missile_bomber", "carrier", "shieldguard"]:
			size = Vector2(82,82)
		if kind in ["interceptor", "rusher"]:
			size = Vector2(52,64)
		var art_key := ("boss" if boss else (kind if SHIPS.has(kind) else ("gunship" if kind in ["missile_bomber", "carrier", "shieldguard", "minelayer", "ion_frigate", "corroder", "disruptor"] else "drone")))
		var tint := Color("ff9a86") if bool(enemy.get("rival",false)) else Color.WHITE
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
		# Swarm-pack members are smaller ships flying as one formation.
		var art_scale := 0.72 if enemy.has("pack_id") else 1.0
		draw_set_transform(p, bank, Vector2(art_scale, art_scale))
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
			# Real module shields remain readable even with reduced effects.
			# The player's guns prioritize the visibly glowing weak points.
			if kind in ["boss3", "boss4"] and sim._alive_modules("vent" if kind == "boss3" else "pylon") > 0:
				var shield_color := Color("ffb065") if kind == "boss3" else Color("b8a0ff")
				draw_arc(Vector2.ZERO, 104.0, 0.0, TAU, 56, Color(shield_color, 0.78), 3.3, true)
				for side in [-1, 1]:
					draw_line(Vector2(side*61,-82), Vector2(side*90,-43), Color(shield_color, 0.85), 3.0, true)
		draw_set_transform(Vector2.ZERO)
	if boss:
		pass # The boss panel is drawn last, above beam lanes, by _draw_boss_panel().
	else:
		var elite_role: String = str(enemy.get("elite_role", ""))
		# World 1 strike wings carry no marker: an arc over their tail read
		# as a shield on the wrong side, and the banner already names them.
		if sim.pilot_id == "hunter" and int(enemy.id) == sim.hunter_target_id and sim.hunter_mark_left > 0.0 and p.y >= 0.0 and p.y <= 885.0:
			draw_arc(p, 48.0, 0.0, TAU, 32, Color("ffb96e"), 2.8, true)
			draw_string(ThemeDB.fallback_font, p + Vector2(-26,-60), "HUNT", HORIZONTAL_ALIGNMENT_LEFT, 78, 13, AMBER)
		if bool(enemy.get("rival",false)) and p.y >= 0.0 and p.y <= 885.0:
			var ring := 65.0 + (0.0 if profile.reduced else sin(visual_time * 5.0) * 3.0)
			draw_arc(p, ring, 0, TAU, 48, DANGER, 3.5, true)
			draw_circle(p+Vector2(45,-60), 15.0, AMBER)
			draw_string(ThemeDB.fallback_font, p+Vector2(39,-52), "!", HORIZONTAL_ALIGNMENT_LEFT, 20, 25, THREAT_INK)
			var label_x := clampf(p.x-97.0, 8.0, 330.0)
			draw_rect(Rect2(label_x-4.0, p.y-110.0, 198.0, 27.0), Color("261522",0.92))
			draw_string(ThemeDB.fallback_font, Vector2(label_x, p.y-91.0), "RIVAL CAPTAIN", HORIZONTAL_ALIGNMENT_LEFT, 194, 17, DANGER)
			_bar(Rect2(p.x-53,p.y+61,106,6),float(enemy.hp)/maxf(1.0,float(enemy.max_hp)),DANGER)
		if elite_role == "leader" and p.y >= 0.0 and p.y <= 885.0:
			# A distinctive amber target ring and literal label make it
			# obvious who powers the squad even at reduced effects / 3x.
			var ring_radius := 54.0 + sin(visual_time * 4.5) * (0.0 if profile.reduced else 2.0)
			draw_arc(p, ring_radius, 0, TAU, 48, Color(AMBER,0.94), 3.5, true)
			for corner in range(4):
				var direction := Vector2.from_angle(corner * PI / 2.0 + PI / 4.0)
				draw_line(p + direction * (ring_radius - 7), p + direction * (ring_radius + 7), AMBER, 3.0, true)
			var label_x: float = clampf(p.x - 61.0, 8.0, 408.0)
			draw_rect(Rect2(label_x-3.0, p.y-81.0, 130.0, 22.0), Color("1b1722",0.88))
			draw_string(ThemeDB.fallback_font, Vector2(label_x, p.y-64.0), "ELITE LEADER", HORIZONTAL_ALIGNMENT_LEFT, 125, 15, AMBER)
			_bar(Rect2(p.x-26, p.y+50, 52, 4), enemy.hp/enemy.max_hp, AMBER)
		elif elite_role == "wing" and p.y >= 0.0 and p.y <= 885.0:
			var disrupted: bool = bool(enemy.get("elite_disrupted",false))
			var wing_color: Color = CYAN if disrupted else AMBER
			draw_arc(p, 35, PI*0.12, PI*0.88, 16, Color(wing_color,0.75), 2.5, true)
			draw_string(ThemeDB.fallback_font, p+Vector2(-28, -44), "OFFLINE" if disrupted else "LINKED", HORIZONTAL_ALIGNMENT_LEFT, 74, 12, wing_color)
		if enemy.hp < enemy.max_hp and elite_role != "leader":
			_bar(Rect2(p.x-20,p.y-(44 if kind == "station" else 50),40,3),enemy.hp/enemy.max_hp,AMBER)
	_draw_evolution_marks(enemy)

# Tiny persistent marks show what the player actually built, instead of
# doubling particle density. They remain visible in reduced FX and at 3x.
func _draw_evolution_marks(enemy: Dictionary) -> void:
	if not sim._new_build_decisions() or enemy.hp <= 0.0:
		return
	var p: Vector2 = enemy.p
	if p.y < 0.0 or p.y > 885.0:
		return
	var radius := 71.0 if str(enemy.kind).begins_with("boss") else 38.0
	if float(enemy.get("evo_spotter_until", -1.0)) > sim.time:
		draw_arc(p, radius, PI * 0.04, PI * 0.89, 22, Color(CYAN, 0.88), 2.3, true)
	if float(enemy.get("evo_conductor_until", -1.0)) > sim.time:
		draw_arc(p, radius + 6.0, PI * 1.11, PI * 1.90, 22, Color("bca0ff"), 2.4, true)
	if int(enemy.id) == sim.engine_siege_target and sim.engine_siege_stacks >= 2 and sim.engine_siege_expires > sim.time:
		draw_arc(p, radius + 10.0, PI * 0.94, PI * 1.06, 10, Color(AMBER, 0.95), 3.0, true)
	if int(enemy.get("evo_lance_hits", 0)) > 0 and float(enemy.get("evo_lance_until", -1.0)) > sim.time:
		for i in range(mini(4, int(enemy.evo_lance_hits))):
			var axis: float = TAU * float(i) / 4.0
			draw_arc(p, radius + 13.0, axis, axis + 0.16, 5, Color("edd5ff"), 3.0, true)

## Engine plumes behind every ordinary enemy; ships arriving on screen
## burn hotter. Visual only, from visual time.
func _draw_enemy_exhaust(enemy: Dictionary) -> void:
	var p: Vector2 = enemy.p
	var scale := 0.72 if enemy.has("pack_id") else 1.0
	var flicker := 0.75 + 0.25 * sin(visual_time * 31.0 + float(enemy.phase) * 7.0)
	var length := (34.0 if enemy.has("arrive_y") else 16.0) * scale * flicker
	for side in [-1.0, 1.0]:
		var base := p + Vector2(side * 9.0 * scale, -18.0 * scale)
		draw_line(base, base + Vector2(0, -length), Color(1.0, 0.55, 0.25, 0.35), 4.0 * scale, true)
		draw_line(base, base + Vector2(0, -length * 0.55), Color(1.0, 0.9, 0.7, 0.55), 1.6 * scale, true)
	for i in range(3):
		var drift := fposmod(visual_time * 2.3 + float(enemy.phase) + i * 0.33, 1.0)
		draw_circle(p + Vector2(sin(float(enemy.phase) * 5.0 + i) * 6.0 * scale, -18.0 * scale - drift * 30.0 * scale), (1.8 - drift) * scale, Color(1.0, 0.7, 0.4, 0.35 * (1.0 - drift)))

func _draw_boss_module(enemy: Dictionary) -> void:
	var p: Vector2 = enemy.p
	var role: String = str(enemy.role)
	var pulse: float = 0.75 + 0.25 * sin(visual_time * 5.0 + float(enemy.id))
	var tint := HiddenSector.MINT if role == "archive_emitter" else (Color("6ce5ff") if role == "launch_bay" else (Color("ffae65") if role == "vent" else Color("bb8dff")))
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
	if bool(enemy.get("phase_objective", false)):
		# Reconfigured modules are unmistakable objectives, not respawned
		# decoration. Keep the marker static when reduced effects are on.
		draw_arc(p, 43, 0.0, TAU, 48, Color(tint, 0.93), 3.2, true)
		draw_string(ThemeDB.fallback_font, p + Vector2(-36, -51),
			"EMITTER" if role == "archive_emitter" else ("VENT" if role == "vent" else "PYLON"), HORIZONTAL_ALIGNMENT_CENTER, 72, 13, tint)
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
		if not profile.reduced:
			var back: Vector2 = -bullet.v.normalized()
			draw_line(p, p + back * 14.0, Color(DANGER, 0.30), 3.0, true)
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
		if not profile.reduced:
			var trail: Vector2 = -bullet.v.normalized()
			draw_line(p, p + trail * 16.0, Color(tint, 0.32), 3.0, true)
		_threat_outline(PackedVector2Array([p + Vector2(0, -7), p + Vector2(7, 0), p + Vector2(0, 7), p + Vector2(-7, 0)]))
		draw_circle(p, 3.0, tint)
		draw_circle(p, 1.1, Color("fff0d6"))

func _draw_threats() -> void:
	var marked_sources := {}
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
		# The warning lane is only half the story: mark the enemy powering it.
		# Never mark the same boss twice when it charges two lanes at once.
		# Legacy/visual-test lanes can be anonymous; keep their red warning
		# fully functional, but do not invent an enemy to mark as its source.
		var source_id: int = int(charge.get("source", -1))
		if source_id < 0 or marked_sources.has(source_id):
			continue
		for enemy in sim.enemies:
			if int(enemy.id) != source_id or float(enemy.hp) <= 0.0:
				continue
			marked_sources[source_id] = true
			var source: Vector2 = enemy.p
			if source.y < 0.0 or source.y > 810.0:
				break
			var boss: bool = str(enemy.kind).begins_with("boss") and str(enemy.kind) != "boss_module"
			var radius: float = 105.0 if boss else 40.0
			draw_arc(source, radius, 0, TAU, 48, Color(DANGER, 0.78), 3.0, true)
			var tag_y: float = clampf(source.y + radius + 26.0, 30.0, 886.0)
			var tag_x: float = clampf(source.x - 43.0, 6.0, 445.0)
			draw_rect(Rect2(tag_x - 4, tag_y - 20, 102, 26), THREAT_INK)
			draw_string(ThemeDB.fallback_font, Vector2(tag_x, tag_y), "CHARGING", HORIZONTAL_ALIGNMENT_LEFT, 94, 16, DANGER)
			break

func _draw_beam_cancel_feedback() -> void:
	# An interruption is visibly different from a red beam actually firing.
	# This animation is tracked in real time, not accelerated simulation time.
	for feedback in beam_cancel_feedback:
		var alpha: float = clampf(float(feedback.remaining) / float(feedback.duration), 0.0, 1.0)
		var x: float = float(feedback.x)
		draw_rect(Rect2(x - 33, 0, 66, 900), Color(CYAN, alpha * 0.09))
		for y in range(65, 870, 100):
			draw_line(Vector2(x - 25, y), Vector2(x + 25, y + 28), Color(CYAN, alpha * 0.65), 2.5, true)
		var label_x: float = clampf(x - 75, 6, 373)
		draw_rect(Rect2(label_x - 5, 654, 162, 34), Color(THREAT_INK, alpha * 0.92))
		draw_string(ThemeDB.fallback_font, Vector2(label_x, 678), "BEAM CANCELED", HORIZONTAL_ALIGNMENT_LEFT, 156, 17, Color(CYAN, alpha))
		var source: Vector2 = feedback.p
		if source.y >= 0.0 and source.y < 810.0:
			var radius: float = 35.0 + (1.0 - alpha) * 32.0
			draw_arc(source, radius, 0, TAU, 40, Color(CYAN, alpha * 0.85), 3.0, true)
			var tag_x: float = clampf(source.x - 55.0, 6, 414)
			var tag_y: float = clampf(source.y + 72.0, 32, 882)
			draw_rect(Rect2(tag_x - 4, tag_y - 20, 126, 26), Color(THREAT_INK, alpha * 0.90))
			draw_string(ThemeDB.fallback_font, Vector2(tag_x, tag_y), "SOURCE DOWN", HORIZONTAL_ALIGNMENT_LEFT, 120, 16, Color(CYAN, alpha))

func _draw_elite_break_feedback() -> void:
	for cue in elite_break_feedback:
		var alpha: float = clampf(float(cue.remaining) / float(cue.duration), 0.0, 1.0)
		var age: float = 1.0 - alpha
		var p: Vector2 = cue.p
		if p.y < 0.0 or p.y > 850.0:
			continue
		draw_arc(p, 30.0 + age * 95.0, 0.0, TAU, 48, Color(CYAN, alpha * 0.94), 4.0, true)
		var label_pos := Vector2(clampf(p.x - 88.0, 8.0, 345.0), clampf(p.y - 73.0, 29.0, 876.0))
		draw_rect(Rect2(label_pos.x - 4.0, label_pos.y - 22.0, 193.0, 29.0), Color("09222c", alpha * 0.90))
		draw_string(ThemeDB.fallback_font, label_pos, "FORMATION BROKEN", HORIZONTAL_ALIGNMENT_LEFT, 185, 17, Color(CYAN, alpha))

# Presentation only: color and geometry distinguish the four weapon families.
# Reduced-effects mode retains one ring and a short label, without a flash.
func _draw_spectacle_feedback() -> void:
	for cue in spectacle_feedback:
		var alpha: float = clampf(float(cue.remaining) / float(cue.duration), 0.0, 1.0)
		var age: float = 1.0 - alpha
		var p: Vector2 = cue.p
		if p.y < -15.0 or p.y > 890.0:
			continue
		var kind: String = str(cue.kind)
		if kind == "custodian-shield":
			var ship: Vector2 = sim.ship_position()
			var radius: float = 38.0 if profile.reduced else 38.0 + age * 30.0
			draw_arc(ship,radius,0,TAU,48,Color(HiddenSector.MINT,alpha),3.2,true)
			draw_string(ThemeDB.fallback_font, ship + Vector2(-90.0,-51.0), "CORE +%.1f SHIELD" % float(cue.amount), HORIZONTAL_ALIGNMENT_CENTER,180,15,Color(HiddenSector.MINT,alpha))
		elif kind == "archive-feedback":
			var radius: float = 78.0 if profile.reduced else 55.0 + age * 65.0
			draw_arc(p,radius,0,TAU,48,Color(HiddenSector.MINT,alpha),3.2,true)
			draw_string(ThemeDB.fallback_font, p + Vector2(-118.0,105.0), "COUNTER SURGE · %.1f%%" % float(cue.amount), HORIZONTAL_ALIGNMENT_CENTER,236,16,Color(HiddenSector.MINT,alpha))
		elif kind in ["mutation-installed", "mutation-proc"]:
			var id: String = str(cue.mutation)
			var family := "pulse" if id in ["piercing_pulse", "ricochet_pulse"] else ("seeker" if id in ["split_seeker", "breach_seeker"] else ("arc" if id in ["arc_reactor", "grounding_arc"] else "lance"))
			var tint := CYAN if family == "pulse" else (AMBER if family == "seeker" else (Color("bc9eff") if family == "arc" else Color("f1e8ff")))
			var size := 42.0 + age * (44.0 if kind == "mutation-installed" else 28.0)
			draw_arc(p, size, 0, TAU, 40, Color(tint, alpha * 0.90), 2.8, true)
			if not bool(profile.get("reduced", false)):
				for i in range(4 if kind == "mutation-installed" else 3):
					var v := Vector2.from_angle(TAU * float(i) / (4.0 if kind == "mutation-installed" else 3.0) + age * 0.3)
					var reach := 18.0 if family == "seeker" else (33.0 if family == "lance" else 22.0)
					draw_line(p + v * (size - 8.0), p + v * (size + reach), Color(tint, alpha * 0.75), 2.2, true)
			if kind == "mutation-installed":
				draw_string(ThemeDB.fallback_font, p + Vector2(-94.0, -96.0), "MUTATION ONLINE", HORIZONTAL_ALIGNMENT_LEFT, 188, 17, Color(tint, alpha))
		elif kind in ["engine-online", "engine-proc"]:
			var engine: String = str(cue.get("engine", ""))
			var tint := CYAN if engine in ["execution_network", "storm_circuit"] else (AMBER if engine in ["missile_siege", "salvage_carrier"] else Color("cba9ff"))
			var ring := (43.0 if kind == "engine-online" else 31.0) + age * (48.0 if kind == "engine-online" else 28.0)
			draw_arc(p, ring, 0, TAU, 36, Color(tint, alpha * 0.80), 2.8, true)
			if not bool(profile.get("reduced", false)):
				for i in range(4):
					var axis := Vector2.from_angle(TAU * float(i) / 4.0 + PI * 0.25)
					draw_line(p + axis * (ring - 9.0), p + axis * (ring + 11.0), Color(tint, alpha * 0.70), 2.2, true)
			if kind == "engine-online":
				draw_string(ThemeDB.fallback_font, p + Vector2(-86.0, -84.0), "ENGINE ONLINE", HORIZONTAL_ALIGNMENT_LEFT, 174, 17, Color(tint, alpha))
		elif kind == "evolution-proc":
			# A restrained, legible payoff cue: one ring and one short label.
			# At 3x the animation uses real seconds, not accelerated simulation.
			var evolution: String = str(cue.get("evolution", ""))
			var labels := {
				"duelist":"FOCUS", "spotter":"MARK HIT", "breacher":"BREACH",
				"interceptor":"INTERRUPT", "conductor":"ARC CHARGE",
				"tempest":"SWARM", "executioner":"EXECUTE", "lifeline":"SHIELD +"
			}
			var tint := CYAN if evolution in ["duelist", "spotter", "lifeline"] else (AMBER if evolution in ["breacher", "interceptor"] else Color("c4a4ff"))
			var ring := 26.0 + age * 32.0
			draw_arc(p, ring, 0.0, TAU, 32, Color(tint, alpha * 0.85), 2.6, true)
			if not bool(profile.get("reduced", false)):
				for i in range(3):
					var axis := Vector2.from_angle(TAU * float(i) / 3.0 + age * 0.5)
					draw_line(p + axis * (ring - 7.0), p + axis * (ring + 8.0), Color(tint, alpha * 0.70), 2.0, true)
			var position := Vector2(clampf(p.x - 63.0, 7.0, 400.0), clampf(p.y - 55.0, 25.0, 866.0))
			draw_rect(Rect2(position.x - 3.0, position.y - 17.0, 136.0, 22.0), Color("101b2a", alpha * 0.84))
			draw_string(ThemeDB.fallback_font, position, str(labels.get(evolution, "BUILD HIT")), HORIZONTAL_ALIGNMENT_LEFT, 128, 15, Color(tint, alpha))
		elif kind == "boss-module-break":
			var role: String = str(cue.role).replace("_", " ").to_upper()
			var ring := 39.0 + age * 50.0
			draw_arc(p, ring, 0, TAU, 48, Color(AMBER, alpha * 0.90), 3.2, true)
			if not bool(profile.get("reduced", false)):
				for i in range(6):
					var v := Vector2.from_angle(TAU * float(i) / 6.0)
					draw_line(p + v * (ring - 6.0), p + v * (ring + 17.0), Color(AMBER, alpha * 0.76), 2.0, true)
			draw_string(ThemeDB.fallback_font, p + Vector2(-74.0, -67.0), role + " DOWN", HORIZONTAL_ALIGNMENT_LEFT, 164, 16, Color(AMBER, alpha))
		elif kind == "boss-phase-break":
			var ring := 65.0 + age * 85.0
			draw_arc(p, ring, 0, TAU, 64, Color(CYAN, alpha * 0.95), 3.5, true)
			if not bool(profile.get("reduced", false)):
				draw_arc(p, ring * 0.68, PI * 0.15, PI * 1.8, 48, Color(AMBER, alpha * 0.68), 3.0, true)
			var archive_phase_break: bool = sim.secret_entered and sim.archive_boss_reworked()
			var label: String = ["LOCKDOWN","LATTICE","COLLAPSE"][clampi(int(cue.phase)-1,0,2)] if archive_phase_break else "PHASE %d / 3" % int(cue.phase)
			var tint: Color = ArchiveIllustration.phase_tint(int(cue.phase)-1) if archive_phase_break else CYAN
			draw_string(ThemeDB.fallback_font, p + Vector2(-82.0, -98.0), label, HORIZONTAL_ALIGNMENT_CENTER, 164, 19, Color(tint, alpha))

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
	elif effect.kind == "hijack-capture":
		var mint := Color("75efd1")
		var radius := 25.0 + age * 40.0
		draw_arc(p, radius, 0.0, TAU, 40, Color(mint, alpha), 3.0, true)
		draw_string(ThemeDB.fallback_font, p + Vector2(-55.0,-45.0), "HIJACKED", HORIZONTAL_ALIGNMENT_CENTER, 110, 16, Color(mint, alpha))
	elif effect.kind == "vent-release":
		# Orange heat expanding away from the destroyed vent, with no flash.
		for i in range(6):
			var axis := Vector2.from_angle(TAU * float(i) / 6.0)
			var distance := 16.0 + age * 84.0
			draw_line(p + axis * distance, p + axis * (distance + 22.0), Color(AMBER, alpha * 0.85), 3.0, true)
		draw_arc(p, 25.0 + age * 58.0, 0.0, TAU, 40, Color(AMBER, alpha * 0.68), 2.5, true)
	elif effect.kind == "wing_drones":
		for side in [-1,1]:
			draw_arc(p+Vector2(side*46,8),18+age*24,-PI,0,24,Color(CYAN,alpha),2,true)
	elif effect.kind == "guard_drones":
		draw_arc(p,58.0,0,TAU,40,Color(CYAN,alpha*0.8),2.0+age*2.0,true)
	elif effect.kind == "guard-shot":
		# Tracer from the guard drone to the bullet it shot down.
		var origin: Vector2 = effect.get("from", p)
		draw_line(origin,p,Color(CYAN,alpha),2.0,true)
		draw_circle(p,3.0+age*5.0,Color(Color.WHITE,alpha*0.8))
	elif effect.kind == "fusion-cast":
		_draw_fusion_cast(effect, alpha, age)
	elif effect.kind == "fusion-formed":
		_draw_fusion_formed(effect, alpha, age)
	elif effect.kind == "elite-broken":
		# On-screen response to destroying the squad coordinator.
		var radius := 28.0 + age * 90.0
		draw_arc(p, radius, 0, TAU, 48, Color(CYAN,alpha*0.95), 4.0, true)
		var label_pos: Vector2 = Vector2(clampf(p.x - 88,8,348),clampf(p.y-80,27,870))
		draw_rect(Rect2(label_pos.x-4,label_pos.y-21,191,29), Color("09222c", alpha*0.90))
		draw_string(ThemeDB.fallback_font, label_pos, "FORMATION BROKEN", HORIZONTAL_ALIGNMENT_LEFT, 184, 17, Color(CYAN,alpha))
	elif effect.kind == "timed-counter":
		# A successful defensive read should be unmistakable, not a generic explosion.
		var radius := 43.0 + age * 43.0
		draw_arc(p, radius, 0, TAU, 40, Color(CYAN, alpha * 0.90), 3.0, true)
		for spoke in range(4):
			var direction := Vector2.from_angle(spoke * TAU / 4.0 + PI / 4.0)
			draw_line(p + direction * (radius - 9), p + direction * (radius + 9), Color(SHIELD, alpha), 2.6, true)
		draw_string(ThemeDB.fallback_font, p + Vector2(-45, -62), "COUNTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(CYAN, alpha))
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
		for i in range(5 if profile.reduced else 9):
			var angle: float = i * TAU / 5 + effect.get("born", 0) * 0.17
			var direction := Vector2.from_angle(angle)
			draw_line(p + direction * age * 7, p + direction * age * 26, Color(color, alpha), 1.8, true)
	else:
		var big: bool = effect.get("boss", false)
		var radius := (115 if big else 48) * age
		_glow(p, maxf(1, (32 if big else 15) * alpha), Color(1.0, 0.75, 0.3, alpha))
		draw_arc(p, radius + 5, 0, TAU, 48, Color(1, 0.6, 0.2, alpha * 0.65), 2.0, true)
		var count := 14 if profile.reduced else 40
		if not profile.reduced:
			draw_circle(p, radius * 0.75, Color(0.35, 0.33, 0.38, alpha * 0.22))
		for i in range(count):
			var angle: float = i * 2.39996 + effect.get("born", 0) * 0.11
			var direction := Vector2.from_angle(angle)
			var distance := radius * (0.4 + fposmod(i * 0.173, 0.7))
			var tail := p + direction * distance
			draw_line(tail, tail + direction * (3 + alpha * 12), Color(1, 0.45 + (i % 3) * 0.15, 0.2, alpha), 1.5, true)
		# Tumbling hull fragments make kills read as physical wreckage.
		if not profile.reduced and not big and effect.kind == "explosion":
			for i in range(4):
				var direction := Vector2.from_angle(i * 1.7 + float(effect.get("born", 0)) * 0.31)
				var center := p + direction * age * (34.0 + i * 9.0)
				var spin := age * (4.0 + i)
				draw_colored_polygon(PackedVector2Array([center + Vector2(-3.5, -2).rotated(spin), center + Vector2(3.5, -1).rotated(spin), center + Vector2(1, 3).rotated(spin)]), Color(0.62, 0.68, 0.76, alpha))

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
	if id in ["nova_aegis","shieldstorm","repair_matrix","reflective_wall","ghost_signal"]:
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
		"shieldstorm":
			# A thin expanding defensive pulse; hostile projectile cores stay visible.
			var r := 45.0 + spread * 140.0
			FusionArt.outline(self,FusionArt.polygon(p,43),Color(a,alpha*0.8),2.1)
			for i in range(8):
				var angle := i * TAU / 8.0
				draw_arc(p,r,angle+0.06,angle+0.59,12,Color(a,alpha*0.67),2.6,true)
				var v := Vector2.from_angle(angle)
				draw_line(p+v*(r+1),p+v*(r+11),Color(b,alpha*0.78),1.8,true)
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

func _draw_hijacked_ships() -> void:
	var tint := Color("75efd1")
	for ally in sim.hijacked_ships:
		var p: Vector2 = ally.p
		var kind: String = str(ally.kind)
		var role: String = str(ally.role)
		# The same silhouettes as enemy ships, rotated toward the enemy and
		# unmistakably identified by a mint outline, health bar and reticle.
		draw_set_transform(p, PI, Vector2(0.72, 0.72))
		if _custom_enemy(kind):
			_draw_custom_enemy(kind)
		else:
			var art_key: String = kind if SHIPS.has(kind) else ("gunship" if role in ["bomber", "guard", "carrier", "disruptor"] else "drone")
			draw_texture_rect(SHIPS[art_key], Rect2(-33,-33,66,66), false, tint)
		draw_set_transform(Vector2.ZERO)
		draw_arc(p, 31.0, 0.0, TAU, 40, Color(tint, 0.9), 2.2, true)
		if role == "guard":
			draw_arc(p, 68.0, PI * 1.10, PI * 1.90, 22, Color(tint,0.55), 2.0, true)
		if role == "carrier" and float(ally.get("sortie_until", 0.0)) > sim.time:
			for side in [-1,1]:
				var wing: Vector2 = p + Vector2(side * 40.0,-24.0)
				var hull := PackedVector2Array([wing+Vector2(0,-10),wing+Vector2(8,8),wing,wing+Vector2(-8,8)])
				draw_colored_polygon(hull, Color("194f45"))
				FusionArt.outline(self,hull,tint,1.5)
		var hp_fraction: float = clampf(float(ally.hp) / maxf(1.0, float(ally.max_hp)), 0.0, 1.0)
		draw_rect(Rect2(p+Vector2(-23,34),Vector2(46,4)), Color("152531"))
		draw_rect(Rect2(p+Vector2(-23,34),Vector2(46*hp_fraction,4)), tint)
		draw_string(ThemeDB.fallback_font, p+Vector2(-43,50), role.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 86, 12, tint)

func _draw_support() -> void:
	# Engineer's field sentry is a visible ship-mounted turret, separate from
	# the ordinary Wing Drone visuals and their individual firing timers.
	if sim.sentry_left > 0.0:
		var turret: Vector2 = sim.ship_position() + Vector2(36.0, -5.0)
		var shape := PackedVector2Array([turret+Vector2(0,-13), turret+Vector2(11,-3), turret+Vector2(8,10), turret+Vector2(-8,10), turret+Vector2(-11,-3)])
		draw_colored_polygon(shape, Color("1b5361"))
		FusionArt.outline(self, shape, CYAN, 2.0)
		draw_circle(turret, 4.0, Color.WHITE)
		draw_line(turret + Vector2(0,-6), turret + Vector2(0,-17), CYAN, 2.5, true)
	if sim.escort_left > 0.0:
		for i in range(sim.escort_count):
			var p: Vector2 = sim.escort_position(i)
			var hull := PackedVector2Array([p+Vector2(0,-14),p+Vector2(10,9),p+Vector2(3,5),p+Vector2(0,10),p+Vector2(-3,5),p+Vector2(-10,9)])
			draw_colored_polygon(hull,Color("244450"))
			FusionArt.outline(self,hull,Color("a9d8e1"),1.4)
			draw_line(p+Vector2(0,-7),p+Vector2(0,3),CYAN,2.2,true)
			draw_line(p+Vector2(0,10),p+Vector2(0,19),Color("badcf4"),2,true)
	# Haven's permanent Hive drones: small mint darts tucked behind the ship.
	for i in range(sim.hive_count()):
		var h: Vector2 = sim.hive_position(i)
		var dart := PackedVector2Array([h+Vector2(0,-10),h+Vector2(7,6),h+Vector2(0,3),h+Vector2(-7,6)])
		draw_colored_polygon(dart, Color("1f4a3f"))
		FusionArt.outline(self, dart, Color("a8f4d0"), 1.3)
		draw_circle(h + Vector2(0,-2), 1.8, Color.WHITE)
		if not profile.reduced:
			draw_line(h + Vector2(0,5), h + Vector2(0,12), Color(0.66, 0.96, 0.82, 0.55), 2.0, true)
	if sim.guard_left > 0.0:
		for i in range(sim.guard_count):
			var g: Vector2 = sim.guard_position(i)
			var diamond := PackedVector2Array([g+Vector2(0,-8),g+Vector2(7,0),g+Vector2(0,8),g+Vector2(-7,0)])
			draw_colored_polygon(diamond,Color("244450"))
			FusionArt.outline(self,diamond,CYAN,1.4)
			draw_circle(g,2.2,Color.WHITE)
	for mine in sim.ion_mines:
		var p: Vector2 = mine.p
		var progress: float = clampf(1.0-mine.fuse/1.8,0.0,1.0)
		FusionArt.outline(self,FusionArt.polygon(p,12,4),Color("c3a8f3"),2)
		draw_circle(p,3,CYAN)
		draw_arc(p,19,-PI/2,-PI/2+TAU*progress,32,CYAN,1.5,true)
		for i in range(4):
			var v := Vector2.from_angle(i*TAU/4)
			draw_line(p+v*13,p+v*18,Color("c3a8f3"),1.5,true)
