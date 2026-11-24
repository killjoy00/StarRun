extends RefCounted
## Combat chrome presenter; menu navigation stays in main.gd.
## Headless UI and screenshot tests exercise this with the real main scene.
const FirstFlight = preload("res://scripts/first_flight.gd")
const Catalog = preload("res://scripts/catalog.gd")

static func _short_ability_name(sim, id: String) -> String:
	var names := {"overdrive":"DRIVE", "capacitor":"CHARGE", "deflector":"DEFLECT", "barrage":"ROCKETS", "barrier":"BARRIER", "salvage":"SALVAGE", "overload":"OVERLOAD", "repair_matrix":"REPAIR", "nova_aegis":"NOVA GRD", "railstorm":"RAILSTORM", "stasis_lock":"TIME LOCK", "missile_grid":"MISSILES", "scrap_converter":"SCRAP", "prism_focus":"PRISM", "reflective_wall":"REFLECT", "ghost_signal":"GHOST", "reactor_surge":"SURGE", "strike":"RAIL", "reboot":"REBOOT", "siphon":"SIPHON", "focus":"FOCUS", "flak":"FLAK", "chrono":"CHRONO", "jammer":"JAMMER", "decoy":"DECOY", "aegis":"AEGIS", "mend":"REPAIR", "emp":"EMP", "nova":"NOVA", "prism":"PRISM", "wing_drones":"WING", "guard_drones":"GUARD", "ion_mine":"MINE", "storm_carrier":"CARRIER"}
	return str(names.get(id, sim.content.abilities[id].name.to_upper()))

## Shrink a slot label (16 pt down to 11 pt) until the whole word fits.
## Names used to be cut to 7 letters on narrow phones ("OVERLOA").
static func fit_label(label: Label, base_size: int = 16, floor_size: int = 11) -> void:
	var font: Font = label.get_theme_font("font")
	var limit: float = label.size.x
	var font_size := base_size
	while font_size > floor_size and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > limit:
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)

