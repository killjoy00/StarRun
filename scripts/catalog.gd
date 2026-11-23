extends RefCounted
## One catalog drives prices, refunds, unlockable actives, and the Hangar UI.
const ACTIVE_SLOTS := 4
const DIFFICULTIES := ["normal", "hard", "insane"]
# Optional challenge rules are local to regular flights. Daily always uses standard.
const ARTIFACTS := [
	{"id":"standard", "name":"Standard", "description":"The normal four-world run."},
	{"id":"glass_fleet", "name":"Glass Fleet", "description":"Half hull, +25% shield and +50% gun damage."},
	{"id":"arsenal_roulette", "name":"Arsenal Shift", "description":"Each time you warp, your gun ranks move to the next gun (Pulse, Seeker, Arc, Lance)."},
	{"id":"drone_armada", "name":"Drone Armada", "description":"No guns and no gun upgrades. Three drones fight for you and get stronger as you level up."},
]
# One extraordinary weapon transformation at a time; can be drafted or bought from a black market.
const MUTATIONS := [
	{"id":"piercing_pulse", "requires":"pulse", "name":"Ghost Rounds", "description":"Pulse shots go through the first enemy and hit a second one for 60% damage.", "market_cost":"Lose 25% max shield.", "hull_factor":1.0, "shield_factor":0.75},
	{"id":"ricochet_pulse", "requires":"pulse", "name":"Bank Shot", "description":"Pulse hits bounce a 35% damage shot to a nearby enemy.", "market_cost":"Lose 20% max shield.", "hull_factor":1.0, "shield_factor":0.80},
	{"id":"split_seeker", "requires":"seeker", "name":"Hydra Warheads", "description":"Seeker hits launch up to 3 small missiles at other enemies.", "market_cost":"Lose 20% max hull.", "hull_factor":0.80, "shield_factor":1.0},
	{"id":"breach_seeker", "requires":"seeker", "name":"Siege Torpedoes", "description":"Seekers do 25% more to bosses and splash 25% damage onto 2 nearby enemies.", "market_cost":"Lose 18% max hull.", "hull_factor":0.82, "shield_factor":1.0},
	{"id":"arc_reactor", "requires":"arc", "name":"Chain Reactor", "description":"Arc kills set off a lightning burst that hits 2 nearby enemies.", "market_cost":"Lose 15% max hull and shield.", "hull_factor":0.85, "shield_factor":0.85},
	{"id":"grounding_arc", "requires":"arc", "name":"Static Lock", "description":"Arc hits stop enemies from shooting for 1.8 seconds and cancel charging beams.", "market_cost":"Lose 20% max hull.", "hull_factor":0.80, "shield_factor":1.0},
	{"id":"refracting_lance", "requires":"lance", "name":"Prism Echo", "description":"Lance hits split off a second beam for 35% damage.", "market_cost":"Lose 15% max hull and shield.", "hull_factor":0.85, "shield_factor":0.85},
	{"id":"capacitor_lance", "requires":"lance", "name":"Capacitor Lance", "description":"Your first Lance kill each shot cuts 0.65 seconds off its recharge.", "market_cost":"Lose 25% max shield.", "hull_factor":1.0, "shield_factor":0.75},
]
const REWARD_MULTIPLIERS := {"normal": 1.0, "hard": 1.75, "insane": 2.5}
const ABILITIES := ["aegis", "nova", "barrage", "overdrive", "chrono", "mend", "flak", "emp", "deflector", "strike", "prism", "barrier", "capacitor", "focus", "decoy", "jammer", "siphon", "overload", "reboot", "salvage", "wing_drones", "ion_mine", "guard_drones"]

