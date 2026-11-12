extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const Services = preload("res://scripts/platform_services.gd")
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
	var results: Dictionary = _balance(12)
	check(results.timed.wins >= results.never.wins + 4, "Timed inputs must improve survival over no inputs")
	check(results.timed.mean_hull > results.on_cooldown.mean_hull + 3 or results.timed.wins > results.on_cooldown.wins, "Timing must outperform cooldown spam on matched seeds")
	check(results.timed.wins > 0, "Base ship must be able to clear the belt without Hangar upgrades")
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
		inside = inside and p.x >= 85 and p.x <= 455 and p.y >= 735 and p.y <= 830
		max_speed = maxf(max_speed, v.length())
		max_acceleration = maxf(max_acceleration, (v - previous).length() / 0.25)
		previous = v
	check(inside, "Curved course must remain in the safe flight band")
	check(max_speed < 75.0, "Flight course must avoid abrupt cross-screen lunges")
	check(max_acceleration < 80.0, "Course corrections must preserve smooth velocity")
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
	sim = Sim.new()
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
	check(not sim.activate("nova"), "Abilities must not activate behind a draft")
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

func _bot(sim: RefCounted, strategy: String) -> void:
	if not sim.cards.is_empty():
		var priorities := ["seeker", "pulse", "regen", "hull", "armor", "coolant", "nova", "aegis", "repair"]
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
		sim.activate("aegis")
		sim.activate("nova")
	elif strategy == "timed":
		var imminent := false
		for charge in sim.charges:
			imminent = imminent or charge.remaining < 0.38
		if imminent:
			if sim.cooldowns.aegis <= 0:
				sim.activate("aegis")
			elif sim.aegis_left <= 0:
				sim.activate("nova")
		elif sim.enemies.size() >= 6:
			sim.activate("nova")
		elif sim.shield < 12 and sim.cooldowns.nova > 0 and sim.charges.is_empty():
			var near := 0
			for b in sim.bullets:
				if b.p.distance_squared_to(sim.ship_position()) < 110 * 110:
					near += 1
			if near >= 5:
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
				if sim.ended:
					break
			survival += sim.time
			remaining += sim.hull
			wins += int(sim.won)
		check(max_charges <= 1, "Dangerous heavy telegraphs must never overlap")
		result[strategy] = {"seeds": seeds, "wins": wins, "mean_survival": snappedf(survival / seeds, 0.1), "mean_hull": snappedf(remaining / seeds, 0.1), "max_bullets": max_entities}
	return result
