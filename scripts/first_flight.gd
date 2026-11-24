extends RefCounted
## Authored encounter schedule. All units, charges and cards use the normal engine.
const SEED := 30417
const REWARD := 15
const BOSS_AT := 145.0
const DRAFT_AT := [35.0, 82.0]
const SECTOR := {
	"id": "debris_belt", "name": "FIRST FLIGHT", "boss": "boss",
	"boss_name": "Harvester", "boss_hp": 1490.0, "health_scale": 1.0,
	"damage_scale": 1.0,
}
# [seconds, [enemy, x, hp, first volley] ...]. Two slower snipers leave
# an Aegis window even when the first cast was early or the first beam missed.
const WAVES := [
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

static func spawn(sim) -> void:
	if sim.boss_spawned:
		return
	if sim.time >= BOSS_AT:
		sim._spawn_boss()
		return
	if sim.intro_wave >= WAVES.size() or sim.time < float(WAVES[sim.intro_wave][0]):
		return
	var wave: Array = WAVES[sim.intro_wave]
	sim.intro_wave += 1
	for i in range(1, wave.size()):
		var unit: Array = wave[i]
		sim._add_enemy(str(unit[0]), Vector2(unit[1], 105.0 + (i % 2) * 55.0))
		var enemy: Dictionary = sim.enemies[-1]
		enemy.hp = float(unit[2])
		enemy.max_hp = enemy.hp
		enemy.fire = float(unit[3])
		enemy.xp = 0 # Drafts unlock at fixed checkpoints.
		if sim.intro_wave == 1:
			enemy.p.y = 75.0 + i * 55.0
		else:
			sim._begin_entry(enemy)
		if sim.intro_wave in [4, 6]:
			enemy.speed = 12.0
			sim.heavy_ready_at = sim.time + 0.85

static func after_step(sim) -> void:
	if sim.stage_transition_queued:
		sim.stage_transition_queued = false
		sim.won = not sim.ended
		sim.ended = true
		sim.bullets.clear()
		sim.charges.clear()
		return
	if sim.ended:
		return
	if sim.intro_picks.size() < DRAFT_AT.size() and sim.time >= float(DRAFT_AT[sim.intro_picks.size()]):
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
	if sim.intro_lesson_seen or sim.intro_beam_blocked or sim.intro_wave not in [4, 6] or sim.cooldowns.aegis > 0.0:
		return
	if sim.charges.any(func(charge): return float(charge.remaining) <= 0.65):
		sim.intro_lesson_seen = true
		sim.intro_aegis_prompt = true

static func cue(sim) -> Array:
	if sim.intro_aegis_prompt:
		return ["BEAM INCOMING", "Use Aegis now."]
	if sim.boss_spawned:
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
				return ["UPGRADE INSTALLED", str(card.name)]
	if sim.time >= 46.0 and sim.time < 51.0:
		return ["FLIGHT SPEED", "Tap %s× to change speed." % str(sim.intro_speed)]
	if sim.time >= BOSS_AT - 5.0:
		return ["HARVESTER AHEAD", "Watch for the beam warning."]
	if not sim.charges.is_empty():
		return ["BEAM INCOMING", "The line shows where it will hit."]
	return []
