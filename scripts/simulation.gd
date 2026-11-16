extends RefCounted
## Fixed-step simulation: no rendering, platform services, wall clock, or input polling.
const DT := 1.0 / 60.0
const WIDTH := 540.0
const HEIGHT := 960.0
const SAVE_VERSION := 1
const PROTOTYPE_SKIP_CORES := 10
const MAXED_DRAFT_CORES := 5
const Catalog = preload("res://scripts/catalog.gd")
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
var boss_attack_pattern := "sweep"
var cooldown_totals: Dictionary = {}
var stage_start := 0.0
var stage_clears := 0
var stage_transition_queued := false
var active_slots: Array = []
var ship_id := "vanguard"
var pilot_id := "rookie"
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
var meta := Catalog.defaults()

func _init(run_seed: int = 1, hangar: Dictionary = {}, selected_ship: String = "vanguard", selected_pilot: String = "rookie", selected_difficulty: String = "normal") -> void:
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
	for card in content.cards:
		if not upgrades.has(card.id):
			upgrades[card.id] = 0
	ship_id = Catalog.ship(selected_ship).id
	pilot_id = Catalog.pilot(selected_pilot).id
	difficulty = selected_difficulty if selected_difficulty in Catalog.DIFFICULTIES else "normal"
	seed_value = run_seed
	rng.seed = run_seed
	next_encounter_at = 55.0 + float(run_seed % 23)
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
	if ended or stage_transition_queued or not intermission_step.is_empty() or not cards.is_empty():
		return
	tick += 1
	time = tick * DT
	for key in cooldowns:
		cooldowns[key] = maxf(0.0, cooldowns[key] - DT)
	aegis_left = maxf(0.0, aegis_left - DT)
	overdrive_left = maxf(0.0, overdrive_left - DT)
	chrono_left = maxf(0.0, chrono_left - DT)
	for timer in ["aftercast_left", "emp_left", "barrier_left", "focus_left", "decoy_left", "jammer_left", "salvage_left", "corrosion_left", "heat_left", "gravity_left"]:
		set(timer, maxf(0.0, float(get(timer)) - DT))
	if corrosion_left > 0.0:
		var corrosion_damage := DT * 1.4 * stage_damage_scale() * stage_risk * stage_defense
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
	var repair_rate: float = upgrades.repair_bots * 0.15 + meta.repair * 0.15 + (0.25 if ship_id == "haven" else 0.0)
	if rank_at("repair_bots", 5): repair_rate += 0.35
	if rank_at("repair_bots", 10): repair_rate += 0.70
	if passive_link_active("field_recovery"): repair_rate *= 1.40
	hull = minf(max_hull, hull + repair_rate * DT)
	if shield_offline > 0.0:
		shield_offline = maxf(0.0, shield_offline - DT)
	else:
		var recharge: float = (1.5 + upgrades.regen * 0.35 + meta.regen * 0.25 + (0.8 if pilot_id == "engineer" else 0.0)) * DT
		if rank_at("regen", 5): recharge += 0.55 * DT
		if rank_at("regen", 10): recharge += 1.0 * DT
		if passive_link_active("shield_cycle"): recharge *= 1.40
		if synergy_active("fortress"):
			recharge *= 1.60
		if _has_prototype("bastion_lattice"):
			recharge *= 1.85
		shield = minf(max_shield, shield + recharge)
	for effect in effects:
		effect.life -= DT
	effects = effects.filter(func(e): return e.life > 0.0)
	if not boss_spawned and time - stage_start >= float(content.boss_at):
		_spawn_boss()
	if time >= next_spawn and not boss_spawned:
		_spawn_enemy()
		var stage_time := time - stage_start
		var pace := maxf(0.55, 1.65 - stage_time / 260.0)
		# Do not raise late World 1 spawns: extra automatic kills give free XP.
		next_spawn = time + pace / (float(stage_spec().spawn_scale) * threat_scale() * stage_risk)
	if time >= next_hazard and not boss_spawned:
		_spawn_hazard()
		next_hazard = time + rng.randf_range(15.0, 23.0)
	if time >= next_encounter_at and not boss_spawned:
		_spawn_encounter()
		next_encounter_at = time + 66.0 + float((seed_value + encounter_index * 11) % 23)
	_update_enemies()
	_update_charges()
	_update_support()
	_update_weapons()
	_update_bullets()
	_update_shots()
	# A defeated boss pauses the run for an explicit player-controlled celebration.
	if pending_levels > 0 and not ended and not stage_transition_queued:
		_offer_cards()

