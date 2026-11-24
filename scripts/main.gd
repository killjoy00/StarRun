extends Node2D
const Simulation = preload("res://scripts/simulation.gd")
const FirstFlight = preload("res://scripts/first_flight.gd")
const Services = preload("res://scripts/platform_services.gd")
const Sound = preload("res://scripts/sound.gd")
const Playfield = preload("res://scripts/playfield.gd")
const Catalog = preload("res://scripts/catalog.gd")
const HangarBay = preload("res://scripts/hangar_bay.gd")
const IconBadge = preload("res://scripts/icon_badge.gd")
const RankBar = preload("res://scripts/rank_bar.gd")
const CombatHud = preload("res://scripts/combat_hud.gd")
const InputRouter = preload("res://scripts/input_router.gd")
const Kit = preload("res://scripts/menu_kit.gd")
const PilotPortrait = preload("res://scripts/pilot_portrait.gd")
const Progress = preload("res://scripts/meta_progress.gd")
const RivalCaptains = preload("res://scripts/rival_captains.gd")
const Codex = preload("res://scripts/codex.gd")
const HiddenSector = preload("res://scripts/hidden_sector.gd")
const ArchiveIllustration = preload("res://scripts/archive_illustration.gd")
const RivalPortrait = preload("res://scripts/rival_portrait.gd")
const MerchantShip = preload("res://scripts/merchant_ship.gd")
const GameCenterBridge = preload("res://scripts/game_center_bridge.gd")
const RemoveAdsStore = preload("res://scripts/remove_ads_store.gd")
const CYAN := Color("66f5df")
const AMBER := Color("ffc078")
const INK := Color("080e1c")
const MUTED := Color("8797ad")
var sim: RefCounted
var services := Services.new()
var sound: Node
var profile := {"cores": 0, "runs": 0, "hangar": {"hull": 0, "damage": 0, "regen": 0}, "hangar_paid": {}, "sound": true, "music": true, "reduced": false, "last_paid_run": -1, "ship": "vanguard", "pilot": "rookie", "ships_owned": ["vanguard"], "pilots_owned": ["rookie"], "speed": 1.0, "difficulty": "normal", "artifact":"standard", "start_world": 1}
var mode := "menu"
var flight_started := false
var intro_panel: PanelContainer
var intro_heading: Label
var intro_caption: Label
var intro_continue: Button
var intro_marker: Panel
var intro_cue: Array = []
var intro_cue_tween: Tween
var intro_save_pending := false
var intro_clear_clock := 0.0
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
var hull_meter: ProgressBar
var shield_meter: ProgressBar
var hull_caption: Label
var shield_caption: Label
var cooldown_meters: Dictionary = {}
var build_label: Label
var report_label: Label
var ability_a: Button
var ability_b: Button
var ability_buttons: Dictionary = {} # Four UI slots, keyed by slot index.
var hangar_category := "Hull"
var loadout_tab := "Ships"
var codex_tab := "Upgrades"
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
var last_boss_kills := 0
var last_hull := 100.0
var hit_feedback_clock := 0.0
var chip_damage := 0.0
var card_selection := 0
var banner_text := ""
var banner_clock := 0.0
var last_sector := ""
var build_return_mode := "playing"
var build_show_all := false
var signal_button: Button
var signal_label: Label
var stage_clear_clock := 0.0
var stage_clear_button: Button
var stage_clear_secondary: Button
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
var pending_launch := "normal" # Normal or daily through abandon confirmation and resize.
var result_earned_cores := -1
var result_awards: Array = []
var result_daily_score := -1
var result_daily_best := -1
var result_new_best := false
var result_rival_news: Dictionary = {}
var result_unlocked: Array = []
var rival_stinger_clock := 0.0
var boss_intro_clock := 0.0
var boss_intro_stage := 0 # The world whose boss intro has played; not replayed on resume.
const BOSS_INTRO_SECONDS := 2.6
const BOSS_TAGLINES := {
	"Harvester": "Strips wrecks for parts. Yours are next.",
	"Storm Carrier": "A flying storm with a hangar full of drones.",
	"Crucible Engine": "The furnace that runs the Foundry. It runs hot.",
	"Void Regent": "Rules the Citadel. Nobody has seen it lose.",
}
var opening_last_phase := ""
# Restrained one-shot audio/haptic responses to meaningful build payoffs.
var spectacle_audio_wait := 0.0
var spectacle_audio_seen := {}
var spectacle_audio_order: Array = []
var spectacle_audio_run: RefCounted
var game_center := GameCenterBridge.new()
var daily_share_service: Object = null
var pending_share_text := ""
var toast_layer: Control
var toast_panel: PanelContainer
var toast_title: Label
var toast_detail: Label
var toast_queue: Array = []
var toast_clock := 0.0
var native_ad_banner: Node = null
var ad_banner_visible := false
var remove_ads_store: Node = null

func _ready() -> void:
	var saved := services.read_save(Services.PROFILE)
	# Test doubles may not implement the recovery fields; read them defensively.
	var profile_recovery := str(services.get("last_recovery")) if services.get("last_recovery") != null else ""
	if not saved.is_empty():
		profile.merge(saved, true)
	if not profile.has("intro_status"):
		var old_flight := services.read_save(Services.RUN)
		var fresh := saved.is_empty() and (old_flight.is_empty() or bool(old_flight.get("intro_reward_eligible", false)))
		profile.intro_status = "available" if fresh else "legacy"
	var hangar := Catalog.defaults()
	hangar.merge(profile.hangar, true)
	profile.hangar = hangar
	# Migrate existing ranks at their historical prices. Later purchases append
	# their exact paid cost, keeping Refund All fair after the price increase.
	var receipt: Variant = profile.get("hangar_paid", {})
	var paid: Dictionary = receipt if receipt is Dictionary else {}
	for entry in Catalog.HANGAR:
		var id: String = str(entry.id)
		if not paid.has(id):
			var historical := 0
			for rank in range(int(hangar.get(id, 0))):
				historical += Catalog.legacy_price(id, rank)
			paid[id] = historical
	profile.hangar_paid = paid
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
	Progress.prepare(profile)
	if str(Catalog.artifact(str(profile.get("artifact","standard"))).id) != str(profile.get("artifact","standard")):
		profile.artifact = "standard"
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
	_initialize_native_banner()
	remove_ads_store = RemoveAdsStore.new()
	add_child(remove_ads_store)
	remove_ads_store.changed.connect(_on_remove_ads_store_changed)
	# Do not offer a purchase that has no benefit in the ad-free first release.
	# The 0.9.6 TestFlight sandbox build remains pinned to the earlier source.
	if _ad_monetization_enabled():
		remove_ads_store.initialize(self, bool(profile.get("remove_ads", false)))
	game_center.initialize(profile, _save_profile)
	# The iOS-only outgoing share plugin exposes UIActivityViewController.
	if OS.has_feature("ios") and Engine.has_singleton("SharePlugin"):
		daily_share_service = Engine.get_singleton("SharePlugin")
		daily_share_service.share_failed.connect(_on_native_share_failed)
		daily_share_service.share_completed.connect(_on_native_share_completed)
		daily_share_service.share_canceled.connect(_on_native_share_canceled)
	get_tree().auto_accept_quit = false
	# Only the real launched game owns the OS window; test harnesses size it.
	if get_tree().current_scene == self:
		_apply_window_mode()
	# Android Back must never kill a flight; _notification routes it instead.
	get_tree().quit_on_go_back = false
	if profile_recovery == "corrupt":
		_queue_toast("Profile could not be read", "Starting fresh. The damaged save was kept on this device.")
	elif profile_recovery in ["tmp", "backup"]:
		_queue_toast("Profile recovered", "Your progress was restored from the last good save.")
		_save_profile()


# The iPhone ad SDK is installed only during ad-enabled native exports.
# On all other platforms this controller does nothing.
func _ad_monetization_enabled() -> bool:
	var path := "res://data/admob.json"
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed is Dictionary and bool(parsed.get("enabled", false))


func _initialize_native_banner() -> void:
	if OS.get_name() != "iOS" or bool(profile.get("remove_ads", false)):
		return
	var cfg_path := "res://data/admob.json"
	if not FileAccess.file_exists(cfg_path):
		return
	var cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string(cfg_path))
	if not cfg is Dictionary or not bool(cfg.get("enabled", false)):
		return
	var runtime_path := "res://scripts/admob_native_runtime.gd"
	if not ResourceLoader.exists(runtime_path):
		push_warning("AdMob enabled but no native runtime was exported.")
		return
	var native_script: Script = load(runtime_path)
	if native_script == null:
		return
	native_ad_banner = native_script.new()
	native_ad_banner.call("setup", self, str(cfg.get("banner_unit_id", "")))
	add_child(native_ad_banner)

func _on_ad_banner_visibility(is_shown: bool) -> void:
	if ad_banner_visible == is_shown:
		return
	ad_banner_visible = is_shown
	_layout()

func _show_ad_privacy_options() -> void:
	if is_instance_valid(native_ad_banner):
		native_ad_banner.call("show_privacy_options")

func _on_remove_ads_store_changed() -> void:
	if is_instance_valid(native_ad_banner):
		native_ad_banner.call("set_entitlement_checked", bool(remove_ads_store.checked))
		native_ad_banner.call("set_ads_removed", bool(remove_ads_store.owned))
	if mode == "settings":
		_show_settings()

func _on_remove_ads_entitled() -> bool:
	# Only called after on-device StoreKit verified an owned non-consumable.
	profile.remove_ads = true
	_save_profile()
	if is_instance_valid(native_ad_banner):
		native_ad_banner.call("set_ads_removed", true)
	_on_ad_banner_visibility(false)
	return bool(profile.get("remove_ads", false))

func _on_remove_ads_revoked() -> void:
	# Apple no longer lists the purchase (for example, it was refunded).
	profile.remove_ads = false
	_save_profile()
	if is_instance_valid(native_ad_banner):
		native_ad_banner.call("set_ads_removed", false)

func _buy_remove_ads() -> void:
	if is_instance_valid(remove_ads_store):
		remove_ads_store.buy()

func _restore_remove_ads() -> void:
	if is_instance_valid(remove_ads_store):
		remove_ads_store.restore()

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

func _haptic(milliseconds: int) -> void:
	if OS.has_feature("mobile") and not bool(profile.get("reduced", false)):
		Input.vibrate_handheld(milliseconds)

func _meter(tint: Color) -> ProgressBar:
	var meter := ProgressBar.new()
	meter.show_percentage = false
	meter.min_value = 0.0
	meter.max_value = 100.0
	meter.value = 100.0
	var background := StyleBoxFlat.new()
	background.bg_color = Color("162338")
	background.set_corner_radius_all(6)
	meter.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = tint
	fill.set_corner_radius_all(6)
	meter.add_theme_stylebox_override("fill", fill)
	return meter

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
	button.pressed.connect(_haptic.bind(12))
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
	hull_meter = _meter(CYAN)
	shield_meter = _meter(Color("80aaff"))
	root.add_child(hull_meter)
	root.add_child(shield_meter)
	hull_caption = _label(root, "", 14, Color.WHITE)
	shield_caption = _label(root, "", 14, Color.WHITE)
	build_label = _label(root, "", 14, MUTED)
	report_label = _label(root, "", 14, MUTED)
	for slot in range(Catalog.ACTIVE_SLOTS):
		ability_buttons[slot] = _button(root, "", _activate_slot.bind(slot))
		ability_buttons[slot].focus_mode = Control.FOCUS_NONE
		var badge := IconBadge.new()
		badge.icon_id = ""
		badge.position = Vector2(4, 4)
		badge.size = Vector2(26, 26)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ability_buttons[slot].add_child(badge)
		var cooldown := _meter(AMBER)
		cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ability_buttons[slot].add_child(cooldown)
		cooldown_meters[slot] = cooldown
		var ability_name := _label(ability_buttons[slot], "", 16, Color.WHITE)
		ability_name.name = "AbilityName"
		ability_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ability_status := _label(ability_buttons[slot], "", 16, CYAN)
		ability_status.name = "AbilityStatus"
		ability_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ability_a = ability_buttons[0]
	ability_b = ability_buttons[1]
	pause_button = _button(root, "Ⅱ", _toggle_pause)
	build_button = _button(root, "BUILD", _show_build)
	speed_button = _button(root, "1×", _cycle_speed)
	sound_button = _button(root, "Effects", _toggle_sound)
	music_button = _button(root, "Music", _toggle_music)
	low_fx_button = _button(root, "Glow", _toggle_fx)
	signal_button = _button(root, "♪  UNLISTED SIGNAL", _show_signal)
	signal_button.visible = false
	signal_label = _label(root, "", 15, HiddenSector.MINT)
	signal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	signal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	signal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	signal_label.visible = false
	_build_intro_hud()
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	toast_layer = Control.new()
	toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_layer)
	toast_panel = PanelContainer.new()
	toast_panel.name = "AchievementToast"
	toast_panel.visible = false
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_theme_stylebox_override("panel", Kit.box(Color("16242b"), Kit.AMBER, 14, 2, 14, 9))
	toast_layer.add_child(toast_panel)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 3)
	toast_panel.add_child(stack)
	toast_title = Kit.label(stack,"ACHIEVEMENT UNLOCKED",13,Kit.AMBER)
	toast_title.add_theme_font_override("font",Kit.font(1,0.35))
	toast_detail = Kit.label(stack,"",17,Kit.TEXT,true)

