extends RefCounted
## Offline-only rival history. Not a leaderboard or a permanent combat upgrade.
## All records are small dictionaries, versioned and safely optional in old saves.
const VERSION := 1
const TRAITS := ["charged_barrage", "interceptor_screen", "reactive_shield", "hunter_lock", "mine_scatter"]
const FIRST := ["Vex", "Mara", "Sable", "Kade", "Nyro", "Tessa", "Drake", "Iona", "Rell", "Solan", "Kora", "Brigg"]
const LAST := ["Talon", "Voss", "Serrin", "Kest", "Orlan", "Morrow", "Cinder", "Vane", "Stryx", "Hale", "Crane", "Dusk"]
const SOURCES := ["drone", "rusher", "interceptor", "gunship", "sniper", "missile_bomber", "carrier", "shieldguard", "minelayer", "ion_frigate", "storm_weaver", "disruptor", "arc_spire", "corroder", "ember_hunter", "forge_turret", "splitter", "slag_bomber", "phase_stalker", "void_lancer", "gravity_sentinel", "echo_carrier", "boss", "boss2", "boss3", "boss4"]

static func valid(entry: Variant) -> bool:
	return entry is Dictionary and int(entry.get("version", 0)) == VERSION and int(entry.get("id", 0)) > 0 and not str(entry.get("name", "")).is_empty() and str(entry.get("trait", "")) in TRAITS and str(entry.get("source_enemy_type", "")) in SOURCES

static func prepare(profile: Dictionary) -> void:
	if not valid(profile.get("rival_active", {})):
		profile["rival_active"] = {}
	var old: Variant = profile.get("rival_archive", [])
	var kept: Array = []
	if old is Array:
		for entry in old:
			if valid(entry) and not kept.any(func(item): return int(item.id) == int(entry.id)):
				kept.append(entry.duplicate(true))
	profile["rival_archive"] = kept.slice(maxi(0, kept.size() - 24))
	var prizes: Variant = profile.get("rival_trophies", [])
	profile["rival_trophies"] = prizes.filter(func(x): return x is int or x is String) if prizes is Array else []

static func _generated(sim: RefCounted, finished_runs: int, run_number: int) -> Dictionary:
	var serial := maxi(1, absi(int(sim.seed_value))) + int(sim.stage) * 37
	var generator := RandomNumberGenerator.new()
	generator.seed = serial * 23 + 173
	var signature_id: String = str(TRAITS[generator.randi_range(0, TRAITS.size() - 1)])
	var title := "Captain %s %s" % [FIRST[generator.randi_range(0, FIRST.size() - 1)], LAST[generator.randi_range(0, LAST.size() - 1)]]
	var kind: String = str(sim.last_killing_source)
	# Boss captains recur in a nimble, counterable fighter rather than
	# silently adding a second campaign boss to normal waves.
	var fighter := kind if kind in ["gunship", "interceptor", "shieldguard", "missile_bomber", "ion_frigate", "sniper"] else "gunship"
	return {"version":VERSION, "id":serial, "name":title, "portrait_seed":generator.randi_range(1, 99999),
		"source_enemy_type":kind, "combat_kind":fighter, "world_created":clampi(int(sim.stage), 1, 4),
		"trait":signature_id, "defeat_count":1, "times_encountered":0, "times_escaped":0,
		"last_encounter_seed":-1, "last_escape_seed":-1, "last_defeat_seed":serial,
		"created_run":run_number, "created_completed_runs":finished_runs, "retired":false, "reward_claimed":false}

static func trait_name(id: String) -> String:
	match id:
		"charged_barrage": return "Charged Barrage"
		"interceptor_screen": return "Interceptor Screen"
		"reactive_shield": return "Reactive Shield"
		"hunter_lock": return "Hunter Lock"
		"mine_scatter": return "Mine Scatter"
	return "Unknown threat"

static func counterplay(id: String) -> String:
	match id:
		"charged_barrage": return "Stop the double beam with Aegis, EMP or a fast kill."
		"interceptor_screen": return "Kill the captain first, or its two escorts."
		"reactive_shield": return "Big hits raise a shield. Hit between pulses."
		"hunter_lock": return "Quick beam warning. Use a defense ability in time."
		"mine_scatter": return "Flak and blasts clear the mines."
	return "Kill the captain first."

