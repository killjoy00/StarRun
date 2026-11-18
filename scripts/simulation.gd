extends RefCounted
## Fixed-step simulation: no rendering, platform services, wall clock, or input polling.
const DT := 1.0 / 60.0
const WIDTH := 540.0
const HEIGHT := 960.0
const SAVE_VERSION := 1
const PROTOTYPE_SKIP_CORES := 10
const MAXED_DRAFT_CORES := 5
const Catalog = preload("res://scripts/catalog.gd")
const HiddenSector = preload("res://scripts/hidden_sector.gd")
var signal_count := 0
var signal_status := "" # "", "offer", "cast", "courier", "received", "missed"
var signal_until := 0.0
var secret_entered := false
var secret_intro_pending := false
var secret_payout := 0
var archive_next_attack := 0.0
var archive_attack_until := 0.0
var archive_exposed_until := 0.0
var archive_phase := 0
var archive_phase_released := false
var archive_attack := ""
var archive_attack_x := 0.0
var content: Dictionary
var rng := RandomNumberGenerator.new()
var seed_value := 1
# A separate seeded course never consumes the combat/draft random stream.
var course: Array[Dictionary] = []
var course_pilot := RandomNumberGenerator.new() # Separate from combat RNG; reconstructed from seed on restore.
var movement_version := 4
var difficulty := "normal"
var daily_day := "" # Empty for standard flights; immutable UTC start date for Daily runs.
var daily_attempt := 0 # Distinguishes replays with the same fixed UTC seed.
var stage := 1
var endless_enabled := false
var endless_stage_spec: Dictionary = {}
var encounter_index := 0
var encounter_queue: Array = []
var next_encounter_at := 50.0
var next_pressure_wave_at := 8.0
var pressure_waves := 0
var opening_scout_wave := 0
var boss_attack_pattern := "sweep"
var cooldown_totals: Dictionary = {}
var stage_start := 0.0
var stage_clears := 0
var stage_transition_queued := false
var active_slots: Array = []
var ship_id := "vanguard"
var pilot_id := "rookie"
var artifact_id := "standard"
var mutations: Array = []
var lance_refund_ready := false
# In-flight traveling merchant. Explicitly enabled by the regular-flight UI:
# Daily, existing simulation probes and historical saves are unchanged.
var merchant_enabled := false
var merchant_state := "" # "", "signal", "shop", "confirm"
var merchant_offers: Array = []
var merchant_selected := ""
var merchant_next_at := 1000000000.0
var merchant_seen_stages: Array = []
var merchant_visits := 0
var merchant_trade_count := 0
var merchant_pact_power := 0.0
var merchant_trade_log: Array = []
var sentry_left := 0.0
var sentry_timer := 0.0
var engineer_service_used := false
# Combat skill identities. Rookie/Vale deliberately remains the generic pilot.
var ace_chain := 0
var ace_chain_left := 0.0
var hunter_target_id := -1
var hunter_mark_left := 0.0
var hunter_mark_cooldown := 0.0
var tactician_counter_used := false
var pilot_procs := {"ace":0, "hunter":0, "tactician":0, "engineer":0, "scavenger":0}
# A rival is explicitly configured by the regular-flight UI. Plain Sim.new()
# and all Dailies are rival-free, keeping old balance fixtures comparable.
var rival_record: Dictionary = {}
var rival_stage := 1
var rival_spawn_at := 110.0
var rival_spawned := false
var rival_intro_pending := false
var rival_retire_pending := false
var rival_outcome := "" # "", "retired", "escaped"
var last_killing_source := ""
var next_hazard := 20.0
var tick := 0
var time := 0.0
var hull := 100.0
var max_hull := 100.0
var shield := 50.0
var max_shield := 50.0
var shield_offline := 0.0
var aegis_left := 0.0
var cooldowns := {"aegis": 0.0, "nova": 0.0, "barrage": 0.0, "overdrive": 0.0, "chrono": 0.0, "mend": 0.0}
var upgrades := {"pulse": 1, "seeker": 1, "armor": 0, "regen": 0, "hull": 0, "coolant": 0, "aegis": 0, "nova": 0}
var stage_casts: Dictionary = {}
var escort_left := 0.0
var escort_timer := 0.0
var escort_count := 0
var escort_damage := 0.0
var ion_mines: Array = []
var aftercast_left := 0.0
var overdrive_left := 0.0
var chrono_left := 0.0
var emp_left := 0.0
var barrier_left := 0.0
var focus_left := 0.0
var decoy_left := 0.0
var jammer_left := 0.0
var salvage_left := 0.0
var corrosion_left := 0.0
var heat_left := 0.0
var gravity_left := 0.0
var last_boss_position := Vector2(270, 135)
var boss_spawn_time := 0.0
var prototypes: Array = []
var capacity_milestones: Array = [] # Tracks one-time rank 5/10 hull and shield increases.
var prototype_offers: Array = []
var intermission_step := "" # "", "prototype", "route", "ready"
var route_choice := ""
var stage_power := 1.0
var stage_risk := 1.0
var stage_defense := 1.0 # Shielded passage reduces incoming damage.
var stage_fire_rate := 1.0 # Redline accelerates automatic weapons.
var bounty_earned := 0
var safeguard_used := false
var shieldstorm_pulse_used := false # Resets on warp; retained across checkpoints.
var bonus_cores := 0
var choice_cores := 0 # Flat, banked rewards. Added after payout multipliers at settlement.
var mend_left := 0.0
var mend_rate := 0.0
var emergency_used := false
var arc_timer := 0.0
var lance_timer := 0.0
var rerolls_left := 0
var pilot_rerolls_left := 0 # Tactician bonus lasts one flight; Hangar uses refill each stage.
var banishes_left := 0
var skips_left := 0
var banished: Array = []
var enemies: Array = []
var bullets: Array = []
var shots: Array = []
var effects: Array = []
var charges: Array = []
var events: Array = []
var damage_taken := {"chaff": 0.0, "heavy": 0.0, "ordnance": 0.0, "hazard": 0.0, "ion": 0.0, "corrosion": 0.0, "disrupt": 0.0, "heat": 0.0, "gravity": 0.0, "void": 0.0}
var damage_dealt := {"pulse": 0.0, "seeker": 0.0, "nova": 0.0, "barrage": 0.0, "arc": 0.0, "lance": 0.0}
var xp := 0.0
var level := 1
var kills := 0
var cards: Array = []
var pending_levels := 0
var ended := false
var won := false
var next_spawn := 1.0
var pulse_timer := 0.0
var seeker_timer := 0.0
var heavy_ready_at := 10.0
var boss_spawned := false
var next_id := 1
var ability_uses := 0
var prevented := 0.0
var beams_fired := 0
var beams_cancelled := 0
# Stacked heavy-beam damage in one physics frame offers no extra input window.
var last_heavy_hit_tick := -1
var meta := Catalog.defaults()

func _init(run_seed: int = 1, hangar: Dictionary = {}, selected_ship: String = "vanguard", selected_pilot: String = "rookie", selected_difficulty: String = "normal", selected_artifact: String = "standard") -> void:
	content = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
	for id in Catalog.ABILITIES:
		if not cooldowns.has(id):
			cooldowns[id] = 0.0
		cooldown_totals[id] = float(content.abilities[id].cooldown)
	for fusion in content.fusions:
		content.abilities[str(fusion.id)] = {"name": str(fusion.name), "cooldown": float(fusion.cooldown)}
		cooldowns[str(fusion.id)] = 0.0
		cooldown_totals[str(fusion.id)] = float(fusion.cooldown)
		upgrades[str(fusion.id)] = 0
		content.cards.append({"id":str(fusion.id), "name":str(fusion.name), "tag":"ABILITY", "description":str(fusion.description), "max":10, "rank5":"20% stronger effect, 10% shorter cooldown", "rank10":"45% stronger effect, 20% shorter cooldown"})
	for mutation in Catalog.MUTATIONS:
		content.cards.append({"id":str(mutation.id), "name":str(mutation.name), "tag":"MUTATION", "description":str(mutation.description), "max":1, "min_stage":2})
	for card in content.cards:
		if not upgrades.has(card.id):
			upgrades[card.id] = 0
	ship_id = Catalog.ship(selected_ship).id
	pilot_id = Catalog.pilot(selected_pilot).id
	difficulty = selected_difficulty if selected_difficulty in Catalog.DIFFICULTIES else "normal"
	artifact_id = selected_artifact if not Catalog.artifact(selected_artifact).is_empty() and str(Catalog.artifact(selected_artifact).id) == selected_artifact else "standard"
	seed_value = run_seed
	rng.seed = run_seed
	# Normal World 1 needs an actual encounter inside the first fifteen seconds.
	# Advanced modes retain their deliberately different progression gates.
	next_encounter_at = (12.0 + float(run_seed % 5)) if difficulty == "normal" else (55.0 + float(run_seed % 23))
	_build_course()
	for key in meta:
		meta[key] = int(hangar.get(key, 0))
	var chassis: Dictionary = Catalog.ship(ship_id)
	max_hull = float(chassis.hull) + meta.hull * 10.0
	hull = max_hull
	max_shield = float(chassis.shield) + meta.shield * 8.0 + (20.0 if pilot_id == "engineer" else 0.0)
	shield = max_shield
	upgrades.pulse = int(chassis.pulse) + meta.pulse_start
	upgrades.seeker = int(chassis.seeker) + meta.seeker_start
	upgrades.arc = int(chassis.arc) + int(meta.arc_start)
	upgrades.lance = int(meta.lance_start)
	upgrades.mend = int(chassis.mend)
	var signature: String = chassis.signature
	upgrades[signature] = maxi(1, int(upgrades.get(signature, 0))) + int(meta.signature_rank)
	active_slots = [signature]
	if artifact_id == "glass_fleet":
		max_hull *= 0.50
		hull = max_hull
		max_shield *= 1.25
		shield = max_shield
	elif artifact_id == "drone_armada":
		for weapon in ["pulse", "seeker", "arc", "lance"]:
			upgrades[weapon] = 0
	pilot_rerolls_left = 1 if pilot_id == "tactician" else 0
	rerolls_left = meta.rerolls + pilot_rerolls_left
	banishes_left = meta.banishes
	skips_left = meta.skips

func _build_course() -> void:
	course_pilot.seed = seed_value ^ 0x53746172
	course.clear()
	course.append({"t": -6.0, "p": Vector2(270, 790)})
	course.append({"t": 0.0, "p": Vector2(270, 790)})
	_extend_course(1200.0)

func _extend_course(until_time: float) -> void:
	# Generate only as required. The same seed and independent RNG reproduce
	# the exact path after save/restore, without consuming draft/combat RNG.
	var pilot := course_pilot
	var arrival: float = float(course[-1].t)
	var previous: Vector2 = course[-1].p
	while arrival < until_time:
		var movement: float = float(Catalog.ship(ship_id).movement) if movement_version >= 4 else 1.0
		arrival += (pilot.randf_range(1.65, 2.8) / movement if movement_version >= 4 else (pilot.randf_range(2.2, 4.0) if movement_version >= 3 else pilot.randf_range(3.8, 7.5)))
		var target: Vector2
		if movement_version >= 4:
			target = previous + Vector2(pilot.randf_range(-245, 245), pilot.randf_range(-115, 115))
		elif movement_version >= 3:
			target = previous + Vector2(pilot.randf_range(-220, 220), pilot.randf_range(-72, 72))
		else:
			target = previous + Vector2(pilot.randf_range(-115, 115), pilot.randf_range(-20, 20))
		if pilot.randf() < (0.05 if movement_version >= 4 else (0.10 if movement_version >= 3 else 0.24)):
			target = previous + Vector2(pilot.randf_range(-18, 18), pilot.randf_range(-8, 8))
		target.x = clampf(target.x, 80 if movement_version >= 4 else (100 if movement_version >= 3 else 125), 460 if movement_version >= 4 else (440 if movement_version >= 3 else 415))
		target.y = clampf(target.y, 610 if movement_version >= 4 else (665 if movement_version >= 3 else 755), 835 if movement_version >= 4 else (815 if movement_version >= 3 else 810))
		course.append({"t": arrival, "p": target})
		previous = target

func ship_position(at: float = -1.0) -> Vector2:
	if at < 0.0:
		at = time
	# Keep an old suspended flight's original trajectory; all new flights use the new pilot.
	if movement_version == 1:
		return Vector2(WIDTH * 0.5 + sin(at * TAU / 6.0) * WIDTH * 0.30, 790.0)
	# World 4 and endless can pass the old 1200-second course boundary.
	# Extend before the interpolation lookahead reaches the final segment.
	if at >= float(course[course.size() - 2].t):
		_extend_course(at + 45.0)
	# Binary search avoids re-scanning the growing multi-world course for every projectile.
	var lo := 1
	var hi := course.size() - 2
	while lo < hi:
		var mid := (lo + hi) / 2
		if at > float(course[mid + 1].t):
			lo = mid + 1
		else:
			hi = mid
	var index := lo
	var current: Dictionary = course[index]
	var next: Dictionary = course[index + 1]
	var duration: float = next.t - current.t
	var weight := clampf((at - current.t) / duration, 0, 1)
	var start: Vector2 = current.p
	var end: Vector2 = next.p
	var p0: Vector2 = course[index - 1].p
	var p3: Vector2 = course[mini(index + 2, course.size() - 1)].p
	var velocity0: Vector2 = (end - p0) / float(next.t - course[index - 1].t)
	var velocity1: Vector2 = (p3 - start) / float(course[mini(index + 2, course.size() - 1)].t - current.t)
	# Cubic Bezier is equivalent to Hermite until the control points reach
	# the safety envelope. Keeping handles within it prevents overshooting
	# the gameplay boundary, without snapping the ship or changing old saves.
	var u := weight
	if movement_version >= 4:
		var handle1: Vector2 = start + velocity0 * duration / 3.0
		var handle2: Vector2 = end - velocity1 * duration / 3.0
		handle1.x = clampf(handle1.x, 75.0, 465.0)
		handle2.x = clampf(handle2.x, 75.0, 465.0)
		handle1.y = clampf(handle1.y, 600.0, 850.0)
		handle2.y = clampf(handle2.y, 600.0, 850.0)
		return start * pow(1.0-u, 3) + 3.0 * handle1 * pow(1.0-u, 2) * u + 3.0 * handle2 * (1.0-u) * u*u + end * u*u*u
	return (2*u*u*u - 3*u*u + 1) * start + (u*u*u - 2*u*u + u) * velocity0 * duration + (-2*u*u*u + 3*u*u) * end + (u*u*u - u*u) * velocity1 * duration

func ship_velocity(at: float = -1.0) -> Vector2:
	if at < 0.0:
		at = time
	return (ship_position(at + 0.025) - ship_position(maxf(0, at - 0.025))) / 0.05

func step() -> void:
	if ended or stage_transition_queued or secret_intro_pending or not intermission_step.is_empty() or not merchant_state.is_empty() or not cards.is_empty():
		return
	tick += 1
	time = tick * DT
	for key in cooldowns:
		cooldowns[key] = maxf(0.0, cooldowns[key] - DT)
	aegis_left = maxf(0.0, aegis_left - DT)
	overdrive_left = maxf(0.0, overdrive_left - DT)
	chrono_left = maxf(0.0, chrono_left - DT)
	ace_chain_left = maxf(0.0, ace_chain_left - DT)
	if ace_chain_left <= 0.0:
		ace_chain = 0
	hunter_mark_left = maxf(0.0, hunter_mark_left - DT)
	hunter_mark_cooldown = maxf(0.0, hunter_mark_cooldown - DT)
	for timer in ["aftercast_left", "emp_left", "barrier_left", "focus_left", "decoy_left", "jammer_left", "salvage_left", "corrosion_left", "heat_left", "gravity_left"]:
		set(timer, maxf(0.0, float(get(timer)) - DT))
	if corrosion_left > 0.0:
		var corrosion_damage := DT * 1.4 * stage_damage_scale() * enemy_damage_multiplier() * stage_risk * stage_defense
		corrosion_damage *= status_damage_multiplier()
		if ship_id == "haven":
			corrosion_damage *= 0.75
		hull = maxf(0.0, hull - corrosion_damage * hull_damage_multiplier())
		damage_taken.corrosion += corrosion_damage
		if hull <= 0.0:
			ended = true
			_log("Hull lost to corrosion")
			return
	if mend_left > 0.0:
		hull = minf(max_hull, hull + mend_rate * minf(DT, mend_left))
		mend_left = maxf(0.0, mend_left - DT)
	# Rank 2 of the permanent Hangar repair line is a meaningful milestone.
	# No-Hangar Hard/Insane progression gates remain completely unchanged.
	var repair_rate: float = upgrades.repair_bots * 0.15 + meta.repair * (0.20 if meta.repair >= 2 else 0.15) + (0.25 if ship_id == "haven" else 0.0)
	if rank_at("repair_bots", 5): repair_rate += 0.35
	if rank_at("repair_bots", 10): repair_rate += 0.70
	if passive_link_active("field_recovery"): repair_rate *= 1.40
	hull = minf(max_hull, hull + repair_rate * DT)
	if shield_offline > 0.0:
		shield_offline = maxf(0.0, shield_offline - DT)
	else:
		var recharge: float = (1.5 + upgrades.regen * 0.35 + meta.regen * (0.30 if meta.regen >= 2 else 0.25) + (0.8 if pilot_id == "engineer" else 0.0)) * DT
		if rank_at("regen", 5): recharge += 0.55 * DT
		if rank_at("regen", 10): recharge += 1.0 * DT
		if passive_link_active("shield_cycle"): recharge *= 1.40
		if synergy_active("fortress"):
			recharge *= 1.60
		if _has_prototype("bastion_lattice"):
			recharge *= 1.85
		shield = minf(max_shield, shield + recharge)
	_engineer_service_window()
	for effect in effects:
		effect.life -= DT
	effects = effects.filter(func(e): return e.life > 0.0)
	_update_signal()
	if not boss_spawned and time - stage_start >= (HiddenSector.BOSS_AT if secret_entered else float(content.boss_at)):
		_spawn_boss()
		if secret_intro_pending:
			return
	if time >= next_spawn and not boss_spawned:
		var stage_time := time - stage_start
		# Scouts → warning → strike wing → recovery → counterattack.
		# Delay only 11–13s pre-wing: a long gap starved early XP and
		# changed genuine later-world survivability. Keep builds viable.
		if stage == 1 and difficulty == "normal" and daily_day.is_empty() and stage_time >= 11.0 and stage_time < 13.0:
			next_spawn = stage_start + 13.0
		else:
			_spawn_enemy()
			var pace := maxf(0.55, 1.65 - stage_time / 260.0)
			next_spawn = time + pace / (float(stage_spec().spawn_scale) * enemy_cadence_scale() * stage_risk)
	if stage == 1 and difficulty == "normal" and daily_day.is_empty() and not boss_spawned:
		_spawn_opening_scout_screen()
	if stage == 1 and difficulty == "normal" and not boss_spawned and time >= next_pressure_wave_at:
		_spawn_world1_pressure()
		next_pressure_wave_at = time + 7.5
	if not secret_entered and time >= next_hazard and not boss_spawned:
		_spawn_hazard()
		next_hazard = time + rng.randf_range(15.0, 23.0)
	if merchant_enabled and merchant_state.is_empty() and not boss_spawned and stage in [2, 3] and time >= merchant_next_at:
		_try_merchant_signal()
	if not boss_spawned and not rival_spawned and not rival_record.is_empty() and stage == rival_stage and time - stage_start >= rival_spawn_at:
		_try_spawn_rival()
	if not secret_entered and time >= next_encounter_at and not boss_spawned:
		_spawn_encounter()
		next_encounter_at = time + (35.0 + float((seed_value + encounter_index * 11) % 9) if stage == 1 and difficulty == "normal" else 66.0 + float((seed_value + encounter_index * 11) % 23))
	_update_enemies()
	if secret_entered:
		_update_archive_attack()
		if ended:
			return
	_update_charges()
	_update_support()
	_update_weapons()
	_update_bullets()
	_update_shots()
	# A defeated boss pauses the run for an explicit player-controlled celebration.
	if pending_levels > 0 and not ended and not stage_transition_queued:
		_offer_cards()

func threat_scale() -> float:
	# Insane combat threat is 25% greater than its former 1.6 value.
	# Do not increase spawn count with it: extra kills grant extra XP.
	return {"normal": 1.0, "hard": 1.25, "insane": 2.0}[difficulty]

func enemy_cadence_scale() -> float:
	# Preserve previous spawn frequency so tougher Insane enemies cannot be
	# farmed for additional XP. Carrier launches keep this rate as well.
	return {"normal": 1.0, "hard": 1.25, "insane": 1.6}[difficulty]

func enemy_fire_scale() -> float:
	# Insane fires 25% more ordinary projectiles than before (2.0 vs 1.6),
	# without increasing the number of XP-bearing enemies.
	return {"normal": 1.0, "hard": 1.25, "insane": 2.0}[difficulty]