func threat_scale() -> float:
	return {"normal": 1.0, "hard": 1.25, "insane": 1.6}[difficulty]

func stage_spec() -> Dictionary:
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
	return maxi(int(content.stage_count), stage + 1) if endless_enabled else int(content.stage_count)

func enable_endless() -> bool:
	if endless_enabled or stage != int(content.stage_count) or not stage_transition_queued or stage_clears != stage:
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
	return mini(55, 20 + (stage - 1) * 5)

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

func passive_bonus(id: String, per_rank: float, at_five: float, at_ten: float) -> float:
	return int(upgrades.get(id, 0)) * per_rank + (at_five if rank_at(id, 5) else 0.0) + (at_ten if rank_at(id, 10) else 0.0)

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
		if str(enemy.kind) in ["boss", "boss2", "boss3", "boss4"] and enemy.hp > 0.0:
			return enemy
	return {}

func boss_phase_label() -> String:
	if not boss_spawned:
		return ""
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
	intermission_step = "route" if prototype_offers.is_empty() else "prototype"
	return true

func prototype_spec(id: String) -> Dictionary:
	for spec in content.prototypes:
		if spec.id == id:
			return spec
	return {}

func choose_prototype(index: int) -> bool:
	if intermission_step != "prototype" or index < 0 or index >= prototype_offers.size():
		return false
	var id: String = str(prototype_offers[index])
	if id in prototypes or prototype_spec(id).is_empty():
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

func _spawn_enemy() -> void:
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
		var queued_kind: String = str(encounter_queue.pop_front())
		_add_enemy(queued_kind, Vector2(120.0 + formation_slot * 150.0, -50.0 - formation_slot * 65.0))
		return
	if endless_enabled and stage > int(content.stage_count):
		pool.append_array(["phase_stalker", "slag_bomber", "ion_frigate", "shieldguard", "void_lancer"])
	var kind: String = pool[rng.randi_range(0, pool.size() - 1)]
	_add_enemy(kind, Vector2(rng.randf_range(55, 485), -35))

func _add_enemy(kind: String, position: Vector2) -> void:
	var spec: Dictionary = content.enemies[kind]
	var scaling := (1.0 + (time - stage_start) / 340.0) * float(stage_spec().health_scale) * threat_scale() * stage_risk
	enemies.append({"id": next_id, "kind": kind, "p": position, "hp": float(spec.hp) * scaling, "max_hp": float(spec.hp) * scaling, "speed": float(spec.speed), "fire": rng.randf_range(1.0, 3.0), "xp": int(spec.xp), "phase": rng.randf_range(0, TAU)})
	next_id += 1

