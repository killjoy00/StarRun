extends Node2D
const Simulation = preload("res://scripts/simulation.gd")
const Services = preload("res://scripts/platform_services.gd")
const Sound = preload("res://scripts/sound.gd")
const Playfield = preload("res://scripts/playfield.gd")
const Catalog = preload("res://scripts/catalog.gd")
const HangarBay = preload("res://scripts/hangar_bay.gd")
const IconBadge = preload("res://scripts/icon_badge.gd")
const Kit = preload("res://scripts/menu_kit.gd")
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
var confirm_key := "" # Second-tap confirmation for permanent or bulk actions.
var draft_guard := 0.0
var banish_mode := false
var loadout_return := "hangar"
var briefing_launch := false
var sheet_base := "menu" # Screen shown beneath a settings, briefing or confirmation sheet.

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
	overlay.size = size
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
	if mode in ["settings", "briefing"]:
		if mode == "settings":
			_show_settings()
		else:
			_show_briefing(briefing_launch)
	elif mode == "abandon":
		_confirm_abandon(sheet_base)
	elif mode == "menu":
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

func _touch_first() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")

## Safe-area margins in logical canvas units. get_display_safe_area() reports
## display pixels, so it is scaled into the 390-point canvas before use.
func _insets() -> Dictionary:
	var view := get_viewport_rect().size
	var top := 0.0
	var bottom := 0.0
	if OS.has_feature("mobile"):
		var window := Vector2(DisplayServer.window_get_size())
		var safe := DisplayServer.get_display_safe_area()
		if window.x > 0.0 and safe.size.x > 0:
			var k := view.x / window.x
			top = float(safe.position.y) * k
			bottom = maxf(0.0, (window.y - float(safe.end.y)) * k)
	return {"top": maxf(top, 14.0), "bottom": maxf(bottom, 14.0)}

func _focus(control: Control) -> void:
	# Focus rings help keyboards and controllers; on a touch screen they read as a stray selection.
	if control != null and not _touch_first():
		control.grab_focus()

func _ui_button(parent: Node, title: String, action: Callable, kind: String = "secondary", height: float = 48.0, in_row: bool = false) -> Button:
	var button := Button.new()
	button.text = title
	Kit.style_button(button, kind, 18 if kind == "primary" else 16, 10, 8.0 if in_row else 14.0)
	button.custom_minimum_size.y = height
	if in_row:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _icon_button(parent: Node, kind: String, action: Callable, tooltip: String) -> Button:
	var button := Button.new()
	Kit.style_button(button, "secondary", 16, 12, 0.0)
	button.custom_minimum_size = Vector2(44, 44)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.tooltip_text = tooltip
	button.pressed.connect(action)
	parent.add_child(button)
	var icon := Kit.glyph(button, kind, Kit.TEXT, 22)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 11
	icon.offset_top = 11
	icon.offset_right = -11
	icon.offset_bottom = -11
	return button

func _wallet() -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", Kit.box(Color("1f1910"), Color("4d3c22"), 22, 1, 12, 7))
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.tooltip_text = "Cores. Spend them in the Hangar."
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	chip.add_child(row)
	row.add_child(Kit.core_icon(16))
	Kit.label(row, str(profile.cores), 18, Kit.AMBER)
	return chip

func _chip(parent: Node, text_value: String, color: Color, filled: bool = false) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", Kit.box(Color(color, 0.22 if filled else 0.08), Color(color, 0.55), 20, 1, 10, 3))
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	var text := Kit.label(row, text_value, 14, color)
	text.add_theme_font_override("font", Kit.font(1, 0.25))
	return chip

func _section(parent: Node, text_value: String, color: Color = Kit.AMBER) -> Label:
	var heading := Kit.label(parent, text_value, 17, color)
	heading.add_theme_font_override("font", Kit.font(0, 0.35))
	return heading

func _backdrop(alpha: float) -> void:
	var screen := get_viewport_rect().size
	var shade := ColorRect.new()
	shade.color = Color(Color("050a14"), alpha)
	shade.size = screen
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	if alpha >= 0.99:
		var art := TextureRect.new()
		art.texture = Playfield.SPACE
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.size = screen
		art.modulate = Color(0.30, 0.38, 0.52, 0.32)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(art)

## A full screen: header on top, body in the middle, actions pinned to the bottom
## where a thumb reaches them.
func _page(alpha: float = 1.0, scroll: bool = true, width: float = 520.0) -> Dictionary:
	_clear_overlay()
	_backdrop(alpha)
	var screen := get_viewport_rect().size
	var inset := _insets()
	var w := minf(width, screen.x - 32.0)
	var frame := VBoxContainer.new()
	frame.position = Vector2((screen.x - w) * 0.5, float(inset.top) + 4.0)
	frame.size = Vector2(w, screen.y - float(inset.top) - float(inset.bottom) - 8.0)
	frame.add_theme_constant_override("separation", 14)
	overlay.add_child(frame)
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	frame.add_child(top)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reading_scroll = null
	if scroll:
		reading_scroll = ScrollContainer.new()
		reading_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		reading_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		frame.add_child(reading_scroll)
		reading_scroll.add_child(body)
	else:
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		frame.add_child(body)
	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	frame.add_child(bottom)
	reading_footer = HBoxContainer.new()
	reading_footer.add_theme_constant_override("separation", 8)
	bottom.add_child(reading_footer)
	reading_panel = frame
	return {"top": top, "body": body, "bottom": bottom, "footer": reading_footer, "frame": frame}

func _page_header(top: VBoxContainer, eyebrow: String, title: String, back: Callable = Callable(), wallet: bool = false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	top.add_child(row)
	if back.is_valid():
		_icon_button(row, "back", back, "Back")
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(titles)
	if not eyebrow.is_empty():
		var over := Kit.caps(titles, eyebrow, Kit.AMBER, 13)
		over.clip_text = true
		over.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var heading := Kit.label(titles, title, 26, Color.WHITE, true)
	heading.add_theme_font_override("font", Kit.font(0, 0.45))
	if wallet:
		row.add_child(_wallet())

## A sheet rising from the bottom edge (centred on wide screens). Pass clear=false
## to lay it over the current screen instead of replacing it.
func _sheet(title: String, eyebrow: String = "", dismiss: Callable = Callable(), clear: bool = true) -> VBoxContainer:
	if clear:
		_clear_overlay()
	var screen := get_viewport_rect().size
	var inset := _insets()
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.72)
	shade.size = screen
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	if dismiss.is_valid():
		shade.gui_input.connect(_on_shade_input.bind(dismiss))
	overlay.add_child(shade)
	var compact := _compact_ui()
	var w := minf(500.0, screen.x)
	var panel := PanelContainer.new()
	var style := Kit.box(Color("0c1727"), Color("2a4257"), 20, 1, 20, 18)
	if compact:
		style.corner_radius_bottom_left = 0
		style.corner_radius_bottom_right = 0
		style.border_width_bottom = 0
		style.content_margin_bottom = 16.0 + float(inset.bottom)
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)
	if compact:
		panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	else:
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	# Presets keep the old rect by rewriting offsets; reset them so the sheet sizes to content.
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0
	panel.offset_left = -w * 0.5
	panel.offset_right = w * 0.5
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	if compact:
		var grip := ColorRect.new()
		grip.color = Color("2f465c")
		grip.custom_minimum_size = Vector2(40, 4)
		grip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(grip)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	box.add_child(titles)
	if not eyebrow.is_empty():
		Kit.caps(titles, eyebrow, Kit.AMBER, 13)
	var heading := Kit.label(titles, title, 24, Color.WHITE, true)
	heading.add_theme_font_override("font", Kit.font(0, 0.45))
	reading_panel = panel
	return box

