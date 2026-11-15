extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/catalog.gd")
# Fixed, progressively stronger loadouts isolate the world curve from draft luck.
const RANKS := {
	2:{"pulse":5,"seeker":5,"arc":3,"lance":2,"munitions":4,"autoloader":4,"targeting":2,"hull":4,"shield":3,"armor":4,"regen":3,"coolant":3,"amplifier":2,"repair_bots":2,"aegis":3,"nova":3,"mend":2,"capacitor":2},
	3:{"pulse":8,"seeker":8,"arc":6,"lance":5,"munitions":7,"autoloader":6,"targeting":5,"hull":6,"shield":6,"armor":6,"regen":5,"coolant":5,"amplifier":4,"repair_bots":4,"aegis":5,"nova":5,"mend":4,"capacitor":4},
	4:{"pulse":10,"seeker":10,"arc":10,"lance":8,"munitions":10,"autoloader":10,"targeting":8,"hull":10,"shield":8,"armor":10,"regen":8,"coolant":8,"amplifier":7,"repair_bots":7,"aegis":8,"nova":8,"mend":7,"capacitor":7}}
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var rows: Array = []
	var idle: bool = "--idle" in OS.get_cmdline_user_args()
	var late: bool = "--late-passives" in OS.get_cmdline_user_args()
	var seeds := [2503] if "--quick" in OS.get_cmdline_user_args() else [2503, 7907]
	for stage in [2,3,4]:
		for profile in ["mid", "full"]:
			for seed in seeds:
				var meta := Catalog.defaults()
				for entry in Catalog.HANGAR:
					meta[entry.id] = int(entry.max) if profile == "full" else int(entry.max) / 2
				var sim := Sim.new(seed, meta)
				for id in RANKS[stage]:
					sim.upgrades[id] = RANKS[stage][id]
				# Include actual capacity gains from these ranks; no injected invulnerability.
				sim.max_hull += 18 * sim.upgrades.hull + (25 if stage >= 3 else 0) + (50 if stage == 4 else 0)
				sim.max_shield += 10 * sim.upgrades.shield + (18 if stage >= 3 else 0)
				sim.hull = sim.max_hull
				sim.shield = sim.max_shield
				sim.active_slots = ["aegis","nova","mend","capacitor"]
				sim._try_fuse()
				sim.stage = stage
				if late:
					for id in ["boss_hunter", "finisher", "opening_salvo", "ablative", "insulation", "shield_surge", "field_medic", "last_stand", "shield_focus", "afterburn"]:
						sim.upgrades[id] = (stage - 1) * 2
				var lowest_hull := 1.0
				var max_bullets := 0
				# 90 seconds of waves, then the real boss; leave 120 seconds to defeat it.
				sim.content.boss_at = 90
				for frame in range(60 * 210):
					if not sim.cards.is_empty():
						sim.cards.clear() # Hold the measured loadout fixed during this isolated probe.
						sim.pending_levels = 0
					if not idle and (not sim.charges.is_empty() or sim.bullets.size() > 18):
						sim.activate("nova_aegis")
						if "nova_aegis" not in sim.active_slots:
							sim.activate("aegis")
							sim.activate("nova")
					if not idle and (sim.hull < sim.max_hull - 30 or sim.shield < sim.max_shield * 0.5):
						sim.activate("repair_matrix")
						sim.activate("mend")
						sim.activate("capacitor")
					sim.step()
					sim.effects.clear()
					max_bullets = maxi(max_bullets, sim.bullets.size())
					lowest_hull = minf(lowest_hull, sim.hull / sim.max_hull)
					if sim.ended or sim.stage_transition_queued:
						break
				var damage := 0.0
				for amount in sim.damage_taken.values(): damage += amount
				var row := {"stage":stage,"strategy":"idle" if idle else "defensive", "late_passives":late,"lowest_hull":snappedf(lowest_hull,0.01),"hangar":profile,"seed":seed,"clear":sim.stage_transition_queued,"seconds":snappedf(sim.time,0.1),"hull_fraction":snappedf(sim.hull/sim.max_hull,0.01),"damage":snappedf(damage,0.1),"kills":sim.kills,"max_bullets":max_bullets}
				rows.append(row)
				print(JSON.stringify(row))
	print("SCALING_RESULT ",JSON.stringify(rows))
	quit()
