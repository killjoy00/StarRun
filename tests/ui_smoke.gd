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
	create_timer(20.0).timeout.connect(_timeout)
	call_deferred("_run")

func _timeout() -> void:
	push_error("UI smoke checks did not finish within 20 seconds; inspect preceding runtime errors")
	quit(1)
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _unwrapped_long_label(node: Node) -> bool:
	if node is Label and node.text.length() > 70 and node.autowrap_mode == TextServer.AUTOWRAP_OFF:
		return true
	for child in node.get_children():
		if _unwrapped_long_label(child):
			return true
	return false

func _contains_text(node: Node, phrase: String) -> bool:
	if node is Label and str(node.text).contains(phrase):
		return true
	for child in node.get_children():
		if _contains_text(child, phrase):
			return true
	return false

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
	check(scene.ability_buttons.size() == 4 and scene.sim.active_slots.size() == 1, "Four mobile active slots, one occupied by the ship signature")
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
		check(scene.ability_a.get_global_rect().end.x <= scene.ability_b.position.x, "Ability buttons must not overlap")
		if logical.x < 760:
			check(scene.ability_buttons[0].position.y == scene.ability_buttons[3].position.y, "All four combat buttons should share one row on phones")
			check(scene.ability_buttons[0].size.x >= 75.0, "Phone combat buttons need usable width")
		for button in scene.ability_buttons.values():
			check(button.get_global_rect().end.y <= logical.y and button.get_global_rect().position.x >= 0 and button.get_global_rect().end.x <= logical.x, "Four equipped ability buttons must fit phone and desktop screens")
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
		check(scene.reading_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Results must wrap instead of forcing horizontal scrolling")
		check(scene.reading_scroll.size.y > 100, "Results report must preserve usable scrolling space")
		check(not _unwrapped_long_label(scene.reading_scroll), "Long results details must wrap on phone screens")
		for control in scene.reading_footer.get_children():
			check(control.get_global_rect().end.y < logical.y and control.size.y >= 44, "Report navigation must stay pinned and touchable at every size")
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
		check(scene.card_buttons.size() == (2 if logical.x < 760 else 4), "Phone draft should show two readable cards per page, desktop all four")
		if logical.x < 760:
			check(scene.reading_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Phone drafts should not need long vertical scrolling")
			var first_card_text: String = scene.card_buttons[0].text
			scene._draft_page(1)
			await process_frame
			check(scene.draft_page == 1 and scene.card_buttons.size() == 2 and scene.card_buttons[0].text != first_card_text, "Next button must reveal the other two choices without changing the hand")
			scene._draft_page(-1)
			await process_frame
			check(scene.draft_page == 0 and scene.card_buttons[0].text == first_card_text, "Previous button must return to the same choices")
		scene.sim.cards.clear()
		scene._new_run()
		check(scene.sim.ship_id == "wraith" and scene.sim.pilot_id == "hunter", "A new flight must use the equipped hull and pilot")
		scene._show_build()
		await process_frame
		check(scene.mode == "build", "Build inspection must pause combat and show equipped modules")
		check(_contains_text(scene.reading_scroll, "Active abilities"), "Build should show equipped buttons before the optional long equipment list")
		check(scene.reading_panel.get_global_rect().end.y <= logical.y and scene.reading_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Build summary must fit and wrap on mobile")
		check(scene.reading_scroll.size.y > 100, "Build cards must scroll in usable area")
		for control in scene.reading_footer.get_children():
			check(control.get_global_rect().end.y < logical.y and control.size.y >= 44, "Resume and main-menu buttons must stay on screen")
		check(not _unwrapped_long_label(scene.reading_scroll), "Build descriptions must use word wrapping")
		scene._toggle_pause()
		check(scene.mode == "playing", "Closing the build view must resume combat")
	scene._show_menu()
	var old_difficulty: String = str(scene.profile.difficulty)
	scene._cycle_difficulty()
	check(scene.profile.difficulty != old_difficulty, "Menu difficulty selector must advance")
	scene._new_run()
	check(scene.sim.difficulty == scene.profile.difficulty and scene.sim.active_slots.size() == 1, "Difficulty and signature ability must apply to the next flight")
	scene._show_build()
	var preserved: Dictionary = scene.sim.snapshot()
	scene._build_to_menu()
	check(scene.mode == "menu" and not scene.services.read_save(scene.Services.RUN).is_empty(), "Main menu must be one tap away without discarding the suspended flight")
	scene._resume_run()
	check(scene.sim.snapshot() == preserved, "Returning from Build through the menu must exactly preserve the flight")
	var themes := {}
	for stage_id in range(1, 5):
		scene.sim.stage = stage_id
		scene.world.sim = scene.sim
		themes[scene.world._visual_theme_id()] = true
	check(themes.size() == 4, "All four stages need distinct visual themes")
	scene.sim.stage = 1
	scene.sim.stage_clears = 0
	scene.sim._spawn_boss()
	scene.sim._damage_enemy(scene.sim.enemies[0], 999999.0, "pulse")
	scene._show_stage_clear()
	check(scene.mode == "stage_clear" and scene.stage_clear_button.disabled, "Boss ceremony must be acknowledged and briefly display its explosion")
	scene.stage_clear_clock = 1.5
	scene._show_stage_clear(false)
	check(not scene.stage_clear_button.disabled, "Warp button must become available after the celebration")
	scene._begin_warp()
	check(scene.mode == "warp", "One click should begin a distinct warp animation")
	scene._complete_warp()
	check(scene.sim.stage == 1 and scene.mode == "prototype" and scene.sim.prototype_offers.size() == 3, "Warp must first present three irreversible Prototype choices")
	await process_frame
	check(scene.reading_scroll.size.y > 100 and scene.reading_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Prototype choice must be readable and scroll vertically")
	check(not _unwrapped_long_label(scene.reading_scroll), "Prototype descriptions and drawbacks must wrap")
	var preserved_hand: Array = scene.sim.prototype_offers.duplicate()
	scene._show_menu()
	scene._resume_run()
	check(scene.mode == "prototype" and scene.sim.prototype_offers == preserved_hand, "Menu/resume must preserve the exact intermission Prototype hand")
	scene._choose_prototype(0)
	check(scene.mode == "route" and scene.sim.prototypes.size() == 1, "Prototype selection must advance to the strategic route screen")
	check(_contains_text(scene.reading_scroll, "REPAIR") and _contains_text(scene.reading_scroll, "MORE DAMAGE") and _contains_text(scene.reading_scroll, "BOUNTY RUN"), "Every strategic route must render after the prototype choice")
	check(_contains_text(scene.reading_scroll, "No extra rewards") and _contains_text(scene.reading_scroll, "25%") and _contains_text(scene.reading_scroll, "30%"), "Every route must explain its actual benefit and cost in plain language")
	await process_frame
	check(scene.reading_scroll.size.y > 100 and not _unwrapped_long_label(scene.reading_scroll), "Route alternatives must wrap on phone-sized viewports")
	scene._show_menu()
	scene._resume_run()
	check(scene.mode == "route" and scene.sim.prototypes.size() == 1, "Suspending during route selection must not duplicate Prototype rewards")
	scene._choose_route("overclock")
	check(scene.sim.stage == 2 and scene.mode == "cards" and is_equal_approx(scene.sim.stage_power, 1.25), "Selecting Overclock must start Stage 2 with reduced shields and its stronger weapons")
	scene.sim.cards.clear()
	scene.mode = "playing"
	scene._show_build()
	await process_frame
	check(_contains_text(scene.reading_scroll, "PROTOTYPE") and _contains_text(scene.reading_scroll, "Current route:"), "Build screen must explain acquired Prototype and route tradeoffs")
	scene._toggle_pause()
	scene.sim.stage = 4
	scene.sim.stage_clears = 4
	scene.sim.stage_transition_queued = true
	scene._show_stage_clear()
	scene.stage_clear_clock = 1.5
	scene._show_stage_clear(false)
	scene._begin_warp()
	check(scene.mode == "results" and scene.sim.won, "Claiming the final boss victory should open the readable report")
	check(scene.reading_footer.get_child_count() == 2, "Results must offer both Fly Again and Main Menu actions")
	print("UI RESULT: %d checks, %d failures" % [checks, failures])
	scene.queue_free()
	await process_frame
	call_deferred("quit", 1 if failures else 0)