## A card the whole surface of which is the tap target. Returns its content box.
func _tap_card(parent: Node, action: Callable, accent: Color, selected: bool = false) -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Kit.box(Kit.SURFACE_HI if selected else Kit.SURFACE, accent if selected else Kit.LINE, 14, 2 if selected else 1, 0, 0))
	parent.add_child(panel)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 14)
	pad.add_theme_constant_override("margin_right", 14)
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_bottom", 12)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(pad)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(content)
	var hit := Button.new()
	hit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("hover", Kit.box(Color(accent, 0.04), Color(accent, 0.65), 14, 1, 0, 0))
	hit.add_theme_stylebox_override("pressed", Kit.box(Color(accent, 0.14), accent, 14, 2, 0, 0))
	hit.add_theme_stylebox_override("focus", Kit.box(Color(0, 0, 0, 0), Kit.AMBER, 14, 2, 0, 0))
	hit.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	hit.pressed.connect(action)
	panel.add_child(hit)
	return {"panel": panel, "content": content, "button": hit}

func _info_card(parent: Node, heading: String, detail: String, accent: Color = Kit.CYAN) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Kit.box(Kit.SURFACE, Kit.LINE, 14, 1, 14, 12))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	panel.add_child(content)
	if not heading.is_empty():
		Kit.caps(content, heading, accent, 13)
	Kit.label(content, detail, 16, Kit.TEXT, true)
	return panel

func _tiles(parent: Node, items: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	for item in items:
		var tile := PanelContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_theme_stylebox_override("panel", Kit.box(Kit.SURFACE, Kit.LINE, 12, 1, 12, 10))
		row.add_child(tile)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 0)
		tile.add_child(stack)
		var value := Kit.label(stack, str(item[1]), 22, item[2] if item.size() > 2 else Color.WHITE)
		value.add_theme_font_override("font", Kit.font(0, 0.45))
		Kit.caps(stack, str(item[0]), Kit.MUTED, 12)
	return row

func _pips(parent: Node, filled: int, total: int, tint: Color = Kit.CYAN, next_available: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(row)
	for i in range(total):
		var pip: Control
		if next_available and i == filled:
			pip = Panel.new()
			pip.add_theme_stylebox_override("panel", Kit.box(Color("213447"), Kit.AMBER, 0, 1, 0, 0))
		else:
			pip = ColorRect.new()
			pip.color = tint if i < filled else Color("213447")
		pip.custom_minimum_size = Vector2(0, 6)
		pip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pip)
	return row

func _tabs(parent: Node, items: Array, current: String, action: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	parent.add_child(row)
	for item in items:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 0)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(column)
		var tab := Button.new()
		tab.text = str(item)
		Kit.style_button(tab, "ghost", 16, 6, 4.0)
		var active: bool = str(item) == current
		for state in ["font_color", "font_hover_color", "font_focus_color"]:
			tab.add_theme_color_override(state, Color.WHITE if active else Kit.MUTED)
		tab.custom_minimum_size.y = 44
		tab.pressed.connect(action.bind(str(item)))
		column.add_child(tab)
		var line := ColorRect.new()
		line.color = Kit.CYAN if active else Kit.LINE
		line.custom_minimum_size.y = 3 if active else 1
		column.add_child(line)
	return row

func _keep_scroll(scroll: ScrollContainer, value: int) -> void:
	# Re-rendering a list after a tap should not throw the player back to the top.
	if scroll == null or value <= 0:
		return
	get_tree().process_frame.connect(_apply_scroll.bind(scroll, value), CONNECT_ONE_SHOT)

func _apply_scroll(scroll: ScrollContainer, value: int) -> void:
	if is_instance_valid(scroll):
		scroll.scroll_vertical = value

func _on_shade_input(event: InputEvent, dismiss: Callable) -> void:
	if event is InputEventMouseButton and event.pressed:
		dismiss.call()

func _name_part(full: String, part: int) -> String:
	var pieces := full.split(" · ")
	if part < pieces.size():
		return pieces[part]
	return "" if part > 0 else full

func _difficulty_text(id: String) -> String:
	match id:
		"hard": return "Enemies get 25% more health and damage, and fire and arrive faster. Cores ×1.75."
		"insane": return "Enemies get 60% more health and damage, and fire and arrive faster. Cores ×2.5."
	return "Standard enemy strength. Cores ×1."

func _multiplier_text(id: String) -> String:
	var value := float(Catalog.REWARD_MULTIPLIERS[id])
	return str(int(value)) if is_equal_approx(value, roundf(value)) else str(value)

func _render_base(base: String) -> void:
	match base:
		"hangar": _show_hangar()
		"paused": _show_pause()
		_: _show_menu()

# ---------------------------------------------------------------------------
# Title
# ---------------------------------------------------------------------------

