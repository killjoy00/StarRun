extends Node2D
const Simulation = preload("res://scripts/simulation.gd")
const Services = preload("res://scripts/platform_services.gd")
const Sound = preload("res://scripts/sound.gd")
const Playfield = preload("res://scripts/playfield.gd")
const Catalog = preload("res://scripts/catalog.gd")
const HangarBay = preload("res://scripts/hangar_bay.gd")
const IconBadge = preload("res://scripts/icon_badge.gd")
const CYAN := Color("66f5df")
const AMBER := Color("ffc078")
const INK := Color("080e1c")
const MUTED := Color("8797ad")
var sim: RefCounted
var services := Services.new()
var sound: Node
var profile := {"cores": 0, "runs": 0, "hangar": {"hull": 0, "damage": 0, "regen": 0}, "sound": true, "music": true, "reduced": false, "last_paid_run": -1, "ship": "vanguard", "pilot": "rookie", "ships_owned": ["vanguard"], "pilots_owned": ["rookie"], "speed": 1.0, "difficulty": "normal"}
var mode := "menu"
var accumulator := 0.0
var visual_time := 0.0
var save_clock := 0.0
var field := Rect2()
var scale_factor := 1.0
var clip: Control
var world: Node2D
var root: Control
var overlay: Control
var hud: Label
var status: Label
var build_label: Label
var report_label: Label
var ability_a: Button
var ability_b: Button
var ability_buttons: Dictionary = {} # Four UI slots, keyed by slot index.
var hangar_category := "Hull"
var loadout_tab := "Ships"
var speed_options := [0.5, 1.0, 2.0, 3.0]
var game_speed := 1.0
var speed_button: Button
var build_button: Button
var hangar_scroll: ScrollContainer
var pause_button: Button
var sound_button: Button
var music_button: Button
var low_fx_button: Button
var card_buttons: Array[Button] = []
var previous_ready := {}
var previous_warning := false
var last_hull := 100.0
var card_selection := 0
var draft_page := 0
var banner_text := ""
var banner_clock := 0.0
var last_sector := ""
var build_return_mode := "playing"
var build_show_all := false
var stage_clear_clock := 0.0
var stage_clear_button: Button
var warp_clock := 0.0
var reading_panel: Control
var reading_scroll: ScrollContainer
var reading_footer: HBoxContainer
var old_size := Vector2.ZERO

func _ready() -> void:
	var saved := services.read_save(Services.PROFILE)
	if not saved.is_empty():
		profile.merge(saved, true)
	var hangar := Catalog.defaults()
	hangar.merge(profile.hangar, true)
	profile.hangar = hangar
	# Repair old profiles without charging for starter choices.
	if not profile.get("ships_owned", []) is Array:
		profile.ships_owned = ["vanguard"]
	if not profile.get("pilots_owned", []) is Array:
		profile.pilots_owned = ["rookie"]
	if "vanguard" not in profile.ships_owned:
		profile.ships_owned.append("vanguard")
	if "rookie" not in profile.pilots_owned:
		profile.pilots_owned.append("rookie")
	if not profile.get("ship", "vanguard") in profile.ships_owned:
		profile.ship = "vanguard"
	if not profile.get("pilot", "rookie") in profile.pilots_owned:
		profile.pilot = "rookie"
	game_speed = float(profile.get("speed", 1.0))
	if game_speed not in speed_options:
		game_speed = 1.0
	sound = Sound.new()
	add_child(sound)
	sound.enabled = profile.sound
	sound.music_enabled = profile.music
	sim = Simulation.new(1, profile.hangar)
	_build_ui()
	_layout()
	_show_menu()
	get_tree().auto_accept_quit = false

# Native Retina screens are laid out in logical 390x844 canvas units, not pixels.
# Protect gameplay labels and menu copy from the old 10-13px type on phones.
func _compact_ui() -> bool:
	return get_viewport_rect().size.x < 760

func _text_size(font_size: int) -> int:
	return maxi(font_size, 16) if _compact_ui() else font_size

func _style(bg: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(4)
	box.content_margin_left = 10 if _compact_ui() else 16
	box.content_margin_right = 10 if _compact_ui() else 16
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

func _label(parent: Node, text_value: String, font_size: int = 16, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", _text_size(font_size))
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, title: String, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = title
	button.add_theme_font_size_override("font_size", _text_size(16))
	button.add_theme_color_override("font_color", INK if primary else CYAN)
	button.add_theme_color_override("font_hover_color", INK if primary else Color.WHITE)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_color_override("font_focus_color", INK if primary else Color.WHITE)
	button.add_theme_color_override("font_pressed_color", INK if primary else CYAN)
	button.add_theme_stylebox_override("normal", _style(CYAN if primary else Color("101d2e"), CYAN if primary else Color("294455")))
	button.add_theme_stylebox_override("hover", _style(Color("91ffe9") if primary else Color("203d4a"), CYAN))
	button.add_theme_stylebox_override("pressed", _style(Color("46bda9"), CYAN))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), AMBER, 2))
	button.add_theme_stylebox_override("disabled", _style(Color("101624"), Color("253043")))
	button.custom_minimum_size.y = 52
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _build_ui() -> void:
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	clip = Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(clip)
	world = Playfield.new()
	world.host = self
	clip.add_child(world)
	hud = _label(root, "", 18, CYAN)
	status = _label(root, "", 16, MUTED)
	build_label = _label(root, "", 14, MUTED)
	report_label = _label(root, "", 14, MUTED)
	for slot in range(Catalog.ACTIVE_SLOTS):
		ability_buttons[slot] = _button(root, "", _activate_slot.bind(slot), slot == 0)
		ability_buttons[slot].focus_mode = Control.FOCUS_NONE
		var badge := IconBadge.new()
		badge.icon_id = ""
		badge.position = Vector2(4, 4)
		badge.size = Vector2(25, 25)
		ability_buttons[slot].add_child(badge)
	ability_a = ability_buttons[0]
	ability_b = ability_buttons[1]
	pause_button = _button(root, "Ⅱ", _toggle_pause)
	build_button = _button(root, "BUILD", _show_build)
	speed_button = _button(root, "1×", _cycle_speed)
	sound_button = _button(root, "Effects", _toggle_sound)
	music_button = _button(root, "Music", _toggle_music)
	low_fx_button = _button(root, "Glow", _toggle_fx)
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)

