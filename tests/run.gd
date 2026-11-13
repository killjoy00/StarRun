extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const Services = preload("res://scripts/platform_services.gd")
const Catalog = preload("res://scripts/catalog.gd")
var failures := 0
var assertions := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	_test_course()
	_test_defenses()
	_test_interrupts_and_priority()
	_test_draft_and_cooldowns()
	_test_resume()
	_test_saves()
	_test_new_abilities()
	_test_homing_and_modules()
	_test_hangar_and_tactics()
	_test_legacy_modules()
	_test_loadouts()
	_test_threat_catalog()
	_test_stage_difficulty_and_pressure()
	_test_20_active_pool()
	var seeds := 12
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = int(arg.get_slice("=", 1))
	var results: Dictionary = _balance(seeds)
	check(results.timed.wins >= results.never.wins + mini(4, maxi(1, int(seeds / 2))), "Timed inputs must improve survival over no inputs")
	check(results.timed.mean_hull > results.on_cooldown.mean_hull + 3 or results.timed.wins > results.on_cooldown.wins, "Timing must outperform cooldown spam on matched seeds")
	check(results.timed.wins > 0, "Base ship must be able to clear Stage 1 without Hangar upgrades")
	print("BALANCE ", JSON.stringify(results))
	print("RESULT: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)

func _test_course() -> void:
	var sim := Sim.new(8821)
	var other := Sim.new(8822)
	var inside := true
	var max_speed := 0.0
	var max_acceleration := 0.0
	var previous := sim.ship_velocity(0.25)
	for i in range(2, 1440):
		var at := i * 0.25
		var p := sim.ship_position(at)
		var v := sim.ship_velocity(at)
		inside = inside and p.x >= 60 and p.x <= 480 and p.y >= 585 and p.y <= 860
		max_speed = maxf(max_speed, v.length())
		max_acceleration = maxf(max_acceleration, (v - previous).length() / 0.25)
		previous = v
	check(inside, "Curved course must remain in the safe flight band")
	check(max_speed > 120.0 and max_speed < 450.0, "New pilot must move faster while avoiding abrupt cross-screen lunges")
	check(max_acceleration < 600.0, "Course corrections must preserve smooth velocity")
	check(sim.ship_position(20).distance_to(other.ship_position(20)) > 1, "Different seeds must produce distinct routes")
	check(sim.ship_position(30).distance_to(sim.ship_position(36)) > 5, "New pilot must not repeat the old six-second weave")
	var legacy := sim.snapshot()
	legacy.erase("movement_version")
	other.restore(legacy)
	check(other.movement_version == 1 and is_equal_approx(other.ship_position(1.5).x, 432.0), "Legacy suspended flights must keep their original trajectory")

func _test_defenses() -> void:
	var sim := Sim.new(9)
	sim.shield = 0
	sim.upgrades.armor = 5
	sim._hit(1, "chaff", "test")
	check(is_equal_approx(sim.hull, 99.75), "Armor must retain the 25% damage floor")
	sim._hit(30, "heavy", "test")
	check(is_equal_approx(sim.hull, 69.75), "Heavy damage must bypass armor")
	sim.activate("aegis")
	sim._hit(30, "heavy", "test")
	check(is_equal_approx(sim.hull, 69.75) and sim.prevented == 30, "Aegis must block heavy damage")
	check(not sim.activate("aegis"), "Aegis cannot be activated twice on cooldown")
	var shield_sim := Sim.new()
	shield_sim.shield = 1
	shield_sim._hit(5, "chaff", "test")
	check(shield_sim.shield_offline == 3.0 and shield_sim.hull == 96.0, "Shield break must apply overflow and downtime")
	for i in range(180):
		shield_sim.step()
	check(shield_sim.shield < 0.1, "Broken shield must not regenerate during its offline window")

func _test_interrupts_and_priority() -> void:
	var sim := Sim.new(20)
	sim.enemies = [{"id": 1, "kind": "drone", "p": Vector2(100, 200), "hp": 30.0, "max_hp": 30.0, "speed": 0.0, "fire": 99.0, "xp": 3, "phase": 0.0}]
	sim.charges = [{"source": 1, "x": 270.0, "remaining": 1.0, "duration": 1.8, "damage": 24.0}]
	sim._update_weapons()
	check(sim.shots[-1].target == 1, "Seekers must prioritize the charging source")
	sim._damage_enemy(sim.enemies[0], 40, "pulse")
	check(sim.charges.is_empty() and sim.beams_cancelled == 1, "Killing a charging source must cancel its beam")
	sim = Sim.new(20, {}, "arcwing")
	sim.charges = [{"source": 99, "x": 270.0, "remaining": 1.0, "duration": 1.8, "damage": 30.0}]
	sim.bullets = [{"p": Vector2(100, 100), "v": Vector2.ZERO, "damage": 12.0, "kind": "ordnance", "hp": 12.0, "source": "gunship"}]
	sim.activate("nova")
	check(sim.charges.is_empty() and sim.bullets.is_empty(), "Nova must cancel beams and remove ordnance at level 1")
	check(sim.cooldowns.aegis == 0.0, "Nova must not consume Aegis")
	sim = Sim.new()
	sim.upgrades.aegis = 5
	sim.enemies = [{"id": 1, "kind": "boss", "p": Vector2(270, 135), "hp": 200.0, "max_hp": 200.0, "speed": 0.0, "fire": 99.0, "xp": 0, "phase": 0.0}]
	sim.charges = [{"source": 1, "x": sim.ship_position().x, "remaining": Sim.DT, "duration": 1.8, "damage": 35.0}]
	sim.activate("aegis")
	check(sim.enemies[0].hp == 200.0, "Aegis capstone must not reflect before a beam lands")
	sim._update_charges()
	check(sim.enemies[0].hp == 140.0 and sim.prevented == 35.0, "Aegis capstone must reflect a blocked heavy beam")

func _test_draft_and_cooldowns() -> void:
	var sim := Sim.new()
	sim.activate("aegis")
	sim._offer_cards()
	var before: Dictionary = sim.snapshot()
	for i in range(100):
		sim.step()
	check(sim.snapshot() == before, "Draft must freeze all simulation state, including cooldowns and projectiles")
	check(not sim.activate("aegis"), "Abilities must not activate behind a draft")
	check(sim.choose_card(0), "A valid draft choice must install")
	check(not sim.choose_card(3), "Invalid choices must have no effect")
	sim.hull = 10
	sim._offer_cards()
	var defensive := false
	for card in sim.cards:
		defensive = defensive or card.id in ["armor", "regen", "hull", "aegis", "repair"]
	check(defensive, "Low hull must offer a legal defensive or repair card")

func _test_resume() -> void:
	var original := Sim.new(123456)
	for i in range(4200):
		_bot(original, "timed")
		original.step()
	var encoded := var_to_bytes(original.snapshot())
	var restored := Sim.new(1)
	check(restored.restore(bytes_to_var(encoded)), "Checkpoint must restore after binary serialization")
	check(restored.snapshot() == original.snapshot(), "Checkpoint must restore every simulation field")
	for i in range(1800):
		_bot(original, "timed")
		_bot(restored, "timed")
		original.step()
		restored.step()
	check(restored.snapshot() == original.snapshot(), "Resumed run must remain deterministic under identical input")
	original._offer_cards()
	restored.restore(original.snapshot())
	check(restored.cards == original.cards, "Resuming a draft must preserve its exact hand")
	check(not restored.restore({"version": -1}), "Unknown checkpoint versions must be rejected")

func _test_saves() -> void:
	var services := Services.new()
	var path := "user://starrun-test.save"
	var expected := {"vector": Vector2(12, 19), "seed": 981, "cards": ["pulse", "aegis"]}
	check(services.write_atomic(path, expected), "Atomic save must succeed")
	check(services.read_save(path) == expected, "Saved data must survive a disk round trip")
	DirAccess.remove_absolute(path)

func _install(sim: RefCounted, id: String) -> void:
	for card in sim.content.cards:
		if card.id == id:
			sim.cards = [card.duplicate(true)]
			sim.choose_card(0)
			return

func _test_new_abilities() -> void:
	var sim := Sim.new(441)
	check(not sim.activate("barrage"), "A locked ability must not cast")
	sim.level = 2
	sim._offer_cards()
	check(sim.cards.any(func(c): return c.tag == "ABILITY" and sim.upgrades[c.id] == 0), "First level-up must offer a new active ability")
	sim.cards.clear()
	for id in ["barrage", "overdrive", "chrono"]:
		_install(sim, id)
		check(sim.upgrades[id] == 1 and sim.activate(id), "Learning %s must occupy a slot and allow casting" % id)
	check(sim.active_slots.size() == 4, "A ship starts with one active and can draft exactly three more")
	_install(sim, "mend")
	check(sim.upgrades.mend == 0 and sim.active_slots.size() == 4, "A fifth unowned ability must never be equipped")
	check(sim.shots.size() == 7, "Barrage must create seven guided rockets at level 1")
	check(sim.overdrive_left >= 4 and sim.chrono_left >= 4, "Timed abilities must persist after activation")
	var healing := Sim.new(4, {}, "haven")
	check(healing.active_slots == ["mend"], "Haven starts with its repair signature")
	healing.hull = 40
	healing.next_spawn = 999
	healing.activate("mend")
	for i in range(240):
		healing.step()
	check(is_equal_approx(healing.hull, 64.0), "Repair drones must restore the promised hull over four seconds")
	var normal := Sim.new()
	var slowed := Sim.new()
	_install(slowed, "chrono")
	slowed.activate("chrono")
	var bullet := {"p":Vector2(20, 100), "v":Vector2(0, 200), "damage":1, "kind":"chaff", "source":"test"}
	normal.bullets = [bullet.duplicate(true)]
	slowed.bullets = [bullet.duplicate(true)]
	normal._update_bullets()
	slowed._update_bullets()
	check(is_equal_approx((slowed.bullets[0].p.y - 100) / (normal.bullets[0].p.y - 100), 0.45), "Chrono must slow enemy projectiles to 45% speed")
	var fast := Sim.new()
	_install(fast, "overdrive")
	fast.activate("overdrive")
	normal = Sim.new()
	for i in range(120):
		normal._update_weapons()
		fast._update_weapons()
	check(fast.shots.size() > normal.shots.size() * 1.5, "Overdrive must materially increase automatic fire")
	var restored := Sim.new()
	restored.restore(sim.snapshot())
	check(restored.snapshot() == sim.snapshot(), "All six cooldowns, active effects and learned modules must survive saving")

func _test_homing_and_modules() -> void:
	var sim := Sim.new()
	sim.enemies = [{"id":1, "kind":"drone", "p":Vector2(285, 500), "hp":100.0, "max_hp":100.0, "xp":0, "fire":99.0, "speed":0.0, "phase":0.0}]
	sim.shots = [{"p":Vector2(250, 790), "v":Vector2(0,-980), "damage":9.0, "weapon":"pulse", "target":-1}]
	for i in range(22):
		sim._update_shots()
	check(sim.enemies[0].hp < 100, "Gentle homing must connect with a slightly off-axis enemy")
	sim.shots = [{"p":Vector2(250, 400), "v":Vector2(0,-980), "damage":9.0, "weapon":"pulse", "target":-1}]
	sim._update_shots()
	check(sim.shots[0].v == Vector2(0,-980), "Pulse must not home backward toward an enemy behind it")
	_install(sim, "arc")
	_install(sim, "lance")
	sim._update_weapons()
	check(sim.damage_dealt.arc > 0 and sim.damage_dealt.lance > 0, "Both new automatic weapons must actually damage enemies")

func _test_hangar_and_tactics() -> void:
	var hangar := Catalog.defaults()
	for id in hangar:
		hangar[id] = 1
	var sim := Sim.new(555, hangar)
	check(sim.max_hull == 110 and sim.max_shield == 58, "Hangar defenses must apply at launch")
	check(sim.upgrades.pulse == 2 and sim.upgrades.seeker == 2, "Starting weapon upgrades must apply to new flights")
	check(sim.weapon_power() > 1 and sim.payout() > Sim.new().payout(), "Armory and salvage tracks must change actual damage and rewards")
	sim._offer_cards()
	check(sim.cards.size() == 4, "Expanded uplink must offer four choices")
	var pending: int = sim.pending_levels
	check(sim.reroll_cards() and sim.rerolls_left == 0 and sim.pending_levels == pending, "Reroll must spend one use without spending another level")
	var removed: String = sim.cards[0].id
	check(sim.banish_card(0) and sim.banishes_left == 0 and not sim.cards.any(func(c): return c.id == removed), "Banished track must leave the draft pool immediately")
	sim.hull = 50
	check(sim.skip_cards() and sim.cards.is_empty() and sim.hull == 62 and sim.skips_left == 0, "Skip must consume a use and trade that hand for repair")
	check(Catalog.refund({"hull":3, "damage":2, "regen":1}) == 30, "Existing purchases must retain their original full refund")
	var credits := 0
	for entry in Catalog.HANGAR:
		credits += Catalog.price(entry.id, 0)
	check(Catalog.refund(hangar) == credits, "Refund must return exactly the price paid across all 22 tracks")
	sim.shield = 0
	sim.hull = 40
	sim._hit(3, "chaff", "test")
	sim.hull = 30
	sim._hit(1, "chaff", "test")
	check(sim.emergency_used and sim.aegis_left > 0, "Emergency field must activate once at low hull")

func _test_legacy_modules() -> void:
	var old := Sim.new().snapshot()
	old.upgrades = {"pulse":1, "seeker":1, "armor":0, "regen":0, "hull":0, "coolant":0, "aegis":1, "nova":1}
	old.meta = {"hull":2, "damage":1, "regen":0}
	old.cooldowns = {"aegis":2.0, "nova":3.0}
	old.damage_dealt = {"pulse":10.0, "seeker":0.0, "nova":0.0}
	old.movement_version = 2
	old.erase("active_slots") # Previous checkpoint had Aegis and Nova learned.
	var sim := Sim.new()
	check(sim.restore(old), "An original first-flight save must still load")
	sim.step()
	check(sim.cooldowns.barrage == 0 and sim.upgrades.arc == 0 and sim.meta.hull == 2 and "nova" in sim.active_slots, "Migration must preserve purchased ranks and learned active slots")


func _test_loadouts() -> void:
	check(Catalog.SHIPS.size() >= 6 and Catalog.PILOTS.size() >= 6, "Six ship archetypes and six pilots must be available")
	check(Catalog.ship("vanguard").cost == 0 and Catalog.pilot("rookie").cost == 0, "Starter ship/pilot must be free")
	var base := Sim.new(222)
	check(base.active_slots == ["aegis"], "Vanguard starts with its Aegis signature only")
	var interceptor := Sim.new(222, {}, "kestrel", "ace")
	check(interceptor.ship_id == "kestrel" and interceptor.pilot_id == "ace" and interceptor.active_slots == ["overdrive"], "Selected hull must supply its own signature active")
	check(interceptor.upgrades.pulse == 2 and interceptor.upgrades.seeker == 0 and interceptor.max_hull == 70, "Interceptor starts with Pulse focus and fragile hull")
	check(interceptor.course[2].t < base.course[2].t, "Interceptor autopilot must make faster turns")
	interceptor._update_weapons()
	check(interceptor.shots.any(func(s): return s.weapon == "pulse") and not interceptor.shots.any(func(s): return s.weapon == "seeker"), "Ship weapon exclusions must prevent firing uninstalled weapons")
	var fortress := Sim.new(222, {}, "bulwark", "engineer")
	check(fortress.max_hull == 160 and fortress.max_shield == 100, "Fortress and Engineer starting defenses stack")
	fortress.shield = 20
	fortress._hit(1.0, "chaff", "test")
	check(fortress.shield == 19.75, "Bulwark inherent armor mitigates chaff")
	var missile := Sim.new(222, {}, "wraith", "hunter")
	check(missile.upgrades.pulse == 0 and missile.upgrades.seeker == 2, "Missile boat must start without Pulse")
	missile.enemies = [{"id":1, "kind":"drone", "p":Vector2(250,240), "hp":100.0, "max_hp":100.0, "speed":0.0, "fire":99.0, "xp":3, "phase":0.0}]
	missile._update_weapons()
	check(missile.shots.size() == 1 and missile.shots[0].weapon == "seeker" and missile.shots[0].damage > 30, "Missile-specialist pilot and hull bonuses must stack")
	var lightning := Sim.new(222, {}, "arcwing", "rookie")
	check(lightning.upgrades.arc == 1 and lightning.upgrades.seeker == 0, "Arcwing must start with Arc Coil instead of missiles")
	var support := Sim.new(222, {}, "haven", "tactician")
	check(support.upgrades.mend == 1 and support.rerolls_left == 1, "Support carrier and tactician start with useful tools")
	var salvager := Sim.new(222, {}, "vanguard", "scavenger")
	check(salvager.payout() > base.payout(), "Salvager gets a measurable currency bonus")
	var checkpoint := support.snapshot()
	var restored := Sim.new(999)
	check(restored.restore(bytes_to_var(var_to_bytes(checkpoint))), "Ship/pilot checkpoint must deserialize")
	check(restored.snapshot() == checkpoint, "Checkpoint must preserve hull type, selected pilot and starter ability")
	# Cosmetic playback speed must not affect fixed-step combat determinism.
	var sim_one := Sim.new(341)
	var sim_three := Sim.new(341)
	for frame in range(240):
		sim_one.step()
	for frame in range(80):
		for factor in range(3):
			sim_three.step()
	check(sim_one.snapshot() == sim_three.snapshot(), "Equal simulated time must give identical outcomes at 1x and 3x")

func _test_threat_catalog() -> void:
	var kinds := ["drone", "gunship", "sniper", "interceptor", "rusher", "missile_bomber", "carrier", "shieldguard", "minelayer", "boulder", "station", "ion_frigate", "corroder", "disruptor"]
	var sim := Sim.new(442)
	for kind in kinds:
		check(sim.content.enemies.has(kind), "Enemy type must have a combat specification: " + kind)
		sim._add_enemy(kind, Vector2(120,200))
	check(sim.enemies.size() == kinds.size(), "All enemy and hazard types must be spawnable")
	sim.enemies.clear()
	sim._add_enemy("missile_bomber", Vector2(260,150))
	sim.enemies[0].fire = 0.0
	sim._update_enemies()
	check(sim.bullets.filter(func(b): return b.kind == "ordnance").size() == 2, "Missile bomber must launch a dual homing volley")
	sim.bullets.clear()
	sim.enemies.clear()
	sim._add_enemy("minelayer", Vector2(260,150))
	sim.enemies[0].fire = 0.0
	sim._update_enemies()
	check(sim.bullets.size() == 1 and sim.bullets[0].kind == "mine" and sim.bullets[0].fuse > 0.0, "Minelayer must deploy a visible timed hazard")
	var mine: Dictionary = sim.bullets[0]
	sim.shots = [{"p":mine.p, "v":Vector2.ZERO, "damage":24.0, "weapon":"pulse", "target":-1}]
	sim.enemies.clear()
	sim._update_shots()
	check(sim.bullets[0].hp <= 0.0, "Player fire must be able to destroy mines")
	sim.bullets.clear()
	sim.shots.clear()
	sim._add_enemy("boulder", Vector2(270,230))
	var before_kills := sim.kills
	sim._damage_enemy(sim.enemies[0], 500.0, "pulse")
	check(sim.kills > before_kills and sim.enemies[0].hp <= 0, "Boulders must be destructible targets")
	sim.enemies.clear()
	sim._add_enemy("station", Vector2(260,150))
	sim.enemies[0].fire = 0.0
	sim._update_enemies()
	check(sim.bullets.any(func(b): return b.kind == "ordnance"), "Stations must be active turret threats")

func _bot(sim: RefCounted, strategy: String) -> void:
	if not sim.cards.is_empty():
		var priorities := ["seeker", "pulse", "arc", "lance", "regen", "hull", "armor", "munitions", "autoloader", "coolant", "shield", "targeting", "repair_bots", "harvester", "amplifier", "nova", "aegis", "barrage", "overdrive", "chrono", "mend", "repair"]
		var best := 0
		var rank := 100
		for i in range(sim.cards.size()):
			var r: int = priorities.find(sim.cards[i].id)
			if sim.hull < sim.max_hull * 0.35 and sim.cards[i].id in ["hull", "repair"]:
				r = -1
			if r < rank:
				rank = r
				best = i
		sim.choose_card(best)
	if strategy == "on_cooldown":
		for id in Catalog.ABILITIES:
			sim.activate(id)
	elif strategy == "timed":
		if sim.enemies.size() >= 3 or sim.boss_spawned:
			sim.activate("barrage")
			sim.activate("overdrive")
		if sim.hull < sim.max_hull - 26:
			sim.activate("mend")
		if sim.bullets.size() > 20:
			sim.activate("chrono")
		var imminent := false
		for charge in sim.charges:
			imminent = imminent or charge.remaining < 0.38
		if imminent:
			if sim.cooldowns.aegis <= 0:
				sim.activate("aegis")
			elif sim.aegis_left <= 0:
				sim.activate("nova")
		elif sim.enemies.size() >= 3 and sim.charges.is_empty():
			sim.activate("nova")
		elif sim.shield < 30 and sim.charges.is_empty():
			var near := 0
			for b in sim.bullets:
				if (b.p + b.v * 0.25).distance_squared_to(sim.ship_position(sim.time + 0.25)) < 36 * 36:
					near += 1
			if near >= 1:
				sim.activate("aegis")

func _balance(seeds: int) -> Dictionary:
	var result: Dictionary = {}
	for strategy in ["never", "on_cooldown", "timed"]:
		var survival := 0.0
		var remaining := 0.0
		var wins := 0
		var max_charges := 0
		var max_entities := 0
		for seed_index in range(seeds):
			var sim := Sim.new(61000 + (seed_index + 1) * 7919)
			for i in range(60 * 360):
				_bot(sim, strategy)
				sim.step()
				max_charges = maxi(max_charges, sim.charges.size())
				max_entities = maxi(max_entities, sim.bullets.size())
				if sim.ended or sim.stage_clears >= 1:
					break
			survival += sim.time
			remaining += sim.hull
			wins += int(sim.stage_clears >= 1)
		check(max_charges <= 1, "Dangerous heavy telegraphs must never overlap")
		result[strategy] = {"seeds": seeds, "wins": wins, "mean_survival": snappedf(survival / seeds, 0.1), "mean_hull": snappedf(remaining / seeds, 0.1), "max_bullets": max_entities}
	return result
