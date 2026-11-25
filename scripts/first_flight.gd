extends RefCounted
## Authored encounter schedule. All units, charges and cards use the normal engine.
const SEED := 30417
const REWARD := 15
const BOSS_AT := 68.0
const EJECT_AFTER := 2.8
const IMPACT_AT := 0.48
const CRASH_SECONDS := 2.1
const DRAFT_AT := [23.0, 48.0]
const LEGACY_BOSS_AT := 145.0
const LEGACY_DRAFT_AT := [35.0, 82.0]
const LESSON_WAVES := [13.5, 29.0]
const CAMPAIGN_WINGS := [
	[13.5, "sniper"], [24.0, 0], [30.5, "sniper"],
	[39.0, "shieldguard"], [49.0, 1], [57.0, "gunship"],
]
const BOSS_ENTRANCE_DELAY := 0.8
const UPGRADE_WINGS := {"arc": "missile_bomber", "lance": "shieldguard", "seeker": "gunship"}
const SECTOR := {
	"id": "debris_belt", "name": "FIRST FLIGHT", "boss": "boss",
	"boss_name": "Harvester", "boss_hp": 1490.0, "health_scale": 1.0,
	"damage_scale": 0.52, "spawn_scale": 1.0,
}
# [seconds, [enemy, x, hp, first volley] ...]. Two slower snipers leave
# an Aegis window even when the first cast was early or the first beam missed.
const LEGACY_WAVES := [
	[0.12, ["drone", 250, 14, 3.0], ["drone", 340, 19, 3.4]],
	[4.2, ["interceptor", 140, 30, 2.2], ["drone", 315, 24, 2.7]],
	[8.8, ["gunship", 288, 52, 1.5]],
	[13.5, ["sniper", 268, 185, 2.8]],
	[20.0, ["drone", 165, 36, 1.3], ["interceptor", 360, 35, 1.8]],
	[29.0, ["sniper", 342, 170, 2.4]],
	[36.0, ["drone", 159, 37, 1.0], ["gunship", 253, 79, 1.5], ["drone", 349, 37, 1.1]],
	[42.0, ["interceptor", 126, 58, 1.4], ["drone", 265, 38, 1.6], ["interceptor", 413, 58, 1.8]],
	[48.5, ["gunship", 276, 91, 1.3], ["missile_bomber", 375, 92, 1.8]],
	[55.0, ["sniper", 170, 170, 2.3], ["drone", 270, 48, 1.1], ["interceptor", 376, 59, 1.2]],
	[62.0, ["shieldguard", 266, 128, 1.8], ["rusher", 113, 68, 1.3], ["rusher", 420, 68, 1.5]],
	[70.0, ["gunship", 174, 102, 1.0], ["missile_bomber", 367, 119, 1.8]],
	[76.0, ["sniper", 268, 185, 2.1], ["interceptor", 375, 62, 1.2]],
	[83.4, ["gunship", 270, 110, 1.2], ["drone", 180, 57, 1.0], ["drone", 360, 57, 1.4]],
	[90.0, ["rusher", 157, 72, 1.0], ["ion_frigate", 270, 124, 1.5], ["rusher", 387, 72, 1.4]],
	[97.0, ["sniper", 240, 210, 2.5], ["gunship", 367, 110, 1.8]],
	[104.0, ["missile_bomber", 155, 135, 1.3], ["shieldguard", 258, 140, 1.7], ["missile_bomber", 387, 135, 1.5]],
	[111.0, ["interceptor", 125, 65, 1.1], ["ion_frigate", 270, 145, 1.4], ["interceptor", 415, 65, 1.8]],
	[119.0, ["gunship", 155, 120, 1.1], ["sniper", 270, 197, 2.1], ["gunship", 385, 120, 1.4]],
	[126.0, ["drone", 146, 50, 1.1], ["ion_frigate", 270, 120, 1.8], ["drone", 394, 50, 1.3]],
	[133.0, ["gunship", 185, 100, 1.4], ["shieldguard", 355, 116, 1.8]],
]

