extends RefCounted
## Keyboard and controller routing stays independent of menu and HUD rendering.
static func key(host, event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_ESCAPE, KEY_P] and host.mode in ["playing", "paused", "build"]:
		host._toggle_pause()
		host.get_viewport().set_input_as_handled()
	elif host.mode == "stage_clear" and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		if host.stage_clear_clock >= 1.2:
			host._begin_warp()
		host.get_viewport().set_input_as_handled()
	elif host.mode == "playing":
		if event.keycode == KEY_B:
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
	elif event.keycode == KEY_ESCAPE and host.mode in ["settings", "briefing", "abandon"]:
		host._close_sheet()
		host.get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and host.mode in ["hangar", "loadout"]:
		if host.mode == "loadout":
			host._loadout_back()
		else:
			host._show_menu()
		host.get_viewport().set_input_as_handled()

static func gamepad(host, event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START:
			host._toggle_pause()
		elif host.mode == "playing":
			var bindings := [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_B]
			var index: int = bindings.find(event.button_index)
			if index >= 0:
				host._activate_slot(index)


