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
	_test_stage_rerolls_and_shield_breaks()
	_test_legacy_modules()
	_test_loadouts()
	_test_threat_catalog()
	_test_stage_difficulty_and_pressure()
	_test_four_stage_campaign()
	_test_boss_components_and_phases()
	_test_synergy_tradeoffs()
	_test_prototype_and_route_choices()
	_test_new_stage_threats()
	_test_active_pool()
	_test_fusions_and_milestones()
	_test_long_runs()
	_test_fusion_thresholds()
	_test_expanded_hangar()
	_test_support_actives()
	var seeds := 24
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = int(arg.get_slice("=", 1))
	var results: Dictionary = _balance(seeds)
	check(results.timed.wins >= results.never.wins + mini(4, maxi(1, int(seeds / 2))), "Timed inputs must improve survival over no inputs")
	# Combat and draft share RNG. Strategy changes draft outcomes, so full-run
	# hull is diagnostic rather than an isolated test of input timing.
	var timing: Dictionary = _fixed_build_timing(seeds)
	check(timing.timed.wins >= timing.on_cooldown.wins + mini(4, maxi(1, int(seeds / 2))), "Timed counters must improve wins with identical equipment")
	check(timing.timed.mean_hull > timing.on_cooldown.mean_hull + 3, "Timed counters must preserve more hull with identical equipment")
	print("FIXED_BUILD_TIMING ", JSON.stringify(timing))
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

func _fuse_pair(sim: RefCounted, pair: Dictionary) -> void:
	for part in pair.parts:
		while int(sim.upgrades.get(str(part),0)) < Sim.FUSION_RANK:
			_install(sim,str(part))

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
	sim.cards.clear() # Discard the deliberately injected, ineligible fifth-slot offer.
	check(sim.shots.size() == 7, "Barrage must create seven guided rockets at level 1")
	check(sim.overdrive_left >= 4 and sim.chrono_left >= 4, "Timed abilities must persist after activation")
	var haven := Sim.new(4, {}, "haven")
	check(haven.active_slots == ["mend"], "Haven starts with its repair signature")
	var healing := Sim.new()
	_install(healing, "mend")
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
	check(sim.skip_cards() and sim.cards.is_empty() and sim.hull == 68 and sim.skips_left == 0, "Skip must consume a use and trade that hand for repair")
	check(Catalog.refund({"hull":3, "damage":2, "regen":1}) == 30, "Existing purchases must retain their original full refund")
	var credits := 0
	for entry in Catalog.HANGAR:
		credits += Catalog.price(entry.id, 0)
	check(Catalog.refund(hangar) == credits, "Refund must return exactly the price paid across every Hangar track")
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
			if r < 0:
				r = 90 # Unknown IDs must not accidentally outrank every existing card.
			if not sim.fusion_spec(str(sim.cards[i].id)).is_empty():
				r = 4 if sim.upgrades[sim.cards[i].id] < 5 else 14
			if sim.cards[i].tag == "ABILITY" and sim.upgrades[sim.cards[i].id] == 0 and sim.active_slots.size() < Catalog.ACTIVE_SLOTS:
				r = 0 if sim.cards[i].id in ["nova", "emp", "flak", "capacitor", "siphon"] else 2
			if sim.hull < sim.max_hull * 0.35 and sim.cards[i].id in ["hull", "repair"]:
				r = -1
			if r < rank:
				rank = r
				best = i
		sim.choose_card(best)
	if strategy == "on_cooldown":
		for id in sim.active_slots:
			sim.activate(str(id))
	elif strategy == "timed":
		# Fusions replace both original buttons. The bot must time the fused cast,
		# rather than trying to press two abilities that no longer exist.
		var urgent_beam := false
		for beam in sim.charges:
			urgent_beam = urgent_beam or float(beam.remaining) < 0.55
		var near_shots := 0
		for bullet in sim.bullets:
			if (bullet.p + bullet.v * 0.30).distance_squared_to(sim.ship_position(sim.time + 0.30)) < 65.0 * 65.0:
				near_shots += 1
		if urgent_beam or near_shots >= 1 or (sim.shield < sim.max_shield - 20 and sim.bullets.size() >= 8):
			sim.activate("nova_aegis")
		if urgent_beam or sim.bullets.size() >= 20:
			sim.activate("stasis_lock")
			sim.activate("ghost_signal")
		if sim.boss_spawned or sim.enemies.size() >= 3:
			sim.activate("railstorm")
			sim.activate("missile_grid")
			sim.activate("prism_focus")
		if sim.hull < sim.max_hull - 30 or sim.shield < sim.max_shield - 30:
			sim.activate("repair_matrix")
		if sim.hull < sim.max_hull - 20 and sim.enemies.size() > 0:
			sim.activate("scrap_converter")
		if sim.bullets.size() >= 15:
			sim.activate("reflective_wall")
			sim.activate("reactor_surge")
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
		if sim.shield < sim.max_shield - 20:
			sim.activate("capacitor")
			sim.activate("deflector")
		if sim.hull < sim.max_hull - 25:
			sim.activate("siphon")
		if not sim.charges.is_empty():
			sim.activate("emp")
		var incoming_rockets: bool = sim.bullets.any(func(b): return str(b.kind) in ["ordnance", "mine", "slag"])
		if incoming_rockets:
			sim.activate("flak")
			sim.activate("missile_grid")
		if sim.bullets.size() >= 12:
			sim.activate("prism")
			sim.activate("overload")
		if sim.enemies.size() >= 2 or sim.boss_spawned:
			sim.activate("wing_drones")
			sim.activate("ion_mine")
			sim.activate("storm_carrier")
		if sim.enemies.size() >= 3:
			sim.activate("focus")
			sim.activate("jammer")
			sim.activate("strike")


func _test_active_pool() -> void:
	check(Catalog.ABILITIES.size() == 22 and Catalog.ACTIVE_SLOTS == 4, "Twenty-two abilities must compete for four active slots")
	var seen := {}
	for id in Catalog.ABILITIES:
		check(not seen.has(id), "Ability IDs must be unique")
		seen[id] = true
		var sim := Sim.new(911, {}, "vanguard")
		check(sim.content.abilities.has(id) and sim.content.cards.any(func(card): return card.id == id and card.tag == "ABILITY"), "Each active needs cooldown and draft card")
		if id != "aegis":
			_install(sim, id)
		var actual: String = id
		if id not in sim.active_slots:
			for fusion in sim.content.fusions:
				if id in fusion.parts and str(fusion.id) in sim.active_slots:
					actual = str(fusion.id)
		check(sim._source_active(id) and sim.activate(actual), "Every original active must work directly or as a fusion: " + id)
	var sim := Sim.new(20)
	check(not sim.activate("nova"), "Unslotted abilities must not cast")
	for id in ["flak", "emp", "strike"]:
		_install(sim, id)
	check(sim.active_slots.size() == 4, "Three installed abilities fill all four slots")
	sim.level = 8
	sim._offer_cards()
	check(not sim.cards.any(func(card): return card.tag == "ABILITY" and sim.upgrades[card.id] == 0 and not sim._can_learn_active(str(card.id))), "A full bar cannot offer a new rank-1 ability")
	var checkpoint := sim.snapshot()
	check(Sim.new().restore(checkpoint), "Four-slot builds must restore")

