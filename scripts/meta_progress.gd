extends RefCounted
## Local, offline progression. Achievements are earned from completed real runs.
## Daily flights use the same UTC seed, ship, pilot and zero-Hangar loadout
## for everyone. Replays improve a local best, but do not farm Core rewards.
const FirstFlight = preload("res://scripts/first_flight.gd")
const Catalog = preload("res://scripts/catalog.gd")
const RivalCaptains = preload("res://scripts/rival_captains.gd")
const Codex = preload("res://scripts/codex.gd")

const ACHIEVEMENTS = [
	{"id":"first_finish","name":"First Debrief","description":"Finish your first run, win or lose.","category":"FLIGHT","target":1},
	{"id":"five_runs","name":"Back in the Cockpit","description":"Finish five runs.","category":"FLIGHT","target":5},
	{"id":"twenty_runs","name":"Seasoned Pilot","description":"Finish twenty runs.","category":"FLIGHT","target":20},
	{"id":"first_boss","name":"Break the Belt","description":"Defeat the Harvester in World 1.","category":"CAMPAIGN","target":1},
	{"id":"second_boss","name":"Ride the Storm","description":"Defeat the Storm Carrier in World 2.","category":"CAMPAIGN","target":2},
	{"id":"third_boss","name":"Out of the Forge","description":"Defeat the Crucible Engine in World 3.","category":"CAMPAIGN","target":3},
	{"id":"fourth_boss","name":"Star Runner","description":"Beat all four worlds.","category":"CAMPAIGN","target":4},
	{"id":"hard_win","name":"Against the Odds","description":"Beat all four worlds on Hard.","category":"MASTERY","target":1},
	{"id":"insane_win","name":"Beyond Reason","description":"Beat all four worlds on Insane.","category":"MASTERY","target":1},
	{"id":"three_ships","name":"Fleet Commander","description":"Win with three different ships.","category":"MASTERY","target":3},
	{"id":"fusion","name":"Two Become One","description":"Finish a run with a fused ability.","category":"BUILDS","target":1},
	{"id":"prototypes","name":"Experimental","description":"Get three Prototypes in one run.","category":"BUILDS","target":3},
	{"id":"interrupted","name":"Cut the Signal","description":"Stop five charging beams in one run.","category":"TACTICS","target":5},
	{"id":"defended","name":"Nothing Gets Through","description":"Block 500 damage in one run.","category":"TACTICS","target":500},
	{"id":"daily_first","name":"Clockwork Pilot","description":"Finish a daily challenge.","category":"DAILY","target":1},
	{"id":"daily_seven","name":"Regular Orbit","description":"Finish the Daily on seven different days.","category":"DAILY","target":7},
	{"id":"open_frequency","name":"Open Frequency","description":"Beat the secret world.","category":"DISCOVERY","target":1,"local_only":true},
	{"id":"endless_six","name":"Beyond the Chart","description":"Clear World 6 in endless mode.","category":"ENDLESS","target":6},
]

static func utc_day() -> String:
	return Time.get_date_string_from_system(true)

## Every Daily generates its own Hangar from the date: the same for
## everyone that day, different each day. A grade sets how much of a full
## Hangar it gets; the ranks are bought in a seeded random order (cheaper
## ranks more likely), so days lean different ways. Owned upgrades never
## apply. Items that only raise Core payouts are left out.
# Shares of a full Hangar's cost. The original (pre-extension) ranks are
# about 21% of it, so Light buys about a third of them, Standard most, Heavy
# all of them plus some extended ranks, Elite deep into the extended ranks.
## Ships and pilots earned through play. Everything not listed here (and not
## free) is bought with Cores: those entries are marked buy_only in Catalog.
const UNLOCKS := {
	"kestrel": {"text":"Beat World 1", "stat":"max_world_any", "target":1},
	"bulwark": {"text":"Block 500 damage in one run", "stat":"max_damage_prevented", "target":500},
	"wraith": {"text":"Get Seeker pods to rank 10 in one run", "stat":"max_rank_seeker", "target":10},
	"arcwing": {"text":"Get Arc coil to rank 10 in one run", "stat":"max_rank_arc", "target":10},
	"haven": {"text":"Turn on SWARM (two drone abilities) in a run", "stat":"swarm", "target":1},
	"engineer": {"text":"Finish 5 runs", "stat":"finished_runs", "target":5},
	"ace": {"text":"Destroy 1,000 enemies in total", "stat":"total_kills", "target":1000},
	"hunter": {"text":"Defeat a rival captain", "stat":"rivals_defeated", "target":1},
	"tactician": {"text":"Stop 5 charging beams in one run", "stat":"max_beams_cancelled", "target":5},
	"scavenger": {"text":"Finish the Daily on 3 different days", "stat":"daily_days", "target":3}
}