# These unlocks are permanent profile purchases, independent of refundable Hangar ranks.
const PILOTS := [
	{"id":"rookie", "name":"Vale · Flight leader", "cost":0, "description":"No special bonus.", "trait":"BALANCED"},
	{"id":"ace", "name":"Vega · Ace", "cost":25, "description":"+25% Pulse damage and better aim. 3 quick kills fire a bonus volley.", "trait":"AIM"},
	{"id":"engineer", "name":"Patch · Engineer", "cost":35, "description":"+20 shield and faster shield recharge. Drops a turret when your shield breaks or between waves.", "trait":"SHIELDS"},
	{"id":"hunter", "name":"Orion · Hunter", "cost":45, "description":"+30% Seeker damage and faster lock-on. Marks a target for all your guns.", "trait":"MISSILES"},
	{"id":"scavenger", "name":"Scrap · Salvager", "cost":60, "description":"+25% XP and +15% Cores. Every 12 kills sends out a damaging shockwave.", "trait":"LOOT"},
	{"id":"tactician", "name":"Nyx · Tactician", "cost":75, "description":"Abilities recharge 15% faster. One extra reroll. Once per world, an ability used just before a hit fires back.", "trait":"ABILITIES"},
	{"id":"daredevil", "name":"Kade · Daredevil", "cost":90, "buy_only":true, "description":"Below half hull: +25% gun damage and abilities recharge 20% faster.", "trait":"RISK"}
]
const SHIPS := [
	{"id":"vanguard", "signature":"aegis", "name":"Vanguard", "cost":0, "description":"Balanced. Starts with Pulse and Seeker. Gets stronger after each world: more damage and less status damage.", "hull":108, "shield":52, "pulse":1, "seeker":1, "arc":0, "mend":0, "movement":1.0, "fire_rate":1.0},
	{"id":"kestrel", "signature":"overdrive", "name":"Kestrel · Interceptor", "cost":45, "description":"Fast. Fires 25% faster and starts with 2 Pulse ranks. Low hull and shield.", "hull":85, "shield":40, "pulse":2, "seeker":0, "arc":0, "mend":0, "movement":1.30, "fire_rate":1.25},
	{"id":"bulwark", "signature":"deflector", "name":"Bulwark · Fortress", "cost":50, "description":"Tank. Huge hull and shield, built-in armor, 30% less beam and missile damage, +20% damage to bosses. Slow. Pulse only.", "hull":160, "shield":80, "pulse":1, "seeker":0, "arc":0, "mend":0, "movement":0.75, "fire_rate":1.0},
	{"id":"wraith", "signature":"barrage", "name":"Wraith · Missile boat", "cost":65, "description":"Missiles. No Pulse. Starts with 2 Seeker ranks that hit 35% harder and reload faster.", "hull":85, "shield":40, "pulse":0, "seeker":2, "arc":0, "mend":0, "movement":1.12, "fire_rate":1.0},
	{"id":"arcwing", "signature":"nova", "name":"Arcwing · Chain fighter", "cost":75, "description":"Lightning. Starts with Arc instead of Seeker. Arc is 30% stronger.", "hull":80, "shield":45, "pulse":1, "seeker":0, "arc":1, "mend":0, "movement":1.18, "fire_rate":1.05},
	{"id":"haven", "signature":"mend", "name":"Haven · Support carrier", "cost":90, "description":"Drone carrier. Drones are 25% stronger, and Wing and Guard drones launch one extra drone. Seekers hit 30% harder and reload 20% faster. No Pulse, 25% less status damage.", "hull":125, "shield":65, "pulse":0, "seeker":1, "arc":0, "mend":1, "movement":0.87, "fire_rate":0.95},
	{"id":"lancer", "signature":"prism", "name":"Lancer · Beam frigate", "cost":120, "buy_only":true, "description":"Beams. Starts with Prism lance instead of Pulse. The lance hits 35% harder and fires 15% more often. Starts with Prism reversal.", "hull":100, "shield":50, "pulse":0, "seeker":0, "arc":0, "lance":1, "mend":0, "movement":1.05, "fire_rate":1.0}
]