## Encounter variants are reproducible by seed. Each has a different timing demand:
## armored escorts, mine-heavy bomber convoys, or protected carrier launches.
func _spawn_encounter() -> void:
	if enemies.size() >= _enemy_limit() - 5 or not encounter_queue.is_empty():
		return
	var ecology := ((stage - 1) % int(content.stage_count)) + 1
	var pattern := (seed_value + stage * 7 + encounter_index * 5) % 3
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
			_log("ELITE CARRIER - prioritize the launch ship")
	encounter_queue = formation.duplicate()

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
	# Hard/Insane are progression difficulties. World 1's boss asks for a
	# stronger build; this costs players time and defense, not bonus XP.
	var opener_boss_scale := 1.50 if difficulty == "hard" else (1.60 if difficulty == "insane" else 1.0)
	if stage != 1:
		opener_boss_scale = 1.0
	var hp := float(spec.boss_hp) * threat_scale() * stage_risk * opener_boss_scale
	var boss_id: int = next_id
	enemies.append({"id": boss_id, "kind": str(spec.boss), "p": Vector2(270, 135), "hp": hp, "max_hp": hp, "speed": 0.0, "fire": 1.0, "xp": 0, "phase": 0.0})
	next_id += 1
	for part in content.boss_modules.get(str(spec.boss), []):
		var part_hp: float = float(part.hp) * threat_scale() * stage_risk * float(stage_spec().get("module_scale", 1.0)) * opener_boss_scale
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
		_log("The Citadel has fallen - full run complete")
		return true
	if intermission_step != "ready" or route_choice not in ["repair", "overclock", "bounty"]:
		return false
	stage += 1
	stage_casts.clear()
	banishes_left += int(meta.banish_relay)
	escort_left = 0.0
	escort_timer = 0.0
	ion_mines.clear()
	rerolls_left = int(meta.rerolls) + pilot_rerolls_left
	encounter_index = 0
	encounter_queue.clear()
	next_encounter_at = time + 55.0 + float((seed_value + stage * 13) % 23)
	endless_stage_spec.clear()
	stage_start = time
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
	stage_defense = 0.82 if route_choice == "repair" else 1.0
	stage_fire_rate = 1.20 if route_choice == "overclock" else 1.0
	var repair_fraction := 0.55 if route_choice == "repair" else (0.10 if route_choice == "overclock" else 0.30)
	hull = minf(max_hull, hull + max_hull * (repair_fraction + meta.warp_repairs * 0.04))
	shield = max_shield * (0.50 if route_choice == "overclock" else 1.0)
	safeguard_used = false
	next_spawn = time + 1.5
	next_hazard = time + 15.0
	heavy_ready_at = time + 10.0
	pending_levels += 1
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
		var kind: String = enemy.kind
		if kind == "boss_module":
			var core: Dictionary = _boss_core()
			if core.is_empty():
				enemy.hp = -1.0
			else:
				enemy.p = core.p + enemy.offset
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
		if (kind in ["sniper", "void_lancer"] or kind.begins_with("boss")) and time >= heavy_ready_at and charges.is_empty() and jammer_left <= 0.0 and emp_left <= 0.0:
			var lead := 2.15 if kind.begins_with("boss") and stage > 1 and boss_attack_pattern == "delayed fan" else 1.8
			var damage := (28.0 if kind in ["sniper", "void_lancer"] else (29.0 + stage * 6.0)) * threat_scale()
			# Late World 1 beam pressure is answerable by Aegis/EMP/Nova/Jammer.
			# This changes damage, not XP or the visible charge warning.
			if stage == 1 and time - stage_start >= 110.0:
				damage *= 1.20
				if difficulty == "hard":
					damage *= 1.15
				elif difficulty == "insane":
					damage *= 1.30
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
			if jammer_left > 0.0 or emp_left > 0.0:
				enemy.fire = 0.5
				continue
			enemy.fire = (2.1 if stage == 1 else maxf(1.1, 1.8 - stage * 0.15)) if kind.begins_with("boss") else float(content.enemies[kind].interval) / threat_scale()
			# More shots late in World 1, without granting additional enemy XP.
			# Boss attacks begin unchanged; the first telegraph stays readable.
			# Fire more often late in the opener on advanced difficulties.
			# Extra enemy kills would grant XP and weaken this pressure curve.
			if stage == 1 and time - stage_start >= 65.0 and not kind.begins_with("boss"):
				if difficulty == "hard":
					enemy.fire *= 0.78
				elif difficulty == "insane":
					enemy.fire *= 0.68
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
				bullets.append({"p": enemy.p, "v": direction * 165.0, "damage": 2.0 * threat_scale(), "kind": "void" if kind == "echo_carrier" else "chaff", "source": kind})
			elif kind in ["minelayer", "slag_bomber"]:
				var is_slag := kind == "slag_bomber"
				bullets.append({"p": enemy.p, "v": Vector2(0, 75 if is_slag else 62), "damage": (18.0 if is_slag else 12.0) * threat_scale(), "kind": "slag" if is_slag else "mine", "hp": 18.0 if is_slag else 14.0, "fuse": 2.9 if is_slag else 3.4, "source": kind})
			else:
				var count := 3
				if kind == "gunship": count = 5
				elif kind in ["interceptor", "rusher"]: count = 2
				elif kind in ["arc_spire", "forge_turret"]: count = 9
				elif kind == "gravity_sentinel": count = 7
				elif kind.begins_with("boss"): count = 9 + stage * 2
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
					bullets.append({"p": enemy.p, "v": direction.rotated(angle) * (260.0 if kind in ["ember_hunter", "phase_stalker"] else 215.0), "damage": (2.1 if kind.begins_with("boss") else (1.25 if kind in ["rusher", "interceptor"] else 1.6)) * threat_scale(), "kind": bullet_kind, "source": kind})
				if kind in ["gunship", "missile_bomber", "station", "boss2", "boss4"]:
					var volley := (1 if _alive_modules("launch_bay") == 0 else 3) if kind == "boss2" else (3 if kind == "boss4" else (2 if kind == "missile_bomber" else 1))
					for i in range(volley):
						bullets.append({"p": enemy.p + Vector2((i * 2 - volley + 1) * 13, 0), "v": direction.rotated((i * 2 - volley + 1) * 0.10) * (175.0 if kind == "missile_bomber" else 140.0), "damage": (11.0 if kind == "missile_bomber" else 12.0) * threat_scale(), "kind":"ordnance", "hp":12.0, "source":kind})
				if kind == "boss3" and boss_phase_label().begins_with("FURNACE SEALED"):
					for i in range(2):
						bullets.append({"p":enemy.p + Vector2((i * 2 - 1) * 70, 10), "v":Vector2(0, 95), "damage":18.0 * threat_scale(), "kind":"slag", "hp":18.0, "fuse":3.2, "source":kind})
		if enemy.p.y > 885:
			enemy.hp = -1.0
			if kind not in ["boulder", "station"]:
				_hit(5.0, "hazard", "Escaped " + kind)
	enemies = enemies.filter(func(e): return e.hp > 0.0)
	for minion in minions:
		if enemies.size() < _enemy_limit():
			_add_enemy(str(minion.kind), minion.p)

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
				_hit(charge.damage, "heavy", boss_name() if boss_spawned else "Heavy lancer")
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