# Each group enters in two or three rows. The sniper waves leave a clean
# central beam lane, with the rest of the pressure coming from the flanks.
const WAVES := [
	[0.12, ["drone", 115, 24, 3.6], ["drone", 268, 24, 3.2], ["drone", 420, 24, 3.6],
		["drone", 185, 25, 3.9], ["drone", 352, 25, 3.9]],
	[4.2, ["interceptor", 125, 32, 2.9], ["interceptor", 400, 32, 2.9],
		["drone", 188, 29, 3.6], ["drone", 270, 29, 3.2], ["drone", 350, 29, 3.6]],
	[8.8, ["gunship", 268, 66, 2.5], ["drone", 103, 28, 3.2], ["drone", 430, 28, 3.2],
		["interceptor", 181, 35, 3.0], ["interceptor", 359, 35, 3.0]],
	[13.5, ["sniper", 268, 200, 2.8], ["drone", 95, 32, 3.4], ["drone", 443, 32, 3.4],
		["interceptor", 151, 37, 3.5], ["interceptor", 390, 37, 3.5]],
	[20.0, ["rusher", 115, 30, 3.2], ["rusher", 425, 30, 3.2],
		["drone", 170, 33, 3.6], ["drone", 370, 33, 3.6]],
	[24.0, 0], # Bring in targets for the first weapon the player picked.
	[29.0, ["sniper", 342, 245, 2.6], ["drone", 95, 33, 3.5], ["drone", 444, 33, 3.5],
		["interceptor", 173, 38, 3.2], ["interceptor", 423, 38, 3.2]],
	[35.0, ["gunship", 269, 87, 2.5], ["interceptor", 119, 40, 3.1], ["interceptor", 420, 40, 3.1],
		["rusher", 95, 37, 3.3], ["rusher", 438, 37, 3.3], ["drone", 268, 42, 3.7]],
	[42.0, ["missile_bomber", 177, 79, 2.2], ["gunship", 363, 74, 2.7],
		["drone", 126, 35, 3.4], ["drone", 270, 35, 3.2], ["drone", 414, 35, 3.4]],
	[49.0, 1],
	[55.5, ["shieldguard", 270, 108, 2.4], ["interceptor", 110, 44, 2.8], ["interceptor", 430, 44, 2.8],
		["rusher", 165, 38, 3.5], ["rusher", 375, 38, 3.5], ["drone", 270, 44, 3.7]],
	[62.0, ["gunship", 163, 80, 2.6], ["gunship", 377, 80, 2.6], ["interceptor", 95, 45, 2.8],
		["interceptor", 444, 45, 2.8], ["drone", 221, 37, 3.5], ["drone", 319, 37, 3.5]],
]
# These flank groups overlap the main waves. Fixed ticks keep a resumed
# flight from launching a group twice or changing the saved wave index.
const REINFORCEMENTS := {
	2: [["rusher", 73, 30, 3.5], ["rusher", 463, 30, 3.5]],
	33: [["interceptor", 93, 40, 3.6], ["drone", 170, 42, 3.7], ["drone", 370, 42, 3.7], ["interceptor", 443, 40, 3.6]],
	38: [["drone", 160, 42, 3.4], ["drone", 270, 42, 3.2], ["drone", 380, 42, 3.4]],
	40: [["rusher", 135, 37, 3.5], ["drone", 270, 44, 3.8], ["rusher", 405, 37, 3.5]],
	45: [["interceptor", 105, 45, 3.3], ["gunship", 270, 74, 2.8], ["interceptor", 435, 45, 3.3]],
	47: [["drone", 150, 43, 3.8], ["drone", 230, 43, 3.7], ["drone", 310, 43, 3.7], ["drone", 390, 43, 3.8]],
	52: [["rusher", 95, 41, 3.5], ["drone", 180, 42, 3.4], ["drone", 360, 42, 3.4], ["rusher", 445, 41, 3.5]],
	54: [["interceptor", 220, 45, 3.6], ["interceptor", 320, 45, 3.6]],
	57: [["drone", 115, 42, 4.1], ["drone", 218, 44, 3.7], ["drone", 322, 44, 3.7], ["drone", 425, 42, 4.1]],
	59: [["drone", 143, 41, 3.5], ["missile_bomber", 270, 79, 2.8], ["drone", 398, 41, 3.5]],
	61: [["interceptor", 104, 43, 3.9], ["drone", 204, 45, 4.1], ["drone", 336, 45, 4.1], ["interceptor", 435, 43, 3.9]],
	65: [["interceptor", 130, 48, 3.5], ["interceptor", 270, 48, 3.5], ["interceptor", 410, 48, 3.5]],
	66: [["drone", 171, 40, 4.2], ["drone", 270, 40, 4.1], ["drone", 369, 40, 4.2]],
}
const FORMATIONS := {
	"arc": [["drone", 125, 34, 2.8, 194], ["drone", 184, 32, 2.6, 170], ["drone", 243, 36, 2.8, 151],
		["drone", 301, 36, 2.8, 151], ["drone", 360, 32, 2.6, 170], ["drone", 419, 34, 2.8, 194]],
	"lance": [["shieldguard", 270, 68, 2.6, 225], ["drone", 270, 45, 2.8, 190],
		["gunship", 270, 74, 2.8, 155], ["interceptor", 144, 37, 3.3, 183], ["interceptor", 397, 37, 3.3, 183]],
	"seeker": [["interceptor", 94, 39, 2.8, 190], ["interceptor", 180, 41, 3.0, 163],
		["interceptor", 270, 38, 2.7, 138], ["interceptor", 359, 41, 3.0, 163], ["interceptor", 444, 39, 2.8, 190]],
}