const GROUPS := ["Hull", "Weapons", "Abilities", "Tactics", "Salvage"]
const HANGAR := [
	{"id":"hull", "name":"Hull plating", "group":"Hull", "description":"+10 starting hull per rank.", "max":15, "tier_from":7, "tier_step":4, "tier_scale":10, "cost":5, "step":0},
	{"id":"shield", "name":"Shield capacitor", "group":"Hull", "description":"+8 starting shield per rank.", "max":15, "tier_from":7, "tier_step":4, "tier_scale":10, "cost":5, "step":2},
	{"id":"armor", "name":"Ceramic mesh", "group":"Hull", "description":"Small bullets do 0.12 less damage per rank.", "max":6, "tier_from":4, "tier_step":6, "tier_scale":10, "cost":6, "step":2},
	{"id":"regen", "name":"Shield lab", "group":"Hull", "description":"Shield recharges faster: +0.25 per second at rank 1, then +0.30 per rank.", "max":10, "tier_from":6, "tier_step":4, "tier_scale":10, "cost":5, "step":0},
	{"id":"repair", "name":"Maintenance bots", "group":"Hull", "description":"Slowly repair hull: 0.15 per second at rank 1, then +0.20 per rank.", "max":8, "tier_from":4, "tier_step":5, "tier_scale":10, "cost":8, "step":3},
	{"id":"damage", "name":"Munitions lab", "group":"Weapons", "description":"Guns do 8% more damage per rank.", "max":12, "tier_from":5, "tier_step":6, "tier_scale":10, "cost":5, "step":0},
	{"id":"fire_rate", "name":"Feed accelerator", "group":"Weapons", "description":"Guns fire 5% faster per rank.", "max":10, "tier_from":5, "tier_step":6, "tier_scale":10, "cost":7, "step":2},
	{"id":"guidance", "name":"Guidance array", "group":"Weapons", "description":"Pulse aims wider and curves more toward enemies.", "max":4, "cost":6, "step":2},
	{"id":"pulse_start", "name":"Pulse precharge", "group":"Weapons", "description":"Start every run with Pulse at rank 2.", "max":1, "cost":15, "step":0},
	{"id":"seeker_start", "name":"Loaded pods", "group":"Weapons", "description":"Start every run with Seeker at rank 2.", "max":1, "cost":15, "step":0},
	{"id":"ability_cooldown", "name":"Reactor cooling", "group":"Abilities", "description":"Abilities recharge 3% faster per rank.", "max":10, "tier_from":6, "tier_step":5, "tier_scale":10, "cost":7, "step":3},
	{"id":"ability_power", "name":"Flux amplifier", "group":"Abilities", "description":"Abilities do 6% more damage, healing and duration per rank.", "max":10, "tier_from":5, "tier_step":5, "tier_scale":10, "cost":7, "step":3},
	{"id":"reserve_shield", "name":"Cast capacitor", "group":"Abilities", "description":"Get 5 shield every time you use an ability.", "max":3, "cost":10, "step":4},
	{"id":"emergency", "name":"Emergency field", "group":"Abilities", "description":"Once per run, become immune for 1.5 seconds when your hull gets low. +0.5 seconds at rank 2.", "max":2, "cost":12, "step":8},
	{"id":"extra_card", "name":"Extra choice", "group":"Tactics", "description":"Pick from 4 upgrades instead of 3.", "max":1, "cost":15, "step":0},
	{"id":"rerolls", "name":"Rerolls", "group":"Tactics", "description":"1 reroll per rank for the whole run. A reroll swaps the upgrade choices for new ones.", "max":6, "cost":5, "step":2},
	{"id":"banishes", "name":"Removes", "group":"Tactics", "description":"Take an upgrade out of this run so it never shows up. 1 per rank.", "max":3, "cost":7, "step":3},
	{"id":"skips", "name":"Skips", "group":"Tactics", "description":"Skip an upgrade pick and repair 12 hull. 1 per rank.", "max":3, "cost":5, "step":2},
	{"id":"xp", "name":"Data harvester", "group":"Salvage", "description":"6% more XP from kills per rank.", "max":8, "tier_from":5, "tier_step":4, "tier_scale":10, "cost":6, "step":2},
	{"id":"cores", "name":"Salvage rig", "group":"Salvage", "description":"8% more Cores after every run per rank.", "max":5, "cost":6, "step":2},
	{"id":"stipend", "name":"Recovery contract", "group":"Salvage", "description":"Every run pays at least 2 more Cores per rank.", "max":3, "cost":8, "step":3},
	{"id":"bounty", "name":"Harvester bounty", "group":"Salvage", "description":"5 more Cores per rank for beating a boss.", "max":3, "cost":8, "step":4},
	{"id":"beam_plating","name":"Ablative panels","group":"Hull","description":"Beams, missiles and mines do 3% less damage per rank.","max":4,"cost":12,"step":5},
	{"id":"shield_restart","name":"Restart circuit","group":"Hull","description":"A broken shield starts recharging 0.2 seconds sooner per rank.","max":4,"cost":12,"step":5},
	{"id":"hazard_seals","name":"Sealed systems","group":"Hull","description":"Status effects are 5% shorter per rank.","max":4,"cost":14,"step":5},
	{"id":"warp_repairs","name":"Docking crew","group":"Hull","description":"Repair 4% more hull between worlds per rank.","max":3,"cost":14,"step":7},
	{"id":"arc_start","name":"Charged coil","group":"Weapons","description":"Start every run with 1 extra Arc rank.","max":1,"cost":35,"step":0},
	{"id":"lance_start","name":"Lance mount","group":"Weapons","description":"Start every run with Lance at rank 1.","max":1,"cost":40,"step":0},
	{"id":"boss_damage","name":"Siege targeting","group":"Weapons","description":"Guns do 3% more damage to bosses per rank.","max":10, "tier_from":6, "tier_step":6, "tier_scale":10,"cost":14,"step":6},
	{"id":"ordnance_damage","name":"Warhead tooling","group":"Weapons","description":"Seekers do 5% more damage per rank.","max":4,"cost":12,"step":5},
	{"id":"signature_rank","name":"Pilot drills","group":"Abilities","description":"Your ship's starting ability gets 1 extra rank.","max":2,"cost":16,"step":10},
	{"id":"cast_repair","name":"Field patch kit","group":"Abilities","description":"Each ability use repairs 1 hull per rank.","max":3,"cost":18,"step":8},
	{"id":"opening_charge","name":"Hot start","group":"Abilities","description":"The first use of each ability in a world recharges 10% faster per rank.","max":3,"cost":18,"step":8},
	{"id":"reroll_focus","name":"Focused rerolls","group":"Tactics","description":"Rerolls always include an upgrade you already have, if one is left.","max":1,"cost":35,"step":0},
	{"id":"banish_relay","name":"Remove refill","group":"Tactics","description":"Get 1 Remove back per rank at each new world.","max":2,"cost":20,"step":12},
	{"id":"skip_patch","name":"Repair stores","group":"Tactics","description":"Skipping an upgrade pick repairs 6 more hull per rank.","max":3,"cost":8,"step":4},
	{"id":"module_salvage","name":"Component salvage","group":"Salvage","description":"Each boss part you destroy pays 1 more Core per rank.","max":3,"cost":18,"step":8},
	{"id":"clean_clear","name":"Clean contract","group":"Salvage","description":"Beat a world with more than 60% hull for 3 more Cores per rank.","max":3,"cost":18,"step":8},
	{"id":"module_breaker","name":"Breach sensors","group":"Weapons","description":"Do 6% more damage to boss parts per rank. Not the boss core.","max":3,"cost":18,"step":8},
	{"id":"point_defense","name":"Point defense","group":"Hull","description":"Boss bullets and missiles do 5% less damage per rank. Not beams.","max":3,"cost":16,"step":7},
	{"id":"second_wind","scale":5,"name":"Second wind","group":"Hull","description":"Once per run, survive a killing blow with 25% hull. +15% hull per extra rank.","max":3,"cost":45,"step":30},
	{"id":"pulse_tuning","scale":5,"name":"Pulse tuning","group":"Weapons","description":"Pulse does 5% more damage per rank.","max":5,"cost":14,"step":6},
	{"id":"arc_tuning","scale":5,"name":"Coil tuning","group":"Weapons","description":"Arc does 5% more damage per rank.","max":5,"cost":14,"step":6},
	{"id":"lance_tuning","scale":5,"name":"Lens tuning","group":"Weapons","description":"Lance does 5% more damage per rank.","max":5,"cost":14,"step":6},
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

# Historical purchases keep their exact receipts when resetting the Hangar.
# The first 15% price increase remains the reference for the next +10%.
static func legacy_price(id: String, rank: int) -> int:
	var item := entry(id)
	var base := int(item.get("cost", 0)) + int(item.get("step", 0)) * rank
	# Extended trees: ranks past the original cap cost more the higher you go.
	# Ranks below it keep their original price, so old receipts still match.
	if item.has("tier_from") and rank >= int(item.tier_from):
		base += int(item.tier_step) * (rank - int(item.tier_from) + 1)
		# Extended ranks are the long late-game climb: each costs about a win.
		base *= int(item.get("tier_scale", 1))
	return base * int(item.get("scale", 1))

static func previous_price(id: String, rank: int) -> int:
	var base := legacy_price(id, rank)
	return ceili(float(base) * 1.15) if base > 0 else 0

static func price(id: String, rank: int) -> int:
	# Compound another 10% on the *visible* post-15%-increase price.
	# Integer ranks round up, and saved paid receipts always win on refund.
	var previous := previous_price(id, rank)
	return ceili(float(previous) * 1.10) if previous > 0 else 0

static func legacy_refund(hangar: Dictionary) -> int:
	var total := 0
	for item in HANGAR:
		for rank in range(int(hangar.get(item.id, 0))):
			total += legacy_price(item.id, rank)
	return total

static func refund(hangar: Dictionary, paid: Dictionary = {}) -> int:
	var total := 0
	for item in HANGAR:
		var id: String = str(item.id)
		if paid.has(id):
			total += int(paid[id])
		else:
			for rank in range(int(hangar.get(id, 0))):
				total += price(id, rank)
	return total

static func artifact(id: String) -> Dictionary:
	for spec in ARTIFACTS:
		if str(spec.id) == id:
			return spec
	return ARTIFACTS[0]

static func mutation(id: String) -> Dictionary:
	for spec in MUTATIONS:
		if str(spec.id) == id:
			return spec
	return {}

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

## A Hangar bought with a share of a full Hangar's Cores (32 = 32%), the way
## a player spreading upgrades would: always the cheapest next rank. Used for
## the Daily's set Hangar and the balance bot's partial Hangars.
static func share_hangar(share: int) -> Dictionary:
	var result := {}
	var total := 0
	for item in HANGAR:
		result[str(item.id)] = 0
		for rank in range(int(item.max)):
			total += price(str(item.id), rank)
	var budget := total * clampi(share, 0, 100) / 100
	while true:
		var best_id := ""
		var best_price := 1 << 30
		for item in HANGAR:
			var id: String = str(item.id)
			if int(result[id]) < int(item.max):
				var next_price := price(id, int(result[id]))
				if next_price < best_price:
					best_price = next_price
					best_id = id
		if best_id.is_empty() or best_price > budget:
			break
		budget -= best_price
		result[best_id] = int(result[best_id]) + 1
	return result
