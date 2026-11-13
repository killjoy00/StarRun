extends RefCounted
## One catalog drives prices, refunds, unlockable actives, and the Hangar UI.
const ACTIVE_SLOTS := 4
const DIFFICULTIES := ["normal", "hard", "insane"]
const REWARD_MULTIPLIERS := {"normal": 1.0, "hard": 1.75, "insane": 2.5}
const ABILITIES := ["aegis", "nova", "barrage", "overdrive", "chrono", "mend", "flak", "emp", "deflector", "strike", "prism", "barrier", "capacitor", "focus", "decoy", "jammer", "siphon", "overload", "reboot", "salvage"]

# These unlocks are permanent profile purchases, independent of refundable Hangar ranks.
const PILOTS := [
	{"id":"rookie", "name":"Vale · Flight leader", "cost":0, "description":"Balanced training. No special bonus.", "trait":"STANDARD ISSUE"},
	{"id":"ace", "name":"Vega · Ace", "cost":25, "description":"+25% Pulse damage and stronger forward tracking.", "trait":"PRECISION"},
	{"id":"engineer", "name":"Patch · Engineer", "cost":35, "description":"+20 starting shield and +0.8 shield regeneration per second.", "trait":"FIELD REPAIR"},
	{"id":"hunter", "name":"Orion · Hunter", "cost":45, "description":"+30% seeker damage and faster lock-on.", "trait":"MISSILE EXPERT"},
	{"id":"scavenger", "name":"Scrap · Salvager", "cost":60, "description":"+25% kill XP and +15% post-flight cores.", "trait":"COLLECTOR"},
	{"id":"tactician", "name":"Nyx · Tactician", "cost":75, "description":"15% shorter ability cooldowns and one free card reroll.", "trait":"BATTLE PLAN"}
]
const SHIPS := [
	{"id":"vanguard", "signature":"aegis", "name":"Vanguard", "cost":0, "description":"Balanced guns and shields. Starts with Pulse Cannon and Seeker Pods.", "hull":100, "shield":50, "pulse":1, "seeker":1, "arc":0, "mend":0, "movement":1.0, "fire_rate":1.0},
	{"id":"kestrel", "signature":"overdrive", "name":"Kestrel · Interceptor", "cost":45, "description":"25% quicker firing, sharper autopilot turns. Twin Pulse start; fragile defenses.", "hull":70, "shield":30, "pulse":2, "seeker":0, "arc":0, "mend":0, "movement":1.30, "fire_rate":1.25},
	{"id":"bulwark", "signature":"aegis", "name":"Bulwark · Fortress", "cost":50, "description":"Massive hull, heavy shields, inherent armor; wide, slower flight path. Pulse only.", "hull":160, "shield":80, "pulse":1, "seeker":0, "arc":0, "mend":0, "movement":0.75, "fire_rate":0.90},
	{"id":"wraith", "signature":"barrage", "name":"Wraith · Missile boat", "cost":65, "description":"No Pulse Cannon at launch. Double seeker pods with 35% harder-hitting ordnance.", "hull":85, "shield":40, "pulse":0, "seeker":2, "arc":0, "mend":0, "movement":1.12, "fire_rate":1.0},
	{"id":"arcwing", "signature":"nova", "name":"Arcwing · Chain fighter", "cost":75, "description":"Starts with Arc Coil instead of Seekers. Lightning chains are 30% stronger.", "hull":80, "shield":45, "pulse":1, "seeker":0, "arc":1, "mend":0, "movement":1.18, "fire_rate":1.05},
	{"id":"haven", "signature":"mend", "name":"Haven · Support carrier", "cost":90, "description":"Starts with Repair Drones, Seekers and extra shielding, but no Pulse Cannon.", "hull":115, "shield":65, "pulse":0, "seeker":1, "arc":0, "mend":1, "movement":0.87, "fire_rate":0.95}
]

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

static func pilot(id: String) -> Dictionary:
	for item in PILOTS:
		if item.id == id:
			return item
	return PILOTS[0]

static func ship(id: String) -> Dictionary:
	for item in SHIPS:
		if item.id == id:
			return item
	return SHIPS[0]
