extends SceneTree
## Layout fuzz: real drafts (3- and 4-card, mutations, recovery, fusion and
## evolution choices), every Hangar tab and every loadout tab, at several
## phone widths. Fails if any visible control or unwrapped label leaves the
## screen horizontally. Run with:
## xvfb-run -a godot --path . --audio-driver Dummy --script tests/layout_fuzz.gd
const Sim = preload("res://scripts/simulation.gd")
const Main = preload("res://scripts/main.gd")
const Catalog = preload("res://scripts/catalog.gd")
class MemoryServices extends "res://scripts/platform_services.gd":
	var values: Dictionary = {}
	func write_atomic(path: String, value: Dictionary) -> bool:
		values[path] = value.duplicate(true)
		return true
	func read_save(path: String) -> Dictionary:
		return values.get(path, {})
	func delete_run() -> void:
		values.erase(RUN)

const SIZES := [Vector2i(320, 568), Vector2i(375, 667), Vector2i(390, 844), Vector2i(430, 932)]
var checks := 0
var failures := 0

func _initialize() -> void:
	create_timer(600.0).timeout.connect(func(): push_error("Layout fuzz timed out"); quit(1))
	call_deferred("_run")

func _scan(scene: Node, label: String) -> void:
	checks += 1
	var width: float = (scene as CanvasItem).get_viewport_rect().size.x
	for node in scene.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree() or control.size.x <= 0.0:
			continue
		var inside_scroll := false
		var parent := control.get_parent()
		while parent != null and parent != scene:
			if parent is ScrollContainer and (parent as ScrollContainer).horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
				inside_scroll = true
				break
			parent = parent.get_parent()
		if inside_scroll:
			continue
		var rect := control.get_global_rect()
		var overflow := false
		if control is Label:
			var text_label := control as Label
			overflow = text_label.autowrap_mode == TextServer.AUTOWRAP_OFF and not text_label.clip_text and text_label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING and text_label.get_minimum_size().x > text_label.size.x + 2.0
		if rect.position.x < -2.0 or rect.end.x > width + 2.0 or overflow:
			failures += 1
			push_error("OFFSCREEN %s: %s x=%.0f..%.0f of %.0f%s \"%s\"" % [label, str(scene.get_path_to(control)), rect.position.x, rect.end.x, width, " (text wider than its box)" if overflow else "", str(control.get("text")) if control.get("text") != null else ""])

func _settle() -> void:
	await process_frame
	await process_frame

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
		var size_label := "%dx%d" % [dimensions.x, dimensions.y]
		# Real drafts across seeds, worlds and levels, with and without the
		# four-card Hangar upgrade, including banish mode.
		for seed in range(40):
			for stage in [1, 2, 3, 4]:
				var hangar := Catalog.defaults()
				hangar.extra_card = seed % 2
				var sim := Sim.new(91000 + seed * 13 + stage, hangar, Catalog.SHIPS[seed % Catalog.SHIPS.size()].id)
				sim.stage = stage
				sim.level = 2 + (seed % 9)
				for weapon in ["pulse", "seeker", "arc", "lance"]:
					sim.upgrades[weapon] = maxi(int(sim.upgrades[weapon]), 1 + (seed + stage) % 6)
				sim._offer_cards(false)
				scene.sim = sim
				scene.mode = "playing"
				scene.banish_mode = seed % 5 == 0
				scene._show_cards(false)
				await _settle()
				_scan(scene, "%s draft seed %d world %d (%d cards)" % [size_label, seed, stage, sim.cards.size()])
		# Every card in the game, one at a time, so no long name or
		# description can slip through a lucky draw.
		var all_cards := Sim.new(92000)
		all_cards.stage = 4
		for card in all_cards.content.cards:
			all_cards.cards = [card.duplicate(true)]
			scene.sim = all_cards
			scene.mode = "playing"
			scene.banish_mode = false
			scene._show_cards(false)
			await _settle()
			_scan(scene, "%s card %s" % [size_label, str(card.id)])
		for tab in Catalog.GROUPS:
			scene._hangar_tab(tab)
			await _settle()
			_scan(scene, "%s hangar %s" % [size_label, tab])
		for tab in ["Ships", "Pilots", "Artifacts"]:
			scene._show_loadout()
			scene._loadout_tab(tab)
			await _settle()
			_scan(scene, "%s loadout %s" % [size_label, tab])
		scene.queue_free()
		await process_frame
	print("LAYOUT FUZZ RESULT: %d screens, %d failures" % [checks, failures])
	quit(1 if failures else 0)