func _show_menu() -> void:
	mode = "menu"
	confirm_key = ""
	var view := _page(1.0, false, 460.0)
	var top: VBoxContainer = view.top
	var body: VBoxContainer = view.body
	var bottom: VBoxContainer = view.bottom
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	top.add_child(bar)
	var mark := Kit.label(bar, "STARRUN", 32, Kit.CYAN)
	mark.add_theme_font_override("font", Kit.font(5, 0.7))
	mark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(_wallet())
	_icon_button(bar, "settings", _show_settings, "Sound and effects")
	Kit.label(top, "Your ship flies and shoots on its own. You build it, and you choose when to fire its abilities.", 16, Kit.MUTED, true)
	# Hero: the equipped ship in flight. Tapping it opens Ships & pilots.
	var hero_frame := PanelContainer.new()
	hero_frame.add_theme_stylebox_override("panel", Kit.box(Color("060c17"), Kit.LINE, 16, 1, 0, 0))
	hero_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero_frame.clip_contents = true
	body.add_child(hero_frame)
	var hero := HangarBay.new()
	hero.style = "flight"
	hero.labels = false
	hero.ship_id = profile.ship
	hero.custom_minimum_size = Vector2(0, 110)
	hero_frame.add_child(hero)
	var caption := MarginContainer.new()
	for side in ["left", "right", "bottom"]:
		caption.add_theme_constant_override("margin_" + side, 14)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_frame.add_child(caption)
	var caption_row := HBoxContainer.new()
	caption_row.size_flags_vertical = Control.SIZE_SHRINK_END
	caption_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_child(caption_row)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_row.add_child(names)
	var ship: Dictionary = Catalog.ship(profile.ship)
	var pilot: Dictionary = Catalog.pilot(profile.pilot)
	var ship_name := Kit.label(names, _name_part(ship.name, 0), 22, Color.WHITE)
	ship_name.add_theme_font_override("font", Kit.font(1, 0.5))
	var role := _name_part(ship.name, 1)
	Kit.label(names, ("%s  ·  " % role if not role.is_empty() else "") + "Pilot " + _name_part(pilot.name, 0), 15, Kit.MUTED)
	var change := _chip(caption_row, "Change", Kit.CYAN)
	Kit.glyph(change.get_child(0), "next", Kit.CYAN, 14)
	var hit := Button.new()
	for state in ["normal", "disabled"]:
		hit.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("hover", Kit.box(Color(1, 1, 1, 0.03), Color(Kit.CYAN, 0.6), 16, 1, 0, 0))
	hit.add_theme_stylebox_override("pressed", Kit.box(Color(Kit.CYAN, 0.10), Kit.CYAN, 16, 2, 0, 0))
	hit.add_theme_stylebox_override("focus", Kit.box(Color(0, 0, 0, 0), Kit.AMBER, 16, 2, 0, 0))
	hit.tooltip_text = "Change ship or pilot"
	hit.pressed.connect(_open_loadout.bind("menu"))
	hero_frame.add_child(hit)
	# Difficulty as a visible three-way choice, not a button that cycles.
	Kit.caps(body, "Difficulty", Kit.MUTED, 13)
	var segments := HBoxContainer.new()
	segments.add_theme_constant_override("separation", 6)
	body.add_child(segments)
	var current := str(profile.get("difficulty", "normal"))
	for id in Catalog.DIFFICULTIES:
		var chosen: bool = id == current
		var segment := Button.new()
		segment.text = "%s\n×%s" % [str(id).capitalize(), _multiplier_text(str(id))]
		Kit.style_button(segment, ("danger" if id == "insane" else "selected") if chosen else "secondary", 16, 10, 6.0)
		if not chosen:
			for state in ["font_color", "font_hover_color", "font_focus_color"]:
				segment.add_theme_color_override(state, Kit.MUTED)
		segment.custom_minimum_size.y = 60
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.pressed.connect(_set_difficulty.bind(str(id)))
		segments.add_child(segment)
	Kit.label(body, _difficulty_text(current), 15, Kit.MUTED, true)
	# Actions: secondary row, then the one primary action at the bottom edge.
	var saved := services.read_save(Services.RUN)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bottom.add_child(row)
	bottom.move_child(row, 0)
	_ui_button(row, "Hangar", _show_hangar, "secondary", 48, true)
	_ui_button(row, "How to play", _show_briefing.bind(false), "secondary", 48, true)
	var primary: Button
	if saved.is_empty():
		primary = _ui_button(reading_footer, "Launch", _launch, "primary", 60, true)
	else:
		_ui_button(row, "New flight", _confirm_abandon.bind("menu"), "secondary", 48, true)
		primary = _ui_button(reading_footer, "Resume  ·  Stage %d" % int(saved.get("stage", 1)), _resume_run, "primary", 60, true)
	if not _touch_first():
		var keys := Kit.label(bottom, "1-4 abilities  ·  B build  ·  Tab speed  ·  Esc pause", 14, Kit.DIM, true)
		keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_focus(primary)

func _set_difficulty(id: String) -> void:
	if id in Catalog.DIFFICULTIES and id != str(profile.get("difficulty", "normal")):
		profile.difficulty = id
		_save_profile()
		sound.play("card")
	_show_menu()

func _launch() -> void:
	# The first flight gets a 20-second briefing; after that Launch means launch.
	if int(profile.runs) == 0 and not bool(profile.get("briefed", false)):
		_show_briefing(true)
		return
	_new_run()

func _launch_or_confirm(base: String) -> void:
	if services.read_save(Services.RUN).is_empty():
		_launch()
	else:
		_confirm_abandon(base)

func _show_settings() -> void:
	if mode != "settings":
		sheet_base = "paused" if mode == "paused" else "menu"
	_render_base(sheet_base)
	mode = "settings"
	var box := _sheet("Sound and effects", "Settings", _close_sheet, false)
	_toggle_row(box, "Sound effects", "Weapons, hits and ability-ready alerts.", bool(profile.sound), _toggle_sound)
	_toggle_row(box, "Music", "Soundtrack during flights.", bool(profile.music), _toggle_music)
	_toggle_row(box, "Calmer visuals", "Less glow, fewer particles and no screen shake.", bool(profile.reduced), _toggle_fx)
	_focus(_ui_button(box, "Done", _close_sheet, "primary", 52))

func _toggle_row(parent: Node, title: String, detail: String, on: bool, action: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	Kit.label(text, title, 17, Color.WHITE)
	Kit.label(text, detail, 15, Kit.MUTED, true)
	var toggle := Button.new()
	toggle.text = "On" if on else "Off"
	Kit.style_button(toggle, "selected" if on else "secondary", 16, 22, 8.0)
	toggle.custom_minimum_size = Vector2(72, 44)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.pressed.connect(action)
	row.add_child(toggle)

func _close_sheet() -> void:
	_render_base(sheet_base)

func _show_briefing(launch_after: bool = false) -> void:
	if mode != "briefing":
		briefing_launch = launch_after
		sheet_base = "menu"
	_render_base(sheet_base)
	mode = "briefing"
	var box := _sheet("How a run works", "Flight briefing", _close_sheet, false)
	var steps := [
		["Autopilot", "Your ship steers and shoots by itself. You never aim."],
		["Abilities", "The four buttons under the playfield are yours. Tap one when it's ready, then it recharges."],
		["Level up", "Pick one upgrade each level. Two matching abilities fuse into a stronger one and free a slot."],
		["Four bosses", "Clear four stages. The cores you earn buy permanent upgrades in the Hangar."],
	]
	for i in range(steps.size()):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		var number := PanelContainer.new()
		number.add_theme_stylebox_override("panel", Kit.box(Color(Kit.CYAN, 0.12), Color(Kit.CYAN, 0.6), 16, 1, 0, 0))
		number.custom_minimum_size = Vector2(32, 32)
		number.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(number)
		var digit := Kit.label(number, str(i + 1), 16, Kit.CYAN)
		digit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		digit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 0)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		Kit.label(text, str(steps[i][0]), 17, Color.WHITE)
		Kit.label(text, str(steps[i][1]), 15, Kit.MUTED, true)
	if not _touch_first():
		Kit.label(box, "Keyboard: 1-4 fire abilities, B opens your build, Tab changes speed, Esc pauses.", 14, Kit.DIM, true)
	_focus(_ui_button(box, "Launch" if briefing_launch else "Got it", _briefing_done, "primary", 56))

func _briefing_done() -> void:
	profile.briefed = true
	_save_profile()
	if briefing_launch:
		briefing_launch = false
		_new_run()
	else:
		_show_menu()

func _confirm_abandon(base: String) -> void:
	sheet_base = base
	_render_base(base)
	mode = "abandon"
	var saved := services.read_save(Services.RUN)
	var box := _sheet("Abandon your saved flight?", "New flight", _close_sheet, false)
	Kit.label(box, "You have a flight saved in Stage %d. Starting over deletes it, and it pays out no cores." % int(saved.get("stage", 1)), 16, Kit.MUTED, true)
	_focus(_ui_button(box, "Resume saved flight", _resume_run, "primary", 54))
	_ui_button(box, "Abandon and launch", _launch, "danger", 48)
	_ui_button(box, "Cancel", _close_sheet, "ghost", 44)

# ---------------------------------------------------------------------------
# Hangar
# ---------------------------------------------------------------------------