func _test_stage_difficulty_and_pressure() -> void:
	var normal := Sim.new(111, {}, "vanguard", "rookie", "normal")
	var hard := Sim.new(111, {}, "vanguard", "rookie", "hard")
	var insane := Sim.new(111, {}, "vanguard", "rookie", "insane")
	for sim in [normal, hard, insane]:
		sim._add_enemy("drone", Vector2(240, 100))
	check(normal.enemies[0].hp < hard.enemies[0].hp and hard.enemies[0].hp < insane.enemies[0].hp, "Difficulty must increase enemy health")
	check(normal.payout() < hard.payout() and hard.payout() < insane.payout(), "Hard and Insane must pay more cores")
	check(normal.content.stage_count == 4 and normal.content.abilities.aegis.cooldown >= 14, "Four stages and slower Aegis must be configured")
	var sim := Sim.new(777)
	sim.boss_spawned = true
	sim.enemies = [{"id":9, "kind":"boss", "p":Vector2(270,135), "hp":10.0, "max_hp":6200.0, "speed":0.0, "fire":99.0, "xp":0, "phase":0.0}]
	sim._damage_enemy(sim.enemies[0], 30.0, "pulse")
	check(sim.stage_clears == 1 and sim.stage_transition_queued and not sim.ended, "Harvester must lead to Stage 2")
	sim._enter_stage_two()
	check(sim.stage == 2 and sim.stage_start == sim.time and sim.pending_levels == 1, "Stage 2 must reset schedules and offer a milestone draft")
	sim._add_enemy("ion_frigate", Vector2(250,100))
	check(sim.enemies[0].max_hp > normal.enemies[0].max_hp, "Stage 2 must be tougher than Stage 1")
	sim.enemies.clear()
	sim._spawn_boss()
	check(sim.enemies.size() == 3 and sim.enemies[0].kind == "boss2" and sim._alive_modules("launch_bay") == 2, "Storm Carrier must have two destructible launch bays")
	sim._damage_enemy(sim.enemies[0], 100000.0, "pulse")
	check(not sim.ended and sim.stage_transition_queued and sim.stage_clears == 2, "Stage 2 must stop for its victory acknowledgement, not end the run")
	check(not sim.advance_stage(), "Stage 2 cannot skip the strategic intermission")
	check(sim.begin_intermission() and sim.choose_prototype(0) and sim.choose_route("repair"), "Stage 2 must require Prototype and route selection")
	check(sim.advance_stage() and sim.stage == 3, "Two strategic choices should unlock the Foundry")
	var statuses := Sim.new(19)
	statuses._hit(1, "ion", "test")
	check(statuses.shield_offline >= 4.0, "Ion fire must disable shield regeneration")
	statuses._hit(1, "corrosion", "test")
	check(statuses.corrosion_left >= 5.0, "Corrosion must cause continuing damage")
	statuses.cooldowns.aegis = 4.0
	statuses._hit(1, "disrupt", "test")
	check(statuses.cooldowns.aegis >= 6.0, "Disruption must delay equipped cooldowns")
	var scatter := Sim.new(11)
	for i in range(650):
		scatter.bullets.append({"p":Vector2(10 + i % 50 * 10, 200 + int(i / 50) * 10), "v":Vector2.ZERO, "damage":1.0, "kind":"chaff", "source":"stress"})
	scatter.bullets.append({"p":Vector2(270, 550), "v":Vector2.ZERO, "damage":12.0, "kind":"mine", "hp":12.0, "source":"stress"})
	scatter.shots.append({"p":Vector2(270, 550), "v":Vector2.ZERO, "damage":20.0, "weapon":"pulse", "target":-1})
	scatter._update_shots()
	check(scatter.bullets[-1].hp <= 0.0, "Spatial lookup must preserve point-defense collisions among hundreds of bullets")


func _test_four_stage_campaign() -> void:
	var sim := Sim.new(404, {}, "vanguard", "rookie", "normal")
	check(sim.stage_count() == 4 and sim.stage_name() == "DEBRIS BELT", "Four authored campaign stages must start in the debris belt")
	var names := {}
	var boss_kinds := ["boss", "boss2", "boss3", "boss4"]
	var health := 0.0
	for stage_number in range(1, 5):
		check(sim.stage == stage_number, "Campaign advances sequentially through each stage")
		check(not names.has(sim.stage_name()), "Each stage needs a different name and environment")
		names[sim.stage_name()] = true
		sim._spawn_boss()
		check(sim.enemies.size() == (1 if stage_number == 1 else 3) and sim.enemies[0].kind == boss_kinds[stage_number - 1], "Each stage must have a distinct boss with modules after Stage 1")
		check(sim.enemies[0].max_hp > health, "Later bosses must require stronger builds")
		health = sim.enemies[0].max_hp
		# This tests transitions, not a fixed damage budget: remove the boss parts first.
		for part in sim.enemies:
			if part.kind == "boss_module": sim._damage_enemy(part, part.hp * 2.0, "pulse")
		sim._damage_enemy(sim.enemies[0], sim.enemies[0].hp * 2.0, "pulse")
		check(sim.stage_clears == stage_number and sim.stage_transition_queued and not sim.ended, "Each boss must freeze before the player acknowledges victory")
		var paused: Dictionary = sim.snapshot()
		sim.step()
		check(sim.snapshot() == paused, "Victory celebration must freeze every simulation field")
		var restored := Sim.new(1)
		check(restored.restore(paused) and restored.snapshot() == paused, "Resume must restore an awaiting stage-clear celebration exactly")
		if stage_number < 4:
			check(not sim.advance_stage(), "Boss victory may not automatically advance or bypass decisions")
			check(sim.begin_intermission(), "Every non-final boss offers a Prototype draft")
			var offers: Array = sim.prototype_offers.duplicate()
			check(offers.size() == 3, "Three unique Prototypes must be offered")
			check(sim.choose_prototype(0), "Selecting a Prototype must succeed")
			check(sim.intermission_step == "route" and sim.prototypes.size() == stage_number, "Prototype choice persists across the campaign")
			var route: String = ["repair", "overclock", "bounty"][stage_number - 1]
			check(sim.choose_route(route) and sim.advance_stage(), "Repair, overclock and bounty routes should unlock the next stage")
		else:
			check(sim.advance_stage(), "Claiming the final boss victory must complete the campaign")
		if stage_number < 4:
			check(sim.stage == stage_number + 1 and not sim.stage_transition_queued and not sim.won, "Next stage should be playable without resetting the build")
			check(sim.pending_levels == stage_number, "Each cleared boss awards exactly one milestone upgrade")
		else:
			check(sim.ended and sim.won and sim.stage_clears == 4, "Acknowledging final boss must finish all four stages")
	check(not sim.advance_stage(), "Final stage can only be settled once")
	check(sim.payout() > Sim.new().payout(), "Later stages must grant increased cumulative salvage")