func _update_support() -> void:
	if escort_left > 0.0:
		escort_left = maxf(0.0,escort_left-DT)
		escort_timer -= DT
		if escort_timer <= 0.0 and escort_left > 0.0:
			escort_timer += 0.5
			for i in range(escort_count):
				var p := escort_position(i)
				var target := _nearest(p)
				if not target.is_empty() and shots.size() < 500:
					shots.append({"p":p,"v":(target.p-p).normalized()*700.0,"damage":escort_damage,"weapon":"escort","target":int(target.id)})
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
			shots.append({"p": origin + Vector2((n * 2 - barrels + 1) * 8, 0), "v": Vector2(0, -980).rotated(bank), "damage": (7.0 + (upgrades.pulse - 1) * 1.68) * weapon_power() * (1.25 if pilot_id == "ace" else 1.0) * (1.20 if rank_at("pulse", 10) else 1.0) * (1.20 if passive_link_active("smart_pulse") else 1.0), "weapon": "pulse", "target": -1})
	if upgrades.seeker > 0 and seeker_timer <= 0.0:
		seeker_timer += (0.62 if pilot_id == "hunter" else 0.70)
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
				shots.append({"p": origin + Vector2((n * 2 - volley + 1) * 7, 0), "v": (target_pos - origin).normalized().rotated((n * 2 - volley + 1) * 0.06) * 650.0, "damage": (14.0 + (upgrades.seeker - 1) * 4.2) * (1.0 + meta.ordnance_damage * 0.05) * weapon_power() * (1.35 if ship_id == "wraith" else 1.0) * (1.3 if pilot_id == "hunter" else 1.0) * (1.25 if passive_link_active("guided_payload") else 1.0), "weapon": "seeker", "target": target_id})
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
	if upgrades.lance > 0 and lance_timer <= 0.0 and not enemies.is_empty():
		lance_timer = 2.4 * (0.60 if rank_at("lance", 10) else (0.78 if rank_at("lance", 5) else 1.0))
		var target := _nearest(origin)
		for enemy in enemies:
			if not charges.is_empty() and enemy.id == charges[0].source:
				target = enemy
		if not target.is_empty():
			var end: Vector2 = origin + (target.p - origin).normalized() * 1200
			effects.append({"kind":"lance", "p":origin, "to":end, "life":0.28, "max_life":0.28, "born":tick})
			for enemy in enemies:
				var closest := Geometry2D.get_closest_point_to_segment(enemy.p, origin, end)
				if closest.distance_to(enemy.p) < (68 if str(enemy.kind).begins_with("boss") else 28):
					_damage_enemy(enemy, (22 + upgrades.lance * 7) * weapon_power() * (1.25 if rank_at("lance", 10) else 1.0) * (1.35 if passive_link_active("lance_sight") else 1.0), "lance")

