extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const Field = preload("res://scripts/playfield.gd")
const Badge = preload("res://scripts/icon_badge.gd")
class Host extends Node:
	var sim: RefCounted
	var profile := {"reduced":false}
	var visual_time := 0.0
	var mode := "playing"
	var banner_clock := 0.0
	var banner_text := ""
var checks := 0
var failures := 0
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/starrun-visuals")
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
func _viewport(dimensions: Vector2i) -> SubViewport:
	var view := SubViewport.new()
	view.size = dimensions
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	return view
func _run() -> void:
	var content := Sim.new().content
	var board := _viewport(Vector2i(740,400))
	var background := ColorRect.new()
	background.color = Color("080f1b")
	background.size = board.size
	board.add_child(background)
	var hashes := {}
	var icon_view := _viewport(Vector2i(40,40))
	icon_view.transparent_bg = true
	var icon := Badge.new()
	icon.size = Vector2(40,40)
	icon_view.add_child(icon)
	for i in range(content.fusions.size()):
		var fusion: Dictionary = content.fusions[i]
		icon.icon_id = fusion.id
		icon.queue_redraw()
		var symbol := await _frame(icon_view)
		var hash_value: int = hash(symbol.get_data())
		check(not hashes.has(hash_value), "Each fusion needs a distinct phone-size insignia")
		hashes[hash_value] = true
		var tile := Panel.new()
		tile.position = Vector2(10+(i%5)*146,10+(i/5)*195)
		tile.size = Vector2(136,182)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("101e2f")
		style.border_color = Color("2b4055")
		style.set_border_width_all(1)
		style.set_corner_radius_all(12)
		tile.add_theme_stylebox_override("panel",style)
		board.add_child(tile)
		var large := Badge.new()
		large.icon_id = fusion.id
		large.position = Vector2(28,14)
		large.size = Vector2(80,80)
		tile.add_child(large)
		var label := Label.new()
		label.text = fusion.name
		label.position = Vector2(3,100)
		label.size = Vector2(130,30)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size",15)
		tile.add_child(label)
		var small := Badge.new()
		small.icon_id = fusion.id
		small.position = Vector2(48,134)
		small.size = Vector2(40,40)
		tile.add_child(small)
	(await _frame(board)).save_png("/tmp/starrun-visuals/fusion-insignia.png")
	board.queue_free()
	icon_view.queue_free()
	var viewport := _viewport(Vector2i(540,960))
	var host := Host.new()
	viewport.add_child(host)
	var field := Field.new()
	field.host = host
	host.add_child(field)
	field.set_process(false)
	for fusion in content.fusions:
		for reduced in [false,true]:
			host.profile.reduced = reduced
			host.sim = Sim.new(2805)
			host.sim.active_slots = fusion.parts.duplicate()
			for part in fusion.parts: host.sim.upgrades[part] = 5
			host.sim._try_fuse()
			host.sim.effects.clear()
			for i in range(3):
				host.sim._add_enemy("station",Vector2(150+i*120,320))
				host.sim.enemies[-1].hp = 10000.0
				host.sim.enemies[-1].max_hp = 10000.0
			check(host.sim.activate(fusion.id), "Render the real cast for " + str(fusion.id))
			for effect in host.sim.effects: effect.life = effect.max_life * 0.65
			# Add live threats after the cast, including attacks it would normally clear.
			for p in [Vector2(240,745),Vector2(270,710),Vector2(315,760)]:
				host.sim.bullets.append({"kind":"chaff","p":p,"v":Vector2(0,100),"damage":1})
			host.sim.charges = [{"x":370.0,"remaining":0.7,"duration":1.8}]
			field._process(0)
			field.queue_redraw()
			var with_fx := await _frame(viewport)
			with_fx.save_png("/tmp/starrun-visuals/fusion-%s-%s.png" % [fusion.id,"reduced" if reduced else "full"])
			var effects: Array = host.sim.effects.duplicate(true)
			host.sim.effects.clear()
			field.queue_redraw()
			var without_fx := await _frame(viewport)
			for bullet in host.sim.bullets:
				var visible := true
				for x in range(-1,2):
					for y in range(-1,2):
						var p: Vector2i = Vector2i(bullet.p)+Vector2i(x,y)
						visible = visible and with_fx.get_pixelv(p).is_equal_approx(without_fx.get_pixelv(p))
				check(visible, "Fusion cannot hide a hostile core: " + str(fusion.id))
			host.sim.effects = effects
	# Formation is presentation time; speed settings do not shorten the recognition cue.
	host.sim.effects = [{"kind":"fusion-formed","fusion":"prism_focus","p":Vector2(270,790),"life":1.2,"max_life":1.2,"born":10}]
	field._process(0)
	field._process(0.4)
	check(is_equal_approx(field.formation_clock,0.8), "Formation cue uses presentation time and does not retrigger")
	field.queue_redraw()
	(await _frame(viewport)).save_png("/tmp/starrun-visuals/fusion-formed.png")
	field._process(0.9)
	check(field.formation_clock == 0, "Formation animation ends cleanly")
	host.sim.effects.append({"kind":"fusion-formed","fusion":"railstorm","p":Vector2(270,790),"life":1.2,"max_life":1.2,"born":10})
	field._process(0)
	field._process(0.4)
	check(is_equal_approx(field.formation_clock,0.8) and field.formation.fusion == "railstorm", "Back-to-back drafts cannot restart old formation cues")
	viewport.queue_free()
	await process_frame
	print("FUSION VISUAL RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