func _build_intro_hud() -> void:
	intro_panel = PanelContainer.new()
	intro_panel.name = "FirstFlightCaption"
	intro_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_panel.add_theme_stylebox_override("panel", Kit.box(Color("0d1d2b"), Color("385568"), 9, 1, 10, 5))
	intro_panel.hide()
	root.add_child(intro_panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	intro_panel.add_child(row)
	var text_stack := VBoxContainer.new()
	text_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	text_stack.add_theme_constant_override("separation", 0)
	row.add_child(text_stack)
	intro_heading = Kit.caps(text_stack, "", Kit.CYAN, 13)
	intro_caption = Kit.label(text_stack, "", 15, Kit.TEXT, true)
	intro_continue = _ui_button(row, "Keep flying", _continue_intro_aegis, "ghost", 44)
	intro_continue.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	intro_continue.hide()

	intro_marker = Panel.new()
	intro_marker.name = "AegisMarker"
	intro_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_marker.add_theme_stylebox_override("panel", Kit.box(Color.TRANSPARENT, Kit.AMBER, 10, 2, 0, 0))
	intro_marker.hide()
	root.add_child(intro_marker)

func _layout_intro_hud() -> void:
	var screen := get_viewport_rect().size
	var width := minf(440.0, screen.x - 32.0)
	intro_panel.position = Vector2((screen.x - width) * 0.5, shield_meter.position.y + 30.0)
	intro_panel.size = Vector2(width, 52.0)
	intro_marker.position = ability_a.position - Vector2(3, 3)
	intro_marker.size = ability_a.size + Vector2(6, 6)

func _update_intro_hud() -> void:
	var active: bool = flight_started and sim.intro_run and mode in ["playing", "intro_aegis"]
	var lesson := active and mode == "intro_aegis"
	intro_marker.visible = lesson
	intro_marker.modulate.a = 1.0 if profile.reduced else 0.87 + 0.13 * sin(visual_time * 5.0)
	intro_continue.visible = lesson
	ability_a.focus_mode = Control.FOCUS_ALL if lesson else Control.FOCUS_NONE
	var cue: Array = FirstFlight.cue(sim) if active else []
	if cue == intro_cue:
		return
	if intro_cue_tween and intro_cue_tween.is_valid():
		intro_cue_tween.kill()
	intro_cue = cue
	intro_panel.visible = not cue.is_empty()
	if cue.is_empty():
		return
	intro_heading.text = cue[0]
	intro_caption.text = cue[1]
	intro_heading.add_theme_color_override("font_color", Kit.AMBER if lesson else Kit.CYAN)
	intro_panel.modulate.a = 1.0
	if not profile.reduced and not lesson:
		intro_panel.modulate.a = 0.0
		intro_cue_tween = create_tween()
		intro_cue_tween.tween_property(intro_panel, "modulate:a", 1.0, 0.23)

func _layout() -> void:
	var size := get_viewport_rect().size
	old_size = size
	root.size = size
	overlay.size = size
	if is_instance_valid(toast_layer):
		toast_layer.size = size
		toast_panel.position = Vector2(16.0, float(_insets().top) + 56.0)
		toast_panel.size = Vector2(minf(410.0,size.x-32.0),0.0)
	var inset := _insets()
	var compact := _compact_ui()
	var safe_top: float = float(inset.top) + 7.0
	var field_top := safe_top + (160.0 if flight_started and sim.intro_run else 92.0)
	var reserved := 128.0 if compact else 196.0
	var usable_height := maxf(80.0, size.y - field_top - reserved - float(inset.bottom))
	scale_factor = minf((size.x - 24.0) / 540.0, usable_height / 960.0)
	field = Rect2(Vector2((size.x - 540.0 * scale_factor) * 0.5, field_top), Vector2(540, 960) * scale_factor)
	clip.position = field.position
	clip.size = field.size
	world.scale = Vector2.ONE * scale_factor
	var chrome_x := 16.0 if compact else field.position.x
	var chrome_width := size.x - 32.0 if compact else field.size.x
	# Reserve horizontal space for the toolbar before placing heading and timer.
	# Narrow headers abbreviate rather than painting over the Build control.
	var toolbar_start := size.x - 14.0 - 196.0 if compact else field.end.x - 174.0
	var top_label_width := maxf(70.0, minf(132.0 if compact else 200.0, toolbar_start - chrome_x - 10.0))
	hud.position = Vector2(chrome_x, safe_top + 4.0)
	hud.size = Vector2(top_label_width, 24)
	status.position = Vector2(chrome_x, safe_top + 28.0)
	status.size = Vector2(top_label_width, 20)
	var meter_y := safe_top + 58.0
	var meter_width := (chrome_width - 10.0) * 0.5
	hull_meter.position = Vector2(chrome_x, meter_y)
	shield_meter.position = Vector2(chrome_x + meter_width + 10.0, meter_y)
	for meter in [hull_meter, shield_meter]:
		meter.size = Vector2(meter_width, 24.0)
	hull_caption.position = hull_meter.position + Vector2(7, 1)
	shield_caption.position = shield_meter.position + Vector2(7, 1)
	hull_caption.size = Vector2(meter_width - 9.0, 22)
	shield_caption.size = Vector2(meter_width - 9.0, 22)
	var signal_width := minf(340.0, size.x - 30.0)
	signal_button.position = Vector2((size.x - signal_width) * 0.5, field.position.y + 97.0 * scale_factor)
	signal_button.size = Vector2(signal_width, 46.0)
	signal_label.position = signal_button.position
	signal_label.size = signal_button.size
	signal_label.add_theme_stylebox_override("normal", Kit.box(Color("101f24"), HiddenSector.COLOR, 10, 1, 10, 5))
	var controls_width := minf(size.x - 28.0, maxf(330.0, field.size.x))
	var controls_x := (size.x - controls_width) * 0.5
	var button_width := (controls_width - (15.0 if compact else 6.0)) / (4.0 if compact else 2.0)
	for i in range(Catalog.ACTIVE_SLOTS):
		var button: Button = ability_buttons[i]
		button.position = Vector2(controls_x + i * (button_width + 5.0), field.end.y + 9.0) if compact else Vector2(controls_x + (i % 2) * (button_width + 6.0), field.end.y + 9.0 + int(i / 2) * 84.0)
		button.size = Vector2(button_width, 102.0 if compact else 80.0)
		button.custom_minimum_size.y = button.size.y
		button.add_theme_font_size_override("font_size", 16 if compact else 15)
		var badge: Control = button.get_child(0)
		# IconBadge starts with a 32pt minimum. Explicitly size it so it
		# cannot expand back into the name row after the Control resolves.
		badge.custom_minimum_size = Vector2(28, 28) if compact else Vector2(32, 32)
		badge.size = badge.custom_minimum_size
		badge.position = Vector2((button_width - badge.size.x) * 0.5, 5.0) if compact else Vector2(8, 16)
		var name_label: Label = button.get_node("AbilityName")
		var status_label: Label = button.get_node("AbilityStatus")
		for label in [name_label, status_label]:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if compact else HORIZONTAL_ALIGNMENT_LEFT
		name_label.position = Vector2(3, 41) if compact else Vector2(44, 13)
		name_label.size = Vector2(button_width - 6.0, 24) if compact else Vector2(button_width - 50.0, 24)
		status_label.position = Vector2(3, 70) if compact else Vector2(44, 43)
		status_label.size = Vector2(button_width - 6.0, 24) if compact else Vector2(button_width - 50.0, 24)
		var cooldown_bar: ProgressBar = cooldown_meters[i]
		cooldown_bar.position = Vector2(7.0, button.size.y - 6.0)
		cooldown_bar.size = Vector2(button_width - 14.0, 3.0)
		# No selected/focused look on slot one; readiness lives in its status.
		button.add_theme_stylebox_override("normal", _style(Color("102335"), Color("34495e")))
		button.add_theme_stylebox_override("hover", _style(Color("183a46"), CYAN))
		button.add_theme_stylebox_override("pressed", _style(Color("20505b"), CYAN))
		button.add_theme_stylebox_override("disabled", _style(Color("0d1929"), Color("263749")))
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
			style.set_content_margin_all(2.0)
			button.add_theme_stylebox_override(state, style)
	var top_height := 44.0 if compact else 36.0
	var toolbar_right := size.x - 14.0 if compact else field.end.x
	var pause_width := 44.0 if compact else 42.0
	var speed_width := 58.0 if compact else 46.0
	var build_width := 78.0 if compact else 74.0
	pause_button.position = Vector2(toolbar_right - pause_width, safe_top)
	pause_button.size = Vector2(pause_width, top_height)
	speed_button.position = Vector2(pause_button.position.x - 6.0 - speed_width, safe_top)
	speed_button.size = Vector2(speed_width, top_height)
	build_button.position = Vector2(speed_button.position.x - 6.0 - build_width, safe_top)
	build_button.size = Vector2(build_width, top_height)
	for control in [build_button, speed_button, pause_button]:
		control.custom_minimum_size.y = top_height
		control.add_theme_font_size_override("font_size", _text_size(12))
		for state in ["normal", "hover", "pressed", "disabled"]:
			var toolbar_style: StyleBoxFlat = control.get_theme_stylebox(state).duplicate()
			toolbar_style.set_content_margin_all(4.0)
			control.add_theme_stylebox_override(state, toolbar_style)
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
	_layout_intro_hud()
	if mode in ["settings", "briefing"]:
		if mode == "settings":
			_show_settings()
		else:
			_show_briefing(briefing_launch)
	elif mode == "abandon":
		_confirm_abandon(sheet_base, pending_launch)
	elif mode == "menu":
		_show_menu()
	elif mode == "achievements":
		_show_achievements()
	elif mode == "codex":
		_show_codex()
	elif mode == "cards":
		_show_cards()
	elif mode == "build_choice":
		_show_build_choice()
	elif mode == "mutation_lab":
		_show_mutation_lab()
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
	elif mode == "archive_signal":
		_show_signal()
	elif mode == "archive_reveal":
		_show_archive_reveal(false)
	elif mode == "archive_intro":
		_show_archive_intro(false)
	elif mode == "archive_ending":
		_show_archive_ending(false)
	elif mode == "stage_clear":
		_show_stage_clear(false)
	elif mode == "prototype":
		_show_prototypes()
	elif mode == "merchant_signal":
		_show_merchant_signal()
	elif mode == "merchant_shop":
		_show_merchant_shop()
	elif mode == "merchant_confirm":
		_show_merchant_confirm()
	elif mode == "merchant_receipt":
		_show_merchant_receipt()
	elif mode == "route":
		_show_route_choice()
	elif mode == "beam_tutorial":
		_show_beam_tutorial()
	elif mode == "intro_results":
		_show_intro_results()
	elif mode == "boss_intro" and sim.intro_run:
		_show_boss_intro(false)

func _clear_overlay() -> void:
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	card_buttons.clear()
	stage_clear_button = null
	stage_clear_secondary = null

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
func _page(alpha: float = 1.0, scroll: bool = true, width: float = 520.0, phone_margin: float = 16.0) -> Dictionary:
	_clear_overlay()
	_backdrop(alpha)
	var screen := get_viewport_rect().size
	var inset := _insets()
	# Critical choice screens use 24pt phone gutters rather than the normal
	# 16pt; never let text or buttons graze a screen edge.
	var side_margin := phone_margin if _compact_ui() else 16.0
	var w := minf(width, maxf(1.0, screen.x - side_margin * 2.0))
	var frame := VBoxContainer.new()
	frame.position = Vector2((screen.x - w) * 0.5, float(inset.top) + 4.0)
	var reserved_ad_height := 64.0 if ad_banner_visible and mode in ["menu", "results"] else 0.0
	frame.size = Vector2(w, screen.y - float(inset.top) - float(inset.bottom) - 8.0 - reserved_ad_height)
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
		reading_scroll.scroll_deadzone = 8
		_enable_scroll_input.call_deferred(weakref(reading_scroll))
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

## Let native touch dragging bubble through cards, icons and purchase buttons.
## ScrollContainer cancels a held button when the gesture becomes a scroll.
func _enable_scroll_input(scroll_ref: WeakRef) -> void:
	var scroll: ScrollContainer = scroll_ref.get_ref()
	if is_instance_valid(scroll):
		for child in scroll.get_children():
			_pass_scroll_input(child)

func _pass_scroll_input(node: Node) -> void:
	if node is Control and node.mouse_filter == Control.MOUSE_FILTER_STOP:
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_pass_scroll_input(child)

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
		# One line, trimmed: a wrapping label with clip_text collapses to
		# zero height, which hid every page eyebrow.
		over.autowrap_mode = TextServer.AUTOWRAP_OFF
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
	if not bool(profile.get("reduced", false)):
		# Animate the sheet content, not its bottom-anchored panel: landscape
		# layouts must keep the container fully inside the safe rectangle.
		box.position.y = 12.0
		box.modulate.a = 0.0
		var entrance := create_tween().set_parallel(true)
		entrance.tween_property(box, "position:y", 0.0, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		entrance.tween_property(box, "modulate:a", 1.0, 0.15)
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
	get_tree().process_frame.connect(_apply_scroll.bind(weakref(scroll), value), CONNECT_ONE_SHOT)

func _apply_scroll(scroll_ref: WeakRef, value: int) -> void:
	var scroll: ScrollContainer = scroll_ref.get_ref()
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
		"hard": return "Enemies are 25% tougher and shoot more. Boss clears pay ×1.75; early recovery is earned by kills."
		"insane": return "Enemies are twice as tough and shoot even more. Boss clears pay ×2.5; early recovery is earned by kills."
	return "The normal challenge. Cores ×1."

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
	flight_started = false
	confirm_key = ""
	var view := _page(1.0, true, 460.0)
	var top: VBoxContainer = view.top
	var body: VBoxContainer = view.body
	var bottom: VBoxContainer = view.bottom
	# Keep the title, wallet, and settings on one line.
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	top.add_child(bar)
	var wordmark := RichTextLabel.new()
	wordmark.name = "StarRunWordmark"
	wordmark.bbcode_enabled = true
	wordmark.text = "[color=#eef7ff]Star[/color][color=#ffc078]/[/color][color=#66f5df]Run[/color]"
	wordmark.fit_content = true
	wordmark.scroll_active = false
	wordmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wordmark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wordmark.custom_minimum_size.y = 48
	wordmark.add_theme_font_override("normal_font", Kit.font(-1, 0.8))
	wordmark.add_theme_font_size_override("normal_font_size", 36 if _compact_ui() else 43)
	bar.add_child(wordmark)
	var wallet: Control = _wallet()
	wallet.name = "TitleWallet"
	bar.add_child(wallet)
	var settings_button := _icon_button(bar, "settings", _show_settings, "Settings")
	settings_button.name = "TitleSettings"

	# The ship and pilot now have separate layout rows. Nothing sits on top
	# of the ship illustration, including on a narrow phone.
	var hero_frame := PanelContainer.new()
	hero_frame.name = "LoadoutPanel"
	hero_frame.add_theme_stylebox_override("panel", Kit.box(Color("060c17"), Kit.LINE, 12, 1, 0, 0))
	hero_frame.clip_contents = true
	body.add_child(hero_frame)
	var preview_stack := VBoxContainer.new()
	preview_stack.add_theme_constant_override("separation", 0)
	hero_frame.add_child(preview_stack)
	var ship_slot := Control.new()
	ship_slot.name = "ShipArtSlot"
	ship_slot.custom_minimum_size = Vector2(0, 110)
	ship_slot.clip_contents = true
	ship_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_stack.add_child(ship_slot)
	var hero := HangarBay.new()
	hero.name = "SelectedShipArt"
	hero.style = "flight"
	hero.labels = false
	hero.ship_id = profile.ship
	ship_slot.add_child(hero)
	hero.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var loadout_strip := PanelContainer.new()
	loadout_strip.name = "SelectedLoadoutStrip"
	loadout_strip.add_theme_stylebox_override("panel", Kit.box(Kit.SURFACE, Kit.LINE, 0, 0, 12, 6))
	preview_stack.add_child(loadout_strip)
	var loadout_row := HBoxContainer.new()
	loadout_row.add_theme_constant_override("separation", 10)
	loadout_strip.add_child(loadout_row)
	var portrait := PilotPortrait.new()
	portrait.name = "SelectedPilotPortrait"
	portrait.pilot_id = profile.pilot
	portrait.custom_minimum_size = Vector2(38, 38)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	loadout_row.add_child(portrait)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	loadout_row.add_child(names)
	var ship: Dictionary = Catalog.ship(profile.ship)
	var pilot: Dictionary = Catalog.pilot(profile.pilot)
	Kit.label(names, _name_part(ship.name, 0), 19, Kit.TEXT)
	Kit.label(names, "Pilot · " + _name_part(pilot.name, 0), 14, Kit.MUTED)
	var change_button := _ui_button(loadout_row, "Change", _open_loadout.bind("menu"), "ghost", 44)
	change_button.name = "ChangeLoadout"
	change_button.tooltip_text = "Choose ship, pilot or rules"
	change_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# The Daily is the same UTC challenge and starting ship for every player.
	var daily: Dictionary = Progress.daily_setup(Progress.utc_day())
	var record: Dictionary = profile.daily_records.get(daily.day, {})
	var daily_panel := PanelContainer.new()
	daily_panel.name = "DailyPanel"
	daily_panel.add_theme_stylebox_override("panel", Kit.box(Kit.SURFACE, Kit.LINE, 12, 1, 12, 8))
	body.add_child(daily_panel)
	var daily_content := VBoxContainer.new()
	daily_content.add_theme_constant_override("separation", 4)
	daily_panel.add_child(daily_content)
	Kit.label(daily_content, "Daily · %s UTC" % str(daily.day), 18, Kit.TEXT)
	var daily_ship: Dictionary = Catalog.ship(str(daily.ship))
	var daily_pilot: Dictionary = Catalog.pilot(str(daily.pilot))
	Kit.label(daily_content, "%s · %s · Normal · %s Hangar" % [_name_part(str(daily_ship.name), 0), _name_part(str(daily_pilot.name), 0), str(Progress.daily_hangar_grade(str(daily.day)).name)], 14, Kit.MUTED, true)
	var daily_text := "Play daily"
	var best_today: int = int(record.get("best_score", -1))
	if best_today >= 0:
		daily_text = "Replay · Best %s" % _num(best_today)
	var daily_actions := HBoxContainer.new()
	daily_actions.add_theme_constant_override("separation", 6)
	daily_content.add_child(daily_actions)
	_ui_button(daily_actions, daily_text, _launch_daily, "secondary", 44, true)
	if game_center.supports_game_center():
		var leaderboard := _ui_button(daily_actions, "Leaderboard", _show_game_center_leaderboard, "ghost", 44, true)
		leaderboard.tooltip_text = "Game Center daily leaderboard"
	Kit.label(body, "Difficulty", 14, Kit.MUTED)
	var segments := HBoxContainer.new()
	segments.add_theme_constant_override("separation", 6)
	body.add_child(segments)
	var current := str(profile.get("difficulty", "normal"))
	for id in Catalog.DIFFICULTIES:
		var chosen: bool = id == current
		var segment := Button.new()
		segment.text = str(id).capitalize()
		Kit.style_button(segment, ("danger" if id == "insane" else "selected") if chosen else "secondary", 16, 10, 6.0)
		if not chosen:
			for state in ["font_color", "font_hover_color", "font_focus_color"]:
				segment.add_theme_color_override(state, Kit.MUTED)
		segment.custom_minimum_size.y = 48
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.tooltip_text = _difficulty_text(str(id))
		segment.pressed.connect(_set_difficulty.bind(str(id)))
		segments.add_child(segment)
	_start_world_picker(body, current)
	# A short navigation rail stays above the thumb-reachable primary action.
	var saved := _saved_flight()
	# Two short rows: five labels in one row were cut off ("Hanga...") on phones.
	var row := HBoxContainer.new()
	row.name = "MenuNavTop"
	row.add_theme_constant_override("separation", 6)
	bottom.add_child(row)
	_ui_button(row, "Hangar", _show_hangar, "ghost", 42, true)
	_ui_button(row, "Codex", _show_codex, "ghost", 42, true).tooltip_text = "Every upgrade, fusion and team-up you have found"
	var awards_button := _ui_button(row, "Awards", _show_achievements, "ghost", 42, true)
	awards_button.tooltip_text = "Achievements and milestones"
	var row2 := HBoxContainer.new()
	row2.name = "MenuNavBottom"
	row2.add_theme_constant_override("separation", 6)
	bottom.add_child(row2)
	_ui_button(row2, "Rivals", _show_rival_journal, "ghost", 42, true)
	_ui_button(row2, "Guide", _show_briefing.bind(false), "ghost", 42, true)
	var primary: Button
	if saved.is_empty():
		if profile.intro_status == "available":
			_ui_button(bottom, "Skip to campaign", _new_run, "ghost", 44)
			primary = _ui_button(reading_footer, "Start first flight", _launch, "primary", 60, true)
		else:
			primary = _ui_button(reading_footer, "Launch", _launch, "primary", 60, true)
	elif bool(saved.get("intro_run", false)):
		_ui_button(bottom, "Skip to campaign" if not bool(saved.ended) else "Launch campaign", _new_run, "ghost", 44)
		primary = _ui_button(reading_footer, "First flight debrief" if bool(saved.ended) else "Resume first flight", _resume_run, "primary", 60, true)
	else:
		_ui_button(bottom, "Start new run", _confirm_abandon.bind("menu"), "ghost", 44)
		var resume_title := "Resume daily  ·  World %d" % int(saved.get("stage",1)) if not str(saved.get("daily_day","")).is_empty() else "Resume  ·  World %d" % int(saved.get("stage",1))
		primary = _ui_button(reading_footer, resume_title, _resume_run, "primary", 60, true)
	_focus(primary)



func _queue_toast(title: String, detail: String) -> void:
	toast_queue.append({"title":title,"detail":detail})
	if toast_clock <= 0.0:
		_next_toast()

func _next_toast() -> void:
	if toast_queue.is_empty():
		toast_clock = 0.0
		toast_panel.visible = false
		return
	var item: Dictionary = toast_queue.pop_front()
	toast_title.text = str(item.title).to_upper()
	toast_detail.text = str(item.detail)
	toast_panel.visible = true
	toast_clock = 3.6

func _advance_toast(delta: float) -> void:
	if toast_clock > 0.0:
		toast_clock -= delta
		if toast_clock <= 0.0:
			_next_toast()

func _show_game_center_leaderboard() -> void:
	if not game_center.show_leaderboard():
		_queue_toast("Game Center", "Sign in to Game Center on your iPhone to compare scores.")

func _show_native_achievements() -> void:
	if not game_center.show_achievements():
		_queue_toast("Game Center", "Sign in to Game Center on your iPhone to view Apple achievements.")

func _share_daily_result() -> void:
	var text_value: String = Progress.daily_share_text(sim)
	if text_value.is_empty():
		return
	# One tap opens the native iOS share sheet. Never claim sharing succeeded
	# before the player chooses a destination; canceling requires no toast.
	if daily_share_service != null and daily_share_service.has_method("share"):
		pending_share_text = text_value
		var result: Variant = daily_share_service.call("share", {
			"title": "Star/Run Daily Challenge",
			"subject": "Star/Run Daily %s UTC" % str(sim.daily_day),
			"content": text_value,
			"mime_type": "text/plain"
		})
		if result == OK:
			return
		pending_share_text = ""
	# The web/desktop fallback also handles a missing or failed iOS plug-in.
	_copy_daily_share_text(text_value)

func _copy_daily_share_text(text_value: String) -> void:
	DisplayServer.clipboard_set(text_value)
	# Acknowledge copying ahead of any queued achievement celebrations.
	toast_queue.push_front({"title": "Ready to share", "detail": "Daily scorecard copied. Paste it into any message or post."})
	toast_clock = 0.0
	_next_toast()

func _on_native_share_completed(_activity_type: String) -> void:
	pending_share_text = ""

func _on_native_share_canceled() -> void:
	pending_share_text = ""

func _on_native_share_failed(_error_message: String) -> void:
	if pending_share_text.is_empty():
		return
	var text_value: String = pending_share_text
	pending_share_text = ""
	_copy_daily_share_text(text_value)

func _show_achievements() -> void:
	mode = "achievements"
	Progress.prepare(profile)
	var view := _page(1.0, true, 540.0)
	_page_header(view.top, "PILOT RECORD", "Achievements", _show_menu)
	var unlocked: Dictionary = profile.achievements
	Kit.label(view.top, "%d of %d earned" % [unlocked.size(),Progress.ACHIEVEMENTS.size()], 15, Kit.MUTED, true)
	if game_center.supports_game_center():
		_ui_button(view.body, "View Apple Game Center achievements", _show_native_achievements, "secondary", 48)
	for item in Progress.ACHIEVEMENTS:
		var id: String = str(item.id)
		var is_unlocked: bool = unlocked.has(id)
		if bool(item.get("local_only", false)) and not is_unlocked:
			_info_card(view.body, "Secret achievement", "Keep playing to find it.", Kit.MUTED)
			continue
		var done: int = mini(int(item.target), Progress.progress(profile, id))
		var status_text := ("Earned %s" % _pretty_day(str(unlocked.get(id, "")))) if is_unlocked else ("%d / %d" % [done, int(item.target)])
		_info_card(view.body, str(item.name), "%s\n%s" % [str(item.description), status_text], Kit.AMBER if is_unlocked else Kit.MUTED)
	_focus(_ui_button(view.footer, "Back to Star/Run", _show_menu, "primary", 54, true))

## Discovery codex. Entries stay hidden until a flight shows them.
func _show_codex() -> void:
	var prior: int = reading_scroll.scroll_vertical if mode == "codex" and is_instance_valid(reading_scroll) else 0
	mode = "codex"
	Progress.prepare(profile)
	var view := _page(1.0, true, 540.0)
	_page_header(view.top, "FOUND IN FLIGHT", "Codex", _show_menu)
	Kit.label(view.top, "%d of %d found" % [Codex.found_count(profile), Codex.total()], 15, Kit.MUTED, true)
	_tabs(view.top, Codex.TABS, codex_tab, _codex_tab)
	var found: Dictionary = profile.codex
	var entries: Array = Codex.entries(codex_tab)
	Kit.label(view.body, "%d of %d %s" % [Codex.found_count(profile, codex_tab), entries.size(), codex_tab.to_lower()], 15, Kit.MUTED, true)
	for entry in entries:
		if found.has(str(entry.key)):
			_info_card(view.body, "%s  ·  %s" % [str(entry.name), str(entry.tag)], str(entry.detail), Kit.CYAN)
		else:
			_info_card(view.body, "???", str(entry.hint), Kit.MUTED)
	_keep_scroll(reading_scroll, prior)
	_focus(_ui_button(view.footer, "Back to Star/Run", _show_menu, "primary", 54, true))

func _codex_tab(value: String) -> void:
	if value not in Codex.TABS:
		return
	codex_tab = value
	if is_instance_valid(reading_scroll):
		reading_scroll.scroll_vertical = 0
	_show_codex()

## "2026-11-22" -> "Nov 22, 2026". Anything else is shown as stored.
func _pretty_day(day: String) -> String:
	var parts := day.split("-")
	if parts.size() != 3 or not parts[1].is_valid_int():
		return day
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s %d, %s" % [months[clampi(int(parts[1]) - 1, 0, 11)], int(parts[2]), parts[0]]

func _rival_identity(parent: Node, record: Dictionary, note: String) -> void:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", Kit.box(Color("18151f"), Kit.DANGER, 14, 2, 12, 12))
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(frame)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	frame.add_child(content)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	content.add_child(row)
	var portrait := RivalPortrait.new()
	portrait.name = "RivalCutscenePortrait"
	portrait.rival = record.duplicate(true)
	portrait.custom_minimum_size = Vector2(120, 142)
	row.add_child(portrait)
	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 6)
	row.add_child(text_column)
	Kit.caps(text_column, "!  RIVAL", Kit.DANGER, 14)
	Kit.label(text_column, str(record.get("name","Unknown captain")), 21, Kit.TEXT, true)
	Kit.label(text_column, RivalCaptains.trait_name(str(record.get("trait",""))), 17, Kit.AMBER, true)
	Kit.label(content, note, 16, Kit.MUTED, true)
	Kit.label(content, RivalCaptains.flavor(record), 16, Kit.TEXT, true)

func _show_rival_journal() -> void:
	RivalCaptains.prepare(profile)
	mode = "rival_journal"
	var view := _page(1.0, true, 520.0)
	_page_header(view.top, "RIVALS", "Rival captains", _show_menu)
	Kit.label(view.top, "Captains who killed you. Beat them for a trophy.", 15, Kit.MUTED, true)
	var active: Dictionary = profile.rival_active
	if active.is_empty():
		_info_card(view.body, "No rival right now", "A captain who kills you may come back in a later run.", Kit.MUTED)
	else:
		_section(view.body, "Hunting you", Kit.DANGER)
		_rival_identity(view.body, active, "Killed you: %d  ·  Seen: %d  ·  Got away: %d" % [int(active.get("defeat_count",1)), int(active.get("times_encountered",0)), int(active.get("times_escaped",0))])
	var history: Array = profile.rival_archive
	_section(view.body, "Beaten (%d)" % history.size(), Kit.AMBER)
	if history.is_empty():
		Kit.label(view.body, "None yet.", 16, Kit.MUTED, true)
	for i in range(history.size()-1, -1, -1):
		var retired: Dictionary = history[i]
		_rival_identity(view.body, retired, "Killed you: %d  ·  Seen: %d" % [int(retired.get("defeat_count",1)),int(retired.get("times_encountered",0))])
	_focus(_ui_button(reading_footer, "Back to Star/Run", _show_menu, "primary", 54, true))

func _rival_stinger(title: String, note: String, reward: bool = false) -> void:
	mode = "rival_retired" if reward else "rival_intro"
	rival_stinger_clock = 0.0
	var view := _page(0.97, true, 490.0)
	_page_header(view.top, "", title)
	Kit.label(view.top, "They killed you before." if not reward else "You got them.", 16, Kit.AMBER, true)
	_rival_identity(view.body, sim.rival_record, note)
	var action := _ui_button(reading_footer, "Continue", _dismiss_rival_stinger, "primary", 60, true)
	_focus(action)
	sound.play("warning" if not reward else "victory")
	_haptic(120)
	_save_run()

func _show_rival_intro() -> void:
	if not sim.rival_intro_pending or sim.rival_record.is_empty():
		return
	if RivalCaptains.note_encounter(profile, sim):
		_save_profile()
	_rival_stinger("RIVAL SIGHTED!", "Kill them for a trophy, or survive until they leave.")

func _show_rival_retired() -> void:
	if not sim.rival_retire_pending or sim.rival_record.is_empty():
		return
	if RivalCaptains.retire(profile, sim):
		_save_profile()
	_rival_stinger("RIVAL DEFEATED!", "Trophy added to Rivals.", true)

## A short title card when a world's boss arrives: the sim pauses, warning
## stripes slide in and the boss name drops in. Tap to skip.
func _show_boss_intro(announce: bool = true) -> void:
	boss_intro_stage = sim.stage
	mode = "boss_intro"
	if announce:
		boss_intro_clock = 0.0
	_clear_overlay()
	var screen := get_viewport_rect().size
	var shade := ColorRect.new()
	shade.name = "BossIntro"
	shade.color = Color(0.01, 0.0, 0.02, 0.0)
	shade.size = screen
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(_on_shade_input.bind(_skip_boss_intro))
	overlay.add_child(shade)
	var center_y := screen.y * 0.40
	var stripes: Array = []
	for i in range(2):
		var band := Label.new()
		band.text = "WARNING   ·   ".repeat(12)
		band.add_theme_font_override("font", Kit.font(2, 0.25))
		band.add_theme_font_size_override("font_size", 15)
		band.add_theme_color_override("font_color", Color("1a0a06"))
		var plate := StyleBoxFlat.new()
		plate.bg_color = Kit.DANGER
		band.add_theme_stylebox_override("normal", plate)
		band.clip_text = true
		band.size = Vector2(screen.x, 28)
		band.position = Vector2(0.0, center_y + (-104.0 if i == 0 else 96.0))
		# Grows in from opposite edges; it never extends past the screen.
		band.pivot_offset = Vector2(0.0 if i == 0 else screen.x, 14.0)
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(band)
		stripes.append(band)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	stack.position = Vector2(16, center_y - 58.0)
	stack.size = Vector2(screen.x - 32, 0)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(stack)
	var boss_heading := "Debris Belt" if sim.intro_run else ("Endless world %d boss" % sim.stage if sim.endless_enabled else "World %d boss" % sim.stage)
	var eyebrow := Kit.caps(stack, boss_heading, Kit.DANGER, 15)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var name_label := Kit.label(stack, sim.boss_name(), 42, Color.WHITE)
	name_label.add_theme_font_override("font", Kit.font(0, 0.8))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tagline := Kit.label(stack, "Watch for the beam." if sim.intro_run else str(BOSS_TAGLINES.get(sim.boss_name(), "Big, angry and in your way.")), 16, Color("ffd9b0"), true)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if profile.reduced or not announce:
		shade.color.a = 0.62
	else:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(shade, "color:a", 0.62, 0.25)
		for band in stripes:
			band.scale.x = 0.0
			tween.tween_property(band, "scale:x", 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		stack.modulate.a = 0.0
		stack.position.y -= 40.0
		tween.tween_property(stack, "modulate:a", 1.0, 0.35).set_delay(0.25)
		tween.tween_property(stack, "position:y", center_y - 58.0, 0.45).set_delay(0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if announce:
		sound.play("warning")
		_haptic(160)
		if sim.intro_run:
			sim.intro_boss_intro_pending = true
			_save_run()

func _skip_boss_intro() -> void:
	if mode == "boss_intro" and boss_intro_clock >= 0.4:
		_dismiss_boss_intro()

func _dismiss_boss_intro() -> void:
	if mode != "boss_intro":
		return
	mode = "playing"
	boss_intro_clock = 0.0
	if sim.intro_run:
		sim.intro_boss_intro_pending = false
		_save_run()
	_clear_overlay()
	accumulator = 0.0
	_surface_pending_flight_choice()

func _dismiss_rival_stinger() -> void:
	if mode not in ["rival_intro", "rival_retired"]:
		return
	sim.rival_intro_pending = false
	sim.rival_retire_pending = false
	mode = "playing"
	_clear_overlay()
	rival_stinger_clock = 0.0
	accumulator = 0.0
	_save_run()
	_surface_pending_flight_choice()

func _set_artifact(id: String) -> void:
	if str(Catalog.artifact(id).id) != id:
		return
	profile.artifact = id
	_save_profile()
	sound.play("card")
	# Selecting an Artifact now happens in the loadout area, not on the title.
	# Stay on the tab so all rule descriptions remain readable.
	loadout_tab = "Artifacts"
	_show_loadout()

## After a world is cleared on a difficulty, the next flight there may
## start one world later. Hidden until World 1 has been cleared.
func _start_world_picker(body: VBoxContainer, difficulty_id: String) -> void:
	var unlocked: int = Progress.max_start_world(profile, difficulty_id)
	if unlocked < 2:
		return
	var chosen_world: int = _chosen_start_world()
	Kit.label(body, "Start at", 14, Kit.MUTED)
	var worlds := HBoxContainer.new()
	worlds.name = "StartWorldPicker"
	worlds.add_theme_constant_override("separation", 6)
	body.add_child(worlds)
	for world in range(1, 5):
		var option := Button.new()
		option.name = "StartWorld%d" % world
		option.text = "World %d" % world if not _compact_ui() else "W%d" % world
		var open: bool = world <= unlocked
		Kit.style_button(option, "selected" if world == chosen_world else "secondary", 16, 10, 6.0)
		if world != chosen_world:
			for state in ["font_color", "font_hover_color", "font_focus_color", "font_disabled_color"]:
				option.add_theme_color_override(state, Kit.MUTED if open else Kit.LINE)
		option.disabled = not open
		option.custom_minimum_size.y = 44
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.tooltip_text = ("Start at World %d" % world) if open else ("Beat World %d to unlock" % (world - 1))
		option.pressed.connect(_set_start_world.bind(world))
		worlds.add_child(option)
	if chosen_world > 1:
		Kit.label(body, "You still get the upgrades from the worlds you skip. Skipped worlds give no Cores.", 14, Kit.MUTED, true)

func _chosen_start_world() -> int:
	return clampi(int(profile.get("start_world", 1)), 1, Progress.max_start_world(profile, str(profile.get("difficulty", "normal"))))

func _set_start_world(world: int) -> void:
	if world != int(profile.get("start_world", 1)):
		profile.start_world = world
		_save_profile()
		sound.play("card")
	_show_menu()

func _set_difficulty(id: String) -> void:
	if id in Catalog.DIFFICULTIES and id != str(profile.get("difficulty", "normal")):
		profile.difficulty = id
		_save_profile()
		sound.play("card")
	_show_menu()

func _launch() -> void:
	if profile.intro_status == "available" and _saved_flight().is_empty():
		_new_intro_run()
	else:
		_new_run()

func _saved_flight() -> Dictionary:
	var saved := services.read_save(Services.RUN)
	if not bool(saved.get("intro_run", false)) or not bool(saved.get("intro_reward_eligible", false)):
		return saved
	# A profile write can commit before the replacement campaign checkpoint.
	var state := str(profile.intro_status)
	if state == "skipped" or (state == "complete" and not bool(saved.get("ended", false))):
		return {}
	return saved

func _launch_daily() -> void:
	if _saved_flight().is_empty():
		_new_daily_run()
	else:
		_confirm_abandon("menu", "daily")

func _launch_or_confirm(base: String) -> void:
	if _saved_flight().is_empty():
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
	_toggle_row(box, "Music", "Music during runs.", bool(profile.music), _toggle_music)
	_toggle_row(box, "Calmer visuals", "Less glow, fewer effects and no screen shake.", bool(profile.reduced), _toggle_fx)
	if _desktop_window():
		_toggle_row(box, "Fullscreen", "Also F11 or Alt+Enter.", bool(profile.get("fullscreen", false)), _toggle_fullscreen)
	if (OS.get_name() == "iOS" and _ad_monetization_enabled()) or OS.get_environment("STARRUN_IAP_REVIEW_CAPTURE") == "1":
		var has_ads_removed := bool(profile.get("remove_ads", false))
		Kit.label(box, "AD-FREE", 16, Kit.CYAN)
		if has_ads_removed:
			Kit.label(box, "Banner ads removed for this Apple Account.", 16, Kit.MUTED, true)
		else:
			var price := str(remove_ads_store.localized_price) if is_instance_valid(remove_ads_store) else ""
			var buy_label := "Remove ads" + (" - " + price if not price.is_empty() else "")
			var purchase_button := _ui_button(box, buy_label, _buy_remove_ads, "secondary", 48)
			purchase_button.disabled = not is_instance_valid(remove_ads_store) or not bool(remove_ads_store.store_ready) or not bool(remove_ads_store.product_available) or bool(remove_ads_store.busy)
		var restore_button := _ui_button(box, "Restore purchases", _restore_remove_ads, "ghost", 44)
		restore_button.disabled = not is_instance_valid(remove_ads_store) or not bool(remove_ads_store.store_ready) or bool(remove_ads_store.busy)
		if is_instance_valid(remove_ads_store):
			Kit.label(box, str(remove_ads_store.message), 14, Kit.MUTED, true)
	if is_instance_valid(native_ad_banner) and bool(native_ad_banner.call("privacy_options_required")):
		_ui_button(box, "Ad privacy choices", _show_ad_privacy_options, "secondary", 44)
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
	var box := _sheet("How a run works", "How to play", _close_sheet, false)
	var steps := [
		["Autopilot", "Your ship steers and shoots by itself. You never aim."],
		["Abilities", "Tap the four buttons at the bottom to use abilities. Each one recharges after use."],
		["Level up", "Pick an upgrade each time you level up. Two matching abilities at rank 5 can fuse into one."],
		["Four bosses", "Beat four worlds. Spend the Cores you earn on permanent upgrades in the Hangar."],
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
	var saved := _saved_flight()
	if profile.intro_status != "available" and (saved.is_empty() or (bool(saved.get("intro_run", false)) and bool(saved.get("ended", false)))):
		_ui_button(box, "Replay first flight", _new_intro_run.bind(true), "secondary", 48)
	_focus(_ui_button(box, "Launch" if briefing_launch else "Got it", _briefing_done, "primary", 56))

func _briefing_done() -> void:
	profile.briefed = true
	_save_profile()
	if briefing_launch:
		briefing_launch = false
		_launch()
	else:
		_show_menu()

func _confirm_abandon(base: String, desired: String = "normal") -> void:
	pending_launch = "daily" if desired == "daily" else "normal"
	sheet_base = base
	_render_base(base)
	mode = "abandon"
	var saved := services.read_save(Services.RUN)
	var box := _sheet("Delete your saved run?", "New run", _close_sheet, false)
	var saved_location := "first flight" if bool(saved.get("intro_run", false)) else "World %d" % int(saved.get("stage", 1))
	Kit.label(box, "You have a run saved in %s. Starting over deletes it and earns no Cores." % saved_location, 16, Kit.MUTED, true)
	_focus(_ui_button(box, "Resume saved run", _resume_run, "primary", 54))
	_ui_button(box, "Abandon and start daily" if pending_launch == "daily" else "Abandon and launch", _new_daily_run if pending_launch == "daily" else _launch, "danger", 48)
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
	hangar_scroll.scroll_deadzone = 8
	_enable_scroll_input.call_deferred(weakref(hangar_scroll))
	body.add_child(hangar_scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hangar_scroll.add_child(list)
	for entry in Catalog.HANGAR:
		if entry.group == hangar_category:
			_hangar_row(list, entry)
	var refund_total := Catalog.refund(profile.hangar, profile.get("hangar_paid", {}))
	if refund_total > 0:
		var armed := confirm_key == "refund"
		var refund := _ui_button(list, ("Tap again to refund %d cores" if armed else "Refund all upgrades  ·  %d cores") % refund_total, _refund_tap, "danger" if armed else "ghost", 44)
		refund.tooltip_text = "Removes all upgrades and gives back every Core."
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
	var bar := RankBar.new()
	bar.name = "RankBar"
	progress.add_child(bar)
	var extended_from := int(entry.get("tier_from", 0))
	bar.setup(bought, top_rank, extended_from, not maxed and int(profile.cores) >= price)
	var in_extended := extended_from > 0 and bought >= extended_from
	Kit.label(progress, "%d/%d" % [bought, top_rank], 14, Color("ffb347") if in_extended else Kit.DIM)
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
	var view := _page(1.0, true, 560.0, 24.0)
	_page_header(view.top, "Next run", "Loadout", _loadout_back, true)
	_tabs(view.top, ["Ships", "Pilots", "Artifacts"], loadout_tab, _loadout_tab)
	var body: VBoxContainer = view.body
	if loadout_tab == "Artifacts":
		Kit.label(body, "Optional rules for normal runs. The Daily always uses Standard.", 16, Kit.MUTED, true)
		for entry in Catalog.ARTIFACTS:
			_artifact_card(body, entry)
	else:
		var ships := loadout_tab == "Ships"
		var entries: Array = Catalog.SHIPS if ships else Catalog.PILOTS
		for entry in entries:
			_loadout_card(body, entry, ships)
	_keep_scroll(reading_scroll, prior)
	_focus(_ui_button(reading_footer, "Done", _loadout_back, "primary", 54, true))

func _artifact_card(parent: Node, entry: Dictionary) -> void:
	var id: String = str(entry.id)
	var selected: bool = str(profile.get("artifact", "standard")) == id
	var card := _tap_card(parent, _set_artifact.bind(id), Kit.AMBER, selected)
	card.panel.name = "ArtifactOption" + id.to_pascal_case()
	# Name and explanation occupy their own full-width rows. Never squeeze the
	# complete word "Standard" (or long names) into four equal-width buttons.
	Kit.caps(card.content, "SELECTED" if selected else "TAP TO SELECT", Kit.CYAN if selected else Kit.MUTED, 12)
	var title := Kit.label(card.content, str(entry.name), 19, Color.WHITE, true)
	title.name = "ArtifactTitle" + id.to_pascal_case()
	title.custom_minimum_size.x = 0
	title.add_theme_font_override("font", Kit.font(0, 0.45))
	Kit.label(card.content, str(entry.description), 16, Kit.TEXT, true)

func _loadout_card(parent: Node, entry: Dictionary, ships: bool) -> void:
	var key := "ship" if ships else "pilot"
	var owned_key := "ships_owned" if ships else "pilots_owned"
	var id: String = str(entry.id)
	var owned: bool = id in profile[owned_key]
	var equipped: bool = profile[key] == id
	var cost: int = int(entry.cost)
	var buyable: bool = bool(entry.get("buy_only", false))
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
		var portrait := PilotPortrait.new()
		portrait.pilot_id = id
		portrait.custom_minimum_size = Vector2(64, 64)
		portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(portrait)
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
	elif not buyable:
		_chip(head, "Locked", Kit.DIM)
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
	if not owned and not buyable and Progress.UNLOCKS.has(id):
		var rule: Dictionary = Progress.UNLOCKS[id]
		var done: int = mini(int(rule.target), Progress.unlock_progress(profile, id))
		Kit.label(info, "Unlock: %s" % str(rule.text), 15, Kit.AMBER, true)
		var meter_row := HBoxContainer.new()
		meter_row.add_theme_constant_override("separation", 8)
		meter_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(meter_row)
		var meter := Kit.meter(meter_row, float(done) / maxf(1.0, float(rule.target)), Kit.AMBER, 5)
		meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		Kit.label(meter_row, "%s / %s" % [_num(done), _num(int(rule.target))], 14, Kit.MUTED)
	elif not owned and int(profile.cores) < cost:
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
	var buyable := false
	for candidate in entries:
		if candidate.id == id:
			cost = int(candidate.cost)
			buyable = bool(candidate.get("buy_only", false))
	# Ships and pilots with an unlock condition are earned in play, not bought.
	if not buyable or int(profile.cores) < cost:
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

# A meaningful one-time choice at rank 5 or when two invested abilities
# can fuse. The regular combat loop is paused by the UI mode, not a timer.
func _show_build_choice() -> void:
	if sim.pending_build_choices.is_empty():
		return
	mode = "build_choice"
	_save_run()
	var choice: Dictionary = sim.pending_build_choices[0]
	var id: String = str(choice.id)
	# Decision cards should not meet the screen bezel on narrow phones.
	var view := _page(0.93, true, 520.0, 24.0)
	var body: VBoxContainer = view.body
	var first_option: Button = null
	if str(choice.kind) == "swap":
		_page_header(view.top, "FUSION PARTNER", "Replace an ability?")
		Kit.label(body, "Learn " + str(sim.content.abilities[id].name) + " at rank 1 by replacing one ability. The replaced ability loses its ranks; the new partner still has to reach rank 5 to fuse.", 16, Kit.MUTED, true)
		for target in sim.fusion_swap_targets(id):
			var key: String = str(target)
			var option := _tap_card(body, _choose_build_decision.bind(key), Kit.AMBER)
			option.panel.name = "SwapAbility" + key.to_pascal_case()
			Kit.label(option.content, "Replace " + str(sim.content.abilities[key].name), 19, Color.WHITE, true)
			Kit.label(option.content, "Lose rank %d of this ability. Learn %s." % [int(sim.upgrades[key]), str(sim.content.abilities[id].name)], 16, Kit.TEXT, true)
			if first_option == null:
				first_option = option.button
		var back := _ui_button(view.bottom, "Keep abilities · back to draft", _choose_build_decision.bind("back"), "secondary", 54, true)
		if first_option == null:
			first_option = back
	elif str(choice.kind) == "evolution":
		var weapon_card: Dictionary = sim.content.cards.filter(func(c): return str(c.id) == id)[0]
		_page_header(view.top, "RANK 5 · " + id.to_upper(), "Choose your evolution")
		Kit.label(body, str(weapon_card.name) + " keeps its ranks. Pick one bonus for the rest of this run.", 16, Kit.MUTED, true)
		for option in sim.content.weapon_evolutions[id]:
			var card := _tap_card(body, _choose_build_decision.bind(str(option.id)), Kit.AMBER)
			card.panel.name = "EvolutionChoice" + str(option.id).to_pascal_case()
			Kit.caps(card.content, str(option.get("role", "")), Kit.AMBER, 12)
			var title := Kit.label(card.content, str(option.name), 20, Color.WHITE, true)
			title.add_theme_font_override("font", Kit.font(0, 0.45))
			Kit.label(card.content, str(option.description), 16, Kit.TEXT, true)
			Kit.caps(card.content, "TAP TO INSTALL", Kit.CYAN, 12)
			if first_option == null:
				first_option = card.button
	else:
		var spec: Dictionary = sim.fusion_spec(id)
		_page_header(view.top, "ABILITY PAIR READY", "Fuse or keep both?")
		var fusion := _tap_card(body, _choose_build_decision.bind("fuse"), Kit.VIOLET)
		fusion.panel.name = "FusionChoiceFuse"
		Kit.caps(fusion.content, "FUSE · FREE ONE SLOT", Kit.VIOLET, 12)
		var fusion_title := Kit.label(fusion.content, "Fuse · " + str(spec.name), 20, Color.WHITE, true)
		fusion_title.add_theme_font_override("font", Kit.font(0, 0.45))
		Kit.label(fusion.content, str(spec.description) + "\nBoth abilities become one new ability at rank 1. Frees a slot.", 16, Kit.TEXT, true)
		Kit.caps(fusion.content, "TAP TO FUSE", Kit.CYAN, 12)
		first_option = fusion.button
		var keep := _tap_card(body, _choose_build_decision.bind("keep"), Kit.CYAN)
		keep.panel.name = "FusionChoiceKeep"
		Kit.caps(keep.content, "KEEP SEPARATE", Kit.CYAN, 12)
		var keep_title := Kit.label(keep.content, "Keep both abilities", 20, Color.WHITE, true)
		keep_title.add_theme_font_override("font", Kit.font(0, 0.45))
		Kit.label(keep.content, "Keep both abilities as they are. This fusion won't be offered again this run.", 16, Kit.TEXT, true)
		Kit.caps(keep.content, "TAP TO KEEP BOTH", Kit.CYAN, 12)
	_focus(first_option)

func _choose_build_decision(value: String) -> void:
	if mode != "build_choice" or not sim.resolve_build_choice(value):
		return
	sound.play("card")
	_save_run()
	_resume_after_build_choice()

func _resume_after_build_choice() -> void:
	if not sim.pending_build_choices.is_empty():
		_show_build_choice()
		return
	if not sim.cards.is_empty():
		_show_cards(false)
		return
	if sim.pending_levels > 0 and not sim.stage_transition_queued:
		sim._offer_cards()
		_show_cards(false)
		return
	mode = "playing"
	_clear_overlay()
	accumulator = -0.25
	_save_run()

func _show_cards(play_sound: bool = true) -> void:
	mode = "cards"
	_save_run()
	draft_guard = 0.35
	var view := _page(0.93, true, 520.0)
	var top: VBoxContainer = view.top
	var body: VBoxContainer = view.body
	var capped: bool = sim.cards.any(func(card): return str(card.id) == "core_cache")
	var title := "Remove an upgrade" if banish_mode else ("Choose a reward" if capped else "Choose an upgrade")
	# Ordinary drafts keep every card on a short phone without scrolling, so
	# only catch-up drafts spend a line on the eyebrow.
	var eyebrow := ("Free upgrades  ·  %d left" % (sim.catch_up_levels + 1)) if sim.catch_up_levels > 0 else ""
	if sim.intro_run:
		eyebrow = "First flight · Upgrade %d of 2" % (sim.intro_picks.size() + 1)
	_page_header(top, eyebrow, title)
	if banish_mode:
		Kit.label(top, "Tap one to remove it from this run. %d left." % sim.banishes_left, 16, Kit.DANGER, true)
	elif capped:
		Kit.label(top, "You have every upgrade. Repair your ship or take Cores.", 16, Kit.MUTED, true)
	else:
		var names := PackedStringArray()
		for slot in sim.active_slots:
			names.append(str(sim.content.abilities[str(slot)].name))
		Kit.label(top, "Abilities %d of 4:  %s" % [names.size(), ", ".join(names) if not names.is_empty() else "none yet"], 15, Kit.MUTED, true)
	for i in range(sim.cards.size()):
		_draft_card(body, i)
	if banish_mode:
		_ui_button(reading_footer, "Cancel", _toggle_banish, "secondary", 52, true)
	elif not capped:
		if sim.rerolls_left > 0:
			_draft_tool("Reroll", "%d left" % sim.rerolls_left, _draft_action.bind("reroll", 0), "Get new choices.")
		if sim.skips_left > 0:
			_draft_tool("Skip", "+%d hull" % (12 + int(sim.meta.skip_patch) * 6), _draft_action.bind("skip", 0), "Skip and repair %d hull" % (12 + int(sim.meta.skip_patch) * 6))
		if sim.banishes_left > 0:
			_draft_tool("Remove", "%d left" % sim.banishes_left, _toggle_banish, "Take one upgrade out of this run's pool")
	if sim.catch_up_levels > 0 and not banish_mode:
		var auto_button := _ui_button(view.bottom, "Pick the rest for me  ·  %d" % (sim.catch_up_levels + 1), _auto_catch_up, "secondary", 48)
		auto_button.name = "AutoPickCatchUp"
		auto_button.tooltip_text = "Picks guns first, then abilities, then defense."
	if not card_buttons.is_empty():
		_focus(card_buttons[0])
	if play_sound:
		sound.play("card")

func _auto_catch_up() -> void:
	if mode != "cards" or draft_guard > 0.0 or not sim.auto_finish_catch_up():
		return
	sound.play("card")
	if not sim.pending_build_choices.is_empty():
		_show_build_choice()
	elif not sim.cards.is_empty():
		_show_cards(false)
	elif sim.pending_levels > 0:
		sim._offer_cards()
		_show_cards(false)
	else:
		_clear_overlay()
		mode = "playing"
		accumulator = -0.25
		_save_run()

func _draft_tool(title: String, detail: String, action: Callable, tooltip: String) -> void:
	var tool := _ui_button(reading_footer, "%s\n%s" % [title, detail], action, "secondary", 58, true)
	tool.add_theme_font_size_override("font_size", 15)
	tool.tooltip_text = tooltip

func _draft_card(parent: Node, i: int) -> void:
	var card: Dictionary = sim.cards[i]
	var id: String = str(card.id)
	var tag: String = str(card.tag)
	var current: int = int(sim.upgrades.get(id, 0))
	var next_rank: int = current + Simulation.rank_gain(card, current)
	var milestone: int = 5 if current < 5 else 10
	var reaches_milestone: bool = current < milestone and next_rank >= milestone and tag != "RECOVERY"
	var is_new_ability := tag == "ABILITY" and current == 0
	var swap_partner: bool = is_new_ability and not sim.fusion_swap_targets(id).is_empty()
	var fusion: String = sim.fusion_target(id) if tag == "ABILITY" and not banish_mode else ""
	var fused: Dictionary = sim.fusion_spec(fusion)
	var accent := Kit.CYAN
	var type_text := "Active" if tag == "ABILITY" else ("Auto weapon" if tag == "WEAPON" else ("Mutation" if tag == "MUTATION" else "Passive"))
	var tag_text := ""
	if not fusion.is_empty():
		accent = Kit.VIOLET
		tag_text = "Active  ·  fusion"
	elif swap_partner:
		accent = Kit.VIOLET
		tag_text = "Active · replace for fusion"
	elif is_new_ability:
		tag_text = "Active  ·  new slot %d/4" % (sim.active_slots.size() + 1)
	elif tag == "MUTATION":
		accent = Kit.VIOLET
		tag_text = "Rare · one per run"
	elif id == "core_cache":
		accent = Kit.AMBER
		tag_text = "Cores"
	elif tag == "RECOVERY":
		accent = Color("7afcc0")
		tag_text = "Recovery"
	else:
		accent = Kit.CYAN if tag == "ABILITY" else (Kit.AMBER if tag == "WEAPON" else Color("9fcbff"))
		tag_text = "%s  ·  rank %d to %d" % [type_text, current, next_rank]
	if reaches_milestone and fusion.is_empty():
		tag_text = "%s  ·  rank %d bonus" % [type_text, milestone]
	var removable := banish_mode and id not in ["repair", "core_cache"]
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
	if id == "core_cache":
		row.add_child(Kit.core_icon(40))
	else:
		var badge := IconBadge.new()
		badge.icon_id = fusion if not fusion.is_empty() and not sim._new_build_decisions() else id
		badge.custom_minimum_size = Vector2(40, 40)
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(badge)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	Kit.caps(info, tag_text, accent, 13)
	var name_text := ("%d  " % (i + 1) if not _touch_first() else "") + (str(fused.name) if not fusion.is_empty() and not sim._new_build_decisions() else str(card.name))
	var title := Kit.label(info, name_text, 19, Color.WHITE, true)
	title.add_theme_font_override("font", Kit.font(0, 0.45))
	Kit.label(info, str(fused.description) if not fusion.is_empty() and not sim._new_build_decisions() else str(card.description), 16, Kit.TEXT, true)
	if swap_partner and not banish_mode:
		Kit.label(info, "Learn a fusion partner by choosing an ability to replace.", 15, Kit.VIOLET, true)
	if not fusion.is_empty():
		var fusion_note := "Unlocks %s · fuse or keep" % str(fused.name) if sim._new_build_decisions() else "%s %d → %d · frees a slot" % [sim.content.abilities[id].name, current, next_rank]
		Kit.label(info, fusion_note, 15, Kit.VIOLET, true)
	elif reaches_milestone:
		# Don't repeat distant rank descriptions on every ordinary card.
		# Only a breakpoint reached by THIS pick needs an extra text line.
		var reward := str(card.get("rank5" if milestone == 5 else "rank10", ""))
		if not reward.is_empty():
			Kit.label(info, "Now: " + reward, 15, accent, true)
	if not banish_mode and tag in ["WEAPON", "SYSTEM", "ABILITY"]:
		var engine_hint: String = sim.engine_hint_for_pick(id)
		if not engine_hint.is_empty():
			Kit.label(info, engine_hint, 15, Kit.AMBER, true)
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
		if not sim.pending_build_choices.is_empty():
			_show_build_choice()
		else:
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
	var flight_label := "First flight" if sim.intro_run else "Stage %d  ·  %s" % [sim.stage, sim.stage_name().capitalize()]
	var box := _sheet("Paused", "%s  ·  %02d:%02d" % [flight_label, seconds / 60, seconds % 60])
	Kit.label(box, "Your run is saved. The game is paused.", 15, Kit.MUTED, true)
	var resume := _ui_button(box, "Resume", _toggle_pause, "primary", 56)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_ui_button(row, "Build", _show_build, "secondary", 48, true)
	_ui_button(row, "Settings", _show_settings, "secondary", 48, true)
	_ui_button(box, "Save and quit to title", _show_menu, "ghost", 44)
	if sim.intro_run:
		_ui_button(box, "Skip to campaign", _new_run, "ghost", 44)
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
	if sim.artifact_id != "standard":
		var rule: Dictionary = Catalog.artifact(sim.artifact_id)
		_info_card(body, "Artifact: " + str(rule.name), str(rule.description), Kit.VIOLET)
	if not sim.mutations.is_empty():
		_section(body, "Mutated weapons")
		for mutation_id in sim.mutations:
			var mutation: Dictionary = Catalog.mutation(str(mutation_id))
			if not mutation.is_empty():
				_info_card(body, str(mutation.name), str(mutation.description), Kit.VIOLET)
	if not sim.weapon_evolutions.is_empty():
		_section(body, "Weapon specializations")
		for weapon in sim.weapon_evolutions:
			for option in sim.content.weapon_evolutions.get(str(weapon), []):
				if str(option.id) == str(sim.weapon_evolutions[weapon]):
					_info_card(body, str(weapon).capitalize() + " · " + str(option.name), str(option.description), Kit.AMBER)
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
			Kit.label(text, "Pick an ability to fill it.", 15, Kit.DIM)
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
			Kit.label(text, "Rank %d of 10 · %s + %s" % [sim.upgrades[id], sim.content.abilities[part_a].name, sim.content.abilities[part_b].name], 15, Kit.MUTED, true)
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
	if sim._new_build_decisions():
		var nearby: Array = []
		for recipe in sim.content.get("build_engines", []):
			if sim.engine_tier(str(recipe.id)) >= 2:
				continue
			var progress: int = sim._engine_recipe_progress(recipe)
			if progress > 0:
				nearby.append({"name":str(recipe.name), "progress":progress})
		if not nearby.is_empty():
			_section(body, "Builds in progress")
			for i in range(mini(3, nearby.size())):
				_info_card(body, str(nearby[i].name), "%d/3 parts · Get all 3 to switch it on." % int(nearby[i].progress), Kit.AMBER)
	var engines: Array = sim.active_engines()
	if not engines.is_empty():
		_section(body, "Automatic build engines")
		for i in range(engines.size() if build_show_all else mini(3, engines.size())):
			var engine: Dictionary = engines[i]
			var rank_label := "MASTERED" if int(engine.tier) == 3 else "ONLINE"
			_info_card(body, str(engine.name) + " · " + rank_label, str(engine.description), Kit.CYAN)
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
		Kit.label(body, "Current route: " + _route_name(sim.destination_choice if not sim.destination_choice.is_empty() else sim.route_choice), 16, Kit.CYAN)
	_ui_button(body, "Hide full equipment list" if build_show_all else "Show all upgrades and Hangar ranks", _toggle_build_details, "ghost", 44)
	if build_show_all:
		for group in [["WEAPON", "Automatic weapons"], ["SYSTEM", "Passive upgrades"]]:
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
	if sim != null:
		var spec: Dictionary = sim.destination_spec(id)
		if not spec.is_empty():
			return str(spec.name)
	return str({"repair": "Shielded passage", "overclock": "Redline assault", "bounty": "Hunter contract"}.get(id, id.capitalize()))

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

func _show_signal() -> void:
	if mode not in ["playing", "archive_signal"] or sim.signal_status != "offer":
		return
	mode = "archive_signal"
	_save_run()
	var view := _page(1.0, true, 500.0)
	_page_header(view.top, "Hidden signal  ·  %d / %d found" % [sim.signal_count, HiddenSector.REQUIRED_SIGNALS], HiddenSector.signal_name(sim.seed_value, sim.stage).capitalize())
	Kit.label(view.top, "“If you can hear this, there is a hidden door past the last world. Find two signals and we can show you where.”", 17, Kit.TEXT, true)
	_info_card(view.body, "Tune the receiver", "Use any ability when you see USE NOW. You have 52 seconds.", HiddenSector.MINT)
	_ui_button(view.body, "Tune receiver", _choose_signal.bind("cast"), "secondary", 48)
	_info_card(view.body, "Intercept the courier", "Shoot down the marked ship before it escapes. Your ship aims at it for you.", HiddenSector.COLOR)
	_ui_button(view.body, "Intercept courier", _choose_signal.bind("courier"), "secondary", 48)
	_focus(_ui_button(reading_footer, "Ignore signal", _choose_signal.bind("ignore"), "ghost", 50, true))

func _choose_signal(action: String) -> void:
	if mode != "archive_signal" or not sim.choose_signal(action):
		return
	mode = "playing"
	accumulator = 0.0
	_clear_overlay()
	_save_run()

func _archive_art(parent: Node, scene: String) -> void:
	var art := ArchiveIllustration.new()
	art.scene = scene
	art.reduced = bool(profile.reduced)
	art.custom_minimum_size.y = 195.0 if get_viewport_rect().size.y < 740.0 else 256.0
	parent.add_child(art)

func _show_archive_reveal(reset_clock: bool = true) -> void:
	mode = "archive_reveal"
	_save_run()
	var view := _page(1.0, true, 560.0)
	_page_header(view.top, "Campaign cleared  ·  Signal found", "A door in the dark")
	_archive_art(view.body, "gate")
	Kit.label(view.body, "“The Regent is down. Look beyond the wreckage. That light has been waiting for you.”", 18, Kit.TEXT, true)
	Kit.label(view.body, "The Silent Archive is a harder secret world. Your win and Cores are already saved. You keep your build and get a full shield.", 16, Kit.MUTED, true)
	var finish_button := _ui_button(reading_footer, "Finish campaign", _finish_at_citadel, "primary", 52, true)
	_ui_button(reading_footer, "Play Endless", _continue_endless, "secondary", 52, true)
	_ui_button(view.bottom, "Enter the Silent Archive", _enter_archive, "amber", 52)
	_focus(finish_button)
	if reset_clock:
		sound.play("archive-signal", -6.0)
		_haptic(110)

func _finish_at_citadel() -> void:
	if mode == "archive_reveal" and sim.can_enter_secret() and sim.advance_stage():
		_finish()

func _enter_archive() -> void:
	if mode == "archive_reveal" and sim.enter_secret():
		_finish_intermission_presentation()
		_show_archive_intro()

func _show_archive_intro(reset_sound: bool = true) -> void:
	mode = "archive_intro"
	_save_run()
	var view := _page(1.0, true, 520.0)
	if sim.boss_spawned:
		_page_header(view.top, "Archive defense online", "The Last Custodian")
		_archive_art(view.body, "boss")
		Kit.label(view.body, "“I was ordered to keep this door closed. I no longer remember by whom.”", 18, Kit.TEXT, true)
		Kit.label(view.body, "The boss has 3 shields. When you see a warning, use an ability to open the core, then shoot it.", 17, HiddenSector.MINT, true)
	else:
		_page_header(view.top, "World 5  ·  Off the charts", "Silent Archive")
		_archive_art(view.body, "arrival")
		Kit.label(view.body, "You found both signals. Your ship knows the way.", 18, Kit.TEXT, true)
		Kit.label(view.body, "Save an ability for the station's warnings. Destroy the relay ships to weaken its guards.", 17, HiddenSector.MINT, true)
	_focus(_ui_button(reading_footer, "Engage Custodian" if sim.boss_spawned else "Fly into the Archive", _resume_archive, "primary", 56, true))
	if reset_sound:
		sound.play("archive-boss" if sim.boss_spawned else "archive-signal", -6.0)
		_haptic(90)

func _resume_archive() -> void:
	if mode != "archive_intro" or not sim.dismiss_secret_intro():
		return
	mode = "playing"
	accumulator = 0.0
	_clear_overlay()
	_save_run()

func _show_archive_ending(reset_sound: bool = true) -> void:
	mode = "archive_ending"
	_save_run()
	var view := _page(1.0, true, 540.0)
	_page_header(view.top, "World 5 clear  ·  Final signal", "A light left on")
	_archive_art(view.body, "epilogue")
	Kit.label(view.body, "The station opens. You found the secret ending.", 19, Kit.TEXT, true)
	Kit.label(view.body, "You leave the gate open.", 18, HiddenSector.MINT, true)
	_info_card(view.body, "Open Frequency", "A permanent record in Awards.", HiddenSector.COLOR)
	_focus(_ui_button(reading_footer, "Finish", _finish_archive, "primary", 56, true))
	if reset_sound:
		sound.play("archive-release", -4.0)
		_haptic(125)

func _finish_archive() -> void:
	if mode == "archive_ending" and sim.advance_stage():
		_finish()

func _update_archive_hud() -> void:
	signal_button.visible = mode == "playing" and sim.signal_status == "offer"
	var custodian_active: bool = sim.secret_entered and sim.boss_spawned and not sim.stage_transition_queued
	signal_label.visible = mode == "playing" and (sim.signal_status in ["cast", "courier"] or not sim.archive_attack.is_empty() or custodian_active)
	if signal_label.visible:
		var world_y := 289.0 if sim.secret_entered and sim.boss_spawned else 97.0
		signal_label.position.y = field.position.y + world_y * scale_factor
	if not sim.archive_attack.is_empty():
		signal_label.text = "%s  %.1fs  ·  USE AN ABILITY" % [sim.archive_attack.to_upper(), maxf(0.0, sim.archive_attack_until - sim.time)]
		signal_label.add_theme_color_override("font_color", Kit.DANGER)
	elif sim.signal_status == "cast":
		signal_label.text = "CAST NOW  ·  ANY ABILITY" if sim.signal_cast_window() else "RECEIVER TUNING  ·  WAIT"
		signal_label.add_theme_color_override("font_color", HiddenSector.MINT if sim.signal_cast_window() else Kit.TEXT)
	elif sim.signal_status == "courier":
		signal_label.text = "MARKED COURIER  ·  %ds" % ceili(sim.signal_until - sim.time)
		signal_label.add_theme_color_override("font_color", HiddenSector.COLOR)
	elif custodian_active:
		if sim.time < sim.archive_exposed_until:
			signal_label.text = "PHASE %d/3 · CORE EXPOSED" % (sim.archive_phase + 1)
			signal_label.add_theme_color_override("font_color", HiddenSector.MINT)
		else:
			signal_label.text = "PHASE %d/3 · SEALED · NEXT %.0fs" % [sim.archive_phase + 1, maxf(0.0, sim.archive_next_attack - sim.time)]
			signal_label.add_theme_color_override("font_color", HiddenSector.COLOR)

func _show_stage_clear(reset_clock: bool = true) -> void:
	if sim.can_enter_secret():
		_show_archive_reveal(reset_clock)
		return
	if sim.secret_entered:
		_show_archive_ending(reset_clock)
		return
	stage_clear_secondary = null # Never keep a freed Endless button across ceremonies.
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
	var progress_title := "Endless world %d cleared" % sim.stage if sim.endless_enabled else "World %d of %d cleared" % [sim.stage, sim.stage_count()]
	var eyebrow := Kit.caps(headline, progress_title, Kit.AMBER, 15)
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
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 12)
	content.add_child(stats)
	_big_stat(stats, str(sim.payout()), "Cores this run", Kit.AMBER)
	_big_stat(stats, str(sim.kills), "Kills", Color.WHITE)
	if is_final:
		Kit.label(content, "Daily done." if not sim.daily_day.is_empty() else "All four worlds beaten.", 16, Kit.TEXT, true)
	elif sim.endless_enabled:
		Kit.label(content, "Next: World %d. It only gets harder." % (sim.stage + 1), 16, Kit.TEXT, true)
	else:
		var next: Dictionary = sim.content.stages[sim.stage]
		Kit.label(content, "Next: %s" % str(next.name).capitalize(), 16, Kit.TEXT, true)
	stage_clear_button = _ui_button(content, "Finish run" if is_final else ("Continue to world %d" % (sim.stage + 1) if sim.endless_enabled else "Warp to " + str(sim.stage_spec().transition).capitalize()), _begin_warp, "primary", 58)
	stage_clear_button.disabled = stage_clear_clock < 1.2
	if is_final and sim.daily_day.is_empty():
		stage_clear_secondary = _ui_button(content, "Keep going (Endless)", _continue_endless, "secondary", 50)
		stage_clear_secondary.disabled = stage_clear_clock < 1.2
	elif sim.endless_enabled:
		stage_clear_secondary = _ui_button(content, "End run", _claim_endless, "secondary", 50)
		stage_clear_secondary.disabled = stage_clear_clock < 1.2
	if not stage_clear_button.disabled:
		_focus(stage_clear_button)
	if reset_clock:
		sound.play("boss-explosion", -4.0)
		_haptic(130)

func _merchant_identity(parent: Node) -> void:
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", Kit.box(Color("1d211f"), Kit.AMBER, 14, 2, 12, 12))
	parent.add_child(plate)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	plate.add_child(row)
	var ship_picture := MerchantShip.new()
	ship_picture.name = "MerchantHailPortrait"
	# A narrower insignia is intentional on 375-point phones. Otherwise the
	# freighter's row forces the whole scroll panel beyond the right edge.
	ship_picture.custom_minimum_size = Vector2(84,96) if _compact_ui() else Vector2(112,122)
	row.add_child(ship_picture)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 5)
	row.add_child(words)
	Kit.caps(words, "?  UNKNOWN SHIP", Kit.AMBER, 12)
	Kit.label(words, "The Quartermaster", 20 if _compact_ui() else 22, Kit.TEXT, true)
	Kit.label(words, "No questions. No returns.", 15, Kit.MUTED, true)

func _show_merchant_signal() -> void:
	if sim.merchant_state != "signal":
		return
	mode = "merchant_signal"
	_save_run()
	var view := _page(0.97, true, 510.0)
	_page_header(view.top, "!  A TRADER IS CALLING  ·  WORLD %d" % sim.stage, "A private offer")
	_merchant_identity(view.body)
	Kit.label(view.body, "A trader is offering rare gear. Every deal has a cost. The game is paused while you decide.", 16, Kit.TEXT, true)
	Kit.label(view.body, "Answer, or ignore them and keep flying.", 15, Kit.MUTED, true)
	_ui_button(view.bottom, "Save and quit to title", _show_menu, "ghost", 44)
	_focus(_ui_button(reading_footer, "Hail freighter", _merchant_hail, "primary", 58, true))
	_ui_button(reading_footer, "Ignore signal", _merchant_leave, "secondary", 58, true)
	sound.play("warning")

func _merchant_hail() -> void:
	if mode != "merchant_signal" or not sim.merchant_hail():
		return
	_save_run()
	sound.play("card")
	_show_merchant_shop()

func _show_merchant_shop() -> void:
	if sim.merchant_state != "shop":
		return
	mode = "merchant_shop"
	_save_run()
	var view := _page(0.95, true, 540.0)
	_page_header(view.top, "TRADER  ·  ONE DEAL", "Quartermaster")
	Kit.label(view.top, "You can make one deal. Costs last for this run only. You can leave without buying.", 16, Kit.MUTED, true)
	_merchant_identity(view.body)
	for offer in sim.merchant_offers:
		var id: String = str(offer.id)
		var card := _tap_card(view.body, _merchant_preview.bind(id), Kit.AMBER)
		card_buttons.append(card.button)
		Kit.caps(card.content, str(offer.tag), Kit.AMBER, 13)
		Kit.label(card.content, str(offer.name), 20, Kit.TEXT, true)
		_gain_cost(card.content, str(offer.gain), str(offer.cost))
		if not sim.merchant_can_afford(id):
			card.button.disabled = true
			card.panel.modulate = Color(1,1,1,0.48)
			Kit.label(card.content, "You can't take this deal right now.", 14, Kit.MUTED, true)
	_ui_button(view.bottom, "Save and quit to title", _show_menu, "ghost", 44)
	_ui_button(reading_footer, "Leave without a deal", _merchant_leave, "secondary", 55, true)
	if not card_buttons.is_empty():
		_focus(card_buttons[0])

func _merchant_preview(id: String) -> void:
	if mode != "merchant_shop" or not sim.merchant_preview(id):
		return
	_save_run()
	_show_merchant_confirm()

func _show_merchant_confirm() -> void:
	if sim.merchant_state != "confirm":
		return
	mode = "merchant_confirm"
	_save_run()
	var view := _page(0.96, true, 510.0)
	_page_header(view.top, "FINAL OFFER  ·  NO REFUNDS", "Confirm this trade")
	_merchant_identity(view.body)
	var offer: Dictionary = sim.merchant_offer_spec(sim.merchant_selected)
	if not offer.is_empty():
		Kit.label(view.body, str(offer.name), 22, Kit.AMBER, true)
		_gain_cost(view.body, str(offer.gain), str(offer.cost))
	Kit.label(view.body, "This lasts for the rest of this run. Nothing happens until you confirm.", 16, Kit.MUTED, true)
	_ui_button(view.bottom, "Save and quit to title", _show_menu, "ghost", 44)
	var accept := _ui_button(reading_footer, "Accept trade", _merchant_accept, "primary", 55, true)
	accept.disabled = not sim.merchant_can_afford(sim.merchant_selected)
	_focus(accept)
	_ui_button(reading_footer, "Back to offers", _merchant_back, "secondary", 55, true)

func _merchant_back() -> void:
	if mode != "merchant_confirm" or not sim.merchant_back():
		return
	_save_run()
	_show_merchant_shop()

func _merchant_accept() -> void:
	if mode != "merchant_confirm" or not sim.merchant_accept():
		return
	_save_run()
	sound.play("card")
	_show_merchant_receipt()

func _merchant_trade_name(id: String) -> String:
	match id:
		"pact": return "Hot Reactor"
		"repair": return "Field Salvage"
		"sell_hull": return "Wreckage Contract"
	if id.begins_with("mutation:"):
		return str(Catalog.mutation(id.trim_prefix("mutation:")).get("name","Exotic modification"))
	if id.begins_with("exchange:"):
		return "Ability Exchange"
	return "Merchant transaction"

func _show_merchant_receipt() -> void:
	mode = "merchant_receipt"
	_save_run()
	var view := _page(0.97, true, 490.0)
	_page_header(view.top, "TRANSACTION COMPLETE", "Deal made")
	_merchant_identity(view.body)
	Kit.label(view.body, "Deal done. It lasts for the rest of this run. The trader is gone.", 17, Kit.TEXT, true)
	Kit.label(view.body, "Received: " + (_merchant_trade_name(str(sim.merchant_trade_log[-1])) if not sim.merchant_trade_log.is_empty() else "Unknown"), 16, Kit.CYAN, true)
	_focus(_ui_button(reading_footer, "Back to the game", _merchant_resume, "primary", 58, true))

func _merchant_leave() -> void:
	if mode not in ["merchant_signal","merchant_shop","merchant_confirm"] or not sim.merchant_leave():
		return
	_merchant_resume()

func _merchant_resume() -> void:
	if mode not in ["merchant_signal","merchant_shop","merchant_confirm","merchant_receipt"]:
		return
	if sim.merchant_state == "receipt":
		sim.merchant_acknowledge_receipt()
	elif not sim.merchant_state.is_empty():
		sim.merchant_leave()
	mode = "playing"
	_clear_overlay()
	accumulator = 0.0
	_save_run()
	_surface_pending_flight_choice()

func _surface_pending_flight_choice() -> void:
	# Overlay transitions have priority over a timer that only advances
	# while actual gameplay runs. No competing event is silently discarded
	# by closing a Quartermaster or Rival Captain panel.
	if mode != "playing":
		return
	if sim.rival_retire_pending:
		_show_rival_retired()
	elif sim.rival_intro_pending:
		_show_rival_intro()
	elif sim.signal_status == "offer" and not sim.stage_transition_queued and not sim.ended and sim.time < sim.signal_until:
		_show_signal()
	elif not sim.cards.is_empty():
		_show_cards()

func _show_prototypes() -> void:
	mode = "prototype"
	_save_run()
	var view := _page(0.95, true, 540.0, 24.0)
	var step_text := ("World %d prototype" % sim.stage) if sim.skipping_worlds() and sim.stage + 1 < sim.start_world else ("Before the next world" if sim.expedition_active() else "Step 1 of 2")
	_page_header(view.top, step_text, "Pick a prototype")
	# This explanation scrolls with the options rather than crowding the
	# fixed header on a short phone.
	Kit.label(view.body, "Each one has a bonus and a cost. Or skip it for %d Cores." % Simulation.PROTOTYPE_SKIP_CORES, 15, Kit.MUTED, true)
	for i in range(sim.prototype_offers.size()):
		var spec: Dictionary = sim.prototype_spec(str(sim.prototype_offers[i]))
		var illegal: bool = str(spec.role) == "ILLEGAL TRADE"
		var card := _tap_card(view.body, _choose_prototype.bind(i), Kit.AMBER if illegal else Kit.CYAN)
		card.panel.name = "PrototypeChoice%d" % i
		card_buttons.append(card.button)
		# Role chip and name have independent full-width lines. Side-by-side
		# intrinsic widths used to force the final option past narrow screens.
		Kit.caps(card.content, "BLACK MARKET" if illegal else str(spec.role), Kit.AMBER if illegal else Kit.MUTED, 12)
		var title := Kit.label(card.content, str(spec.name), 19, Color.WHITE, true)
		title.add_theme_font_override("font", Kit.font(0, 0.45))
		_gain_cost(card.content, str(spec.benefit), str(spec.cost))
	_ui_button(view.bottom, "Save and quit to title", _show_menu, "ghost", 44)
	var skip_button := _ui_button(reading_footer, "Skip prototype · +%d Cores" % Simulation.PROTOTYPE_SKIP_CORES, _skip_prototype, "secondary", 54, true)
	skip_button.tooltip_text = "Take %d Cores instead." % Simulation.PROTOTYPE_SKIP_CORES
	if not card_buttons.is_empty():
		_focus(card_buttons[0])

func _gain_cost(parent: Node, gain: String, cost: String) -> void:
	# A two-column GridContainer measures the unwrapped minimum width of
	# long benefits. It could force a whole card beyond a 375pt phone viewport.
	# Vertical, auto-wrapping rows keep every tradeoff within the card instead.
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 8)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(details)
	for pair in [["Gain", gain, Kit.CYAN, Kit.TEXT], ["Cost", cost, Kit.AMBER, Color("ffd9b0")]]:
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 2)
		section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		section.mouse_filter = Control.MOUSE_FILTER_IGNORE
		details.add_child(section)
		Kit.caps(section, str(pair[0]), pair[2], 12)
		var detail := Kit.label(section, str(pair[1]), 15, pair[3], true)
		detail.custom_minimum_size.x = 0

func _show_route_choice() -> void:
	mode = "route"
	_save_run()
	var view := _page(0.95, true, 540.0, 24.0)
	_page_header(view.top, "Chart your next jump" if sim.expedition_active() else "Step 2 of 2", "Pick a destination" if sim.expedition_active() else "Pick a route")
	var next: Dictionary = sim.content.stages[mini(sim.stage, sim.content.stages.size() - 1)]
	Kit.label(view.body, "Next: World %d, %s. %s" % [sim.stage + 1, str(next.name).capitalize(), str(next.description)], 16, Kit.MUTED, true)
	var routes := [
		{"id": "repair", "tag": "Safe", "gain": "Repair 70% hull. Next world: 35% less damage taken, abilities recharge 15% faster, +15% gun damage while shield is above half.", "cost": "No extra XP or Cores.", "accent": Kit.CYAN},
		{"id": "overclock", "tag": "All-in", "gain": "Next world: guns hit 35% harder and fire 20% faster.", "cost": "Repair only 10% hull. Start at half shield. Take 20% more hull damage.", "accent": Kit.AMBER},
		{"id": "bounty", "tag": "Greedy", "gain": "One extra upgrade, +50%% XP, +%d Cores for the boss. Repair 40%% hull." % (30 * (sim.stage + 1)), "cost": "More enemies, and 30% tougher.", "accent": Kit.DANGER},
	]
	if sim.expedition_active():
		routes.clear()
		for id in sim.available_destinations():
			var spec: Dictionary = sim.destination_spec(str(id)).duplicate(true)
			spec["accent"] = Kit.CYAN if spec.group == "repair" else (Kit.AMBER if spec.group == "overclock" else Kit.DANGER)
			routes.append(spec)
	for route in routes:
		var card := _tap_card(view.body, _choose_route.bind(str(route.id)), route.accent)
		card.panel.name = "RouteChoice" + str(route.id).to_pascal_case()
		card_buttons.append(card.button)
		Kit.caps(card.content, str(route.tag), route.accent, 12)
		var title := Kit.label(card.content, _route_name(str(route.id)), 19, Color.WHITE, true)
		title.add_theme_font_override("font", Kit.font(0, 0.45))
		_gain_cost(card.content, str(route.gain), str(route.cost))
	_ui_button(reading_footer, "Save and quit to title", _show_menu, "ghost", 48, true)
	if not card_buttons.is_empty():
		_focus(card_buttons[0])

func _show_mutation_lab() -> void:
	mode = "mutation_lab"
	_save_run()
	var view := _page(0.95, true, 540.0, 24.0)
	_page_header(view.top, "EXPERIMENTAL WORKSHOP", "Choose a mutation")
	Kit.label(view.body, "Transform one of your existing weapons for the rest of this run. This is a separate choice, not a replacement for your prototype. You can skip it.", 16, Kit.MUTED, true)
	for id in sim.mutation_offers:
		var spec: Dictionary = Catalog.mutation(str(id))
		var card := _tap_card(view.body, _choose_lab_mutation.bind(str(id)), Kit.VIOLET)
		card.panel.name = "LabMutation" + str(id).to_pascal_case()
		card_buttons.append(card.button)
		Kit.caps(card.content, str(spec.requires).capitalize() + " · one mutation per run", Kit.VIOLET, 12)
		Kit.label(card.content, str(spec.name), 19, Color.WHITE, true)
		Kit.label(card.content, str(spec.description), 16, Kit.TEXT, true)
	var skip := _ui_button(reading_footer, "Skip mutation", _choose_lab_mutation.bind("skip"), "secondary", 54, true)
	_ui_button(view.bottom, "Save and quit to title", _show_menu, "ghost", 44)
	_focus(skip if card_buttons.is_empty() else card_buttons[0])

func _choose_lab_mutation(id: String) -> void:
	if mode != "mutation_lab" or not sim.choose_lab_mutation(id):
		return
	_save_run()
	_finish_intermission()

func _show_results() -> void:
	mode = "results"
	var view := _page(1.0, true, 540.0)
	var body: VBoxContainer = view.body
	var qualifier: String = "Daily · %s" % sim.daily_day if not sim.daily_day.is_empty() else str(sim.difficulty).capitalize()
	var title := "Victory" if sim.won else "Destroyed"
	if sim.secret_entered:
		title = "Open Frequency" if sim.won else "Signal lost"
	_page_header(view.top, qualifier, title)
	Kit.label(view.top, "World %d of %d  ·  %s  ·  %s" % [sim.stage, sim.stage_count(), sim.stage_name().capitalize(), _clock(sim.time)], 16, Kit.MUTED, true)
	if sim.secret_entered and not sim.won:
		Kit.label(view.top, "Your win and Cores are saved.", 16, HiddenSector.MINT, true)
	# Cores first: it is what the run was for.
	var hero := PanelContainer.new()
	hero.add_theme_stylebox_override("panel", Kit.box(Color("1b160f"), Color("4d3c22"), 16, 1, 16, 14))
	body.add_child(hero)
	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 12)
	hero.add_child(hero_row)
	hero_row.add_child(Kit.core_icon(30))
	var credited: int = result_earned_cores if result_earned_cores >= 0 else sim.payout()
	var earned := Kit.label(hero_row, "+%s" % _num(credited), 40, Kit.AMBER)
	earned.add_theme_font_override("font", Kit.font(0, 0.7))
	var hero_text := VBoxContainer.new()
	hero_text.add_theme_constant_override("separation", 0)
	hero_text.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_row.add_child(hero_text)
	Kit.label(hero_text, "Cores", 16, Kit.TEXT)
	Kit.label(hero_text, "Wallet %s" % _num(int(profile.cores)), 15, Kit.MUTED)
	if sim.bounty_earned > 0:
		Kit.label(hero_text, "%s from bounties" % _num(sim.bounty_earned), 14, Kit.MUTED)
	_ui_button(body, "Hangar", _show_hangar, "amber", 48)
	if not sim.daily_day.is_empty():
		var day_record: Dictionary = profile.daily_records.get(sim.daily_day, {})
		var best: int = result_daily_best if result_daily_best >= 0 else int(day_record.get("best_score",-1))
		var score: int = result_daily_score if result_daily_score >= 0 else Progress.daily_score(sim)
		_info_card(body, "Daily challenge  ·  %s" % sim.daily_day, "Score %s  ·  Best %s%s\nCores only for your first daily run of the day." % [_num(score), _num(best), "  ·  NEW BEST" if result_new_best else ""], Kit.AMBER)
		_ui_button(body, "Share score" if daily_share_service != null else "Copy score", _share_daily_result, "secondary", 50)
		if game_center.supports_game_center():
			_ui_button(body, "Leaderboard", _show_game_center_leaderboard, "secondary", 48)
	# Rival news.
	if not result_rival_news.is_empty():
		var recent: Dictionary = result_rival_news.get("rival", {})
		if not recent.is_empty():
			match str(result_rival_news.get("kind", "")):
				"created":
					_rival_identity(body, recent, "NEW RIVAL  ·  They may come back.")
				"rival_defeat":
					_rival_identity(body, recent, "YOUR RIVAL GOT YOU AGAIN")
				"retired":
					_rival_identity(body, recent, "RIVAL BEATEN  ·  Trophy added.")
	if sim.rival_outcome == "retired" and result_rival_news.is_empty() and not sim.rival_record.is_empty():
		_rival_identity(body, sim.rival_record, "RIVAL BEATEN  ·  Trophy added.")
	if not result_rival_news.is_empty() or sim.rival_outcome == "retired":
		_ui_button(body, "Rivals", _show_rival_journal, "secondary", 48)
	if not result_unlocked.is_empty():
		var unlocked_names := PackedStringArray()
		for id in result_unlocked:
			var ship: Dictionary = Catalog.ship(str(id))
			unlocked_names.append(str(ship.name) if str(ship.id) == str(id) else str(Catalog.pilot(str(id)).name))
		_info_card(body, "Unlocked", "\n".join(unlocked_names), Kit.AMBER)
		_ui_button(body, "Ships & pilots", _show_loadout, "secondary", 48)
	if not result_awards.is_empty():
		var names := PackedStringArray()
		for id in result_awards:
			var entry: Dictionary = Progress.achievement(str(id))
			if not entry.is_empty():
				names.append(str(entry.name))
		_info_card(body, "New achievements", "\n".join(names), Kit.CYAN)
		_ui_button(body, "Achievements", _show_achievements, "secondary", 48)
	# The numbers.
	_tiles(body, [["Kills", _num(sim.kills)], ["Worlds", "%d/%d" % [mini(sim.stage_clears, sim.stage_count()), sim.stage_count()]], ["Level", str(sim.level)]])
	_tiles(body, [["Blocked", _num(roundi(sim.prevented))], ["Beams stopped", str(sim.beams_cancelled)], ["Abilities used", str(sim.ability_uses)]])
	# What killed you, with one tip.
	var taken_rows: Array = []
	var total_taken := 0.0
	var damage_names := {"heavy":"Heavy beams", "chaff":"Small shots", "ordnance":"Missiles", "hazard":"Hazards", "ion":"Ion", "corrosion":"Corrosion", "heat":"Heat", "gravity":"Gravity", "disrupt":"Disruption", "void":"Void"}
	for kind in sim.damage_taken:
		var value := float(sim.damage_taken[kind])
		if value > 0.0:
			taken_rows.append([str(damage_names.get(kind, str(kind).capitalize())), value, str(kind)])
			total_taken += value
	taken_rows.sort_custom(func(a, b): return a[1] > b[1])
	if not sim.won and not taken_rows.is_empty():
		var tips := {"heavy":"Aegis blocks beams. Use it when the warning shows.", "ordnance":"Flak clears missiles, mines and slag.", "chaff":"Barrier blocks small bullets. Deflector turns them into shield.", "hazard":"Watch the edges and keep a defense ability ready.", "ion":"Capacitor refills your shield and fixes jamming.", "corrosion":"Kill corroding enemies first. Add repair or armor.", "heat":"Add shield recharge and stop the volley.", "gravity":"Chrono or Jammer helps against crowds.", "disrupt":"Jammer silences enemy weapons.", "void":"Save a defense ability for the boss's big attacks."}
		var worst: Array = taken_rows[0]
		_info_card(body, "What killed you", "%s, %d%% of damage taken.\n%s" % [worst[0], roundi(worst[1] / total_taken * 100.0), str(tips.get(worst[2], "Upgrade your defenses."))], Kit.DANGER)
	var dealt_rows: Array = []
	var weapon_names := {"pulse":"Pulse", "seeker":"Seekers", "arc":"Arc", "lance":"Lance", "nova":"Nova", "barrage":"Barrage"}
	for key in sim.damage_dealt:
		var value := float(sim.damage_dealt[key])
		# Engine damage is listed with the build below.
		if value > 0.0 and not str(key).begins_with("engine_"):
			dealt_rows.append([str(weapon_names.get(key, str(key).replace("_", " ").capitalize())), value])
	dealt_rows.sort_custom(func(a, b): return a[1] > b[1])
	_bar_rows(body, "Damage dealt", dealt_rows.slice(0, 5), Kit.AMBER)
	_bar_rows(body, "Damage taken", taken_rows.slice(0, 5), Kit.DANGER)
	# The build, as short lines.
	var build_lines := PackedStringArray()
	var ability_names := PackedStringArray()
	for slot in sim.active_slots:
		var spec_name: String = str(sim.content.abilities.get(str(slot), {}).get("name", str(slot).capitalize()))
		ability_names.append("%s %d" % [spec_name, int(sim.upgrades.get(str(slot), 0))])
	if not ability_names.is_empty():
		build_lines.append("Abilities: " + ", ".join(ability_names))
	for combo in sim.active_synergies():
		build_lines.append("Bonus: " + str(combo.name).capitalize())
	for link in sim.active_passive_links():
		build_lines.append("Pair: " + str(link.name))
	for engine in sim.active_engines():
		build_lines.append("Engine: " + str(engine.name) + (" (max)" if int(engine.tier) == 3 else ""))
	for impact in sim.build_impact_rows(2):
		build_lines.append("%s: %s" % [str(impact.name), str(impact.detail)])
	for weapon in sim.weapon_evolutions:
		for option in sim.content.weapon_evolutions.get(str(weapon), []):
			if str(option.id) == str(sim.weapon_evolutions[weapon]):
				build_lines.append("Evolution: " + str(option.name))
	for id in sim.prototypes:
		build_lines.append("Prototype: " + str(sim.prototype_spec(str(id)).name))
	for id in sim.mutations:
		build_lines.append("Mutation: " + str(Catalog.mutation(str(id)).name))
	if sim.artifact_id != "standard":
		build_lines.append("Artifact: " + str(Catalog.artifact(sim.artifact_id).name))
	if sim.merchant_trade_count > 0:
		var deal_names := PackedStringArray()
		for deal_id in sim.merchant_trade_log:
			deal_names.append(_merchant_trade_name(str(deal_id)))
		build_lines.append("Trader: " + ", ".join(deal_names))
	_info_card(body, "Your build", "\n".join(build_lines) if not build_lines.is_empty() else "No abilities this run.", Kit.CYAN)
	if not sim.won:
		var recap := PackedStringArray()
		for i in range(sim.events.size() - 1, -1, -1):
			var event: Dictionary = sim.events[i]
			if event.time >= sim.time - 10.0 and recap.size() < 4:
				recap.append("-%.1fs   %s" % [sim.time - event.time, event.message])
		if not recap.is_empty():
			_info_card(body, "Last moments", "\n".join(recap), Kit.MUTED)
	var again := _ui_button(reading_footer, "Daily again" if not sim.daily_day.is_empty() else "Fly again", _new_daily_run if not sim.daily_day.is_empty() else _new_run, "primary", 56, true)
	_ui_button(reading_footer, "Title", _show_menu, "secondary", 56, true)
	_focus(again)

