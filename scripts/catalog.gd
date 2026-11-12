extends RefCounted
## One catalog drives prices, refunds, migration and the Hangar UI.
const ABILITIES := ["aegis", "nova", "barrage", "overdrive", "chrono", "mend"]
const GROUPS := ["Hull", "Weapons", "Abilities", "Tactics", "Salvage"]
const HANGAR := [
	{"id":"hull", "name":"Hull plating", "group":"Hull", "description":"+10 starting hull per rank.", "max":6, "cost":5, "step":0},
	{"id":"shield", "name":"Shield capacitor", "group":"Hull", "description":"+8 starting shield per rank.", "max":6, "cost":5, "step":2},
	{"id":"armor", "name":"Ceramic mesh", "group":"Hull", "description":"Reduce every chaff hit by another 0.12.", "max":4, "cost":6, "step":2},
	{"id":"regen", "name":"Shield lab", "group":"Hull", "description":"+0.25 shield regenerated each second.", "max":5, "cost":5, "step":0},
	{"id":"repair", "name":"Maintenance bots", "group":"Hull", "description":"Repair 0.15 hull each second per rank.", "max":4, "cost":8, "step":3},
	{"id":"damage", "name":"Munitions lab", "group":"Weapons", "description":"All automatic weapons deal 8% more damage.", "max":5, "cost":5, "step":0},
	{"id":"fire_rate", "name":"Feed accelerator", "group":"Weapons", "description":"All automatic weapons fire 5% faster.", "max":5, "cost":7, "step":2},
	{"id":"guidance", "name":"Guidance array", "group":"Weapons", "description":"Widen pulse targeting and increase its gentle steering.", "max":4, "cost":6, "step":2},
	{"id":"pulse_start", "name":"Pulse precharge", "group":"Weapons", "description":"Start each new flight with level 2 Pulse Cannon.", "max":1, "cost":15, "step":0},
	{"id":"seeker_start", "name":"Loaded pods", "group":"Weapons", "description":"Start each new flight with level 2 Seeker Pods.", "max":1, "cost":15, "step":0},
	{"id":"ability_cooldown", "name":"Reactor cooling", "group":"Abilities", "description":"Every ability recharges 3% faster per rank.", "max":5, "cost":7, "step":3},
	{"id":"ability_power", "name":"Flux amplifier", "group":"Abilities", "description":"+6% ability damage, healing and duration.", "max":5, "cost":7, "step":3},
	{"id":"reserve_shield", "name":"Cast capacitor", "group":"Abilities", "description":"Recover 5 shield whenever you activate an ability.", "max":3, "cost":10, "step":4},
	{"id":"emergency", "name":"Emergency field", "group":"Abilities", "description":"Once per flight, gain 1.5 seconds of Aegis at low hull. +0.5s at rank 2.", "max":2, "cost":12, "step":8},
	{"id":"extra_card", "name":"Expanded uplink", "group":"Tactics", "description":"Choose from four cards at every level-up.", "max":1, "cost":15, "step":0},
	{"id":"rerolls", "name":"Reroll uplinks", "group":"Tactics", "description":"Reroll a whole upgrade hand once per rank per flight.", "max":3, "cost":7, "step":3},
	{"id":"banishes", "name":"Banish protocols", "group":"Tactics", "description":"Remove an upgrade track from this flight's pool. One use per rank.", "max":3, "cost":7, "step":3},
	{"id":"skips", "name":"Repair fallback", "group":"Tactics", "description":"Skip a draft to repair 12 hull. One use per rank per flight.", "max":3, "cost":5, "step":2},
	{"id":"xp", "name":"Data harvester", "group":"Salvage", "description":"Earn 6% more XP from kills per rank.", "max":5, "cost":6, "step":2},
	{"id":"cores", "name":"Salvage rig", "group":"Salvage", "description":"Earn 8% more cores after every flight.", "max":5, "cost":6, "step":2},
	{"id":"stipend", "name":"Recovery contract", "group":"Salvage", "description":"Every flight pays at least 2 additional cores per rank.", "max":3, "cost":8, "step":3},
	{"id":"bounty", "name":"Harvester bounty", "group":"Salvage", "description":"Earn 5 additional cores per rank for a boss clear.", "max":3, "cost":8, "step":4}
]

static func defaults() -> Dictionary:
	var result := {}
	for entry in HANGAR:
		result[entry.id] = 0
	return result

static func entry(id: String) -> Dictionary:
	for item in HANGAR:
		if item.id == id:
			return item
	return {}

static func price(id: String, rank: int) -> int:
	var item := entry(id)
	return int(item.get("cost", 0)) + int(item.get("step", 0)) * rank

static func refund(hangar: Dictionary) -> int:
	var total := 0
	for item in HANGAR:
		for rank in range(int(hangar.get(item.id, 0))):
			total += price(item.id, rank)
	return total
