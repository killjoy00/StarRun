extends Node2D
const Simulation = preload("res://scripts/simulation.gd")
const Services = preload("res://scripts/platform_services.gd")
const Sound = preload("res://scripts/sound.gd")
const Playfield = preload("res://scripts/playfield.gd")
const CYAN := Color("66f5df")
const AMBER := Color("ffc078")
const INK := Color("080e1c")
const MUTED := Color("8797ad")
var sim: RefCounted
var services := Services.new()
var sound: Node
var profile := {"cores": 0, "runs": 0, "hangar": {"hull": 0, "damage": 0, "regen": 0}, "sound": true, "music": true, "reduced": false, "last_paid_run": -1}
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
var pause_button: Button
var sound_button: Button
var music_button: Button
var low_fx_button: Button
var card_buttons: Array[Button] = []
var previous_ready := {"aegis": true, "nova": true}
var previous_warning := false
var last_hull := 100.0
var card_selection := 0
var banner_text := ""
var banner_clock := 0.0
var old_size := Vector2.ZERO

func _ready() -> void:
	var saved := services.read_save(Services.PROFILE)
	if not saved.is_empty():
		profile.merge(saved, true)
	sound = Sound.new()
	add_child(sound)
	sound.enabled = profile.sound
	sound.music_enabled = profile.music
	sim = Simulation.new(1, profile.hangar)
	_build_ui()
	_layout()
	_show_menu()
	get_tree().auto_accept_quit = false

