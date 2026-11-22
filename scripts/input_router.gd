extends RefCounted
## Keyboard and controller routing stays independent of menu and HUD rendering.
static func key(host, event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	# Desktop fullscreen works on every screen: F11, or Alt+Enter.
	if host._desktop_window() and (event.keycode == KEY_F11 or (event.keycode in [KEY_ENTER, KEY_KP_ENTER] and event.alt_pressed)):
		host._toggle_fullscreen()
		host.get_viewport().set_input_as_handled()
		return
	if host.mode == "boss_intro" and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
		host._skip_boss_intro()
		host.get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and back(host):
		host.get_viewport().set_input_as_handled()
	elif event.keycode == KEY_P and host.mode in ["playing", "paused", "build"]:
		host._toggle_pause()
		host.get_viewport().set_input_as_handled()
	elif host.mode == "stage_clear" and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		if host.stage_clear_clock >= 1.2:
			host._begin_warp()
		host.get_viewport().set_input_as_handled()
	elif host.mode == "playing":
		if event.keycode == KEY_R and host.sim.signal_status == "offer":
			host._show_signal()
			host.get_viewport().set_input_as_handled()
		elif event.keycode == KEY_B:
			host._show_build()
			host.get_viewport().set_input_as_handled()
		elif event.keycode == KEY_TAB:
			host._cycle_speed()
			host.get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE or (event.keycode >= KEY_1 and event.keycode <= KEY_4):
			host._activate_slot(0 if event.keycode == KEY_SPACE else event.keycode - KEY_1)
			host.get_viewport().set_input_as_handled()
	elif host.mode == "cards" and event.keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
		host._choose(event.keycode - KEY_1)
		host.get_viewport().set_input_as_handled()

## Shared "go back" for Escape and the Android Back button/gesture.
## Returns true when the current screen consumed it.
static func back(host) -> bool:
	if host.mode in ["playing", "paused", "build"]:
		host._toggle_pause()
	elif host.mode in ["settings", "briefing", "abandon"]:
		host._close_sheet()
	elif host.mode == "loadout":
		host._loadout_back()
	elif host.mode == "hangar":
		host._show_menu()
	else:
		return false
	return true

static func gamepad(host, event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START:
			host._toggle_pause()
		elif host.mode == "playing" and event.button_index == JOY_BUTTON_DPAD_UP and host.sim.signal_status == "offer":
			host._show_signal()
		elif host.mode == "playing":
			var bindings := [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_B]
			var index: int = bindings.find(event.button_index)
			if index >= 0:
				host._activate_slot(index)


