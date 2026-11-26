extends RefCounted
## Fifteen authored three-slot formations per campaign world. No extra
## spawn budget, enemies, XP awards or RNG calls are introduced by selection.
const WORLDS := [
	[
		["Scout chevron", 0, 0, ["drone","rusher","drone"]],
		["Fighter screen", 25, 1, ["gunship","interceptor","drone"]],
		["Rusher sweep", 0, 2, ["rusher","drone","rusher"]],
		["Pursuit wing", 25, 3, ["interceptor","rusher","interceptor"]],
		["Gunship line", 25, 2, ["gunship","drone","gunship"]],
		["Sniper escort", 65, 1, ["sniper","gunship","interceptor"]],
		["Missile screen", 65, 0, ["missile_bomber","drone","interceptor"]],
		["Crossing interceptors", 25, 4, ["interceptor","gunship","interceptor"]],
		["Sniper crossfire", 65, 4, ["sniper","interceptor","sniper"]],
		["Bomber echelon", 65, 3, ["missile_bomber","rusher","missile_bomber"]],
		["Shield wall", 110, 2, ["shieldguard","gunship","shieldguard"]],
		["Mine corridor", 110, 4, ["minelayer","gunship","minelayer"]],
		["Carrier escort", 110, 1, ["carrier","shieldguard","interceptor"]],
		["Heavy attack wing", 110, 0, ["shieldguard","missile_bomber","gunship"]],
		["Wreckage blockade", 170, 3, ["carrier","minelayer","shieldguard"]]
	],
	[
		["Ion spearhead", 0, 0, ["ion_frigate","interceptor","ion_frigate"]],
		["Storm sweep", 0, 4, ["storm_weaver","ion_frigate","storm_weaver"]],
		["Disruptor escort", 0, 1, ["disruptor","ion_frigate","interceptor"]],
		["Ion crossfire", 0, 2, ["ion_frigate","disruptor","ion_frigate"]],
		["Fast interception", 0, 3, ["interceptor","storm_weaver","interceptor"]],
		["Arc battery", 50, 2, ["arc_spire","ion_frigate","arc_spire"]],
		["Corrosion corridor", 50, 4, ["corroder","ion_frigate","corroder"]],
		["Shielded spire", 50, 1, ["arc_spire","shieldguard","storm_weaver"]],
		["Storm front", 50, 0, ["storm_weaver","arc_spire","storm_weaver"]],
		["Jamming wedge", 50, 3, ["disruptor","shieldguard","corroder"]],
		["Missile battery", 115, 2, ["missile_bomber","arc_spire","missile_bomber"]],
		["Corrosion escort", 115, 1, ["corroder","shieldguard","disruptor"]],
		["Surge formation", 115, 0, ["arc_spire","disruptor","ion_frigate"]],
		["Disruption crossfire", 115, 4, ["disruptor","storm_weaver","disruptor"]],
		["Electrical blockade", 115, 3, ["shieldguard","arc_spire","corroder"]]
	],
	[
		["Ember wedge", 0, 0, ["ember_hunter","splitter","ember_hunter"]],
		["Forge battery", 0, 2, ["forge_turret","gunship","forge_turret"]],
		["Splitter escort", 0, 1, ["splitter","gunship","ember_hunter"]],
		["Hunter crossfire", 0, 4, ["ember_hunter","forge_turret","ember_hunter"]],
		["Foundry patrol", 0, 3, ["gunship","splitter","forge_turret"]],
		["Slag corridor", 45, 4, ["slag_bomber","splitter","slag_bomber"]],
		["Mine screen", 45, 2, ["minelayer","forge_turret","minelayer"]],
		["Protected furnace", 45, 1, ["forge_turret","splitter","ember_hunter"]],
		["Molten spearhead", 45, 0, ["slag_bomber","ember_hunter","forge_turret"]],
		["Splitter echelon", 45, 3, ["splitter","minelayer","splitter"]],
		["Carrier furnace", 105, 1, ["carrier","slag_bomber","ember_hunter"]],
		["Double slag", 105, 2, ["slag_bomber","forge_turret","slag_bomber"]],
		["Ember flood", 105, 4, ["ember_hunter","splitter","ember_hunter"]],
		["Foundry blockade", 105, 3, ["forge_turret","carrier","minelayer"]],
		["Molten assault", 105, 0, ["slag_bomber","splitter","forge_turret"]]
	],
	[
		["Phase wedge", 0, 0, ["phase_stalker","void_lancer","phase_stalker"]],
		["Lancer crossfire", 0, 4, ["void_lancer","disruptor","void_lancer"]],
		["Gravity escort", 0, 1, ["gravity_sentinel","phase_stalker","disruptor"]],
		["Void battery", 0, 2, ["void_lancer","gravity_sentinel","void_lancer"]],
		["Interference echelon", 0, 3, ["disruptor","phase_stalker","disruptor"]],
		["Echo escort", 45, 1, ["echo_carrier","phase_stalker","gravity_sentinel"]],
		["Gravity well", 45, 2, ["gravity_sentinel","void_lancer","gravity_sentinel"]],
		["Phantom sweep", 45, 4, ["phase_stalker","echo_carrier","phase_stalker"]],
		["Void spearhead", 45, 0, ["echo_carrier","void_lancer","phase_stalker"]],
		["Echo echelon", 45, 3, ["gravity_sentinel","echo_carrier","disruptor"]],
		["Arc blockade", 110, 2, ["arc_spire","void_lancer","gravity_sentinel"]],
		["Slag crossfire", 110, 4, ["slag_bomber","void_lancer","slag_bomber"]],
		["Citadel escort", 110, 1, ["echo_carrier","gravity_sentinel","arc_spire"]],
		["Blackout wedge", 110, 0, ["disruptor","void_lancer","arc_spire"]],
		["Final defense", 110, 3, ["echo_carrier","slag_bomber","gravity_sentinel"]]
	]
]
# Chevron, escort, line, echelon and wide crossfire. All positions are
# offscreen for queued arrivals; the World 1 wing uses the same lanes.
const LANES := [
	[Vector2(270, -35), Vector2(132, -85), Vector2(408, -85)],
	[Vector2(270, -50), Vector2(164, -25), Vector2(376, -25)],
	[Vector2(110, -40), Vector2(270, -40), Vector2(430, -40)],
	[Vector2(126, -30), Vector2(270, -65), Vector2(414, -100)],
	[Vector2(110, -45), Vector2(430, -45), Vector2(270, -100)]
]

static func pick(world: int, elapsed: float, seed_value: int, index: int) -> Array:
	var eligible: Array = []
	for formation in WORLDS[world - 1]:
		if elapsed >= float(formation[1]):
			eligible.append(formation)
	# Seven is coprime to the full library of fifteen. The seed changes
	# the start, not the combat or draft RNG stream.
	return eligible[posmod(seed_value + world * 13 + index * 7, eligible.size())]

static func position(formation: Array, slot: int) -> Vector2:
	return LANES[int(formation[2])][slot]