func _layout() -> void:
	var size := get_viewport_rect().size
	old_size = size
	root.size = size
	var usable_height := maxf(240, size.y - (160 if _compact_ui() else 222))
	scale_factor = minf((size.x - 24) / 540.0, usable_height / 960.0)
	field = Rect2(Vector2((size.x - 540 * scale_factor) / 2, 75), Vector2(540, 960) * scale_factor)
	clip.position = field.position
	clip.size = field.size
	world.scale = Vector2.ONE * scale_factor
	hud.position = Vector2(field.position.x, 16)
	hud.size = Vector2(field.size.x, 24)
	status.position = Vector2(field.position.x, 43)
	status.size = Vector2(field.size.x, 22)
	var compact := _compact_ui()
	var controls_width := minf(size.x - 28, maxf(330, field.size.x))
	var controls_x := (size.x - controls_width) / 2
	var button_width := (controls_width - (15 if compact else 6)) / (4 if compact else 2)
	for i in range(Catalog.ACTIVE_SLOTS):
		var button: Button = ability_buttons[i]
		button.position = Vector2(controls_x + i * (button_width + 5), field.end.y + 9) if compact else Vector2(controls_x + (i % 2) * (button_width + 6), field.end.y + 9 + int(i / 2) * 56)
		button.size = Vector2(button_width, 54 if compact else 50)
		button.custom_minimum_size.y = 54 if compact else 50
		button.add_theme_font_size_override("font_size", _text_size(12))
		button.get_child(0).visible = not compact # On narrow screens the badges overlap button text.
		button.add_theme_stylebox_override("normal", _style(CYAN if i == 0 else Color("111e30"), CYAN if i == 0 else Color("354557")))
		for state in ["normal", "hover", "pressed", "disabled"]:
			var compact_style: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
			compact_style.content_margin_left = 6
			compact_style.content_margin_right = 6
			compact_style.content_margin_top = 6
			compact_style.content_margin_bottom = 6
			button.add_theme_stylebox_override(state, compact_style)
	var top_height := 44.0 if compact else 36.0
	build_button.position = Vector2(field.end.x - (202 if compact else 165), 30 if compact else 31)
	build_button.size = Vector2(86 if compact else 74, top_height)
	speed_button.position = Vector2(field.end.x - (114 if compact else 90), 30 if compact else 31)
	speed_button.size = Vector2(66 if compact else 46, top_height)
	for control in [build_button, speed_button]:
		control.custom_minimum_size.y = top_height
		control.add_theme_font_size_override("font_size", _text_size(11))
	pause_button.position = Vector2(field.end.x - (46 if compact else 42), 30 if compact else 31)
	pause_button.size = Vector2(46 if compact else 42, top_height)
	pause_button.custom_minimum_size.y = top_height
	pause_button.add_theme_font_size_override("font_size", _text_size(14))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var compact_style: StyleBoxFlat = pause_button.get_theme_stylebox(state).duplicate()
		compact_style.set_content_margin_all(6)
		pause_button.add_theme_stylebox_override(state, compact_style)
	var wide := size.x > 950
	build_label.visible = wide
	report_label.visible = wide
	build_label.position = Vector2(maxf(26, field.position.x - 260), 160)
	build_label.size = Vector2(235, 600)
	report_label.position = Vector2(field.end.x + 35, 160)
	report_label.size = Vector2(220, 600)
	sound_button.position = Vector2(16, size.y - 52)
	sound_button.size = Vector2(90, 36)
	sound_button.custom_minimum_size.y = 36
	low_fx_button.position = Vector2(size.x - 106, size.y - 52)
	low_fx_button.size = Vector2(90, 36)
	low_fx_button.custom_minimum_size.y = 36
	sound_button.visible = wide
	music_button.position = Vector2(114, size.y - 52)
	music_button.size = Vector2(90, 36)
	music_button.custom_minimum_size.y = 36
	music_button.visible = wide
	low_fx_button.visible = wide
	if mode == "menu":
		_show_menu()
	elif mode == "cards":
		_show_cards()
	elif mode == "paused":
		_show_pause()
	elif mode == "results":
		_show_results()
	elif mode == "hangar":
		_show_hangar()
	elif mode == "loadout":
		_show_loadout()
	elif mode == "build":
		_show_build()
	elif mode == "stage_clear":
		_show_stage_clear(false)
	elif mode == "prototype":
		_show_prototypes()
	elif mode == "route":
		_show_route_choice()

func _clear_overlay() -> void:
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	card_buttons.clear()
	stage_clear_button = null

func _panel(width: float = 440.0) -> VBoxContainer:
	_clear_overlay()
	var screen := get_viewport_rect().size
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.05, 0.85)
	shade.size = screen
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.size = screen
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = minf(width, screen.x - 28)
	panel.add_theme_stylebox_override("panel", _style(Color("0b1424"), Color("284451")))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = minf(620, screen.y - 60)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box