func _show_hangar() -> void:
	var prior: int = hangar_scroll.scroll_vertical if is_instance_valid(hangar_scroll) and mode == "hangar" else 0
	mode = "hangar"
	var view := _page(1.0, false, 560.0)
	var body: VBoxContainer = view.body
	_page_header(view.top, "Permanent upgrades", "Hangar", _show_menu, true)
	# Equipped ship strip, tappable to change ship or pilot.
	var strip := _tap_card(body, _open_loadout.bind("hangar"), Kit.CYAN)
	var strip_row := HBoxContainer.new()
	strip_row.add_theme_constant_override("separation", 12)
	strip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.content.add_child(strip_row)
	var bay := HangarBay.new()
	bay.ship_id = profile.ship
	bay.labels = false
	bay.custom_minimum_size = Vector2(88, 80)
	strip_row.add_child(bay)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip_row.add_child(info)
	var ship: Dictionary = Catalog.ship(profile.ship)
	var title := Kit.label(info, _name_part(ship.name, 0), 19, Color.WHITE)
	title.add_theme_font_override("font", Kit.font(0, 0.45))
	Kit.label(info, "Pilot " + _name_part(Catalog.pilot(profile.pilot).name, 0), 15, Kit.MUTED)
	var hull := int(ship.hull) + int(profile.hangar.hull) * 10
	var shield := int(ship.shield) + int(profile.hangar.shield) * 8 + (20 if profile.pilot == "engineer" else 0)
	var stat_line := "%d hull  ·  %d shield" % [hull, shield]
	if int(profile.hangar.damage) > 0:
		stat_line += "  ·  +%d%% damage" % (int(profile.hangar.damage) * 8)
	Kit.label(info, stat_line, 15, Kit.CYAN, true)
	Kit.glyph(strip_row, "next", Kit.MUTED, 18)
	_tabs(body, Catalog.GROUPS, hangar_category, _hangar_tab)
	hangar_scroll = ScrollContainer.new()
	hangar_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hangar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(hangar_scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hangar_scroll.add_child(list)
	for entry in Catalog.HANGAR:
		if entry.group == hangar_category:
			_hangar_row(list, entry)
	var refund_total := Catalog.refund(profile.hangar)
	if refund_total > 0:
		var armed := confirm_key == "refund"
		var refund := _ui_button(list, ("Tap again to refund %d cores" if armed else "Refund all upgrades  ·  %d cores") % refund_total, _refund_tap, "danger" if armed else "ghost", 44)
		refund.tooltip_text = "Every rank in every category is removed and fully refunded."
	_keep_scroll(hangar_scroll, prior)
	var launch := _ui_button(reading_footer, "Launch", _launch_or_confirm.bind("hangar"), "primary", 56, true)
	_focus(launch)

func _hangar_row(parent: Node, entry: Dictionary) -> void:
	var bought: int = int(profile.hangar[entry.id])
	var top_rank: int = int(entry.max)
	var maxed := bought >= top_rank
	var price := Catalog.price(entry.id, bought)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Kit.box(Kit.SURFACE, Color("2a5450") if bought > 0 else Kit.LINE, 12, 1, 12, 12))
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var badge := IconBadge.new()
	badge.icon_id = entry.id
	badge.custom_minimum_size = Vector2(36, 36)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(badge)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	Kit.label(info, entry.name, 17, Color.WHITE, true)
	Kit.label(info, entry.description, 15, Kit.MUTED, true)
	var progress := HBoxContainer.new()
	progress.add_theme_constant_override("separation", 8)
	info.add_child(progress)
	_pips(progress, bought, top_rank, Kit.CYAN, not maxed and int(profile.cores) >= price)
	Kit.label(progress, "%d/%d" % [bought, top_rank], 14, Kit.DIM)
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(84, 44)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if maxed:
		buy.text = "Max"
		Kit.style_button(buy, "secondary", 16, 10, 8.0)
		buy.disabled = true
	else:
		buy.text = str(price)
		buy.icon = Kit.core_texture()
		buy.add_theme_constant_override("icon_max_width", 16)
		buy.add_theme_constant_override("h_separation", 6)
		var affordable: bool = int(profile.cores) >= price
		Kit.style_button(buy, "amber" if affordable else "secondary", 17, 10, 8.0)
		buy.disabled = not affordable
		buy.tooltip_text = "Install rank %d" % (bought + 1) if affordable else "Need %d more cores" % (price - int(profile.cores))
	buy.pressed.connect(_purchase.bind(entry.id))
	row.add_child(buy)

func _refund_tap() -> void:
	if confirm_key == "refund":
		confirm_key = ""
		_respec()
	else:
		confirm_key = "refund"
		_show_hangar()

# ---------------------------------------------------------------------------
# Ships & pilots
# ---------------------------------------------------------------------------

func _open_loadout(from: String) -> void:
	loadout_return = from
	confirm_key = ""
	_show_loadout()

func _loadout_back() -> void:
	confirm_key = ""
	if loadout_return == "menu":
		_show_menu()
	else:
		_show_hangar()

func _show_loadout() -> void:
	var prior: int = reading_scroll.scroll_vertical if mode == "loadout" and is_instance_valid(reading_scroll) else 0
	mode = "loadout"
	var view := _page(1.0, true, 560.0)
	_page_header(view.top, "Next flight", "Ships & pilots", _loadout_back, true)
	_tabs(view.top, ["Ships", "Pilots"], loadout_tab, _loadout_tab)
	var body: VBoxContainer = view.body
	var ships := loadout_tab == "Ships"
	var entries: Array = Catalog.SHIPS if ships else Catalog.PILOTS
	for entry in entries:
		_loadout_card(body, entry, ships)
	_keep_scroll(reading_scroll, prior)
	_focus(_ui_button(reading_footer, "Done", _loadout_back, "primary", 54, true))

func _loadout_card(parent: Node, entry: Dictionary, ships: bool) -> void:
	var key := "ship" if ships else "pilot"
	var owned_key := "ships_owned" if ships else "pilots_owned"
	var id: String = str(entry.id)
	var owned: bool = id in profile[owned_key]
	var equipped: bool = profile[key] == id
	var cost: int = int(entry.cost)
	var armed := confirm_key == key + ":" + id
	var card := _tap_card(parent, _loadout_tap.bind(key, id), Kit.CYAN, equipped)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.content.add_child(row)
	if ships:
		var thumb := HangarBay.new()
		thumb.ship_id = id
		thumb.labels = false
		thumb.custom_minimum_size = Vector2(72, 72)
		thumb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(thumb)
	else:
		var badge := IconBadge.new()
		badge.icon_id = id
		badge.custom_minimum_size = Vector2(44, 44)
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(badge)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(head)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(names)
	var title := Kit.label(names, _name_part(entry.name, 0), 18, Color.WHITE)
	title.add_theme_font_override("font", Kit.font(0, 0.45))
	var role := _name_part(entry.name, 1) if ships else str(entry.get("trait", "")).capitalize()
	if ships and role.is_empty():
		role = "All-rounder"
	Kit.label(names, role, 15, Kit.MUTED)
	if equipped:
		var chip := _chip(head, "Equipped", Kit.CYAN, true)
		Kit.glyph(chip.get_child(0), "check", Kit.CYAN, 14)
	elif owned:
		_chip(head, "Equip", Kit.TEXT)
	elif armed:
		_chip(head, "Tap to confirm", Kit.AMBER, true)
	else:
		var price := _chip(head, str(cost), Kit.AMBER if int(profile.cores) >= cost else Kit.DIM)
		var price_row: HBoxContainer = price.get_child(0)
		var icon := Kit.core_icon(14)
		price_row.add_child(icon)
		price_row.move_child(icon, 0)
	Kit.label(info, entry.description, 15, Kit.MUTED, true)
	if ships:
		var stats := GridContainer.new()
		stats.columns = 3
		stats.add_theme_constant_override("h_separation", 10)
		stats.add_theme_constant_override("v_separation", 2)
		stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(stats)
		var values := [["Hull", float(entry.hull) / 160.0], ["Shield", float(entry.shield) / 80.0], ["Speed", (float(entry.movement) - 0.6) / 0.7]]
		for stat in values:
			var stat_name := Kit.caps(stats, str(stat[0]), Kit.DIM, 12)
			stat_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for stat in values:
			Kit.meter(stats, float(stat[1]), Kit.CYAN, 5)
		Kit.label(info, "Starts with " + str(sim.content.abilities[str(entry.signature)].name), 15, Kit.CYAN)
	if not owned and int(profile.cores) < cost:
		Kit.label(info, "Need %d more cores" % (cost - int(profile.cores)), 14, Kit.DIM)
	elif armed:
		Kit.label(info, "Unlock for %d cores? Tap again to confirm." % cost, 15, Kit.AMBER, true)