func _style(bg: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(4)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

func _label(parent: Node, text_value: String, font_size: int = 16, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, title: String, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = title
	button.add_theme_font_size_override("font_size", 16)
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
	hud = _label(root, "", 14, CYAN)
	status = _label(root, "", 13, MUTED)
	build_label = _label(root, "", 14, MUTED)
	report_label = _label(root, "", 14, MUTED)
	ability_a = _button(root, "1  AEGIS", func(): _activate("aegis"), true)
	ability_b = _button(root, "2  NOVA", func(): _activate("nova"))
	pause_button = _button(root, "Ⅱ", _toggle_pause)
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
	var usable_height := maxf(280, size.y - 164)
	scale_factor = minf((size.x - 24) / 540.0, usable_height / 960.0)
	field = Rect2(Vector2((size.x - 540 * scale_factor) / 2, 75), Vector2(540, 960) * scale_factor)
	clip.position = field.position
	clip.size = field.size
	world.scale = Vector2.ONE * scale_factor
	hud.position = Vector2(field.position.x, 16)
	hud.size = Vector2(field.size.x, 24)
	status.position = Vector2(field.position.x, 43)
	status.size = Vector2(field.size.x, 22)
	var button_width := (field.size.x - 72) / 2
	ability_a.position = Vector2(field.position.x, field.end.y + 12)
	ability_a.size = Vector2(button_width, 58)
	ability_a.add_theme_font_size_override("font_size", 14)
	ability_b.add_theme_font_size_override("font_size", 14)
	ability_b.position = ability_a.position + Vector2(button_width + 8, 0)
	ability_b.size = ability_a.size
	pause_button.position = ability_b.position + Vector2(button_width + 8, 0)
	pause_button.size = Vector2(48, 58)
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

func _clear_overlay() -> void:
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	card_buttons.clear()

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
	panel.add_child(box)
	return box

func _wrapped(parent: Node, value: String, size: int = 15, color: Color = MUTED) -> Label:
	var label := _label(parent, value, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _show_menu() -> void:
	mode = "menu"
	var box := _panel()
	_label(box, "S T A R / R U N", 38, CYAN)
	_label(box, "DEBRIS BELT   /   FLIGHT 01", 13, AMBER)
	_wrapped(box, "Build the ship. Read the threat. Choose your moment.", 19, Color.WHITE)
	_wrapped(box, "Your ship flies and fires itself. Aegis blocks incoming damage; Nova clears missiles and interrupts charging beams. Choose an upgrade whenever you level up.")
	_wrapped(box, "About five minutes. One boss. No steering.", 14)
	if not services.read_save(Services.RUN).is_empty():
		_button(box, "Resume flight", _resume_run, true)
	_button(box, "Launch new flight", _new_run, not FileAccess.file_exists(Services.RUN)).grab_focus()
	_button(box, "Hangar · %d cores" % profile.cores, _show_hangar)
	var row := HBoxContainer.new()
	box.add_child(row)
	var effects_toggle := _button(row, "Effects " + ("on" if profile.sound else "off"), _toggle_sound)
	var music_toggle := _button(row, "Music " + ("on" if profile.music else "off"), _toggle_music)
	var glow_toggle := _button(row, "Glow " + ("low" if profile.reduced else "full"), _toggle_fx)
	for toggle in [effects_toggle, music_toggle, glow_toggle]:
		toggle.add_theme_font_size_override("font_size", 12)
	_label(box, "Keys 1 / 2 · Controller A / X · Esc: pause", 12, MUTED)

func _new_run() -> void:
	profile.runs += 1
	_save_profile()
	sim = Simulation.new(61000 + int(profile.runs) * 7919, profile.hangar)
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
	previous_ready = {"aegis": sim.cooldowns.aegis <= 0, "nova": sim.cooldowns.nova <= 0}
	banner_text = "AEGIS blocks. NOVA interrupts."
	banner_clock = 5.0
	sound.play("start")
	_save_run()

func _process(delta: float) -> void:
	visual_time += delta
	banner_clock = maxf(0.0, banner_clock - delta)
	if old_size != get_viewport_rect().size:
		_layout()
	if mode == "playing":
		accumulator += minf(delta, 0.2)
		while accumulator >= Simulation.DT and mode == "playing":
			sim.step()
			accumulator -= Simulation.DT
			if sim.ended:
				_finish()
			elif not sim.cards.is_empty():
				_show_cards()
		var warning: bool = not sim.charges.is_empty()
		if warning and not previous_warning:
			sound.play("warning")
		previous_warning = warning
		for key in previous_ready:
			var ready: bool = sim.cooldowns[key] <= 0
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
	queue_redraw()
	world.queue_redraw()

func _update_hud() -> void:
	hud.text = "HULL %03d    SHIELD %02d    LV %02d" % [sim.hull, sim.shield, sim.level]
	var seconds := int(sim.time)
	status.text = "%02d:%02d  /  DEBRIS BELT%s" % [seconds / 60, seconds % 60, "  ·  BOSS" if sim.boss_spawned else ""]
	for pair in [[ability_a, "aegis", "1  AEGIS"], [ability_b, "nova", "2  NOVA"]]:
		var cooldown: float = sim.cooldowns[pair[1]]
		pair[0].text = pair[2] + ("\n%.1fs" % cooldown if cooldown > 0 else "\nREADY")
		pair[0].disabled = mode != "playing" or cooldown > 0
	build_label.text = "V A N G U A R D\nAUTOPILOT ONLINE\n\nWEAPONS\n\nPulse cannon   %d / 5\nSeeker pods    %d / 5\n\nSeeker priority:\nCharging source\n→ Missile → Nearest\n\nSYSTEMS\n\nArmor         %d / 5\nRegenerator   %d / 5\nHull plating  %d / 5\nCoolant loop  %d / 5\n\nABILITIES\n\nAegis field   %d / 5\nNova pulse    %d / 5" % [sim.upgrades.pulse, sim.upgrades.seeker, sim.upgrades.armor, sim.upgrades.regen, sim.upgrades.hull, sim.upgrades.coolant, sim.upgrades.aegis, sim.upgrades.nova]
	report_label.text = "F L I G H T   D A T A\n\nSECTOR 01 / 04\nDEBRIS BELT\n\n%s\n\nTHREAT KEY\n\n●  Chaff · armor / shield\n◇  Missile · seekers / Nova\n┃  Heavy · Aegis / interrupt\n\nFLIGHT PLAN\n\nDotted path: next 2 seconds\nAmber lane: incoming beam\n\nKills             %d\nBeams cancelled   %d\nDamage blocked    %d\n\nSEED %d" % ["HARVESTER ENGAGED" if sim.boss_spawned else "Harvester at 04:00", sim.kills, sim.beams_cancelled, sim.prevented, sim.seed_value]

func _activate(id: String) -> void:
	if mode == "playing" and sim.activate(id):
		sound.play(id)
		if not sim.cards.is_empty():
			_show_cards()

func _show_cards() -> void:
	mode = "cards"
	_save_run()
	card_selection = 0
	var box := _panel(460)
	_label(box, "UPLINK AVAILABLE", 13, CYAN)
	_label(box, "Choose your upgrade", 26)
	_label(box, "LEVEL %02d · Flight paused" % sim.level, 14, MUTED)
	for i in range(sim.cards.size()):
		var card: Dictionary = sim.cards[i]
		var current: int = int(sim.upgrades.get(card.id, 0))
		var title := "%d   %s    %s\n%s" % [i + 1, card.name.to_upper(), "LV %d → %d" % [current, current + 1] if card.id != "repair" else "", card.description]
		var button := _button(box, title, _choose.bind(i))
		button.add_theme_font_size_override("font_size", 14)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 96
		card_buttons.append(button)
	if not card_buttons.is_empty():
		card_buttons[0].grab_focus()
	sound.play("card")

func _choose(index: int) -> void:
	if mode == "cards" and sim.choose_card(index):
		_clear_overlay()
		mode = "playing"
		accumulator = -0.25
		_save_run()

func _toggle_pause() -> void:
	if mode == "playing":
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
	_button(box, "Effects: " + ("on" if profile.sound else "off"), _toggle_sound)
	_button(box, "Music: " + ("on" if profile.music else "off"), _toggle_music)
	_button(box, "Glow: " + ("low" if profile.reduced else "full"), _toggle_fx)
	_button(box, "Save & return to hangar", _show_menu)

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
	var box := _panel(490)
	_label(box, "SECTOR CLEARED" if sim.won else "SIGNAL LOST", 32, CYAN if sim.won else AMBER)
	_wrapped(box, "Harvester destroyed. The belt is behind you." if sim.won else "The flight recorder survived. Here's what happened.", 16, Color.WHITE)
	_label(box, "%02d:%02d survived · %d kills · +%d cores" % [int(sim.time) / 60, int(sim.time) % 60, sim.kills, sim.payout()], 14, CYAN)
	_wrapped(box, "DAMAGE RECEIVED\nChaff %.0f   Heavy %.0f   Missiles %.0f   Hazards %.0f\n\nWEAPON DAMAGE\nPulse %.0f   Seekers %.0f   Nova %.0f\n\n%d beams cancelled · %.0f damage blocked" % [sim.damage_taken.chaff, sim.damage_taken.heavy, sim.damage_taken.ordnance, sim.damage_taken.hazard, sim.damage_dealt.pulse, sim.damage_dealt.seeker, sim.damage_dealt.nova, sim.beams_cancelled, sim.prevented], 14)
	var recap := "FINAL 10 SECONDS"
	var count := 0
	for i in range(sim.events.size() - 1, -1, -1):
		var event: Dictionary = sim.events[i]
		if event.time >= sim.time - 10 and count < 5:
			recap += "\n−%.1fs  %s" % [sim.time - event.time, event.message]
			count += 1
	_wrapped(box, recap, 13, MUTED)
	_button(box, "Launch another flight", _new_run, true).grab_focus()
	_button(box, "Hangar · %d cores" % profile.cores, _show_hangar)

func _show_hangar() -> void:
	mode = "hangar"
	var box := _panel()
	_label(box, "VANGUARD HANGAR", 26, CYAN)
	_label(box, "%d CORES AVAILABLE" % profile.cores, 14, AMBER)
	_wrapped(box, "Small upgrades between flights. The belt can be cleared without them. Respec returns every core.")
	for entry in [["hull", "Hull bay", "+10 starting hull"], ["damage", "Armory", "+8% weapon damage"], ["regen", "Shield lab", "+0.25 shield / second"]]:
		var bought: int = int(profile.hangar[entry[0]])
		var button := _button(box, "%s %d / 3 · %s\n5 cores" % [entry[1], bought, entry[2]], _purchase.bind(entry[0]))
		button.disabled = profile.cores < 5 or bought >= 3
	_button(box, "Respec · refund all upgrades", _respec)
	_button(box, "Back to flight deck", _show_menu, true).grab_focus()

func _purchase(id: String) -> void:
	if profile.cores >= 5 and profile.hangar[id] < 3:
		profile.cores -= 5
		profile.hangar[id] += 1
		_save_profile()
		_show_hangar()

func _respec() -> void:
	for key in profile.hangar:
		profile.cores += int(profile.hangar[key]) * 5
		profile.hangar[key] = 0
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

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_ESCAPE, KEY_P]:
		_toggle_pause()
	elif mode == "playing":
		if event.keycode in [KEY_1, KEY_SPACE]:
			_activate("aegis")
		elif event.keycode == KEY_2:
			_activate("nova")
	elif mode == "cards" and event.keycode in [KEY_1, KEY_2, KEY_3]:
		_choose(event.keycode - KEY_1)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START:
			_toggle_pause()
		elif mode == "playing":
			if event.button_index == JOY_BUTTON_A:
				_activate("aegis")
			elif event.button_index == JOY_BUTTON_X:
				_activate("nova")

func _draw() -> void:
	if sim == null or field.size.x == 0:
		return
	var screen := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, screen), Color("050914"))
	draw_texture_rect(Playfield.SPACE, Rect2(Vector2.ZERO, screen), false, Color(0.23, 0.28, 0.36, 0.45))
	if screen.x > 950:
		draw_string(ThemeDB.fallback_font, Vector2(32, 58), "S T A R / R U N", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, CYAN)
		draw_string(ThemeDB.fallback_font, Vector2(screen.x - 220, 56), "FIRST FLIGHT  /  0.2", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
	draw_rect(field.grow(1), Color("29414b"), false, 1)