func _wrapped(parent: Node, value: String, size: int = 15, color: Color = MUTED) -> Label:
	var label := _label(parent, value, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.x = 0
	return label

func _reading_screen(width: float = 530.0) -> Dictionary:
	# Full-height reading layout: title and actions remain pinned while details scroll.
	_clear_overlay()
	var screen := get_viewport_rect().size
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.018, 0.035, 0.95)
	shade.size = screen
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.size = screen
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(width, screen.x - 28), minf(745, screen.y - 28))
	panel.add_theme_stylebox_override("panel", _style(Color("0c1828"), Color("3c5b69"), 1))
	center.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(layout)
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 3)
	layout.add_child(header)
	var top_separator := HSeparator.new()
	layout.add_child(top_separator)
	reading_scroll = ScrollContainer.new()
	reading_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reading_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reading_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	reading_scroll.custom_minimum_size.y = 0
	layout.add_child(reading_scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.custom_minimum_size.x = 0
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reading_scroll.add_child(body)
	var bottom_separator := HSeparator.new()
	layout.add_child(bottom_separator)
	reading_footer = HBoxContainer.new()
	reading_footer.add_theme_constant_override("separation", 8)
	layout.add_child(reading_footer)
	reading_panel = panel
	return {"header":header, "body":body, "footer":reading_footer, "panel":panel, "scroll":reading_scroll}

func _reading_card(parent: Node, heading: String, detail: String, accent: Color = CYAN) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.x = 0
	panel.add_theme_stylebox_override("panel", _style(Color("132638"), Color("28495c")))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	panel.add_child(content)
	_wrapped(content, heading, 17, accent)
	_wrapped(content, detail, 15, Color("e1edf4"))
	return panel

func _reading_cta(parent: HBoxContainer, title: String, action: Callable, primary: bool = false) -> Button:
	var button := _button(parent, title, action, primary)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.x = 0
	button.custom_minimum_size.y = 54
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return button

func _show_menu() -> void:
	mode = "menu"
	var box := _panel()
	_label(box, "S T A R / R U N", 38, CYAN)
	_label(box, "DEBRIS BELT   /   FLIGHT 01", 13, AMBER)
	_wrapped(box, "Build the ship. Read the threat. Choose your moment.", 19, Color.WHITE)
	_wrapped(box, "Your ship flies and fires itself. Each hull begins with one signature ability. Draft up to three more from a pool of 20.")
	_wrapped(box, "Four stages. Boss weak points, build synergies and irreversible Prototype and route decisions. Still no steering.", 14)
	_wrapped(box, "SHIP  %s   /   PILOT  %s" % [Catalog.ship(profile.ship).name, Catalog.pilot(profile.pilot).name], 13, CYAN)
	if not services.read_save(Services.RUN).is_empty():
		_button(box, "Resume flight", _resume_run, true)
	_button(box, "Launch new flight", _new_run, not FileAccess.file_exists(Services.RUN)).grab_focus()
	_button(box, "Hangar · %d cores" % profile.cores, _show_hangar)
	_button(box, "Pilots & ships · equip / unlock", _show_loadout)
	_button(box, "Difficulty: %s · rewards ×%.2f" % [str(profile.get("difficulty", "normal")).to_upper(), float(Catalog.REWARD_MULTIPLIERS[profile.get("difficulty", "normal")])], _cycle_difficulty)
	var row: BoxContainer = VBoxContainer.new() if _compact_ui() else HBoxContainer.new()
	box.add_child(row)
	var effects_toggle := _button(row, "Effects " + ("on" if profile.sound else "off"), _toggle_sound)
	var music_toggle := _button(row, "Music " + ("on" if profile.music else "off"), _toggle_music)
	var glow_toggle := _button(row, "Glow " + ("low" if profile.reduced else "full"), _toggle_fx)
	for toggle in [effects_toggle, music_toggle, glow_toggle]:
		toggle.add_theme_font_size_override("font_size", _text_size(12))
	_wrapped(box, "Keys 1–4 · B: build · Tab: speed · Esc: pause", 12, MUTED)

func _new_run() -> void:
	profile.runs += 1
	build_show_all = false
	_save_profile()
	sim = Simulation.new(61000 + int(profile.runs) * 7919, profile.hangar, profile.ship, profile.pilot, str(profile.get("difficulty", "normal")))
	_start_flight()

func _resume_run() -> void:
	var state := services.read_save(Services.RUN)
	sim = Simulation.new()
	if not sim.restore(state):
		_new_run()
		return
	_start_flight()
	if not sim.cards.is_empty():
		_show_cards()

func _start_flight() -> void:
	mode = "playing"
	_clear_overlay()
	accumulator = 0.0
	last_hull = sim.hull
	previous_warning = false
	previous_ready.clear()
	for id in sim.active_slots:
		previous_ready[id] = sim.cooldowns[id] <= 0
	last_sector = _sector_name(sim.time)
	banner_text = "Time your abilities. Survive four stages."
	banner_clock = 5.0
	sound.play("start")
	_save_run()
	if sim.stage_transition_queued:
		match sim.intermission_step:
			"prototype": _show_prototypes()
			"route": _show_route_choice()
			"ready": _finish_intermission()
			_: _show_stage_clear()

func _process(delta: float) -> void:
	visual_time += delta * (game_speed if mode == "playing" else 1.0)
	banner_clock = maxf(0.0, banner_clock - delta)
	if old_size != get_viewport_rect().size:
		_layout()
	if mode == "stage_clear":
		var before: float = stage_clear_clock
		stage_clear_clock += delta
		if stage_clear_button != null and stage_clear_clock >= 1.2:
			stage_clear_button.disabled = false
		if (before < 0.55 and stage_clear_clock >= 0.55) or (before < 1.05 and stage_clear_clock >= 1.05):
			sound.play("explosion", -7.0)
	elif mode == "warp":
		warp_clock += delta
		if warp_clock >= 1.45:
			_complete_warp()
	if mode == "playing":
		accumulator += minf(delta, 0.2) * game_speed
		while accumulator >= Simulation.DT and mode == "playing":
			sim.step()
			accumulator -= Simulation.DT
			if sim.stage_transition_queued:
				_show_stage_clear()
			elif sim.ended:
				_finish()
			elif not sim.cards.is_empty():
				_show_cards()
		var sector_now := _sector_name(sim.time)
		if sector_now != last_sector:
			last_sector = sector_now
			banner_text = sector_now + "  /  NEW SECTOR"
			banner_clock = 3.5
		var warning: bool = not sim.charges.is_empty()
		if warning and not previous_warning:
			sound.play("warning")
		previous_warning = warning
		for key in previous_ready:
			var ready: bool = sim.cooldowns[key] <= 0 and sim.upgrades[key] > 0
			if ready and not previous_ready[key]:
				sound.play("ready-" + key)
			previous_ready[key] = ready
		if sim.hull < last_hull:
			sound.play("hit")
		last_hull = sim.hull
		save_clock += delta
		if save_clock > 10:
			save_clock = 0
			_save_run()
	sound.update(sim, mode, delta)
	var shake := 0.0
	if mode == "playing" and not profile.reduced:
		for effect in sim.effects:
			if effect.kind == "hull-hit" or effect.get("boss", false):
				shake = maxf(shake, minf(4.0, effect.life * 9.0))
	world.position = Vector2(sin(visual_time * 79), cos(visual_time * 83)) * shake
	_update_hud()
	build_button.visible = mode in ["playing", "paused", "build"]
	pause_button.visible = mode in ["playing", "paused", "build"]
	speed_button.visible = mode in ["playing", "paused", "build"]
	speed_button.text = str(game_speed) + "×"
	queue_redraw()
	world.queue_redraw()

func _short_ability_name(id: String) -> String:
	var names := {"overdrive":"DRIVE", "capacitor":"CHARGE", "deflector":"DEFLECT", "barrage":"ROCKETS", "barrier":"BARRIER", "salvage":"SALVAGE", "overload":"OVERLOAD", "repair_matrix":"REPAIR", "nova_aegis":"NOVA SHD", "railstorm":"RAILSTORM", "stasis_lock":"TIME LOCK", "missile_grid":"MISSILES", "scrap_converter":"SCRAP", "prism_focus":"PRISM", "reflective_wall":"REFLECT", "ghost_signal":"GHOST", "reactor_surge":"SURGE", "strike":"RAIL", "reboot":"REBOOT", "siphon":"SIPHON", "focus":"FOCUS", "flak":"FLAK", "chrono":"CHRONO", "jammer":"JAMMER", "decoy":"DECOY", "aegis":"AEGIS", "mend":"REPAIR", "emp":"EMP", "nova":"NOVA", "prism":"PRISM"}
	return str(names.get(id, sim.content.abilities[id].name.to_upper())).left(9)

func _update_hud() -> void:
	hud.text = "S%d  HULL %03d   SHIELD %02d   LV %02d" % [sim.stage, sim.hull, sim.shield, sim.level]
	var seconds := int(sim.time - sim.stage_start)
	status.text = "%s  %02d:%02d" % [sim.difficulty.to_upper(), seconds / 60, seconds % 60]
	for i in range(Catalog.ACTIVE_SLOTS):
		var button: Button = ability_buttons[i]
		var occupied: bool = i < sim.active_slots.size()
		var id: String = str(sim.active_slots[i]) if occupied else ""
		var cooldown: float = float(sim.cooldowns.get(id, 0.0))
		var learned: bool = occupied and int(sim.upgrades.get(id, 0)) > 0
		var title: String = _short_ability_name(id) if occupied and _compact_ui() else (sim.content.abilities[id].name.to_upper() if occupied else "EMPTY")
		var status_text := ("%.0fs" % ceilf(cooldown) if cooldown > 0 else "READY") if learned and _compact_ui() else (("%.1fs" % cooldown if cooldown > 0 else "READY") if learned else ("FREE" if _compact_ui() else "DRAFT AN ABILITY"))
		button.text = ("%s\n%s" % [title, status_text]) if _compact_ui() else ("%d  %s\n%s" % [i + 1, title, status_text])
		button.disabled = mode != "playing" or cooldown > 0 or not learned
		button.tooltip_text = (sim.content.abilities[id].name + " · Level %d" % sim.upgrades[id]) if learned else "Install an active ability in an upgrade draft"
		var badge: Control = button.get_child(0)
		if badge.get("icon_id") != id:
			badge.set("icon_id", id)
			badge.queue_redraw()
		if occupied and not previous_ready.has(id):
			previous_ready[id] = true
	build_label.text = "%s / %s\nAUTOPILOT ONLINE\n\n" % [Catalog.ship(sim.ship_id).name.to_upper(), Catalog.pilot(sim.pilot_id).name.to_upper()]
	for tag in ["WEAPON", "ABILITY", "SYSTEM"]:
		build_label.text += tag + "S\n"
		for card in sim.content.cards:
			if card.tag == tag and sim.upgrades[card.id] > 0:
				build_label.text += "%s  %d/5\n" % [card.name, sim.upgrades[card.id]]
		build_label.text += "\n"
	report_label.text = "F L I G H T   D A T A\n\n%s\n\n%s\n\nTHREAT KEY\n\n●  Chaff · armor / shield\n◇  Missile · seekers / Nova\n┃  Heavy · Aegis / interrupt\n\nFLIGHT PLAN\n\nDotted path: next 2 seconds\nAmber lane: incoming beam\n\nKills             %d\nBeams cancelled   %d\nDamage blocked    %d\n\nSEED %d" % [_sector_name(sim.time), sim.boss_name().to_upper() + " ENGAGED" if sim.boss_spawned else "Boss at 04:00", sim.kills, sim.beams_cancelled, sim.prevented, sim.seed_value]

func _activate_slot(slot: int) -> void:
	if slot >= 0 and slot < sim.active_slots.size():
		_activate(str(sim.active_slots[slot]))

func _activate(id: String) -> void:
	if mode == "playing" and sim.activate(id):
		sound.play(id if id in ["aegis", "nova", "barrage", "overdrive", "chrono", "mend"] else "nova")
		if not sim.cards.is_empty():
			_show_cards()

func _show_cards() -> void:
	mode = "cards"
	_save_run()
	var compact := _compact_ui()
	var page_size := 2 if compact else maxi(1, sim.cards.size())
	var max_page: int = maxi(0, int(ceil(float(sim.cards.size()) / float(page_size))) - 1)
	draft_page = clampi(draft_page, 0, max_page)
	var first: int = draft_page * page_size
	var last: int = mini(sim.cards.size(), first + page_size)
	var view := _reading_screen(470)
	var header: VBoxContainer = view.header
	var body: VBoxContainer = view.body
	var footer: HBoxContainer = view.footer
	_label(header, "Pick an upgrade", 24, Color.WHITE)
	_wrapped(header, "Level %d  |  Options %d-%d of %d" % [sim.level, first + 1, last, sim.cards.size()], 15, MUTED)
	if sim.stage > 1 and sim.time - sim.stage_start < 1.0:
		_wrapped(header, "Stage %d: %s" % [sim.stage, sim.stage_name()], 15, AMBER)
	# No long four-choice column on phones. Two full-width cards per page.
	if compact:
		reading_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	for i in range(first, last):
		var card: Dictionary = sim.cards[i]
		var id: String = str(card.id)
		var current: int = int(sim.upgrades.get(id, 0))
		var increment: int = 1 if card.tag == "ABILITY" and current == 0 else 2
		var next_rank: int = mini(int(card.max), current + increment)
		var heading: String = "%d. %s" % [i + 1, card.name]
		var detail: String = ("New active  |  %d of 4 slots" % (sim.active_slots.size() + 1)) if card.tag == "ABILITY" and current == 0 else ("%s  |  Rank %d to %d" % [card.tag.capitalize(), current, next_rank])
		detail += "\n" + str(card.description)
		if current < 10 and id != "repair":
			var milestone: int = 5 if current < 5 else 10
			detail += "\nRank %d: %s" % [milestone, str(card.get("rank5" if milestone == 5 else "rank10", ""))]
		if card.tag == "ABILITY" and current == 0:
			var fusion: String = sim.fusion_hint(id)
			if not fusion.is_empty():
				detail += "\nFuses into " + fusion.get_slice(":", 0) + ". Frees a slot."
		elif card.tag in ["WEAPON", "SYSTEM"]:
			var link: String = sim.passive_hint(id)
			if not link.is_empty():
				detail += "\nPair bonus: " + link.get_slice(":", 0)
		var card_panel := _reading_card(body, heading, detail, CYAN if card.tag == "ABILITY" else AMBER)
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 8)
		card_panel.get_child(0).add_child(actions)
		var pick := _button(actions, "Take " + str(card.name), _choose.bind(i), i == first)
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.custom_minimum_size.y = 48
		pick.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_buttons.append(pick)
		if sim.banishes_left > 0 and id != "repair":
			var drop := _button(actions, "Remove", _draft_action.bind("banish", i))
			drop.custom_minimum_size.y = 48
			drop.tooltip_text = "Remove %s from this run's upgrade pool" % card.name
	if compact and max_page > 0:
		var prev := _reading_cta(footer, "Prev", _draft_page.bind(-1))
		prev.disabled = draft_page == 0
		var next := _reading_cta(footer, "Next", _draft_page.bind(1))
		next.disabled = draft_page == max_page
	if sim.rerolls_left > 0:
		_reading_cta(footer, "Reroll", _draft_action.bind("reroll", 0))
	if sim.skips_left > 0:
		_reading_cta(footer, "Skip", _draft_action.bind("skip", 0))
	if not card_buttons.is_empty():
		card_buttons[0].grab_focus()
	sound.play("card")