## A titled card of horizontal bars, longest first: [name, value] rows.
func _bar_rows(parent: Node, heading: String, rows: Array, tint: Color) -> void:
	if rows.is_empty():
		return
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", Kit.box(Kit.SURFACE, Kit.LINE, 14, 1, 14, 12))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	Kit.caps(content, heading, tint, 13)
	var top: float = maxf(1.0, float(rows[0][1]))
	for row in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		content.add_child(line)
		var name_label := Kit.label(line, str(row[0]), 15, Kit.TEXT)
		name_label.custom_minimum_size.x = 104
		var bar := _meter(tint)
		bar.value = float(row[1]) / top * 100.0
		bar.custom_minimum_size = Vector2(0, 10)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(bar)
		var amount := Kit.label(line, _num(roundi(float(row[1]))), 15, Kit.MUTED)
		amount.custom_minimum_size.x = 64
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

## 12345 -> "12,345".
func _num(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out

func _clock(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]

func _opening_first30_beat() -> void:
	var phase: String = sim.world1_opening_phase()
	if phase == opening_last_phase:
		return
	opening_last_phase = phase
	match phase:
		"scouts":
			banner_text = "ENEMIES AHEAD"
			banner_clock = 3.5
		"warning":
			banner_text = "!  ENEMY GROUP INCOMING"
			banner_clock = 4.0
			sound.play("warning")
		"formation":
			banner_text = "THREE-SHIP ATTACK"
			banner_clock = 3.5
			sound.play("warning")
		"recovery":
			banner_text = "MORE ENEMIES COMING"
			banner_clock = 2.6
		"counterattack":
			banner_text = "BIG WAVE  ·  HOLD ON"
			banner_clock = 3.5

func _new_intro_run(replay: bool = false) -> void:
	var saved := _saved_flight()
	if not saved.is_empty() and (not bool(saved.get("intro_run", false)) or not bool(saved.get("ended", false))):
		return
	banish_mode = false
	build_show_all = false
	var reward_eligible: bool = not replay and profile.intro_status == "available"
	if reward_eligible and not _save_profile():
		_queue_toast("First flight could not start", "The profile could not be saved.")
		return
	sim = Simulation.new(FirstFlight.SEED)
	sim.configure_first_flight(reward_eligible)
	_start_flight()

func _show_intro_aegis() -> void:
	mode = "intro_aegis"
	accumulator = 0.0
	_save_run()
	_update_intro_hud()
	_update_hud()
	_focus(ability_a)
	sound.play("warning")
	_haptic(45)

func _continue_intro_aegis() -> void:
	if mode != "intro_aegis":
		return
	sim.intro_aegis_prompt = false
	mode = "playing"
	accumulator = 0.0
	_save_run()

func _show_intro_clear() -> void:
	mode = "intro_clear"
	intro_clear_clock = 0.0
	_save_run()
	sound.play("boss-explosion")
	_haptic(90)

func _unsettled_intro() -> bool:
	if profile.intro_status != "available":
		return false
	var saved := _saved_flight()
	return bool(saved.get("intro_run", false)) and bool(saved.get("intro_reward_eligible", false)) and bool(saved.get("won", false))

func _finish_intro_run() -> void:
	flight_started = true
	var checkpoint_saved := _save_run()
	intro_save_pending = false
	result_earned_cores = 0
	if sim.won and sim.intro_reward_eligible:
		if profile.intro_status == "available" and not checkpoint_saved:
			intro_save_pending = true
		elif profile.intro_status == "available":
			var settled := profile.duplicate(true)
			Progress.settle_first_flight(settled, sim)
			if services.write_atomic(Services.PROFILE, settled):
				# Keep the profile's identity for Game Center and platform services.
				profile.merge(settled, true)
			else:
				intro_save_pending = true
		if profile.intro_status == "complete":
			result_earned_cores = int(profile.get("intro_cores", 0))
	var first_view := mode != "intro_results"
	_show_intro_results()
	if first_view:
		sound.play("victory" if sim.won else "defeat", -8.0)

func _show_intro_results() -> void:
	mode = "intro_results"
	var view := _page(1.0, true, 460.0)
	var body: VBoxContainer = view.body
	_page_header(view.top, "First flight", "Harvester defeated" if sim.won else "Ship lost", _show_menu)
	var frame := PanelContainer.new()
	frame.clip_contents = true
	frame.add_theme_stylebox_override("panel", Kit.box(Color("091424"), Kit.LINE, 12, 1, 0, 0))
	body.add_child(frame)
	var ship_art := HangarBay.new()
	ship_art.style = "flight"
	ship_art.labels = false
	ship_art.ship_id = "vanguard"
	ship_art.custom_minimum_size.y = 118.0
	frame.add_child(ship_art)
	ship_art.set_process(not bool(profile.reduced))
	_tiles(body, [
		["Kills", str(sim.kills), Kit.TEXT],
		["Flight time", _clock(sim.time), Kit.TEXT],
		["Cores earned", str(maxi(0, result_earned_cores)), Kit.CYAN],
	])
	if intro_save_pending:
		Kit.label(body, "Your Cores could not be saved. Try saving again.", 16, Kit.MUTED, true)
		_focus(_ui_button(reading_footer, "Save reward", _finish_intro_run, "primary", 56, true))
		return
	if sim.won:
		var plating: int = int(profile.hangar.hull)
		var price := Catalog.price("hull", plating)
		if result_earned_cores > 0 and plating == 0:
			_info_card(body, "Hull plating", "Adds 10 starting hull to future campaign runs.")
			if int(profile.cores) >= price:
				_ui_button(body, "Buy Hull plating · %d Cores" % price, _buy_intro_plating, "secondary", 49)
		elif plating > 0:
			Kit.label(body, "Hull plating adds %d starting hull in the campaign." % (10 * plating), 16, Kit.MUTED, true)
		Kit.label(body, "The campaign spans four worlds.", 16, Kit.MUTED, true)
	else:
		Kit.label(body, "Keep Aegis ready for the beam, then use it just before impact.", 16, Kit.MUTED, true)
		_ui_button(view.bottom, "Try first flight again", _new_intro_run.bind(not sim.intro_reward_eligible), "secondary", 48)
	Kit.label(body, "First flights award no campaign achievements or unlocks.", 14, Kit.MUTED, true)
	_focus(_ui_button(reading_footer, "Launch campaign", _new_run, "primary", 56, true))

func _buy_intro_plating() -> void:
	if _buy_hangar_rank("hull"):
		_show_intro_results()

func _new_run() -> void:
	if _unsettled_intro():
		_resume_run()
		return
	if profile.intro_status == "available":
		profile.intro_status = "skipped"
		if not _save_profile():
			profile.intro_status = "available"
			_queue_toast("Could not start the campaign", "Your first flight is still available.")
			return
	banish_mode = false
	profile.runs += 1
	build_show_all = false
	result_earned_cores = -1
	result_awards.clear()
	result_rival_news.clear()
	_save_profile()
	sim = Simulation.new(61000 + int(profile.runs) * 7919, profile.hangar, profile.ship, profile.pilot, str(profile.get("difficulty", "normal")), str(profile.get("artifact", "standard")))
	sim.enable_expedition_rules()
	sim.enable_merchant()
	var returning: Dictionary = RivalCaptains.for_launch(profile, sim)
	if not returning.is_empty():
		sim.configure_rival(returning)
	var start_world: int = _chosen_start_world()
	if start_world > 1:
		sim.begin_at_world(start_world)
	_start_flight()

func _new_daily_run() -> void:
	if _unsettled_intro():
		_resume_run()
		return
	# One shared run for each UTC day: same seed, ship, pilot and the day's
	# generated Hangar for everyone. The player's own upgrades never apply.
	var setup: Dictionary = Progress.daily_setup(Progress.utc_day())
	banish_mode = false
	build_show_all = false
	result_earned_cores = -1
	result_awards.clear()
	result_rival_news.clear()
	profile.runs += 1
	var attempt: int = Progress.start_daily(profile, str(setup.day))
	_save_profile()
	sim = Simulation.new(int(setup.seed), Progress.daily_hangar(str(setup.day)), str(setup.ship), str(setup.pilot), str(setup.difficulty))
	sim.daily_day = str(setup.day)
	sim.daily_attempt = attempt
	_start_flight()

func _resume_run() -> void:
	banish_mode = false
	result_earned_cores = -1
	result_awards.clear()
	result_rival_news.clear()
	var state := _saved_flight()
	sim = Simulation.new()
	if not sim.restore(state):
		_new_run()
		return
	if sim.ended and (sim.secret_entered or sim.intro_run):
		_finish()
		return
	_start_flight(false)
	if sim.intro_aegis_prompt:
		_show_intro_aegis()
	elif sim.intro_boss_intro_pending:
		_show_boss_intro()
	elif mode == "playing" and not sim.pending_build_choices.is_empty():
		_show_build_choice()
	elif mode == "playing" and not sim.cards.is_empty():
		_show_cards()

## First heavy beam is an in-flight lesson, not another preflight paragraph.
## Simulation ticks stop while this callout is visible; nothing can hit the ship.
func _show_beam_tutorial() -> void:
	mode = "beam_tutorial"
	profile.beam_tutorial_seen = true
	_save_profile()
	_clear_overlay()
	var shade := ColorRect.new()
	shade.color = Color(0.005, 0.01, 0.025, 0.65)
	shade.size = get_viewport_rect().size
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Kit.box(Color("13283b"), Kit.AMBER, 16, 2, 16, 14))
	panel.position = Vector2(16.0, field.position.y + 22.0)
	panel.size = Vector2(get_viewport_rect().size.x - 32.0, 0.0)
	overlay.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)
	Kit.caps(column, "TIP  ·  BIG BEAM", Kit.AMBER, 14)
	Kit.label(column, "The red line shows where a big beam will hit. Destroy the marked enemy to stop it%s." % (", or use Aegis when it fires" if "aegis" in sim.active_slots else ""), 17, Kit.TEXT, true)
	_ui_button(column, "Got it · back to the fight", _resume_beam_tutorial, "primary", 48)
	var slot: int = sim.active_slots.find("aegis")
	if slot >= 0 and slot < Catalog.ACTIVE_SLOTS:
		var button: Button = ability_buttons[slot]
		var pointer := _label(overlay, "▼  AEGIS", 17, Kit.AMBER)
		pointer.position = Vector2(button.position.x, button.position.y - 28.0)
		pointer.size = Vector2(button.size.x + 6.0, 26)
		pointer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_haptic(60)