func _loadout_tap(key: String, id: String) -> void:
	var owned_key := "ships_owned" if key == "ship" else "pilots_owned"
	if id in profile[owned_key]:
		confirm_key = ""
		if profile[key] != id:
			_select_loadout(key, id)
		return
	var entries: Array = Catalog.SHIPS if key == "ship" else Catalog.PILOTS
	var cost := 0
	for candidate in entries:
		if candidate.id == id:
			cost = int(candidate.cost)
	if int(profile.cores) < cost:
		return
	# Unlocks are permanent purchases, so they take a second tap to confirm.
	var token := key + ":" + id
	if confirm_key == token:
		confirm_key = ""
		_select_loadout(key, id)
	else:
		confirm_key = token
		_show_loadout()

# ---------------------------------------------------------------------------
# Level-up draft
# ---------------------------------------------------------------------------

func _show_cards(play_sound: bool = true) -> void:
	mode = "cards"
	_save_run()
	draft_guard = 0.35
	var view := _page(0.93, true, 520.0)
	var top: VBoxContainer = view.top
	var body: VBoxContainer = view.body
	var title := "Remove an upgrade" if banish_mode else "Choose an upgrade"
	_page_header(top, "Level %d  ·  Stage %d" % [sim.level, sim.stage], title)
	if banish_mode:
		Kit.label(top, "Tap one to take it out of this run's draft pool. %d removal%s left." % [sim.banishes_left, "" if sim.banishes_left == 1 else "s"], 16, Kit.DANGER, true)
	else:
		var names := PackedStringArray()
		for slot in sim.active_slots:
			names.append(str(sim.content.abilities[str(slot)].name))
		Kit.label(top, "Abilities %d of 4:  %s" % [names.size(), ", ".join(names) if not names.is_empty() else "none yet"], 15, Kit.MUTED, true)
	for i in range(sim.cards.size()):
		_draft_card(body, i)
	if banish_mode:
		_ui_button(reading_footer, "Cancel", _toggle_banish, "secondary", 52, true)
	else:
		if sim.rerolls_left > 0:
			_draft_tool("Reroll", "%d left" % sim.rerolls_left, _draft_action.bind("reroll", 0), "Replace the whole hand. Hangar rerolls refill each stage.")
		if sim.skips_left > 0:
			_draft_tool("Skip", "+12 hull", _draft_action.bind("skip", 0), "Take no upgrade and repair 12 hull")
		if sim.banishes_left > 0:
			_draft_tool("Remove", "%d left" % sim.banishes_left, _toggle_banish, "Take one upgrade out of this run's pool")
	if not card_buttons.is_empty():
		_focus(card_buttons[0])
	if play_sound:
		sound.play("card")

func _draft_tool(title: String, detail: String, action: Callable, tooltip: String) -> void:
	var tool := _ui_button(reading_footer, "%s\n%s" % [title, detail], action, "secondary", 58, true)
	tool.add_theme_font_size_override("font_size", 15)
	tool.tooltip_text = tooltip

func _draft_card(parent: Node, i: int) -> void:
	var card: Dictionary = sim.cards[i]
	var id: String = str(card.id)
	var tag: String = str(card.tag)
	var current: int = int(sim.upgrades.get(id, 0))
	var next_rank: int = mini(int(card.max), current + (1 if tag == "ABILITY" and current == 0 else 2))
	var milestone: int = 5 if current < 5 else 10
	var reaches_milestone: bool = current < milestone and next_rank >= milestone and tag != "RECOVERY"
	var is_new_ability := tag == "ABILITY" and current == 0
	var fusion: String = sim.fusion_hint(id) if is_new_ability else ""
	var accent := Kit.CYAN
	var tag_text := ""
	if not fusion.is_empty():
		accent = Kit.VIOLET
		tag_text = "Fusion  ·  frees a slot"
	elif is_new_ability:
		tag_text = "New ability  ·  slot %d of 4" % (sim.active_slots.size() + 1)
	elif tag == "RECOVERY":
		accent = Color("7afcc0")
		tag_text = "Recovery"
	else:
		accent = Kit.CYAN if tag == "ABILITY" else (Kit.AMBER if tag == "WEAPON" else Color("9fcbff"))
		tag_text = "%s  ·  rank %d to %d" % [tag.capitalize(), current, next_rank]
	if reaches_milestone:
		tag_text = "Rank %d bonus  ·  %d to %d" % [milestone, current, next_rank]
	var removable := banish_mode and id != "repair"
	var action: Callable = _draft_action.bind("banish", i) if banish_mode else _choose.bind(i)
	var view := _tap_card(parent, action, Kit.DANGER if banish_mode else accent)
	# Only a pick that actually fuses or crosses a breakpoint gets an accent edge.
	if not banish_mode and (not fusion.is_empty() or reaches_milestone):
		view.panel.add_theme_stylebox_override("panel", Kit.box(Kit.SURFACE, accent, 14, 2, 0, 0))
	var hit: Button = view.button
	if banish_mode and not removable:
		hit.disabled = true
		view.panel.modulate = Color(1, 1, 1, 0.45)
	card_buttons.append(hit)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.content.add_child(row)
	var badge := IconBadge.new()
	badge.icon_id = id
	badge.custom_minimum_size = Vector2(40, 40)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(badge)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	Kit.caps(info, tag_text, accent, 13)
	var name_text := ("%d  " % (i + 1) if not _touch_first() else "") + str(card.name)
	var title := Kit.label(info, name_text, 19, Color.WHITE, true)
	title.add_theme_font_override("font", Kit.font(0, 0.45))
	Kit.label(info, str(card.description), 16, Kit.TEXT, true)
	if not fusion.is_empty():
		Kit.label(info, "Fuses into %s." % fusion.get_slice(":", 0), 15, Kit.VIOLET, true)
	elif current < 10 and (reaches_milestone or (not _compact_ui() and tag in ["WEAPON", "SYSTEM", "ABILITY"])):
		var reward := str(card.get("rank5" if milestone == 5 else "rank10", ""))
		if not reward.is_empty():
			Kit.label(info, ("Now: %s" % reward) if reaches_milestone else ("At rank %d: %s" % [milestone, reward]), 15, accent if reaches_milestone else Kit.MUTED, true)
	if current == 0 and tag in ["WEAPON", "SYSTEM"]:
		var link: String = sim.passive_hint(id)
		if not link.is_empty():
			Kit.label(info, "Pair: " + link.get_slice(":", 0), 15, Kit.AMBER, true)

func _toggle_banish() -> void:
	if mode != "cards":
		return
	banish_mode = not banish_mode and sim.banishes_left > 0
	_show_cards(false)