static func unlock_progress(profile: Dictionary, id: String) -> int:
	var rule: Dictionary = UNLOCKS.get(id, {})
	if rule.is_empty():
		return 0
	var stats: Dictionary = profile.get("achievement_stats", {})
	match str(rule.stat):
		"daily_days":
			var days: Variant = stats.get("daily_days", [])
			return days.size() if days is Array else 0
		"rivals_defeated":
			var trophies: Variant = profile.get("rival_trophies", [])
			return trophies.size() if trophies is Array else 0
		"swarm":
			var found: Variant = profile.get("codex", {})
			return 1 if found is Dictionary and found.has("synergy:swarm") else 0
	return int(stats.get(str(rule.stat), 0))

## Grant every ship and pilot whose condition is met. Returns the new ones.
static func apply_unlocks(profile: Dictionary) -> Array:
	var added: Array = []
	for id in UNLOCKS:
		var is_ship: bool = Catalog.SHIPS.any(func(s): return str(s.id) == id)
		var key := "ships_owned" if is_ship else "pilots_owned"
		var owned: Variant = profile.get(key, [])
		if not owned is Array:
			owned = []
		if id not in owned and unlock_progress(profile, id) >= int(UNLOCKS[id].target):
			owned.append(id)
			added.append(id)
			profile[key] = owned
	return added

const DAILY_HANGAR_GRADES := [["Light", 3, 7], ["Standard", 9, 16], ["Heavy", 22, 40], ["Elite", 50, 80]]
const DAILY_HANGAR_SKIPPED := ["cores", "stipend", "bounty"]

static func daily_hangar_grade(day: String) -> Dictionary:
	var generator := RandomNumberGenerator.new()
	generator.seed = daily_seed(day) * 7 + 4111
	var grade: Array = DAILY_HANGAR_GRADES[generator.randi_range(0, DAILY_HANGAR_GRADES.size() - 1)]
	return {"name":str(grade[0]), "share":generator.randi_range(int(grade[1]), int(grade[2])), "seed":generator.randi()}

static func daily_hangar(day: String) -> Dictionary:
	var grade: Dictionary = daily_hangar_grade(day)
	var generator := RandomNumberGenerator.new()
	generator.seed = int(grade.seed)
	var result := {}
	var total := 0
	for item in Catalog.HANGAR:
		result[str(item.id)] = 0
		for rank in range(int(item.max)):
			total += Catalog.price(str(item.id), rank)
	var budget: int = total * int(grade.share) / 100
	while true:
		var options: Array = []
		var weights: Array = []
		var weight_sum := 0.0
		for item in Catalog.HANGAR:
			var id: String = str(item.id)
			if id in DAILY_HANGAR_SKIPPED or int(result[id]) >= int(item.max):
				continue
			var cost: int = Catalog.price(id, int(result[id]))
			if cost <= budget:
				options.append(id)
				var weight := 1.0 / sqrt(float(maxi(1, cost)))
				weights.append(weight)
				weight_sum += weight
		if options.is_empty():
			break
		var roll := generator.randf() * weight_sum
		var pick: String = options[-1]
		for index in range(options.size()):
			roll -= float(weights[index])
			if roll <= 0.0:
				pick = options[index]
				break
		budget -= Catalog.price(pick, int(result[pick]))
		result[pick] = int(result[pick]) + 1
	return result

static func daily_seed(day: String) -> int:
	# Numeric YYYYMMDD is stable across platforms, locales and time zones.
	return int(day.replace("-", "")) * 31 + 1741

static func daily_setup(day: String) -> Dictionary:
	var ordinal: int = int(day.replace("-", ""))
	# Buy-only ships and pilots are not in the rotation, so adding one never
	# changes which ship or pilot a past or current day uses.
	var ships: Array = Catalog.SHIPS.filter(func(s): return not bool(s.get("buy_only", false)))
	var pilots: Array = Catalog.PILOTS.filter(func(p): return not bool(p.get("buy_only", false)))
	return {
		"day":day, "seed":daily_seed(day),
		"ship":str(ships[posmod(ordinal, ships.size())].id),
		"pilot":str(pilots[posmod(int(ordinal / 7), pilots.size())].id),
		"difficulty":"normal"
	}

