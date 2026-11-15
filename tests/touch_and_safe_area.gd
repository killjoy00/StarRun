extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
class PhoneScene extends "res://scripts/main.gd":
	var safe_top := 59.0
	func _touch_first() -> bool:
		return true
	func _insets() -> Dictionary:
		return {"top":safe_top, "bottom":34.0}
class MemoryServices extends "res://scripts/platform_services.gd":
	var values: Dictionary = {}
	func write_atomic(path: String, value: Dictionary) -> bool:
		values[path] = value.duplicate(true)
		return true
	func read_save(path: String) -> Dictionary:
		return values.get(path, {})
	func delete_run() -> void:
		values.erase(RUN)
var checks := 0
var failures := 0
func _initialize() -> void:
	Input.set_emulate_touch_from_mouse(true)
	create_timer(30).timeout.connect(func(): push_error("Touch tests timed out"); quit(1))
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _motion(p: Vector2, relative: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = p
	event.global_position = p
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event, true)
func _press(p: Vector2, held: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = p
	event.global_position = p
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = held
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event, true)
func _drag(p: Vector2, distance: float) -> void:
	_motion(p, Vector2.ZERO, false)
	_press(p, true)
	await create_timer(0.15).timeout # Reproduce touch, hold, then drag on a card.
	for i in range(1, 9):
		_motion(p + Vector2(0, distance * i / 8.0), Vector2(0, distance / 8.0), true)
		await process_frame
	await create_timer(0.12).timeout
	_press(p + Vector2(0, distance), false)
	await create_timer(0.1).timeout
func _frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
func _buttons(node: Node) -> Array:
	var found: Array = []
	if node is Button: found.append(node)
	for child in node.get_children(): found.append_array(_buttons(child))
	return found
func _run() -> void:
	check(DisplayServer.is_touchscreen_available(), "Gesture test must run with native touchscreen emulation")
	var scene := PhoneScene.new()
	scene.services = MemoryServices.new()
	root.add_child(scene)
	scene.set_process(false)
	scene.world.set_process(false)
	scene.sound.enabled = false
	scene.sound.music_enabled = false
	for dimensions in [Vector2i(390,844), Vector2i(375,667)]:
		root.size = dimensions
		await _frame()
		scene._layout()
		scene._clear_overlay()
		scene.mode = "playing"
		scene._process(0)
		var logical: Vector2 = scene.get_viewport_rect().size
		for control in [scene.hud, scene.status, scene.build_button, scene.speed_button, scene.pause_button]:
			check(control.position.y >= 59, "All HUD controls must clear the simulated iPhone cutout")
		check(scene.hud.get_global_rect().end.y <= scene.build_button.get_global_rect().position.y, "HUD text must not overlap the top buttons")
		check(scene.field.position.y > scene.pause_button.get_global_rect().end.y, "Playfield begins below toolbar")
		for control in scene.ability_buttons.values():
			check(control.get_global_rect().end.y <= logical.y - 34, "Ability controls clear the home indicator")
		await _frame()
		root.get_texture().get_image().save_png("/tmp/starrun-visuals/notch-%d.png" % dimensions.x)
		scene.profile.cores = 10000
		scene._hangar_tab("Hull")
		await _frame()
		var wallet: int = scene.profile.cores
		var scroll: ScrollContainer = scene.hangar_scroll
		var buy: Button = _buttons(scroll)[0]
		await _drag(buy.get_global_rect().get_center(), -150)
		check(scroll.scroll_vertical > 60, "Holding and dragging a purchase button must scroll Hangar")
		check(scene.profile.cores == wallet, "Dragging a purchase button must not spend cores")
		var offset := scroll.scroll_vertical
		await _drag(scroll.get_global_rect().get_center(), 100)
		check(scroll.scroll_vertical < offset, "Menu drag must also work downward")
		scene._show_loadout()
		await _frame()
		scroll = scene.reading_scroll
		var card: Button = _buttons(scroll)[0]
		await _drag(card.get_global_rect().get_center(), -150)
		check(scroll.scroll_vertical > 60, "Holding and dragging a loadout card must scroll")
		check(scene.profile.cores == wallet and scene.confirm_key.is_empty(), "Dragging must not equip or arm an unlock")
		scene.sim = Sim.new(2750)
		scene.sim.stage = 3
		scene.sim.cards = []
		# Long real descriptions and all four options exercise an overflowing draft.
		for id in ["insulation", "ablative", "shield_surge", "opening_salvo"]:
			scene.sim.cards.append(scene.sim.content.cards.filter(func(c): return c.id == id)[0])
			scene.sim.upgrades[id] = 4
		scene._show_cards(false)
		scene.draft_guard = 0
		await _frame()
		scroll = scene.reading_scroll
		var hand: Array = scene.sim.cards.duplicate(true)
		var overflows: bool = scroll.get_child(0).size.y > scroll.size.y + 1.0
		await _drag(scene.card_buttons[1].get_global_rect().get_center(), -150)
		check((scroll.scroll_vertical > 0) == overflows, "A held draft card scrolls whenever its contents exceed the view")
		check(scene.mode == "cards" and scene.sim.cards == hand, "A draft drag must not choose an upgrade")
		# A stationary tap still selects after scrolling has stopped.
		scroll.scroll_vertical = 0
		await _frame()
		var p: Vector2 = scene.card_buttons[0].get_global_rect().get_center()
		_motion(p, Vector2.ZERO, false)
		_press(p, true)
		await process_frame
		_press(p, false)
		await _frame()
		check(scene.sim.upgrades.insulation == 6 and scene.mode == "playing", "A normal tap still picks the intended upgrade")
		scene.mode = "playing"
		scene._show_build()
		scene.build_show_all = true
		scene._show_build()
		await _frame()
		scroll = scene.reading_scroll
		await _drag(scroll.get_global_rect().get_center(), -150)
		check(scroll.scroll_vertical > 0, "Build details scroll from their text and card surfaces")
		check(scene.reading_panel.position.y >= 59, "Menus also respect the cutout")
	scene.queue_free()
	await process_frame
	print("TOUCH RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