func _draft_action(action: String, index: int) -> void:
	if mode != "cards" or draft_guard > 0.0:
		return
	var changed: bool = sim.reroll_cards() if action == "reroll" else (sim.banish_card(index) if action == "banish" else sim.skip_cards())
	if not changed:
		return
	banish_mode = false
	if sim.cards.is_empty():
		mode = "playing"
		_clear_overlay()
		accumulator = -0.25
		_save_run()
	else:
		_show_cards()

func _choose(index: int) -> void:
	# A short guard stops a combat tap from picking a card the instant the draft opens.
	if mode == "cards" and draft_guard <= 0.0 and not banish_mode and sim.choose_card(index):
		_clear_overlay()
		mode = "playing"
		accumulator = -0.25
		_save_run()

# ---------------------------------------------------------------------------
# Pause and build
# ---------------------------------------------------------------------------

func _show_pause() -> void:
	mode = "paused"
	sheet_base = "paused"
	_save_run()
	var seconds := int(sim.time - sim.stage_start)
	var box := _sheet("Paused", "Stage %d  ·  %s  ·  %02d:%02d" % [sim.stage, sim.stage_name().capitalize(), seconds / 60, seconds % 60])
	Kit.label(box, "Your flight is saved. Nothing moves until you resume.", 15, Kit.MUTED, true)
	var resume := _ui_button(box, "Resume", _toggle_pause, "primary", 56)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_ui_button(row, "Build", _show_build, "secondary", 48, true)
	_ui_button(row, "Settings", _show_settings, "secondary", 48, true)
	_ui_button(box, "Save and quit to title", _show_menu, "ghost", 44)
	_focus(resume)

func _show_build() -> void:
	if mode not in ["playing", "paused", "build"]:
		return
	if mode in ["playing", "paused"]:
		build_return_mode = mode
	var prior: int = reading_scroll.scroll_vertical if mode == "build" and is_instance_valid(reading_scroll) else 0
	mode = "build"
	_save_run()
	var view := _page(0.95, true, 540.0)
	var body: VBoxContainer = view.body
	_page_header(view.top, "%s  ·  Pilot %s" % [_name_part(Catalog.ship(sim.ship_id).name, 0), _name_part(Catalog.pilot(sim.pilot_id).name, 0)], "Build")
	_tiles(body, [["Hull", "%d/%d" % [sim.hull, sim.max_hull], Kit.CYAN], ["Shield", "%d/%d" % [sim.shield, sim.max_shield], Color("9fcbff")], ["Level", str(sim.level)]])
	_section(body, "Active abilities")
	for slot in range(Catalog.ACTIVE_SLOTS):
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", Kit.box(Kit.SURFACE, Kit.LINE, 12, 1, 12, 10))
		body.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		panel.add_child(row)
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 0)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if slot >= sim.active_slots.size():
			var slot_number := Kit.label(row, str(slot + 1), 17, Kit.DIM)
			slot_number.custom_minimum_size.x = 36
			row.add_child(text)
			Kit.label(text, "Empty slot", 16, Kit.DIM)
			Kit.label(text, "Draft an ability to fill it.", 15, Kit.DIM)
			continue
		var id: String = str(sim.active_slots[slot])
		var badge := IconBadge.new()
		badge.icon_id = id
		badge.custom_minimum_size = Vector2(36, 36)
		row.add_child(badge)
		row.add_child(text)
		var fused: Dictionary = sim.fusion_spec(id)
		if not fused.is_empty():
			var part_a: String = str(fused.parts[0])
			var part_b: String = str(fused.parts[1])
			Kit.label(text, str(fused.name), 17, Kit.VIOLET)
			Kit.label(text, "Fused: %s rank %d + %s rank %d" % [sim.content.abilities[part_a].name, sim.upgrades[part_a], sim.content.abilities[part_b].name, sim.upgrades[part_b]], 15, Kit.MUTED, true)
		else:
			Kit.label(text, str(sim.content.abilities[id].name), 17, Color.WHITE)
			Kit.label(text, "Rank %d of 10" % int(sim.upgrades[id]), 15, Kit.MUTED)
	var pairs: Array = sim.active_passive_links()
	if not pairs.is_empty():
		_section(body, "Paired upgrades")
		for i in range(pairs.size() if build_show_all else mini(3, pairs.size())):
			_info_card(body, str(pairs[i].name), str(pairs[i].description), Kit.AMBER)
		if not build_show_all and pairs.size() > 3:
			Kit.label(body, "%d more in the full list below." % (pairs.size() - 3), 15, Kit.MUTED)
	var combos: Array = sim.active_synergies()
	if not combos.is_empty():
		_section(body, "Build bonuses")
		for combo in combos:
			_info_card(body, str(combo.name), str(combo.description), Kit.CYAN)
	if not sim.prototypes.is_empty():
		_section(body, "Prototype")
		for id in sim.prototypes:
			var spec: Dictionary = sim.prototype_spec(str(id))
			_info_card(body, str(spec.name), "Gain: %s\nCost: %s" % [spec.benefit, spec.cost], Kit.CYAN)
	if not sim.route_choice.is_empty():
		Kit.label(body, "Current route: " + _route_name(sim.route_choice), 16, Kit.CYAN)
	_ui_button(body, "Hide full equipment list" if build_show_all else "Show weapons, systems and Hangar ranks", _toggle_build_details, "ghost", 44)
	if build_show_all:
		for group in [["WEAPON", "Automatic weapons"], ["SYSTEM", "Ship systems"]]:
			_section(body, str(group[1]))
			for entry in sim.content.cards:
				if entry.tag == group[0] and int(sim.upgrades.get(entry.id, 0)) > 0:
					_info_card(body, "%s  ·  rank %d/10" % [entry.name, sim.upgrades[entry.id]], str(entry.description), Kit.AMBER if group[0] == "WEAPON" else Color("9fcbff"))
		_section(body, "Hangar ranks")
		var hangar_lines := PackedStringArray()
		for entry in Catalog.HANGAR:
			var rank: int = int(sim.meta.get(entry.id, 0))
			if rank > 0:
				hangar_lines.append("%s  ·  rank %d" % [entry.name, rank])
		Kit.label(body, "\n".join(hangar_lines) if not hangar_lines.is_empty() else "No Hangar upgrades yet.", 15, Kit.MUTED, true)
	_keep_scroll(reading_scroll, prior)
	var resume := _ui_button(reading_footer, "Back to pause" if build_return_mode == "paused" else "Resume", _toggle_pause, "primary", 54, true)
	_ui_button(reading_footer, "Quit to title", _build_to_menu, "secondary", 54, true)
	_focus(resume)

func _route_name(id: String) -> String:
	return str({"repair": "Repair", "overclock": "More damage", "bounty": "Bounty run"}.get(id, id.capitalize()))

# ---------------------------------------------------------------------------
# Boss down, intermission and results
# ---------------------------------------------------------------------------

func _big_stat(parent: Node, value: String, caption: String, color: Color) -> void:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(stack)
	var number := Kit.label(stack, value, 30, color)
	number.add_theme_font_override("font", Kit.font(0, 0.6))
	Kit.caps(stack, caption, Kit.MUTED, 12)