static func boss_at(sim) -> float:
	return BOSS_AT if sim.intro_scripted else LEGACY_BOSS_AT

static func featured_weapon(sim, pick: int) -> String:
	var id: String = sim.intro_picks[pick]
	return str(sim.intro_picks[0]) if id == "coolant" else id

static func recommendation(sim) -> String:
	if not sim.intro_scripted:
		return ""
	if sim.intro_picks.is_empty():
		return "Pick Arc coil. Its lightning jumps between ships."
	match str(sim.intro_picks[0]):
		"arc": return "Pick Arc coil again to hit more ships at once."
		"lance": return "Pick Prism lance again so it fires faster."
		"seeker": return "Pick Seeker pods again to fire two missiles at once."
	return ""

static func spawn(sim) -> void:
	if sim.boss_spawned:
		return
	if sim.time >= boss_at(sim) or (sim.intro_campaign_waves and _clear_for_harvester(sim)):
		if sim.intro_scripted:
			# The campaign entrance clears the field. In the short intro,
			# let the last formation stay in flight as the Harvester arrives.
			var escorts: Array = sim.enemies
			sim.enemies = []
			sim._spawn_boss()
			sim.enemies.append_array(escorts)
		else:
			sim._spawn_boss()
		return
	if sim.intro_campaign_waves:
		_spawn_campaign_waves(sim)
		return
	if sim.intro_scripted and sim.tick % roundi(1.0 / sim.DT) == 0:
		_enter_formation(sim, REINFORCEMENTS.get(roundi(sim.time), []))
	var waves := WAVES if sim.intro_scripted else LEGACY_WAVES
	if sim.intro_wave >= waves.size() or sim.time < float(waves[sim.intro_wave][0]):
		return
	var wave: Array = waves[sim.intro_wave]
	sim.intro_wave += 1
	var showcase: bool = wave[1] is int
	var units: Array = FORMATIONS[featured_weapon(sim, int(wave[1]))] if showcase else wave.slice(1)
	_enter_formation(sim, units, float(wave[0]) in LESSON_WAVES)

static func _spawn_campaign_waves(sim) -> void:
	if sim.intro_wave >= CAMPAIGN_WINGS.size():
		return
	sim.wave_drift += sim.DT * (sim.spawn_flow() - 1.0)
	sim._spawn_regular_waves()
	var wing: Array = CAMPAIGN_WINGS[sim.intro_wave]
	if sim.time < float(wing[0]):
		return
	var lead: String = UPGRADE_WINGS[featured_weapon(sim, int(wing[1]))] if wing[1] is int else wing[1]
	var lead_index: int = sim.enemies.size()
	sim._send_world1_strike_wing(lead)
	if sim.intro_wave == 0:
		# Keep the first shooter alive long enough to teach the timing.
		var sniper: Dictionary = sim.enemies[lead_index]
		sniper.max_hp = 115.0
		sniper.hp = sniper.max_hp
		sim.heavy_ready_at = sim.time + 0.85
	sim.intro_wave += 1

static func _clear_for_harvester(sim) -> bool:
	if sim.intro_wave < CAMPAIGN_WINGS.size() or not sim.enemies.is_empty():
		return false
	if sim.intro_clear_at < 0.0:
		sim.intro_clear_at = sim.time
	return sim.time >= sim.intro_clear_at + BOSS_ENTRANCE_DELAY

static func _enter_formation(sim, units: Array, lesson: bool = false) -> void:
	for i in range(units.size()):
		var unit: Array = units[i]
		var y := float(unit[4]) if unit.size() > 4 else 105.0 + ((i + 1) % 2) * 55.0
		sim._add_enemy(str(unit[0]), Vector2(unit[1], y))
		var enemy: Dictionary = sim.enemies[-1]
		enemy.hp = float(unit[2])
		enemy.max_hp = enemy.hp
		enemy.fire = float(unit[3])
		enemy.xp = 0 # Drafts unlock at fixed checkpoints.
		sim._begin_entry(enemy)
		# Always start the sprite entirely above the field, with depth
		# between the rows so the group visibly flies into its formation.
		enemy.p.y = -76.0 - float(i % 3) * 25.0
		if lesson and enemy.kind == "sniper":
			enemy.speed = 12.0
			sim.heavy_ready_at = sim.time + 0.85