func boss_projectile_rate_multiplier() -> float:
	# Every boss fires more often. Hard and Insane add boss-specific pressure
	# beyond ordinary enemy fire; minion launches and heavy charge timers stay
	# unchanged, preserving their independently readable counterplay.
	return {"normal": 1.08, "hard": 1.15, "insane": 1.40}[difficulty]

func boss_health_pressure() -> float:
	# Regular enemies retain their existing difficulty health curve.
	# Advanced bosses get a steeper, *separate* difficulty multiplier,
	# and their targetable modules receive exactly the same factor.
	# W1 Hard/Insane already have massive authored opener multipliers, so
	# keep its extra pressure restrained; later bosses carry the escalation.
	if stage == 1:
		return {"normal": 1.10, "hard": 1.12, "insane": 1.35}[difficulty]
	if stage == 2:
		return {"normal": 1.18, "hard": 1.34, "insane": 1.55}[difficulty]
	return {"normal": 1.30, "hard": 1.55, "insane": 1.85}[difficulty]

func boss_projectile_damage_multiplier() -> float:
	# Boss rounds and missiles hurt a little more on higher difficulties.
	# Heavy beams keep their original telegraphed damage and duration.
	return {"normal": 1.0, "hard": 1.05, "insane": 1.12}[difficulty]

func is_pressure_shooter(kind: String) -> bool:
	# This group shoots ordinary projectile patterns, not additional
	# XP-bearing minions, mines, heavy charge lanes or boss volleys.
	return kind in [
		"gunship", "shieldguard", "ion_frigate", "corroder",
		"disruptor", "arc_spire", "forge_turret", "gravity_sentinel"
	]

func shooter_health_pressure(kind: String) -> float:
	# Only slower ranged shooters in Worlds 2+ get HP. Keep World 1 and
	# hazard/boss/beam ecology unchanged for accessible first-run learning.
	if stage <= 1 or not is_pressure_shooter(kind):
		return 1.0
	if stage == 2:
		return {"normal":1.12, "hard":1.16, "insane":1.20}[difficulty]
	return {"normal":1.15, "hard":1.20, "insane":1.25}[difficulty]

func shooter_first_fire_window(kind: String) -> Vector2:
	# Normal World 1 keeps the original initial fire window; special wing
	# arrivals have an explicit, readable first shot timer of their own.
	# A surviving shooter should get a chance to reveal its projectile
	# pattern before the auto-weapons erase it. A shorter *first* timer
	# does not accelerate the ongoing fire interval or increase XP.
	if stage <= 1 or not is_pressure_shooter(kind):
		return Vector2(1.0, 3.0)
	return Vector2(0.95, 1.80) if stage == 2 else Vector2(0.85, 1.65)

func projectile_interval_factor(kind: String) -> float:
	# v1.1: a little more *ordinary gunfire*, with the bigger increase in
	# the relatively quiet first world. Higher worlds already have a stage
	# fire-rate multiplier. Do not create extra XP-bearing minions, extra
	# mine/slag hazards, or shorten the heavy-beam warning/interval.
	if kind in ["carrier", "echo_carrier", "minelayer", "slag_bomber"]:
		return 1.0
	if kind.begins_with("boss"):
		return 0.95  # ~5% more boss projectile fans
	if kind == "missile_bomber":
		return 0.96  # Ordnance is harder to clear than ordinary shots
	return 0.92 if stage == 1 else 0.94  # ~9% W1, ~6% W2+

# Harvester pressure rises during a prolonged opening boss fight on the
# progression difficulties. It is independent of Hangar state, does not
# create extra enemies or XP, and leaves Normal untouched. Faster builds
# can end the fight before the later volleys escalate.
func opener_boss_enrage() -> float:
	if stage != 1 or difficulty == "normal" or not boss_spawned:
		return 1.0
	var elapsed := maxf(0.0, time - boss_spawn_time - 20.0)
	# Long defensive stall builds should not indefinitely out-heal the
	# advanced opening boss. Well-upgraded offense can beat this timer.
	return 1.0 + minf(6.0, elapsed / (25.0 if difficulty == "hard" else 20.0))

func stage_spec() -> Dictionary:
	if secret_entered:
		return HiddenSector.SPEC
	if stage <= int(content.stage_count):
		return content.stages[clampi(stage - 1, 0, content.stages.size() - 1)]
	if int(endless_stage_spec.get("_stage", -1)) != stage:
		var depth := stage - int(content.stage_count)
		var template: Dictionary = content.stages[(stage - 1) % int(content.stage_count)]
		var baseline: Dictionary = content.stages[int(content.stage_count) - 1]
		endless_stage_spec = template.duplicate(true)
		endless_stage_spec._stage = stage
		endless_stage_spec.id = "endless_%d" % stage
		endless_stage_spec.name = "ENDLESS %d · %s" % [depth, template.name]
		endless_stage_spec.subtitle = "Escalation sector"
		endless_stage_spec.boss_name = "%s Ascendant" % template.boss_name
		endless_stage_spec.boss_hp = float(baseline.boss_hp) * pow(1.48, depth)
		endless_stage_spec.health_scale = float(baseline.health_scale) * pow(1.30, depth)
		endless_stage_spec.damage_scale = float(baseline.damage_scale) * pow(1.22, depth)
		endless_stage_spec.spawn_scale = float(baseline.spawn_scale) * pow(1.08, depth)
		endless_stage_spec.fire_scale = float(baseline.fire_scale) * pow(1.07, depth)
		endless_stage_spec.module_scale = float(baseline.module_scale) * pow(1.42, depth)
		endless_stage_spec.transition = "ENDLESS %d" % (depth + 1)
		endless_stage_spec.reward_label = "ENDLESS RUN · BONUS %d" % depth
	return endless_stage_spec

func boss_name() -> String:
	return str(stage_spec().boss_name)

func stage_name() -> String:
	return str(stage_spec().name)

func stage_count() -> int:
	if secret_entered:
		return HiddenSector.WORLD
	return maxi(int(content.stage_count), stage + 1) if endless_enabled else int(content.stage_count)

func enable_endless() -> bool:
	if secret_entered or endless_enabled or stage != int(content.stage_count) or not stage_transition_queued or stage_clears != stage:
		return false
	endless_enabled = true
	_log("Endless unlocked: keeping the existing build")
	return true

func claim_endless() -> bool:
	if not endless_enabled or not stage_transition_queued or stage_clears != stage:
		return false
	stage_transition_queued = false
	ended = true
	won = true
	_log("Endless victory claimed after world %d" % stage)
	return true

func _enemy_limit() -> int:
	# Normal World 1 spawns a more visible crowd, but never allows endless
	# accumulated squads to flatten slow, defensive starting ships.
	if stage == 1 and difficulty == "normal":
		return 11
	return mini(55, 20 + (stage - 1) * 5)

func _has_mutation(id: String) -> bool:
	return id in mutations

func _install_mutation(id: String) -> bool:
	var spec: Dictionary = Catalog.mutation(id)
	if spec.is_empty() or not mutations.is_empty() or int(upgrades.get(str(spec.requires), 0)) <= 0 or artifact_id == "drone_armada":
		return false
	mutations.append(id)
	upgrades[id] = 1
	_log("WEAPON MUTATED - " + str(spec.name))
	return true

func _apply_mutation_cost(id: String) -> void:
	var item: Dictionary = Catalog.mutation(id)
	if item.is_empty():
		return
	max_hull *= float(item.get("hull_factor", 1.0))
	hull = minf(max_hull, hull)
	max_shield *= float(item.get("shield_factor", 1.0))
	shield = minf(max_shield, shield)

func world1_opening_phase() -> String:
	if stage != 1 or difficulty != "normal" or not daily_day.is_empty():
		return ""
	var elapsed: float = time - stage_start
	if elapsed < 8.0: return "scouts"
	if elapsed < 12.0: return "warning"
	if elapsed < 18.0: return "formation"
	if elapsed < 21.0: return "recovery"
	if elapsed < 30.0: return "counterattack"
	return ""

func enable_merchant() -> bool:
	if not daily_day.is_empty() or merchant_enabled or ended:
		return false
	merchant_enabled = true
	if stage in [2,3]:
		_schedule_merchant()
	return true

func _schedule_merchant() -> void:
	merchant_next_at = 1000000000.0
	if not merchant_enabled or not daily_day.is_empty() or merchant_visits >= 2 or stage not in [2,3] or stage in merchant_seen_stages:
		return
	# Independent seed math; never touch combat/draft RNG to decide visits.
	if posmod(seed_value * 13 + stage * 47, 100) < 62:
		merchant_next_at = stage_start + 65.0 + float(posmod(seed_value + stage * 29, 20))

func _make_merchant_offers() -> Array:
	var result: Array = []
	var available: Array = _market_offers()
	if not available.is_empty():
		var item: Dictionary = available[posmod(seed_value + stage * 17, available.size())]
		result.append({"id":"mutation:" + str(item.id), "name":"EXOTIC · " + str(item.name), "gain":str(item.description), "cost":str(item.market_cost), "tag":"ILLEGAL TECH"})
	if merchant_pact_power <= 0.0:
		result.append({"id":"pact", "name":"Hot Reactor", "gain":"+35% automatic weapon damage for the rest of this flight.", "cost":"Give up 22% maximum shield capacity this flight.", "tag":"HULL PACT"})
	var old_slot := ""
	for id in active_slots:
		if str(id) != str(Catalog.ship(ship_id).signature) and fusion_spec(str(id)).is_empty():
			old_slot = str(id)
			break
	if not old_slot.is_empty():
		var new_id := ""
		for candidate in ["emp","deflector","flak","jammer","overdrive","decoy","barrier"]:
			if candidate not in active_slots and int(upgrades.get(candidate,0)) == 0 and fusion_spec(candidate).is_empty():
				new_id = candidate
				break
		if not new_id.is_empty():
			result.append({"id":"exchange:" + old_slot + ":" + new_id, "name":"Ability Exchange", "gain":"Replace %s with %s at rank 1; no extra ability slot." % [str(content.abilities[old_slot].name), str(content.abilities[new_id].name)], "cost":"Surrender every invested rank in %s." % str(content.abilities[old_slot].name), "tag":"UNLICENSED SWAP"})
	if hull < max_hull * 0.90 or shield < max_shield * 0.75:
		result.append({"id":"repair", "name":"Field Salvage", "gain":"Repair 40% of max hull and refill 30% of max shield.", "cost":"Spend 8 Cores already earned during this flight (no future credit).", "tag":"SALVAGE"})
	result.append({"id":"sell_hull", "name":"Wreckage Contract", "gain":"Bank 16 bonus Cores for the flight's final payout.", "cost":"Give up 18% of maximum hull capacity this flight.", "tag":"SALVAGE PACT"})
	return result.slice(0, 5)

func _try_merchant_signal() -> bool:
	if not merchant_enabled or not daily_day.is_empty() or not merchant_state.is_empty() or merchant_visits >= 2 or stage not in [2,3] or stage in merchant_seen_stages or boss_spawned or time < merchant_next_at:
		return false
	# Don't stack a trading interlude on a nemesis, heavy warning, or boss.
	if enemies.size() >= _enemy_limit() - 7 or not charges.is_empty() or enemies.any(func(e): return bool(e.get("rival", false))):
		return false
	merchant_offers = _make_merchant_offers()
	merchant_seen_stages.append(stage)
	merchant_visits += 1
	merchant_next_at = 1000000000.0
	merchant_selected = ""
	merchant_state = "signal"
	_log("UNREGISTERED MERCHANT - ship hailing at the edge of the convoy")
	return true

func merchant_hail() -> bool:
	if merchant_state != "signal":
		return false
	merchant_state = "shop"
	return true

func merchant_preview(id: String) -> bool:
	if merchant_state != "shop" or not merchant_offers.any(func(offer): return str(offer.id) == id):
		return false
	merchant_selected = id
	merchant_state = "confirm"
	return true

func merchant_back() -> bool:
	if merchant_state != "confirm":
		return false
	merchant_state = "shop"
	merchant_selected = ""
	return true

func merchant_offer_spec(id: String) -> Dictionary:
	for offer in merchant_offers:
		if str(offer.id) == id:
			return offer
	return {}

func merchant_can_afford(id: String) -> bool:
	if id.begins_with("mutation:"):
		var mutation: Dictionary = Catalog.mutation(id.trim_prefix("mutation:"))
		return not mutation.is_empty() and mutations.is_empty() and artifact_id != "drone_armada" and int(upgrades.get(str(mutation.requires),0)) > 0
	if id == "pact":
		return merchant_pact_power <= 0.0
	if id == "sell_hull":
		return max_hull > 35.0
	if id == "repair":
		return choice_cores + bonus_cores >= 8
	if id.begins_with("exchange:"):
		var old_id: String = id.get_slice(":",1)
		var new_id: String = id.get_slice(":",2)
		return old_id in active_slots and old_id != str(Catalog.ship(ship_id).signature) and fusion_spec(old_id).is_empty() and int(upgrades.get(new_id,0)) == 0 and new_id not in active_slots and new_id in Catalog.ABILITIES
	return false

func merchant_accept() -> bool:
	if merchant_state != "confirm" or merchant_selected.is_empty() or merchant_offer_spec(merchant_selected).is_empty() or not merchant_can_afford(merchant_selected):
		return false
	var chosen: String = merchant_selected
	match chosen:
		"pact":
			max_shield *= 0.78
			shield = minf(shield,max_shield)
			merchant_pact_power = 0.35
		"repair":
			var remaining := 8
			var from_bounty: int = mini(remaining,bonus_cores)
			bonus_cores -= from_bounty
			remaining -= from_bounty
			choice_cores -= remaining
			hull = minf(max_hull,hull + max_hull * 0.40)
			shield = minf(max_shield,shield + max_shield * 0.30)
		"sell_hull":
			max_hull *= 0.82
			hull = minf(max_hull,hull)
			choice_cores += 16
		_:
			if chosen.begins_with("mutation:"):
				var mutation_id: String = chosen.trim_prefix("mutation:")
				if not _install_mutation(mutation_id):
					return false
				_apply_mutation_cost(mutation_id)
			elif chosen.begins_with("exchange:"):
				var old_id: String = chosen.get_slice(":",1)
				var new_id: String = chosen.get_slice(":",2)
				var slot_index: int = active_slots.find(old_id)
				if slot_index < 0:
					return false
				upgrades[old_id] = 0
				upgrades[new_id] = 1
				active_slots[slot_index] = new_id
				cooldowns[new_id] = 0.0
				cooldown_totals[new_id] = float(content.abilities[new_id].cooldown)
			else:
				return false
	merchant_trade_count += 1
	merchant_trade_log.append(chosen)
	merchant_state = ""
	merchant_selected = ""
	merchant_offers.clear()
	_log("MERCHANT TRADE COMPLETE - " + chosen)
	return true

func merchant_leave() -> bool:
	if merchant_state not in ["signal","shop","confirm"]:
		return false
	merchant_state = ""
	merchant_selected = ""
	merchant_offers.clear()
	_log("Merchant signal dismissed")
	return true

func _market_offers() -> Array:
	if not mutations.is_empty() or artifact_id == "drone_armada":
		return []
	var offers: Array = []
	for mutation in Catalog.MUTATIONS:
		if int(upgrades.get(str(mutation.requires), 0)) > 0:
			offers.append(mutation)
	return offers

func _has_prototype(id: String) -> bool:
	return id in prototypes

func fusion_spec(id: String) -> Dictionary:
	for fusion in content.fusions:
		if str(fusion.id) == id:
			return fusion
	return {}

func fused_into(id: String) -> String:
	for fusion in content.fusions:
		if str(fusion.id) in active_slots and id in fusion.parts:
			return str(fusion.id)
	return ""

func stage_damage_scale() -> float:
	var scale: float = float(stage_spec().get("damage_scale", 1.0))
	# Each warp is followed by new status effects and stronger enemies. Ease
	# players into those mechanics without handing out extra kills or XP.
	# The encounter reaches its full authored damage well before the boss.
	if stage in [2, 3, 4] and not boss_spawned:
		var entry_factor := 0.75 if stage == 2 else (0.82 if stage == 3 else 0.65)
		var full_at := 155.0 if stage == 2 else (170.0 if stage == 3 else 195.0)
		var ramp: float = clampf((time - stage_start - 25.0) / (full_at - 25.0), 0.0, 1.0)
		scale *= lerpf(entry_factor, 1.0, ramp)
	return scale

# Later worlds trade slightly less enemy durability for more dangerous hits.
# World 1 and endless are untouched to protect the opening progression gate.
func enemy_health_multiplier() -> float:
	return 0.90 if stage in [2, 3, 4] else 1.0

func enemy_damage_multiplier() -> float:
	return 1.05 if stage in [2, 3, 4] else 1.0

func passive_bonus(id: String, per_rank: float, at_five: float, at_ten: float) -> float:
	return int(upgrades.get(id, 0)) * per_rank + (at_five if rank_at(id, 5) else 0.0) + (at_ten if rank_at(id, 10) else 0.0)

func status_damage_multiplier() -> float:
	# Insulation now resists damaging status attacks as well as reducing
	# their duration. Rank 5: 7% resisted; rank 10: 15% resisted.
	return 1.0 - passive_bonus("insulation", 0.008, 0.03, 0.04)

func status_duration_scale() -> float:
	return (1.0 - passive_bonus("insulation", 0.03, 0.10, 0.10)) * (1.0 - meta.hazard_seals * 0.05)

func _source_active(id: String) -> bool:
	if id in active_slots:
		return true
	for fusion in content.fusions:
		if str(fusion.id) in active_slots and id in fusion.parts:
			return true
	return false

const FUSION_RANK := 5

func fusion_target(id: String) -> String:
	# Preview only a pick that will actually complete a rank-5 pair.
	var current := int(upgrades.get(id, 0))
	var after_pick := mini(10, current + (1 if current == 0 else 2))
	for fusion in content.fusions:
		if id in fusion.parts:
			var other: String = str(fusion.parts[1]) if str(fusion.parts[0]) == id else str(fusion.parts[0])
			if id in active_slots and other in active_slots and after_pick >= FUSION_RANK and int(upgrades[other]) >= FUSION_RANK:
				return str(fusion.id)
	return ""

func fusion_hint(id: String) -> String:
	var target := fusion_target(id)
	if target.is_empty(): return ""
	var spec := fusion_spec(target)
	return str(spec.name) + ": " + str(spec.description) + " (frees one slot)"

func _can_learn_active(_id: String) -> bool:
	# New actives start at rank 1, so none can bypass a full bar by fusing.
	return active_slots.size() < Catalog.ACTIVE_SLOTS

func _try_fuse() -> void:
	for fusion in content.fusions:
		var first: String = str(fusion.parts[0])
		var second: String = str(fusion.parts[1])
		if first not in active_slots or second not in active_slots or int(upgrades[first]) < FUSION_RANK or int(upgrades[second]) < FUSION_RANK:
			continue
		var insert_at: int = mini(active_slots.find(first), active_slots.find(second))
		var current_cd: float = maxf(float(cooldowns.get(first, 0.0)), float(cooldowns.get(second, 0.0)))
		active_slots.erase(first)
		active_slots.erase(second)
		active_slots.insert(insert_at, str(fusion.id))
		upgrades[str(fusion.id)] = 1
		cooldowns[str(fusion.id)] = current_cd
		effects.append({"kind":"fusion-formed", "fusion":str(fusion.id), "p":ship_position(), "life":1.2, "max_life":1.2, "born":tick})
		_log(str(content.abilities[first].name) + " + " + str(content.abilities[second].name) + " became " + str(fusion.name) + ". One slot freed.")

func active_passive_links() -> Array:
	var pairs: Array = []
	for link in content.passive_links:
		if int(upgrades.get(str(link.requires[0]), 0)) > 0 and int(upgrades.get(str(link.requires[1]), 0)) > 0:
			pairs.append(link)
	return pairs

func passive_link_active(id: String) -> bool:
	for link in active_passive_links():
		if str(link.id) == id:
			return true
	return false

func passive_hint(id: String) -> String:
	for link in content.passive_links:
		if id in link.requires:
			var other: String = str(link.requires[1]) if str(link.requires[0]) == id else str(link.requires[0])
			if int(upgrades.get(other, 0)) > 0:
				return str(link.name) + ": " + str(link.description)
	return ""

func rank_at(id: String, milestone: int) -> bool:
	return int(upgrades.get(id, 0)) >= milestone

func _active_rank_scale(id: String) -> float:
	var sources: Array = [id]
	var spec: Dictionary = fusion_spec(id)
	if not spec.is_empty():
		sources = spec.parts
	var total := 0.0
	for source in sources:
		var rank: int = int(upgrades.get(str(source), 0))
		total += 1.0 + (0.20 if rank >= 5 else 0.0) + (0.25 if rank >= 10 else 0.0)
	var inherited := total / maxf(1.0, float(sources.size()))
	if not spec.is_empty():
		inherited *= 1.0 + maxf(0, int(upgrades[id]) - 1) * 0.04 + (0.20 if rank_at(id, 5) else 0.0) + (0.25 if rank_at(id, 10) else 0.0)
	return inherited