func _test_boss_components_and_phases() -> void:
	var storm := Sim.new(1234)
	storm.stage = 2
	storm._spawn_boss()
	check(storm._alive_modules("launch_bay") == 2 and storm.boss_phase_label() == "LAUNCH BAYS ONLINE", "Stage 2 boss must have attack-controlling launch bays")
	var root: Dictionary = storm.enemies[0]
	var original_hp: float = root.hp
	storm._damage_enemy(root, 100.0, "pulse")
	check(root.hp < original_hp and root.hp > original_hp - 100.0, "Live launch bays armor the carrier core")
	storm.time = storm.boss_spawn_time + 6.0
	storm.enemies[0].fire = 0.0
	storm._update_enemies()
	check(storm.enemies.any(func(e): return e.kind == "storm_weaver"), "Live launch bays must deploy storm fighters")
	for bay in storm.enemies:
		if bay.kind == "boss_module" and bay.role == "launch_bay":
			storm._damage_enemy(bay, 100000.0, "pulse")
	check(storm._alive_modules("launch_bay") == 0 and storm.boss_phase_label() == "LAUNCH BAYS DESTROYED", "Destroying bays must change the boss phase")
	check(not storm.stage_transition_queued and storm.stage_clears == 0 and storm.bounty_earned == 0 and storm.enemies[0].hp > 0.0, "Destroying launch bays must not award victory or contract bounty before the boss core dies")
	storm.bullets.clear()
	storm.enemies[0].fire = 0.0
	storm._update_enemies()
	check(storm.bullets.filter(func(b): return b.kind == "ordnance").size() == 1, "Destroyed launch bays must reduce carrier missile volleys")
	var furnace := Sim.new(2345)
	furnace.stage = 3
	furnace._spawn_boss()
	var core: Dictionary = furnace.enemies[0]
	var sealed_hp: float = core.hp
	furnace._damage_enemy(core, 100.0, "pulse")
	var sealed_damage: float = sealed_hp - core.hp
	furnace.time = furnace.boss_spawn_time + 10.0
	var exposed_hp: float = core.hp
	furnace._damage_enemy(core, 100.0, "pulse")
	var exposed_damage: float = exposed_hp - core.hp
	check(exposed_damage > sealed_damage * 3.0, "Foundry boss must alternate between heavily armored and exposed core phases")
	for vent in furnace.enemies:
		if vent.kind == "boss_module" and vent.role == "vent":
			furnace._damage_enemy(vent, 100000.0, "pulse")
	furnace.time = furnace.boss_spawn_time
	var open_hp: float = core.hp
	furnace._damage_enemy(core, 100.0, "pulse")
	check(furnace._alive_modules("vent") == 0 and open_hp - core.hp >= 99.0, "Destroying both vents must permanently expose the Crucible core")
	check(not furnace.stage_transition_queued and furnace.stage_clears == 0, "Destroying cooling vents must not clear the Foundry before the core dies")
	var void_boss := Sim.new(3456)
	void_boss.stage = 4
	void_boss._spawn_boss()
	var regent: Dictionary = void_boss.enemies[0]
	var shielded_hp: float = regent.hp
	void_boss._damage_enemy(regent, 100.0, "pulse")
	check(shielded_hp - regent.hp < 40.0, "Shield pylons must protect the Void Regent core")
	void_boss.heavy_ready_at = 0.0
	void_boss._update_enemies()
	check(void_boss.charges.size() == 2, "Both pylons must sustain two heavy attack lanes")
	for pylon in void_boss.enemies:
		if pylon.kind == "boss_module" and pylon.role == "pylon":
			void_boss._damage_enemy(pylon, 100000.0, "pulse")
	check(void_boss._alive_modules("pylon") == 0, "Void shield pylons must be destructible")
	check(not void_boss.stage_transition_queued and void_boss.stage_clears == 0, "Destroying shield pylons must not clear the Citadel before the core dies")
	void_boss.charges.clear()
	void_boss.heavy_ready_at = 0.0
	void_boss._update_enemies()
	check(void_boss.charges.size() == 1, "Destroying pylons must change the heavy beam pattern")
	regent.hp = regent.max_hp * 0.30
	check(void_boss.boss_phase_label() == "FINAL ONSLAUGHT", "Final boss must reveal an enraged low-health phase")
	var baseline := Sim.new(3456)
	baseline.stage = 4
	baseline._spawn_boss()
	check(baseline._nearest(Vector2(270, 790)).kind == "boss_module", "Autopilot targeting must prioritize intact boss parts without player aiming")
	check(void_boss._nearest(Vector2(270, 790)).kind == "boss4", "After destroying pylons auto-aim must return to the Regent core")

func _test_synergy_tradeoffs() -> void:
	var base := Sim.new(555)
	var fortress := Sim.new(555)
	_install(fortress, "capacitor")
	check(fortress.synergy_active("fortress") and fortress.active_synergies().size() >= 1, "Aegis + Capacitor must form Fortress")
	check(fortress.weapon_power() < base.weapon_power() and fortress.hull_damage_multiplier() < base.hull_damage_multiplier(), "Fortress must trade weapon power for resilience")
	var assault := Sim.new(555, {}, "kestrel")
	_install(assault, "strike")
	check(assault.synergy_active("assault"), "Overdrive + Rail Strike must form Glass Cannon")
	check(assault.weapon_power() > base.weapon_power() and assault.hull_damage_multiplier() > base.hull_damage_multiplier(), "Glass Cannon must increase both damage dealt and hull damage taken")
	var control := Sim.new(555)
	_install(control, "emp")
	_install(control, "flak")
	check(control.synergy_active("control") and control.cooldown_multiplier() < 1.0 and control.weapon_power() < base.weapon_power(), "Control must reduce ability cooldown at a weapon-cost tradeoff")
	var salvage := Sim.new(555)
	_install(salvage, "salvage")
	_install(salvage, "siphon")
	check(salvage.synergy_active("salvager") and salvage.payout() > base.payout() and salvage.weapon_power() < base.weapon_power(), "Salvager must raise core payout at the cost of combat power")
	check(base.synergy_hint("capacitor").contains("FORTRESS"), "Upgrade drafts must explain synergy opportunities without requiring a wiki")
	base.level = 2
	base._offer_cards()
	check(base.cards.any(func(card): return card.tag == "ABILITY" and base.upgrades[card.id] == 0 and (not base.synergy_hint(str(card.id)).is_empty() or not base.fusion_hint(str(card.id)).is_empty())), "Even-level drafts should offer a real pairing for a starting ability")
	check(base.active_slots.size() == 1, "Draft guidance must not install extra actives automatically")