func _resume_beam_tutorial() -> void:
	if mode != "beam_tutorial":
		return
	mode = "playing"
	_clear_overlay()
	accumulator = 0.0

func _start_flight(announce: bool = true) -> void:
	mode = "playing"
	flight_started = true
	if sim.intro_run:
		game_speed = float(sim.intro_speed) if sim.intro_speed in speed_options else 1.0
	else:
		game_speed = float(profile.get("speed", 1.0))
		if game_speed not in speed_options:
			game_speed = 1.0
	intro_panel.hide()
	intro_cue.clear()
	save_clock = 0.0
	_layout()
	opening_last_phase = ""
	spectacle_audio_run = sim
	spectacle_audio_seen.clear()
	spectacle_audio_order.clear()
	spectacle_audio_wait = 0.0
	_clear_overlay()
	accumulator = 0.0
	last_hull = sim.hull
	last_boss_kills = sim.stage_clears
	boss_intro_stage = sim.stage if sim.boss_spawned else 0
	previous_warning = false
	previous_ready.clear()
	for id in sim.active_slots:
		previous_ready[id] = sim.cooldowns[id] <= 0
	last_sector = _sector_name(sim.time)
	banner_text = "Daily challenge · %s UTC · fixed loadout" % sim.daily_day if not sim.daily_day.is_empty() else ("ARTIFACT · " + str(Catalog.artifact(sim.artifact_id).name).to_upper() if sim.artifact_id != "standard" else "Upgrade your ship. Survive four worlds.")
	banner_clock = 0.0 if sim.intro_run else 5.0
	if announce or not sim.intro_run:
		sound.play("start")
	_save_run()
	if sim.rival_retire_pending:
		_show_rival_retired()
	elif sim.rival_intro_pending:
		_show_rival_intro()
	elif sim.secret_intro_pending:
		_show_archive_intro()
	elif sim.merchant_state == "signal":
		_show_merchant_signal()
	elif sim.merchant_state == "shop":
		_show_merchant_shop()
	elif sim.merchant_state == "confirm":
		_show_merchant_confirm()
	elif sim.merchant_state == "receipt":
		_show_merchant_receipt()
	elif sim.signal_status == "offer" and not sim.stage_transition_queued and not sim.ended and sim.time < sim.signal_until:
		_show_signal()
	elif sim.stage_transition_queued:
		match sim.intermission_step:
			"prototype": _show_prototypes()
			"route": _show_route_choice()
			"mutation": _show_mutation_lab()
			"ready": _finish_intermission()
			_: _show_stage_clear()