func _draft_page(direction: int) -> void:
	if mode != "cards":
		return
	draft_page = maxi(0, draft_page + direction)
	_show_cards()


func _draft_action(action: String, index: int) -> void:
	var changed: bool = sim.reroll_cards() if action == "reroll" else (sim.banish_card(index) if action == "banish" else sim.skip_cards())
	if not changed:
		return
	draft_page = 0
	if sim.cards.is_empty():
		mode = "playing"
		_clear_overlay()
		accumulator = -0.25
		_save_run()
	else:
		_show_cards()

func _choose(index: int) -> void:
	if mode == "cards" and sim.choose_card(index):
		draft_page = 0
		_clear_overlay()
		mode = "playing"
		accumulator = -0.25
		_save_run()

func _toggle_pause() -> void:
	if mode == "build":
		if build_return_mode == "paused":
			_show_pause()
		else:
			mode = "playing"
			_clear_overlay()
			accumulator = 0.0
	elif mode == "playing":
		_show_pause()
	elif mode == "paused":
		mode = "playing"
		_clear_overlay()
		accumulator = 0.0

func _show_pause() -> void:
	mode = "paused"
	_save_run()
	var box := _panel()
	_label(box, "FLIGHT PAUSED", 28, CYAN)
	_wrapped(box, "Your flight is saved, including the current upgrade hand and ability cooldowns.")
	_button(box, "Continue flight", _toggle_pause, true).grab_focus()
	_button(box, "Inspect build", _show_build)
	_button(box, "Effects: " + ("on" if profile.sound else "off"), _toggle_sound)
	_button(box, "Music: " + ("on" if profile.music else "off"), _toggle_music)
	_button(box, "Glow: " + ("low" if profile.reduced else "full"), _toggle_fx)
	_button(box, "Save & return to hangar", _show_menu)