func _active_rank_cooldown(id: String) -> float:
	var sources: Array = [id]
	var spec: Dictionary = fusion_spec(id)
	if not spec.is_empty():
		sources = spec.parts
	var total := 0.0
	for source in sources:
		var rank: int = int(upgrades.get(str(source), 0))
		total += 1.0 - (0.10 if rank >= 5 else 0.0) - (0.10 if rank >= 10 else 0.0)
	var inherited := total / maxf(1.0, float(sources.size()))
	if not spec.is_empty():
		inherited *= 1.0 - (0.10 if rank_at(id, 5) else 0.0) - (0.10 if rank_at(id, 10) else 0.0)
	return inherited

func active_synergies() -> Array:
	var found: Array = []
	for spec in content.synergies:
		var has_first := false
		var has_second := false
		for id in spec.first:
			if _source_active(str(id)):
				has_first = true
		for id in spec.second:
			if _source_active(str(id)):
				has_second = true
		if has_first and has_second:
			found.append(spec)
	return found

func synergy_active(id: String) -> bool:
	for item in active_synergies():
		if str(item.id) == id:
			return true
	return false

func synergy_hint(ability: String) -> String:
	if ability in active_slots:
		return ""
	for spec in content.synergies:
		if synergy_active(str(spec.id)):
			continue
		var belongs_first: bool = ability in spec.first
		var belongs_second: bool = ability in spec.second
		if (belongs_first and spec.second.any(func(other): return _source_active(str(other)))) or (belongs_second and spec.first.any(func(other): return _source_active(str(other)))):
			return str(spec.name) + ": " + str(spec.description)
	return ""

func _alive_modules(role: String = "") -> int:
	var count := 0
	for enemy in enemies:
		if enemy.kind == "boss_module" and enemy.hp > 0.0 and (role.is_empty() or str(enemy.role) == role):
			count += 1
	return count

func _boss_core() -> Dictionary:
	for enemy in enemies:
		if _is_boss(str(enemy.kind)) and enemy.hp > 0.0:
			return enemy
	return {}

func _is_boss(kind: String) -> bool:
	return kind.begins_with("boss") and kind != "boss_module"

func boss_phase_label() -> String:
	if not boss_spawned:
		return ""
	if secret_entered:
		if not archive_attack.is_empty():
			return "CAST AN ABILITY TO BREAK THE LOCK"
		return "CORE EXPOSED" if time < archive_exposed_until else ["READING YOUR FLIGHT", "LATTICE RECONFIGURING", "COLLAPSE IMMINENT"][archive_phase]
	if stage == 1:
		return "BEAM CHARGING - INTERRUPT" if not charges.is_empty() else "LASER PREPARING"
	if stage == 2:
		return "LAUNCH BAYS ONLINE" if _alive_modules("launch_bay") > 0 else "LAUNCH BAYS DESTROYED"
	if stage == 3:
		if _alive_modules("vent") == 0:
			return "CORE EXPOSED - VENTS DESTROYED"
		return "CORE EXPOSED" if floori((time - boss_spawn_time) / 9.0) % 2 == 1 else "FURNACE SEALED - TARGET VENTS"
	if stage == 4:
		if _alive_modules("pylon") > 0:
			return "SHIELD PYLONS ACTIVE"
		var core: Dictionary = _boss_core()
		return "FINAL ONSLAUGHT" if not core.is_empty() and float(core.hp) / float(core.max_hp) < 0.35 else "CORE SHIELD DOWN"
	return ""

func begin_intermission() -> bool:
	if not stage_transition_queued or stage >= stage_count() or not intermission_step.is_empty():
		return false
	var available: Array = []
	for spec in content.prototypes:
		if spec.id not in prototypes:
			available.append(str(spec.id))
	prototype_offers.clear()
	while prototype_offers.size() < mini(3, available.size()):
		prototype_offers.append(available.pop_at(rng.randi_range(0, available.size() - 1)))
	# One third of boss intermissions reveal an optional, costly mutation
	# in the third offer slot. It replaces a Prototype; no extra free pick.
	if not prototype_offers.is_empty() and stage <= 3 and rng.randi_range(0, 2) == 0:
		var market: Array = _market_offers()
		if not market.is_empty():
			var offered: Dictionary = market[rng.randi_range(0, market.size() - 1)]
			prototype_offers[prototype_offers.size() - 1] = "market:" + str(offered.id)
	intermission_step = "route" if prototype_offers.is_empty() else "prototype"
	return true

func prototype_spec(id: String) -> Dictionary:
	if id.begins_with("market:"):
		var mutation: Dictionary = Catalog.mutation(id.trim_prefix("market:"))
		if mutation.is_empty():
			return {}
		return {"id":id, "name":"BLACK MARKET · " + str(mutation.name), "role":"ILLEGAL TRADE", "benefit":str(mutation.description), "cost":str(mutation.market_cost)}
	for spec in content.prototypes:
		if spec.id == id:
			return spec
	return {}

func choose_prototype(index: int) -> bool:
	if intermission_step != "prototype" or index < 0 or index >= prototype_offers.size():
		return false
	var id: String = str(prototype_offers[index])
	if prototype_spec(id).is_empty():
		return false
	if id.begins_with("market:"):
		var mutation_id: String = id.trim_prefix("market:")
		if not _install_mutation(mutation_id):
			return false
		_apply_mutation_cost(mutation_id)
		intermission_step = "route"
		_log("Black market trade accepted - equipment sacrificed for " + str(Catalog.mutation(mutation_id).name))
		return true
	if id in prototypes:
		return false
	prototypes.append(id)
	if id == "mirror_cell":
		var old_capacity: float = max_shield
		max_shield *= 1.60
		shield = minf(max_shield, shield + old_capacity * 0.60)
	intermission_step = "route"
	_log("Prototype installed: " + str(prototype_spec(id).name))
	return true

func skip_prototype() -> bool:
	if intermission_step != "prototype":
		return false
	choice_cores += PROTOTYPE_SKIP_CORES
	intermission_step = "route"
	_log("Prototype passed: +%d banked Cores" % PROTOTYPE_SKIP_CORES)
	return true

func choose_route(id: String) -> bool:
	if intermission_step != "route" or id not in ["repair", "overclock", "bounty"]:
		return false
	route_choice = id
	intermission_step = "ready"
	_log("Warp route selected: " + id)
	return true

func can_enter_secret() -> bool:
	return daily_day.is_empty() and not endless_enabled and not secret_entered and not ended and stage == int(content.stage_count) and stage_clears == stage and stage_transition_queued and signal_count >= HiddenSector.REQUIRED_SIGNALS

func _update_signal() -> void:
	if not daily_day.is_empty() or stage not in [2, 3, 4] or signal_count >= HiddenSector.REQUIRED_SIGNALS:
		return
	if signal_status.is_empty() and time - stage_start >= HiddenSector.signal_time(seed_value, stage):
		signal_until = stage_start + 195.0
		signal_status = "offer" if time < signal_until else "missed"
	elif signal_status in ["offer", "cast", "courier"] and time >= signal_until:
		signal_status = "missed"

func choose_signal(action: String) -> bool:
	if not daily_day.is_empty() or ended or stage_transition_queued or signal_status != "offer" or time >= signal_until or stage not in [2, 3, 4] or endless_enabled:
		return false
	match action:
		"cast":
			signal_status = "cast"
			signal_until = time + 52.0
		"courier":
			signal_status = "courier"
			signal_until = time + 24.0
			# A dedicated contact is seeded without touching the campaign RNG.
			var x: float = 115.0 + float(posmod(seed_value + stage * 73, 311))
			var hp: float = 240.0 * stage * sqrt(threat_scale())
			enemies.append({"id":next_id, "kind":"archive_courier", "p":Vector2(x, 230), "hp":hp, "max_hp":hp, "speed":26.0, "fire":2.2, "xp":0, "phase":0.0})
			next_id += 1
		"ignore":
			signal_status = "missed"
		_:
			return false
	return true

func signal_cast_window() -> bool:
	return signal_status == "cast" and time < signal_until and fposmod(signal_until - time, 8.0) <= 4.0

func _receive_signal() -> void:
	signal_status = "received"
	signal_count += 1
	_log("ARCHIVE COORDINATES · %d/%d signals recovered" % [signal_count, HiddenSector.REQUIRED_SIGNALS])

func enter_secret() -> bool:
	if not can_enter_secret():
		return false
	secret_payout = payout()
	secret_entered = true
	intermission_step = "ready"
	route_choice = "repair"
	return advance_stage()

func dismiss_secret_intro() -> bool:
	if not secret_intro_pending:
		return false
	secret_intro_pending = false
	return true

func _spawn_archive_patrol() -> void:
	# Destroy the relay and the flanking ships lose their coordinated burst.
	var leader: int = next_id
	var center := rng.randf_range(150.0, 390.0)
	_add_enemy("archive_relay", Vector2(center, -18.0))
	enemies[-1].fire = 3.4
	for side in [-1, 1]:
		_add_enemy("archive_shard", Vector2(center + side * 86.0, -40.0))
		enemies[-1]["archive_relay"] = leader
		enemies[-1].fire = 3.4

func _spawn_enemy() -> void:
	if secret_entered:
		if enemies.size() < 15:
			if encounter_index % 5 == 0:
				_spawn_archive_patrol()
			else:
				_add_enemy("archive_shard", Vector2(rng.randf_range(55, 485), -35))
			encounter_index += 1
		return
	if enemies.size() >= _enemy_limit():
		return
	# Each authored enemy ecology recurs, but endless mixes threats from later worlds.
	var stage_time := time - stage_start
	var pool: Array = []
	match ((stage - 1) % int(content.stage_count)) + 1:
		1:
			pool = ["drone", "drone", "drone", "rusher"]
			if stage_time > 25:
				pool.append_array(["interceptor", "gunship", "drone"])
			if stage_time > 65:
				pool.append_array(["sniper", "missile_bomber", "interceptor"])
			if stage_time > 110:
				pool.append_array(["carrier", "shieldguard", "minelayer", "missile_bomber"])
			if stage_time > 170:
				pool.append_array(["shieldguard", "minelayer", "carrier"])
			if difficulty == "insane" and stage_time > 150:
				pool.append("ion_frigate")
		2:
			pool = ["ion_frigate", "storm_weaver", "interceptor", "ion_frigate", "disruptor"]
			if stage_time > 50:
				pool.append_array(["arc_spire", "corroder", "shieldguard", "storm_weaver"])
			if stage_time > 115:
				pool.append_array(["missile_bomber", "arc_spire", "corroder", "disruptor"])
		3:
			pool = ["ember_hunter", "forge_turret", "splitter", "ember_hunter", "gunship"]
			if stage_time > 45:
				pool.append_array(["slag_bomber", "forge_turret", "splitter", "minelayer"])
			if stage_time > 105:
				pool.append_array(["slag_bomber", "ember_hunter", "forge_turret", "carrier"])
		4:
			pool = ["phase_stalker", "void_lancer", "phase_stalker", "gravity_sentinel", "disruptor"]
			if stage_time > 45:
				pool.append_array(["echo_carrier", "void_lancer", "gravity_sentinel", "phase_stalker"])
			if stage_time > 110:
				pool.append_array(["echo_carrier", "void_lancer", "arc_spire", "slag_bomber"])

	if not encounter_queue.is_empty():
		# A formation consumes normal spawn opportunities, not extra waves of XP.
		var formation_slot: int = 3 - encounter_queue.size()
		# Existing saves can still contain plain string queues. New elite
		# queues carry leader/wing information without a save format bump.
		var queued: Variant = encounter_queue.pop_front()
		var queued_kind: String = str(queued.get("kind", "")) if queued is Dictionary else str(queued)
		_add_enemy(queued_kind, Vector2(120.0 + formation_slot * 150.0, -50.0 - formation_slot * 65.0))
		if queued is Dictionary and not enemies.is_empty():
			var unit: Dictionary = enemies[-1]
			unit["elite_squad"] = int(queued.get("squad", -1))
			unit["elite_role"] = "leader" if bool(queued.get("leader", false)) else "wing"
			unit["elite_disrupted"] = bool(queued.get("disrupted", false))
			if unit.elite_role == "leader":
				unit.max_hp *= 1.20
				unit.hp = unit.max_hp
				unit.fire = 1.10
			elif unit.elite_disrupted:
				unit.fire = maxf(float(unit.fire), 1.8)
			else:
				unit.fire = 1.25
		return
	if endless_enabled and stage > int(content.stage_count):
		pool.append_array(["phase_stalker", "slag_bomber", "ion_frigate", "shieldguard", "void_lancer"])
	var kind: String = pool[rng.randi_range(0, pool.size() - 1)]
	_add_enemy(kind, Vector2(rng.randf_range(55, 485), -35))

func _add_enemy(kind: String, position: Vector2) -> void:
	var spec: Dictionary = HiddenSector.ENEMIES[kind] if HiddenSector.ENEMIES.has(kind) else content.enemies[kind]
	var scaling := (1.0 + (time - stage_start) / 340.0) * float(stage_spec().health_scale) * threat_scale() * stage_risk * enemy_health_multiplier() * shooter_health_pressure(kind)
	var first_fire := shooter_first_fire_window(kind)
	enemies.append({"id": next_id, "kind": kind, "p": position, "hp": float(spec.hp) * scaling, "max_hp": float(spec.hp) * scaling, "speed": float(spec.speed), "fire": rng.randf_range(first_fire.x, first_fire.y), "xp": int(spec.xp), "phase": rng.randf_range(0, TAU)})
	next_id += 1

## Encounter variants are reproducible by seed. Worlds 2-4 sometimes promote
## the same three normal spawn slots into an elite leader/wing formation.
## Breaking the leader cancels coordination, not enemies, XP or future waves.
func _elite_leader_active(wing: Dictionary) -> bool:
	if str(wing.get("elite_role", "")) != "wing" or bool(wing.get("elite_disrupted", false)):
		return false
	var leader_id: int = int(wing.get("elite_squad", -1))
	for other in enemies:
		if int(other.id) == leader_id and float(other.hp) > 0.0 and str(other.get("elite_role", "")) == "leader":
			return true
	return false

func _spawn_encounter() -> void:
	if enemies.size() >= _enemy_limit() - 5 or not encounter_queue.is_empty():
		return
	if stage == 1 and difficulty == "normal":
		# If slow guns are already holding a crowded screen, do not pile
		# another formation on top of it just to hit a clock.
		if _visible_world1_enemies() < 3:
			_spawn_world1_strike_wing()
		return
	var ecology := ((stage - 1) % int(content.stage_count)) + 1
	var pattern := (seed_value + stage * 7 + encounter_index * 5) % 3
	# One elite squad in every two natural encounter opportunities; never
	# World 1, boss phases, or an extra third-party spawn/kill payout.
	var elite: bool = stage in [2, 3, 4] and (encounter_index + seed_value) % 2 == 0
	encounter_index += 1
	var formation: Array = []
	match pattern:
		0:
			formation = ["shieldguard", "interceptor", "gunship"] if ecology == 1 else (["shieldguard", "ion_frigate", "storm_weaver"] if ecology == 2 else (["shieldguard", "ember_hunter", "splitter"] if ecology == 3 else ["shieldguard", "phase_stalker", "disruptor"]))
			_log("ESCORT FORMATION - armored lead, interceptors flanking")
		1:
			formation = ["missile_bomber", "minelayer", "missile_bomber"] if ecology == 1 else (["missile_bomber", "arc_spire", "ion_frigate"] if ecology == 2 else (["slag_bomber", "forge_turret", "slag_bomber"] if ecology == 3 else ["void_lancer", "gravity_sentinel", "void_lancer"]))
			_log("BOMBER CONVOY - ordnance incoming")
		2:
			formation = ["carrier", "gunship", "interceptor"] if ecology == 1 else (["carrier", "shieldguard", "disruptor"] if ecology == 2 else (["carrier", "slag_bomber", "ember_hunter"] if ecology == 3 else ["echo_carrier", "phase_stalker", "gravity_sentinel"]))
			_log("CARRIER ESCORT - prioritize the launch ship")
	if elite:
		var leader_id: int = next_id
		encounter_queue.clear()
		for index in range(formation.size()):
			encounter_queue.append({
				"kind":str(formation[index]), "squad":leader_id,
				"leader":index == 0, "disrupted":false
			})
		_log("ELITE FORMATION - destroy the marked leader to disrupt escorts")
	else:
		encounter_queue = formation.duplicate()

func _spawn_opening_scout_screen() -> void:
	# A deliberate series of early, attackable contact groups. They grant
	# no XP and leave the combat/draft RNG unchanged. Their first shots have
	# a long lead-in so fragile starters see threats before being punished.
	var times := [1.5, 5.5, 9.0, 21.5]
	if opening_scout_wave >= times.size() or time - stage_start < float(times[opening_scout_wave]):
		return
	var phase: int = opening_scout_wave
	opening_scout_wave += 1
	var count: int = mini(2, maxi(0, mini(_enemy_limit() - enemies.size(), 3 - _visible_world1_enemies())))
	for index in range(count):
		var enemy_type := "drone" if (phase + index) % 3 == 0 else ("interceptor" if phase != 3 else "gunship")
		var x: float = 135.0 if index == 0 else 405.0
		var y: float = 95.0 if phase < 2 else 120.0
		var rng_before: int = rng.state
		_add_enemy(enemy_type, Vector2(x, y + float(index) * 32.0))
		rng.state = rng_before
		var scout: Dictionary = enemies[-1]
		scout["opening_scout"] = true
		scout["pressure_wing"] = true
		scout["xp"] = 0
		scout["max_hp"] *= 0.85 if phase < 2 else 0.70
		scout["opening_scout_expires"] = time + 3.8
		scout.hp = scout.max_hp
		scout.fire = 4.5 if phase == 0 else (3.2 if phase == 1 else 2.5)
	if count > 0:
		_log("SCOUT SWEEP - unregistered contacts" if phase < 2 else "ESCORTS INBOUND - prepare for the strike")

func _spawn_world1_strike_wing() -> void:
	# Three enemies ARRIVE TOGETHER instead of in widely separated singles.
	# Advance the next ordinary spawn by three slots: no three extra XP-bearing
	# kills on top of the regular wave schedule, no change to Hard/Insane.
	var elapsed: float = time - stage_start
	var pattern: int = (seed_value + encounter_index * 5) % 3
	var formation: Array = ["gunship", "drone", "interceptor"]
	if elapsed >= 48.0:
		match pattern:
			0: formation = ["shieldguard", "interceptor", "gunship"]
			1: formation = ["missile_bomber", "drone", "rusher"]
			2: formation = ["sniper", "gunship", "interceptor"]
	encounter_index += 1
	for index in range(3):
		_add_enemy(str(formation[index]), Vector2(100.0 + index * 165.0, 38.0 - index * 16.0))
		var member: Dictionary = enemies[-1]
		member["strike_wing"] = true
		# Only the grouped attackers gain a modest window to reveal their
		# patterns before automatic fire clears the formation.
		member.max_hp *= 1.20
		member.hp = member.max_hp
		member.fire = 1.85 + index * 0.20
	var pace := maxf(0.55, 1.65 - elapsed / 260.0)
	next_spawn = maxf(next_spawn, time) + 3.0 * pace / (float(stage_spec().spawn_scale) * enemy_cadence_scale() * stage_risk)
	_log("STRIKE WING - coordinated enemy attack")

func _visible_world1_enemies() -> int:
	var visible := 0
	for enemy in enemies:
		var p: Vector2 = enemy.p
		if enemy.hp > 0.0 and p.x >= 0.0 and p.x <= WIDTH and p.y >= 0.0 and p.y <= 920.0:
			visible += 1
	return visible

func _spawn_world1_pressure() -> void:
	# The opening director fills EMPTY space, not low ship statistics.
	# Extra pressure ships are genuine, attackable enemies, but do not
	# grant XP or turn strong early builds into an endless upgrade fountain.
	var count: int = mini(1, maxi(0, 2 - _visible_world1_enemies()))
	count = mini(count, maxi(0, _enemy_limit() - enemies.size()))
	if count <= 0:
		return
	for index in range(count):
		var kind: String = ["gunship", "interceptor", "drone"][(seed_value + pressure_waves + index) % 3]
		_add_enemy(kind, Vector2(135.0 + 270.0 * index, 72.0 + 30.0 * index))
		var wing: Dictionary = enemies[-1]
		wing["strike_wing"] = true
		wing["pressure_wing"] = true
		wing.xp = 0
		wing.max_hp *= 1.65
		wing.hp = wing.max_hp
		wing.fire = 2.20 + index * 0.20
	pressure_waves += 1
	_log("STRIKE WING REINFORCEMENTS - no additional XP")

func configure_rival(record: Dictionary) -> bool:
	# Called only for selected regular flights, never by stress fixture
	# constructors. A run has at most one captain regardless of stage.
	if not daily_day.is_empty() or ended or not rival_record.is_empty():
		return false
	if int(record.get("version", 0)) != 1 or int(record.get("id", 0)) <= 0:
		return false
	if str(record.get("name", "")).is_empty() or str(record.get("trait", "")) not in ["charged_barrage", "interceptor_screen", "reactive_shield", "hunter_lock", "mine_scatter"]:
		return false
	rival_record = record.duplicate(true)
	rival_stage = clampi(int(record.get("world_created", 1)), 1, 3)
	rival_spawn_at = 127.0 if rival_stage == 1 else 78.0
	return true

