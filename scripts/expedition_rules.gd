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

static func route(id: String) -> Dictionary:
	for item in ROUTES:
		if str(item.id) == id:
			return item
	return {}

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
