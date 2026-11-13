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
	check(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items", "Retina phones must use adaptive canvas stretching")
	check(ProjectSettings.get_setting("display/window/stretch/aspect") == "expand", "Phone aspect ratio must expand instead of letterboxing")
	check(ProjectSettings.get_setting("display/window/size/viewport_width") == 390, "Mobile reference width must remain 390 logical points")
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
		# Canvas Items uses logical coordinates: a 1170x2532 Retina display
		# reports roughly 390x844 UI points, not raw hardware pixels.
		var logical: Vector2 = scene.get_viewport_rect().size
		print("UI size physical=%s logical=%s" % [str(dimensions), str(logical)])
		check(scene.field.position.x >= 0 and scene.field.end.x <= logical.x, "Playfield must fit horizontally")
		check(scene.ability_a.get_global_rect().end.y <= logical.y, "Controls must fit below playfield")
		check(scene.ability_a.get_global_rect().end.x <= scene.ability_b.position.x, "Ability labels must not overlap at phone sizes")
		for button in scene.ability_buttons.values():
			check(button.get_global_rect().end.y <= logical.y and button.get_global_rect().position.x >= 0 and button.get_global_rect().end.x <= logical.x, "All six ability buttons must fit phone and desktop screens")
		check(scene.pause_button.get_global_rect().end.y < scene.field.position.y, "Pause must fit above the playfield")
		check(scene.build_button.get_global_rect().position.x >= 0 and scene.speed_button.get_global_rect().end.x <= logical.x, "Build and speed controls must fit narrow screens")
		if logical.x < 760:
			check(scene.hud.get_theme_font_size("font_size") >= 18, "Phone HUD must be readable")
			check(scene.status.get_theme_font_size("font_size") >= 16, "Phone timer must be readable")
			for control in [scene.build_button, scene.speed_button, scene.pause_button]:
				check(control.get_theme_font_size("font_size") >= 16, "Phone top controls must use >=16pt text")
				check(control.size.y >= 44, "Phone top controls need 44pt touch targets")
			for control in scene.ability_buttons.values():
				check(control.get_theme_font_size("font_size") >= 16, "Phone ability labels must use >=16pt text")
		check(scene.game_speed == 1.0 or scene.game_speed in scene.speed_options, "Speed setting must remain valid")
		var previous_speed: float = scene.game_speed
		scene._cycle_speed()
		check(scene.game_speed != previous_speed and scene.profile.speed == scene.game_speed, "Speed control must update the saved speed preference")
		scene.sim._offer_cards()
		scene._show_cards()
		await process_frame
		var center: Control = scene.overlay.get_child(1)
		var panel: Control = center.get_child(0)
		check(panel.get_global_rect().position.y >= 0 and panel.get_global_rect().end.y <= logical.y, "Card panel must fit the screen")
		scene.sim.cards.clear()
		scene._show_results()
		await process_frame
		center = scene.overlay.get_child(1)
		panel = center.get_child(0)
		check(panel.get_global_rect().position.y >= 0 and panel.get_global_rect().end.y <= logical.y, "Flight recorder must fit the screen")
		scene.profile.cores = 100
		for group in scene.Catalog.GROUPS:
			scene._hangar_tab(group)
			await process_frame
			await process_frame
			check(scene.hangar_scroll.size.y > 70 and scene.hangar_scroll.get_global_rect().end.y < logical.y - 40, "Each Hangar category must have usable scrolling space above the footer")
		scene.profile.cores = 1000
		scene._show_loadout()
		await process_frame
		check(scene.mode == "loadout", "Loadout selector must open from the Hangar")
		scene._select_loadout("ship", "wraith")
		check(scene.profile.ship == "wraith" and "wraith" in scene.profile.ships_owned, "Unlocking a ship must equip and persist ownership")
		scene._loadout_tab("Pilots")
		scene._select_loadout("pilot", "hunter")
		check(scene.profile.pilot == "hunter" and "hunter" in scene.profile.pilots_owned, "Unlocking a pilot must equip and persist ownership")
		scene._show_hangar()
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
		scene._new_run()
		check(scene.sim.ship_id == "wraith" and scene.sim.pilot_id == "hunter", "A new flight must use the equipped hull and pilot")
		scene._show_build()
		await process_frame
		check(scene.mode == "build", "Build inspection must pause combat and show equipped modules")
		scene._toggle_pause()
		check(scene.mode == "playing", "Closing the build view must resume combat")
	print("UI RESULT: %d checks, %d failures" % [checks, failures])
	scene.queue_free()
	await process_frame
	call_deferred("quit", 1 if failures else 0)