func _show_stage_clear(reset_clock: bool = true) -> void:
	if reset_clock:
		stage_clear_clock = 0.0
	mode = "stage_clear"
	_save_run()
	_clear_overlay()
	var screen := get_viewport_rect().size
	var inset := _insets()
	var shade := ColorRect.new()
	shade.color = Color(0.005, 0.012, 0.025, 0.22)
	shade.size = screen
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	var is_final: bool = sim.stage == sim.stage_count()
	var headline := VBoxContainer.new()
	headline.position = Vector2(16, float(inset.top) + 10.0)
	headline.size = Vector2(screen.x - 32, 0)
	headline.add_theme_constant_override("separation", 2)
	headline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(headline)
	var eyebrow := Kit.caps(headline, "Stage %d of %d cleared" % [sim.stage, sim.stage_count()], Kit.AMBER, 15)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := Kit.label(headline, "%s destroyed" % sim.boss_name(), 32, Color.WHITE, true)
	title.add_theme_font_override("font", Kit.font(0, 0.7))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var panel := PanelContainer.new()
	var style := Kit.box(Color(Color("0a1626"), 0.96), Kit.AMBER, 18, 2, 18, 16)
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)
	var w := minf(520.0, screen.x - 24.0)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -w * 0.5
	panel.offset_right = w * 0.5
	panel.offset_top = -float(inset.bottom) - 4.0
	panel.offset_bottom = -float(inset.bottom) - 4.0
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	Kit.caps(content, str(sim.stage_spec().reward_label), Kit.AMBER, 14)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 12)
	content.add_child(stats)
	_big_stat(stats, str(sim.payout()), "Cores so far", Kit.AMBER)
	_big_stat(stats, str(sim.kills), "Enemies destroyed", Color.WHITE)
	Kit.label(content, "Cores are paid out when the run ends.", 15, Kit.MUTED, true)
	if is_final:
		Kit.label(content, "All four stages cleared. Your full report is next.", 16, Kit.TEXT, true)
	else:
		var next: Dictionary = sim.content.stages[sim.stage]
		Kit.label(content, "Next: %s, %s. First you pick a prototype and a route." % [str(next.name).capitalize(), str(next.subtitle).to_lower()], 16, Kit.TEXT, true)
	stage_clear_button = _ui_button(content, "Claim victory" if is_final else "Warp to " + str(sim.stage_spec().transition).capitalize(), _begin_warp, "primary", 58)
	stage_clear_button.disabled = stage_clear_clock < 1.2
	if not stage_clear_button.disabled:
		_focus(stage_clear_button)
	if reset_clock:
		sound.play("boss-explosion", -4.0)

func _show_prototypes() -> void:
	mode = "prototype"
	_save_run()
	var view := _page(0.95, true, 540.0)
	_page_header(view.top, "Between stages  ·  step 1 of 2", "Pick a prototype")
	Kit.label(view.top, "You keep it for the rest of the run. Every prototype has a cost.", 16, Kit.MUTED, true)
	for i in range(sim.prototype_offers.size()):
		var spec: Dictionary = sim.prototype_spec(str(sim.prototype_offers[i]))
		var card := _tap_card(view.body, _choose_prototype.bind(i), Kit.CYAN)
		card_buttons.append(card.button)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.content.add_child(head)
		var title := Kit.label(head, str(spec.name), 19, Color.WHITE, true)
		title.add_theme_font_override("font", Kit.font(0, 0.45))
		_chip(head, str(spec.role).capitalize(), Kit.MUTED)
		_gain_cost(card.content, str(spec.benefit), str(spec.cost))
	_ui_button(reading_footer, "Save and quit to title", _show_menu, "ghost", 48, true)
	if not card_buttons.is_empty():
		_focus(card_buttons[0])

func _gain_cost(parent: Node, gain: String, cost: String) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(grid)
	for pair in [["Gain", gain, Kit.CYAN, Kit.TEXT], ["Cost", cost, Kit.AMBER, Color("ffd9b0")]]:
		var tag := Kit.caps(grid, str(pair[0]), pair[2], 13)
		tag.custom_minimum_size = Vector2(44, 23)
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		Kit.label(grid, str(pair[1]), 16, pair[3], true)

func _show_route_choice() -> void:
	mode = "route"
	_save_run()
	var view := _page(0.95, true, 540.0)
	_page_header(view.top, "Between stages  ·  step 2 of 2", "Choose your route")
	var next: Dictionary = sim.content.stages[mini(sim.stage, sim.content.stages.size() - 1)]
	Kit.label(view.top, "Next: Stage %d, %s. %s" % [sim.stage + 1, str(next.name).capitalize(), str(next.description)], 16, Kit.MUTED, true)
	var routes := [
		{"id": "repair", "tag": "Safe", "gain": "Repair 55% of hull. Shields refilled.", "cost": "No extra rewards.", "accent": Kit.CYAN},
		{"id": "overclock", "tag": "Aggressive", "gain": "Automatic weapons deal 25% more damage next stage.", "cost": "Repair only 10% of hull. Shields start at 60%.", "accent": Kit.AMBER},
		{"id": "bounty", "tag": "Risky", "gain": "+%d base cores if you beat the next boss. Repair 30%% of hull." % (20 * (sim.stage + 1)), "cost": "Enemies get 30% more health, damage and spawns.", "accent": Kit.DANGER},
	]
	for route in routes:
		var card := _tap_card(view.body, _choose_route.bind(str(route.id)), route.accent)
		card_buttons.append(card.button)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.content.add_child(head)
		var title := Kit.label(head, _route_name(str(route.id)), 19, Color.WHITE, true)
		title.add_theme_font_override("font", Kit.font(0, 0.45))
		_chip(head, str(route.tag), route.accent)
		_gain_cost(card.content, str(route.gain), str(route.cost))
	_ui_button(reading_footer, "Save and quit to title", _show_menu, "ghost", 48, true)
	if not card_buttons.is_empty():
		_focus(card_buttons[0])