func _test_prototype_and_route_choices() -> void:
	var sim := Sim.new(888)
	sim._spawn_boss()
	sim._damage_enemy(sim.enemies[0], 100000.0, "pulse")
	check(not sim.advance_stage(), "Cannot enter Stage 2 without both strategic choices")
	check(sim.begin_intermission() and sim.prototype_offers.size() == 3, "A stage clear must offer exactly three Prototypes")
	var hand := sim.prototype_offers.duplicate()
	check(not sim.begin_intermission() and sim.prototype_offers == hand, "Rerendering or resuming must not redraw Prototype offers")
	var snapshot: Dictionary = sim.snapshot()
	var restored := Sim.new(1)
	check(restored.restore(snapshot) and restored.prototype_offers == hand and restored.intermission_step == "prototype", "The exact Prototype hand must survive checkpoint restore")
	check(not sim.choose_route("bounty"), "Route choice must not bypass Prototype installation")
	check(sim.choose_prototype(0), "A valid Prototype must install")
	check(not sim.choose_prototype(0) and not sim.advance_stage(), "Prototype choice is exactly once per stage")
	check(sim.choose_route("repair") and sim.advance_stage(), "A safe repair route must advance to Stage 2")
	check(is_equal_approx(sim.stage_risk, 1.0) and is_equal_approx(sim.stage_power, 1.0), "Safe route must have no extra threat or damage")
	var risk := Sim.new(889)
	risk.stage = 2
	risk._spawn_boss()
	risk._damage_enemy(risk.enemies[0], 100000.0, "pulse")
	check(risk.begin_intermission() and risk.choose_prototype(0) and risk.choose_route("bounty") and risk.advance_stage(), "Bounty route must advance after two choices")
	check(risk.stage == 3 and is_equal_approx(risk.stage_risk, 1.30), "Bounty route must multiply enemy pressure by 30%")
	var baseline := Sim.new(889)
	baseline.stage = 3
	risk._add_enemy("drone", Vector2(220, 80))
	baseline._add_enemy("drone", Vector2(220, 80))
	check(risk.enemies[0].hp > baseline.enemies[0].hp, "Risk contract must have meaningfully stronger enemies")
	risk.enemies.clear()
	risk._spawn_boss()
	var baseline_boss := Sim.new(889)
	baseline_boss.stage = 3
	baseline_boss._spawn_boss()
	check(risk.enemies[0].max_hp > baseline_boss.enemies[0].max_hp and risk.enemies[1].max_hp > baseline_boss.enemies[1].max_hp, "High-risk contracts must increase both boss core and module durability")
	risk._damage_enemy(risk.enemies[0], 1000000.0, "pulse")
	check(risk.bounty_earned == 60 and risk.bonus_cores >= 60, "Bounties must pay only when the risked next-stage boss is beaten")
	var clock := Sim.new(890)
	clock.stage = 2
	clock._spawn_boss()
	clock._damage_enemy(clock.enemies[0], 100000.0, "pulse")
	check(clock.begin_intermission() and clock.choose_prototype(0) and clock.choose_route("overclock") and clock.advance_stage(), "Overclock route must be available")
	check(is_equal_approx(clock.stage_power, 1.25) and is_equal_approx(clock.shield, clock.max_shield * 0.60), "Overclock must grant damage but start with reduced shields")
	var prototype := Sim.new(556)
	prototype.prototypes = ["volatile_core", "null_harmonics", "salvage_charter", "breach_optics"]
	check(prototype.weapon_power() > 0.0 and prototype.cooldown_multiplier() < 1.0 and prototype.payout() > Sim.new().payout(), "Prototype stack must affect combat, cooldown and rewards")
	var legacy: Dictionary = Sim.new().snapshot()
	for key in ["prototypes", "prototype_offers", "intermission_step", "route_choice", "stage_power", "stage_risk", "bounty_earned", "safeguard_used", "boss_spawn_time"]:
		legacy.erase(key)
	check(Sim.new().restore(legacy), "An older v0.5 flight without strategic fields must remain resumable")
	var safeguard := Sim.new(891)
	safeguard.prototypes = ["emergency_safeguard"]
	safeguard.safeguard_used = true
	safeguard._spawn_boss()
	check(safeguard.safeguard_used, "Emergency Safeguard must not reset when the boss spawns during the same stage")


func _test_fusions_and_milestones() -> void:
	var content := Sim.new(1901).content
	check(content.fusions.size() == 11 and content.passive_links.size() == 8, "Twenty-two base actives must have eleven fusions and eight passive links")
	for card in content.cards:
		check(int(card.max) == 10 and card.has("rank5") and card.has("rank10"), "Every upgrade needs rank 5 and 10 milestones: " + str(card.id))
	for pair in content.fusions:
		var sim := Sim.new(1901)
		_fuse_pair(sim,pair)
		check(str(pair.id) in sim.active_slots and sim._source_active(str(pair.parts[0])) and sim._source_active(str(pair.parts[1])), "Fusion must replace two active buttons: " + str(pair.id))
		check(sim.active_slots.size() == (1 if "aegis" in pair.parts else 2), "Fusion must free one equipped slot, not add a fifth button")
		check(not sim.activate(str(pair.parts[0])) and not sim.activate(str(pair.parts[1])), "Consumed components cannot cast separately: " + str(pair.id))
		var old_uses: int = sim.ability_uses
		check(sim.activate(str(pair.id)) and sim.ability_uses == old_uses + 1 and float(sim.cooldowns[str(pair.id)]) > 0.0, "Fused button must cast one new skill with a real cooldown: " + str(pair.id))
		var snap: Dictionary = sim.snapshot()
		var clone := Sim.new(2)
		check(clone.restore(snap) and clone.snapshot() == snap, "Fused skills and source ranks must survive save/restore: " + str(pair.id))
	var counter := Sim.new(1909)
	counter.active_slots = ["nova_aegis"]
	counter.upgrades.aegis = 1
	counter.upgrades.nova = 1
	counter.upgrades.nova_aegis = 1
	counter.hull = counter.max_hull - 30.0
	var plain := Sim.new(1909)
	plain.active_slots = ["nova_aegis"]
	plain.upgrades.aegis = 1
	plain.upgrades.nova = 1
	plain.upgrades.nova_aegis = 1
	plain.hull = plain.max_hull - 30.0
	counter.charges.append({"source":0, "x":270.0, "remaining":0.5, "duration":1.8, "damage":29.0})
	counter._add_enemy("station", Vector2(260, 120))
	plain._add_enemy("station", Vector2(260, 120))
	check(counter.activate("nova_aegis") and plain.activate("nova_aegis"), "Nova Guard must cast when a beam is close")
	check(counter.cooldowns.nova_aegis < plain.cooldowns.nova_aegis and counter.hull > plain.hull and counter.aegis_left > plain.aegis_left, "A well-timed fusion counter must earn real healing and a shorter cooldown")
	check(counter.kills > plain.kills, "A timed Nova Guard counter must hit much harder than firing it early")
	var slots := Sim.new(1902)
	for name in ["flak", "emp", "strike"]:
		_install(slots, name)
	check(slots.active_slots.size() == 4 and not slots._can_learn_active("nova"), "A rank-1 partner cannot bypass a full bar")
	var free_slot := Sim.new(1903)
	_install(free_slot,"nova")
	check(free_slot.active_slots.size() == 2 and "nova_aegis" not in free_slot.active_slots, "Collecting two rank-1 actives does not fuse them")
	_fuse_pair(free_slot,content.fusions[0])
	check(free_slot.active_slots.size() == 1 and "nova_aegis" in free_slot.active_slots, "A rank-5 pair reopens one slot")
	for link in content.passive_links:
		var sim := Sim.new(1904)
		for part in link.requires:
			if int(sim.upgrades.get(str(part), 0)) == 0:
				_install(sim, str(part))
		check(sim.passive_link_active(str(link.id)), "Both equipped passive tracks must trigger the defined team-up: " + str(link.id))
	var tank := Sim.new(1905)
	tank.upgrades.armor = 1
	tank.upgrades.hull = 1
	check(tank.passive_link_active("reinforced_plating") and tank.hull_damage_multiplier() < Sim.new(1905).hull_damage_multiplier(), "Armor + Hull must reduce actual incoming damage")
	var first := Sim.new(1906)
	first.upgrades.hull = 4
	first.cards = [first.content.cards.filter(func(card): return card.id == "hull")[0]]
	var hp: float = first.max_hull
	check(first.choose_card(0) and first.upgrades.hull == 6 and first.max_hull == hp + 36.0 + 25.0 and first.capacity_milestones.has("hull5"), "Crossing rank 5 must pay a one-time larger hull bonus")
	first.upgrades.hull = 9
	first.cards = [first.content.cards.filter(func(card): return card.id == "hull")[0]]
	hp = first.max_hull
	check(first.choose_card(0) and first.upgrades.hull == 10 and first.max_hull == hp + 18.0 + 50.0 and first.capacity_milestones.has("hull10"), "Crossing rank 10 must pay another one-time hull bonus")
	var saved: Dictionary = first.snapshot()
	var resume := Sim.new(9)
	check(resume.restore(saved) and resume.max_hull == first.max_hull and resume.capacity_milestones == first.capacity_milestones, "Capacity milestones must not pay twice on restore")
	var old: Dictionary = saved.duplicate(true)
	old.erase("capacity_milestones")
	old.max_hull -= 75.0
	old.hull -= 75.0
	var migrated := Sim.new(9)
	check(migrated.restore(old) and migrated.max_hull == first.max_hull, "Old v0.6 saves must receive existing rank milestones exactly once")
	var starter := Sim.new(1907)
	var ranked := Sim.new(1907)
	ranked.upgrades.aegis = 5
	check(starter.activate("aegis") and ranked.activate("aegis") and ranked.cooldowns.aegis < starter.cooldowns.aegis and ranked.aegis_left > starter.aegis_left, "Rank 5 active milestone must improve cooldown and effect")
	var maxed := Sim.new(1907)
	maxed.upgrades.aegis = 10
	check(maxed.activate("aegis") and maxed.cooldowns.aegis < ranked.cooldowns.aegis and maxed.aegis_left > ranked.aegis_left, "Rank 10 active milestone must improve both again")
	var guns := Sim.new(1908)
	guns.upgrades.pulse = 10
	guns.upgrades.seeker = 10
	guns._add_enemy("drone", Vector2(250, 150))
	guns._update_weapons()
	check(guns.shots.filter(func(shot): return shot.weapon == "pulse").size() == 3 and guns.shots.filter(func(shot): return shot.weapon == "seeker").size() == 3, "Rank 10 pulse and seeker volleys must change live weapon behavior")