func weapon_power() -> float:
	var power: float = (1.0 + meta.damage * 0.08 + upgrades.munitions * 0.08 + (0.14 if rank_at("munitions", 5) else 0.0) + (0.22 if rank_at("munitions", 10) else 0.0) + (0.05 if passive_link_active("guided_payload") else 0.0)) * (1.85 if focus_left > 0.0 else 1.0) * (0.75 if heat_left > 0.0 else 1.0) * stage_power
	if hull < max_hull * 0.40:
		power *= 1.0 + passive_bonus("last_stand", 0.03, 0.10, 0.20)
	if shield > max_shield * 0.75:
		power *= 1.0 + passive_bonus("shield_focus", 0.025, 0.10, 0.15)
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
			if enemy.kind == "boss_module":
				d *= 0.22
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
					_hit(bullet.damage, "hazard", "Molten slag" if bullet.kind == "slag" else "Proximity mine")
				bullet.hp = 0.0
		var bullet_pace: float = (0.45 if chrono_left > 0 else 1.0) * control_pace
		bullet.p += bullet.v * DT * bullet_pace
		var hit_radius := 18.0 if bullet.kind == "ordnance" else (13.0 if bullet.kind in ["mine", "slag"] else 10.0)
		if bullet.p.distance_squared_to(ship) < hit_radius * hit_radius and int(bullet.get("hp", 1)) > 0:
			if not (barrier_left > 0.0 and _is_small_shot(str(bullet.kind))):
				_hit(bullet.damage, "hazard" if bullet.kind in ["mine", "slag"] else bullet.kind, "Molten slag" if bullet.kind == "slag" else ("Proximity mine" if bullet.kind == "mine" else str(bullet.source)))
			bullet.p.y = HEIGHT + 100
	bullets = bullets.filter(func(b): return b.p.y < HEIGHT + 35 and b.p.y > -100 and b.p.x > -60 and b.p.x < WIDTH + 60 and b.get("hp", 1) > 0)

func _update_shots() -> void:
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
		if shot.weapon in ["seeker", "barrage"] and shot.target >= 0:
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
		if shot.weapon in ["seeker", "barrage"] and shot.target >= 0:
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
				if shot.p.distance_squared_to(enemy.p) < radius * radius:
					_damage_enemy(enemy, shot.damage, shot.weapon)
					struck = true
					break
		if struck:
			shot.p.y = -200
	shots = shots.filter(func(s): return s.p.y > -100 and s.p.y < HEIGHT and s.p.x > -50 and s.p.x < WIDTH + 50)
	enemies = enemies.filter(func(e): return e.hp > 0.0)

