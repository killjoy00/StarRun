extends Node
## Original, pre-rendered stereo score and effects; presentation observes simulation only.
var enabled := true
var music_enabled := true
var players: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var cruise: AudioStreamPlayer
var boss: AudioStreamPlayer
var engine: AudioStreamPlayer
var previous_time := -1.0
var previous_pulse := 0.0
var previous_seeker := 0.0
var previous_kills := 0
var previous_hull := 100.0
var previous_shield := 50.0
var low_hull_timer := 0.0
var explosion_timer := 0.0
var last_mode := "menu"

func _ready() -> void:
	for i in range(14):
		var player := AudioStreamPlayer.new()
		add_child(player)
		players.append(player)
	for id in ["pulse", "seeker", "explosion", "boss-explosion", "ready-aegis", "ready-nova", "aegis", "nova", "hit", "shield-break", "card", "start", "warning", "low-hull", "victory", "defeat", "barrage", "overdrive", "chrono", "mend", "ready-barrage", "ready-overdrive", "ready-chrono", "ready-mend"]:
		sounds[id] = load("res://assets/audio/" + id + ".wav")
	cruise = _loop("score-cruise")
	boss = _loop("score-boss")
	engine = _loop("engine")

func _loop(id: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = load("res://assets/audio/" + id + ".ogg")
	if player.stream is AudioStreamOggVorbis:
		player.stream.loop = true
	player.volume_db = -80.0
	add_child(player)
	if DisplayServer.get_name() != "headless":
		player.play()
	return player

func play(id: String, gain_db: float = -10.0) -> void:
	if not enabled or not sounds.has(id) or DisplayServer.get_name() == "headless":
		return
	for player in players:
		if not player.playing:
			player.stream = sounds[id]
			player.volume_db = gain_db
			player.pitch_scale = randf_range(0.94, 1.06) if id in ["pulse", "seeker", "explosion", "hit"] else 1.0
			player.play()
			return

func update(sim: RefCounted, mode: String, delta: float) -> void:
	var flying := mode == "playing"
	var intense: bool = sim.boss_spawned
	var ducked: bool = not sim.charges.is_empty()
	var music_gain := (-23.0 if ducked else -17.0) if flying else -28.0
	var fade := 1.0 - exp(-delta * 3.5)
	cruise.volume_db = lerpf(cruise.volume_db, music_gain if music_enabled and not intense else -80.0, fade)
	boss.volume_db = lerpf(boss.volume_db, music_gain if music_enabled and intense else -80.0, fade)
	engine.volume_db = lerpf(engine.volume_db, -28.0 if flying and enabled else -80.0, fade)
	engine.pitch_scale = 0.95 + minf(sim.ship_velocity().length() / 150.0, 0.35)
	explosion_timer = maxf(0, explosion_timer - delta)
	low_hull_timer = maxf(0, low_hull_timer - delta)
	if sim.time < previous_time or previous_time < 0:
		previous_pulse = sim.pulse_timer
		previous_seeker = sim.seeker_timer
		previous_hull = sim.hull
		previous_shield = sim.shield
		previous_kills = sim.kills
	if flying and sim.time > previous_time:
		if sim.pulse_timer > previous_pulse + 0.02:
			play("pulse", -22.0)
		if sim.seeker_timer > previous_seeker + 0.02 and sim.shots.any(func(shot): return shot.weapon == "seeker" and shot.p.distance_to(sim.ship_position()) < 100):
			play("seeker", -22.0)
		if sim.kills > previous_kills and explosion_timer <= 0:
			play("boss-explosion" if sim.won else "explosion", -14.0)
			explosion_timer = 0.09
		if previous_shield > 0 and sim.shield <= 0:
			play("shield-break", -9.0)
		if sim.hull < sim.max_hull * 0.3 and low_hull_timer <= 0:
			play("low-hull", -10.0)
			low_hull_timer = 3.5
	if mode == "results" and last_mode != "results":
		play("victory" if sim.won else "defeat", -8.0)
	previous_time = sim.time
	previous_pulse = sim.pulse_timer
	previous_seeker = sim.seeker_timer
	previous_kills = sim.kills
	previous_hull = sim.hull
	previous_shield = sim.shield
	last_mode = mode

func _exit_tree() -> void:
	for player in players + [cruise, boss, engine]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	players.clear()
	sounds.clear()
