extends SceneTree
class MemoryServices extends "res://scripts/platform_services.gd":
	var values: Dictionary = {}
	func write_atomic(path: String, value: Dictionary) -> bool:
		values[path] = value.duplicate(true)
		return true
	func read_save(path: String) -> Dictionary:
		return values.get(path, {})
	func delete_run() -> void:
		values.erase(RUN)
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
	scene.services = MemoryServices.new()
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
		for button in scene.ability_buttons.values():
			check(button.get_global_rect().end.y <= dimensions.y and button.get_global_rect().position.x >= 0 and button.get_global_rect().end.x <= dimensions.x, "All six ability buttons must fit phone and desktop screens")
		check(scene.pause_button.get_global_rect().end.y < scene.field.position.y, "Pause must fit above the playfield")
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
		scene.profile.cores = 100
		for group in scene.Catalog.GROUPS:
			scene._hangar_tab(group)
			await process_frame
			await process_frame
			check(scene.hangar_scroll.size.y > 70 and scene.hangar_scroll.get_global_rect().end.y < dimensions.y - 40, "Each Hangar category must have usable scrolling space above the footer")
		var paid: int = scene.profile.cores
		scene._purchase("shield")
		check(scene.profile.hangar.shield > 0 and scene.profile.cores < paid, "Hangar purchase must update the wallet and installed ranks")
		scene._respec()
		check(scene.profile.cores == paid, "Refund must return every spent core through the UI flow")
		scene.sim.meta.extra_card = 1
		scene.sim.banishes_left = 1
		scene.sim.rerolls_left = 1
		scene.sim._offer_cards()
		scene._show_cards()
		await process_frame
		check(scene.card_buttons.size() == 4, "Four-card drafts must render all choices alongside draft tools")
		scene.sim.cards.clear()
	print("UI RESULT: %d checks, %d failures" % [checks, failures])
	scene.queue_free()
	await process_frame
	call_deferred("quit", 1 if failures else 0)