func _test_new_stage_threats() -> void:
	var sim := Sim.new(707)
	for kind in ["arc_spire", "storm_weaver", "forge_turret", "slag_bomber", "ember_hunter", "splitter", "phase_stalker", "void_lancer", "gravity_sentinel", "echo_carrier"]:
		check(sim.content.enemies.has(kind) and sim.content.enemies[kind].hp > 0, "All new enemies need positive health specs: " + kind)
	sim.stage = 3
	sim.stage_start = sim.time
	sim._add_enemy("slag_bomber", Vector2(250, 100))
	sim.enemies[0].fire = 0.0
	sim._update_enemies()
	check(sim.bullets.any(func(b): return b.kind == "slag" and b.fuse > 0.0), "Foundry bomber must create timed molten-slag hazards")
	sim._hit(2.0, "heat", "test")
	check(sim.heat_left >= 5.0 and sim.weapon_power() < Sim.new().weapon_power(), "Heat must reduce firepower temporarily")
	var first_kills := sim.kills
	sim.enemies.clear()
	sim._add_enemy("splitter", Vector2(225, 180))
	sim._damage_enemy(sim.enemies[0], 10000.0, "pulse")
	check(sim.kills == first_kills + 1 and sim.enemies.size() == 3, "Splitter must release two new drone enemies on death")
	sim.enemies.clear()
	sim.bullets.clear()
	sim.stage = 4
	sim.stage_start = sim.time
	sim._add_enemy("gravity_sentinel", Vector2(260, 120))
	sim.enemies[0].fire = 0.0
	sim._update_enemies()
	check(sim.bullets.any(func(b): return b.kind == "gravity"), "Void sentinels must launch recognizable gravity projectiles")
	sim._hit(2.0, "gravity", "test")
	check(sim.gravity_left >= 4.5, "Gravity threat must slow automatic weapons")
	sim.enemies.clear()
	sim.bullets.clear()
	sim._spawn_boss()
	sim.heavy_ready_at = 0.0
	sim._update_enemies()
	check(sim.charges.size() == 2 and sim.charges[0].remaining >= 1.0, "Final boss must telegraph two distinct heavy lanes")
	sim._hit(2.0, "void", "test")
	check(sim.hull < sim.max_hull, "Void shots must meaningfully bypass shields")

func _balance(seeds: int) -> Dictionary:
	var result: Dictionary = {}
	for strategy in ["never", "on_cooldown", "timed"]:
		var survival := 0.0
		var remaining := 0.0
		var wins := 0
		var max_charges := 0
		var max_entities := 0
		for seed_index in range(seeds):
			# Rank-5 fusion sources add milestone power; Hard keeps this encounter
			# challenging enough to distinguish counter timing from cooldown spam.
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

func _test_stage_rerolls_and_shield_breaks() -> void:
	for rank in [0, 1, 3]:
		for pilot in ["rookie", "tactician"]:
			var sim := Sim.new(2401, {"rerolls": rank}, "vanguard", pilot)
			for stage_number in range(1, 5):
				var expected: int = rank + (1 if pilot == "tactician" and stage_number == 1 else 0)
				check(sim.rerolls_left == expected, "Only purchased stage rerolls replenish; pilot bonus is once per flight")
				sim._offer_cards(false)
				for use in range(expected):
					check(sim.reroll_cards(), "Every granted reroll can replace the hand")
				check(not sim.reroll_cards(), "Exhausted rerolls cannot replace the hand")
				var saved := sim.snapshot()
				var resumed := Sim.new()
				check(resumed.restore(saved) and resumed.rerolls_left == 0 and resumed.pilot_rerolls_left == 0, "Resume must not replenish spent rerolls")
				check(resumed.pilot_id == pilot, "Resume must retain the pilot whose reroll allowance was saved")
				sim = resumed
				sim.cards.clear()
				sim._spawn_boss()
				sim._damage_enemy(sim.enemies[0], 9999999.0, "pulse")
				if stage_number < 4:
					check(sim.begin_intermission() and sim.choose_prototype(0) and sim.choose_route("repair") and sim.advance_stage(), "Rerolls refill through the real boss/intermission transition")
					var allowance: int = sim.rerolls_left
					check(not sim.advance_stage() and sim.rerolls_left == allowance, "Repeated stage advance cannot grant more rerolls")
	var unused := Sim.new(2402, {"rerolls": 2}, "vanguard", "tactician")
	unused._offer_cards(false)
	unused.reroll_cards()
	check(unused.rerolls_left == 2 and unused.pilot_rerolls_left == 1, "Use renewable stage rerolls before the pilot reserve")
	unused.cards.clear()
	unused._spawn_boss()
	unused._damage_enemy(unused.enemies[0], 9999999.0, "pulse")
	unused._enter_stage_two()
	check(unused.rerolls_left == 3 and unused.pilot_rerolls_left == 1, "Unused stage uses do not accumulate; unused pilot reserve remains")
	var legacy := unused.snapshot()
	legacy.erase("pilot_rerolls_left")
	var migrated := Sim.new()
	check(migrated.restore(legacy) and migrated.rerolls_left == unused.rerolls_left, "Older checkpoints keep their current allowance without a free refill")
	var shielded := Sim.new(2403)
	shielded._hit(2, "chaff", "test")
	check(not shielded.effects.any(func(e): return e.kind == "shield-break"), "Ordinary shield hits do not show a break")
	shielded.shield = 4.0
	shielded._hit(4.0, "heavy", "test")
	check(shielded.shield == 0 and shielded.effects.filter(func(e): return e.kind == "shield-break").size() == 1, "Exact shield depletion must emit one distinct break cue")
	shielded._hit(4.0, "heavy", "test")
	check(shielded.effects.filter(func(e): return e.kind == "shield-break").size() == 1, "Further hull hits must not repeat the shield-break cue")
	var protected := Sim.new(2404)
	protected.aegis_left = 1.0
	protected._hit(100.0, "heavy", "test")
	check(not protected.effects.any(func(e): return e.kind == "shield-break"), "Aegis-blocked attacks must not claim the shield broke")
	var safeguard := Sim.new(2405)
	safeguard.prototypes = ["emergency_safeguard"]
	safeguard.shield = 2.0
	safeguard._hit(3.0, "heavy", "test")
	check(safeguard.shield > 0 and safeguard.effects.any(func(e): return e.kind == "shield-break"), "An immediately rebuilt shield still shows the actual break")