func _damage_enemy(enemy: Dictionary, amount: float, weapon: String) -> void:
	if enemy.hp <= 0.0:
		return
	if weapon in ["pulse", "seeker", "arc", "lance"]:
		if str(enemy.kind).begins_with("boss"):
			amount *= (1.0 + passive_bonus("boss_hunter", 0.05, 0.15, 0.25)) * (1.0 + meta.boss_damage * 0.03)
		if enemy.hp < enemy.max_hp * 0.35:
			amount *= 1.0 + passive_bonus("finisher", 0.04, 0.15, 0.25)
		if is_equal_approx(float(enemy.hp), float(enemy.max_hp)):
			amount *= 1.0 + passive_bonus("opening_salvo", 0.04, 0.15, 0.25)
	if enemy.kind == "shieldguard":
		amount *= 0.72
	if enemy.kind == "boss_module":
		amount *= 2.40 if _has_prototype("breach_optics") else 1.0
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
	damage_dealt[weapon] = float(damage_dealt.get(weapon, 0.0)) + minf(amount, enemy.hp)
	enemy.hp -= amount
	effects.append({"kind": "impact", "p": enemy.p, "life": 0.16, "max_life": 0.16, "born": tick})
	if enemy.hp > 0:
		return
	kills += 1
	hull = minf(max_hull, hull + passive_bonus("field_medic", 0.10, 0.25, 0.50))
	if enemy.kind == "boss_module":
		bonus_cores += int(meta.module_salvage)
		_log(str(enemy.name) + " destroyed - " + boss_phase_label())
	if salvage_left > 0.0:
		bonus_cores += 1 + int(upgrades.salvage / 2) + (1 if synergy_active("salvager") else 0)
	# Boss components are targets, but only the core can end a stage or pay a contract.
	var is_boss: bool = str(enemy.kind) in ["boss", "boss2", "boss3", "boss4"]
	effects.append({"kind": "explosion", "p": enemy.p, "life": 1.5 if is_boss else 0.5, "max_life": 1.5 if is_boss else 0.5, "born": tick, "boss": is_boss})
	var before := charges.size()
	charges = charges.filter(func(c): return c.source != enemy.id)
	beams_cancelled += before - charges.size()
	xp += enemy.xp * (1.0 + meta.xp * 0.06 + upgrades.harvester * 0.08 + (0.15 if rank_at("harvester", 5) else 0.0) + (0.25 if rank_at("harvester", 10) else 0.0) + (0.20 if passive_link_active("field_recovery") else 0.0) + (0.25 if pilot_id == "scavenger" else 0.0)) * (1.35 if route_choice == "bounty" else 1.0)
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		pending_levels += 1
	if enemy.kind == "splitter" and enemies.size() < _enemy_limit() - 2:
		for i in range(2):
			_add_enemy("drone", enemy.p + Vector2((i * 2 - 1) * 22, 14))
	if is_boss:
		if hull > max_hull * 0.60:
			bonus_cores += int(meta.clean_clear) * 3
		if stage_risk > 1.0:
			var reward: int = 20 * stage
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
	amount *= stage_damage_scale()
	if aegis_left > 0:
		prevented += amount
		effects.append({"kind": "shield-hit", "p": ship_position(), "life": 0.16, "max_life": 0.16, "born": tick})
		return
	var reduced := amount * stage_risk * stage_defense
	# Haven's support chassis resists damaging status rounds, which dominate
	# later worlds; direct beams, chaff, mines and escaped enemies still hurt.
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
		shield_offline = maxf(0.5, (1.5 if passive_link_active("shield_cycle") else 3.0) - meta.shield_restart * 0.2)
		effects.append({"kind": "shield-break", "p": ship_position(), "life": 0.75, "max_life": 0.75, "born": tick})
		_log("Shield broke")
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
	if ended or stage_transition_queued or not intermission_step.is_empty() or not cards.is_empty() or ability not in active_slots or not cooldowns.has(ability) or int(upgrades.get(ability, 0)) <= 0 or cooldowns[ability] > 0.0:
		return false
	ability_uses += 1
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
	if not fusion_spec(ability).is_empty():
		_activate_fusion(ability, effect_strength)
		return true
	if ability == "aegis":
		# A well-read telegraph earns a small resource rebate; blind cooldown
		# casts still give normal short-lived immunity without the bonus.
		var imminent := charges.any(func(c): return float(c.remaining) > 0.0 and float(c.remaining) <= 0.7)
		if not imminent:
			var near_ship: Vector2 = ship_position(time + 0.30)
			for bullet in bullets:
				if (bullet.p + bullet.v * 0.30).distance_squared_to(near_ship) < 65.0 * 65.0:
					imminent = true
					break
		if imminent:
			shield = minf(max_shield, shield + 10.0 * effect_strength)
			cooldowns[ability] *= 0.80
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
		mend_rate = (24 + (upgrades.mend - 1) * 6) * effect_strength / 4.0
		# Repair drones are the support counter to the status damage in
		# Ion Storm and the weapon-suppressing heat of Solar Foundry.
		if corrosion_left > 0.0 or heat_left > 0.0:
			corrosion_left = 0.0
			heat_left = 0.0
			_log("Repair drones purged corrosion and overheating")
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
			shield = minf(max_shield, shield + 8.0 * effect_strength)
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
		var interrupted := charges.filter(func(c): return float(c.remaining) > 0.0 and float(c.remaining) <= 1.5).size()
		if interrupted > 0:
			charges = charges.filter(func(c): return float(c.remaining) > 1.5)
			beams_cancelled += interrupted
			cooldowns[ability] *= 0.80
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
	for card in content.cards:
		if stage < int(card.get("min_stage", 1)):
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
			cards[0] = partners[rng.randi_range(0, partners.size() - 1)]
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
	for key in ["capacity_milestones", "prototypes", "prototype_offers", "intermission_step", "route_choice", "stage_power", "stage_risk", "stage_defense", "stage_fire_rate", "bounty_earned", "safeguard_used", "boss_spawn_time", "seed_value", "ship_id", "pilot_id", "movement_version", "difficulty", "daily_day", "daily_attempt", "stage", "endless_enabled", "encounter_index", "encounter_queue", "next_encounter_at", "boss_attack_pattern", "cooldown_totals", "stage_start", "stage_clears", "stage_transition_queued", "active_slots", "next_hazard", "tick", "time", "hull", "max_hull", "shield", "max_shield", "shield_offline", "aegis_left", "cooldowns", "upgrades", "enemies", "bullets", "shots", "effects", "charges", "events", "damage_taken", "damage_dealt", "xp", "level", "kills", "cards", "pending_levels", "ended", "won", "next_spawn", "pulse_timer", "seeker_timer", "heavy_ready_at", "boss_spawned", "next_id", "ability_uses", "prevented", "beams_fired", "beams_cancelled", "meta"]:
		state[key] = get(key)
	for key in ["stage_casts", "escort_left", "escort_timer", "escort_count", "escort_damage", "ion_mines", "aftercast_left", "overdrive_left", "chrono_left", "emp_left", "barrier_left", "focus_left", "decoy_left", "jammer_left", "salvage_left", "corrosion_left", "heat_left", "gravity_left", "last_boss_position", "bonus_cores", "choice_cores", "mend_left", "mend_rate", "emergency_used", "arc_timer", "lance_timer", "rerolls_left", "pilot_rerolls_left", "banishes_left", "skips_left", "banished"]:
		state[key] = get(key)
	return state.duplicate(true)

func restore(state: Dictionary) -> bool:
	if state.get("version", -1) != SAVE_VERSION:
		return false
	for key in state:
		if key not in ["version", "rng"]:
			if key in ["upgrades", "cooldowns", "meta", "damage_dealt"]:
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