func _show_stage_clear(reset_clock: bool = true) -> void:
	if reset_clock:
		stage_clear_clock = 0.0
	mode = "stage_clear"
	_save_run()
	_clear_overlay()
	var screen := get_viewport_rect().size
	var shade := ColorRect.new()
	shade.color = Color(0.005, 0.012, 0.025, 0.19)
	shade.size = screen
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	var layout := VBoxContainer.new()
	layout.position = Vector2(14, 12)
	layout.size = screen - Vector2(28, 26)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(layout)
	var top := _wrapped(layout, "STAGE %d / 4  ·  %s DESTROYED" % [sim.stage, sim.boss_name().to_upper()], 22, AMBER)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(space)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("0a1726", 0.96), AMBER, 2))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	panel.add_child(content)
	_wrapped(content, sim.stage_spec().reward_label.to_upper(), 21, AMBER)
	_wrapped(content, "RUN SALVAGE  %d CORES · %d ENEMIES DEFEATED\nSalvage is awarded when the flight ends." % [sim.payout(), sim.kills], 16, Color.WHITE)
	var next_text := "The Void Citadel is yours. Claim your victory and see the flight report." if sim.stage == sim.stage_count() else "Next: %s. Warp, install a Prototype, then choose repairs, damage or a higher-risk bounty." % sim.stage_spec().transition
	_wrapped(content, next_text, 16, Color.WHITE)
	stage_clear_button = _button(content, "Claim victory & see report" if sim.stage == sim.stage_count() else "Warp to " + str(sim.stage_spec().transition), _begin_warp, true)
	stage_clear_button.disabled = stage_clear_clock < 1.2
	stage_clear_button.custom_minimum_size.y = 58
	if not stage_clear_button.disabled:
		stage_clear_button.grab_focus()
	if reset_clock:
		sound.play("boss-explosion", -4.0)

func _begin_warp() -> void:
	if mode != "stage_clear" or stage_clear_clock < 1.2:
		return
	if sim.stage == sim.stage_count():
		if sim.advance_stage():
			_finish()
		return
	mode = "warp"
	warp_clock = 0.0
	_clear_overlay()
	sound.play("start", -7.0)

func _complete_warp() -> void:
	if mode != "warp":
		return
	if not sim.begin_intermission():
		_show_stage_clear(false)
		return
	_show_prototypes()

func _show_prototypes() -> void:
	mode = "prototype"
	_save_run()
	var view := _reading_screen(540)
	var header: VBoxContainer = view.header
	var body: VBoxContainer = view.body
	var footer: HBoxContainer = view.footer
	_label(header, "CHOOSE A PROTOTYPE", 26, CYAN)
	_wrapped(header, "Stage %d cleared. Install one permanent upgrade for the rest of this flight." % sim.stage, 15, Color.WHITE)
	_wrapped(header, "Every Prototype has a benefit and a cost. The other two options are lost.", 14, AMBER)
	var first: Button = null
	for i in range(sim.prototype_offers.size()):
		var id: String = str(sim.prototype_offers[i])
		var spec: Dictionary = sim.prototype_spec(id)
		var card := _reading_card(body, "%d  /  %s  [%s]" % [i + 1, spec.name, spec.role], "%s\nBENEFIT  %s\nTRADEOFF  %s" % [spec.description, spec.benefit, spec.cost], CYAN)
		var content: VBoxContainer = card.get_child(0)
		var choose := _button(content, "Install " + str(spec.name), _choose_prototype.bind(i), i == 0)
		choose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choose.custom_minimum_size.y = 50
		if first == null:
			first = choose
	_reading_cta(footer, "Save & Main Menu", _show_menu)
	if first != null:
		first.grab_focus()

func _choose_prototype(index: int) -> void:
	if mode != "prototype" or not sim.choose_prototype(index):
		return
	sound.play("card")
	_save_run()
	_show_route_choice()

func _show_route_choice() -> void:
	mode = "route"
	_save_run()
	var view := _reading_screen(540)
	var header: VBoxContainer = view.header
	var body: VBoxContainer = view.body
	var footer: HBoxContainer = view.footer
	_label(header, "CHOOSE YOUR NEXT ROUTE", 26, CYAN)
	_wrapped(header, "NEXT: %s  ·  STAGE %d OF 4" % [sim.stage_spec().transition, sim.stage + 1], 15, Color.WHITE)
	_wrapped(header, "One immediate decision: restore your hull, push your damage or gamble for extra cores.", 14, MUTED)
	var routes := [
		{"id":"repair", "name":"SAFE PASSAGE", "text":"BENEFIT  Repair 55% of max hull and fully restore shields.\nTRADEOFF  No extra damage or core bounty.", "action":"Repair and continue"},
		{"id":"overclock", "name":"REDLINE JUMP", "text":"BENEFIT  +25% automatic weapon damage for the next stage.\nTRADEOFF  Repair only 10% hull and start with 60% shields.", "action":"Overclock and continue"},
		{"id":"bounty", "name":"HIGH-RISK CONTRACT", "text":"BENEFIT  +%d base cores for defeating the next boss.\nTRADEOFF  +30%% enemy health, damage and spawn pressure; repair only 30%% hull." % (20 * (sim.stage + 1)), "action":"Accept bounty and continue"}
	]
	var first: Button = null
	for route in routes:
		var card := _reading_card(body, str(route.name), str(route.text), AMBER if route.id == "bounty" else CYAN)
		var content: VBoxContainer = card.get_child(0)
		var button := _button(content, str(route.action), _choose_route.bind(str(route.id)), route.id == "repair")
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 52
		if first == null:
			first = button
	_reading_cta(footer, "Save & Main Menu", _show_menu)
	if first != null:
		first.grab_focus()

func _choose_route(id: String) -> void:
	if mode != "route" or not sim.choose_route(id):
		return
	_finish_intermission()

func _finish_intermission() -> void:
	if not sim.advance_stage():
		_show_route_choice()
		return
	mode = "playing"
	_clear_overlay()
	accumulator = 0.0
	last_sector = _sector_name(sim.time)
	banner_text = "STAGE %d / 4  ·  %s" % [sim.stage, sim.stage_name()]
	banner_clock = 5.0
	sound.play("start")
	_save_run()
	if sim.pending_levels > 0:
		sim._offer_cards()
		_show_cards()

func _finish() -> void:
	mode = "results"
	# Record settlement identity in profile before removing the resume save.
	if int(profile.last_paid_run) != sim.seed_value:
		profile.cores += sim.payout()
		profile.last_paid_run = sim.seed_value
		_save_profile()
	services.delete_run()
	_show_results()