static func daily_score(sim: RefCounted) -> int:
	# Stage clears dominate score; kills/build strength break ties. No bonus
	# for waiting longer to die or for spending permanent Hangar currency.
	return int(sim.stage_clears) * 10000 + int(sim.kills) * 3 + int(sim.level) * 50 + (5000 if sim.won else 0) + maxi(0, roundi(float(sim.hull)))

static func prepare(profile: Dictionary) -> void:
	RivalCaptains.prepare(profile)
	if not profile.get("achievements", {}) is Dictionary:
		profile.achievements = {}
	if not profile.has("achievements"):
		profile.achievements = {}
	if not profile.get("codex", {}) is Dictionary or not profile.has("codex"):
		profile.codex = {}
	if not profile.get("daily_records", {}) is Dictionary:
		profile.daily_records = {}
	if not profile.has("daily_records"):
		profile.daily_records = {}
	var defaults := {
		"finished_runs":0, "max_world_clears":0, "victories":0,
		"hard_wins":0, "insane_wins":0, "victory_ships":[],
		"fusion_runs":0, "max_prototypes":0, "max_beams_cancelled":0,
		"max_damage_prevented":0, "daily_days":[], "max_world_any":0, "archive_cleared":false,
		"world_clears":{}, "total_kills":0, "max_rank_seeker":0, "max_rank_arc":0
	}
	var old: Variant = profile.get("achievement_stats", {})
	if old is Dictionary:
		defaults.merge(old, true)
	if not defaults.victory_ships is Array:
		defaults.victory_ships = []
	if not defaults.daily_days is Array:
		defaults.daily_days = []
	if not defaults.world_clears is Dictionary:
		defaults.world_clears = {}
	# Profiles from before start-world select: best clears were tracked for
	# all difficulties together. Credit them to Normal, and a Hard or
	# Insane win to that difficulty.
	if defaults.world_clears.is_empty():
		defaults.world_clears = {"normal":mini(int(defaults.max_world_clears), 4), "hard":4 if int(defaults.hard_wins) > 0 else 0, "insane":4 if int(defaults.insane_wins) > 0 else 0}
	profile.achievement_stats = defaults
	if not profile.has("last_settled_run_key"):
		profile.last_settled_run_key = ""
	# Older profiles get whatever their past runs already earned.
	apply_unlocks(profile)

## Highest world a regular flight may start at on this difficulty: one past
## the best world cleared there. Clears on a harder difficulty count too.
static func max_start_world(profile: Dictionary, difficulty: String) -> int:
	prepare(profile)
	var clears: Dictionary = profile.achievement_stats.world_clears
	var order: Array = Catalog.DIFFICULTIES
	var best := 0
	for index in range(maxi(0, order.find(difficulty)), order.size()):
		best = maxi(best, int(clears.get(str(order[index]), 0)))
	return clampi(best + 1, 1, 4)

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
		"open_frequency":
			return int(bool(stats.get("archive_cleared",false)))
		"endless_six":
			return int(stats.get("max_world_any",0))
	return 0

## A separate receipt keeps this reward independent of campaign/Daily seeds.
static func settle_first_flight(profile: Dictionary, sim: RefCounted) -> void:
	if not sim.intro_run or not sim.intro_reward_eligible or not sim.ended or (not sim.won and not sim.intro_ejected) or profile.get("intro_status") != "available":
		return
	profile.intro_status = "complete"
	profile.intro_cores = FirstFlight.REWARD
	profile.cores = int(profile.get("cores", 0)) + FirstFlight.REWARD
	if sim.intro_beam_blocked:
		profile.beam_tutorial_seen = true