static func refresh(host) -> void:
	var sim = host.sim
	host.hud.text = "W%d  LV%02d" % [sim.stage, sim.level] if host._compact_ui() or host.hud.size.x < 155.0 else "WORLD %d  ·  LV %02d" % [sim.stage, sim.level]
	if sim.intro_run:
		host.hud.text = "FIRST FLIGHT"
		fit_label(host.hud, 18, 11)
	host.hull_meter.value = clampf(sim.hull / maxf(1.0, sim.max_hull) * 100.0, 0.0, 100.0)
	host.shield_meter.value = clampf(sim.shield / maxf(1.0, sim.max_shield) * 100.0, 0.0, 100.0)
	host.hull_caption.text = "HULL  %d/%d" % [ceili(sim.hull), ceili(sim.max_hull)]
	host.shield_caption.text = "SHIELD  %d/%d" % [ceili(sim.shield), ceili(sim.max_shield)]
	var seconds := int(sim.time - sim.stage_start)
	if sim.intro_run:
		host.status.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	else:
		host.hud.add_theme_font_size_override("font_size", 18)
		host.status.text = "%s  %02d:%02d" % [sim.difficulty.left(1).to_upper() if host.status.size.x < 110.0 else sim.difficulty.to_upper(), seconds / 60, seconds % 60]
	for i in range(Catalog.ACTIVE_SLOTS):
		var button: Button = host.ability_buttons[i]
		var occupied: bool = i < sim.active_slots.size()
		var id: String = str(sim.active_slots[i]) if occupied else ""
		var cooldown: float = float(sim.cooldowns.get(id, 0.0))
		var learned: bool = occupied and int(sim.upgrades.get(id, 0)) > 0
		var title: String = _short_ability_name(sim, id) if occupied and (host._compact_ui() or button.size.x < 175.0) else (sim.content.abilities[id].name.to_upper() if occupied else "EMPTY")
		var status_text := ("%.0fs" % ceilf(cooldown) if cooldown > 0 else "READY") if learned and host._compact_ui() else (("%.1fs" % cooldown if cooldown > 0 else "READY") if learned else "OPEN")
		# Icons and the two lines of text occupy separate bounds on every screen.
		button.text = ""
		var name_label: Label = button.get_node("AbilityName")
		var status_label: Label = button.get_node("AbilityStatus")
		name_label.text = title if occupied else "EMPTY"
		fit_label(name_label)
		status_label.text = status_text
		name_label.add_theme_color_override("font_color", Color("eef7ff") if learned else Color("778ba0"))
		status_label.add_theme_color_override("font_color", Color("66f5df") if learned and cooldown <= 0.0 else Color("b4c6d8") if learned else Color("6c8097"))
		var can_cast: bool = host.mode == "playing" or (host.mode == "intro_aegis" and id == "aegis")
		button.disabled = not can_cast or cooldown > 0 or not learned
		# Make the timing legible without implying an unready ability can cast.
		var counter_ready: bool = not button.disabled and host.mode == "playing" and host._archive_counter_warning()
		if counter_ready:
			var precise: bool = sim.archive_precise_counter_window()
			status_label.text = "CAST NOW" if precise else "HOLD"
			fit_label(status_label, 12, 9)
			status_label.add_theme_color_override("font_color", Color("80f5cd") if precise else Color("ffc078"))
			var pulse: float = 1.0 if bool(host.profile.get("reduced",false)) else 0.78 + 0.22 * sin(host.visual_time * 8.0)
			button.modulate = Color(1.0,1.0,1.0,1.0).lerp(Color("a2ffe1") if precise else Color("ffd0a0"), pulse)
		else:
			button.modulate = Color.WHITE
			fit_label(status_label, 12, 9)
		button.tooltip_text = (sim.content.abilities[id].name + (" (combined ability)" if not sim.fusion_spec(id).is_empty() else "") + "  |  Ready" if cooldown <= 0.0 else sim.content.abilities[id].name + "  |  %.1fs" % cooldown) if learned else "Empty slot"
		var cooldown_bar: ProgressBar = host.cooldown_meters[i]
		cooldown_bar.visible = learned and cooldown > 0.0
		cooldown_bar.value = clampf(100.0 * (1.0 - cooldown / maxf(1.0, float(sim.cooldown_totals.get(id, sim.content.abilities[id].cooldown)))) if occupied else 0.0, 0.0, 100.0)
		var badge: Control = button.get_child(0)
		badge.visible = occupied
		if badge.get("icon_id") != id:
			badge.set("icon_id", id)
			badge.queue_redraw()
		if occupied and not host.previous_ready.has(id):
			host.previous_ready[id] = true
	host.build_label.text = "%s / %s\nAUTOPILOT ONLINE\n\n" % [Catalog.ship(sim.ship_id).name.to_upper(), Catalog.pilot(sim.pilot_id).name.to_upper()]
	for tag in ["WEAPON", "ABILITY", "SYSTEM", "MUTATION"]:
		host.build_label.text += tag + "S\n"
		for card in sim.content.cards:
			if card.tag == tag and sim.upgrades[card.id] > 0 and sim.fused_into(str(card.id)).is_empty():
				host.build_label.text += "%s  %d/%d\n" % [card.name, sim.upgrades[card.id], card.max]
		host.build_label.text += "\n"
	host.report_label.text = "F L I G H T   D A T A\n\n%s\n\n%s\n\nTHREAT KEY\n\n●  Chaff · armor / shield\n◇  Missile · seekers / Nova\n┃  Heavy · Aegis / interrupt\n\nFLIGHT PLAN\n\nDotted path: next 2 seconds\nCoral lane: incoming beam\n\nKills             %d\nBeams cancelled   %d\nDamage blocked    %d\n\nSEED %d" % [host._sector_name(sim.time), sim.boss_name().to_upper() + " ENGAGED" if sim.boss_spawned else ("Custodian at 01:45" if sim.secret_entered else ("Harvester at " + host._clock(FirstFlight.boss_at(sim)) if sim.intro_run else "Boss at 04:00")), sim.kills, sim.beams_cancelled, sim.prevented, sim.seed_value]
