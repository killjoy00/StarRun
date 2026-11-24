extends RefCounted
## Destinations modify one actual world, not the permanent profile. A separate
## seeded draw preserves combat and draft RNG and is stable on save/resume.
const ROUTES := [
	{"id":"shipyard","name":"Abandoned Shipyard","tag":"Recovery","group":"repair","repair":0.70,"defense":0.65,"cooldown":0.85,"shield_power":1.15,"gain":"Repair 70% hull. Full shield. 35% less incoming damage, 15% shorter ability cooldowns, +15% gun damage above half shield.","cost":"No extra XP or Cores."},
	{"id":"research","name":"Research Station","tag":"Discovery","group":"repair","repair":0.50,"defense":0.85,"cooldown":0.90,"picks":1,"mutation":true,"gain":"Repair 50% hull. Full shield. 15% less damage, 10% shorter cooldowns, one extra upgrade and a mutation choice if eligible.","cost":"Less protection than the shipyard."},
	{"id":"blockade","name":"Military Blockade","tag":"Assault","group":"overclock","repair":0.30,"shield":0.75,"risk":1.12,"power":1.38,"fire":1.15,"hull_risk":1.08,"elite":true,"gain":"Guns hit 38% harder and fire 15% faster. Repair 30% hull; start at 75% shield.","cost":"12% greater enemy pressure, elite formations and 8% extra hull damage."},
	{"id":"rift","name":"Energy Rift","tag":"Volatile","group":"overclock","repair":0.25,"shield":0.50,"power":1.22,"fire":1.20,"cooldown":0.72,"hull_risk":1.15,"gain":"Guns hit 22% harder, fire 20% faster and abilities recharge 28% faster.","cost":"Repair 25% hull, start at half shield, take 15% extra hull damage."},
	{"id":"pirates","name":"Pirate Territory","tag":"Bounty","group":"bounty","repair":0.40,"risk":1.30,"xp":1.35,"bounty":35,"picks":1,"elite":true,"gain":"Repair 40% hull. One extra upgrade, +35% kill XP and 35 Cores per destination world number on boss victory.","cost":"30% greater enemy pressure and elite formations."},
	{"id":"graveyard","name":"Asteroid Graveyard","tag":"Salvage","group":"bounty","repair":0.45,"risk":1.20,"xp":1.50,"bounty":20,"picks":1,"gain":"Repair 45% hull. One extra upgrade, +50% kill XP and 20 Cores per world number for the boss.","cost":"20% greater enemy pressure."},
	{"id":"smugglers","name":"Smuggler's Corridor","tag":"Opportunity","group":"bounty","repair":0.35,"risk":1.15,"xp":1.15,"bounty":20,"rerolls":2,"mutation":true,"gain":"Repair 35% hull. Two extra rerolls, +15% kill XP, mutation choice if eligible and 20 Cores per world number for the boss.","cost":"15% greater enemy pressure."},
	{"id":"uncharted","name":"Uncharted Sector","tag":"Exploration","group":"bounty","repair":0.40,"risk":1.25,"xp":1.25,"bounty":15,"picks":2,"elite":true,"gain":"Repair 40% hull. Two extra upgrades, +25% kill XP and 15 Cores per world number on boss victory.","cost":"25% greater enemy pressure and elite formations."},
]

# The original destinations remain available to suspended runs and exact
# checkpoint counterfactuals. New launches explicitly select version 1.
static func route(id: String, version: int = 0) -> Dictionary:
	for item in ROUTES:
		if str(item.id) != id:
			continue
		var spec: Dictionary = item.duplicate(true)
		if version >= 1:
			match id:
				"shipyard":
					spec.merge({"repair":1.0,"defense":0.60,"damaged_defense":0.50,"gain":"Fully restore hull and shield. Take 40% less damage (50% less if you arrive below 80% hull). 15% shorter cooldowns and +15% gun damage above half shield.","cost":"No extra XP or Cores."}, true)
				"research":
					spec["gain"] = "Repair 50% hull. Full shield. 15% less damage, 10% shorter cooldowns. One extra upgrade to advance your build, plus a weapon mutation choice if eligible."
				"graveyard":
					spec.merge({"xp":1.65,"gain":"Repair 45% hull. One extra upgrade, +65% kill XP and 20 Cores per world number for the boss."}, true)
				"smugglers":
					spec.merge({"risk":1.08,"picks":1,"rerolls":0,"curated":true,"gain":"Repair 35% hull. A special build-focused upgrade draft, +15% kill XP, mutation choice if eligible and 20 Cores per world number for the boss.","cost":"8% greater enemy pressure. The special draft replaces the two bonus rerolls."}, true)
				"uncharted":
					spec.merge({"wildcard":true,"gain":"Repair 40% hull. Receive 1–3 bonus upgrades, +25% kill XP and 15 Cores per world number on boss victory.","cost":"25% greater enemy pressure and elite formations. The number of bonus upgrades is revealed on arrival."}, true)
		return spec
	return {}

