extends SceneTree
## Phase 2+3 contract: choices must be real, saved and independent of manual
## ability timing. Fixed fixtures test behavior, not synthetic human win rates.
const Sim = preload("res://scripts/simulation.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("BUILD_OVERHAUL: " + text)

func _enemy(sim: RefCounted, leader: bool = false) -> Dictionary:
	sim._add_enemy("carrier", Vector2(260, 210))
	var enemy: Dictionary = sim.enemies[-1]
	enemy.hp = 10000.0
	enemy.max_hp = 10000.0
	if leader:
		enemy["elite_role"] = "leader"
	return enemy

func _sim(seed: int, weapon: String = "", evolution: String = "") -> RefCounted:
	var sim := Sim.new(seed)
	sim.stage = 2
	if not weapon.is_empty():
		sim.upgrades[weapon] = 5
	if not evolution.is_empty():
		sim.weapon_evolutions[weapon] = evolution
	return sim

func _strike(sim: RefCounted, weapon: String, leader: bool = false) -> Dictionary:
	var e: Dictionary = _enemy(sim, leader)
	sim._damage_enemy(e, 25.0, weapon)
	return e

func _run() -> void:
	var catalog := Sim.new(912001)
	check(catalog.content.weapon_evolutions.size() == 4, "four weapon families with evolution choices")
	for weapon in ["pulse", "seeker", "arc", "lance"]:
		var options: Array = catalog.content.weapon_evolutions[weapon]
		check(options.size() == 2 and str(options[0].id) != str(options[1].id), weapon + " offers two distinct alternatives")
		var sim := Sim.new(912002)
		sim.stage = 2
		sim.upgrades[weapon] = 4
		sim.cards = [sim.content.cards.filter(func(c): return str(c.id) == weapon)[0]]
		check(sim.choose_card(0), weapon + " rank 4 draft crosses rank 5")
		check(sim.pending_build_choices.size() == 1 and sim.pending_build_choices[0].id == weapon, weapon + " queues a real decision")
		var checkpoint: Dictionary = sim.snapshot()
		var restored := Sim.new()
		check(restored.restore(checkpoint) and restored.snapshot() == checkpoint, weapon + " pending choice saves exactly")
		var option_id: String = str(options[1].id)
		check(not restored.resolve_build_choice("not-an-evolution"), weapon + " rejects bogus choice IDs")
		check(restored.resolve_build_choice(option_id) and restored.weapon_evolutions[weapon] == option_id and restored.pending_build_choices.is_empty(), weapon + " second option can really be chosen")
		check(restored.snapshot() != checkpoint, weapon + " choice actually changes saved state")
		restored.step() # Combat may start if there is no follow-up draft.
		check(restored.weapon_evolutions[weapon] == option_id, weapon + " evolution remains after the next simulated step")
	var preserved := _sim(912003, "pulse", "duelist")
	var save: Dictionary = preserved.snapshot()
	save.erase("build_choices_active")
	save.erase("weapon_evolutions")
	save.erase("pending_build_choices")
	save.erase("fusion_declined")
	save.erase("evolution_lifeline_tick")
	var old := Sim.new()
	check(old.restore(save) and not old.build_choices_active and old.evolution_id("pulse") == "", "pre-overhaul saved flights remain on old behavior")
	old._queue_weapon_evolutions()
	check(old.pending_build_choices.is_empty(), "older saved run never receives a new choice unexpectedly")
	var daily := _sim(912004, "pulse", "duelist")
	daily.daily_day = "2026-11-18"
	check(daily.evolution_id("pulse") == "", "published Daily ignores even manually restored evolution data")
	daily._queue_weapon_evolutions()
	check(daily.pending_build_choices.is_empty(), "Daily cannot gain new evolution hands")
	var world1 := Sim.new(912005)
	world1.upgrades.pulse = 5
	world1._queue_weapon_evolutions()
	check(world1.pending_build_choices.is_empty(), "original World 1 opening has no new evolution prompt")
	world1.stage = 2
	world1._queue_weapon_evolutions()
	check(world1.pending_build_choices.size() == 1, "World 1 rank 5 is offered at the next regular warp")
	var fuse := _sim(912006)
	fuse.active_slots = ["aegis", "nova"]
	fuse.upgrades.aegis = 5
	fuse.upgrades.nova = 5
	fuse._try_fuse()
	check(fuse.pending_build_choices.size() == 1 and "nova_aegis" not in fuse.active_slots, "rank-5 pair offers a fusion rather than silently consuming abilities")
	var saved: Dictionary = fuse.snapshot()
	var kept := Sim.new()
	check(kept.restore(saved) and kept.resolve_build_choice("keep"), "Keep both is a valid saved choice")
	check(kept.active_slots == ["aegis", "nova"] and "nova_aegis" in kept.fusion_declined, "Keeping preserves both abilities and records one-time decline")
	kept._try_fuse()
	check(kept.pending_build_choices.is_empty(), "Declined fusion is not offered again")
	var fused := Sim.new()
	check(fused.restore(saved) and fused.resolve_build_choice("fuse"), "Fusion choice can really be accepted")
	check("nova_aegis" in fused.active_slots and fused.active_slots.size() == 1, "Fusion actually frees a combat button")
	check(fused.snapshot() != saved, "Fusion decision survives as distinct saved loadout")
	var old_daily := _sim(912007)
	old_daily.daily_day = "2026-11-18"
	old_daily.active_slots = ["aegis", "nova"]
	old_daily.upgrades.aegis = 5
	old_daily.upgrades.nova = 5
	old_daily._try_fuse()
	check("nova_aegis" in old_daily.active_slots and old_daily.pending_build_choices.is_empty(), "Daily retains original automatic fusion")
	var duel := _sim(912008, "pulse", "duelist")
	var duel_e: Dictionary = _enemy(duel)
	var d0: float = duel_e.hp
	duel._damage_enemy(duel_e, 20.0, "pulse")
	var first: float = d0 - duel_e.hp
	d0 = duel_e.hp
	duel._damage_enemy(duel_e, 20.0, "pulse")
	check(d0 - duel_e.hp > first, "Duelist ramps damage on real consecutive Pulse hits")
	var spot := _sim(912009, "pulse", "spotter")
	var spot_e: Dictionary = _enemy(spot)
	spot._damage_enemy(spot_e, 20.0, "pulse")
	check(float(spot_e.get("evo_spotter_until", 0.0)) > spot.time, "Spotter marks with real Pulse hit")
	spot._damage_enemy(spot_e, 20.0, "seeker")
	check(float(spot.damage_dealt.get("seeker", 0.0)) > 20.0 and float(spot_e.get("evo_spotter_until", 0.0)) < spot.time, "A different weapon consumes the Spotter mark exactly once")
	var breacher := _sim(912010, "seeker", "breacher")
	var breach_e: Dictionary = _enemy(breacher, true)
	breacher._damage_enemy(breach_e, 20.0, "seeker")
	check(float(breacher.damage_dealt.get("seeker", 0.0)) > 20.0, "Breacher specializes in elites/bosses")
	var interceptor := _sim(912011, "seeker", "interceptor")
	var int_e: Dictionary = _enemy(interceptor, true)
	interceptor.charges = [{"source":int(int_e.id), "x":260.0, "remaining":0.5, "duration":1.4, "damage":22.0}]
	interceptor._damage_enemy(int_e, 20.0, "seeker")
	check(interceptor.charges.is_empty() and interceptor.beams_cancelled == 1, "Interceptor cancels a genuine targeted heavy charge")
	var conductor := _sim(912012, "arc", "conductor")
	var con_e: Dictionary = _enemy(conductor)
	conductor._damage_enemy(con_e, 20.0, "arc")
	conductor._damage_enemy(con_e, 20.0, "pulse")
	check(float(conductor.damage_dealt.get("pulse", 0.0)) > 20.0, "Conductor converts an Arc tag into real cross-weapon power")
	var tempest := _sim(912013, "arc", "tempest")
	var tempest_e: Dictionary = _enemy(tempest)
	tempest._damage_enemy(tempest_e, 20.0, "arc")
	check(float(tempest.damage_dealt.get("arc", 0.0)) > 20.0, "Tempest favors normal swarms rather than bosses")
	var exe := _sim(912014, "lance", "executioner")
	var exe_e: Dictionary = _enemy(exe, true)
	d0 = exe_e.hp
	exe._damage_enemy(exe_e, 20.0, "lance")
	first = d0 - exe_e.hp
	d0 = exe_e.hp
	exe._damage_enemy(exe_e, 20.0, "lance")
	check(d0 - exe_e.hp > first, "Executioner focuses on a priority enemy")
	var life := _sim(912015, "lance", "lifeline")
	var life_e: Dictionary = _enemy(life)
	life.shield -= 30.0
	d0 = life.shield
	life._damage_enemy(life_e, 30.0, "lance")
	check(life.shield > d0 and float(life.damage_dealt.get("lance",0.0)) < 30.0, "Lifeline exchanges direct damage for bounded shield restoration")
	var held: float = life.shield
	life._damage_enemy(life_e, 30.0, "lance")
	check(is_equal_approx(life.shield, held), "Lifeline repairs only once per weapon firing tick")
	var draft := _sim(912016)
	draft.upgrades.arc = 5
	check(draft._engine_relevance_score("autoloader") > 0 and not draft.engine_hint_for_pick("autoloader").is_empty(), "Build helper recognizes a real Arc partner")
	draft.level = 7
	draft._offer_cards(false)
	check(draft.cards.any(func(c): return draft._engine_relevance_score(str(c.id)) > 0), "Build-aware hand contains a relevant engine choice on an eligible level")
	var draft_state: Dictionary = draft.snapshot()
	var draft_clone := Sim.new()
	check(draft_clone.restore(draft_state) and draft_clone.cards == draft.cards and draft_clone.rng.state == draft.rng.state, "Offer hands and RNG state survive checkpoint exactly")
	draft.banished.append("autoloader")
	draft._offer_cards(false)
	check(not draft.cards.any(func(c): return str(c.id) == "autoloader"), "Build-aware offers respect a banished partner")
	var random_daily := _sim(912017)
	random_daily.daily_day = "2026-11-18"
	check(random_daily._engine_relevance_score("autoloader") == 0 and random_daily.engine_hint_for_pick("autoloader").is_empty(), "Daily uses the original unbiased draft policy")
	var no_cast := _sim(912018)
	no_cast.upgrades.pulse = 5
	no_cast.weapon_evolutions.pulse = "duelist"
	var ship_target: Dictionary = _enemy(no_cast)
	for i in range(6):
		no_cast._damage_enemy(ship_target, 20.0, "pulse")
	check(no_cast.ability_uses == 0 and ship_target.hp < ship_target.max_hp, "Specialization has real payoff without any manual ability cast")
	print("BUILD_OVERHAUL_RESULT %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
