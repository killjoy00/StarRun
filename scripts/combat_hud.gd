extends RefCounted
## Combat chrome presenter; menu navigation stays in main.gd.
## Headless UI and screenshot tests exercise this with the real main scene.
const Catalog = preload("res://scripts/catalog.gd")

static func _short_ability_name(sim, id: String) -> String:
	var names := {"overdrive":"DRIVE", "capacitor":"CHARGE", "deflector":"DEFLECT", "barrage":"ROCKETS", "barrier":"BARRIER", "salvage":"SALVAGE", "overload":"OVERLOAD", "repair_matrix":"REPAIR", "nova_aegis":"NOVA GRD", "railstorm":"RAILSTORM", "stasis_lock":"TIME LOCK", "missile_grid":"MISSILES", "scrap_converter":"SCRAP", "prism_focus":"PRISM", "reflective_wall":"REFLECT", "ghost_signal":"GHOST", "reactor_surge":"SURGE", "strike":"RAIL", "reboot":"REBOOT", "siphon":"SIPHON", "focus":"FOCUS", "flak":"FLAK", "chrono":"CHRONO", "jammer":"JAMMER", "decoy":"DECOY", "aegis":"AEGIS", "mend":"REPAIR", "emp":"EMP", "nova":"NOVA", "prism":"PRISM"}
	return str(names.get(id, sim.content.abilities[id].name.to_upper())).left(9)

static func refresh(host) -> void:
	var sim = host.sim
	host.hud.text = "W%d  ·  LV %02d" % [sim.stage, sim.level] if sim.endless_enabled else "WORLD %d  ·  LV %02d" % [sim.stage, sim.level]
	host.hull_meter.value = clampf(sim.hull / maxf(1.0, sim.max_hull) * 100.0, 0.0, 100.0)
	host.shield_meter.value = clampf(sim.shield / maxf(1.0, sim.max_shield) * 100.0, 0.0, 100.0)
	host.hull_caption.text = "HULL  %d/%d" % [ceili(sim.hull), ceili(sim.max_hull)]
	host.shield_caption.text = "SHIELD  %d/%d" % [ceili(sim.shield), ceili(sim.max_shield)]
	var seconds := int(sim.time - sim.stage_start)
	host.status.text = "%s  %02d:%02d" % [sim.difficulty.to_upper(), seconds / 60, seconds % 60]
	for i in range(Catalog.ACTIVE_SLOTS):
		var button: Button = host.ability_buttons[i]
		var occupied: bool = i < sim.active_slots.size()
		var id: String = str(sim.active_slots[i]) if occupied else ""
		var cooldown: float = float(sim.cooldowns.get(id, 0.0))
		var learned: bool = occupied and int(sim.upgrades.get(id, 0)) > 0
		var title: String = _short_ability_name(sim, id) if occupied and host._compact_ui() else (sim.content.abilities[id].name.to_upper() if occupied else "EMPTY")
		var status_text := ("%.0fs" % ceilf(cooldown) if cooldown > 0 else "READY") if learned and host._compact_ui() else (("%.1fs" % cooldown if cooldown > 0 else "READY") if learned else ("FREE" if host._compact_ui() else "DRAFT AN ABILITY"))
		button.text = ("%s\n%s" % [title, status_text]) if host._compact_ui() else ("%d  %s\n%s" % [i + 1, title, status_text])
		button.disabled = host.mode != "playing" or cooldown > 0 or not learned
		button.tooltip_text = (sim.content.abilities[id].name + (" (combined ability)" if not sim.fusion_spec(id).is_empty() else "") + "  |  Ready" if cooldown <= 0.0 else sim.content.abilities[id].name + "  |  %.1fs" % cooldown) if learned else "Empty slot"
		var cooldown_bar: ProgressBar = host.cooldown_meters[i]
		cooldown_bar.value = clampf(100.0 * (1.0 - cooldown / maxf(1.0, float(sim.cooldown_totals.get(id, sim.content.abilities[id].cooldown)))) if occupied else 0.0, 0.0, 100.0)
		var badge: Control = button.get_child(0)
		if badge.get("icon_id") != id:
			badge.set("icon_id", id)
			badge.queue_redraw()
		if occupied and not host.previous_ready.has(id):
			host.previous_ready[id] = true
	host.build_label.text = "%s / %s\nAUTOPILOT ONLINE\n\n" % [Catalog.ship(sim.ship_id).name.to_upper(), Catalog.pilot(sim.pilot_id).name.to_upper()]
	for tag in ["WEAPON", "ABILITY", "SYSTEM"]:
		host.build_label.text += tag + "S\n"
		for card in sim.content.cards:
			if card.tag == tag and sim.upgrades[card.id] > 0 and sim.fused_into(str(card.id)).is_empty():
				host.build_label.text += "%s  %d/%d\n" % [card.name, sim.upgrades[card.id], card.max]
		host.build_label.text += "\n"
	host.report_label.text = "F L I G H T   D A T A\n\n%s\n\n%s\n\nTHREAT KEY\n\n●  Chaff · armor / shield\n◇  Missile · seekers / Nova\n┃  Heavy · Aegis / interrupt\n\nFLIGHT PLAN\n\nDotted path: next 2 seconds\nCoral lane: incoming beam\n\nKills             %d\nBeams cancelled   %d\nDamage blocked    %d\n\nSEED %d" % [host._sector_name(sim.time), sim.boss_name().to_upper() + " ENGAGED" if sim.boss_spawned else "Boss at 04:00", sim.kills, sim.beams_cancelled, sim.prevented, sim.seed_value]