func _show_results() -> void:
	mode = "results"
	var view := _reading_screen(540)
	var header: VBoxContainer = view.header
	var body: VBoxContainer = view.body
	var footer: HBoxContainer = view.footer
	_label(header, "FOUR STAGES CLEARED" if sim.won else "FLIGHT ENDED", 27, CYAN if sim.won else AMBER)
	_wrapped(header, "Reached %s  ·  %s" % [sim.stage_name(), sim.difficulty.to_upper()], 17, Color.WHITE)
	_wrapped(header, "Stage %d of %d  ·  %02d:%02d flight time" % [sim.stage, sim.stage_count(), int(sim.time) / 60, int(sim.time) % 60], 15, MUTED)
	_reading_card(body, "SALVAGE EARNED", "+%d CORES  ·  %d enemy ships destroyed\n%d stages cleared  ·  %d abilities activated\nBase cores earned through bounty contracts: %d" % [sim.payout(), sim.kills, sim.stage_clears, sim.ability_uses, sim.bounty_earned], AMBER)
	var build_lines := PackedStringArray()
	for combo in sim.active_synergies():
		build_lines.append(str(combo.name) + " - " + str(combo.description))
	for id in sim.prototypes:
		var spec: Dictionary = sim.prototype_spec(str(id))
		build_lines.append(str(spec.name) + " - " + str(spec.benefit))
	_reading_card(body, "YOUR BUILD STRATEGY", "\n".join(build_lines) if not build_lines.is_empty() else "No synergy combos or Prototypes acquired.", CYAN)
	_reading_card(body, "FINAL SHIP STATUS", "Hull %d / %d  ·  Shield %d / %d\n%.0f damage blocked  ·  %d beams cancelled" % [sim.hull, sim.max_hull, sim.shield, sim.max_shield, sim.prevented, sim.beams_cancelled])
	_label(body, "DAMAGE REPORT", 19, AMBER)
	var damage_lines := PackedStringArray()
	for kind in ["chaff", "heavy", "ordnance", "hazard", "ion", "corrosion", "disrupt", "heat", "gravity", "void"]:
		var value: float = float(sim.damage_taken.get(kind, 0.0))
		if value > 0.0:
			var name: String = str({"ordnance":"Missiles", "hazard":"Hazards", "heavy":"Heavy beams"}.get(kind, kind.capitalize()))
			damage_lines.append("%s   %.0f" % [name, value])
	_reading_card(body, "INCOMING DAMAGE", "\n".join(damage_lines) if not damage_lines.is_empty() else "No incoming damage recorded.")
	var weapons: Array = []
	for key in sim.damage_dealt:
		var value: float = float(sim.damage_dealt[key])
		if value > 0:
			weapons.append({"name":str(key).capitalize(), "damage":value})
	weapons.sort_custom(func(a, b): return a.damage > b.damage)
	var weapon_lines := PackedStringArray()
	for i in range(mini(5, weapons.size())):
		weapon_lines.append("%s   %.0f" % [weapons[i].name, weapons[i].damage])
	_reading_card(body, "TOP WEAPONS", "\n".join(weapon_lines) if not weapon_lines.is_empty() else "No weapon damage recorded.")
	_label(body, "LAST MOMENTS", 19, AMBER)
	var recap := PackedStringArray()
	for i in range(sim.events.size() - 1, -1, -1):
		var event: Dictionary = sim.events[i]
		if event.time >= sim.time - 10.0 and recap.size() < 5:
			recap.append("%.1fs ago  ·  %s" % [sim.time - event.time, event.message])
	_reading_card(body, "FLIGHT RECORDER", "\n".join(recap) if not recap.is_empty() else "No events during the final ten seconds.")
	_button(body, "Visit Hangar  ·  %d cores available" % profile.cores, _show_hangar)
	var again := _reading_cta(footer, "Fly again", _new_run, true)
	_reading_cta(footer, "Main menu", _show_menu)
	again.grab_focus()

func _show_hangar() -> void:
	mode = "hangar"
	_clear_overlay()
	var screen := get_viewport_rect().size
	var compact := screen.x < 760
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.045, 1.0)
	shade.size = screen
	overlay.add_child(shade)
	var margin := MarginContainer.new()
	margin.position = Vector2(18, 18)
	margin.size = screen - Vector2(36, 36)
	overlay.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_label(heading, Catalog.ship(profile.ship).name.to_upper() + " / DOCK 07", 11, CYAN)
	_label(heading, "Hangar", 34, Color.WHITE)
	var wallet := VBoxContainer.new()
	header.add_child(wallet)
	_label(wallet, "%d" % profile.cores, 30, AMBER)
	_label(wallet, "CORES", 11, MUTED)
	var body: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	layout.add_child(body)
	var hero := VBoxContainer.new()
	hero.custom_minimum_size.x = 0 if compact else 280
	body.add_child(hero)
	var bay := HangarBay.new()
	bay.ship_id = profile.ship
	bay.custom_minimum_size = Vector2(0 if compact else 280, 126 if compact else 290)
	bay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_child(bay)
	_button(hero, "Pilots & ships · %s / %s" % [Catalog.ship(profile.ship).name, Catalog.pilot(profile.pilot).name], _show_loadout)
	if not compact:
		_label(hero, "Flight configuration", 20, Color.WHITE)
		_wrapped(hero, "HULL  %d    SHIELD  %d\nWEAPON DAMAGE  +%d%%\nABILITY RECHARGE  +%d%%" % [int(Catalog.ship(profile.ship).hull) + profile.hangar.hull * 10, int(Catalog.ship(profile.ship).shield) + profile.hangar.shield * 8 + (20 if profile.pilot == "engineer" else 0), profile.hangar.damage * 8, profile.hangar.ability_cooldown * 3], 14, CYAN)
		_wrapped(hero, "22 upgrade tracks plus permanent pilot and ship unlocks. Current suspended flights keep their original loadout.", 14)
		_wrapped(hero, "Draft from 20 active abilities, with a maximum of four equipped at once.", 14)
	var workshop := VBoxContainer.new()
	workshop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workshop.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(workshop)
	var tabs: Container = GridContainer.new() if compact else HBoxContainer.new()
	if compact:
		(tabs as GridContainer).columns = 3
		tabs.add_theme_constant_override("h_separation", 4)
		tabs.add_theme_constant_override("v_separation", 4)
	else:
		tabs.add_theme_constant_override("separation", 4)
	workshop.add_child(tabs)
	for group in Catalog.GROUPS:
		var tab := _button(tabs, group, _hangar_tab.bind(group), group == hangar_category)
		tab.custom_minimum_size = Vector2(0, 46 if compact else 38)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", _text_size(11 if compact else 13))
		for style in ["normal", "hover", "pressed", "disabled"]:
			var box: StyleBoxFlat = tab.get_theme_stylebox(style).duplicate()
			box.content_margin_left = 6
			box.content_margin_right = 6
			tab.add_theme_stylebox_override(style, box)
	hangar_scroll = ScrollContainer.new()
	hangar_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hangar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	workshop.add_child(hangar_scroll)
	var grid := GridContainer.new()
	grid.columns = 1 if compact else 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	hangar_scroll.add_child(grid)
	var index := 0
	for entry in Catalog.HANGAR:
		if entry.group != hangar_category:
			continue
		index += 1
		var bought: int = int(profile.hangar[entry.id])
		var maxed: bool = bought >= int(entry.max)
		var price := Catalog.price(entry.id, bought)
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size.x = 0 if compact else 220
		panel.add_theme_stylebox_override("panel", _style(Color("101f2b"), Color("49736b") if bought > 0 else Color("293d50")))
		grid.add_child(panel)
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 8)
		panel.add_child(card)
		_label(card, "%02d   /   %s" % [index, entry.group.to_upper()], 10, AMBER)
		var name_row := HBoxContainer.new()
		card.add_child(name_row)
		var badge := IconBadge.new()
		badge.icon_id = entry.id
		name_row.add_child(badge)
		_wrapped(name_row, entry.name, 19, Color.WHITE)
		_wrapped(card, entry.description, 13, MUTED)
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 4)
		card.add_child(pips)
		for tier in range(int(entry.max)):
			var pip := ColorRect.new()
			pip.color = CYAN if tier < bought else Color("23394a")
			pip.custom_minimum_size = Vector2(20, 4)
			pips.add_child(pip)
		var buy := _button(card, "FULLY INSTALLED" if maxed else "Install · %d cores    %d / %d" % [price, bought, entry.max], _purchase.bind(entry.id))
		buy.custom_minimum_size.y = 48 if compact else 38
		buy.add_theme_font_size_override("font_size", _text_size(12))
		buy.disabled = maxed or profile.cores < price
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	layout.add_child(footer)
	var launch := _button(footer, "Launch", _new_run, true)
	launch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var refund := _button(footer, "Refund" if compact else "Refund · %d" % Catalog.refund(profile.hangar), _respec)
	refund.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refund.add_theme_font_size_override("font_size", _text_size(13))
	var back := _button(footer, "Back", _show_menu)
	back.add_theme_font_size_override("font_size", _text_size(13))
	launch.grab_focus()