func _process(delta: float) -> void:
	if is_instance_valid(native_ad_banner):
		native_ad_banner.call("set_display_for_mode", mode)
	_advance_toast(delta)
	game_center.update(delta)
	visual_time += delta * (game_speed if mode == "playing" else 1.0)
	banner_clock = maxf(0.0, banner_clock - delta)
	if old_size != get_viewport_rect().size:
		_layout()
	if mode == "intro_clear":
		intro_clear_clock += delta
		if intro_clear_clock >= (0.3 if profile.reduced else 1.65):
			_finish()
	if mode == "boss_intro":
		boss_intro_clock += delta
		if boss_intro_clock >= (1.4 if profile.reduced else BOSS_INTRO_SECONDS):
			_dismiss_boss_intro()
	if mode in ["rival_intro", "rival_retired"]:
		rival_stinger_clock += delta
		if rival_stinger_clock >= 3.6:
			_dismiss_rival_stinger()
	if mode == "stage_clear":
		var before: float = stage_clear_clock
		stage_clear_clock += delta
		if stage_clear_button != null and stage_clear_clock >= 1.2:
			stage_clear_button.disabled = false
		if stage_clear_secondary != null and stage_clear_clock >= 1.2:
			stage_clear_secondary.disabled = false
		if (before < 0.55 and stage_clear_clock >= 0.55) or (before < 1.05 and stage_clear_clock >= 1.05):
			sound.play("explosion", -7.0)
	elif mode == "warp":
		warp_clock += delta
		if warp_clock >= 1.45:
			_complete_warp()
	if mode == "playing" and not sim.pending_build_choices.is_empty():
		_show_build_choice()
	if mode == "playing":
		accumulator += minf(delta, 0.2) * game_speed
		while accumulator >= Simulation.DT and mode == "playing":
			var previous_signal: String = sim.signal_status
			var previous_attack: String = sim.archive_attack
			sim.step()
			accumulator -= Simulation.DT
			if previous_signal != sim.signal_status:
				_archive_signal_feedback()
			if previous_attack.is_empty() and not sim.archive_attack.is_empty():
				sound.play("archive-boss", -10.0)
				_haptic(45)
			if not sim.intro_run:
				_opening_first30_beat()
			if sim.ended:
				if sim.intro_run and sim.won:
					_show_intro_clear()
				else:
					_finish()
			elif sim.intro_aegis_prompt:
				_show_intro_aegis()
			elif sim.boss_spawned and boss_intro_stage != sim.stage and not sim.secret_entered and not sim.stage_transition_queued:
				_show_boss_intro()
			elif sim.rival_retire_pending:
				_show_rival_retired()
			elif sim.rival_intro_pending:
				_show_rival_intro()
			elif sim.secret_intro_pending:
				_show_archive_intro()
			elif sim.merchant_state == "signal":
				_show_merchant_signal()
			elif sim.merchant_state == "receipt":
				_show_merchant_receipt()
			elif sim.stage_transition_queued:
				_show_stage_clear()
			elif not sim.cards.is_empty():
				_show_cards()
			elif not sim.intro_run and sim.stage == 1 and not bool(profile.get("beam_tutorial_seen", false)) and "aegis" in sim.active_slots and not sim.charges.is_empty():
				_show_beam_tutorial()
		var sector_now := _sector_name(sim.time)
		if not sim.intro_run and sector_now != last_sector:
			last_sector = sector_now
			banner_text = sector_now + "  /  NEW SECTOR"
			banner_clock = 3.5
		var warning: bool = not sim.charges.is_empty()
		if warning and not previous_warning:
			if mode != "intro_aegis":
				sound.play("warning")
			if sim.boss_spawned and not sim.intro_run:
				banner_text = "BOSS BEAM · %s · USE A DEFENSE" % sim.boss_attack_pattern.to_upper()
				banner_clock = 2.8
		previous_warning = warning
		for key in previous_ready:
			var ready: bool = sim.cooldowns[key] <= 0 and sim.upgrades[key] > 0
			if ready and not previous_ready[key]:
				sound.play("ready-" + key)
			previous_ready[key] = ready
		# Discrete hits give feedback immediately. Damage over time (corrosion)
		# lowers hull every tick, so it is pooled and rate-limited instead of
		# firing a sound and a vibration on every frame.
		hit_feedback_clock = maxf(0.0, hit_feedback_clock - delta)
		if sim.hull < last_hull:
			var lost: float = last_hull - sim.hull
			chip_damage += lost
			if hit_feedback_clock <= 0.0 and (lost >= 1.0 or chip_damage >= 6.0):
				sound.play("hit")
				_haptic(80 if lost >= 15.0 else 35)
				hit_feedback_clock = 0.12 if lost >= 1.0 else 0.6
				chip_damage = 0.0
		last_hull = sim.hull
		save_clock += delta
		if save_clock > (3.0 if sim.intro_run else 10.0):
			save_clock = 0
			_save_run()
	sound.update(sim, mode, delta)
	_play_spectacle_cues(delta)
	var shake := 0.0
	if mode == "playing" and not profile.reduced:
		for effect in sim.effects:
			if effect.kind == "hull-hit" or effect.get("boss", false):
				shake = maxf(shake, minf(4.0, effect.life * 9.0))
	world.position = Vector2(sin(visual_time * 79), cos(visual_time * 83)) * shake
	_update_hud()
	draft_guard = maxf(0.0, draft_guard - delta)
	# Combat chrome only shows while a flight is on screen; menus own the whole display.
	var in_flight: bool = mode in ["playing", "paused", "warp", "beam_tutorial", "intro_aegis", "intro_clear", "boss_intro", "rival_intro", "rival_retired", "merchant_signal", "merchant_shop", "merchant_confirm", "merchant_receipt"] or (mode == "settings" and sheet_base == "paused")
	for control in [hud, status, hull_meter, shield_meter, hull_caption, shield_caption, build_button, pause_button, speed_button]:
		control.visible = in_flight
	for button in ability_buttons.values():
		button.visible = in_flight
	var lesson := mode == "intro_aegis"
	for button in [speed_button, build_button, pause_button]:
		button.disabled = lesson or mode == "intro_clear"
	speed_button.text = _speed_label()
	_update_intro_hud()
	queue_redraw()
	world.queue_redraw()