func _try_spawn_rival() -> bool:
	if rival_spawned or rival_record.is_empty() or not daily_day.is_empty() or boss_spawned or stage != rival_stage or enemies.size() >= _enemy_limit() - 3:
		return false
	var kind: String = str(rival_record.get("combat_kind", "gunship"))
	if not content.enemies.has(kind) or kind in ["boss", "boss2", "boss3", "boss4", "boulder"]:
		kind = "gunship"
	_add_enemy(kind, Vector2(270.0, 62.0))
	var captain: Dictionary = enemies[-1]
	captain["rival"] = true
	captain["rival_id"] = int(rival_record.id)
	captain["rival_trait"] = str(rival_record.trait)
	captain["rival_rank"] = mini(3, maxi(1, int(rival_record.get("defeat_count", 1)) + int(rival_record.get("times_escaped", 0))))
	captain["rival_timer"] = 2.8
	captain["rival_shield_left"] = 0.0
	captain["rival_shield_cooldown"] = 0.0
	captain["rival_trait_used"] = 0
	captain.speed *= 0.33
	captain.max_hp = minf(740.0, maxf(160.0, float(captain.max_hp) * 4.5) * (1.0 + 0.15 * float(int(captain.rival_rank) - 1)))
	captain.hp = captain.max_hp
	captain.xp = 0
	captain.fire = 3.2
	rival_spawned = true
	rival_intro_pending = true
	_log("RIVAL SIGHTED - " + str(rival_record.name))
	return true

func _rival_action(enemy: Dictionary, minions: Array) -> void:
	if not bool(enemy.get("rival", false)) or enemy.hp <= 0.0:
		return
	enemy.rival_shield_left = maxf(0.0, float(enemy.get("rival_shield_left", 0.0)) - DT)
	enemy.rival_shield_cooldown = maxf(0.0, float(enemy.get("rival_shield_cooldown", 0.0)) - DT)
	enemy.rival_timer = float(enemy.rival_timer) - DT * (0.45 if chrono_left > 0 else 1.0)
	if enemy.rival_timer > 0.0:
		return
	if jammer_left > 0.0 or emp_left > 0.0:
		enemy.rival_timer = 0.7
		return
	var signature_id: String = str(enemy.rival_trait)
	var power: float = threat_scale() * stage_risk * (1.0 + 0.12 * float(int(enemy.rival_rank) - 1))
	match signature_id:
		"charged_barrage":
			if charges.size() < 3:
				var predicted: float = ship_position(time + 1.9).x
				for offset in [-35.0, 35.0]:
					charges.append({"source":int(enemy.id), "x":clampf(predicted + offset, 36.0, 504.0), "remaining":1.9, "duration":1.9, "damage":19.0 * power})
				_log("RIVAL BARRAGE - two heavy beams charging")
			enemy.rival_timer = 9.5
		"hunter_lock":
			if charges.size() < 3:
				charges.append({"source":int(enemy.id), "x":clampf(ship_position(time + 1.6).x, 35.0, 505.0), "remaining":1.6, "duration":1.6, "damage":24.0 * power})
				_log("RIVAL LOCK - defensive counter window")
			enemy.rival_timer = 7.0
		"interceptor_screen":
			if int(enemy.rival_trait_used) < 1 and enemies.size() + minions.size() <= _enemy_limit() - 3:
				for side in [-1.0, 1.0]:
					minions.append({"kind":"interceptor", "p":enemy.p + Vector2(side * 70.0, 25.0), "rival_escort":true})
				enemy.rival_trait_used = 1
				_log("RIVAL ESCORT - two interceptors launched")
			enemy.rival_timer = 11.0
		"mine_scatter":
			for side in [-1.0, 0.0, 1.0]:
				bullets.append({"p":enemy.p + Vector2(side*55.0,20.0), "v":Vector2(side*12.0,90.0), "damage":12.0*power, "kind":"mine", "fuse":3.8, "hp":15.0, "source":"rival"})
			_log("RIVAL MINES - three lanes blocked")
			enemy.rival_timer = 10.0
		"reactive_shield":
			# Reacts to real incoming damage in _damage_enemy, not a flat buff.
			enemy.rival_timer = 8.0

func _spawn_hazard() -> void:
	if enemies.size() >= _enemy_limit() - 1:
		return
	var kind := "station"
	match ((stage - 1) % int(content.stage_count)) + 1:
		1: kind = "boulder" if rng.randf() < 0.65 else "station"
		2: kind = "arc_spire" if rng.randf() < 0.7 else "station"
		3: kind = "forge_turret" if rng.randf() < 0.6 else "slag_bomber"
		4: kind = "gravity_sentinel" if rng.randf() < 0.65 else "void_lancer"
	_add_enemy(kind, Vector2(rng.randf_range(85, 455), -65))
	_log("Incoming %s" % kind.replace("_", " "))

func _spawn_boss() -> void:
	encounter_queue.clear()
	boss_spawned = true
	boss_spawn_time = time
	if secret_entered:
		secret_intro_pending = true
		archive_next_attack = time + 1.6
		archive_attack = ""
		archive_phase = 0
		archive_phase_released = false
		archive_exposed_until = time + 1.6
	# The safeguard is once per stage; spawning the boss must not recharge it.
	enemies.clear()
	bullets.clear()
	charges.clear()
	shield = max_shield
	hull = minf(max_hull, hull + 15)
	heavy_ready_at = time + 3.0
	var spec := stage_spec()
	boss_attack_pattern = ["sweep", "crossfire", "delayed fan"][(seed_value + stage * 11) % 3]
	_log("BOSS WARNING - %s attack sequence" % boss_attack_pattern.to_upper())
	# Progression difficulties need stronger boss fights without making
	# World 1 tankier than World 2. The World 2 bridge maintains ascending
	# boss HP; Worlds 3 and 4 naturally exceed that threshold.
	var opener_boss_scale := 1.0
	if difficulty in ["hard", "insane"]:
		if stage == 1:
			opener_boss_scale = 6.5 if difficulty == "hard" else 5.5
		elif stage == 2:
			opener_boss_scale = 2.5
	var hp := float(spec.boss_hp) * threat_scale() * stage_risk * opener_boss_scale * enemy_health_multiplier() * boss_health_pressure()
	var boss_id: int = next_id
	enemies.append({"id": boss_id, "kind": str(spec.boss), "p": Vector2(270, 135), "hp": hp, "max_hp": hp, "speed": 0.0, "fire": 1.0, "xp": 0, "phase": 0.0})
	next_id += 1
	for part in content.boss_modules.get(str(spec.boss), []):
		var part_hp: float = float(part.hp) * threat_scale() * stage_risk * float(stage_spec().get("module_scale", 1.0)) * opener_boss_scale * enemy_health_multiplier() * boss_health_pressure()
		enemies.append({"id": next_id, "kind": "boss_module", "role": str(part.role), "name": str(part.name), "parent": boss_id, "offset": Vector2(float(part.offset_x), float(part.offset_y)), "p": Vector2(270 + float(part.offset_x), 135 + float(part.offset_y)), "hp": part_hp, "max_hp": part_hp, "speed": 0.0, "fire": 999999.0, "xp": 0, "phase": 0.0})
		next_id += 1
	_log(str(spec.boss_name) + " arrived - %d targetable modules" % _alive_modules())

func advance_stage() -> bool:
	if not stage_transition_queued or stage_clears != stage:
		return false
	if stage >= stage_count():
		stage_transition_queued = false
		ended = true
		won = true
		_log("The Archive is free · secret route complete" if secret_entered else "The Citadel has fallen - full run complete")
		return true
	if intermission_step != "ready" or route_choice not in ["repair", "overclock", "bounty"]:
		return false
	stage += 1
	signal_status = ""
	signal_until = 0.0
	if secret_entered:
		archive_next_attack = time + 24.0
		secret_intro_pending = true
	if artifact_id == "arsenal_roulette":
		# Move existing ranks, rather than gifting or destroying upgrades.
		var before: Array = [int(upgrades.pulse), int(upgrades.seeker), int(upgrades.arc), int(upgrades.lance)]
		upgrades.pulse = before[3]
		upgrades.seeker = before[0]
		upgrades.arc = before[1]
		upgrades.lance = before[2]
		_log("ARSENAL SHIFT - automatic weapon ranks rotated")
	stage_casts.clear()
	tactician_counter_used = false
	engineer_service_used = false
	ace_chain = 0
	ace_chain_left = 0.0
	hunter_target_id = -1
	hunter_mark_left = 0.0
	hunter_mark_cooldown = 0.0
	banishes_left += int(meta.banish_relay)
	escort_left = 0.0
	escort_timer = 0.0
	ion_mines.clear()
	rerolls_left = int(meta.rerolls) + pilot_rerolls_left
	encounter_index = 0
	encounter_queue.clear()
	next_encounter_at = time + 55.0 + float((seed_value + stage * 13) % 23)
	next_pressure_wave_at = time + 8.0
	pressure_waves = 0
	endless_stage_spec.clear()
	stage_start = time
	_schedule_merchant()
	boss_spawned = false
	boss_spawn_time = 0.0
	stage_transition_queued = false
	intermission_step = ""
	prototype_offers.clear()
	enemies.clear()
	bullets.clear()
	shots.clear()
	charges.clear()
	effects.clear()
	stage_power = 1.35 if route_choice == "overclock" else 1.0
	stage_risk = 1.30 if route_choice == "bounty" else 1.0
	stage_defense = 0.65 if route_choice == "repair" else 1.0
	stage_fire_rate = 1.20 if route_choice == "overclock" else 1.0
	var repair_fraction := 0.70 if route_choice == "repair" else (0.10 if route_choice == "overclock" else 0.40)
	hull = minf(max_hull, hull + max_hull * (repair_fraction + meta.warp_repairs * 0.04))
	shield = max_shield * (0.50 if route_choice == "overclock" else 1.0)
	safeguard_used = false
	shieldstorm_pulse_used = false
	next_spawn = time + 1.5
	next_hazard = time + 15.0
	heavy_ready_at = time + 10.0
	if not secret_entered:
		pending_levels += 1 + (1 if route_choice == "bounty" else 0)
	_log("STAGE %d - %s - %s ROUTE" % [stage, stage_name(), route_choice.to_upper()])
	return true

# Historical test shim; regular gameplay always uses both decisions.
func _enter_stage_two() -> void:
	if begin_intermission():
		choose_prototype(0)
		choose_route("repair")
	advance_stage()

func _update_enemies() -> void:
	var pace := 0.45 if chrono_left > 0 else 1.0
	var minions: Array = []
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		# Visual scouts peel away on schedule. They cannot soak automatic
		# fire for an entire wave, escape to inflict hazard damage, or
		# starve low-DPS Bulwark/Haven starters of normal enemy XP.
		if bool(enemy.get("opening_scout", false)) and time >= float(enemy.get("opening_scout_expires", 999999.0)):
			enemy.hp = -1.0
			continue
		var kind: String = enemy.kind
		if kind == "boss_module":
			var core: Dictionary = _boss_core()
			if core.is_empty():
				enemy.hp = -1.0
			else:
				enemy.p = core.p + enemy.offset
			continue
		if kind == HiddenSector.BOSS:
			enemy.p.x = 270.0 + sin((time - boss_spawn_time) * 0.68) * 99.0
			enemy.p.y = 154.0 + cos((time - boss_spawn_time) * 0.52) * 16.0
			_archive_index_fire(enemy)
			continue
		if HiddenSector.ENEMIES.has(kind):
			_update_archive_enemy(enemy, pace)
			continue
		if kind.begins_with("boss"):
			enemy.p.x = 270.0 + sin(time * (0.7 + stage * 0.16)) * (100.0 + stage * 9.0)
		else:
			enemy.p.y += enemy.speed * DT * pace
			if kind == "interceptor":
				enemy.p.x += cos(time * 4.2 + enemy.phase) * 135.0 * DT * pace
			elif kind in ["rusher", "ember_hunter", "storm_weaver"]:
				enemy.p.x = move_toward(enemy.p.x, ship_position().x, (28.0 if kind == "rusher" else 65.0) * DT * pace)
			elif kind == "phase_stalker":
				var cycle: int = floori((time - stage_start + float(enemy.phase)) / 2.8)
				if int(enemy.get("blink", -1)) != cycle:
					enemy.blink = cycle
					enemy.p.x = clampf(270.0 + sin(cycle * 2.7 + enemy.phase) * 175.0, 52.0, 488.0)
					effects.append({"kind":"phase", "p":enemy.p, "life":0.50, "max_life":0.50, "born":tick})
			elif kind in ["minelayer", "slag_bomber", "echo_carrier"]:
				enemy.p.x += sin(time * 3.0 + enemy.phase) * 48.0 * DT * pace
			else:
				enemy.p.x += sin(time * 1.8 + enemy.phase) * 12.0 * DT * pace
			enemy.p.x = clampf(enemy.p.x, 35, 505)
		if kind == "boulder":
			if enemy.p.y > 945.0:
				enemy.hp = -1.0
			elif enemy.p.distance_to(ship_position()) < 44.0:
				_hit(17.0, "hazard", "Boulder collision")
				enemy.hp = -1.0
			continue
		enemy.fire -= DT * pace * float(stage_spec().get("fire_scale", 1.0))
		_rival_action(enemy, minions)
		if (kind in ["sniper", "void_lancer"] or kind.begins_with("boss")) and time >= heavy_ready_at and charges.is_empty() and jammer_left <= 0.0 and emp_left <= 0.0:
			var lead := 2.15 if kind.begins_with("boss") and stage > 1 and boss_attack_pattern == "delayed fan" else 1.8
			var damage := (28.0 if kind in ["sniper", "void_lancer"] else (29.0 + stage * 6.0)) * threat_scale()
			# Late World 1 beam pressure is answerable by Aegis/EMP/Nova/Jammer.
			# This changes damage, not XP or the visible charge warning.
			if stage == 1 and time - stage_start >= 110.0:
				damage *= 1.20
				if difficulty == "hard":
					damage *= 1.30
				elif difficulty == "insane":
					damage *= 1.50
			if kind == "boss" and stage == 1:
				damage *= opener_boss_enrage()
			var beam_count := 2 if kind == "boss4" and _alive_modules("pylon") > 0 else 1
			for beam in range(beam_count):
				var pattern_shift := 0.0
				# Keep the primary heavy beam aimed at the ship. Only auxiliary
				# lanes sweep or crossfire; timing the counter must stay valuable.
				if beam > 0 and kind.begins_with("boss") and boss_attack_pattern == "sweep":
					pattern_shift = sin((time - boss_spawn_time) * 0.72) * 75.0
				elif beam > 0 and kind.begins_with("boss") and boss_attack_pattern == "crossfire":
					pattern_shift = 62.0 if beams_fired % 2 == 0 else -62.0
				var target_x: float = ship_position(time + lead).x + (beam * 2 - beam_count + 1) * 68.0 + pattern_shift
				charges.append({"source": enemy.id, "x": clampf(target_x, 35.0, 505.0), "remaining": lead, "duration": lead, "damage": damage})
			var beam_interval := 7.5 if stage == 1 else (6.0 if stage == 2 else (5.7 if stage == 3 else (4.4 if _alive_modules("pylon") == 0 else 5.8)))
			# Early Citadel lancer beams were stacking before new builds could adapt.
			# The boss retains its original heavy cadence and two-lane pylon phase.
			if stage == 4 and not boss_spawned and time - stage_start < 135.0:
				beam_interval = maxf(beam_interval, 7.8)
			heavy_ready_at = time + beam_interval
			_log("%s heavy beam charging" % kind.replace("_", " "))
		if enemy.fire <= 0.0:
			# An opening salvo from a very slow turret should emerge
			# at the top edge, not be held until deep into the playfield.
			# This applies only to the HP-tested shooters in Worlds 2+;
			# their later volleys use their existing interval unchanged.
			if stage > 1 and is_pressure_shooter(kind) and enemy.p.y < 0.0:
				enemy.fire = 0.0
				continue
			# Jammer and EMP still cancel boss beams, but the Harvester
			# gradually adapts after a prolonged advanced-difficulty fight.
			# It keeps firing its dodgeable projectile fans instead of
			# allowing an infinite healing + jamming stalemate.
			var boss_overload := kind == "boss" and stage == 1 and difficulty != "normal" and time - boss_spawn_time >= 75.0
			if (jammer_left > 0.0 or emp_left > 0.0) and not boss_overload:
				enemy.fire = 0.5
				continue
			if kind.begins_with("boss"):
				enemy.fire = ((2.1 if stage == 1 else maxf(1.1, 1.8 - stage * 0.15)) / boss_projectile_rate_multiplier()) * projectile_interval_factor(kind)
			else:
				# Carrier attacks also launch minions; do not accelerate their
				# launch cycle and accidentally create more XP on Insane.
				var attack_scale := enemy_cadence_scale() if kind in ["carrier", "echo_carrier"] else enemy_fire_scale()
				enemy.fire = (float(content.enemies[kind].interval) / attack_scale) * projectile_interval_factor(kind)
				# Elite wingmen fire about 20% more volleys only while their
				# marked leader survives. Destroying it restores normal pacing.
				if _elite_leader_active(enemy):
					enemy.fire *= 0.80
			# More shots late in World 1, without granting additional enemy XP.
			# Boss attacks begin unchanged; the first telegraph stays readable.
			# Fire more often late in the opener on advanced difficulties.
			# Extra enemy kills would grant XP and weaken this pressure curve.
			if stage == 1 and time - stage_start >= 65.0 and not kind.begins_with("boss"):
				if difficulty == "hard":
					enemy.fire *= 0.65
				elif difficulty == "insane":
					enemy.fire *= 0.55
			if stage == 1 and time - stage_start >= 110.0:
				if kind == "boss":
					if time - boss_spawn_time >= 18.0:
						enemy.fire *= 0.80
				else:
					enemy.fire *= 0.80
			if kind == "boss4" and boss_phase_label() == "FINAL ONSLAUGHT":
				enemy.fire *= 0.70
			var flight_time: float = enemy.p.distance_to(ship_position()) / 215.0
			flight_time = enemy.p.distance_to(ship_position(time + flight_time)) / 215.0
			var aim: Vector2 = ship_position(time + flight_time)
			if decoy_left > 0.0:
				aim = Vector2(70 if ship_position().x > 270 else 470, 700)
			var direction: Vector2 = (aim - enemy.p).normalized()
			if kind == "boss2" and _alive_modules("launch_bay") > 0:
				var launch_cycle: int = floori((time - boss_spawn_time) / 5.0)
				if int(enemy.get("last_launch", -1)) < launch_cycle:
					enemy.last_launch = launch_cycle
					for bay in enemies:
						if bay.kind == "boss_module" and bay.hp > 0 and bay.role == "launch_bay" and enemies.size() + minions.size() < _enemy_limit() - 2:
							minions.append({"p":bay.p + Vector2(0, 25), "kind":"storm_weaver"})
					_log("Storm Carrier launched fighters - destroy its bays")
			if kind in ["carrier", "echo_carrier"]:
				if enemies.size() + minions.size() < _enemy_limit() - 2:
					minions.append({"p": enemy.p + Vector2(rng.randf_range(-30, 30), 28), "kind":"phase_stalker" if kind == "echo_carrier" else "drone"})
				bullets.append({"p": enemy.p, "v": direction * 165.0, "damage": 2.0 * threat_scale(), "kind": "void" if kind == "echo_carrier" else "chaff", "source": "rival" if bool(enemy.get("rival", false)) else kind})
			elif kind in ["minelayer", "slag_bomber"]:
				var is_slag := kind == "slag_bomber"
				bullets.append({"p": enemy.p, "v": Vector2(0, 75 if is_slag else 62), "damage": (18.0 if is_slag else 12.0) * threat_scale(), "kind": "slag" if is_slag else "mine", "hp": 18.0 if is_slag else 14.0, "fuse": 2.9 if is_slag else 3.4, "source": "rival" if bool(enemy.get("rival", false)) else kind})
			else:
				var count := 3
				if kind == "gunship": count = 5
				elif kind in ["interceptor", "rusher"]: count = 2
				elif kind in ["arc_spire", "forge_turret"]: count = 9
				elif kind == "gravity_sentinel": count = 7
				elif kind.begins_with("boss"):
					count = 9 + stage * 2
					# World 1 boss adds real dodgable fire after the first
					# telegraphs. No guaranteed hits or synthetic failure rule.
					if stage == 1 and time - boss_spawn_time >= 15.0:
						if difficulty == "hard":
							count += 6
						elif difficulty == "insane":
							count += 8
				if kind == "boss4" and boss_phase_label() == "FINAL ONSLAUGHT":
					count += 6
				var bullet_kind := "chaff"
				match kind:
					"ion_frigate", "arc_spire", "storm_weaver": bullet_kind = "ion"
					"corroder": bullet_kind = "corrosion"
					"disruptor": bullet_kind = "disrupt"
					"ember_hunter", "forge_turret", "boss3": bullet_kind = "heat"
					"phase_stalker", "void_lancer", "boss4": bullet_kind = "void"
					"gravity_sentinel": bullet_kind = "gravity"
				if kind == "boss4" and floori(time * 0.5) % 2 == 0:
					bullet_kind = "gravity"
				for i in range(count):
					var angle: float = (i - (count - 1) / 2.0) * (0.19 if kind in ["arc_spire", "forge_turret"] else 0.15)
					bullets.append({"p": enemy.p, "v": direction.rotated(angle) * (260.0 if kind in ["ember_hunter", "phase_stalker"] else 215.0), "damage": (2.1 if kind.begins_with("boss") else (1.25 if kind in ["rusher", "interceptor"] else 1.6)) * threat_scale() * (boss_projectile_damage_multiplier() if kind.begins_with("boss") else 1.0) * (opener_boss_enrage() if kind == "boss" else 1.0), "kind": bullet_kind, "source": "rival" if bool(enemy.get("rival", false)) else kind})
				if kind in ["gunship", "missile_bomber", "station", "boss2", "boss4"]:
					var volley := (1 if _alive_modules("launch_bay") == 0 else 3) if kind == "boss2" else (3 if kind == "boss4" else (2 if kind == "missile_bomber" else 1))
					for i in range(volley):
						bullets.append({"p": enemy.p + Vector2((i * 2 - volley + 1) * 13, 0), "v": direction.rotated((i * 2 - volley + 1) * 0.10) * (175.0 if kind == "missile_bomber" else 140.0), "damage": (11.0 if kind == "missile_bomber" else 12.0) * threat_scale() * (boss_projectile_damage_multiplier() if kind.begins_with("boss") else 1.0), "kind":"ordnance", "hp":12.0, "source":"rival" if bool(enemy.get("rival", false)) else kind})
				if kind == "boss3" and boss_phase_label().begins_with("FURNACE SEALED"):
					for i in range(2):
						bullets.append({"p":enemy.p + Vector2((i * 2 - 1) * 70, 10), "v":Vector2(0, 95), "damage":18.0 * threat_scale(), "kind":"slag", "hp":18.0, "fuse":3.2, "source":"rival" if bool(enemy.get("rival", false)) else kind})
		if enemy.p.y > 885:
			if bool(enemy.get("rival", false)) and rival_outcome.is_empty():
				rival_outcome = "escaped"
				_log(str(rival_record.get("name", "Rival")) + " escaped")
			enemy.hp = -1.0
			if kind not in ["boulder", "station"]:
				_hit(5.0, "hazard", "Escaped " + kind)
	enemies = enemies.filter(func(e): return e.hp > 0.0)
	for minion in minions:
		if enemies.size() < _enemy_limit():
			_add_enemy(str(minion.kind), minion.p)
			if bool(minion.get("rival_escort", false)):
				enemies[-1]["rival_escort"] = true
				enemies[-1]["xp"] = 0