# Concise player-facing information, calculated from the same route data as combat.
# Keep the previous rules and their original copy on suspended flights.
static func preview(spec: Dictionary, hull_fraction: float, world: int) -> Dictionary:
	var headline := ""
	var extras := ""
	var cost := str(spec.cost)
	var repair := "Repair %d%% hull" % roundi(float(spec.get("repair", 0.0)) * 100.0)
	var shield := "Start at %d%% shield" % roundi(float(spec.get("shield", 1.0)) * 100.0)
	var bounty := "%d Cores on boss victory" % (int(spec.get("bounty", 0)) * world)
	match str(spec.id):
		"shipyard":
			var defense := float(spec.get("damaged_defense", spec.defense)) if hull_fraction < 0.80 else float(spec.defense)
			headline = "FULL HULL + SHIELD · %d%% LESS DAMAGE" % roundi((1.0 - defense) * 100.0)
			extras = "15% shorter cooldowns; +15% gun damage above half shield."
		"research":
			headline = "+1 UPGRADE · MUTATION IF ELIGIBLE"
			extras = repair + "; full shield; 15% less damage; 10% shorter cooldowns."
		"blockade":
			headline = "+38% GUN DAMAGE · +15% FIRE RATE"
			extras = repair + "; " + shield.to_lower() + "."
		"rift":
			headline = "+22% GUN DAMAGE · +20% FIRE RATE"
			extras = "28% shorter cooldowns."
		"pirates", "graveyard", "smugglers", "uncharted":
			var bonus := "1–3 UPGRADES" if bool(spec.get("wildcard", false)) else ("BUILD DRAFT" if bool(spec.get("curated", false)) else "+1 UPGRADE")
			headline = "+%d%% KILL XP · %s" % [roundi((float(spec.xp) - 1.0) * 100.0), bonus]
			extras = repair + "; " + bounty + "."
			if bool(spec.get("mutation", false)):
				extras += " Mutation if eligible."
			if bool(spec.get("curated", false)):
				cost = "8% greater enemy pressure."
			if bool(spec.get("wildcard", false)):
				cost = "25% greater enemy pressure; elite formations. Upgrade count revealed on arrival."
	return {"headline":headline,"extras":extras,"cost":cost}

# Arrival feedback is derived from the committed route and actual applied defense.
# The wildcard count is the same deterministic draw as the engine; never roll again.
static func arrival_summary(spec: Dictionary, world: int, seed: int, defense: float, hull: float, max_hull: float, shield: float, max_shield: float) -> String:
	var status := "Hull %d/%d · Shield %d/%d" % [ceili(hull),ceili(max_hull),ceili(shield),ceili(max_shield)]
	match str(spec.id):
		"shipyard":
			return "Full hull and shield · %d%% less damage this world" % roundi((1.0 - defense) * 100.0)
		"research":
			return "+1 upgrade · 15% less damage · " + status
		"blockade":
			return "+38% gun damage · +15% fire rate · " + status
		"rift":
			return "+22% gun damage · +20% fire rate · 28% shorter cooldowns"
		"pirates", "graveyard":
			return "+%d%% kill XP · +1 upgrade · %d Cores on boss victory" % [roundi((float(spec.xp)-1.0)*100.0),int(spec.bounty)*world]
		"smugglers":
			return "Build-focused upgrade · +15% kill XP · %d Cores on boss victory" % (int(spec.bounty)*world)
		"uncharted":
			var count := wildcard_picks(seed, world)
			return "%d bonus upgrade%s · +25%% kill XP · %d Cores on boss victory" % [count,"" if count == 1 else "s",int(spec.bounty)*world]
	return status

static func wildcard_picks(seed: int, world: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 104729 + world * 7919 + 811
	return rng.randi_range(1, 3)

static func offers(seed: int, world: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 2654435761 + world * 104729 + 73
	var result: Array = []
	for group in ["repair", "overclock", "bounty"]:
		var pool: Array = ROUTES.filter(func(item): return item.group == group)
		result.append(str(pool[rng.randi_range(0, pool.size()-1)].id))
	return result

## Only advanced regular runs with no actually cleared world receive this
## earned recovery payment. No multiplier on the flat launch stipend and
## no payout for immediate deliberate death. Boss clears retain old payouts.
static func early_advanced_base(kills: int, stipend: int, bonus: int, salvage: int, multiplier: float) -> int:
	var recovery: int = mini(30, maxi(0, int(kills / 12)))
	var earned_stipend: int = int(float(stipend * 2) * recovery / 30.0)
	return int((recovery + earned_stipend + float(int(kills / 30) + bonus) * multiplier) * (1.0 + salvage * 0.08))