static func for_launch(profile: Dictionary, sim: RefCounted) -> Dictionary:
	prepare(profile)
	if not str(sim.daily_day).is_empty():
		return {}
	var active: Dictionary = profile.rival_active
	if active.is_empty() or bool(active.get("retired", false)):
		return {}
	# At least one OTHER completed flight after the original defeat.
	if int(profile.get("runs", 0)) <= int(active.get("created_run", 0)) + 1:
		return {}
	var stats: Dictionary = profile.get("achievement_stats", {})
	if int(stats.get("finished_runs", 0)) <= int(active.get("created_completed_runs", 0)):
		return {}
	# A run seed makes the encounter roll stable across restarts.
	var roll: int = posmod(int(sim.seed_value) * 7 + int(active.id) * 11, 100)
	return active.duplicate(true) if roll < 38 else {}

static func note_encounter(profile: Dictionary, sim: RefCounted) -> bool:
	prepare(profile)
	var active: Dictionary = profile.rival_active
	if active.is_empty() or int(active.id) != int(sim.rival_record.get("id", -1)):
		return false
	if int(active.get("last_encounter_seed", -1)) == int(sim.seed_value):
		return false
	active.times_encountered = int(active.get("times_encountered", 0)) + 1
	active.last_encounter_seed = int(sim.seed_value)
	profile.rival_active = active
	return true

static func retire(profile: Dictionary, sim: RefCounted) -> bool:
	prepare(profile)
	if not str(sim.daily_day).is_empty() or str(sim.rival_outcome) != "retired":
		return false
	var active: Dictionary = profile.rival_active
	if active.is_empty() or int(active.id) != int(sim.rival_record.get("id", -1)):
		return false
	if profile.rival_archive.any(func(x): return int(x.id) == int(active.id)):
		profile.rival_active = {}
		return false
	active.retired = true
	active.reward_claimed = true
	active.retired_run = int(sim.seed_value)
	active.final_world = int(sim.stage)
	var archive: Array = profile.rival_archive
	archive.append(active.duplicate(true))
	profile.rival_archive = archive.slice(maxi(0, archive.size() - 24))
	var trophies: Array = profile.rival_trophies
	if int(active.id) not in trophies:
		trophies.append(int(active.id))
	profile.rival_trophies = trophies
	profile.rival_active = {}
	return true

static func settle(profile: Dictionary, sim: RefCounted) -> Dictionary:
	# Called only after the regular settlement's duplicate-run guard.
	prepare(profile)
	if not str(sim.daily_day).is_empty():
		return {}
	if str(sim.rival_outcome) == "retired":
		var fresh: bool = retire(profile, sim)
		return {"kind":"retired", "rival":sim.rival_record.duplicate(true)} if fresh else {}
	var active: Dictionary = profile.rival_active
	if str(sim.rival_outcome) == "escaped" and not active.is_empty() and int(active.id) == int(sim.rival_record.get("id", -1)):
		if int(active.get("last_escape_seed", -1)) != int(sim.seed_value):
			active.times_escaped = int(active.get("times_escaped", 0)) + 1
			active.last_escape_seed = int(sim.seed_value)
			profile.rival_active = active
	if not bool(sim.ended) or bool(sim.won):
		return {}
	if not active.is_empty():
		if str(sim.last_killing_source) == "rival" and bool(sim.rival_spawned) and int(active.id) == int(sim.rival_record.get("id", -1)):
			if int(active.get("last_defeat_seed", -1)) != int(sim.seed_value):
				active.defeat_count = mini(3, int(active.get("defeat_count", 1)) + 1)
				active.last_defeat_seed = int(sim.seed_value)
				profile.rival_active = active
			return {"kind":"rival_defeat","rival":active.duplicate(true)}
		return {}
	if str(sim.last_killing_source) not in SOURCES:
		return {}
	var record: Dictionary = _generated(sim, int(profile.achievement_stats.finished_runs), int(profile.get("runs",0)))
	profile.rival_active = record
	return {"kind":"created","rival":record.duplicate(true)}
