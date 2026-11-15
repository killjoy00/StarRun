extends RefCounted
## Local, offline progression. Achievements are earned from completed real runs.
## Daily flights use the same UTC seed, ship, pilot and zero-Hangar loadout
## for everyone. Replays improve a local best, but do not farm Core rewards.
const Catalog = preload("res://scripts/catalog.gd")

const ACHIEVEMENTS = [
	{"id":"first_finish","name":"First Debrief","description":"Finish your first flight, win or lose.","category":"FLIGHT","target":1},
	{"id":"five_runs","name":"Back in the Cockpit","description":"Finish five flights.","category":"FLIGHT","target":5},
	{"id":"twenty_runs","name":"Seasoned Pilot","description":"Finish twenty flights.","category":"FLIGHT","target":20},
	{"id":"first_boss","name":"Break the Belt","description":"Defeat the Harvester in World 1.","category":"CAMPAIGN","target":1},
	{"id":"second_boss","name":"Ride the Storm","description":"Defeat the Storm Carrier in World 2.","category":"CAMPAIGN","target":2},
	{"id":"third_boss","name":"Out of the Forge","description":"Defeat the Crucible Engine in World 3.","category":"CAMPAIGN","target":3},
	{"id":"fourth_boss","name":"Star Runner","description":"Complete the four-world campaign.","category":"CAMPAIGN","target":4},
	{"id":"hard_win","name":"Against the Odds","description":"Win a campaign on Hard.","category":"MASTERY","target":1},
	{"id":"insane_win","name":"Beyond Reason","description":"Win a campaign on Insane.","category":"MASTERY","target":1},
	{"id":"three_ships","name":"Fleet Commander","description":"Win with three different ships.","category":"MASTERY","target":3},
	{"id":"fusion","name":"Two Become One","description":"Finish a flight with a fused ability.","category":"BUILDS","target":1},
	{"id":"prototypes","name":"Experimental","description":"Carry three Prototypes into the same flight.","category":"BUILDS","target":3},
	{"id":"interrupted","name":"Cut the Signal","description":"Cancel five heavy-beam charges in one flight.","category":"TACTICS","target":5},
	{"id":"defended","name":"Nothing Gets Through","description":"Prevent 500 damage in a single flight.","category":"TACTICS","target":500},
	{"id":"daily_first","name":"Clockwork Pilot","description":"Finish a daily challenge.","category":"DAILY","target":1},
	{"id":"daily_seven","name":"Regular Orbit","description":"Finish a challenge on seven different UTC dates.","category":"DAILY","target":7},
	{"id":"endless_six","name":"Beyond the Chart","description":"Clear World 6 in endless mode.","category":"ENDLESS","target":6},
]

static func utc_day() -> String:
	return Time.get_date_string_from_system(true)

static func daily_seed(day: String) -> int:
	# Numeric YYYYMMDD is stable across platforms, locales and time zones.
	return int(day.replace("-", "")) * 31 + 1741

static func daily_setup(day: String) -> Dictionary:
	var ordinal: int = int(day.replace("-", ""))
	var ships: Array = Catalog.SHIPS
	var pilots: Array = Catalog.PILOTS
	return {
		"day":day, "seed":daily_seed(day),
		"ship":str(ships[posmod(ordinal, ships.size())].id),
		"pilot":str(pilots[posmod(ordinal / 7, pilots.size())].id),
		"difficulty":"normal"
	}

static func daily_score(sim: RefCounted) -> int:
	# Stage clears dominate score; kills/build strength break ties. No bonus
	# for waiting longer to die or for spending permanent Hangar currency.
	return int(sim.stage_clears) * 10000 + int(sim.kills) * 3 + int(sim.level) * 50 + (5000 if sim.won else 0) + maxi(0, roundi(float(sim.hull)))

static func prepare(profile: Dictionary) -> void:
	if not profile.get("achievements", {}) is Dictionary:
		profile.achievements = {}
	if not profile.has("achievements"):
		profile.achievements = {}
	if not profile.get("daily_records", {}) is Dictionary:
		profile.daily_records = {}
	if not profile.has("daily_records"):
		profile.daily_records = {}
	var defaults := {
		"finished_runs":0, "max_world_clears":0, "victories":0,
		"hard_wins":0, "insane_wins":0, "victory_ships":[],
		"fusion_runs":0, "max_prototypes":0, "max_beams_cancelled":0,
		"max_damage_prevented":0, "daily_days":[], "max_world_any":0
	}
	var old: Variant = profile.get("achievement_stats", {})
	if old is Dictionary:
		defaults.merge(old, true)
	if not defaults.victory_ships is Array:
		defaults.victory_ships = []
	if not defaults.daily_days is Array:
		defaults.daily_days = []
	profile.achievement_stats = defaults
	if not profile.has("last_settled_run_key"):
		profile.last_settled_run_key = ""