func _show_results() -> void:
	mode = "results"
	var view := _page(1.0, true, 540.0)
	var body: VBoxContainer = view.body
	_page_header(view.top, "Stage %d of %d  ·  %s" % [sim.stage, sim.stage_count(), sim.difficulty.capitalize()], "Victory" if sim.won else "Ship destroyed")
	Kit.label(view.top, "Reached %s in %02d:%02d of flight." % [sim.stage_name().capitalize(), int(sim.time) / 60, int(sim.time) % 60], 16, Kit.MUTED, true)
	var hero := PanelContainer.new()
	hero.add_theme_stylebox_override("panel", Kit.box(Color("1b160f"), Color("4d3c22"), 16, 1, 16, 14))
	body.add_child(hero)
	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 12)
	hero.add_child(hero_row)
	hero_row.add_child(Kit.core_icon(30))
	var earned := Kit.label(hero_row, "+%d" % sim.payout(), 40, Kit.AMBER)
	earned.add_theme_font_override("font", Kit.font(0, 0.7))
	var hero_text := VBoxContainer.new()
	hero_text.add_theme_constant_override("separation", 0)
	hero_text.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_row.add_child(hero_text)
	Kit.label(hero_text, "cores earned", 16, Kit.TEXT)
	Kit.label(hero_text, "%d in your wallet" % int(profile.cores), 15, Kit.MUTED)
	_ui_button(body, "Spend them in the Hangar", _show_hangar, "amber", 48)
	_tiles(body, [["Kills", str(sim.kills)], ["Stages", "%d/%d" % [sim.stage_clears, sim.stage_count()]], ["Abilities used", str(sim.ability_uses)]])
	var build_lines := PackedStringArray()
	for slot in sim.active_slots:
		var fusion: Dictionary = sim.fusion_spec(str(slot))
		if not fusion.is_empty():
			build_lines.append("Fusion: " + str(fusion.name))
	for link in sim.active_passive_links():
		build_lines.append("Pair: " + str(link.name))
	for combo in sim.active_synergies():
		build_lines.append(str(combo.name).capitalize() + ": " + str(combo.description))
	for id in sim.prototypes:
		var spec: Dictionary = sim.prototype_spec(str(id))
		build_lines.append(str(spec.name) + ": " + str(spec.benefit))
	_info_card(body, "What you built", "\n".join(build_lines) if not build_lines.is_empty() else "No fusions, pairs or prototypes this time.", Kit.CYAN)
	if sim.bounty_earned > 0:
		_info_card(body, "Bounty contracts", "%d base cores from bounty runs." % sim.bounty_earned, Kit.AMBER)
	_info_card(body, "Ship at the end", "Hull %d / %d  ·  Shield %d / %d\n%.0f damage blocked  ·  %d beams cancelled" % [sim.hull, sim.max_hull, sim.shield, sim.max_shield, sim.prevented, sim.beams_cancelled], Color("9fcbff"))
	var damage_lines := PackedStringArray()
	for kind in ["chaff", "heavy", "ordnance", "hazard", "ion", "corrosion", "disrupt", "heat", "gravity", "void"]:
		var value: float = float(sim.damage_taken.get(kind, 0.0))
		if value > 0.0:
			var name: String = str({"ordnance": "Missiles", "hazard": "Hazards", "heavy": "Heavy beams"}.get(kind, kind.capitalize()))
			damage_lines.append("%s   %.0f" % [name, value])
	_info_card(body, "Damage taken", "\n".join(damage_lines) if not damage_lines.is_empty() else "No incoming damage recorded.", Kit.DANGER)
	var weapons: Array = []
	for key in sim.damage_dealt:
		var value: float = float(sim.damage_dealt[key])
		if value > 0:
			weapons.append({"name": str(key).capitalize(), "damage": value})
	weapons.sort_custom(func(a, b): return a.damage > b.damage)
	var weapon_lines := PackedStringArray()
	for i in range(mini(5, weapons.size())):
		weapon_lines.append("%s   %.0f" % [weapons[i].name, weapons[i].damage])
	_info_card(body, "Top weapons", "\n".join(weapon_lines) if not weapon_lines.is_empty() else "No weapon damage recorded.", Kit.AMBER)
	var recap := PackedStringArray()
	for i in range(sim.events.size() - 1, -1, -1):
		var event: Dictionary = sim.events[i]
		if event.time >= sim.time - 10.0 and recap.size() < 5:
			recap.append("%.1fs before the end  ·  %s" % [sim.time - event.time, event.message])
	_info_card(body, "Final ten seconds", "\n".join(recap) if not recap.is_empty() else "Nothing logged in the final ten seconds.", Kit.MUTED)
	var again := _ui_button(reading_footer, "Fly again", _new_run, "primary", 56, true)
	_ui_button(reading_footer, "Title", _show_menu, "secondary", 56, true)
	_focus(again)

func _new_run() -> void:
	banish_mode = false
	profile.runs += 1
	build_show_all = false
	_save_profile()
	sim = Simulation.new(61000 + int(profile.runs) * 7919, profile.hangar, profile.ship, profile.pilot, str(profile.get("difficulty", "normal")))
	_start_flight()

func _resume_run() -> void:
	banish_mode = false
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
	draft_guard = maxf(0.0, draft_guard - delta)
	# Combat chrome only shows while a flight is on screen; menus own the whole display.
	var in_flight: bool = mode in ["playing", "paused", "warp"] or (mode == "settings" and sheet_base == "paused")
	for control in [hud, status, build_button, pause_button, speed_button]:
		control.visible = in_flight
	for button in ability_buttons.values():
		button.visible = in_flight
	speed_button.text = str(game_speed) + "×"
	queue_redraw()
	world.queue_redraw()

func _short_ability_name(id: String) -> String:
	var names := {"overdrive":"DRIVE", "capacitor":"CHARGE", "deflector":"DEFLECT", "barrage":"ROCKETS", "barrier":"BARRIER", "salvage":"SALVAGE", "overload":"OVERLOAD", "repair_matrix":"REPAIR", "nova_aegis":"NOVA GRD", "railstorm":"RAILSTORM", "stasis_lock":"TIME LOCK", "missile_grid":"MISSILES", "scrap_converter":"SCRAP", "prism_focus":"PRISM", "reflective_wall":"REFLECT", "ghost_signal":"GHOST", "reactor_surge":"SURGE", "strike":"RAIL", "reboot":"REBOOT", "siphon":"SIPHON", "focus":"FOCUS", "flak":"FLAK", "chrono":"CHRONO", "jammer":"JAMMER", "decoy":"DECOY", "aegis":"AEGIS", "mend":"REPAIR", "emp":"EMP", "nova":"NOVA", "prism":"PRISM"}
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
		button.tooltip_text = (sim.content.abilities[id].name + (" (combined ability)" if not sim.fusion_spec(id).is_empty() else "") + "  |  Ready" if cooldown <= 0.0 else sim.content.abilities[id].name + "  |  %.1fs" % cooldown) if learned else "Empty slot"
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
				build_label.text += "%s  %d/%d\n" % [card.name, sim.upgrades[card.id], card.max]
		build_label.text += "\n"
	report_label.text = "F L I G H T   D A T A\n\n%s\n\n%s\n\nTHREAT KEY\n\n●  Chaff · armor / shield\n◇  Missile · seekers / Nova\n┃  Heavy · Aegis / interrupt\n\nFLIGHT PLAN\n\nDotted path: next 2 seconds\nCoral lane: incoming beam\n\nKills             %d\nBeams cancelled   %d\nDamage blocked    %d\n\nSEED %d" % [_sector_name(sim.time), sim.boss_name().to_upper() + " ENGAGED" if sim.boss_spawned else "Boss at 04:00", sim.kills, sim.beams_cancelled, sim.prevented, sim.seed_value]

func _activate_slot(slot: int) -> void:
	if slot >= 0 and slot < sim.active_slots.size():
		_activate(str(sim.active_slots[slot]))

func _activate(id: String) -> void:
	if mode == "playing" and sim.activate(id):
		sound.play(id if id in ["aegis", "nova", "barrage", "overdrive", "chrono", "mend"] else "nova")
		if not sim.cards.is_empty():
			_show_cards()

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

func _choose_prototype(index: int) -> void:
	if mode != "prototype" or not sim.choose_prototype(index):
		return
	sound.play("card")
	_save_run()
	_show_route_choice()

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
	if mode == "settings":
		_show_settings()
	elif mode == "menu":
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
	if event.keycode in [KEY_ESCAPE, KEY_P] and mode in ["playing", "paused", "build"]:
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
	elif event.keycode == KEY_ESCAPE and mode in ["settings", "briefing", "abandon"]:
		_close_sheet()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and mode in ["hangar", "loadout"]:
		if mode == "loadout":
			_loadout_back()
		else:
			_show_menu()
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

func _toggle_build_details() -> void:
	build_show_all = not build_show_all
	_show_build()

func _build_to_menu() -> void:
	if mode != "build":
		return
	_save_run()
	_show_menu()


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
		draw_string(ThemeDB.fallback_font, Vector2(screen.x - 220, 56), "FOUR STAGES  /  " + str(ProjectSettings.get_setting("application/config/version")), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
	draw_rect(field.grow(1), Color("29414b"), false, 1)
