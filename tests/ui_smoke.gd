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
	if node is RichTextLabel and node.get_parsed_text().contains(phrase):
		return true
	if node is Button and str(node.text).contains(phrase):
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
		check(scene.hull_meter.value == 100.0 and scene.shield_meter.value == 100.0, "Full hull and shield must fill both HUD bars")
		check(scene.hull_caption.text.begins_with("HULL") and scene.shield_caption.text.begins_with("SHIELD"), "Meters must be labeled with current and max values")
		check(scene.hull_meter.get_global_rect().end.x < scene.shield_meter.get_global_rect().position.x, "Hull and shield meters must have a visible gap")
		check(scene.ability_buttons[0].get_child(0).visible and scene.cooldown_meters[0].value == 100.0, "Ability insignia and ready-state cooldown bar must be visible")
		if logical.x < 760:
			check(scene.hud.get_global_rect().end.x < scene.build_button.get_global_rect().position.x, "Combat heading must not overlap Build")
			check(scene.status.get_global_rect().end.x < scene.build_button.get_global_rect().position.x, "Timer must not overlap Build")
			check(scene.ability_buttons[0].position.y == scene.ability_buttons[3].position.y, "All four combat buttons should share one row on phones")
			check(scene.ability_buttons[0].size.x >= 75.0, "Phone combat buttons need usable width")
		for button in scene.ability_buttons.values():
			var bounds: Rect2 = button.get_global_rect()
			if bounds.end.y > logical.y or bounds.position.x < 0 or bounds.end.x > logical.x:
				print("HUD_BUTTON_OOB logical=%s position=%s size=%s" % [str(logical), str(bounds.position), str(bounds.size)])
			check(bounds.end.y <= logical.y and bounds.position.x >= 0 and bounds.end.x <= logical.x, "Four equipped ability buttons must fit phone and desktop screens")
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
		var panel: Control = scene.reading_panel
		check(panel.get_global_rect().position.y >= 0 and panel.get_global_rect().end.y <= logical.y, "Card panel must fit the screen")
		scene.sim.cards.clear()
		scene._show_results()
		await process_frame
		panel = scene.reading_panel
		check(panel.get_global_rect().position.y >= 0 and panel.get_global_rect().end.y <= logical.y, "Flight recorder must fit the screen")
		check(scene.reading_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Results must wrap instead of forcing horizontal scrolling")
		check(scene.reading_scroll.size.y > 100, "Results report must preserve usable scrolling space")
		check(not _unwrapped_long_label(scene.reading_scroll), "Long results details must wrap on phone screens")
		for control in scene.reading_footer.get_children():
			check(control.get_global_rect().end.y < logical.y and control.size.y >= 44, "Report navigation must stay pinned and touchable at every size")
		scene._show_menu()
		await process_frame
		check(not scene.hud.visible and not scene.ability_a.visible, "Combat HUD must not show through the title screen")
		check(_contains_text(scene.overlay, "Star/Run"), "The title must display the requested Star/Run wordmark")
		check(_contains_text(scene.overlay, "DAILY CHALLENGE") and _contains_text(scene.overlay,"UTC"), "The title must advertise a UTC Daily Challenge")
		check(_contains_text(scene.overlay, "Awards"), "Achievements must be discoverable from the title")
		check(scene.reading_panel.get_global_rect().end.y <= logical.y and scene.reading_footer.get_child(0).size.y >= 56, "Title must fit with a large launch button at the bottom")
		scene._show_achievements()
		await process_frame
		check(scene.mode == "achievements" and _contains_text(scene.reading_scroll, "First Debrief"), "The achievements page lists locked milestones")
		check(scene.reading_panel.get_global_rect().end.y <= logical.y and scene.reading_scroll.size.y > 100 and scene.reading_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Achievements page must wrap and scroll at every viewport")
		scene._show_menu()
		for sheet in ["settings", "briefing", "pause"]:
			if sheet == "settings":
				scene._show_settings()
			elif sheet == "briefing":
				scene._show_briefing(false)
			else:
				scene.mode = "playing"
				scene._show_pause()
			await process_frame
			await process_frame
			var rect: Rect2 = scene.reading_panel.get_global_rect()
			check(rect.position.y >= 0 and rect.end.y <= logical.y + 1.0 and rect.size.y > 120, "%s sheet must be fully on screen" % sheet)
		scene._show_menu()
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
		scene.profile.ships_owned = ["vanguard"]
		scene.profile.ship = "vanguard"
		scene._loadout_tap("ship", "wraith")
		check(scene.profile.ship != "wraith" and "wraith" not in scene.profile.ships_owned, "Permanent unlocks must not spend cores on the first tap")
		scene._loadout_tap("ship", "wraith")
		check(scene.profile.ship == "wraith" and "wraith" in scene.profile.ships_owned, "Unlocking a ship must equip and persist ownership")
		scene._loadout_tab("Pilots")
		scene._select_loadout("pilot", "hunter")
		check(scene.profile.pilot == "hunter" and "hunter" in scene.profile.pilots_owned, "Unlocking a pilot must equip and persist ownership")
		scene._show_hangar()
		var paid: int = scene.profile.cores
		scene._purchase("shield")
		check(scene.profile.hangar.shield > 0 and scene.profile.cores < paid, "Hangar purchase must update the wallet and installed ranks")
		scene._refund_tap()
		check(scene.profile.hangar.shield > 0, "Refund all must ask for a second tap")
		scene._refund_tap()
		check(scene.profile.cores == paid, "Refund must return every spent core through the UI flow")
		scene.sim.meta.extra_card = 1
		scene.sim.banishes_left = 1
		scene.sim.rerolls_left = 1
		scene.sim._offer_cards()
		scene._show_cards()
		await process_frame
		await process_frame
		check(scene.card_buttons.size() == 4 and scene.sim.cards.size() == 4, "Every draft option must be visible together so choices can be compared")
		var last_card: Rect2 = scene.card_buttons[3].get_global_rect()
		check(last_card.end.y <= scene.reading_scroll.get_global_rect().end.y + 1.0, "A four-card draft must fit without scrolling")
		for control in scene.reading_footer.get_children():
			check(control.size.y >= 44 and control.get_global_rect().end.y <= logical.y, "Draft tools must be touchable and on screen")
		var hand: int = scene.sim.cards.size()
		scene.draft_guard = 0.3
		scene._choose(0)
		check(scene.mode == "cards" and scene.sim.cards.size() == hand, "A tap landing as the draft opens must not pick a card")
		scene._toggle_banish()
		check(scene.banish_mode and scene.mode == "cards", "Remove must enter an explicit pick-to-remove mode")
		scene._toggle_banish()
		check(not scene.banish_mode, "Cancel must leave remove mode without spending a removal")
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
	scene._set_difficulty("hard")
	check(scene.profile.difficulty == "hard", "Difficulty segments must select directly")
	var old_difficulty: String = str(scene.profile.difficulty)
	scene._cycle_difficulty()
	check(scene.profile.difficulty != old_difficulty, "Menu difficulty selector must advance")
	scene._launch_or_confirm("menu")
	check(scene.mode == "abandon" and not scene.services.read_save(scene.Services.RUN).is_empty(), "Launching over a saved flight must ask before deleting it")
	scene._close_sheet()
	check(scene.mode == "menu", "Cancelling the abandon prompt must return to the title")
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
	check(_contains_text(scene.reading_scroll, "Repair") and _contains_text(scene.reading_scroll, "More damage") and _contains_text(scene.reading_scroll, "Bounty run"), "Every strategic route must render after the prototype choice")
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
	check(_contains_text(scene.reading_scroll, "Prototype") and _contains_text(scene.reading_scroll, "Current route:"), "Build screen must explain acquired Prototype and route tradeoffs")
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
	# Daily launch is a separate mode but uses the same single checkpoint slot.
	scene._show_menu()
	var daily_id: String = scene.Progress.utc_day()
	var daily_expected: Dictionary = scene.Progress.daily_setup(daily_id)
	scene._launch_daily()
	check(scene.sim.daily_day == daily_id and scene.sim.daily_attempt == 1, "Daily launch stores an immutable UTC date and attempt")
	check(scene.sim.seed_value == int(daily_expected.seed) and scene.sim.ship_id == str(daily_expected.ship) and scene.sim.pilot_id == str(daily_expected.pilot), "A Daily always uses the global day's ship, pilot, seed and difficulty")
	check(scene.sim.difficulty == "normal" and scene.sim.meta.damage == 0 and scene.sim.meta.hull == 0, "Daily ignores owned Hangar bonuses without wiping the real profile")
	var daily_snapshot: Dictionary = scene.sim.snapshot()
	scene._show_menu()
	scene._resume_run()
	check(scene.sim.snapshot() == daily_snapshot, "Daily resume restores the exact date, build and RNG")
	scene._show_menu()
	scene._launch_daily()
	check(scene.mode == "abandon" and scene.pending_launch == "daily", "Starting another Daily with a saved flight requires abandonment confirmation")
	scene._close_sheet()
	check(scene.mode == "menu", "Cancelling Daily abandonment returns to title without deleting progress")
	scene._resume_run()
	check(scene.sim.snapshot() == daily_snapshot, "Cancelled Daily abandonment preserves the first run")
	scene.sim.stage = 4
	scene.sim.stage_clears = 4
	scene.sim.stage_transition_queued = true
	scene._show_stage_clear()
	scene.stage_clear_clock = 1.5
	scene._show_stage_clear(false)
	check(scene.stage_clear_secondary == null or not scene.stage_clear_secondary.is_inside_tree(), "Daily must not offer endless scoring after World 4")
	var stage_before: int = scene.sim.stage
	scene._continue_endless()
	check(scene.sim.stage == stage_before and not scene.sim.endless_enabled, "Daily scoring cannot enter Endless mode")
	scene._begin_warp()
	check(scene.sim.won and scene.mode == "results" and scene.profile.daily_records.has(daily_id), "Settling the Daily saves the best result locally")
	check(scene.profile.achievements.has("daily_first"), "Finishing a Daily earns its permanent achievement")
	check(_contains_text(scene.reading_scroll, "DAILY CHALLENGE"), "Daily results show score, UTC identity and personal best")
	print("UI RESULT: %d checks, %d failures" % [checks, failures])
	scene.queue_free()
	await process_frame
	call_deferred("quit", 1 if failures else 0)
