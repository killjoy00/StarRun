extends SceneTree
## Capture the complete UI matrix on every PR, without touching a player's save.
## Run with xvfb-run -a godot --path . --audio-driver Dummy --script tests/screenshot_harness.gd
const Sim = preload("res://scripts/simulation.gd")
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
	"menu", "achievements", "daily-results", "settings", "briefing",
	"hangar-hull", "hangar-weapons", "hangar-abilities",
	"ships", "pilots", "combat-1", "combat-4",
	"cards", "cards-banish", "cards-maxed", "paused", "build",
	"stage-clear", "prototypes", "route",
	"results-loss", "results-win", "rival-intro", "rival-retired", "rival-journal",
	"opening-warning", "opening-strike", "merchant-signal", "merchant-shop", "merchant-confirm", "merchant-receipt", "beam-tutorial", "beam-charging", "beam-canceled", "endless-clear"
]
var output := "/tmp/starrun-screenshots"
var count := 0
var failures := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	create_timer(150.0).timeout.connect(func(): push_error("Screenshot matrix timed out"); quit(1))
	call_deferred("_run")

func _run() -> void:
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
			scene._update_hud()
			scene._process(0.0)
			# Capture the final frame after the 150ms sheet slide, not the dim fade-in.
			await create_timer(0.20).timeout
			await process_frame
			await RenderingServer.frame_post_draw
			var picture := root.get_texture().get_image()
			if picture.is_empty() or picture.get_width() != dimensions.x or picture.get_height() != dimensions.y:
				failures += 1
				push_error("Screenshot size mismatch: %s / %s" % [str(dimensions), screen])
				continue
			var path := folder.path_join(screen + ".png")
			if picture.save_png(path) != OK:
				failures += 1
				push_error("Could not save " + path)
			else:
				count += 1
		scene.queue_free()
		await process_frame
	print("SCREENSHOT MATRIX: %d of %d screens (3 sizes) saved to %s" % [count, SIZES.size() * SCREENS.size(), output])
	quit(0 if failures == 0 and count == SIZES.size() * SCREENS.size() else 1)

func _prepare(scene, screen: String) -> void:
	match screen:
		"menu":
			scene._show_menu()
		"achievements":
			scene._show_achievements()
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
			scene.banner_text = "!  HOSTILE FORMATION INBOUND" if screen == "opening-warning" else "STRIKE WING  ·  THREE-SHIP ATTACK"
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
		"ships", "pilots":
			scene.loadout_tab = "Ships" if screen == "ships" else "Pilots"
			scene._show_loadout()
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
		"endless-clear":
			scene.sim.endless_enabled = true
			scene.sim.stage = 5
			scene.sim.stage_clears = 5
			scene.sim.stage_transition_queued = true
			scene._show_stage_clear(false)
