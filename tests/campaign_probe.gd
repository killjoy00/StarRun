extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/catalog.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	for profile in ["mid", "full"]:
		for seed in [2503,7907]:
			var meta := Catalog.defaults()
			for entry in Catalog.HANGAR: meta[entry.id] = int(entry.max) if profile == "full" else int(entry.max) / 2
			var sim := Sim.new(seed, meta)
			for frame in range(60 * 1500):
				if sim.stage_transition_queued:
					print("CAMPAIGN_CLEAR ", JSON.stringify({"stage":sim.stage,"seconds":sim.time-sim.stage_start,"seed":seed,"hangar":profile,"level":sim.level,"hull":sim.hull}))
					if sim.stage < 4:
						sim.begin_intermission()
						sim.choose_prototype(0)
						sim.choose_route("repair")
					sim.advance_stage()
				_bot(sim, "timed")
				sim.step()
				sim.effects.clear()
				if sim.ended: break
			print("CAMPAIGN_RESULT ", JSON.stringify({"stage":sim.stage,"cleared":sim.stage_clears,"won":sim.won,"seconds":sim.time,"seed":seed,"hangar":profile,"level":sim.level,"hull":sim.hull}))
	quit()
func _bot(sim: RefCounted, strategy: String) -> void:
	if not sim.cards.is_empty():
		var priorities := ["seeker", "pulse", "arc", "lance", "boss_hunter", "shield_focus", "afterburn", "regen", "hull", "armor", "munitions", "autoloader", "coolant", "shield", "targeting", "repair_bots", "field_medic", "ablative", "shield_surge", "harvester", "amplifier", "nova", "aegis", "barrage", "overdrive", "chrono", "mend", "repair"]
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
		if sim.boss_spawned or sim._crowd_count() >= 3:
			sim.activate("railstorm")
			sim.activate("missile_grid")
			sim.activate("prism_focus")
		if sim.hull < sim.max_hull - 30 or sim.shield < sim.max_shield - 30:
			sim.activate("repair_matrix")
		if sim.hull < sim.max_hull - 20 and sim._crowd_count() > 0:
			sim.activate("scrap_converter")
		if sim.bullets.size() >= 15:
			sim.activate("reflective_wall")
			sim.activate("reactor_surge")
		if sim._crowd_count() >= 3 or sim.boss_spawned:
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
		elif sim._crowd_count() >= 3 and sim.charges.is_empty():
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
		if sim._crowd_count() >= 3:
			sim.activate("focus")
			sim.activate("jammer")
			sim.activate("strike")


