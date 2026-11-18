extends RefCounted
## Separate from the authored four-world catalog so Daily and Endless keep their routes.
const WORLD := 5
const REQUIRED_SIGNALS := 2
const BOSS_AT := 105.0
const BOSS := "boss_warden"
const ATTACKS := ["lock", "lattice", "collapse"]
const PHASE_FLOORS := [0.68, 0.34, 0.07]
# The original high-Hangar Custodian collapsed in 4–15 seconds. Three real
# counterplay cycles now require surviving distinct attack patterns instead
# of instantly burning from one health threshold to the next.
const PHASE_REARM_SECONDS := 16.0
const SEALED_DAMAGE_FACTOR := 0.18
const COUNTER_EXPOSURE_SECONDS := 4.2
const UNANSWERED_EXPOSURE_SECONDS := 1.8
const VOLLEY_INTERVALS := [2.60, 2.20, 1.85]
const VOLLEY_COUNTS := [5, 6, 7]
const VOLLEY_DAMAGE := 4.5
const LATTICE_PROJECTILES_PER_SIDE := 15
const COLLAPSE_PROJECTILES_PER_SIDE := 9
const ATTACK_PROJECTILE_DAMAGE := 6.0
const LOCK_BEAM_DAMAGE := 66.0
const COLLAPSE_BEAM_DAMAGE := 82.0
const COLOR := Color("f2d49b")
const MINT := Color("90ffe0")
const SPEC := {
	"id":"silent_archive", "name":"SILENT ARCHIVE", "subtitle":"The station beyond the Citadel",
	"description":"Relay patrols, converging fire and a station that reacts to your abilities.",
	"boss":BOSS, "boss_name":"The Last Custodian", "boss_hp":480000.0,
	"health_scale":20.0, "spawn_scale":1.62, "fire_scale":1.10, "reward_label":"The signal is free"
}
const ENEMIES := {
	"archive_relay":{"hp":175.0, "speed":31.0, "xp":0, "interval":5.8},
	"archive_shard":{"hp":102.0, "speed":56.0, "xp":0, "interval":4.0},
	"archive_courier":{"hp":240.0, "speed":26.0, "xp":0, "interval":5.4}
}
const SIGNALS := ["WRECK TRANSMISSION", "UNLISTED DISTRESS CALL", "RETURNING ECHO"]

static func signal_time(seed_value: int, world: int) -> float:
	return 40.0 + float(posmod(seed_value + world * 29, 39))

static func signal_name(seed_value: int, world: int) -> String:
	return SIGNALS[posmod(seed_value + world, SIGNALS.size())]