func _test_long_runs() -> void:
	var added := ["boss_hunter", "finisher", "opening_salvo", "ablative", "insulation", "shield_surge", "field_medic", "last_stand", "shield_focus", "afterburn"]
	var sim := Sim.new(2751)
	check(sim.content.cards.filter(func(c): return c.id in added and c.tag == "SYSTEM").size() == 10, "Ten new passives must exist")
	for stage in [1, 2]:
		sim.stage = stage
		var seen := {}
		for i in range(300):
			sim._offer_cards(false)
			for card in sim.cards: seen[card.id] = true
		check(added.all(func(id): return seen.has(id) == (stage == 2)), "Late passives become draftable in world 2")
		check(not sim.cards.any(func(c): return not sim.fusion_spec(c.id).is_empty()), "Unowned fusions cannot be offered directly")
	for pair in sim.content.fusions:
		var fused := Sim.new(2752)
		_fuse_pair(fused,pair)
		var seen := {}
		for i in range(100):
			fused._offer_cards(false)
			for card in fused.cards: seen[card.id] = true
		check(not seen.has(pair.parts[0]) and not seen.has(pair.parts[1]) and seen.has(pair.id), "Only the fused upgrade may reappear: " + str(pair.id))
		fused.cards = [fused.content.cards.filter(func(c): return c.id == pair.id)[0]]
		var power: float = fused._active_rank_scale(pair.id)
		var slots: Array = fused.active_slots.duplicate()
		check(fused.choose_card(0) and fused.upgrades[pair.id] == 3 and fused._active_rank_scale(pair.id) > power and fused.active_slots == slots, "Upgrading a fusion strengthens it without consuming a slot")
		# Migrate an already-open v0.7.2 draft, preserving its remaining draft tools.
		fused.cards = [fused.content.cards.filter(func(c): return c.id == pair.parts[0])[0]]
		fused.pending_levels = 2
		fused.rerolls_left = 1
		var old: Dictionary = fused.snapshot()
		var restored := Sim.new()
		check(restored.restore(old) and restored.pending_levels == 2 and restored.rerolls_left == 1 and not restored.cards.any(func(c): return c.id in pair.parts), "Old component offers migrate without charging a reroll or losing a level")
		var again := Sim.new()
		check(again.restore(restored.snapshot()) and again.snapshot() == restored.snapshot(), "Migrated draft remains stable after another restore")
	for id in added:
		var ranked := Sim.new(2753)
		var card: Dictionary = ranked.content.cards.filter(func(c): return c.id == id)[0]
		ranked.cards = [card]
		check(ranked.choose_card(0) and ranked.upgrades[id] == 2 and ranked.active_slots == ["aegis"], "Passive picks never consume an active slot: " + id)
	var target := {"id":99, "p":Vector2(270,200), "kind":"boss", "hp":1000.0, "max_hp":1000.0}
	sim = Sim.new()
	sim.upgrades.boss_hunter = 10
	sim._damage_enemy(target, 100, "pulse")
	check(is_equal_approx(target.hp, 810.0), "Siege rounds increase live boss damage")
	target = {"id":99, "p":Vector2(270,200), "kind":"drone", "hp":300.0, "max_hp":1000.0}
	sim.upgrades.finisher = 10
	sim._damage_enemy(target, 100, "pulse")
	check(is_equal_approx(target.hp, 120.0), "Finisher applies below 35% enemy hull")
	target = {"id":99, "p":Vector2(270,200), "kind":"drone", "hp":1000.0, "max_hp":1000.0}
	sim.upgrades.opening_salvo = 10
	sim._damage_enemy(target, 100, "pulse")
	sim._damage_enemy(target, 100, "pulse")
	check(is_equal_approx(target.hp, 720.0), "First strike applies only to the opening hit")
	sim = Sim.new()
	sim.upgrades.ablative = 10
	sim._hit(10, "heavy", "test")
	sim._hit(10, "ordnance", "test")
	sim._hit(10, "hazard", "Molten slag")
	sim._hit(10, "ion", "test")
	check(is_equal_approx(sim.damage_taken.heavy, 6) and is_equal_approx(sim.damage_taken.ordnance, 6) and is_equal_approx(sim.damage_taken.hazard, 6) and is_equal_approx(sim.damage_taken.ion, 10), "Blast plating protects only explosive and beam damage")
	sim = Sim.new()
	sim.upgrades.insulation = 10
	for kind in ["ion", "heat", "gravity", "corrosion"]: sim._hit(1, kind, "test")
	sim.cooldowns.aegis = 8
	sim._hit(1, "disrupt", "test")
	check(is_equal_approx(sim.shield_offline, 2) and is_equal_approx(sim.heat_left, 2.5) and is_equal_approx(sim.gravity_left, 2.25) and is_equal_approx(sim.corrosion_left, 2.5) and is_equal_approx(sim.cooldowns.aegis, 9), "Insulation shortens all five debuffs")
	sim = Sim.new()
	sim.upgrades.shield_surge = 10
	sim.shield = 0
	sim.activate("aegis")
	check(is_equal_approx(sim.shield, sim.max_shield * 0.15), "Shield reserve restores shield on a cast")
	sim = Sim.new()
	sim.upgrades.field_medic = 10
	sim.hull -= 20
	var before: float = sim.hull
	sim._add_enemy("drone", Vector2(270,200))
	sim._damage_enemy(sim.enemies[0], 1000, "pulse")
	check(is_equal_approx(sim.hull, before + 1.75), "Combat repairs restore hull from an actual kill")
	sim = Sim.new()
	var base_power: float = sim.weapon_power()
	sim.upgrades.last_stand = 10
	check(is_equal_approx(sim.weapon_power(), base_power), "Last stand stays inactive at healthy hull")
	sim.hull = sim.max_hull * 0.3
	check(is_equal_approx(sim.weapon_power(), base_power * 1.6), "Last stand boosts damage below 40% hull")
	sim = Sim.new()
	base_power = sim.weapon_power()
	sim.upgrades.shield_focus = 10
	check(is_equal_approx(sim.weapon_power(), base_power * 1.5), "Shield focus boosts damage with high shields")
	sim.shield = sim.max_shield * 0.5
	check(is_equal_approx(sim.weapon_power(), base_power), "Shield focus stops when shields drop")
	sim = Sim.new()
	sim.upgrades.afterburn = 10
	sim.pulse_timer = 1.0
	sim.activate("aegis")
	sim._update_weapons()
	check(is_equal_approx(sim.pulse_timer, 1.0 - Sim.DT * 1.55), "Follow-through accelerates actual weapon timers")
	var clone := Sim.new()
	check(clone.restore(sim.snapshot()) and clone.aftercast_left == 4.0 and clone.upgrades.afterburn == 10, "New passives and cast timer survive resume")
	for i in range(241): sim.step()
	check(sim.aftercast_left == 0.0, "Follow-through expires after four simulation seconds")
	for active in ["aegis", "nova_aegis"]:
		sim = Sim.new()
		if active == "nova_aegis": _fuse_pair(sim,sim.content.fusions[0])
		for key in ["aegis", "nova", "nova_aegis", "coolant", "amplifier"]: sim.upgrades[key] = 10
		sim.meta.ability_cooldown = 10
		sim.meta.ability_power = 10
		sim.cards.clear()
		sim.activate(active)
		check(sim.aegis_left <= sim.cooldowns[active] - 1.5 + 0.001, "Endgame cooldowns cannot create permanent invulnerability")
	for stage in [2,3,4]:
		sim = Sim.new()
		sim.stage = stage
		sim._hit(10, "ion", "test")
		check(is_equal_approx(sim.damage_taken.ion, 10 * sim.stage_spec().damage_scale), "World damage scale reaches collision resolution")

