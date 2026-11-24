extends SceneTree
## Capture the complete UI matrix on every PR, without touching a player's save.
## Run with xvfb-run -a godot --path . --audio-driver Dummy --script tests/screenshot_harness.gd
const Sim = preload("res://scripts/simulation.gd")
const Intro = preload("res://scripts/first_flight.gd")
const Main = preload("res://scripts/main.gd")
class MemoryServices extends "res://scripts/platform_services.gd":
	var values: Dictionary = {}
	func write_atomic(path: String, value: Dictionary) -> bool:
		values[path] = value.duplicate(true)
		return true
	func read_save(path: String) -> Dictionary:
		return values.get(path, {})
	func delete_run() -> void:
		values.erase(RUN)

const SIZES := [Vector2i(375, 667), Vector2i(390, 844), Vector2i(1280, 800)]
const SCREENS := [
	"menu", "menu-start-world", "achievements", "codex", "codex-team-ups", "daily-results", "settings", "briefing",
	"hangar-hull", "hangar-weapons", "hangar-abilities",
	"ships", "pilots", "artifacts", "combat-1", "combat-4", "combat-drones", "boss-intro",
	"cards", "cards-banish", "cards-maxed", "cards-catch-up", "prototypes-skipped", "evolution", "fusion", "paused", "build",
	"stage-clear", "prototypes", "route",
	"results-loss", "results-win", "rival-intro", "rival-retired", "rival-journal",
	"opening-warning", "opening-strike", "merchant-signal", "merchant-shop", "merchant-confirm", "merchant-receipt", "beam-tutorial", "beam-charging", "beam-canceled", "boss-1-charging", "endless-clear",
	"archive-signal", "archive-reveal", "archive-arrival", "archive-patrol",
	"archive-boss-intro", "archive-boss-lock", "archive-ending",
	"first-flight-title", "first-flight-launch", "first-flight-aegis", "first-flight-draft",
	"first-flight-draft-two", "first-flight-harvester", "first-flight-ejection",
	"first-flight-ejection-reduced", "first-flight-debrief"
]
var output := "/tmp/starrun-screenshots"
var count := 0
var failures := 0
var intro_fixtures: Dictionary = {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	create_timer(150.0).timeout.connect(func(): push_error("Screenshot matrix timed out"); quit(1))
	call_deferred("_run")

## Layout guard: every visible control and its text must stay inside the
## screen horizontally. Reports each offender with its path and rectangle.
var bounds_failures := 0
func _scan_bounds(scene: Node, screen: String, dimensions: Vector2i) -> void:
	# Controls live in the stretched canvas, so compare in logical units.
	var width: float = (scene as CanvasItem).get_viewport_rect().size.x
	for node in scene.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree() or control.size.x <= 0.0:
			continue
		var rect := control.get_global_rect()
		var clipped_by_scroll := false
		var parent := control.get_parent()
		while parent != null and parent != scene:
			if parent is ScrollContainer and (parent as ScrollContainer).horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
				clipped_by_scroll = true
				break
			parent = parent.get_parent()
		if clipped_by_scroll:
			continue
		var text_overflow := false
		if control is Label:
			var label := control as Label
			text_overflow = label.autowrap_mode == TextServer.AUTOWRAP_OFF and not label.clip_text and label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING and label.get_minimum_size().x > label.size.x + 2.0
		var intro_chrome := control.name in [&"FirstFlightCaption", &"AegisMarker"]
		var viewport_height: float = (scene as CanvasItem).get_viewport_rect().size.y
		var intro_vertical_overflow := intro_chrome and (rect.position.y < 0.0 or rect.end.y > viewport_height)
		if rect.position.x < -2.0 or rect.end.x > width + 2.0 or text_overflow or intro_vertical_overflow:
			bounds_failures += 1
			print("OFFSCREEN %s %dx%d %s x=%.0f..%.0f%s \"%s\"" % [screen, dimensions.x, dimensions.y, str(scene.get_path_to(control)), rect.position.x, rect.end.x, " text-overflow" if text_overflow else "", str(control.get("text")) if control.get("text") != null else ""])

func _run() -> void:
	_build_intro_fixtures()
	for dimensions in SIZES:
		root.size = dimensions
		await process_frame
		var scene := Main.new()
		scene.services = MemoryServices.new()
		root.add_child(scene)
		scene.set_process(false)
		scene.world.set_process(false)
		scene.sound.enabled = false
		scene.sound.music_enabled = false
		scene.profile.cores = 5000
		scene._layout()
		var folder := output.path_join("%dx%d" % [dimensions.x, dimensions.y])
		DirAccess.make_dir_recursive_absolute(folder)
		for screen in SCREENS:
			scene.sim = Sim.new(84101, scene.profile.hangar)
			scene.banish_mode = false
			scene.stage_clear_clock = 2.0
			_prepare(scene, screen)
			scene.world._process(0.0)
			scene._update_hud()
			scene._process(0.0)
			# Capture the final frame after the 150ms sheet slide, not the dim fade-in.
			await create_timer(0.75 if screen == "first-flight-harvester" else 0.20).timeout
			await process_frame
			await RenderingServer.frame_post_draw
			var picture := root.get_texture().get_image()
			if picture.is_empty() or picture.get_width() != dimensions.x or picture.get_height() != dimensions.y:
				failures += 1
				push_error("Screenshot size mismatch: %s / %s" % [str(dimensions), screen])
				continue
			_scan_bounds(scene, screen, dimensions)
			var path := folder.path_join(screen + ".png")
			if picture.save_png(path) != OK:
				failures += 1
				push_error("Could not save " + path)
			else:
				count += 1
		scene.queue_free()
		await process_frame
	print("SCREENSHOT MATRIX: %d of %d screens (%d sizes) saved to %s" % [count, SIZES.size() * SCREENS.size(), SIZES.size(), output])
	if bounds_failures > 0:
		push_error("%d controls left the screen horizontally (see OFFSCREEN lines)" % bounds_failures)
	quit(0 if failures == 0 and bounds_failures == 0 and count == SIZES.size() * SCREENS.size() else 1)

func _build_intro_fixtures() -> void:
	var sim := Sim.new(Intro.SEED)
	sim.configure_first_flight(true)
	for i in range(15000):
		sim.step()
		if sim.tick == 66:
			intro_fixtures["first-flight-launch"] = sim.snapshot()
		if sim.intro_aegis_prompt:
			intro_fixtures["first-flight-aegis"] = sim.snapshot()
			sim.activate("aegis")
		if not sim.cards.is_empty():
			var screen := "first-flight-draft" if sim.intro_picks.is_empty() else "first-flight-draft-two"
			intro_fixtures[screen] = sim.snapshot()
			sim.choose_card(0)
		if sim.boss_spawned and not intro_fixtures.has("first-flight-harvester"):
			intro_fixtures["first-flight-harvester"] = sim.snapshot()
		if not sim.charges.is_empty() and sim.charges[0].remaining <= 0.65:
			sim.activate("aegis")
		if sim.ended:
			break
	if not sim.intro_ejected:
		failures += 1
		push_error("The intro screenshot fixture did not reach the scripted ejection")
	var ending := sim.snapshot()
	intro_fixtures["first-flight-debrief"] = ending
	intro_fixtures["first-flight-ejection"] = ending
	intro_fixtures["first-flight-ejection-reduced"] = ending

func _prepare(scene, screen: String) -> void:
	if screen == "first-flight-title":
		scene.services.delete_run()
		scene.profile.intro_status = "available"
		scene.profile.cores = 0
		scene._show_menu()
		return
	if screen in ["first-flight-ejection", "first-flight-ejection-reduced"]:
		scene.sim.restore(intro_fixtures[screen])
		scene.flight_started = true
		scene.profile.reduced = screen == "first-flight-ejection-reduced"
		scene._show_intro_crash()
		scene.intro_end_clock = Intro.IMPACT_AT + 0.14
		return
	if intro_fixtures.has(screen):
		scene.profile.reduced = false
		scene.services.write_atomic(scene.Services.RUN, intro_fixtures[screen])
		scene._resume_run()
		if screen == "first-flight-harvester":
			scene._show_boss_intro()
			scene.boss_intro_clock = 1.1
		return
	match screen:
		"menu":
			scene._show_menu()
		"menu-start-world":
			scene.profile.achievement_stats.world_clears = {"normal":3}
			scene.profile.start_world = 3
			scene._show_menu()
			scene.profile.achievement_stats.world_clears = {"normal":0}
			scene.profile.start_world = 1
		"cards-catch-up":
			scene.sim.begin_at_world(3)
			scene.sim.skip_prototype()
			scene.sim.skip_prototype()
			scene.sim.choose_route("repair")
			scene.sim.advance_stage()
			scene.sim._offer_cards()
			scene._show_cards(false)
		"prototypes-skipped":
			scene.sim.begin_at_world(3)
			scene._show_prototypes()
		"achievements":
			scene._show_achievements()
		"codex", "codex-team-ups":
			scene.profile.codex = {"card:pulse":true, "card:seeker":true, "card:armor":true, "card:aegis":true, "fusion:nova_aegis":true, "link:reinforced_plating":true, "synergy:fortress":true, "engine:execution_network":true, "card:piercing_pulse":true}
			scene.codex_tab = "Team-ups" if screen == "codex-team-ups" else "Upgrades"
			scene._show_codex()
		"daily-results":
			scene.sim.daily_day = "2026-11-15"
			scene.sim.daily_attempt = 1
			scene.sim.ended = true
			scene.sim.stage = 2
			scene.sim.stage_clears = 1
			scene.sim.kills = 220
			scene.sim.hull = 0.0
			scene.result_earned_cores = 0
			scene.result_daily_score = scene.Progress.daily_score(scene.sim)
			scene.result_daily_best = scene.result_daily_score
			scene._show_results()
		"rival-intro", "rival-retired", "rival-journal":
			var origin := Sim.new(84001)
			origin.last_killing_source = "gunship"
			var rival: Dictionary = scene.RivalCaptains._generated(origin,1,1)
			scene.profile.rival_active = rival.duplicate(true)
			scene.sim.configure_rival(rival)
			scene.sim._try_spawn_rival()
			if screen == "rival-intro":
				scene._show_rival_intro()
			elif screen == "rival-retired":
				scene.sim.rival_outcome = "retired"
				scene.sim.rival_retire_pending = true
				scene._show_rival_retired()
			else:
				# This gallery follows the retirement frame in sequence.
				# Don't re-create the same captain as both active and archived.
				scene.profile.rival_active = {}
				scene._show_rival_journal()
		"opening-warning", "opening-strike":
			scene.sim.tick = 540 if screen == "opening-warning" else 840
			scene.sim.time = scene.sim.tick * Sim.DT
			if screen == "opening-strike":
				scene.sim._spawn_world1_strike_wing()
			scene.mode = "playing"
			scene._clear_overlay()
			scene.last_sector = scene._sector_name(scene.sim.time)
			scene.banner_text = "!  ENEMY GROUP INCOMING" if screen == "opening-warning" else "THREE-SHIP ATTACK"
			scene.banner_clock = 4.0
		"merchant-signal", "merchant-shop", "merchant-confirm", "merchant-receipt":
			scene.sim.enable_merchant()
			scene.sim.stage = 2
			scene.sim.time = 80.0
			scene.sim.merchant_next_at = 70.0
			scene.sim._try_merchant_signal()
			if screen == "merchant-signal":
				scene._show_merchant_signal()
			else:
				scene.sim.merchant_hail()
				if screen == "merchant-shop":
					scene._show_merchant_shop()
				else:
					scene.sim.merchant_preview("pact")
					if screen == "merchant-confirm":
						scene._show_merchant_confirm()
					else:
						scene.sim.merchant_accept()
						scene._show_merchant_receipt()
		"settings":
			scene.mode = "menu"
			# Apple App Review evidence: native UI rendered at the exact
			# 390x844 logical iPhone viewport, using a StoreKit product-available
			# state. No tap performs a charge and no UI is composited afterward.
			if OS.get_environment("STARRUN_IAP_REVIEW_CAPTURE") == "1":
				scene.remove_ads_store.store_ready = true
				scene.remove_ads_store.product_available = true
				scene.remove_ads_store.localized_price = ""
				scene.remove_ads_store.message = "One purchase removes banner ads."
			scene._show_settings()
		"briefing":
			scene.mode = "menu"
			scene._show_briefing(false)
		"hangar-hull", "hangar-weapons", "hangar-abilities":
			scene.hangar_category = {"hangar-hull":"Hull", "hangar-weapons":"Weapons", "hangar-abilities":"Abilities"}[screen]
			scene._show_hangar()
		"ships", "pilots", "artifacts":
			scene.loadout_tab = {"ships":"Ships", "pilots":"Pilots", "artifacts":"Artifacts"}[screen]
			scene._show_loadout()
		"boss-intro":
			scene.sim.stage = 2
			scene.sim._spawn_boss()
			scene.mode = "playing"
			scene._show_boss_intro()
			scene.boss_intro_clock = 1.0
		"combat-drones":
			scene.sim = Sim.new(84101, scene.profile.hangar, "haven")
			scene.sim.stage = 2
			scene.sim.active_slots = ["mend", "wing_drones", "guard_drones"]
			scene.sim.upgrades.wing_drones = 5
			scene.sim.upgrades.guard_drones = 5
			for i in range(30):
				scene.sim.step()
			scene.sim.time = 1.0
			scene.sim.activate("wing_drones")
			scene.sim.activate("guard_drones")
			var center: Vector2 = scene.sim.ship_position()
			for i in range(8):
				scene.sim.bullets.append({"p":center + Vector2(-90 + i * 25, -120), "v":Vector2(0, 160), "kind":"chaff", "damage":6.0})
			scene.sim._update_guards()
			scene.mode = "playing"
			scene._clear_overlay()
		"combat-1", "combat-4":
			scene.sim.stage = 4 if screen == "combat-4" else 1
			scene.sim.boss_spawned = screen == "combat-4"
			scene.mode = "playing"
			scene._clear_overlay()
		"cards", "cards-banish":
			scene.sim.level = 6
			scene.sim._offer_cards(false)
			scene.sim.banishes_left = 2
			scene.banish_mode = screen == "cards-banish"
			scene._show_cards(false)
		"cards-maxed":
			scene.sim.level = 38
			for card in scene.sim.content.cards:
				scene.sim.upgrades[str(card.id)] = int(card.max)
			scene.sim._offer_cards(false)
			scene._show_cards(false)
		"evolution":
			scene.sim.stage = 2
			scene.sim.upgrades.pulse = 5
			scene.sim._queue_weapon_evolutions()
			scene._show_build_choice()
		"fusion":
			scene.sim.stage = 2
			scene.sim.active_slots = ["aegis", "nova"]
			scene.sim.upgrades.aegis = 5
			scene.sim.upgrades.nova = 5
			scene.sim._try_fuse()
			scene._show_build_choice()
		"paused":
			scene._show_pause()
		"build":
			scene.mode = "playing"
			scene._show_build()
		"stage-clear", "prototypes", "route":
			scene.sim.stage = 1
			scene.sim.stage_clears = 1
			scene.sim.stage_transition_queued = true
			if screen == "stage-clear":
				scene._show_stage_clear(false)
			else:
				scene.sim.begin_intermission()
				if screen == "prototypes":
					scene._show_prototypes()
				else:
					scene.sim.choose_prototype(0)
					scene._show_route_choice()
		"results-loss", "results-win":
			scene.sim.ended = true
			scene.sim.won = screen == "results-win"
			scene.sim.stage = 4 if scene.sim.won else 2
			scene.sim.stage_clears = 4 if scene.sim.won else 1
			scene.sim.hull = 0.0 if not scene.sim.won else 80.0
			scene.sim.damage_taken.heavy = 62.0
			scene.sim.damage_taken.ordnance = 38.0
			scene._show_results()
		"beam-tutorial":
			scene.sim.charges = [{"x":270.0, "remaining":1.5, "duration":1.8, "source":0, "damage":30.0}]
			scene._show_beam_tutorial()
		"beam-charging", "beam-canceled":
			scene.mode = "playing"
			scene._clear_overlay()
			scene.sim.enemies = [{"id": 9, "kind": "sniper", "p": Vector2(280, 242), "hp": 60.0, "max_hp": 60.0, "fire": 99.0, "speed": 0.0, "phase": 0.0, "xp": 0}]
			scene.sim.charges = [{"source": 9, "x": 280.0, "remaining": 1.2, "duration": 1.8, "damage": 30.0}]
			if screen == "beam-canceled":
				scene.sim._damage_enemy(scene.sim.enemies[0], 100.0, "pulse")
				scene.sim.enemies.clear()
			# The screenshot harness disables automatic processing.
			scene.world._process(0.0)
		"boss-1-charging":
			# The Harvester's phase label ("BEAM CHARGING - INTERRUPT") must fit.
			scene.sim._spawn_boss()
			scene.boss_intro_stage = scene.sim.stage
			scene.mode = "playing"
			scene._clear_overlay()
			var core: Dictionary = scene.sim._boss_core()
			scene.sim.charges = [{"source": int(core.id), "x": float(core.p.x), "remaining": 1.2, "duration": 1.8, "damage": 30.0}]
			scene.world._process(0.0)
		"endless-clear":
			scene.sim.endless_enabled = true
			scene.sim.stage = 5
			scene.sim.stage_clears = 5
			scene.sim.stage_transition_queued = true
			scene._show_stage_clear(false)

		"archive-signal":
			scene.sim.stage = 2
			scene.sim.signal_status = "offer"
			scene.sim.signal_until = 195.0
			scene.mode = "playing"
			scene._show_signal()
		"archive-reveal", "archive-arrival", "archive-patrol", "archive-boss-intro", "archive-boss-lock", "archive-ending":
			scene.sim.stage = 4
			scene.sim.stage_clears = 4
			scene.sim.time = 1100.0
			scene.sim.tick = 66000
			scene.sim.level = 63
			scene.sim.upgrades.nova = 5
			scene.sim.upgrades.capacitor = 4
			scene.sim.active_slots.append_array(["nova", "capacitor"])
			scene.sim.signal_count = 2
			scene.sim.stage_transition_queued = true
			scene._show_stage_clear(false)
			if screen == "archive-reveal":
				return
			scene._enter_archive()
			if screen == "archive-arrival":
				return
			scene._resume_archive()
			if screen == "archive-patrol":
				scene.sim.time += 28.0
				scene.sim._spawn_archive_patrol()
				for enemy in scene.sim.enemies:
					enemy.p.y += 350.0
				scene.sim.archive_attack = "lock"
				scene.sim.archive_attack_x = 190.0
				scene.sim.archive_attack_until = scene.sim.time + 1.4
				return
			scene.sim.time = scene.sim.stage_start + 105.0
			scene.sim._spawn_boss()
			scene._show_archive_intro(false)
			if screen == "archive-boss-intro":
				return
			scene._resume_archive()
			if screen == "archive-boss-lock":
				scene.sim.time = scene.sim.archive_next_attack
				scene.sim.archive_phase = 2
				scene.sim._update_archive_attack()
				return
			scene.sim.archive_phase = 2
			scene.sim.archive_phase_released = true
			scene.sim._damage_enemy(scene.sim._boss_core(), 9999999.0, "nova")
			scene._show_stage_clear(false)