static func start_daily(profile: Dictionary, day: String) -> int:
	prepare(profile)
	var records: Dictionary = profile.daily_records
	var record: Dictionary = records.get(day, {"attempts":0,"completed":0,"best_score":-1,"best_stage":0,"won":false,"rewarded":false})
	record.attempts = int(record.get("attempts",0)) + 1
	records[day] = record
	profile.daily_records = records
	return int(record.attempts)

static func progress(profile: Dictionary, id: String) -> int:
	var stats: Dictionary = profile.get("achievement_stats", {})
	match id:
		"first_finish","five_runs","twenty_runs":
			return int(stats.get("finished_runs",0))
		"first_boss","second_boss","third_boss","fourth_boss":
			return int(stats.get("max_world_clears",0))
		"hard_win":
			return int(stats.get("hard_wins",0))
		"insane_win":
			return int(stats.get("insane_wins",0))
		"three_ships":
			var ships: Array = stats.get("victory_ships",[])
			return ships.size()
		"fusion":
			return int(stats.get("fusion_runs",0))
		"prototypes":
			return int(stats.get("max_prototypes",0))
		"interrupted":
			return int(stats.get("max_beams_cancelled",0))
		"defended":
			return int(stats.get("max_damage_prevented",0))
		"daily_first","daily_seven":
			var dates: Array = stats.get("daily_days",[])
			return dates.size()
		"endless_six":
			return int(stats.get("max_world_any",0))
	return 0

static func settle(profile: Dictionary, sim: RefCounted) -> Dictionary:
	prepare(profile)
	var day: String = str(sim.daily_day)
	var daily: bool = not day.is_empty()
	var unique_key := ("daily:%s:%d" % [day, int(sim.daily_attempt)]) if daily else ("flight:%d" % int(sim.seed_value))
	var records: Dictionary = profile.daily_records
	var record: Dictionary = records.get(day, {})
	var result := {"earned":0,"awarded":[],"daily":daily,"score":-1,"best_score":-1,"new_best":false}
	if daily:
		result.score = daily_score(sim)
		result.best_score = int(record.get("best_score", -1))
	# Double-finish and crash/retry must not pay out or grant progress twice.
	if str(profile.last_settled_run_key) == unique_key:
		return result
	var earned := 0
	if daily:
		if record.is_empty():
			record = {"attempts":maxi(1,int(sim.daily_attempt)),"completed":0,"best_score":-1,"best_stage":0,"won":false,"rewarded":false}
		record.completed = int(record.get("completed",0)) + 1
		var score: int = int(result.score)
		if score > int(record.get("best_score",-1)):
			record.best_score = score
			result.new_best = true
		record.best_stage = maxi(int(record.get("best_stage",0)),int(sim.stage_clears))
		record.won = bool(record.get("won",false)) or bool(sim.won)
		if not bool(record.get("rewarded",false)):
			earned = int(sim.payout())
			record.rewarded = true
		records[day] = record
		profile.daily_records = records
		result.best_score = int(record.best_score)
	else:
		if int(profile.get("last_paid_run",-1)) != int(sim.seed_value):
			earned = int(sim.payout())
			profile.last_paid_run = int(sim.seed_value)
	profile.cores = int(profile.get("cores",0)) + earned
	var stats: Dictionary = profile.achievement_stats
	stats.finished_runs = int(stats.finished_runs) + 1
	stats.max_world_clears = maxi(int(stats.max_world_clears),int(sim.stage_clears))
	stats.max_world_any = maxi(int(stats.max_world_any),int(sim.stage_clears))
	stats.max_prototypes = maxi(int(stats.max_prototypes),int(sim.prototypes.size()))
	stats.max_beams_cancelled = maxi(int(stats.max_beams_cancelled),int(sim.beams_cancelled))
	stats.max_damage_prevented = maxi(int(stats.max_damage_prevented),roundi(float(sim.prevented)))
	if sim.active_slots.any(func(slot): return not sim.fusion_spec(str(slot)).is_empty()):
		stats.fusion_runs = int(stats.fusion_runs) + 1
	if bool(sim.won):
		stats.victories = int(stats.victories) + 1
		if str(sim.difficulty) == "hard":
			stats.hard_wins = int(stats.hard_wins) + 1
		elif str(sim.difficulty) == "insane":
			stats.insane_wins = int(stats.insane_wins) + 1
		var ships: Array = stats.victory_ships
		if sim.ship_id not in ships:
			ships.append(sim.ship_id)
	if daily:
		var dates: Array = stats.daily_days
		if day not in dates:
			dates.append(day)
	profile.achievement_stats = stats
	var awarded: Array = []
	var unlocked: Dictionary = profile.achievements
	for achievement in ACHIEVEMENTS:
		var id: String = str(achievement.id)
		if not unlocked.has(id) and progress(profile,id) >= int(achievement.target):
			unlocked[id] = utc_day()
			awarded.append(id)
	profile.achievements = unlocked
	profile.last_settled_run_key = unique_key
	result.earned = earned
	result.awarded = awarded
	return result

static func achievement(id: String) -> Dictionary:
	for item in ACHIEVEMENTS:
		if str(item.id) == id:
			return item
	return {}