func _fixed_build_timing(seeds: int) -> Dictionary:
	var results := {}
	for strategy in ["on_cooldown", "timed"]:
		var wins := 0
		var hull := 0.0
		var survival := 0.0
		for seed in range(seeds):
			# Rank-5 fusion sources add milestone power; Hard keeps this encounter
			# challenging enough to distinguish counter timing from cooldown spam.
			var sim := Sim.new(61000 + (seed + 1) * 7919, {}, "vanguard", "rookie", "hard")
			_fuse_pair(sim,sim.content.fusions[0])
			sim.cards.clear()
			sim.upgrades.pulse = 3
			sim.upgrades.seeker = 3
			sim.upgrades.armor = 3
			sim.upgrades.regen = 2
			sim._spawn_boss()
			for frame in range(60 * 120):
				sim.cards.clear()
				sim.pending_levels = 0
				var counter: bool = sim.charges.any(func(c): return c.remaining < 0.55)
				if not counter:
					for b in sim.bullets:
						if (b.p+b.v*0.30).distance_squared_to(sim.ship_position(sim.time+0.30)) < 65*65: counter = true; break
				if strategy == "on_cooldown" or counter: sim.activate("nova_aegis")
				sim.step()
				sim.effects.clear()
				if sim.ended or sim.stage_transition_queued: break
			wins += int(sim.stage_transition_queued)
			hull += sim.hull
			survival += sim.time
		results[strategy] = {"wins":wins,"mean_hull":snappedf(hull/seeds,0.1),"seconds":snappedf(survival/seeds,0.1)}
	return results

func _test_fusion_thresholds() -> void:
	for pair in Sim.new().content.fusions:
		var sim := Sim.new(2801)
		sim.active_slots = [str(pair.parts[0]),str(pair.parts[1])]
		var a: String = pair.parts[0]
		var b: String = pair.parts[1]
		for ranks in [[1,1],[4,4],[4,5],[5,4],[10,1],[1,10]]:
			sim.upgrades[a] = ranks[0]
			sim.upgrades[b] = ranks[1]
			sim._try_fuse()
			check(str(pair.id) not in sim.active_slots, "Both fusion components must reach 5: " + str(pair.id))
		sim.upgrades[a] = 5
		sim.upgrades[b] = 1
		check(sim.fusion_hint(b).is_empty(), "A rank-1 partner must not be advertised as an immediate fusion")
		sim.upgrades[b] = 3
		check(not sim.fusion_hint(b).is_empty(), "The 3-to-5 pick previews the resulting fusion")
		var copy := Sim.new()
		check(copy.restore(sim.snapshot()) and copy.active_slots == sim.active_slots, "Resume keeps a pair separate until upgraded")
		_install(copy,b)
		check(str(pair.id) in copy.active_slots and copy.upgrades[a] == 5 and copy.upgrades[b] == 5, "A real rank-5 draft pick triggers fusion")
		check(copy.effects.any(func(e): return e.kind == "fusion-formed" and e.fusion == pair.id), "Forming a fusion emits its own presentation event")
		copy.cards.clear()
		check(copy.activate(pair.id) and copy.effects.any(func(e): return e.kind == "fusion-cast" and e.fusion == pair.id), "Every fusion emits its distinct cast effect")
		check(not copy.effects.any(func(e): return e.kind == "nova"), "Fusions no longer add the same generic Nova effect")
		var old: Dictionary = copy.snapshot()
		old.upgrades[a] = 1
		old.upgrades[b] = 1
		var legacy := Sim.new()
		check(legacy.restore(old) and str(pair.id) in legacy.active_slots, "Already-earned fusions survive old saves without losing occupied slots")
	var full := Sim.new(2802)
	full.active_slots = ["aegis","nova","emp","flak"]
	full.upgrades.aegis = 5
	full.upgrades.nova = 4
	full.upgrades.emp = 1
	full.upgrades.flak = 1
	_install(full,"nova")
	check(full.upgrades.nova == 6 and full.active_slots.size() == 3 and "nova_aegis" in full.active_slots, "Crossing 5 from 4 also fuses on a full bar")

	var old_bar := Sim.new(2803, {"rerolls":2})
	old_bar.active_slots = ["aegis","emp","flak","mend"]
	for id in old_bar.active_slots: old_bar.upgrades[id] = 1
	old_bar.cards = [old_bar.content.cards.filter(func(c): return c.id == "nova")[0]]
	var restored := Sim.new()
	check(restored.restore(old_bar.snapshot()) and not restored.cards.any(func(c): return c.tag == "ABILITY" and restored.upgrades[c.id] == 0), "An old full-bar partner offer must become a valid hand")
	check(restored.rerolls_left == old_bar.rerolls_left and restored.pending_levels == old_bar.pending_levels, "Migrating the full-bar hand costs no reroll or level")
	var stable := Sim.new()
	check(stable.restore(restored.snapshot()) and stable.snapshot() == restored.snapshot(), "The migrated full-bar hand stays fixed on subsequent resumes")