func _hangar_tab(group: String) -> void:
	hangar_category = group
	_show_hangar()

func _purchase(id: String) -> void:
	var entry := Catalog.entry(id)
	if entry.is_empty():
		return
	var rank: int = int(profile.hangar.get(id, 0))
	var price := Catalog.price(id, rank)
	if profile.cores >= price and rank < int(entry.max):
		profile.cores -= price
		profile.hangar[id] = rank + 1
		_save_profile()
		sound.play("card")
		_show_hangar()

func _respec() -> void:
	profile.cores += Catalog.refund(profile.hangar)
	profile.hangar = Catalog.defaults()
	_save_profile()
	_show_hangar()

func _toggle_sound() -> void:
	profile.sound = not profile.sound
	sound.enabled = profile.sound
	sound.music_enabled = profile.music
	_save_profile()
	_refresh_panel()

func _toggle_music() -> void:
	profile.music = not profile.music
	sound.music_enabled = profile.music
	_save_profile()
	_refresh_panel()

func _toggle_fx() -> void:
	profile.reduced = not profile.reduced
	_save_profile()
	_refresh_panel()

func _refresh_panel() -> void:
	if mode == "menu":
		_show_menu()
	elif mode == "paused":
		_show_pause()

func _save_profile() -> void:
	if not services.write_atomic(Services.PROFILE, profile):
		banner_text = "Save unavailable on this device"
		banner_clock = 5.0

func _save_run() -> void:
	if sim != null and not sim.ended:
		if not services.write_atomic(Services.RUN, sim.snapshot()):
			banner_text = "Run could not be saved"
			banner_clock = 5.0

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if mode == "playing":
			_show_pause()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_run()
		get_tree().quit()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_ESCAPE, KEY_P]:
		_toggle_pause()
		get_viewport().set_input_as_handled()
	elif mode == "stage_clear" and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		if stage_clear_clock >= 1.2:
			_begin_warp()
		get_viewport().set_input_as_handled()
	elif mode == "playing":
		if event.keycode == KEY_B:
			_show_build()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_TAB:
			_cycle_speed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE or (event.keycode >= KEY_1 and event.keycode <= KEY_4):
			_activate_slot(0 if event.keycode == KEY_SPACE else event.keycode - KEY_1)
			get_viewport().set_input_as_handled()
	elif mode == "cards" and event.keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
		_choose(event.keycode - KEY_1)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START:
			_toggle_pause()
		elif mode == "playing":
			var bindings := [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_B]
			var index := bindings.find(event.button_index)
			if index >= 0:
				_activate_slot(index)


func _sector_name(at: float) -> String:
	if sim.stage > 1:
		return sim.boss_name().to_upper() if sim.boss_spawned else "%s · STAGE %d" % [sim.stage_name(), sim.stage]
	if at < 65:
		return "DEBRIS BELT"
	if at < 125:
		return "ION NEBULA"
	if at < 190:
		return "WRECK FIELD"
	if at < 240:
		return "DARK RIFT"
	return "HARVESTER ZONE"

func _cycle_difficulty() -> void:
	var current := Catalog.DIFFICULTIES.find(str(profile.get("difficulty", "normal")))
	profile.difficulty = Catalog.DIFFICULTIES[(current + 1) % Catalog.DIFFICULTIES.size()]
	_save_profile()
	_show_menu()

func _cycle_speed() -> void:
	var index := speed_options.find(game_speed)
	game_speed = float(speed_options[(index + 1) % speed_options.size()])
	profile.speed = game_speed
	_save_profile()
	speed_button.text = str(game_speed) + "×"

