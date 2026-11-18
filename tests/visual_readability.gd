extends SceneTree
## Render actual gameplay layers under X11/Xvfb, with deterministic overlap fixtures.
const Sim = preload("res://scripts/simulation.gd")
const Playfield = preload("res://scripts/playfield.gd")
class PhoneScene extends "res://scripts/main.gd":
	func _touch_first() -> bool:
		return true
class MemoryServices extends "res://scripts/platform_services.gd":
	var values: Dictionary = {}
	func write_atomic(path: String, value: Dictionary) -> bool:
		values[path] = value.duplicate(true)
		return true
	func read_save(path: String) -> Dictionary:
		return values.get(path, {})
	func delete_run() -> void:
		values.erase(RUN)
class FixtureHost extends Node:
	var sim: RefCounted
	var profile := {"reduced": false}
	var visual_time := 133.0
	var mode := "playing"
	var banner_clock := 0.0
	var banner_text := ""
var failures := 0
var checks := 0
var output := "/tmp/starrun-visuals"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _frame(view: Viewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(540, 960)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var host := FixtureHost.new()
	host.sim = Sim.new(2501)
	host.sim.tick = 7980
	host.sim.time = 133.0
	host.sim.shield = 0.0
	host.sim.shield_offline = 3.0
	viewport.add_child(host)
	var field := Playfield.new()
	field.host = host
	host.add_child(field)
	field.set_process(false)
	var kinds := ["chaff", "ion", "corrosion", "disrupt", "heat", "gravity", "void", "ordnance", "mine", "slag"]
	for i in range(kinds.size()):
		var p := Vector2(100 + (i % 4) * 110, 360 + (i / 4) * 100)
		host.sim.bullets.append({"kind": kinds[i], "p": p, "v": Vector2(15, 100), "fuse": 1.5})
		host.sim.effects.append({"kind":"explosion", "p":p, "life":0.35, "max_life":0.5, "born":0, "boss":true})
		host.sim.effects.append({"kind":"arc", "p":p - Vector2(15, 20), "to":p + Vector2(20, 40), "life":0.2, "max_life":0.22, "born":0})
		host.sim.shots.append({"weapon":"barrage", "p":p, "v":Vector2(0,-100)})
	host.sim.effects.append({"kind":"nova", "p":Vector2(270,790), "life":0.3, "max_life":0.5, "born":0})
	host.sim.effects.append({"kind":"beam", "p":Vector2(210,0), "life":0.3, "max_life":0.32, "born":0})
	host.sim.charges = [{"x":370.0, "remaining":0.7, "duration":1.8}]
	for stage in range(1, 5):
		host.sim.stage = stage
		for reduced in [false, true]:
			host.profile.reduced = reduced
			field.shield_break_clock = 0.48
			field.queue_redraw()
			var crowded := await _frame(viewport)
			crowded.save_png(output.path_join("stage-%d-%s.png" % [stage, "reduced" if reduced else "full"]))
			# Compare each actual projectile core with/without overlapping effects.
			var effects: Array = host.sim.effects
			host.sim.effects = []
			field.queue_redraw()
			var clear := await _frame(viewport)
			for bullet in host.sim.bullets:
				var p: Vector2 = bullet.p
				var visible := true
				for x in range(-1, 2):
					for y in range(-1, 2):
						visible = visible and crowded.get_pixel(int(p.x) + x, int(p.y) + y).is_equal_approx(clear.get_pixel(int(p.x) + x, int(p.y) + y))
				check(visible, "Threat core must survive overlapping explosions/arc/beam: " + str(bullet.kind))
			host.sim.effects = effects
	# Feedback persists in real presentation time and does not repeatedly restart.
	host.sim.effects.append({"kind":"shield-break", "born":7980, "life":0.75, "max_life":0.75})
	field._process(0.01)
	field._process(0.25)
	check(is_equal_approx(field.shield_break_clock, 0.5), "Break cue holds for 0.75 real seconds without retriggering")
	field._process(0.6)
	check(field.shield_break_clock == 0.0, "Break burst ends while the empty shield indicator remains")
	host.sim.effects.clear()
	field.shield_break_clock = 0.5
	host.sim.stage = 1
	field._process(0.0)
	check(field.shield_break_clock == 0.0, "Warp repair must clear any previous stage break burst")
	# Real elite squad art must be readable on the actual 540x960 playfield,
	# including when reduced effects is enabled. No screenshot mockups.
	host.sim = Sim.new(7600)
	host.sim.stage = 2
	host.sim._spawn_encounter()
	for i in range(3):
		host.sim._spawn_enemy()
	for i in range(host.sim.enemies.size()):
		host.sim.enemies[i].p = Vector2(155 + i * 116, 300 + (i % 2) * 55)
	check(str(host.sim.enemies[0].get("elite_role","")) == "leader", "Fixture uses a genuine generated elite leader, not a decorative marker")
	for reduced in [false,true]:
		host.profile.reduced = reduced
		field.queue_redraw()
		var alive := await _frame(viewport)
		alive.save_png(output.path_join("elite-leader-%s.png" % ("reduced" if reduced else "full")))
		check(alive.get_size() == Vector2i(540,960), "Elite leader indicator renders in portrait at both detail levels")
	host.sim._damage_enemy(host.sim.enemies[0], float(host.sim.enemies[0].hp) + 9999.0, "pulse")
	check(host.sim.effects.any(func(e): return e.kind == "elite-broken"), "Destroying the leader creates a visible formation-broken effect")
	field._process(0.01)
	check(field.elite_break_feedback.size() == 1, "Formation broken feedback is tracked once for a real-time visual hold")
	field.queue_redraw()
	var disrupted := await _frame(viewport)
	disrupted.save_png(output.path_join("elite-formation-broken.png"))
	check(disrupted.get_size() == Vector2i(540,960), "Formation-broken cue renders on the real playfield")
	field._process(0.50)
	check(field.elite_break_feedback.size() == 1, "Formation cue survives 0.5 real seconds even when combat runs at 3x")
	field._process(0.65)
	check(field.elite_break_feedback.is_empty(), "Formation cue expires after a full real-time hold without retriggering")
	# Capture REAL boss HUD, shield modules and active warning layers across
	# all three phases, at both reduced- and full-effects settings.
	# These files are visual review inputs, not evidence of finger reaction.
	for stage in [3, 4, 5]:
		host.sim = Sim.new(75000 + stage)
		host.sim.stage = stage
		host.sim.secret_entered = stage == 5
		host.sim._spawn_boss()
		for phase in range(3):
			if stage in [3, 4] and phase > 0:
				var core: Dictionary = host.sim._boss_core()
				host.sim._damage_enemy(core, 9999999.0, "nova")
				var parts: Array = host.sim.enemies.filter(func(e): return e.kind == "boss_module" and e.hp > 0.0)
				for part in parts:
					host.sim._damage_enemy(part, 9999999.0, "nova")
			if stage == 5:
				host.sim.archive_phase = phase
				host.sim.archive_attack = ""
				host.sim.archive_next_attack = host.sim.time
				host.sim._update_archive_attack()
			else:
				host.sim.charges.clear()
				host.sim.heavy_ready_at = host.sim.time
				host.sim._update_enemies()
			for reduced in [false, true]:
				host.profile.reduced = reduced
				field.queue_redraw()
				var boss_image := await _frame(viewport)
				boss_image.save_png(output.path_join("boss-world-%d-phase-%d-%s.png" % [stage, phase + 1, "reduced" if reduced else "full"]))
				check(boss_image.get_size() == Vector2i(540, 960),
					"Real World %d boss phase %d renders with reduced/full effects" % [stage, phase + 1])
	viewport.queue_free()
	await process_frame
	var scene := PhoneScene.new()
	scene.services = MemoryServices.new()
	root.add_child(scene)
	scene.set_process(false)
	scene.world.set_process(false)
	scene.sound.enabled = false
	scene.sound.music_enabled = false
	for dimensions in [Vector2i(390,844), Vector2i(375,667)]:
		root.size = dimensions
		await process_frame
		scene._layout()
		scene.sim = Sim.new(2502, {"rerolls":1})
		scene.sim.upgrades.pulse = 4
		scene.sim.upgrades.aegis = 5
		scene.sim.upgrades.nova = 3
		scene.sim.active_slots.append("nova")
		scene.sim.upgrades.chrono = 8
		scene.sim.cards = []
		for id in ["nova", "pulse", "chrono", "armor"]:
			scene.sim.cards.append(scene.sim.content.cards.filter(func(c): return c.id == id)[0])
		scene._show_cards(false)
		scene._process(0.0)
		var draft := await _frame(root)
		draft.save_png(output.path_join("draft-%d.png" % dimensions.x))
		check(scene.card_buttons[3].get_global_rect().end.y <= scene.reading_scroll.get_global_rect().end.y + 1, "Fusion and rank bonuses must fit together on a phone draft")
		var labels := scene.overlay.find_children("*", "Label", true, false)
		check(labels.any(func(label): return label.text == "Nova Guard"), "A qualifying pick shows the resulting fusion")
		scene.banish_mode = true
		scene._show_cards(false)
		await process_frame
		labels = scene.overlay.find_children("*", "Label", true, false)
		check(labels.any(func(label): return label.text == scene.sim.cards[0].name) and not labels.any(func(label): return label.text == "Nova Guard"), "Banish shows the actual component being removed")
		scene.banish_mode = false
		scene.sim.upgrades.aegis = 3
		scene._show_cards(false)
		await process_frame
		labels = scene.overlay.find_children("*", "Label", true, false)
		check(not labels.any(func(label): return "fusion" in label.text.to_lower()), "No early fusion label appears before the other component is rank 5")
		scene.profile.cores = 20
		scene._hangar_tab("Tactics")
		scene._process(0.0)
		var hangar := await _frame(root)
		hangar.save_png(output.path_join("hangar-%d.png" % dimensions.x))
	scene.queue_free()
	await process_frame
	print("VISUAL RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
