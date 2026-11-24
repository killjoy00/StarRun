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
const SECTOR := {
	"id": "debris_belt", "name": "FIRST FLIGHT", "boss": "boss",
	"boss_name": "Harvester", "boss_hp": 1490.0, "health_scale": 1.0,
	"damage_scale": 1.0,
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

const WAVES := [
	[0.12, ["drone", 250, 14, 3.0], ["drone", 340, 19, 3.4]],
	[4.2, ["interceptor", 140, 30, 2.2], ["drone", 315, 24, 2.7]],
	[8.8, ["gunship", 288, 52, 1.5]],
	[13.5, ["sniper", 268, 185, 2.8]],
	[20.0, ["drone", 165, 30, 1.6], ["interceptor", 360, 30, 2.0]],
	[24.0, 0], # Bring in targets for the first weapon the player picked.
	[29.0, ["sniper", 342, 235, 2.4]],
	[35.0, ["interceptor", 120, 36, 1.3], ["gunship", 268, 72, 1.8], ["interceptor", 410, 36, 1.4]],
	[42.0, ["missile_bomber", 165, 74, 1.5], ["gunship", 375, 67, 1.8]],
	[49.0, 1],
	[55.5, ["interceptor", 145, 42, 1.8], ["shieldguard", 268, 108, 1.8], ["interceptor", 394, 42, 1.8]],
	[62.0, ["gunship", 175, 72, 1.4], ["gunship", 365, 72, 1.6]],
]
const FORMATIONS := {
	"arc": [["drone", 156, 27, 2.1, 182], ["drone", 232, 27, 2.0, 152],
		["drone", 308, 27, 2.0, 152], ["drone", 384, 27, 2.1, 182]],
	"lance": [["shieldguard", 270, 65, 2.1, 195], ["drone", 270, 39, 2.3, 170],
		["gunship", 270, 71, 2.4, 145]],
	"seeker": [["interceptor", 95, 36, 2.0, 185], ["interceptor", 260, 36, 2.4, 150],
		["interceptor", 445, 36, 2.2, 185]],
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
	if sim.time >= boss_at(sim):
		sim._spawn_boss()
		return
	var waves := WAVES if sim.intro_scripted else LEGACY_WAVES
	if sim.intro_wave >= waves.size() or sim.time < float(waves[sim.intro_wave][0]):
		return
	var wave: Array = waves[sim.intro_wave]
	sim.intro_wave += 1
	var showcase: bool = wave[1] is int
	var units: Array = FORMATIONS[featured_weapon(sim, int(wave[1]))] if showcase else wave.slice(1)
	for i in range(units.size()):
		var unit: Array = units[i]
		var y := float(unit[4]) if showcase else 105.0 + ((i + 1) % 2) * 55.0
		sim._add_enemy(str(unit[0]), Vector2(unit[1], y))
		var enemy: Dictionary = sim.enemies[-1]
		enemy.hp = float(unit[2])
		enemy.max_hp = enemy.hp
		enemy.fire = float(unit[3])
		enemy.xp = 0 # Drafts unlock at fixed checkpoints.
		if sim.intro_wave == 1:
			enemy.p.y = 130.0 + i * 55.0
		elif not showcase:
			sim._begin_entry(enemy)
		if float(wave[0]) in LESSON_WAVES:
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
	var waves := WAVES if sim.intro_scripted else LEGACY_WAVES
	if float(waves[sim.intro_wave - 1][0]) in LESSON_WAVES and sim.charges.any(func(charge): return float(charge.remaining) <= 0.65):
		sim.intro_lesson_seen = true
		sim.intro_aegis_prompt = true

static func cue(sim) -> Array:
	if sim.intro_aegis_prompt:
		return ["BEAM INCOMING", "Use Aegis now."]
	if sim.boss_spawned:
		if sim.intro_scripted:
			return ["HARVESTER MAIN GUN", "Get ready to eject."]
		if not sim.charges.is_empty():
			return ["BEAM INCOMING", "Time Aegis just before the beam hits."]
		return []
	if sim.time < 5.2:
		return ["AUTOPILOT ON", "Your ship steers and fires for you."]
	if sim.intro_beam_blocked and sim.time - sim.intro_blocked_at < 3.0:
		return ["BEAM BLOCKED", "Aegis needs time to recharge."]
	if not sim.intro_picks.is_empty() and sim.time - sim.intro_pick_at < 3.0:
		for card in sim.content.cards:
			if str(card.id) == str(sim.intro_picks[-1]):
				if sim.intro_scripted:
					match str(card.id):
						"arc": return ["ARC COIL ONLINE", "Watch the lightning jump between ships."]
						"lance": return ["PRISM LANCE ONLINE", "One shot can hit ships in a line."]
						"seeker": return ["SEEKER PODS ONLINE", "Watch the missiles follow their targets."]
						"coolant": return ["COOLANT LOOP ONLINE", "Aegis recharges faster."]
				return ["UPGRADE INSTALLED", str(card.name)]
	if not sim.intro_scripted and sim.time >= 46.0 and sim.time < 51.0:
		return ["FLIGHT SPEED", "Tap %s× to change speed." % str(sim.intro_speed)]
	if sim.time >= boss_at(sim) - (3.0 if sim.intro_scripted else 5.0):
		return ["HARVESTER AHEAD", "Main gun charging."] if sim.intro_scripted else ["HARVESTER AHEAD", "Watch for the beam warning."]
	if not sim.charges.is_empty():
		return ["BEAM INCOMING", "The line shows where it will hit."]
	return []
