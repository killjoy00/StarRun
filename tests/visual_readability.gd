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
		scene.sim.upgrades.chrono = 8
		scene.sim.cards = []
		for id in ["nova", "pulse", "chrono", "armor"]:
			scene.sim.cards.append(scene.sim.content.cards.filter(func(c): return c.id == id)[0])
		scene._show_cards(false)
		scene._process(0.0)
		var draft := await _frame(root)
		draft.save_png(output.path_join("draft-%d.png" % dimensions.x))
		check(scene.card_buttons[3].get_global_rect().end.y <= scene.reading_scroll.get_global_rect().end.y + 1, "Fusion and rank bonuses must fit together on a phone draft")
		scene.profile.cores = 20
		scene._hangar_tab("Tactics")
		scene._process(0.0)
		var hangar := await _frame(root)
		hangar.save_png(output.path_join("hangar-%d.png" % dimensions.x))
	scene.queue_free()
	await process_frame
	print("VISUAL RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