static func after_step(sim) -> void:
	if sim.intro_scripted and not sim.ended and sim.boss_spawned and (sim.stage_transition_queued or sim.time - sim.boss_spawn_time >= EJECT_AFTER):
		# The main gun is the end of this flight. Keep this event separate
		# from the ordinary beam so a real, well-timed Aegis still works.
		sim.last_killing_source = "harvester_main_gun"
		sim.intro_ejected = true
		sim.stage_transition_queued = false
		sim.ended = true
		sim.hull = 0.0
		sim.shield = 0.0
		sim.aegis_left = 0.0
		sim.bullets.clear()
		sim.shots.clear()
		sim.charges.clear()
		sim.effects.clear()
		sim._log("Vanguard lost. Pilot ejected.")
		return
	if sim.stage_transition_queued:
		sim.stage_transition_queued = false
		sim.won = not sim.ended
		sim.ended = true
		sim.bullets.clear()
		sim.charges.clear()
		return
	if sim.ended:
		return
	var drafts := DRAFT_AT if sim.intro_scripted else LEGACY_DRAFT_AT
	if sim.intro_picks.size() < drafts.size() and sim.time >= float(drafts[sim.intro_picks.size()]):
		var ids := ["arc", "lance", "seeker"]
		if not sim.intro_picks.is_empty():
			var first: String = sim.intro_picks[0]
			ids = [first, "lance" if first == "arc" else "arc", "coolant"]
		for id in ids:
			for card in sim.content.cards:
				if str(card.id) == id:
					sim.cards.append(card.duplicate(true))
					break
		return
	if sim.intro_lesson_seen or sim.intro_beam_blocked or sim.intro_wave == 0 or sim.cooldowns.aegis > 0.0:
		return
	var lesson_wave: bool
	if sim.intro_campaign_waves:
		lesson_wave = sim.intro_wave == 1 and sim.time < float(CAMPAIGN_WINGS[0][0]) + 3.0
	else:
		var waves := WAVES if sim.intro_scripted else LEGACY_WAVES
		lesson_wave = float(waves[sim.intro_wave - 1][0]) in LESSON_WAVES
	if lesson_wave and sim.charges.any(func(charge): return float(charge.remaining) <= 0.65):
		sim.intro_lesson_seen = true
		sim.intro_aegis_prompt = true

static func popup(sim) -> Array:
	if sim.intro_aegis_prompt:
		return ["Block the beam", "Use Aegis just before the sniper fires."]
	if sim.time < 3.4:
		return ["Autopilot is on", "Your ship steers and fires for you."]
	if sim.intro_picks.is_empty() or sim.time - sim.intro_pick_at >= 2.8:
		return []
	if sim.intro_scripted:
		match str(sim.intro_picks[-1]):
			"arc": return ["Arc coil installed", "Watch the lightning jump between ships."]
			"lance": return ["Prism lance installed", "One shot can hit ships in a line."]
			"seeker": return ["Seeker pods installed", "Watch the missiles follow their targets."]
			"coolant": return ["Coolant loop installed", "Aegis recharges faster."]
	for card in sim.content.cards:
		if str(card.id) == str(sim.intro_picks[-1]):
			return ["Upgrade installed", str(card.name)]
	return []

static func cue(sim) -> Array:
	if sim.boss_spawned:
		if sim.intro_scripted:
			return ["HARVESTER MAIN GUN", "Get ready to eject."]
		if not sim.charges.is_empty():
			return ["BEAM INCOMING", "Time Aegis just before the beam hits."]
		return []
	if sim.intro_beam_blocked and sim.time - sim.intro_blocked_at < 3.0:
		return ["BEAM BLOCKED", "Aegis needs time to recharge."]
	if not sim.intro_scripted and sim.time >= 46.0 and sim.time < 51.0:
		return ["FLIGHT SPEED", "Tap %s× to change speed." % str(sim.intro_speed)]
	if not sim.intro_campaign_waves and sim.time >= boss_at(sim) - (3.0 if sim.intro_scripted else 5.0):
		return ["HARVESTER AHEAD", "Main gun charging."] if sim.intro_scripted else ["HARVESTER AHEAD", "Watch for the beam warning."]
	if not sim.charges.is_empty():
		return ["BEAM INCOMING", "The line shows where it will hit."]
	return []
