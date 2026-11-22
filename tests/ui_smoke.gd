extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
class MemoryServices extends "res://scripts/platform_services.gd":
	var values: Dictionary = {}
	func write_atomic(path: String, value: Dictionary) -> bool:
		values[path] = value.duplicate(true)
		return true
	func read_save(path: String) -> Dictionary:
		return values.get(path, {})
	func delete_run() -> void:
		values.erase(RUN)
class NativeShareMock extends RefCounted:
	var payload: Dictionary = {}
	var response: int = OK
	func share(data: Dictionary) -> int:
		payload = data.duplicate(true)
		return response

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

func _merchant_panels_within_screen(parent: Node, screen_width: float) -> bool:
	for panel in parent.find_children("*","PanelContainer",true,false):
		if panel is Control:
			var rect: Rect2 = panel.get_global_rect()
			if rect.position.x < 7.0 or rect.end.x > screen_width - 7.0:
				return false
	return true

# Regression guard for phone width regressions caused by intrinsic grid/chip
# sizes. Verify the actual Godot card rectangles, not only text wrap flags.
func _choice_panels_within_screen(parent: Node, screen_width: float) -> bool:
	var matched := 0
	for panel in parent.find_children("*", "PanelContainer", true, false):
		if not (panel.name.begins_with("ArtifactOption") or panel.name.begins_with("PrototypeChoice") or panel.name.begins_with("RouteChoice") or panel.name.begins_with("EvolutionChoice") or panel.name.begins_with("FusionChoice")):
			continue
		matched += 1
		var rect: Rect2 = panel.get_global_rect()
		if rect.position.x < 21.0 or rect.end.x > screen_width - 21.0 or rect.size.x < 180.0:
			print("CHOICE_CARD_OOB %s width=%.1f rect=%s" % [panel.name, screen_width, str(rect)])
			return false
	return matched > 0

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
	check(is_instance_valid(scene.remove_ads_store), "Remove Ads StoreKit adapter must initialize without loading native SDKs on desktop")
	check(not scene.remove_ads_store.product_available and not scene.remove_ads_store.store_ready, "No fake or chargeable purchases may appear on a desktop build")
	check(not scene.remove_ads_store._grant_verified({"productId": "wrong.product", "store": "apple"}, false), "A different product cannot grant an ad-free entitlement")
	check(not scene.remove_ads_store._grant_verified({"productId": scene.remove_ads_store.PRODUCT_ID, "store": "fake"}, false), "Only actual Apple StoreKit transactions can grant Remove Ads")
	check(not bool(scene.profile.get("remove_ads", false)), "Invalid purchases cannot modify a saved user's entitlements")
	# Avoid changing a real player's checkpoint when inspecting draft and result panels.
	scene.sim.ended = true
	check(scene.ability_buttons.size() == 4 and scene.sim.active_slots.size() == 1, "Four mobile active slots, one occupied by the ship signature")
	for dimensions in [Vector2i(360, 740), Vector2i(375, 667), Vector2i(390, 844), Vector2i(1280, 800)]:
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
		for control in [scene.build_button, scene.speed_button, scene.pause_button]:
			for meter in [scene.hull_meter, scene.shield_meter]:
				check(not control.get_global_rect().intersects(meter.get_global_rect()), "Toolbar buttons must not cover hull/shield meters")
		var base_style: StyleBoxFlat = scene.ability_buttons[0].get_theme_stylebox("normal")
		var other_style: StyleBoxFlat = scene.ability_buttons[1].get_theme_stylebox("normal")
		check(base_style.bg_color == other_style.bg_color and base_style.border_color == other_style.border_color, "First ability must not have a default highlight")
		check(scene.ability_buttons[0].get_child(0).visible and scene.cooldown_meters[0].value == 100.0, "Ability insignia and cooldown progress remain initialized")
		check(not scene.cooldown_meters[0].visible, "A ready ability should not look preselected through a full amber progress bar")
		var signature: String = str(scene.sim.active_slots[0])
		scene.sim.cooldowns[signature] = 4.0
		scene._update_hud()
		check(scene.cooldown_meters[0].visible and scene.ability_buttons[0].get_node("AbilityStatus").text.contains("s"), "Cooldown progress appears when the equipped ability is recovering")
		scene.sim.cooldowns[signature] = 0.0
		scene._update_hud()
		if logical.x < 760:
			check(scene.hud.get_global_rect().end.x < scene.build_button.get_global_rect().position.x, "Combat heading must not overlap Build")
			check(scene.status.get_global_rect().end.x < scene.build_button.get_global_rect().position.x, "Timer must not overlap Build")
			check(scene.ability_buttons[0].position.y == scene.ability_buttons[3].position.y, "All four combat buttons should share one row on phones")
			check(scene.ability_buttons[0].size.x >= 75.0, "Phone combat buttons need usable width")
		for button in scene.ability_buttons.values():
			var icon: Control = button.get_child(0)
			var name_label: Label = button.get_node("AbilityName")
			var ready_label: Label = button.get_node("AbilityStatus")
			var progress: ProgressBar = scene.cooldown_meters[scene.ability_buttons.find_key(button)]
			check(button.text.is_empty() and not name_label.get_global_rect().intersects(ready_label.get_global_rect()), "Ability name and READY/cooldown text occupy distinct rows")
			check(not name_label.get_global_rect().intersects(icon.get_global_rect()) and not ready_label.get_global_rect().intersects(icon.get_global_rect()), "Ability icons never overlap their text")
			check(not ready_label.get_global_rect().intersects(progress.get_global_rect()), "Ability status text stays above the cooldown progress")
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
		check(_contains_text(scene.overlay, "Daily ·") and _contains_text(scene.overlay, "UTC"), "The title must still show the Daily date and UTC reset")
		check(_contains_text(scene.overlay, "Normal, no Hangar"), "The Daily must clearly disclose its fixed difficulty and lack of Hangar upgrades")
		check(not _contains_text(scene.overlay, "BUILD  /  REACT  /  REPEAT"), "The title must not add a marketing slogan above the playable choices")
		var wordmark: Control = scene.overlay.find_child("StarRunWordmark", true, false)
		var title_wallet: Control = scene.overlay.find_child("TitleWallet", true, false)
		var settings: Control = scene.overlay.find_child("TitleSettings", true, false)
		var art: Control = scene.overlay.find_child("ShipArtSlot", true, false)
		var selected_ship: Control = scene.overlay.find_child("SelectedShipArt", true, false)
		var strip: Control = scene.overlay.find_child("SelectedLoadoutStrip", true, false)
		var selected_pilot: Control = scene.overlay.find_child("SelectedPilotPortrait", true, false)
		var change_loadout: Control = scene.overlay.find_child("ChangeLoadout", true, false)
		check(wordmark != null and title_wallet != null and settings != null, "Title heading, wallet and settings must stay discoverable")
		check(art != null and selected_ship != null and strip != null and selected_pilot != null and change_loadout != null, "Art and ship/pilot controls must use independent, named rows")
		if art != null and selected_ship != null and strip != null and selected_pilot != null and change_loadout != null:
			check(art.size.x > 120.0 and selected_ship.size.y >= 100.0, "Title must preserve a visible ship preview, not shrink its artwork to zero")
			check(not art.get_global_rect().intersects(strip.get_global_rect()), "Ship artwork and pilot/ship names must never overlap at any viewport")
			check(strip.get_global_rect().has_point(selected_pilot.get_global_rect().get_center()) and strip.get_global_rect().has_point(change_loadout.get_global_rect().get_center()), "Pilot portrait and Change action must fit inside their own strip")
			check(change_loadout.size.y >= 44.0, "Changing ship or pilot must remain a phone-sized tap target")
		if wordmark != null and title_wallet != null and settings != null:
			check(not wordmark.get_global_rect().intersects(title_wallet.get_global_rect()), "Title name must not overlap the Core wallet")
			check(not title_wallet.get_global_rect().intersects(settings.get_global_rect()), "Core wallet must not overlap Settings")
			check(settings.get_global_rect().end.x <= logical.x - 8.0, "Settings must remain inside the screen")
		check(_contains_text(scene.overlay, "Change") and _contains_text(scene.overlay, "Play daily"), "Selecting a ship or pilot and starting a Daily must remain obvious")
		check(_contains_text(scene.overlay, "Awards"), "Achievements must be discoverable from the title")
		check(_contains_text(scene.overlay, "Rivals"), "A local captain journal is discoverable from the title")
		check(scene.overlay.find_child("ArtifactStandard", true, false) == null, "Artifact buttons must not clutter the title screen")
		scene._open_loadout("menu")
		scene._loadout_tab("Artifacts")
		await process_frame
		check(scene.mode == "loadout" and _contains_text(scene.overlay, "Standard") and _contains_text(scene.overlay, "Glass Fleet") and _contains_text(scene.overlay, "Drone Armada"), "Artifacts must be discoverable beside Ships and Pilots, with full names")
		var standard_label: Label = scene.overlay.find_child("ArtifactTitleStandard", true, false)
		check(standard_label != null and standard_label.text == "Standard", "Standard artifact must render as a complete, independent label")
		if standard_label != null:
			var word_width := standard_label.get_theme_font("font").get_string_size("Standard", HORIZONTAL_ALIGNMENT_LEFT, -1, standard_label.get_theme_font_size("font_size")).x
			check(standard_label.size.x >= word_width, "The word Standard must have enough measured width to display in full")
		check(_choice_panels_within_screen(scene.overlay, logical.x), "Artifact cards must fit inside narrow-phone margins")
		scene._set_artifact("glass_fleet")
		check(str(scene.profile.artifact) == "glass_fleet" and _contains_text(scene.overlay, "Half hull"), "Choosing an Artifact must persist and explain its rules")
		scene._set_artifact("standard")
		check(str(scene.profile.artifact) == "standard", "Standard must restore ordinary flight rules")
		scene._loadout_back()
		check(scene.mode == "menu", "Done returns to the uncluttered title")
		var previous_sim: RefCounted = scene.sim
		var past := Sim.new(95800)
		past.last_killing_source = "gunship"
		var record: Dictionary = scene.RivalCaptains._generated(past,1,1)
		scene.profile.rival_active = record.duplicate(true)
		scene.sim = Sim.new(95803)
		scene.sim.configure_rival(record)
		scene.sim._try_spawn_rival()
		scene._show_rival_intro()
		await process_frame
		var picture: Control = scene.overlay.find_child("RivalCutscenePortrait", true, false)
		check(scene.mode == "rival_intro" and _contains_text(scene.overlay, "RIVAL SIGHTED!") and _contains_text(scene.overlay, "!  RIVAL"), "Rival reveal displays warning, portrait and exclamation without advancing gameplay")
		check(picture != null and picture.size.x >= 100 and scene.reading_panel.get_global_rect().end.y <= logical.y + 1.0, "Portrait warning fits mobile and desktop safe areas")
		scene._dismiss_rival_stinger()
		check(scene.mode == "playing" and not scene.sim.rival_intro_pending, "Engage resumes combat and persists cutscene acknowledgment")
		scene.sim.rival_outcome = "retired"
		scene.sim.rival_retire_pending = true
		scene._show_rival_retired()
		await process_frame
		check(scene.mode == "rival_retired" and _contains_text(scene.overlay, "RIVAL DEFEATED!") and scene.profile.rival_trophies.size() == 1, "Retirement reveal gives a cosmetic trophy once")
		scene._dismiss_rival_stinger()
		scene._show_rival_journal()
		await process_frame
		check(scene.mode == "rival_journal" and _contains_text(scene.overlay, "Beaten (1)") and _contains_text(scene.overlay, str(record.name)), "Journal shows the named captain and retirement history")
		check(scene.reading_panel.get_global_rect().end.y <= logical.y + 1.0 and scene.reading_scroll.size.y > 100, "Journal scroll and footer remain inside the phone display")
		var merchant := Sim.new(55020)
		scene.sim = merchant
		merchant.enable_merchant()
		merchant.stage = 2
		merchant.time = 80.0
		merchant.merchant_next_at = 70.0
		check(merchant._try_merchant_signal(), "Merchant fixture starts from a genuine opt-in mid-flight signal")
		scene._show_merchant_signal()
		await process_frame
		var quartermaster: Control = scene.overlay.find_child("MerchantHailPortrait", true, false)
		check(scene.mode == "merchant_signal" and quartermaster != null and quartermaster.size.x >= 100.0 and _contains_text(scene.overlay, "Hail freighter"), "Merchant signal displays bespoke ship art and an explicit hail decision")
		check(scene.reading_panel.get_global_rect().end.y <= logical.y + 1.0 and _merchant_panels_within_screen(scene.overlay, logical.x), "Merchant hail portrait and bordered cards fit both edges of the phone")
		scene._merchant_hail()
		await process_frame
		check(scene.mode == "merchant_shop" and _contains_text(scene.overlay, "Quartermaster") and _contains_text(scene.overlay, "Leave without a deal"), "Market displays real offers, an exit and no forced purchase")
		check(scene.reading_panel.get_global_rect().end.y <= logical.y + 1.0 and scene.reading_scroll.size.y > 100 and _merchant_panels_within_screen(scene.overlay, logical.x), "Merchant trade cards scroll without horizontal clipping on narrow phones")
		var starting_shield: float = merchant.max_shield
		scene._merchant_preview("pact")
		await process_frame
		check(scene.mode == "merchant_confirm" and _contains_text(scene.overlay, "Confirm this trade") and is_equal_approx(merchant.max_shield,starting_shield) and _merchant_panels_within_screen(scene.overlay,logical.x), "Confirmation keeps the irreversible cost visible and the content on screen")
		scene._merchant_back()
		check(scene.mode == "merchant_shop" and is_equal_approx(merchant.max_shield,starting_shield), "Declining confirmation has no effect")
		scene._merchant_preview("pact")
		scene._merchant_accept()
		await process_frame
		check(scene.mode == "merchant_receipt" and merchant.merchant_trade_count == 1 and merchant.max_shield < starting_shield, "Accepting a deal charges exactly once and displays a receipt")
		check(scene.reading_panel.get_global_rect().end.y <= logical.y + 1.0 and _merchant_panels_within_screen(scene.overlay,logical.x), "Merchant receipt fits narrow phones without truncating deal details")
		scene._merchant_resume()
		check(scene.mode == "playing" and merchant.merchant_state.is_empty(), "Returning from the merchant unpauses gameplay")
		scene.sim = previous_sim
		scene.profile.rival_active = {}
		scene.profile.rival_archive = []
		scene.profile.rival_trophies = []
		scene.services.delete_run()
		scene._show_menu()
		check(scene.reading_panel.get_global_rect().end.y <= logical.y and scene.reading_footer.get_child(0).size.y >= 56, "Title must fit with a large launch button at the bottom")
		scene._show_achievements()
		await process_frame
		check(scene.mode == "achievements" and _contains_text(scene.reading_scroll, "FIRST DEBRIEF"), "The achievements page lists locked milestones")
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
		for card in scene.sim.content.cards:
			scene.sim.upgrades[str(card.id)] = int(card.max)
		scene.sim._offer_cards(false)
		scene._show_cards(false)
		await process_frame
		check(scene.sim.cards.size() == 2 and _contains_text(scene.reading_scroll, "Field repair") and _contains_text(scene.reading_scroll, "Salvage Cores"), "Full builds show repair and the Core reward together")
		check(scene.reading_footer.get_child_count() == 0, "Full builds should not show useless reroll/removal tools")
		scene.draft_guard = 0.0
		var core_before: int = scene.sim.choice_cores
		scene._choose(1)
		check(scene.mode == "playing" and scene.sim.choice_cores == core_before + 5, "The maxed draft Core reward works through the actual UI action")
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
	scene._set_artifact("glass_fleet")
	check(str(scene.profile.artifact) == "glass_fleet" and _contains_text(scene.overlay, "Half hull"), "Regular flight artifact selection must persist and explain its tradeoff")
	scene._set_artifact("standard")
	check(str(scene.profile.artifact) == "standard", "Returning to Standard must remove the optional rule set")
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
	check(_contains_text(scene.reading_footer, "Skip prototype") and _contains_text(scene.reading_footer, "10 Cores"), "Prototype draft must offer a visible Core alternative")
	var before_skip: Dictionary = scene.sim.snapshot()
	scene._skip_prototype()
	check(scene.mode == "route" and scene.sim.prototypes.is_empty() and scene.sim.choice_cores == 10, "Skipping through the UI banks Cores and opens the route")
	check(scene.sim.restore(before_skip), "UI smoke can restore the original prototype hand to test installing it")
	scene._show_prototypes()
	scene._choose_prototype(0)
	check(scene.mode == "route" and scene.sim.prototypes.size() == 1, "Prototype selection must advance to the strategic route screen")
	check(_contains_text(scene.reading_scroll, "Shielded passage") and _contains_text(scene.reading_scroll, "Redline assault") and _contains_text(scene.reading_scroll, "Hunter contract"), "Every strategic route must render after the prototype choice")
	check(_contains_text(scene.reading_scroll, "70%") and _contains_text(scene.reading_scroll, "35% less damage") and _contains_text(scene.reading_scroll, "+15% gun damage") and _contains_text(scene.reading_scroll, "above half") and _contains_text(scene.reading_scroll, "One extra upgrade"), "Each route must explain its current benefit, shield threshold, and tradeoff in plain language")
	await process_frame
	check(scene.reading_scroll.size.y > 100 and not _unwrapped_long_label(scene.reading_scroll), "Route alternatives must wrap on phone-sized viewports")
	scene._show_menu()
	scene._resume_run()
	check(scene.mode == "route" and scene.sim.prototypes.size() == 1, "Suspending during route selection must not duplicate Prototype rewards")
	scene._choose_route("overclock")
	check(scene.sim.stage == 2 and scene.mode == "cards" and is_equal_approx(scene.sim.stage_power, 1.35) and is_equal_approx(scene.sim.stage_fire_rate, 1.20), "Selecting Overclock must start Stage 2 with reduced shields and its stronger weapons")
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
	check(_contains_text(scene.reading_scroll, "Copy Daily score"), "Non-iOS results explicitly offer clipboard fallback")
	scene._share_daily_result()
	check(scene.toast_panel.visible and scene.toast_detail.text.contains("copied"), "Desktop clipboard fallback shows a confirmation toast")
	check(scene.Progress.daily_share_text(scene.sim).contains(daily_id), "Share payload preserves the saved Daily UTC date")
	check(scene.result_awards.has("daily_first") and scene.toast_queue.size() > 0, "New achievements queue nonblocking unlock notifications")
	scene._advance_toast(4.0)
	check(scene.toast_panel.visible and scene.toast_title.text == "ACHIEVEMENT UNLOCKED", "Queued achievement notification appears after copy toast dismisses")
	# Simulate the native iOS singleton in headless CI without needing an iPhone.
	var native_share := NativeShareMock.new()
	scene.daily_share_service = native_share
	scene._share_daily_result()
	var expected_share: String = scene.Progress.daily_share_text(scene.sim)
	check(native_share.payload.get("content", "") == expected_share and native_share.payload.get("mime_type", "") == "text/plain", "Native share sheet receives complete scorecard as plain text")
	check(native_share.payload.get("title", "") == "Star/Run Daily Challenge" and str(native_share.payload.get("subject", "")).contains(daily_id), "Native share sheet receives branded title and original UTC date")
	check(scene.pending_share_text == expected_share, "Share sheet launch is asynchronous, not treated as completed sharing")
	scene._on_native_share_canceled()
	check(scene.pending_share_text.is_empty(), "Canceling native share clears pending text without publishing")
	scene._share_daily_result()
	scene._on_native_share_failed("Simulated native failure")
	check(scene.pending_share_text.is_empty() and scene.toast_panel.visible and scene.toast_detail.text.contains("copied"), "Failed native sharing falls back to a copyable scorecard")
	native_share.response = ERR_CANT_OPEN
	scene._share_daily_result()
	check(scene.pending_share_text.is_empty() and scene.toast_detail.text.contains("copied"), "Immediate native share errors also fall back to clipboard")
	# A deleted charging enemy must leave its lane cancellation visible for
	# the same real duration at any game speed. Playfield is normally driven
	# by the scene tree; call it explicitly to inspect the real-time cue.
	scene.sim = Sim.new(88201)
	scene.mode = "playing"
	scene.world.set_process(false)
	scene.sim.enemies = [{"id": 22, "kind": "sniper", "p": Vector2(250, 230), "hp": 60.0, "max_hp": 60.0, "speed": 0.0, "fire": 99.0, "xp": 0, "phase": 0.0}]
	scene.sim.charges = [{"source": 22, "x": 250.0, "remaining": 0.9, "duration": 1.8, "damage": 30.0}]
	scene.world._process(0.0)
	check(scene.world.beam_cancel_feedback.is_empty(), "A live red warning lane must not show interruption feedback")
	scene.sim._damage_enemy(scene.sim.enemies[0], 100.0, "pulse")
	scene.world._process(0.0)
	check(scene.world.beam_cancel_feedback.size() == 1, "Destroying the marked charger must present an explicit canceled-beam cue")
	scene.world._process(0.35)
	check(scene.world.beam_cancel_feedback.size() == 1 and is_equal_approx(float(scene.world.beam_cancel_feedback[0].remaining), 0.50), "Beam interruption must remain visible after 350ms of real time")
	scene.world._process(0.50)
	check(scene.world.beam_cancel_feedback.is_empty(), "Beam cancellation cue must expire after 0.85 real seconds")
	scene._show_beam_tutorial()
	check(_contains_text(scene.overlay, "Destroy the marked enemy to stop it"), "First beam tutorial must explain destroying its charging enemy")
	for dimensions in [Vector2i(375, 667), Vector2i(390, 844), Vector2i(1280, 800)]:
		root.size = dimensions
		await process_frame
		scene.set_process(false)
		scene.sim = Sim.new(60121 + dimensions.x)
		scene.sim.stage = 3
		scene.sim.signal_status = "offer"
		scene.sim.signal_until = 195.0
		scene.mode = "playing"
		scene._layout()
		scene._update_hud()
		check(scene.signal_button.visible and scene.signal_button.size.y >= 44.0, "Transmission has a visible touch target")
		scene.signal_button.pressed.emit()
		check(scene.mode == "archive_signal" and _contains_text(scene.overlay, "Intercept courier") and _contains_text(scene.overlay, "Tune receiver"), "Receiver panel offers both explicit objectives")
		scene._choose_signal("cast")
		check(scene.mode == "playing" and scene.sim.signal_status == "cast", "Choosing a receiver tactic resumes combat")
		scene.sim.stage = 4
		scene.sim.stage_clears = 4
		scene.sim.stage_transition_queued = true
		scene.sim.signal_count = 2
		scene._show_stage_clear(false)
		await process_frame
		check(scene.mode == "archive_reveal" and scene.sim.stage == 4, "Reveal leaves the flight at the Citadel until a choice is made")
		check(_contains_text(scene.overlay, "Finish campaign") and _contains_text(scene.overlay, "Play Endless") and _contains_text(scene.overlay, "Enter the Silent Archive"), "All three routes have explicit button labels")
		check(scene.reading_panel.get_global_rect().end.y <= scene.get_viewport_rect().size.y, "Archive reveal actions fit the safe height")
		scene._enter_archive()
		check(scene.mode == "archive_intro" and scene.sim.secret_intro_pending, "Explicit entry opens a paused Archive arrival")
		scene._resume_run()
		check(scene.mode == "archive_intro" and scene.sim.stage == 5, "Resume restores the Archive arrival")
		scene._resume_archive()
		scene.sim._spawn_boss()
		scene._show_archive_intro(false)
		check(_contains_text(scene.overlay, "Last Custodian") and _contains_text(scene.overlay, "use an ability to open the core") and _contains_text(scene.overlay, "3 shields"), "Boss intro explains the counter")
		scene._resume_archive()
		scene.sim.archive_phase = 2
		scene.sim.archive_phase_released = true
		scene.sim._damage_enemy(scene.sim._boss_core(), 9999999.0, "nova")
		scene._show_stage_clear(false)
		scene._resume_run()
		check(scene.mode == "archive_ending" and _contains_text(scene.overlay, "You leave the gate open"), "Epilogue preserves its state on resume")
		scene._finish_archive()
		check(scene.mode == "results" and scene.profile.achievements.has("open_frequency"), "Debrief awards the permanent record")
		check(scene.services.read_save(scene.Services.RUN).is_empty(), "Settled Archive run cannot be resumed again")

	# Test the real mobile decision panel and persistence, not merely the
	# simulation's logical option IDs. Combat must stay paused in this mode.
	for dimensions in [Vector2i(375, 667), Vector2i(390, 844)]:
		root.size = dimensions
		await process_frame
		scene.sim = Sim.new(99100 + dimensions.x)
		scene.sim.stage = 2
		scene.sim.upgrades.pulse = 5
		scene.sim._queue_weapon_evolutions()
		scene.mode = "playing"
		scene._layout()
		scene._show_build_choice()
		await process_frame
		check(scene.mode == "build_choice" and scene.sim.pending_build_choices.size() == 1, "Rank-5 mobile evolution choice pauses combat")
		check(_contains_text(scene.overlay, "Duelist") and _contains_text(scene.overlay, "Spotter"), "Both evolution paths and their descriptions are visible on real mobile UI")
		# Kit.caps renders card headings as uppercase on actual devices.
		check(_contains_text(scene.overlay, "FOCUS FIRE") and _contains_text(scene.overlay, "TEAM UP"), "Both compact specialization roles fit the phone evolution choice")
		check(scene.reading_panel.get_global_rect().end.y <= scene.get_viewport_rect().size.y, "Evolution panel fits narrow-phone safe area")
		check(_choice_panels_within_screen(scene.overlay, scene.get_viewport_rect().size.x), "Evolution option cards preserve 24pt phone gutters")
		var snapshot: Dictionary = scene.services.read_save(scene.Services.RUN)
		check(snapshot.has("pending_build_choices") and snapshot.pending_build_choices.size() == 1, "An unanswered evolution choice is checkpointed before interaction")
		scene._resume_run()
		check(scene.mode == "build_choice" and scene.sim.pending_build_choices.size() == 1, "Restart shows the identical unanswered decision, not an auto-pick")
		scene._choose_build_decision("spotter")
		check(scene.mode == "playing" and scene.sim.weapon_evolutions.pulse == "spotter", "Choosing Spotter installs it and resumes the actual flight")
		check(scene.services.read_save(scene.Services.RUN).weapon_evolutions.pulse == "spotter", "Chosen evolution persists in storage")
		scene.sim = Sim.new(99200 + dimensions.x)
		scene.sim.stage = 2
		scene.sim.active_slots = ["aegis", "nova"]
		scene.sim.upgrades.aegis = 5
		scene.sim.upgrades.nova = 5
		scene.sim._try_fuse()
		scene._show_build_choice()
		await process_frame
		check(scene.mode == "build_choice" and _contains_text(scene.overlay, "Fuse") and _contains_text(scene.overlay, "Keep both"), "Mobile fusion panel presents two explicit strategies")
		check(_choice_panels_within_screen(scene.overlay, scene.get_viewport_rect().size.x), "Fusion choice cards stay away from phone edges")
		scene._choose_build_decision("keep")
		check(scene.mode == "playing" and scene.sim.active_slots == ["aegis", "nova"], "Mobile Keep choice preserves two distinct buttons")
		# Debrief reports actual engine activity, not an unsupported power score.
		scene.sim = Sim.new(99300 + dimensions.x)
		scene.sim.stage = 2
		scene.sim.engine_procs.storm_circuit = 4
		scene.sim.damage_dealt.engine_storm = 218.0
		scene._show_results()
		await process_frame
		check(_contains_text(scene.overlay, "YOUR BUILD AT WORK") and _contains_text(scene.overlay, "Storm Circuit"), "Real engine activation summary appears on phone debrief")
		check(_contains_text(scene.overlay, "218 direct damage"), "Debrief displays measured engine damage and does not invent a damage multiplier")
		check(scene.reading_panel.get_global_rect().end.y <= scene.get_viewport_rect().size.y, "Build-impact debrief stays inside narrow-phone safe area")
	# World 1 -> 2: the last Prototype and Route choices must actually
	# become reachable by scrolling on short, narrow phones. No sideways layout.
	for dimensions in [Vector2i(360, 740), Vector2i(375, 667), Vector2i(390, 844), Vector2i(1280, 800)]:
		root.size = dimensions
		await process_frame
		scene._layout()
		scene.sim = Sim.new(99001 + dimensions.x)
		scene.sim.stage_transition_queued = true
		check(scene.sim.begin_intermission(), "Fixture enters the real World 1 -> 2 intermission")
		scene._show_prototypes()
		await process_frame
		check(scene.card_buttons.size() == 3, "World transition offers exactly three Prototype choices")
		check(_choice_panels_within_screen(scene.overlay, scene.get_viewport_rect().size.x), "All three Prototype cards fit the screen horizontally")
		var last_prototype: Control = scene.overlay.find_child("PrototypeChoice2", true, false)
		check(last_prototype != null, "The third Prototype option must exist in the scrolling region")
		if last_prototype != null:
			scene.reading_scroll.scroll_vertical = int(scene.reading_scroll.get_v_scroll_bar().max_value)
			await process_frame
			await process_frame
			check(last_prototype.get_global_rect().end.y <= scene.reading_scroll.get_global_rect().end.y + 2.0, "The third Prototype can scroll fully above the pinned footer")
		scene._choose_prototype(0)
		await process_frame
		check(scene.mode == "route", "Choosing a Prototype still opens the next-world route choice")
		check(_choice_panels_within_screen(scene.overlay, scene.get_viewport_rect().size.x), "All three Route cards fit the screen horizontally")
		var last_route: Control = scene.overlay.find_child("RouteChoiceBounty", true, false)
		check(last_route != null, "The third Route must exist in the scrolling region")
		if last_route != null:
			scene.reading_scroll.scroll_vertical = int(scene.reading_scroll.get_v_scroll_bar().max_value)
			await process_frame
			await process_frame
			check(last_route.get_global_rect().end.y <= scene.reading_scroll.get_global_rect().end.y + 2.0, "The third Route can scroll fully above the pinned footer")

	print("UI RESULT: %d checks, %d failures" % [checks, failures])
	scene.queue_free()
	await process_frame
	call_deferred("quit", 1 if failures else 0)