func _update_archive_enemy(enemy: Dictionary, pace: float) -> void:
	var kind: String = enemy.kind
	var age: float = time - stage_start
	enemy.p.y += enemy.speed * DT * pace
	if kind == "archive_shard":
		enemy.p.x = clampf(enemy.p.x + sin(age * 4.2 + enemy.phase) * 65.0 * DT * pace, 32.0, 508.0)
	if enemy.p.y > 885.0 or (kind == "archive_courier" and (signal_status != "courier" or time >= signal_until)):
		enemy.hp = -1.0
		return
	enemy.fire -= DT * pace
	if enemy.fire > 0.0 or enemy.p.y < 10.0 or emp_left > 0.0 or jammer_left > 0.0:
		return
	enemy.fire = float(HiddenSector.ENEMIES[kind].interval)
	var linked: bool = kind == "archive_relay"
	if kind == "archive_shard" and enemy.has("archive_relay"):
		linked = enemies.any(func(relay): return int(relay.id) == int(enemy.archive_relay) and relay.hp > 0.0)
	var direction: Vector2 = (ship_position(time + 1.9) - enemy.p).normalized()
	var count := 3 if linked else 1
	for i in range(count):
		bullets.append({"p":enemy.p, "v":direction.rotated((i - (count - 1) * 0.5) * 0.17) * 245.0, "damage":2.5 * threat_scale(), "kind":"chaff", "source":kind})

func _archive_index_fire(core: Dictionary) -> void:
	core.fire -= DT
	if core.fire > 0.0 or jammer_left > 0.0 or emp_left > 0.0:
		return
	core.fire = [3.45, 2.9, 2.55][archive_phase]
	var aim := ship_position(time + 2.35)
	for side in [-1, 1]:
		var origin: Vector2 = core.p + Vector2(side * 66.0, 12.0)
		var direction := (aim - origin).normalized()
		for i in range(3 + archive_phase):
			var angle: float = (float(i) - (2.0 + archive_phase) * 0.5) * 0.11
			bullets.append({"p":origin, "v":direction.rotated(angle) * (242.0 + 17.0 * i), "damage":3.9 * threat_scale(), "kind":"void", "source":HiddenSector.BOSS})

func _update_archive_attack() -> void:
	var core := _boss_core() if boss_spawned else {}
	if boss_spawned and core.is_empty():
		return
	if not archive_attack.is_empty():
		if time >= archive_attack_until:
			_resolve_archive_attack(core)
		return
	if not core.is_empty() and archive_phase < 2 and archive_phase_released and core.hp <= core.max_hp * HiddenSector.PHASE_FLOORS[archive_phase] + 0.001:
		archive_phase += 1
		archive_phase_released = false
		archive_next_attack = minf(archive_next_attack, time + 1.35)
	if time < archive_next_attack:
		return
	archive_attack = HiddenSector.ATTACKS[archive_phase] if boss_spawned else "lock"
	archive_attack_until = time + (3.2 if archive_phase == 2 else 3.6)
	archive_attack_x = ship_position(archive_attack_until).x
	_log("ARCHIVE " + archive_attack.to_upper() + " charging · any active ability breaks the lock")

func _resolve_archive_attack(core: Dictionary) -> void:
	var origin: Vector2 = core.get("p", Vector2(270, 165))
	var attack := archive_attack
	archive_attack = ""
	archive_phase_released = true
	archive_next_attack = time + (16.0 if not boss_spawned else (7.5 if archive_phase == 2 else 10.0))
	archive_exposed_until = time + 3.0
	if attack != "lattice":
		effects.append({"kind":"beam", "p":Vector2(archive_attack_x, 0), "life":0.32, "max_life":0.32, "born":tick})
		beams_fired += 1
		if absf(ship_position().x - archive_attack_x) < 38.0:
			_hit((67.0 if attack == "collapse" else (51.0 if boss_spawned else 27.0)) * threat_scale(), "heavy", HiddenSector.BOSS if boss_spawned else "Archive gate")
	if attack in ["lattice", "collapse"]:
		var count := 13 if attack == "lattice" else 7
		for side in [-1, 1]:
			var source := origin + Vector2(side * 115.0, 18.0)
			var dir: Vector2 = (ship_position(time + 2.0) - source).normalized()
			for i in range(count):
				var offset := (i - (count - 1) * 0.5) * 0.15
				bullets.append({"p":source, "v":dir.rotated(offset) * (220.0 + i * 7.0), "damage":5.0 * threat_scale(), "kind":"void", "source":HiddenSector.BOSS})

func _counter_archive_attack() -> void:
	archive_attack = ""
	archive_phase_released = true
	archive_next_attack = time + (16.0 if not boss_spawned else 9.0)
	archive_exposed_until = time + 6.0
	beams_cancelled += 1
	effects.append({"kind":"ion-burst", "p":ship_position(), "radius":215.0, "life":0.75, "max_life":0.75, "born":tick})
	_log("RESONANCE BROKEN · weapons have a clear shot")

func _update_charges() -> void:
	for charge in charges:
		charge.remaining -= DT
		if charge.remaining <= 0.0:
			beams_fired += 1
			effects.append({"kind": "beam", "p": Vector2(charge.x, 0), "life": 0.32, "max_life": 0.32, "born": tick})
			if absf(ship_position().x - charge.x) < 33:
				if aegis_left > 0.0 and upgrades.aegis >= 5:
					for enemy in enemies:
						if enemy.id == charge.source:
							_damage_enemy(enemy, 60.0, "nova")
							_log("Aegis reflected the heavy beam")
				var attacker := boss_name() if boss_spawned else "Heavy lancer"
				for charging_enemy in enemies:
					if int(charging_enemy.id) == int(charge.source):
						attacker = "rival" if bool(charging_enemy.get("rival", false)) else str(charging_enemy.kind)
						break
				_hit(charge.damage, "heavy", attacker)
	charges = charges.filter(func(c): return c.remaining > 0.0)

func escort_position(index: int) -> Vector2:
	var side := -1.0 if index % 2 == 0 else 1.0
	var p := ship_position() + Vector2(side * (46.0 + (index / 2) * 22.0), 8.0 + (index / 2) * 22.0)
	return Vector2(clampf(p.x,12,528),p.y)

func _launch_escorts(count: int, duration: float, damage: float) -> void:
	escort_count = count
	escort_left = duration
	escort_damage = damage
	escort_timer = 0.0

func _deploy_ion_mines(count: int, damage: float, radius: float) -> void:
	var target := _nearest(ship_position())
	var anchor: Vector2 = target.p + Vector2(0,100) if not target.is_empty() else ship_position() + Vector2(0,-170)
	for i in range(count):
		var p := anchor + Vector2((i - (count-1)*0.5)*100.0,0)
		p.x = clampf(p.x,25,515)
		p.y = clampf(p.y,65,865)
		ion_mines.append({"p":p,"fuse":1.8,"damage":damage,"radius":radius})
	while ion_mines.size() > 6: ion_mines.pop_front()

func _engineer_service_window() -> void:
	if pilot_id != "engineer" or engineer_service_used or boss_spawned or time - stage_start < 25.0 or shield <= max_shield * 0.50:
		return
	engineer_service_used = true
	sentry_left = maxf(sentry_left, 4.0)
	sentry_timer = 0.0
	pilot_procs.engineer += 1
	_log("FIELD SENTRY - proactive engineering sweep")

func _update_support() -> void:
	if artifact_id == "drone_armada" and escort_left <= 0.0:
		_launch_escorts(3, 9999.0, 10.0)
	# Hunter selects a REAL high-priority enemy. The same mark drives
	# auto-targeting, damage, and visible ring cues; no manual aiming.
	if pilot_id == "hunter":
		if hunter_mark_left <= 0.0:
			hunter_target_id = -1
		if hunter_target_id >= 0 and not enemies.any(func(e): return int(e.id) == hunter_target_id and float(e.hp) > 0.0):
			hunter_target_id = -1
			hunter_mark_left = 0.0
		if hunter_target_id < 0 and hunter_mark_cooldown <= 0.0:
			var priority: Dictionary = {}
			for candidate in enemies:
				if float(candidate.hp) <= 0.0 or candidate.p.y < -5.0 or candidate.kind == "boulder":
					continue
				if candidate.kind in ["gunship","sniper","missile_bomber","shieldguard","carrier","ion_frigate","storm_weaver","slag_bomber","void_lancer","boss_module","boss","boss2","boss3","boss4",HiddenSector.BOSS,"archive_relay"] or str(candidate.get("elite_role","")) == "leader":
					priority = candidate
					break
			if not priority.is_empty():
				hunter_target_id = int(priority.id)
				hunter_mark_left = 14.0
				hunter_mark_cooldown = 18.0
				_log("HUNTER LOCK - priority threat designated")
	if sentry_left > 0.0:
		sentry_left = maxf(0.0, sentry_left - DT)
		sentry_timer -= DT
		if sentry_timer <= 0.0:
			sentry_timer += 0.45
			var sentry_origin: Vector2 = ship_position() + Vector2(36.0, -5.0)
			var sentry_target: Dictionary = _nearest(sentry_origin)
			if not sentry_target.is_empty() and shots.size() < 500:
				shots.append({"p":sentry_origin, "v":(sentry_target.p - sentry_origin).normalized() * 750.0, "damage":12.0 * weapon_power(), "weapon":"escort", "target":int(sentry_target.id)})
	if escort_left > 0.0:
		escort_left = maxf(0.0,escort_left-DT)
		escort_timer -= DT
		if escort_timer <= 0.0 and escort_left > 0.0:
			escort_timer += 0.48 if artifact_id == "drone_armada" else 0.5
			for i in range(escort_count):
				var p := escort_position(i)
				var target := _nearest(p)
				if not target.is_empty() and shots.size() < 500:
					shots.append({"p":p,"v":(target.p-p).normalized()*700.0,"damage":((9.0 + level * 1.8) * weapon_power() * (1.0 + 0.75 * float(stage - 1)) if artifact_id == "drone_armada" else escort_damage),"weapon":"escort","target":int(target.id), "homing":artifact_id == "drone_armada"})
	var armed: Array = []
	for mine in ion_mines:
		mine.fuse -= DT
		var contact: bool = mine.fuse < 1.45 and enemies.any(func(e): return e.hp > 0 and e.p.distance_squared_to(mine.p) <= 90.0*90.0)
		if mine.fuse > 0.0 and not contact:
			armed.append(mine)
			continue
		var radius_squared: float = mine.radius * mine.radius
		for enemy in enemies:
			if enemy.p.distance_squared_to(mine.p) <= radius_squared:
				_damage_enemy(enemy,mine.damage,"ion_mine")
		var kept: Array = []
		for bullet in bullets:
			if bullet.p.distance_squared_to(mine.p) <= radius_squared:
				prevented += float(bullet.get("damage",0.0))
			else: kept.append(bullet)
		bullets = kept
		effects.append({"kind":"ion-burst","p":mine.p,"radius":mine.radius,"life":0.65,"max_life":0.65,"born":tick})
	ion_mines = armed

func _focus_reroll() -> void:
	if cards.any(func(card): return int(upgrades.get(card.id,0)) > 0): return
	var available: Array = content.cards.filter(func(card): return int(upgrades.get(card.id,0)) > 0 and int(upgrades[card.id]) < int(card.max) and card.id not in banished and fused_into(str(card.id)).is_empty() and (fusion_spec(str(card.id)).is_empty() or card.id in active_slots) and stage >= int(card.get("min_stage",1)))
	if not available.is_empty() and not cards.is_empty():
		cards[-1] = available[rng.randi_range(0,available.size()-1)].duplicate(true)

func _update_weapons() -> void:
	var rate: float = (1.0 + upgrades.autoloader * 0.08 + meta.fire_rate * 0.05 + (0.75 if overdrive_left > 0 else 0.0)) * float(Catalog.ship(ship_id).fire_rate) * stage_fire_rate
	if rank_at("autoloader", 5): rate += 0.15
	if rank_at("autoloader", 10): rate += 0.25
	if aftercast_left > 0.0:
		rate *= 1.0 + passive_bonus("afterburn", 0.03, 0.10, 0.15)
	if gravity_left > 0.0:
		rate *= 0.72
	pulse_timer -= DT * rate
	seeker_timer -= DT * rate
	arc_timer -= DT * rate * (1.15 if passive_link_active("arc_feed") else 1.0)
	lance_timer -= DT * rate
	var bank := clampf(ship_velocity().x * 0.004, -0.32, 0.32)
	var origin := ship_position() + Vector2(0, -34).rotated(bank)
	if upgrades.pulse > 0 and pulse_timer <= 0.0:
		pulse_timer += 0.19
		var barrels := 3 if rank_at("pulse", 10) else (2 if rank_at("pulse", 5) else 1)
		for n in range(barrels):
			shots.append({"p": origin + Vector2((n * 2 - barrels + 1) * 8, 0), "v": Vector2(0, -980).rotated(bank), "damage": (7.0 + (upgrades.pulse - 1) * 1.68) * weapon_power() * (1.25 if pilot_id == "ace" else 1.0) * (1.20 if rank_at("pulse", 10) else 1.0) * (1.20 if passive_link_active("smart_pulse") else 1.0), "weapon": "pulse", "target": -1, "pierce":(1 if _has_mutation("piercing_pulse") else 0), "last_enemy":-1})
	if upgrades.seeker > 0 and seeker_timer <= 0.0:
		# Haven clears early waves with rapid support pods instead of a Pulse starter.
		var seeker_interval: float = 0.62 if pilot_id == "hunter" else 0.70
		if ship_id == "haven":
			seeker_interval = 0.50 if pilot_id == "hunter" else 0.55
		seeker_timer += seeker_interval
		# Priority is readable and build-controlled: charging source, missile, nearest enemy.
		var target_id := -1
		var target_pos := Vector2(270, -100)
		if not charges.is_empty():
			target_id = charges[0].source
		for enemy in enemies:
			if enemy.id == target_id:
				target_pos = enemy.p
		if target_id < 0:
			for bullet in bullets:
				if bullet.kind in ["ordnance", "mine", "slag"]:
					target_pos = bullet.p
					target_id = -2
					break
		if target_id == -1 and not enemies.is_empty():
			var chosen: Dictionary = _nearest(origin)
			if not chosen.is_empty():
				target_id = int(chosen.id)
				target_pos = chosen.p
		if target_id != -1:
			var volley: int = 3 if rank_at("seeker", 10) else (2 if rank_at("seeker", 5) else 1)
			for n in range(volley):
				shots.append({"p": origin + Vector2((n * 2 - volley + 1) * 7, 0), "v": (target_pos - origin).normalized().rotated((n * 2 - volley + 1) * 0.06) * 650.0, "damage": (14.0 + (upgrades.seeker - 1) * 4.2) * (1.0 + meta.ordnance_damage * 0.05) * weapon_power() * (1.35 if ship_id == "wraith" else (1.12 if ship_id == "haven" else 1.0)) * (1.3 if pilot_id == "hunter" else 1.0) * (1.25 if passive_link_active("guided_payload") else 1.0), "weapon": "seeker", "target": target_id})
	if upgrades.arc > 0 and arc_timer <= 0.0 and not enemies.is_empty():
		arc_timer = 1.7
		var visited: Array = []
		var start := origin
		for chain in range(2 + int(upgrades.arc) / 2 + (1 if rank_at("arc", 5) else 0) + (2 if rank_at("arc", 10) else 0) + (1 if passive_link_active("arc_feed") else 0)):
			var target := _nearest(start, visited)
			if target.is_empty() or start.distance_to(target.p) > 640:
				break
			visited.append(target.id)
			effects.append({"kind":"arc", "p":start, "to":target.p, "life":0.22, "max_life":0.22, "born":tick})
			start = target.p
			_damage_enemy(target, (10 + upgrades.arc * 3) * weapon_power() * (1.3 if ship_id == "arcwing" else 1.0) * (1.25 if rank_at("arc", 10) else 1.0), "arc")
			if _has_mutation("grounding_arc") and target.hp > 0.0:
				target.fire = maxf(float(target.fire), 1.8)
				var canceled: int = charges.size()
				charges = charges.filter(func(charge): return int(charge.source) != int(target.id))
				beams_cancelled += canceled - charges.size()
				effects.append({"kind":"timed-counter", "p":target.p, "life":0.55, "max_life":0.55, "born":tick})
	if upgrades.lance > 0 and lance_timer <= 0.0:
		var target := _nearest(origin)
		for enemy in enemies:
			if not charges.is_empty() and enemy.id == charges[0].source and enemy.hp > 0.0:
				target = enemy
		# Kills earlier this tick leave dead enemies in the array until the
		# projectile pass. Do not consume a full lance cycle without firing.
		if not target.is_empty():
			lance_timer = 2.4 * (0.60 if rank_at("lance", 10) else (0.78 if rank_at("lance", 5) else 1.0))
			lance_refund_ready = true
			var echo_used := false
			var end: Vector2 = origin + (target.p - origin).normalized() * 1200
			# Keep each instantaneous strike legible at 3x (0.20s real time).
			# The effect duration changes visuals, not damage or shot cadence.
			effects.append({"kind":"lance", "p":origin, "to":end, "life":0.60, "max_life":0.60, "born":tick})
			for enemy in enemies:
				var closest := Geometry2D.get_closest_point_to_segment(enemy.p, origin, end)
				if closest.distance_to(enemy.p) < (68 if str(enemy.kind).begins_with("boss") else 28):
					var strike_damage: float = (22 + upgrades.lance * 7) * weapon_power() * (1.25 if rank_at("lance", 10) else 1.0) * (1.35 if passive_link_active("lance_sight") else 1.0)
					_damage_enemy(enemy, strike_damage, "lance")
					if _has_mutation("refracting_lance") and not echo_used:
						for other in enemies:
							if other.hp > 0.0 and int(other.id) != int(enemy.id) and Geometry2D.get_closest_point_to_segment(other.p, origin, end).distance_to(other.p) >= 32.0 and other.p.distance_squared_to(enemy.p) <= 245.0 * 245.0:
								effects.append({"kind":"lance", "p":enemy.p, "to":other.p, "life":0.42, "max_life":0.42, "born":tick})
								_damage_enemy(other, strike_damage * 0.35, "lance_echo")
								echo_used = true
								break