func _test_expanded_hangar() -> void:
	check(Catalog.HANGAR.size() == 38, "Sixteen new permanent tracks bring the Hangar to 38")
	var starting := Sim.new(3001,{"arc_start":1,"lance_start":1,"signature_rank":2})
	check(starting.upgrades.arc == 1 and starting.upgrades.lance == 1, "Purchased starting weapons are installed")
	check(Sim.new(3001,{"arc_start":1},"arcwing").upgrades.arc == 2, "Charged coil also improves an Arcwing’s starting weapon")
	check(starting.upgrades.aegis == 3 and starting.active_slots == ["aegis"], "Pilot drills upgrades the signature without filling another slot")
	check(Sim.new(3001,{"signature_rank":2},"haven").upgrades.mend == 3, "Pilot drills follows the selected ship")
	var armor := Sim.new(3002,{"beam_plating":4})
	armor.shield = 0
	armor._hit(20,"heavy","test beam")
	check(is_equal_approx(armor.hull,82.4), "Ablative panels reduce an actual beam hit by 12%")
	var restart := Sim.new(3003,{"shield_restart":4})
	restart._hit(50,"heavy","break")
	check(restart.shield == 0 and is_equal_approx(restart.shield_offline,2.2), "Restart circuit shortens shield-break downtime")
	var sealed := Sim.new(3004,{"hazard_seals":4})
	sealed._hit(1,"heat","heat")
	check(is_equal_approx(sealed.heat_left,4.0), "Sealed systems shorten an actual status hit")
	var siege := Sim.new(3005,{"boss_damage":5})
	var target := {"id":99,"kind":"boss","hp":1000.0,"max_hp":1000.0,"p":Vector2(270,130)}
	siege._damage_enemy(target,100,"pulse")
	check(is_equal_approx(target.hp,885.0), "Siege targeting applies only to automatic boss damage")
	target.hp = 1000.0
	siege._damage_enemy(target,100,"nova")
	check(is_equal_approx(target.hp,900.0), "Siege targeting does not silently amplify active damage")
	var normal := Sim.new(3006)
	var warheads := Sim.new(3006,{"ordnance_damage":4})
	normal._add_enemy("station",Vector2(270,300))
	warheads._add_enemy("station",Vector2(270,300))
	normal._update_weapons()
	warheads._update_weapons()
	check(is_equal_approx(warheads.shots.filter(func(v):return v.weapon=="seeker")[0].damage,normal.shots.filter(func(v):return v.weapon=="seeker")[0].damage*1.2), "Warhead tooling strengthens real seeker projectiles")
	var cast := Sim.new(3007,{"cast_repair":3,"opening_charge":3})
	cast.hull = 40
	cast.activate("aegis")
	normal = Sim.new(3007)
	normal.activate("aegis")
	check(cast.hull == 43 and is_equal_approx(cast.cooldowns.aegis,normal.cooldowns.aegis*0.7), "Field patch and Hot start apply to the first cast")
	var saved := Sim.new()
	check(saved.restore(cast.snapshot()) and saved.stage_casts.has("aegis"), "Hot start spending survives resume")
	cast.cooldowns.aegis = 0
	cast.activate("aegis")
	check(is_equal_approx(cast.cooldowns.aegis,normal.cooldowns.aegis), "Hot start does not repeat within a world")
	var warp := Sim.new(3008,{"warp_repairs":3,"banish_relay":2,"banishes":1})
	warp.hull = 10
	warp.stage_transition_queued = true
	warp.stage_clears = 1
	warp.intermission_step = "ready"
	warp.route_choice = "overclock"
	warp.stage_casts.aegis = true
	warp._launch_escorts(2,6,10)
	warp._deploy_ion_mines(1,100,150)
	check(warp.advance_stage() and is_equal_approx(warp.hull,32.0) and warp.banishes_left == 3, "Warp repairs and Banish relay pay at the new world")
	check(warp.stage_casts.is_empty() and warp.ion_mines.is_empty() and warp.escort_left == 0, "Warp resets first casts and clears support from the previous battlefield")
	var focused := Sim.new(3009,{"reroll_focus":1})
	focused.rerolls_left = 100
	focused._offer_cards(false)
	var valid := true
	for i in range(100):
		focused.reroll_cards()
		valid = valid and focused.cards.any(func(c):return focused.upgrades.get(c.id,0)>0)
		var ids := {}
		for card in focused.cards:
			valid = valid and not ids.has(card.id)
			ids[card.id] = true
	check(valid and focused.rerolls_left == 0, "Focused rerolls offer an owned upgrade without duplicate cards or extra uses")
	focused.banished = ["aegis","pulse","seeker"]
	focused._offer_cards(false)
	focused._focus_reroll()
	check(not focused.cards.any(func(c):return c.id in focused.banished), "Focused uplink respects removed tracks when nothing owned remains")
	var skip := Sim.new(3010,{"skip_patch":3,"skips":1})
	skip.hull = 10
	skip._offer_cards(false)
	check(skip.skip_cards() and skip.hull == 40 and skip.skips_left == 0, "Repair stores increase the actual skip heal")
	var salvage := Sim.new(3011,{"module_salvage":3,"clean_clear":3})
	salvage._spawn_boss()
	var part := {"id":99,"name":"Test part","kind":"boss_module","hp":10.0,"max_hp":10.0,"p":Vector2(270,100),"xp":0}
	salvage._damage_enemy(part,20,"pulse")
	check(salvage.bonus_cores == 3, "Component salvage pays for a destroyed boss part")
	salvage.hull = 70
	salvage._damage_enemy(salvage.enemies[0],100000,"pulse")
	check(salvage.bonus_cores == 12, "Clean contract pays a healthy world clear")
	salvage._damage_enemy(salvage.enemies[0],100000,"pulse")
	check(salvage.bonus_cores == 12, "A destroyed boss cannot pay the contract twice")
	var legacy: Dictionary = Sim.new().snapshot()
	for id in ["arc_start","cast_repair","opening_charge","reroll_focus"]: legacy.meta.erase(id)
	legacy.erase("stage_casts")
	legacy.erase("ion_mines")
	var restored := Sim.new()
	check(restored.restore(legacy) and restored.meta.arc_start == 0 and restored.ion_mines.is_empty(), "Older saves default new purchases and support state safely")

func _test_support_actives() -> void:
	for rank in [1,5,10]:
		var drone := Sim.new(3050)
		drone.active_slots = ["wing_drones"]
		drone.upgrades.wing_drones = rank
		drone._add_enemy("station",Vector2(270,600))
		drone.enemies[0].hp = 10000.0
		drone.enemies[0].max_hp = 10000.0
		check(drone.activate("wing_drones") and drone.escort_count == 2+int(rank>=5)+int(rank>=10), "Drone milestones add real escorts at rank " + str(rank))
		for frame in range(40):
			drone._update_support()
			drone._update_shots()
		check(drone.enemies[0].hp < 10000 and drone.damage_dealt.get("escort",0)>0, "Escort shots must hit real targets")
		var copy := Sim.new()
		check(copy.restore(drone.snapshot()) and copy.snapshot() == drone.snapshot(), "Escort count, damage and cadence survive saving")
		drone.escort_left = Sim.DT
		drone.escort_timer = 0.0
		var shots: int = drone.shots.size()
		drone._update_support()
		check(drone.escort_left == 0 and drone.shots.size() == shots, "Expired escorts cannot fire one extra volley")
		var mine := Sim.new(3051)
		mine.active_slots = ["ion_mine"]
		mine.upgrades.ion_mine = rank
		mine._add_enemy("station",Vector2(270,450))
		mine.enemies[0].hp = 10000.0
		mine.enemies[0].max_hp = 10000.0
		check(mine.activate("ion_mine") and mine.ion_mines.size() == (2 if rank == 10 else 1), "Mine rank 10 deploys a second charge")
		check(mine.ion_mines[0].radius == (190.0 if rank>=5 else 150.0), "Mine rank 5 expands the actual blast radius")
		mine.bullets = [{"p":mine.ion_mines[0].p,"v":Vector2.ZERO,"kind":"chaff","damage":10},{"p":Vector2(5,5),"v":Vector2.ZERO,"kind":"chaff","damage":10}]
		copy = Sim.new()
		check(copy.restore(mine.snapshot()) and copy.snapshot() == mine.snapshot(), "Armed mines survive saving exactly")
		for frame in range(110): mine._update_support()
		check(mine.ion_mines.is_empty() and mine.enemies[0].hp < 10000 and mine.bullets.size() == 1 and mine.bullets[0].p == Vector2(5,5), "Timed mines damage their area and clear only nearby shots")
	var carrier := Sim.new(3052)
	_fuse_pair(carrier,carrier.fusion_spec("storm_carrier"))
	check(carrier.activate("storm_carrier") and carrier.escort_count == 4 and carrier.ion_mines.size() == 3, "Storm Carrier combines four escorts and three mines in one active slot")

	carrier.ion_mines.clear()
	carrier._add_enemy("drone",Vector2(300,930))
	carrier._deploy_ion_mines(3,100,190)
	check(carrier.ion_mines.all(func(m):return m.p.x >= 25 and m.p.x <= 515 and m.p.y <= 865), "Ion charges stay visible even when targeting an enemy near the bottom edge")