static func settle(profile: Dictionary, sim: RefCounted) -> Dictionary:
	prepare(profile)
	var day: String = str(sim.daily_day)
	var daily: bool = not day.is_empty()
	var unique_key := ("daily:%s:%d" % [day, int(sim.daily_attempt)]) if daily else ("flight:%d" % int(sim.seed_value))
	var records: Dictionary = profile.daily_records
	var record: Dictionary = records.get(day, {})
	var result := {"earned":0,"awarded":[],"daily":daily,"score":-1,"best_score":-1,"new_best":false,"rival_news":{},"codex_new":0,"unlocked":[]}
	# Codex discoveries merge idempotently, so a repeated settle is harmless.
	if sim.has_method("note_codex"):
		sim.note_codex()
		result.codex_new = Codex.record(profile, sim.codex_seen)
	var best_key := "best_score"
	if daily:
		result.score = daily_score(sim)
		result.best_score = int(record.get(best_key, -1))
	# Double-finish and crash/retry must not pay out or grant progress twice.
	if str(profile.last_settled_run_key) == unique_key:
		return result
	var earned := 0
	if daily:
		if record.is_empty():
			record = {"attempts":maxi(1,int(sim.daily_attempt)),"completed":0,"best_score":-1,"best_stage":0,"won":false,"rewarded":false}
		record.completed = int(record.get("completed",0)) + 1
		var score: int = int(result.score)
		if score > int(record.get(best_key,-1)):
			record[best_key] = score
			result.new_best = true
		record.best_stage = maxi(int(record.get("best_stage",0)),int(sim.stage_clears))
		record.won = bool(record.get("won",false)) or bool(sim.won)
		if not bool(record.get("rewarded",false)):
			earned = int(sim.payout())
			record.rewarded = true
		records[day] = record
		profile.daily_records = records
		result.best_score = int(record.get(best_key, -1))
	else:
		if int(profile.get("last_paid_run",-1)) != int(sim.seed_value):
			earned = int(sim.payout())
			profile.last_paid_run = int(sim.seed_value)
	profile.cores = int(profile.get("cores",0)) + earned
	var stats: Dictionary = profile.achievement_stats
	stats.finished_runs = int(stats.finished_runs) + 1
	var secret: bool = sim.secret_entered and not daily
	var worlds: int = mini(int(sim.stage_clears), 4) if secret else int(sim.stage_clears)
	# A win only counts as beating all four worlds when the flight started
	# at World 1, so a later start can earn the World 1-3 boss awards at most.
	var full_run: bool = int(sim.start_world) <= 1
	stats.max_world_clears = maxi(int(stats.max_world_clears), worlds if full_run else mini(worlds, 3))
	stats.max_world_any = maxi(int(stats.max_world_any), worlds)
	var by_difficulty: Dictionary = stats.world_clears
	by_difficulty[str(sim.difficulty)] = maxi(int(by_difficulty.get(str(sim.difficulty), 0)), mini(worlds, 4))
	stats.world_clears = by_difficulty
	if secret and bool(sim.won) and int(sim.stage_clears) == 5:
		stats.archive_cleared = true
	stats.max_prototypes = maxi(int(stats.max_prototypes),int(sim.prototypes.size()))
	stats.max_beams_cancelled = maxi(int(stats.max_beams_cancelled),int(sim.beams_cancelled))
	stats.max_damage_prevented = maxi(int(stats.max_damage_prevented),roundi(float(sim.prevented)))
	stats.total_kills = int(stats.total_kills) + int(sim.kills)
	stats.max_rank_seeker = maxi(int(stats.max_rank_seeker), int(sim.upgrades.get("seeker", 0)))
	stats.max_rank_arc = maxi(int(stats.max_rank_arc), int(sim.upgrades.get("arc", 0)))
	if sim.active_slots.any(func(slot): return not sim.fusion_spec(str(slot)).is_empty()):
		stats.fusion_runs = int(stats.fusion_runs) + 1
	# The campaign is earned at the Citadel clear, independently of whether
	# the optional extension is survived. Daily and late starts retain their
	# existing eligibility. The normal settlement key still prevents duplicates.
	var campaign_cleared: bool = bool(sim.won) or (secret and worlds == 4) or (not daily and bool(sim.endless_enabled) and int(sim.stage_clears) >= 4)
	if full_run and campaign_cleared:
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
	result.rival_news = RivalCaptains.settle(profile, sim)
	profile.last_settled_run_key = unique_key
	result.earned = earned
	result.awarded = awarded
	result.unlocked = apply_unlocks(profile)
	return result

static func achievement(id: String) -> Dictionary:
	for item in ACHIEVEMENTS:
		if str(item.id) == id:
			return item
	return {}


# A paste-ready scorecard that does not expose a player's device ID or profile.
# Use the immutable UTC day from the saved run, never the wall-clock on replay.
static func daily_share_text(sim: RefCounted) -> String:
	if str(sim.daily_day).is_empty():
		return ""
	var ship: Dictionary = Catalog.ship(str(sim.ship_id))
	var pilot: Dictionary = Catalog.pilot(str(sim.pilot_id))
	var outcome := "FOUR WORLDS CLEARED" if bool(sim.won) else "Worlds cleared: %d/4" % mini(int(sim.stage_clears),4)
	return "Star/Run · Daily %s UTC\nScore: %d\n%s\nShip: %s · Pilot: %s\nSame seed. How far can you get?\n#StarRun" % [
		str(sim.daily_day), daily_score(sim), outcome, str(ship.name), str(pilot.name)
	]