# Sound and haptics belong to rare, meaningful events, not every projectile
# or button press. Each effect can be heard once and is rate-limited in
# real seconds, so 3x does not turn mutation procs into a cacophony.
func _play_spectacle_cues(delta: float) -> void:
	if spectacle_audio_run != sim:
		spectacle_audio_run = sim
		spectacle_audio_seen.clear()
		spectacle_audio_order.clear()
		spectacle_audio_wait = 0.0
	spectacle_audio_wait = maxf(0.0, spectacle_audio_wait - delta)
	if mode not in ["playing", "stage_clear", "warp"]:
		return
	var priority := 0
	for effect in sim.effects:
		var kind: String = str(effect.kind)
		if kind not in ["mutation-installed", "boss-module-break", "boss-phase-break", "engine-online"]:
			continue
		var key := "%s:%d:%d:%d" % [kind, int(effect.born), roundi(float(effect.p.x)), roundi(float(effect.p.y))]
		if spectacle_audio_seen.has(key):
			continue
		spectacle_audio_seen[key] = true
		spectacle_audio_order.append(key)
		if spectacle_audio_order.size() > 96:
			spectacle_audio_seen.erase(spectacle_audio_order.pop_front())
		priority = maxi(priority, 3 if kind == "boss-phase-break" else (2 if kind in ["mutation-installed", "engine-online"] else 1))
	if priority == 0 or spectacle_audio_wait > 0.0:
		return
	if priority == 3:
		sound.play("boss-explosion", -11.0)
		_haptic(55)
		spectacle_audio_wait = 0.75
	elif priority == 2:
		sound.play("archive-release", -18.0)
		_haptic(40)
		spectacle_audio_wait = 0.80
	else:
		sound.play("explosion", -17.0)
		_haptic(30)
		spectacle_audio_wait = 0.40

