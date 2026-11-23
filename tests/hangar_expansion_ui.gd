extends SceneTree
const Portrait = preload("res://scripts/pilot_portrait.gd")
const Catalog = preload("res://scripts/catalog.gd")
class PhoneScene extends "res://scripts/main.gd":
	func _touch_first() -> bool: return true
class MemoryServices extends "res://scripts/platform_services.gd":
	var values := {}
	func write_atomic(path: String, value: Dictionary) -> bool:
		values[path] = value.duplicate(true)
		return true
	func read_save(path: String) -> Dictionary: return values.get(path,{})
	func delete_run() -> void: values.erase(RUN)
var checks := 0
var failures := 0
func _initialize():
	DirAccess.make_dir_recursive_absolute("/tmp/starrun-visuals")
	create_timer(30).timeout.connect(func(): push_error("Expansion UI timed out"); quit(1))
	call_deferred("_run")
func check(ok: bool,message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _frame():
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
func _run():
	var board := SubViewport.new()
	board.size = Vector2i(660,470)
	board.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(board)
	var back := ColorRect.new()
	back.color = Color("0b1422")
	back.size = board.size
	board.add_child(back)
	var hashes := {}
	for i in range(Catalog.PILOTS.size()):
		var pilot: Dictionary = Catalog.PILOTS[i]
		var face := Portrait.new()
		face.pilot_id = pilot.id
		face.position = Vector2(20+(i%3)*220,12+(i/3)*235)
		face.size = Vector2(190,190)
		board.add_child(face)
		var texture: Texture2D = Portrait.FACES[pilot.id]
		var digest: int = hash(texture.get_image().get_data())
		check(not hashes.has(digest) and texture.get_width() == 384, "Each pilot has a distinct bundled face portrait")
		hashes[digest] = true
		var label := Label.new()
		label.position = face.position + Vector2(0,195)
		label.size = Vector2(190,25)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text = str(pilot.name).get_slice(" · ",0)
		board.add_child(label)
	await _frame()
	board.get_texture().get_image().save_png("/tmp/starrun-visuals/pilot-faces.png")
	board.queue_free()
	var scene := PhoneScene.new()
	scene.services = MemoryServices.new()
	root.add_child(scene)
	scene.set_process(false)
	scene.world.set_process(false)
	scene.sound.enabled = false
	scene.sound.music_enabled = false
	for dimensions in [Vector2i(390,844),Vector2i(375,667)]:
		root.size = dimensions
		await _frame()
		scene._layout()
		scene.loadout_tab = "Pilots"
		scene._show_loadout()
		await _frame()
		var faces := scene.overlay.find_children("*","Control",true,false).filter(func(c): return c is Portrait)
		check(faces.size() == Catalog.PILOTS.size(), "Pilot selection displays every portrait")
		for face in faces:
			check(face.size.x >= 64 and face.get_global_rect().end.x < dimensions.x, "Pilot faces remain large and inside the phone card")
		root.get_texture().get_image().save_png("/tmp/starrun-visuals/pilots-%d.png" % dimensions.x)
		scene.reading_scroll.scroll_vertical = int(scene.reading_scroll.get_v_scroll_bar().max_value)
		await _frame()
		check(faces[-1].get_global_rect().intersects(scene.reading_scroll.get_global_rect()), "The last pilot remains reachable")
		scene.profile.cores = 2000
		for group in Catalog.GROUPS:
			scene._hangar_tab(group)
			await _frame()
			var labels := scene.hangar_scroll.find_children("*","Label",true,false)
			var entries := Catalog.HANGAR.filter(func(e):return e.group==group)
			check(entries.all(func(e):return labels.any(func(label):return label.text==e.name)), "Expanded Hangar contains every " + group + " purchase")
			scene.hangar_scroll.scroll_vertical = int(scene.hangar_scroll.get_v_scroll_bar().max_value)
			await _frame()
			var last: Label = labels.filter(func(label): return label.text==entries[-1].name)[0]
			check(last.get_global_rect().intersects(scene.hangar_scroll.get_global_rect()), "The final " + group + " purchase can be reached")
			root.get_texture().get_image().save_png("/tmp/starrun-visuals/hangar-%s-%d.png" % [group.to_lower(),dimensions.x])
		scene.profile.ship = "haven"
		scene.profile.pilot = "engineer"
		scene._show_menu()
		await _frame()
		check(scene.overlay.find_children("*","Control",true,false).any(func(c):return c is Portrait), "The equipped pilot's face appears on the main menu")
		root.get_texture().get_image().save_png("/tmp/starrun-visuals/menu-pilot-%d.png" % dimensions.x)
	scene.queue_free()
	await process_frame
	print("EXPANSION UI RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