func weapon_power() -> float:
	var power: float = (1.0 + meta.damage * 0.08 + upgrades.munitions * 0.08 + (0.14 if rank_at("munitions", 5) else 0.0) + (0.22 if rank_at("munitions", 10) else 0.0) + (0.05 if passive_link_active("guided_payload") else 0.0)) * (1.85 if focus_left > 0.0 else 1.0) * (0.75 if heat_left > 0.0 else 1.0) * stage_power
	if artifact_id == "glass_fleet":
		power *= 1.50
	if merchant_pact_power > 0.0:
		power *= 1.0 + merchant_pact_power
	# Shielded Passage contributes immediate offense without needing a niche draft.
	# It only rewards shields above half capacity during Worlds 2-4.
	if stage in [2, 3, 4] and route_choice == "repair" and shield > max_shield * 0.50:
		power *= 1.15
	# Engineer can convert well-maintained shields into modest weapon output.
	# Its repair identity remains, while the payoff no longer disappears
	# against max-Hangar boss health in long fights.
	if pilot_id == "engineer" and shield > max_shield * 0.50:
		power *= 1.06
	if hull < max_hull * 0.60:
		power *= 1.0 + passive_bonus("last_stand", 0.03, 0.10, 0.20)
	if shield > max_shield * 0.75:
		power *= 1.0 + passive_bonus("shield_focus", 0.025, 0.10, 0.15)
	# Rank milestones make protecting a pristine hull an offensive decision.
	# Shield Focus is a World 2+ draft; the opening progression is unchanged.
	if stage >= 2 and hull >= max_hull - 0.01:
		power *= 1.0 + (0.12 if rank_at("shield_focus", 5) else 0.0) + (0.18 if rank_at("shield_focus", 10) else 0.0)
	if synergy_active("fortress"):
		power *= 0.82
	if synergy_active("assault"):
		power *= 1.28
	if synergy_active("control"):
		power *= 0.88
	if synergy_active("salvager"):
		power *= 0.82
	for prototype in prototypes:
		match str(prototype):
			"bastion_lattice": power *= 0.88
			"volatile_core": power *= 1.55
			"null_harmonics": power *= 0.88
			"salvage_charter": power *= 0.85
			"emergency_safeguard": power *= 0.90
	return power

func ability_power() -> float:
	var power: float = 1.0 + meta.ability_power * 0.06 + upgrades.amplifier * 0.06
	if rank_at("amplifier", 5): power += 0.15
	if rank_at("amplifier", 10): power += 0.25
	if passive_link_active("quick_charge"): power *= 1.15
	if synergy_active("assault"):
		power *= 1.20
	if _has_prototype("echo_coil"):
		power *= 1.70
	return power

func hull_damage_multiplier() -> float:
	var factor := 1.0
	if synergy_active("fortress"):
		factor *= 0.85
	if passive_link_active("reinforced_plating"):
		factor *= 0.90
	if synergy_active("assault"):
		factor *= 1.28
	if _has_prototype("volatile_core"):
		factor *= 1.30
	if route_choice == "overclock" and stage >= 2:
		factor *= 1.20
	return factor

func cooldown_multiplier() -> float:
	var factor := 1.0
	# Shielded Passage protects the player through more timely active choices,
	# not extra auto-weapon damage. World 1 is always unaffected.
	if route_choice == "repair" and stage >= 2:
		factor *= 0.85
	if synergy_active("control"):
		factor *= 0.82
	if rank_at("coolant", 5): factor *= 0.95
	if rank_at("coolant", 10): factor *= 0.90
	if passive_link_active("quick_charge"): factor *= 0.88
	if _has_prototype("null_harmonics"):
		factor *= 0.62
	if _has_prototype("mirror_cell"):
		factor *= 1.15
	if _has_prototype("echo_coil"):
		factor *= 1.18
	return factor

func _nearest(origin: Vector2, excluded: Array = []) -> Dictionary:
	# Auto-target components first during boss fights. Players never aim or steer.
	var best: Dictionary = {}
	var distance := INF
	for enemy in enemies:
		if enemy.hp > 0.0 and enemy.id not in excluded:
			var d: float = origin.distance_squared_to(enemy.p)
			if enemy.kind == "boss_module" or enemy.kind == "archive_courier":
				d *= 0.22
			elif enemy.kind == "archive_relay":
				d *= 0.58
			elif pilot_id == "hunter" and int(enemy.id) == hunter_target_id and hunter_mark_left > 0.0:
				d *= 0.14
			elif str(enemy.get("elite_role", "")) == "leader":
				# The player controls abilities, not aim. Give a readable
				# elite counterplay objective a moderate auto-target bias.
				d *= 0.55
			if d < distance:
				distance = d
				best = enemy
	return best

func _is_small_shot(kind: String) -> bool:
	# Status projectiles are small shots too. Only beams, missiles, mines
	# and molten slag should bypass the chaff barrier/deflector/prism family.
	return kind in ["chaff", "ion", "corrosion", "disrupt", "heat", "gravity", "void"]

func _update_bullets() -> void:
	var ship := ship_position()
	var control_pace: float = 0.88 if synergy_active("control") else 1.0
	for bullet in bullets:
		if bullet.kind == "ordnance":
			var target := Vector2(70 if ship.x > 270 else 470, 700) if decoy_left > 0.0 else ship
			bullet.v = bullet.v.lerp((target - bullet.p).normalized() * (185.0 if bullet.source == "missile_bomber" else 155.0), DT * 0.9)
		if bullet.kind in ["mine", "slag"]:
			bullet.fuse -= DT * (0.45 if chrono_left > 0 else 1.0)
			if bullet.fuse <= 0.0:
				effects.append({"kind":"explosion", "p":bullet.p, "life":0.38, "max_life":0.38, "born":tick})
				if bullet.p.distance_to(ship) < (105.0 if bullet.kind == "slag" else 83.0):
					_hit(bullet.damage, "hazard", "rival" if str(bullet.get("source","")) == "rival" else ("Molten slag" if bullet.kind == "slag" else "Proximity mine"))
				bullet.hp = 0.0
		var bullet_pace: float = (0.45 if chrono_left > 0 else 1.0) * control_pace
		bullet.p += bullet.v * DT * bullet_pace
		var hit_radius := 18.0 if bullet.kind == "ordnance" else (13.0 if bullet.kind in ["mine", "slag"] else 10.0)
		if bullet.p.distance_squared_to(ship) < hit_radius * hit_radius and int(bullet.get("hp", 1)) > 0:
			if not (barrier_left > 0.0 and _is_small_shot(str(bullet.kind))):
				_hit(bullet.damage, "hazard" if bullet.kind in ["mine", "slag"] else bullet.kind, "rival" if str(bullet.get("source","")) == "rival" else ("Molten slag" if bullet.kind == "slag" else ("Proximity mine" if bullet.kind == "mine" else str(bullet.source))))
			bullet.p.y = HEIGHT + 100
	bullets = bullets.filter(func(b): return b.p.y < HEIGHT + 35 and b.p.y > -100 and b.p.x > -60 and b.p.x < WIDTH + 60 and b.get("hp", 1) > 0)

func _update_shots() -> void:
	var spawned_shards: Array = []
	# Only interceptor-capable projectiles belong in collision buckets.
	# Avoid the former every-player-shot x every-enemy-bullet scan.
	const CELL := 64.0
	var ordnance_cells: Dictionary = {}
	for bullet in bullets:
		if bullet.kind not in ["ordnance", "mine", "slag"] or float(bullet.get("hp", 1)) <= 0.0:
			continue
		var cell := Vector2i(floori(bullet.p.x / CELL), floori(bullet.p.y / CELL))
		if not ordnance_cells.has(cell):
			ordnance_cells[cell] = []
		ordnance_cells[cell].append(bullet)
	for shot in shots:
		if (shot.weapon in ["seeker", "barrage"] or bool(shot.get("homing", false))) and shot.target >= 0:
			var alive := enemies.any(func(e): return e.id == shot.target and e.hp > 0)
			if not alive:
				var replacement := _nearest(shot.p)
				shot.target = int(replacement.get("id", -1))
		if shot.weapon == "pulse":
			# Mild forward-only steering: no U-turns or seeker-style pursuit.
			var candidate: Dictionary = {}
			var score := INF
			for enemy in enemies:
				var offset: Vector2 = enemy.p - shot.p
				if enemy.hp <= 0 or offset.y >= -8 or absf(Vector2.UP.angle_to(offset)) > 0.58 + meta.guidance * 0.035 + (0.12 if pilot_id == "ace" else 0.0):
					continue
				var candidate_score := (absf(offset.x) + offset.length() * 0.10) * (0.60 if enemy.kind == "boss_module" else 1.0)
				if candidate_score < score:
					score = candidate_score
					candidate = enemy
			if not candidate.is_empty():
				var desired: Vector2 = (candidate.p - shot.p).normalized()
				shot.v = shot.v.rotated(clampf(shot.v.angle_to(desired), -DT * (0.85 + meta.guidance * 0.12 + (0.25 if pilot_id == "ace" else 0.0)), DT * (0.85 + meta.guidance * 0.12)))
		if (shot.weapon in ["seeker", "barrage"] or bool(shot.get("homing", false))) and shot.target >= 0:
			for enemy in enemies:
				if enemy.id == shot.target:
					shot.v = shot.v.lerp((enemy.p - shot.p).normalized() * 650, DT * 8.0)
		if shot.weapon == "seeker" and shot.target == -2:
			for bullet in bullets:
				if bullet.kind in ["ordnance", "mine", "slag"]:
					shot.v = shot.v.lerp((bullet.p - shot.p).normalized() * 650, DT * 8.0)
					break
		shot.p += shot.v * DT
		var struck := false
		if shot.weapon in ["seeker", "barrage", "pulse"]:
			var center := Vector2i(floori(shot.p.x / CELL), floori(shot.p.y / CELL))
			for dx in range(-1, 2):
				if struck:
					break
				for dy in range(-1, 2):
					if struck:
						break
					for bullet in ordnance_cells.get(center + Vector2i(dx, dy), []):
						if float(bullet.get("hp", 1)) > 0.0 and bullet.p.distance_squared_to(shot.p) < 28.0 * 28.0:
							bullet.hp -= shot.damage
							if bullet.hp <= 0.0:
								effects.append({"kind":"explosion", "p":bullet.p, "life":0.30, "max_life":0.30, "born":tick})
							struck = true
							break
		if not struck:
			for enemy in enemies:
				if enemy.hp <= 0.0:
					continue
				var radius := 68.0 if str(enemy.kind).begins_with("boss") and enemy.kind != "boss_module" else (30.0 if enemy.kind == "boss_module" else 25.0)
				if shot.p.distance_squared_to(enemy.p) < radius * radius and int(shot.get("last_enemy", -1)) != int(enemy.id):
					_damage_enemy(enemy, shot.damage, shot.weapon)
					if shot.weapon == "pulse" and _has_mutation("ricochet_pulse"):
						var jump: Dictionary = {}
						for other in enemies:
							if other.hp > 0.0 and int(other.id) != int(enemy.id) and other.p.distance_squared_to(enemy.p) <= 290.0 * 290.0:
								jump = other
								break
						if not jump.is_empty():
							effects.append({"kind":"arc", "p":enemy.p, "to":jump.p, "life":0.32, "max_life":0.32, "born":tick})
							_damage_enemy(jump, float(shot.damage) * 0.35, "pulse_echo")
					if shot.weapon == "seeker" and _has_mutation("breach_seeker"):
						var spread := 0
						for other in enemies:
							if spread >= 2:
								break
							if other.hp > 0.0 and int(other.id) != int(enemy.id) and other.p.distance_squared_to(enemy.p) < 170.0 * 170.0:
								_damage_enemy(other, float(shot.damage) * 0.25, "seeker_blast")
								spread += 1
						if spread > 0:
							effects.append({"kind":"ion-burst", "p":enemy.p, "radius":125.0, "life":0.50, "max_life":0.50, "born":tick})
					if shot.weapon == "seeker" and _has_mutation("split_seeker") and not bool(shot.get("shard", false)):
						var victims: Array = []
						for other in enemies:
							if other.hp > 0.0 and int(other.id) != int(enemy.id) and other.p.distance_squared_to(enemy.p) < 380.0 * 380.0:
								victims.append(other)
						victims.sort_custom(func(a, b): return a.p.distance_squared_to(enemy.p) < b.p.distance_squared_to(enemy.p))
						for n in range(mini(3, victims.size())):
							var victim: Dictionary = victims[n]
							var start: Vector2 = enemy.p + Vector2((n - 1) * 13.0, -12.0)
							spawned_shards.append({"p":start, "v":(victim.p - start).normalized() * 650.0, "damage":float(shot.damage) * 0.35, "weapon":"seeker", "target":int(victim.id), "shard":true})
						if not victims.is_empty():
							effects.append({"kind":"explosion", "p":enemy.p, "life":0.42, "max_life":0.42, "born":tick})
					if shot.weapon == "pulse" and int(shot.get("pierce", 0)) > 0:
						shot["pierce"] = 0
						shot["last_enemy"] = int(enemy.id)
						shot["damage"] = float(shot.damage) * 0.60
					else:
						struck = true
						break
		if struck:
			shot.p.y = -200
	shots.append_array(spawned_shards)
	shots = shots.filter(func(s): return s.p.y > -100 and s.p.y < HEIGHT and s.p.x > -50 and s.p.x < WIDTH + 50)
	enemies = enemies.filter(func(e): return e.hp > 0.0)

func _damage_enemy(enemy: Dictionary, amount: float, weapon: String) -> void:
	if enemy.hp <= 0.0:
		return
	if weapon in ["pulse", "seeker", "arc", "lance"]:
		if str(enemy.kind).begins_with("boss"):
			amount *= (1.0 + passive_bonus("boss_hunter", 0.05, 0.15, 0.25)) * (1.0 + meta.boss_damage * 0.03)
			# Bulwark retains its slower fire and tank role, but is no
			# longer disproportionately weak at long advanced bosses.
			if ship_id == "bulwark":
				amount *= 1.12
		if enemy.hp < enemy.max_hp * 0.35:
			amount *= 1.0 + passive_bonus("finisher", 0.04, 0.15, 0.25)
		if float(enemy.hp) > float(enemy.max_hp) * 0.75:
			amount *= 1.0 + passive_bonus("opening_salvo", 0.04, 0.15, 0.25)
	if weapon == "seeker" and _has_mutation("breach_seeker") and str(enemy.kind).begins_with("boss"):
		amount *= 1.25
	if pilot_id == "hunter" and hunter_mark_left > 0.0 and int(enemy.id) == hunter_target_id and weapon in ["pulse", "seeker", "arc", "lance"]:
		amount *= 1.15
	if bool(enemy.get("rival", false)) and str(enemy.get("rival_trait", "")) == "reactive_shield":
		if float(enemy.get("rival_shield_cooldown", 0.0)) <= 0.0 and amount >= 14.0:
			enemy.rival_shield_left = 1.3
			enemy.rival_shield_cooldown = 8.0
			_log("RIVAL SHIELD - break the rhythm")
		if float(enemy.get("rival_shield_left", 0.0)) > 0.0:
			amount *= 0.5
	if enemy.kind == "shieldguard":
		amount *= 0.72
	if enemy.kind == "boss_module":
		# Optional Hangar specialist tool: trade Cores for faster destruction
		# of exposed launch bays, vents and pylons, never the core itself.
		amount *= (2.40 if _has_prototype("breach_optics") else 1.0) * (1.0 + meta.module_breaker * 0.06)
	elif _has_prototype("breach_optics"):
		amount *= 0.90
	if enemy.kind == "boss2" and _alive_modules("launch_bay") > 0:
		amount *= 0.85
	if enemy.kind == "boss3" and _alive_modules("vent") > 0 and boss_phase_label().begins_with("FURNACE SEALED"):
		amount *= 0.28
	if enemy.kind == "boss4" and _alive_modules("pylon") > 0:
		amount *= 0.28
	if upgrades.targeting > 0 and weapon in ["pulse", "seeker", "arc", "lance"] and rng.randf() < (upgrades.targeting * 0.05 + (0.05 if weapon == "pulse" and passive_link_active("smart_pulse") else 0.0) + (0.08 if weapon == "lance" and passive_link_active("lance_sight") else 0.0)):
		amount *= 3.0 if rank_at("targeting", 10) else (2.5 if rank_at("targeting", 5) else 2.0)
	if enemy.kind == HiddenSector.BOSS:
		if time >= archive_exposed_until:
			amount *= 0.46
		if archive_phase < 2 or not archive_phase_released:
			var floor_hp: float = enemy.max_hp * HiddenSector.PHASE_FLOORS[archive_phase]
			amount = minf(amount, maxf(0.0, enemy.hp - floor_hp))
	damage_dealt[weapon] = float(damage_dealt.get(weapon, 0.0)) + minf(amount, enemy.hp)
	enemy.hp -= amount
	effects.append({"kind": "impact", "p": enemy.p, "life": 0.16, "max_life": 0.16, "born": tick})
	if enemy.hp > 0:
		return
	if weapon == "lance" and _has_mutation("capacitor_lance") and lance_refund_ready:
		lance_timer = maxf(0.0, lance_timer - 0.65)
		lance_refund_ready = false
		effects.append({"kind":"timed-counter", "p":enemy.p, "life":0.45, "max_life":0.45, "born":tick})
	if bool(enemy.get("rival", false)) and rival_outcome.is_empty():
		rival_outcome = "retired"
		rival_retire_pending = true
		_log("RIVAL DEFEATED - " + str(rival_record.get("name", "Captain")))
	if enemy.kind == "archive_courier":
		if signal_status == "courier" and time < signal_until:
			_receive_signal()
		effects.append({"kind":"explosion", "p":enemy.p, "life":0.5, "max_life":0.5, "born":tick})
		return
	kills += 1
	# Ace rewards rapid, accurate auto-weapon kills with a visible crossfire
	# from the destruction point. The shots cannot trigger the combo again.
	if pilot_id == "ace" and weapon in ["pulse", "seeker", "arc", "lance"] and not str(enemy.kind).begins_with("boss"):
		ace_chain = ace_chain + 1 if ace_chain_left > 0.0 else 1
		ace_chain_left = 6.0
		if ace_chain >= 3:
			ace_chain = 0
			ace_chain_left = 0.0
			var strikes := 0
			for nearby in enemies:
				if strikes >= 2:
					break
				if float(nearby.hp) > 0.0 and int(nearby.id) != int(enemy.id) and enemy.p.distance_squared_to(nearby.p) <= 370.0 * 370.0:
					effects.append({"kind":"lance", "p":enemy.p, "to":nearby.p, "life":0.45, "max_life":0.45, "born":tick})
					_damage_enemy(nearby, 14.0 * weapon_power(), "precision")
					strikes += 1
			if strikes > 0:
				pilot_procs.ace += 1
				_log("PRECISION CROSSFIRE - Ace volley")
	# Hunter's hunted target pays off with an immediate shield recovery and
	# frees the lock for the next threat; the next mark is not instantaneous.
	if pilot_id == "hunter" and int(enemy.id) == hunter_target_id and hunter_mark_left > 0.0:
		shield = minf(max_shield, shield + 10.0)
		hunter_target_id = -1
		hunter_mark_left = 0.0
		hunter_mark_cooldown = maxf(hunter_mark_cooldown, 10.0)
		pilot_procs.hunter += 1
		_log("HUNT COMPLETE - shields restored")
	# The Salvager turns collected wreckage into a physical shockwave every
	# twelve real kills. Chained wreckage damage does not trigger itself.
	if weapon == "arc" and _has_mutation("arc_reactor"):
		var chained := 0
		for nearby in enemies:
			if chained >= 2:
				break
			if float(nearby.hp) > 0.0 and int(nearby.id) != int(enemy.id) and nearby.p.distance_squared_to(enemy.p) <= 180.0 * 180.0:
				effects.append({"kind":"arc", "p":enemy.p, "to":nearby.p, "life":0.42, "max_life":0.42, "born":tick})
				_damage_enemy(nearby, amount * 0.35, "nova")
				chained += 1
	if pilot_id == "scavenger" and weapon != "scrap" and kills % 12 == 0 and not str(enemy.kind).begins_with("boss"):
		effects.append({"kind":"ion-burst", "p":enemy.p, "radius":145.0, "life":0.65, "max_life":0.65, "born":tick})
		var jumped := 0
		for nearby in enemies:
			if jumped >= 2:
				break
			if float(nearby.hp) > 0.0 and int(nearby.id) != int(enemy.id) and nearby.p.distance_squared_to(enemy.p) <= 145.0 * 145.0:
				_damage_enemy(nearby, 30.0 * weapon_power(), "scrap")
				jumped += 1
		pilot_procs.scavenger += 1
		_log("SCRAP STORM - salvaged wreckage discharged")
	hull = minf(max_hull, hull + passive_bonus("field_medic", 0.10, 0.25, 0.50))
	if enemy.kind == "boss_module":
		bonus_cores += int(meta.module_salvage)
		_log(str(enemy.name) + " destroyed - " + boss_phase_label())
	if str(enemy.get("elite_role", "")) == "leader":
		# Escorts should lose their buff even if the leader dies before all
		# queued wings appear. This is a brief tactical opening, not a kill
		# reward or a free removal of the remaining enemies.
		var disrupted := 0
		var squad_id: int = int(enemy.id)
		for wing in enemies:
			if int(wing.id) != squad_id and int(wing.get("elite_squad", -1)) == squad_id and float(wing.hp) > 0.0:
				wing["elite_disrupted"] = true
				wing.fire = maxf(float(wing.fire), 1.8)
				disrupted += 1
		for queued in encounter_queue:
			if queued is Dictionary and int(queued.get("squad", -1)) == squad_id:
				queued["disrupted"] = true
				disrupted += 1
		effects.append({"kind":"elite-broken", "p":enemy.p, "source":squad_id, "life":1.25, "max_life":1.25, "born":tick})
		_log("FORMATION BROKEN - %d escorts disrupted" % disrupted)
	if salvage_left > 0.0 and not secret_entered and enemy.kind != "archive_courier" and not bool(enemy.get("rival", false)) and not bool(enemy.get("rival_escort", false)):
		bonus_cores += 1 + int(upgrades.salvage / 2) + (1 if synergy_active("salvager") else 0)
	# Boss components are targets, but only the core can end a stage or pay a contract.
	var is_boss := _is_boss(str(enemy.kind))
	effects.append({"kind": "explosion", "p": enemy.p, "life": 1.5 if is_boss else 0.5, "max_life": 1.5 if is_boss else 0.5, "born": tick, "boss": is_boss})
	var before := charges.size()
	for charge in charges:
		if int(charge.source) == int(enemy.id):
			# Explain why a heavy-beam warning vanishes when its emitter dies.
			# The playfield holds the cue in real time even at 3x game speed.
			effects.append({"kind":"beam-canceled", "p":enemy.p, "x":float(charge.x), "source":int(enemy.id), "reason":"source", "life":1.0, "max_life":1.0, "born":tick})
	charges = charges.filter(func(c): return c.source != enemy.id)
	beams_cancelled += before - charges.size()
	if charges.size() < before:
		_log("Beam canceled - charging enemy destroyed")
	xp += enemy.xp * (1.0 + meta.xp * 0.06 + upgrades.harvester * 0.08 + (0.15 if rank_at("harvester", 5) else 0.0) + (0.25 if rank_at("harvester", 10) else 0.0) + (0.20 if passive_link_active("field_recovery") else 0.0) + (0.25 if pilot_id == "scavenger" else 0.0)) * (1.50 if route_choice == "bounty" else 1.0)
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		pending_levels += 1
	if enemy.kind == "splitter" and enemies.size() < _enemy_limit() - 2:
		for i in range(2):
			_add_enemy("drone", enemy.p + Vector2((i * 2 - 1) * 22, 14))
	if is_boss:
		if secret_entered:
			archive_attack = ""
			bullets.clear()
		if not secret_entered and hull > max_hull * 0.60:
			bonus_cores += int(meta.clean_clear) * 3
		if stage_risk > 1.0:
			var reward: int = 30 * stage
			bonus_cores += reward
			bounty_earned += reward
			_log("Bounty contract complete - +%d base cores" % reward)
		last_boss_position = enemy.p
		stage_clears = stage
		stage_transition_queued = true
		_log("%s destroyed · Stage %d complete" % [boss_name(), stage])