func _update_hud() -> void:
	CombatHud.refresh(self)
	_update_archive_hud()

func _archive_signal_feedback() -> void:
	if sim.signal_status == "offer":
		banner_text = "HIDDEN SIGNAL FOUND"
		banner_clock = 4.0
		sound.play("archive-signal")
	elif sim.signal_status == "received":
		banner_text = "%d / %d SIGNALS FOUND" % [sim.signal_count, HiddenSector.REQUIRED_SIGNALS]
		banner_clock = 4.0
		_save_run()
		sound.play("archive-release", -10.0)
	elif sim.signal_status == "missed":
		banner_text = "SIGNAL LOST"
		banner_clock = 3.0
		_save_run()

func _activate_slot(slot: int) -> void:
	if slot >= 0 and slot < sim.active_slots.size():
		_activate(str(sim.active_slots[slot]))

func _activate(id: String) -> void:
	var old_signal: String = sim.signal_status
	var old_attack: String = sim.archive_attack
	var lesson := mode == "intro_aegis" and id == "aegis"
	if (mode == "playing" or lesson) and sim.activate(id):
		if lesson:
			_continue_intro_aegis()
		elif sim.intro_run:
			_save_run()
		_haptic(38)
		if old_signal != sim.signal_status:
			_archive_signal_feedback()
		if not old_attack.is_empty() and sim.archive_attack.is_empty():
			_save_run()
			sound.play("archive-release", -12.0)
		sound.play_ability(id)
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