func _show_build() -> void:
	if mode not in ["playing", "paused", "build"]:
		return
	if mode in ["playing", "paused"]:
		build_return_mode = mode
	mode = "build"
	_save_run()
	var view := _reading_screen(540)
	var header: VBoxContainer = view.header
	var body: VBoxContainer = view.body
	var footer: HBoxContainer = view.footer
	_label(header, "YOUR BUILD", 27, CYAN)
	_wrapped(header, "%s  /  %s" % [Catalog.ship(sim.ship_id).name, Catalog.pilot(sim.pilot_id).name], 17, Color.WHITE)
	_wrapped(header, "STAGE %d OF %d  ·  %s  ·  LEVEL %d" % [sim.stage, sim.stage_count(), sim.difficulty.to_upper(), sim.level], 15, MUTED)
	_reading_card(body, "SHIP STATUS", "HULL  %d / %d\nSHIELDS  %d / %d\nACTIVE SLOTS  %d / 4" % [sim.hull, sim.max_hull, sim.shield, sim.max_shield, sim.active_slots.size()])
	_label(body, "BUILD IDENTITY", 19, AMBER)
	var active_combos: Array = sim.active_synergies()
	if active_combos.is_empty():
		_reading_card(body, "NO ACTIVE SYNERGY", "Draft complementary active abilities to unlock Fortress, Glass Cannon, Control or Salvager bonuses - each has a drawback.", MUTED)
	for combo in active_combos:
		_reading_card(body, str(combo.name), str(combo.description), CYAN)
	if sim.prototypes.is_empty():
		_wrapped(body, "No Prototypes yet. Defeat a stage boss to choose one.", 15, MUTED)
	for id in sim.prototypes:
		var spec: Dictionary = sim.prototype_spec(str(id))
		_reading_card(body, "PROTOTYPE  ·  " + str(spec.name), "BENEFIT  %s\nTRADEOFF  %s" % [spec.benefit, spec.cost], AMBER)
	if not sim.route_choice.is_empty():
		_wrapped(body, "Current route: %s  ·  %s" % [sim.route_choice.to_upper(), "Extra enemy pressure" if sim.stage_risk > 1.0 else ("Weapon overclock" if sim.stage_power > 1.0 else "Reinforced hull")], 15, CYAN)
	_label(body, "EQUIPPED ABILITIES", 19, AMBER)
	var active_grid := GridContainer.new()
	active_grid.columns = 1 if _compact_ui() else 2
	active_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_grid.add_theme_constant_override("h_separation", 8)
	active_grid.add_theme_constant_override("v_separation", 8)
	body.add_child(active_grid)
	for slot in range(Catalog.ACTIVE_SLOTS):
		if slot >= sim.active_slots.size():
			_reading_card(active_grid, "%d  ·  EMPTY SLOT" % (slot + 1), "Choose an ability from your next level-up.", MUTED)
			continue
		var id: String = str(sim.active_slots[slot])
		var rank: int = int(sim.upgrades.get(id, 0))
		var desc := ""
		for card in sim.content.cards:
			if card.id == id:
				desc = str(card.description)
				break
		var recharge := int(sim.content.abilities[id].cooldown)
		_reading_card(active_grid, "%d  ·  %s" % [slot + 1, sim.content.abilities[id].name.to_upper()], "RANK %d / 5  ·  %ds BASE COOLDOWN\n%s" % [rank, recharge, desc], CYAN)
	_label(body, "AUTOMATIC WEAPONS", 19, AMBER)
	var weapons := 0
	for entry in sim.content.cards:
		if entry.tag != "WEAPON" or int(sim.upgrades.get(entry.id, 0)) <= 0:
			continue
		weapons += 1
		_reading_card(body, str(entry.name), "Rank %d of %d · %s" % [sim.upgrades[entry.id], entry.max, entry.description])
	if weapons == 0:
		_wrapped(body, "No automatic weapon modules installed.", 15)
	_label(body, "SYSTEMS & SUPPORT", 19, AMBER)
	var systems: Array = []
	for entry in sim.content.cards:
		if entry.tag == "SYSTEM" and int(sim.upgrades.get(entry.id, 0)) > 0:
			systems.append(entry)
	for index in range(systems.size() if build_show_all else mini(3, systems.size())):
		var entry: Dictionary = systems[index]
		_reading_card(body, str(entry.name), "Rank %d of %d · %s" % [sim.upgrades[entry.id], entry.max, entry.description])
	if systems.size() > 3:
		_button(body, "Show less" if build_show_all else "Show all %d installed systems" % systems.size(), _toggle_build_details)
	var hangar_count := 0
	var hangar_lines := PackedStringArray()
	for entry in Catalog.HANGAR:
		var rank: int = int(sim.meta.get(entry.id, 0))
		if rank > 0:
			hangar_count += 1
			hangar_lines.append("%s  ·  %d/%d" % [entry.name, rank, entry.max])
	var support := "%d permanent Hangar upgrades active on this flight." % hangar_count
	if build_show_all and hangar_count > 0:
		support += "\n" + "\n".join(hangar_lines)
	_reading_card(body, "HANGAR SUPPORT", support, AMBER)
	var resume := _reading_cta(footer, "Back to pause" if build_return_mode == "paused" else "Resume flight", _toggle_pause, true)
	_reading_cta(footer, "Main menu", _build_to_menu)
	resume.grab_focus()

func _toggle_build_details() -> void:
	build_show_all = not build_show_all
	_show_build()

func _build_to_menu() -> void:
	if mode != "build":
		return
	_save_run()
	_show_menu()


func _show_loadout() -> void:
	mode = "loadout"
	var box := _panel(540)
	_label(box, "FLIGHT CREW & FLEET", 26, CYAN)
	_wrapped(box, "Unlocks are permanent. Equip one ship and one pilot; both apply to your next new flight. Suspended runs remain unchanged.", 13)
	_label(box, "AVAILABLE CORES  %d" % profile.cores, 17, AMBER)
	var nav := HBoxContainer.new()
	box.add_child(nav)
	_button(nav, "‹ Hangar", _show_hangar)
	var tabs := HBoxContainer.new()
	box.add_child(tabs)
	for tab in ["Ships", "Pilots"]:
		var button := _button(tabs, tab, _loadout_tab.bind(tab), tab == loadout_tab)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var entries: Array = Catalog.SHIPS if loadout_tab == "Ships" else Catalog.PILOTS
	var key := "ship" if loadout_tab == "Ships" else "pilot"
	var owned_key := "ships_owned" if loadout_tab == "Ships" else "pilots_owned"
	for entry in entries:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _style(Color("152435"), CYAN if profile[key] == entry.id else Color("314458")))
		box.add_child(panel)
		var row := HBoxContainer.new()
		panel.add_child(row)
		var badge := IconBadge.new()
		badge.icon_id = entry.id
		badge.custom_minimum_size = Vector2(42, 42)
		row.add_child(badge)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		_label(details, entry.name, 17, Color.WHITE)
		_wrapped(details, entry.description, 12)
		var is_owned: bool = entry.id in profile[owned_key]
		var equipped: bool = profile[key] == entry.id
		var label_text := "EQUIPPED" if equipped else ("EQUIP" if is_owned else "UNLOCK · %d" % entry.cost)
		var choose := _button(details, label_text, _select_loadout.bind(key, entry.id))
		choose.custom_minimum_size.y = 36
		choose.disabled = equipped or (not is_owned and profile.cores < int(entry.cost))
	_button(box, "Back to Hangar", _show_hangar, true).grab_focus()

func _loadout_tab(value: String) -> void:
	loadout_tab = value
	_show_loadout()

func _select_loadout(key: String, id: String) -> void:
	if key not in ["ship", "pilot"]:
		return
	var entries: Array = Catalog.SHIPS if key == "ship" else Catalog.PILOTS
	var item: Dictionary = {}
	for candidate in entries:
		if candidate.id == id:
			item = candidate
			break
	if item.is_empty():
		return
	var owned_key := "ships_owned" if key == "ship" else "pilots_owned"
	if id not in profile[owned_key]:
		if profile.cores < int(item.cost):
			return
		profile.cores -= int(item.cost)
		profile[owned_key].append(id)
	profile[key] = id
	_save_profile()
	sound.play("card")
	_show_loadout()

func _draw() -> void:
	if sim == null or field.size.x == 0:
		return
	var screen := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, screen), Color("050914"))
	draw_texture_rect(Playfield.SPACE, Rect2(Vector2.ZERO, screen), false, Color(0.23, 0.28, 0.36, 0.45))
	if screen.x > 950:
		draw_string(ThemeDB.fallback_font, Vector2(32, 58), "S T A R / R U N", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, CYAN)
		draw_string(ThemeDB.fallback_font, Vector2(screen.x - 220, 56), "FOUR STAGES  /  0.5", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
	draw_rect(field.grow(1), Color("29414b"), false, 1)