func xp_needed() -> int:
	return 25 + (level - 1) * 9

func _hit(amount: float, kind: String, source: String) -> void:
	if ended:
		return
	amount *= stage_damage_scale() * enemy_damage_multiplier()
	if aegis_left > 0:
		prevented += amount
		effects.append({"kind": "shield-hit", "p": ship_position(), "life": 0.16, "max_life": 0.16, "born": tick})
		return
	var reduced := amount * stage_risk * stage_defense
	# Boss projectile defense only covers ordinary status/chaff rounds and
	# boss-launched missiles. Charged heavy beams and slag still require
	# their own specific counters, not an invisible blanket resistance.
	if source.begins_with("boss") and kind not in ["heavy", "hazard"]:
		reduced *= 1.0 - float(meta.point_defense) * 0.05
	# Simultaneous boss4 heavy lanes can both hit an autopiloted ship on a
	# single simulation frame. Leave the first full-strength and cap the
	# second to 35%, without shortening charge telegraphs or changing Aegis.
	if kind == "heavy":
		if tick == last_heavy_hit_tick:
			reduced *= 0.35
			_log("Overlapping heavy beams - secondary impact reduced")
		last_heavy_hit_tick = tick
	# Haven's support chassis resists damaging status rounds, which dominate
	# later worlds; direct beams, chaff, mines and escaped enemies still hurt.
	if kind in ["ion", "corrosion", "disrupt", "heat", "gravity", "void"]:
		reduced *= status_damage_multiplier()
	if ship_id == "haven" and kind in ["ion", "corrosion", "disrupt", "heat", "gravity", "void"]:
		reduced *= 0.75
	if kind in ["heavy", "ordnance"] or (kind == "hazard" and source in ["Molten slag", "Proximity mine"]):
		reduced *= (1.0 - passive_bonus("ablative", 0.03, 0.05, 0.05)) * (1.0 - meta.beam_plating * 0.03)
	if kind == "ion":
		shield_offline = maxf(shield_offline, 4.0 * status_duration_scale())
	elif kind == "heat":
		heat_left = maxf(heat_left, 5.0 * status_duration_scale())
	elif kind == "gravity":
		gravity_left = maxf(gravity_left, 4.5 * status_duration_scale())
	elif kind == "void":
		# The Citadel's early void swarms once bypassed shields for 30% on
		# every hit, disproportionately punishing non-Nova defensive builds.
		# Preserve the shield-piercing identity while leaving counterplay.
		var hull_bleed := 0.20 if stage == 4 else 0.30
		hull = maxf(0.0, hull - reduced * hull_bleed * hull_damage_multiplier())
		reduced *= 1.0 - hull_bleed
	elif kind == "corrosion":
		corrosion_left = maxf(corrosion_left, 5.0 * status_duration_scale())
	elif kind == "disrupt":
		for id in active_slots:
			if cooldowns[id] > 0.0:
				cooldowns[id] = minf(60.0, cooldowns[id] + 2.0 * status_duration_scale())
	if kind == "chaff":
		reduced = maxf(reduced * 0.25, reduced - upgrades.armor * 0.35 - meta.armor * 0.12 - (0.75 if ship_id == "bulwark" else 0.0) - (0.65 if rank_at("armor", 5) else 0.0) - (1.10 if rank_at("armor", 10) else 0.0) - (0.25 if passive_link_active("reinforced_plating") else 0.0))
	var shield_damage := minf(shield, reduced)
	var had_shield := shield > 0.0
	shield -= shield_damage
	var hull_damage := reduced - shield_damage
	hull = maxf(0.0, hull - hull_damage * hull_damage_multiplier())
	effects.append({"kind": "hull-hit" if hull_damage > 0 else "shield-hit", "p": ship_position(), "life": 0.22, "max_life": 0.22, "born": tick})
	damage_taken[kind] = float(damage_taken.get(kind, 0.0)) + reduced
	if had_shield and shield <= 0:
		if pilot_id == "engineer" and hull > 0.0:
			sentry_left = 6.0
			sentry_timer = 0.0
			pilot_procs.engineer += 1
			_log("FIELD SENTRY - Engineer deployed an emergency turret")
		shield_offline = maxf(0.5, (1.5 if passive_link_active("shield_cycle") else 3.0) - meta.shield_restart * 0.2)
		effects.append({"kind": "shield-break", "p": ship_position(), "life": 0.75, "max_life": 0.75, "born": tick})
		_log("Shield broke")
		# Shieldstorm is an earned Aegis + Flak fusion, not a free route effect.
		# Once per world, its reactive pulse sweeps projectiles/charges (not enemies
		# or XP) after an actual survivable shield break. World 1 is unchanged.
		if stage >= 2 and "shieldstorm" in active_slots and not shieldstorm_pulse_used and hull > 0.0:
			shieldstorm_pulse_used = true
			for bullet in bullets:
				prevented += float(bullet.get("damage", 0.0))
			beams_cancelled += charges.size()
			bullets.clear()
			charges.clear()
			effects.append({"kind":"fusion-cast", "fusion":"shieldstorm", "p":ship_position(), "life":0.9, "max_life":0.9, "born":tick, "targets":[]})
			_log("Shieldstorm automatically swept incoming fire on shield break")
		if _has_prototype("emergency_safeguard") and not safeguard_used:
			safeguard_used = true
			shield_offline = 0.0
			shield = minf(max_shield, max_shield * 0.80)
			hull = minf(max_hull, hull + 15.0)
			_log("Emergency Safeguard rebuilt 80% shields and repaired 15 hull")
	if kind != "chaff" or hull_damage > 0.0:
		_log("%s · %.1f %s damage%s" % [source, reduced, kind, " to hull" if hull_damage > 0 else " to shield"])
	if hull <= 0:
		ended = true
		if source == "rival" or content.enemies.has(source):
			last_killing_source = source
		var availability := PackedStringArray()
		for id in Catalog.ABILITIES:
			if upgrades[id] > 0:
				availability.append("%s %.1fs" % [content.abilities[id].name, cooldowns[id]])
		_log("Hull lost · " + " / ".join(availability))
	elif hull < max_hull * 0.35 and meta.emergency > 0 and not emergency_used:
		emergency_used = true
		aegis_left = maxf(aegis_left, 1.0 + meta.emergency * 0.5)
		_log("Emergency field deployed")

func activate(ability: String) -> bool:
	if ended or stage_transition_queued or secret_intro_pending or not intermission_step.is_empty() or not cards.is_empty() or ability not in active_slots or not cooldowns.has(ability) or int(upgrades.get(ability, 0)) <= 0 or cooldowns[ability] > 0.0:
		return false
	ability_uses += 1
	if signal_cast_window():
		_receive_signal()
	if secret_entered and not archive_attack.is_empty():
		_counter_archive_attack()
	var effect_strength: float = ability_power() * _active_rank_scale(ability)
	cooldowns[ability] = float(content.abilities[ability].cooldown) * maxf(0.4, 1.0 - upgrades.coolant * 0.08 - meta.ability_cooldown * 0.03 - (0.15 if pilot_id == "tactician" else 0.0)) * cooldown_multiplier() * _active_rank_cooldown(ability)
	if not stage_casts.has(ability):
		cooldowns[ability] *= 1.0 - meta.opening_charge * 0.10
		stage_casts[ability] = true
	cooldown_totals[ability] = cooldowns[ability]
	hull = minf(max_hull, hull + meta.cast_repair)
	aftercast_left = 4.0
	shield = minf(max_shield, shield + meta.reserve_shield * 5 + max_shield * passive_bonus("shield_surge", 0.0075, 0.025, 0.05))
	_log(str(content.abilities[ability].name) + " used")
	# The Tactician gets one earned counterbattery per world. An ability used
	# on an empty screen earns nothing: time it into real incoming danger.
	if pilot_id == "tactician" and not tactician_counter_used:
		var imminent: bool = charges.any(func(c): return float(c.remaining) > 0.0 and float(c.remaining) <= 0.8)
		for bullet in bullets:
			if (bullet.p + bullet.v * 0.35).distance_squared_to(ship_position(time + 0.35)) < 110.0 * 110.0:
				imminent = true
				break
		if imminent:
			tactician_counter_used = true
			var kept: Array = []
			var suppressed := 0
			for bullet in bullets:
				if suppressed < 3 and bullet.p.distance_squared_to(ship_position()) <= 155.0 * 155.0:
					prevented += float(bullet.get("damage", 0.0))
					suppressed += 1
				else:
					kept.append(bullet)
			bullets = kept
			for slot in active_slots:
				if cooldowns.has(slot) and float(cooldowns[slot]) > 0.0:
					cooldowns[slot] *= 0.82
					if slot == ability:
						cooldown_totals[slot] = cooldowns[slot]
			effects.append({"kind":"ion-burst", "p":ship_position(), "radius":150.0, "life":0.6, "max_life":0.6, "born":tick})
			pilot_procs.tactician += 1
			_log("TACTICAL COUNTERBATTERY - %d threats suppressed" % suppressed)
	if not fusion_spec(ability).is_empty():
		_activate_fusion(ability, effect_strength)
		return true
	if ability == "aegis":
		# A well-read telegraph earns a small resource rebate; blind cooldown
		# casts still give normal short-lived immunity without the bonus.
		var imminent := charges.any(func(c): return float(c.remaining) > 0.0 and float(c.remaining) <= 0.7 and absf(ship_position(time + float(c.remaining)).x - float(c.x)) < 43.0)
		if not imminent:
			var near_ship: Vector2 = ship_position(time + 0.30)
			for bullet in bullets:
				if (bullet.p + bullet.v * 0.30).distance_squared_to(near_ship) < 65.0 * 65.0:
					imminent = true
					break
		if imminent:
			shield = minf(max_shield, shield + (18.0 if stage >= 2 else 14.0) * effect_strength)
			cooldowns[ability] *= 0.75
			cooldown_totals[ability] = cooldowns[ability]
			effects.append({"kind":"timed-counter", "p":ship_position(), "life":0.65, "max_life":0.65, "born":tick})
			_log("Aegis precision counter - shields restored")
		aegis_left = minf((1.8 + (upgrades.aegis - 1) * 0.25) * effect_strength, maxf(0.0, cooldowns[ability] - 1.5))
	elif ability == "nova":
		beams_cancelled += charges.size()
		charges.clear()
		prevented += bullets.reduce(func(total, b): return total + b.damage if b.p.distance_squared_to(ship_position()) < 160 * 160 else total, 0.0)
		bullets.clear()
		effects.append({"kind": "nova", "p": ship_position(), "life": 0.65, "max_life": 0.65, "born": tick})
		for enemy in enemies:
			_damage_enemy(enemy, 65.0 * (1 + (upgrades.nova - 1) * 0.25) * effect_strength, "nova")
		enemies = enemies.filter(func(e): return e.hp > 0.0)
	elif ability == "barrage":
		var targets := enemies.filter(func(e): return e.hp > 0)
		for i in range(7 + (int(upgrades.barrage) - 1) * 2):
			var target: Dictionary = targets[i % targets.size()] if not targets.is_empty() else {}
			shots.append({"p":ship_position() + Vector2(0, -30), "v":Vector2.UP.rotated((i - 3) * 0.14) * 650, "damage":(24 + upgrades.barrage * 5) * effect_strength, "weapon":"barrage", "target":int(target.get("id", -1))})
	elif ability == "overdrive":
		overdrive_left = (4.0 + (upgrades.overdrive - 1) * 0.6) * effect_strength
	elif ability == "chrono":
		chrono_left = (4.0 + (upgrades.chrono - 1) * 0.5) * effect_strength
	elif ability == "mend":
		mend_left = 4.0
		# This ship invests in field repair instead of the second starting gun.
		mend_rate = (24 + (upgrades.mend - 1) * 6) * effect_strength * (1.25 if ship_id == "haven" else 1.0) / 4.0
		# Repair drones are the support counter to the status damage in
		# Ion Storm and the weapon-suppressing heat of Solar Foundry.
		if corrosion_left > 0.0 or heat_left > 0.0:
			corrosion_left = 0.0
			heat_left = 0.0
			_log("Repair drones purged corrosion and overheating")
		# Later-world Mend can also reboot suppressed shields.
		if stage >= 2 and shield_offline > 0.0:
			shield_offline = 0.0
			_log("Repair drones restarted suppressed shields")
		if upgrades.mend >= 5:
			shield = minf(max_shield, shield + 15)
	elif ability == "flak":
		var close_call := false
		for bullet in bullets:
			if bullet.kind == "ordnance" and (bullet.p + bullet.v * 0.45).distance_squared_to(ship_position(time + 0.45)) < 90.0 * 90.0:
				close_call = true
			elif bullet.kind in ["mine", "slag"] and float(bullet.get("fuse", 10.0)) <= 0.75 and bullet.p.distance_squared_to(ship_position()) < 110.0 * 110.0:
				close_call = true
		var stopped := bullets.filter(func(b): return b.kind in ["ordnance", "mine", "slag"]).size()
		bullets = bullets.filter(func(b): return b.kind not in ["ordnance", "mine", "slag"])
		prevented += stopped * 12.0
		if stopped > 0 and close_call:
			shield = minf(max_shield, shield + (16.0 if stage >= 2 else 10.0) * effect_strength)
			cooldowns[ability] *= 0.90
			cooldown_totals[ability] = cooldowns[ability]
			effects.append({"kind":"timed-counter", "p":ship_position(), "life":0.65, "max_life":0.65, "born":tick})
			_log("Flak close-call intercept - shield restored")
		for enemy in enemies:
			if enemy.kind in ["missile_bomber", "minelayer", "slag_bomber", "boss2", "boss3", "boss4"]:
				_damage_enemy(enemy, 30.0 * effect_strength, "flak")
	elif ability == "emp":
		beams_cancelled += charges.size()
		charges.clear()
		emp_left = (3.0 + upgrades.emp * 0.25) * effect_strength
	elif ability == "deflector":
		var remaining: Array = []
		var absorbed := 0
		for bullet in bullets:
			if _is_small_shot(str(bullet.kind)) and bullet.p.distance_squared_to(ship_position()) < 300.0 * 300.0:
				absorbed += 1
			else:
				remaining.append(bullet)
		bullets = remaining
		shield = minf(max_shield, shield + absorbed * (2.0 + upgrades.deflector * 0.5))
		prevented += absorbed * 1.5
	elif ability == "strike":
		var target: Dictionary = {}
		for enemy in enemies:
			if target.is_empty() or enemy.hp > target.hp:
				target = enemy
		for charge in charges:
			for enemy in enemies:
				if enemy.id == charge.source:
					target = enemy
		if not target.is_empty():
			# A bounded slice of boss max HP keeps Rail Strike useful in later worlds.
			var boss_bonus := minf(2200.0, float(target.max_hp) * 0.008) if str(target.kind).begins_with("boss") else 0.0
			_damage_enemy(target, (170.0 + 70.0 * upgrades.strike + boss_bonus) * effect_strength, "strike")
	elif ability == "prism":
		var remaining: Array = []
		var reflected := 0
		for bullet in bullets:
			if reflected < 18 and _is_small_shot(str(bullet.kind)) and bullet.p.distance_squared_to(ship_position()) < 310.0 * 310.0:
				var target := _nearest(bullet.p)
				shots.append({"p": bullet.p, "v": Vector2.UP * 630.0, "damage": (15.0 + upgrades.prism * 4.0) * effect_strength, "weapon": "barrage", "target": int(target.get("id", -1))})
				reflected += 1
			else:
				remaining.append(bullet)
		bullets = remaining
		prevented += reflected * 1.5
	elif ability == "barrier":
		barrier_left = (6.0 + upgrades.barrier * 0.75) * effect_strength
	elif ability == "capacitor":
		shield_offline = 0.0
		shield = minf(max_shield, shield + (30.0 + upgrades.capacitor * 15.0) * effect_strength)
	elif ability == "focus":
		focus_left = (6.0 + upgrades.focus * 0.6) * effect_strength
	elif ability == "decoy":
		decoy_left = (5.0 + upgrades.decoy * 0.6) * effect_strength
	elif ability == "jammer":
		jammer_left = (5.0 + upgrades.jammer * 0.5) * effect_strength
		# The regular cast suppresses future charges. A cast during the visible
		# final 1.5s of a beam charge also interrupts it and earns a cooldown rebate.
		var precise_interrupt := charges.any(func(c): return float(c.remaining) > 0.0 and float(c.remaining) <= 0.9)
		var interrupted := charges.filter(func(c): return float(c.remaining) > 0.0 and float(c.remaining) <= 1.5).size()
		if interrupted > 0:
			charges = charges.filter(func(c): return float(c.remaining) > 1.5)
			beams_cancelled += interrupted
			cooldowns[ability] *= (0.70 if precise_interrupt else 0.90)
			cooldown_totals[ability] = cooldowns[ability]
			effects.append({"kind":"timed-counter", "p":ship_position(), "life":0.65, "max_life":0.65, "born":tick})
			_log("Signal jammer interrupted %d charging beam(s)" % interrupted)
	elif ability == "siphon":
		var target := _nearest(ship_position())
		if not target.is_empty():
			# Scale boss damage modestly, but never allow late-world boss HP to
			# create limitless healing. Heal only for damage actually inflicted.
			var boss_bonus := minf(1200.0, float(target.max_hp) * 0.004) if str(target.kind).begins_with("boss") else 0.0
			var before: float = float(damage_dealt.get("siphon", 0.0))
			_damage_enemy(target, (75.0 + upgrades.siphon * 38.0 + boss_bonus) * effect_strength, "siphon")
			var actual: float = maxf(0.0, float(damage_dealt.get("siphon", 0.0)) - before)
			hull = minf(max_hull, hull + minf(25.0 * effect_strength, actual * 0.30))
	elif ability == "overload":
		var remaining: Array = []
		var detonated := 0
		for bullet in bullets:
			if bullet.kind == "chaff" and bullet.p.distance_squared_to(ship_position()) < 450.0 * 450.0:
				detonated += 1
			else:
				remaining.append(bullet)
		bullets = remaining
		for enemy in enemies:
			_damage_enemy(enemy, minf(250.0, 35.0 + detonated * 5.0 + upgrades.overload * 14.0) * effect_strength, "overload")
	elif ability == "reboot":
		for id in active_slots:
			if id != "reboot":
				cooldowns[id] = maxf(0.0, cooldowns[id] * 0.4 - 2.0 * upgrades.reboot * effect_strength)
	elif ability == "wing_drones":
		_launch_escorts(2 + int(rank_at("wing_drones",5)) + int(rank_at("wing_drones",10)), (6.0 + (upgrades.wing_drones-1)*0.35) * effect_strength, (12.0 + upgrades.wing_drones*2.5) * effect_strength)
	elif ability == "ion_mine":
		_deploy_ion_mines(2 if rank_at("ion_mine",10) else 1, (150.0+upgrades.ion_mine*24.0)*effect_strength, 190.0 if rank_at("ion_mine",5) else 150.0)
	elif ability == "salvage":
		salvage_left = (10.0 + upgrades.salvage * 1.0) * effect_strength
	if ability not in ["aegis", "nova", "ion_mine"]:
		effects.append({"kind":ability, "p":ship_position(), "life":0.6, "max_life":0.6, "born":tick})
	return true

