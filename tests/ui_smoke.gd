extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.sound.enabled = false
	scene.sound.music_enabled = false
	await process_frame
	# Avoid changing a real player's checkpoint when inspecting draft and result panels.
	scene.sim.ended = true
	for dimensions in [Vector2i(375, 667), Vector2i(390, 844), Vector2i(1280, 800)]:
		root.size = dimensions
		await process_frame
		await process_frame
		scene._layout()
		scene._update_hud()
		check(scene.field.position.x >= 0 and scene.field.end.x <= dimensions.x, "Playfield must fit horizontally")
		check(scene.ability_a.get_global_rect().end.y <= dimensions.y, "Controls must fit below playfield")
		check(scene.ability_a.get_global_rect().end.x <= scene.ability_b.position.x, "Ability labels must not overlap at phone sizes")
		check(scene.ability_b.get_global_rect().end.x <= scene.pause_button.position.x, "Nova must not overlap pause")
		scene.sim._offer_cards()
		scene._show_cards()
		await process_frame
		var center: Control = scene.overlay.get_child(1)
		var panel: Control = center.get_child(0)
		check(panel.get_global_rect().position.y >= 0 and panel.get_global_rect().end.y <= dimensions.y, "Card panel must fit the screen")
		scene.sim.cards.clear()
		scene._show_results()
		await process_frame
		center = scene.overlay.get_child(1)
		panel = center.get_child(0)
		check(panel.get_global_rect().position.y >= 0 and panel.get_global_rect().end.y <= dimensions.y, "Flight recorder must fit the screen")
	print("UI RESULT: %d checks, %d failures" % [checks, failures])
	scene.queue_free()
	await process_frame
	call_deferred("quit", 1 if failures else 0)