func _continue_endless() -> void:
	if not sim.daily_day.is_empty():
		return # Daily scores end at World 4; no endless farming.
	if mode == "archive_reveal" and sim.enable_endless():
		_save_run()
		mode = "warp"
		warp_clock = 0.0
		_clear_overlay()
		sound.play("start", -7.0)
		return
	if mode != "stage_clear" or stage_clear_clock < 1.2 or not sim.enable_endless():
		return
	_save_run()
	_begin_warp()

func _claim_endless() -> void:
	if mode != "stage_clear" or stage_clear_clock < 1.2 or not sim.claim_endless():
		return
	_finish()

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
	if sim.intermission_step == "route":
		_show_route_choice()
	else:
		_show_prototypes()

func _choose_prototype(index: int) -> void:
	if mode != "prototype" or not sim.choose_prototype(index):
		return
	sound.play("card")
	_save_run()
	_next_intermission_step()

func _skip_prototype() -> void:
	if mode != "prototype" or not sim.skip_prototype():
		return
	sound.play("card")
	_save_run()
	_next_intermission_step()

# When a flight starts at a later world, each skipped world has its own
# Prototype pick before the one route choice.
func _next_intermission_step() -> void:
	if sim.intermission_step == "prototype":
		_show_prototypes()
	else:
		_show_route_choice()

func _choose_route(id: String) -> void:
	if mode != "route" or not sim.choose_route(id):
		return
	if sim.intermission_step == "mutation":
		_show_mutation_lab()
	else:
		_finish_intermission()

func _finish_intermission() -> void:
	if not sim.advance_stage():
		_show_route_choice()
		return
	_finish_intermission_presentation()

func _finish_intermission_presentation() -> void:
	mode = "playing"
	_clear_overlay()
	accumulator = 0.0
	last_sector = _sector_name(sim.time)
	banner_text = "WORLD %d  ·  %s" % [sim.stage, sim.stage_name()]
	banner_clock = 5.0
	sound.play("start")
	_save_run()
	if not sim.pending_build_choices.is_empty():
		_show_build_choice()
	elif sim.pending_levels > 0:
		sim._offer_cards()
		_show_cards()

func _finish() -> void:
	if sim.intro_run:
		_finish_intro_run()
		return
	mode = "results"
	if sim.secret_entered:
		services.write_atomic(Services.RUN, sim.snapshot())
	# A crash between the rival's defeat and the result panel must still
	# retire their dossier exactly once.
	if sim.rival_outcome == "retired":
		RivalCaptains.retire(profile, sim)
	# Both ordinary and daily flights settle exactly once, even after a
	# crash/repeated callback. Only a first daily completion pays Cores.
	var settlement: Dictionary = Progress.settle(profile, sim)
	result_earned_cores = int(settlement.earned)
	result_awards = settlement.awarded
	result_daily_score = int(settlement.score)
	result_daily_best = int(settlement.best_score)
	result_new_best = bool(settlement.new_best)
	result_rival_news = settlement.get("rival_news", {})
	result_unlocked = settlement.get("unlocked", [])
	if _save_profile():
		services.delete_run()
	_show_results()
	# New achievements are listed on the results screen itself; a popup on
	# top covered its "What took you down" header.
	if not result_awards.is_empty():
		sound.play("card")
	game_center.sync()

func _hangar_tab(group: String) -> void:
	hangar_category = group
	_show_hangar()

func _purchase(id: String) -> void:
	if _buy_hangar_rank(id):
		_show_hangar()

func _buy_hangar_rank(id: String) -> bool:
	var entry := Catalog.entry(id)
	if entry.is_empty():
		return false
	var rank: int = int(profile.hangar.get(id, 0))
	var price := Catalog.price(id, rank)
	if profile.cores >= price and rank < int(entry.max):
		profile.cores -= price
		profile.hangar[id] = rank + 1
		var paid: Dictionary = profile.get("hangar_paid", {})
		paid[id] = int(paid.get(id, 0)) + price
		profile.hangar_paid = paid
		if not _save_profile():
			profile.cores += price
			profile.hangar[id] = rank
			paid[id] -= price
			_queue_toast("Purchase could not be saved", "Your Cores are still available.")
			return false
		sound.play("card")
		return true
	return false

func _respec() -> void:
	profile.cores += Catalog.refund(profile.hangar, profile.get("hangar_paid", {}))
	profile.hangar = Catalog.defaults()
	profile.hangar_paid = {}
	_save_profile()
	_show_hangar()

## Windows, Linux (including Steam Deck) and macOS own a resizable window.
func _desktop_window() -> bool:
	return OS.has_feature("pc") and DisplayServer.get_name() != "headless"

func _toggle_fullscreen() -> void:
	profile.fullscreen = not bool(profile.get("fullscreen", false))
	_apply_window_mode()
	_save_profile()
	if mode == "settings":
		_refresh_panel()

func _apply_window_mode() -> void:
	if not _desktop_window():
		return
	if bool(profile.get("fullscreen", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_fit_window_to_screen()

## The default 1280x900 window is taller than a Steam Deck (800 px) or a
## 1366x768 laptop. Shrink it to the screen's usable area and center it.
func _fit_window_to_screen() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	if usable.size.x <= 0 or usable.size.y <= 0:
		return
	var size := DisplayServer.window_get_size()
	# Leave room for the title bar and window borders.
	var limit := Vector2i(usable.size.x - 16, usable.size.y - 48)
	if size.x <= limit.x and size.y <= limit.y:
		return
	var fitted := Vector2i(mini(size.x, limit.x), mini(size.y, limit.y))
	DisplayServer.window_set_size(fitted)
	DisplayServer.window_set_position(usable.position + (usable.size - fitted) / 2)

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

func _save_profile() -> bool:
	if services.write_atomic(Services.PROFILE, profile):
		return true
	banner_text = "Save unavailable on this device"
	banner_clock = 5.0
	return false

func _save_run() -> bool:
	if flight_started and sim != null and (not sim.ended or sim.intro_run):
		if services.write_atomic(Services.RUN, sim.snapshot()):
			return true
		banner_text = "Run could not be saved"
		banner_clock = 5.0
	return false

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if mode == "playing":
			_show_pause()
		elif flight_started and sim.intro_run:
			_save_run()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		# Retry any Game Center items that failed while the app was away.
		game_center.sync()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android Back pauses a flight or steps back a screen, like Escape.
		# Only the title screen exits, and it saves first.
		if not InputRouter.back(self) and mode == "menu":
			_save_run()
			get_tree().quit()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_run()
		get_tree().quit()

func _input(event: InputEvent) -> void:
	InputRouter.key(self, event)

func _unhandled_input(event: InputEvent) -> void:
	InputRouter.gamepad(self, event)

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

func _speed_label() -> String:
	return str(int(game_speed)) + "×" if is_equal_approx(game_speed, float(int(game_speed))) else str(game_speed) + "×"

func _cycle_speed() -> void:
	var index := speed_options.find(game_speed)
	game_speed = float(speed_options[(index + 1) % speed_options.size()])
	if sim.intro_run:
		sim.intro_speed = game_speed
		_save_run()
	else:
		profile.speed = game_speed
		_save_profile()
	speed_button.text = _speed_label()

func _toggle_build_details() -> void:
	build_show_all = not build_show_all
	_show_build()

func _build_to_menu() -> void:
	if mode != "build":
		return
	_save_run()
	_show_menu()


func _loadout_tab(value: String) -> void:
	if value not in ["Ships", "Pilots", "Artifacts"]:
		return
	# Switching to a shorter tab must begin at its first option, not inherit
	# the scroll offset of an earlier long Ships or Pilots catalog.
	if value != loadout_tab and is_instance_valid(reading_scroll):
		reading_scroll.scroll_vertical = 0
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
		if not bool(item.get("buy_only", false)) or profile.cores < int(item.cost):
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
		draw_string(ThemeDB.fallback_font, Vector2(32, 58), "Star/Run", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, CYAN)
		draw_string(ThemeDB.fallback_font, Vector2(screen.x - 220, 56), "FOUR STAGES  /  " + str(ProjectSettings.get_setting("application/config/version")), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
	draw_rect(field.grow(1), Color("29414b"), false, 1)