func _activate_fusion(id: String, strength: float) -> void:
	# One cast, one cooldown, and one occupied slot for the two source abilities.
	var visual := {"kind":"fusion-cast", "fusion":id, "p":ship_position(), "life":0.9, "max_life":0.9, "born":tick, "targets":[]}
	match id:
		"nova_aegis":
			# Countering a telegraphed beam or a shot about to connect pays off.
			# Firing as soon as the cooldown ends still clears bullets, but loses
			# the shield, hull and cooldown rebate of a well-timed counter.
			var counter_window: bool = charges.any(func(c): return float(c.remaining) <= 0.7)
			if not counter_window:
				var soon: Vector2 = ship_position(time + 0.30)
				for bullet in bullets:
					if (bullet.p + bullet.v * 0.30).distance_squared_to(soon) < 65.0 * 65.0:
						counter_window = true
						break
			visual["counter"] = counter_window
			if counter_window:
				shield = minf(max_shield, shield + 40.0 * strength)
				hull = minf(max_hull, hull + 12.0 * strength)
				cooldowns[id] *= 0.65
				_log("Nova Guard countered incoming fire")
			aegis_left = maxf(aegis_left, minf((3.8 if counter_window else 2.4) * strength, maxf(0.0, cooldowns[id] - 1.5)))
			shield = minf(max_shield, shield + 28.0 * strength)
			beams_cancelled += charges.size()
			charges.clear()
			prevented += bullets.reduce(func(sum, b): return sum + float(b.damage), 0.0)
			bullets.clear()
			# The blast is deliberately modest on an early cast; a true counter
			# is much more powerful. This makes timing matter more than spam.
			var blast: float = (235.0 if counter_window else 70.0) * strength
			for enemy in enemies:
				_damage_enemy(enemy, blast, "nova")
		"shieldstorm":
			# A protective alternative to Nova Guard: no free kills or blast XP.
			for bullet in bullets:
				prevented += float(bullet.get("damage", 0.0))
			beams_cancelled += charges.size()
			bullets.clear()
			charges.clear()
			shield_offline = 0.0
			shield = minf(max_shield, shield + 45.0 * strength)
			aegis_left = maxf(aegis_left, minf(3.3 * strength, maxf(0.0, cooldowns[id] - 1.5)))
			_log("Shieldstorm cleared incoming fire and reinforced shielding")
		"railstorm":
			overdrive_left = maxf(overdrive_left, 7.0 * strength)
			for n in range(3):
				var target: Dictionary = _nearest(ship_position())
				if not target.is_empty():
					visual.targets.append(target.p)
					_damage_enemy(target, 180.0 * strength, "strike")
		"stasis_lock":
			chrono_left = maxf(chrono_left, 6.0 * strength)
			emp_left = maxf(emp_left, 5.0 * strength)
			beams_cancelled += charges.size()
			charges.clear()
			for enemy in enemies:
				_damage_enemy(enemy, 45.0 * strength, "nova")
		"repair_matrix":
			mend_left = 6.0
			mend_rate = (62.0 * strength) / mend_left
			shield_offline = 0.0
			shield = minf(max_shield, shield + 65.0 * strength)
			barrier_left = maxf(barrier_left, 4.0 * strength)
			corrosion_left = 0.0
			heat_left = 0.0
		"missile_grid":
			var stopped := bullets.filter(func(b): return b.kind in ["ordnance", "mine", "slag"]).size()
			bullets = bullets.filter(func(b): return b.kind not in ["ordnance", "mine", "slag"])
			prevented += stopped * 12.0
			var targets: Array = enemies.filter(func(e): return float(e.hp) > 0.0)
			for n in range(14):
				if targets.is_empty():
					break
				var target: Dictionary = targets[n % targets.size()]
				shots.append({"p":ship_position() + Vector2((n % 3 - 1) * 9, -28), "v":Vector2.UP.rotated((n - 7) * 0.10) * 710.0, "damage":40.0 * strength, "weapon":"barrage", "fusion":id, "target":int(target.id)})
		"scrap_converter":
			salvage_left = maxf(salvage_left, 16.0 * strength)
			var target: Dictionary = _nearest(ship_position())
			if not target.is_empty():
				visual.targets.append(target.p)
				var dealt: float = minf(float(target.hp), 175.0 * strength)
				_damage_enemy(target, dealt, "siphon")
				hull = minf(max_hull, hull + dealt * 0.55)
		"prism_focus":
			focus_left = maxf(focus_left, 9.0 * strength)
			var kept: Array = []
			var turned := 0
			for bullet in bullets:
				if turned < 25 and bullet.p.distance_squared_to(ship_position()) < 400.0 * 400.0:
					var target: Dictionary = _nearest(bullet.p)
					if not target.is_empty():
						shots.append({"p":bullet.p, "v":Vector2.UP * 700.0, "damage":35.0 * strength, "weapon":"barrage", "fusion":id, "target":int(target.id)})
						turned += 1
						continue
				kept.append(bullet)
			bullets = kept
			prevented += turned * 2.0
		"reflective_wall":
			barrier_left = maxf(barrier_left, 10.0 * strength)
			var absorbed := bullets.filter(func(b): return b.kind in ["chaff", "ion", "corrosion", "disrupt"]).size()
			bullets = bullets.filter(func(b): return b.kind not in ["chaff", "ion", "corrosion", "disrupt"])
			shield = minf(max_shield, shield + absorbed * 3.5 * strength)
			prevented += absorbed * 2.0
			for n in range(mini(12, absorbed)):
				var target: Dictionary = _nearest(ship_position())
				if not target.is_empty():
					shots.append({"p":ship_position(), "v":Vector2.UP * 720.0, "damage":28.0 * strength, "weapon":"barrage", "fusion":id, "target":int(target.id)})
		"ghost_signal":
			jammer_left = maxf(jammer_left, 10.0 * strength)
			decoy_left = maxf(decoy_left, 10.0 * strength)
			beams_cancelled += charges.size()
			charges.clear()
			var stopped := bullets.filter(func(b): return b.kind == "ordnance").size()
			bullets = bullets.filter(func(b): return b.kind != "ordnance")
			prevented += stopped * 12.0
		"storm_carrier":
			_launch_escorts(4, 8.0 * strength, 30.0 * strength)
			_deploy_ion_mines(3, 260.0 * strength, 190.0)
		"reactor_surge":
			for slot in active_slots:
				if str(slot) != id:
					cooldowns[str(slot)] = maxf(0.0, float(cooldowns.get(str(slot), 0.0)) * 0.25 - 2.0)
			var detonated := bullets.filter(func(b): return b.kind == "chaff").size()
			bullets = bullets.filter(func(b): return b.kind != "chaff")
			for enemy in enemies:
				_damage_enemy(enemy, minf(320.0, 70.0 + detonated * 7.0) * strength, "overload")
	effects.append(visual)


func _offer_cards(consume_level: bool = true) -> void:
	var pool: Array = []
	var mutation_pool: Array = []
	for card in content.cards:
		if stage < int(card.get("min_stage", 1)):
			continue
		if card.tag == "MUTATION":
			var spec: Dictionary = Catalog.mutation(str(card.id))
			if mutations.is_empty() and artifact_id != "drone_armada" and int(upgrades.get(str(spec.requires), 0)) > 0 and int(upgrades.get(str(card.id), 0)) == 0 and card.id not in banished:
				mutation_pool.append(card.duplicate(true))
			continue
		if artifact_id == "drone_armada" and card.tag in ["WEAPON", "MUTATION"]:
			continue
		if not fused_into(str(card.id)).is_empty():
			continue
		if not fusion_spec(str(card.id)).is_empty() and str(card.id) not in active_slots:
			continue
		if upgrades[card.id] < int(card.max) and card.id not in banished:
			if card.tag == "ABILITY" and upgrades[card.id] == 0 and not _can_learn_active(str(card.id)):
				continue
			pool.append(card.duplicate(true))
	cards.clear()
	# Draw once, checkpoint the exact hand. RNG state is part of the save.
	while cards.size() < 3 + int(meta.extra_card) and not pool.is_empty():
		var index := rng.randi_range(0, pool.size() - 1)
		cards.append(pool.pop_at(index))
	# At every even early level, show a discoverable synergy partner alongside
	# independent upgrades. No automatic installation or extra active slot.
	if level % 2 == 0:
		var has_new := cards.any(func(c): return c.tag == "ABILITY" and upgrades[c.id] == 0)
		var learnable := pool.filter(func(c): return c.tag == "ABILITY" and upgrades[c.id] == 0)
		if not has_new and not learnable.is_empty():
			cards[-1] = learnable[rng.randi_range(0, learnable.size() - 1)]
		var has_partner := cards.any(func(c): return c.tag == "ABILITY" and upgrades[c.id] == 0 and (not fusion_hint(str(c.id)).is_empty() or not synergy_hint(str(c.id)).is_empty()))
		var partners := learnable.filter(func(c): return not fusion_hint(str(c.id)).is_empty() or not synergy_hint(str(c.id)).is_empty())
		if not has_partner and not partners.is_empty():
			var options: Array = partners.filter(func(p): return not cards.any(func(c): return c.id == p.id))
			if not options.is_empty():
				cards[0] = options[rng.randi_range(0, options.size() - 1)]
	# Once an active is invested to rank 3, occasionally surface its
	# still-missing fusion partner as a *choice*, not a free installation.
	# Preserve the free-slot, banish, and max-rank rules from the actual pool.
	if level >= 4 and level % 3 == 0 and active_slots.size() < Catalog.ACTIVE_SLOTS and not cards.is_empty():
		var missing_partners: Array = []
		for fusion in content.fusions:
			var first: String = str(fusion.parts[0])
			var second: String = str(fusion.parts[1])
			var candidate := ""
			if first in active_slots and int(upgrades[first]) >= 3 and second not in active_slots:
				candidate = second
			elif second in active_slots and int(upgrades[second]) >= 3 and first not in active_slots:
				candidate = first
			if not candidate.is_empty():
				for option in pool:
					if str(option.id) == candidate and not cards.any(func(c): return str(c.id) == candidate):
						missing_partners.append(option)
		if not missing_partners.is_empty():
			cards[cards.size() - 1] = missing_partners[rng.randi_range(0, missing_partners.size() - 1)]
	# Rare, opt-in transformation: at a four-level milestone in later
	# worlds, one normal card may be replaced by a matching weapon mutation.
	# Never inject a weapon the player does not own.
	if stage >= 2 and level % 4 == 0 and mutations.is_empty() and not cards.is_empty() and rng.randi_range(0, 2) == 0:
		var candidates: Array = mutation_pool
		if not candidates.is_empty():
			cards[cards.size() - 1] = candidates[rng.randi_range(0, candidates.size() - 1)]
	if hull < max_hull * 0.40 and not cards.is_empty():
		var has_defense := false
		for card in cards:
			has_defense = has_defense or card.id in ["armor", "regen", "hull", "aegis"]
		if not has_defense:
			cards[0] = {"id": "repair", "name": "Emergency repair", "tag": "RECOVERY", "description": "Restore 30 hull immediately.", "max": 99}
	if cards.is_empty():
		cards.append({"id": "repair", "name": "Field repair", "tag": "RECOVERY", "description": "Restore 30 hull.", "max": 99})
		cards.append({"id": "core_cache", "name": "Salvage Cores", "tag": "RECOVERY", "description": "Bank %d Cores for the end of this flight." % MAXED_DRAFT_CORES, "max": 99})
	if consume_level:
		pending_levels -= 1

func reroll_cards() -> bool:
	if cards.is_empty() or rerolls_left <= 0:
		return false
	# Spend the renewable stage allowance before the one-off pilot bonus.
	if rerolls_left <= pilot_rerolls_left:
		pilot_rerolls_left = maxi(0, pilot_rerolls_left - 1)
	rerolls_left -= 1
	_offer_cards(false)
	if int(meta.reroll_focus) > 0: _focus_reroll()
	return true

func banish_card(index: int) -> bool:
	if index < 0 or index >= cards.size() or banishes_left <= 0 or str(cards[index].id) in ["repair", "core_cache"]:
		return false
	banishes_left -= 1
	banished.append(cards[index].id)
	_offer_cards(false)
	return true

func skip_cards() -> bool:
	if cards.is_empty() or skips_left <= 0:
		return false
	skips_left -= 1
	hull = minf(max_hull, hull + 12 + meta.skip_patch * 6)
	cards.clear()
	return true

func choose_card(index: int) -> bool:
	if index < 0 or index >= cards.size():
		return false
	var id: String = cards[index].id
	if not fused_into(id).is_empty():
		return false
	if id == "repair":
		hull = minf(max_hull, hull + 30)
	elif id == "core_cache":
		choice_cores += MAXED_DRAFT_CORES
	elif not Catalog.mutation(id).is_empty():
		if not _install_mutation(id):
			return false
	else:
		var card: Dictionary = cards[index]
		if card.tag == "ABILITY" and int(upgrades[id]) == 0:
			if not _can_learn_active(id):
				return false
			active_slots.append(id)
		var before: int = int(upgrades[id])
		var increment: int = 1 if card.tag == "ABILITY" and before == 0 else 2
		upgrades[id] = mini(int(card.max), before + increment)
		var gained := int(upgrades[id]) - before
		if id == "hull":
			max_hull += 18 * gained
			hull = minf(max_hull, hull + 18 * gained)
		if id == "shield":
			max_shield += 10 * gained
			shield = minf(max_shield, shield + 10 * gained)
		if id in ["hull", "shield"]:
			for milestone in [5, 10]:
				var marker: String = id + str(milestone)
				if before < milestone and rank_at(id, milestone) and marker not in capacity_milestones:
					capacity_milestones.append(marker)
					var bonus: float = (25.0 if milestone == 5 else 50.0) if id == "hull" else (18.0 if milestone == 5 else 35.0)
					if id == "hull":
						max_hull += bonus
						hull = minf(max_hull, hull + bonus)
					else:
						max_shield += bonus
						shield = minf(max_shield, shield + bonus)
		if card.tag == "ABILITY":
			_try_fuse()
	_log("Installed " + cards[index].name)
	cards.clear()
	return true

func _log(message: String) -> void:
	events.append({"time": time, "message": message})
	if events.size() > 120:
		events.pop_front()

func payout() -> int:
	if secret_entered:
		return secret_payout
	var base: int = int((5 + int(kills / 6) + meta.stipend * 2 + (15 * stage_clears + 5 * stage_clears * stage_clears + meta.bounty * 5 * stage_clears) + bonus_cores) * (1.0 + meta.cores * 0.08) * float(Catalog.REWARD_MULTIPLIERS[difficulty]))
	if pilot_id == "scavenger":
		base += maxi(1, int(round(base * 0.15)))
	if synergy_active("salvager"):
		base = int(round(base * 1.25))
	if _has_prototype("salvage_charter"):
		base = int(round(base * 1.75))
	if endless_enabled:
		var bonus_worlds := maxi(0, stage_clears - int(content.stage_count))
		base += 75 * bonus_worlds * (bonus_worlds + 1) / 2
	return base + choice_cores

func snapshot() -> Dictionary:
	var state: Dictionary = {"version": SAVE_VERSION, "rng": rng.state}
	for key in ["signal_count", "signal_status", "signal_until", "secret_entered", "secret_intro_pending", "secret_payout", "archive_next_attack", "archive_attack_until", "archive_exposed_until", "archive_phase", "archive_phase_released", "archive_attack", "archive_attack_x"]:
		state[key] = get(key)
	for key in ["capacity_milestones", "prototypes", "prototype_offers", "intermission_step", "route_choice", "stage_power", "stage_risk", "stage_defense", "stage_fire_rate", "bounty_earned", "safeguard_used", "shieldstorm_pulse_used", "boss_spawn_time", "seed_value", "ship_id", "pilot_id", "artifact_id", "mutations", "lance_refund_ready", "merchant_enabled", "merchant_state", "merchant_offers", "merchant_selected", "merchant_next_at", "merchant_seen_stages", "merchant_visits", "merchant_trade_count", "merchant_pact_power", "merchant_trade_log", "sentry_left", "sentry_timer", "engineer_service_used", "ace_chain", "ace_chain_left", "hunter_target_id", "hunter_mark_left", "hunter_mark_cooldown", "tactician_counter_used", "pilot_procs", "rival_record", "rival_stage", "rival_spawn_at", "rival_spawned", "rival_intro_pending", "rival_retire_pending", "rival_outcome", "last_killing_source", "movement_version", "difficulty", "daily_day", "daily_attempt", "stage", "endless_enabled", "encounter_index", "encounter_queue", "next_encounter_at", "next_pressure_wave_at", "pressure_waves", "opening_scout_wave", "boss_attack_pattern", "cooldown_totals", "stage_start", "stage_clears", "stage_transition_queued", "active_slots", "next_hazard", "tick", "time", "hull", "max_hull", "shield", "max_shield", "shield_offline", "aegis_left", "cooldowns", "upgrades", "enemies", "bullets", "shots", "effects", "charges", "events", "damage_taken", "damage_dealt", "xp", "level", "kills", "cards", "pending_levels", "ended", "won", "next_spawn", "pulse_timer", "seeker_timer", "heavy_ready_at", "boss_spawned", "next_id", "ability_uses", "prevented", "beams_fired", "beams_cancelled", "last_heavy_hit_tick", "meta"]:
		state[key] = get(key)
	for key in ["stage_casts", "escort_left", "escort_timer", "escort_count", "escort_damage", "ion_mines", "aftercast_left", "overdrive_left", "chrono_left", "emp_left", "barrier_left", "focus_left", "decoy_left", "jammer_left", "salvage_left", "corrosion_left", "heat_left", "gravity_left", "last_boss_position", "bonus_cores", "choice_cores", "mend_left", "mend_rate", "emergency_used", "arc_timer", "lance_timer", "rerolls_left", "pilot_rerolls_left", "banishes_left", "skips_left", "banished"]:
		state[key] = get(key)
	return state.duplicate(true)

func restore(state: Dictionary) -> bool:
	if state.get("version", -1) != SAVE_VERSION:
		return false
	for key in state:
		if key not in ["version", "rng"]:
			if key in ["upgrades", "cooldowns", "meta", "damage_dealt", "pilot_procs"]:
				var merged: Dictionary = get(key).duplicate(true)
				merged.merge(state[key], true)
				set(key, merged)
			else:
				set(key, state[key])
	# Preserve an older save's remaining uses; start stage refills at its next warp.
	if not state.has("pilot_rerolls_left"):
		pilot_rerolls_left = mini(rerolls_left, 1) if pilot_id == "tactician" else 0
	movement_version = int(state.get("movement_version", 1))
	if not state.has("active_slots"):
		active_slots.clear()
		for id in Catalog.ABILITIES:
			if int(upgrades.get(id, 0)) > 0 and active_slots.size() < Catalog.ACTIVE_SLOTS:
				active_slots.append(id)
	if difficulty not in Catalog.DIFFICULTIES:
		difficulty = "normal"
	# Older saved flights had rank 5 upgrades but no one-time capacity rewards.
	if not state.has("capacity_milestones"):
		capacity_milestones = []
		for track in ["hull", "shield"]:
			for milestone in [5, 10]:
				if rank_at(track, milestone):
					var bonus: float = (25.0 if milestone == 5 else 50.0) if track == "hull" else (18.0 if milestone == 5 else 35.0)
					capacity_milestones.append(track + str(milestone))
					if track == "hull":
						max_hull += bonus
						hull = minf(max_hull, hull + bonus)
					else:
						max_shield += bonus
						shield = minf(max_shield, shield + bonus)
	endless_stage_spec.clear()
	_build_course()
	rng.state = state.rng
	# Old drafts may contain consumed components, or a new partner that used to
	# bypass a full bar when fusions happened at rank 1. Rebuild those once.
	if cards.any(func(card): return not fused_into(str(card.id)).is_empty() or (card.tag == "ABILITY" and int(upgrades[card.id]) == 0 and not _can_learn_active(str(card.id)))):
		_offer_cards(false)
	return true
