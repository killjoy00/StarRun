extends Node
## Original, pre-rendered stereo score and effects; presentation observes simulation only.
const Catalog = preload("res://scripts/catalog.gd")
const CUE_GROUPS := {
	"aegis":"shield", "deflector":"shield", "barrier":"shield", "capacitor":"shield", "mend":"shield",
	"barrage":"missile", "strike":"missile", "prism":"energy", "focus":"energy", "siphon":"energy",
	"flak":"mine", "ion_mine":"mine", "wing_drones":"drone", "guard_drones":"drone", "decoy":"drone",
	"emp":"pulse", "jammer":"pulse", "nova":"pulse", "overload":"pulse",
	"overdrive":"engine", "chrono":"energy", "reboot":"engine", "salvage":"drone"
}
var enabled := true
var music_enabled := true
var players: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var cruise: AudioStreamPlayer
var boss: AudioStreamPlayer
var engine: AudioStreamPlayer
var archive: AudioStreamPlayer
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
	for id in Catalog.ABILITIES:
		if not sounds.has(id):
			sounds[id] = _synthesize_cue(id, false)
		if not sounds.has("ready-" + id):
			sounds["ready-" + id] = _synthesize_cue(id, true)
	sounds["archive-signal"] = _archive_tone([330.0, 440.0, 660.0], 0.92)
	sounds["archive-boss"] = _archive_tone([164.8, 174.6, 110.0], 0.69)
	sounds["archive-release"] = _archive_tone([220.0, 329.6, 440.0, 659.3], 1.45)
	sounds["archive-phase-0"] = _archive_tone([164.8,220.0],0.46)
	sounds["archive-phase-1"] = _archive_tone([220.0,329.6,196.0],0.56)
	sounds["archive-phase-2"] = _archive_tone([110.0,138.6,82.4],0.62)
	sounds["archive-counter-ready"] = _archive_tone([440.0,660.0],0.22)
	sounds["custodian-unlock"] = _archive_tone([261.6,392.0,523.2,784.0],0.94)
	sounds["custodian-shield"] = _archive_tone([392.0,523.2],0.24)
	archive = AudioStreamPlayer.new()
	archive.stream = _archive_tone([55.0, 82.4, 110.0, 164.8], 8.0, true)
	archive.volume_db = -80.0
	add_child(archive)
	if DisplayServer.get_name() != "headless":
		archive.play()
	cruise = _loop("score-cruise")
	boss = _loop("score-boss")
	engine = _loop("engine")

func _archive_tone(notes: Array, length: float, loop: bool = false) -> AudioStreamWAV:
	const RATE := 24000
	var pcm := PackedByteArray()
	pcm.resize(roundi(length * RATE) * 2)
	for i in range(pcm.size() / 2):
		var t := float(i) / RATE
		var mix := 0.0
		for n in range(notes.size()):
			var age := t - n * length * 0.14
			var f: float = notes[n]
			if loop:
				var swell := 0.25 + 0.18 * cos(TAU * (t / length + n * 0.23))
				mix += swell * (sin(TAU * roundf(f * length) * t / length) + 0.22 * sin(TAU * roundf(f * 2 * length) * t / length))
			elif age > 0.0:
				var envelope := minf(1.0, age * 75.0) * exp(-age * 5.0) * minf(1.0, (length - t) * 24.0)
				mix += envelope * (sin(TAU * f * age) + 0.19 * sin(TAU * f * 3.0 * age))
		pcm.encode_s16(i * 2, clampi(roundi(mix * 9000), -32767, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = pcm
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = pcm.size() / 2
	return stream

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

## Separate cast and ready cues per active, grouped into recognizable timbres.
## Runtime synthesis avoids loading dozens of large WAV files on phones.
func _synthesize_cue(id: String, ready: bool) -> AudioStreamWAV:
	var kind: String = str(CUE_GROUPS.get(id, "fusion"))
	var seed_value := absi(id.hash() % 233)
	var rate := 24000
	var length := 0.19 if ready else (0.48 if kind in ["shield", "fusion"] else 0.34)
	var samples := int(rate * length)
	var pcm := PackedByteArray()
	pcm.resize(samples * 2)
	var base := 260.0 + float(seed_value) * 1.4
	match kind:
		"shield": base = 190.0 + float(seed_value) * 0.5
		"missile": base = 120.0 + float(seed_value) * 0.4
		"mine": base = 95.0 + float(seed_value) * 0.2
		"drone": base = 600.0 + float(seed_value) * 0.8
		"pulse": base = 285.0 + float(seed_value) * 0.7
		"engine": base = 145.0 + float(seed_value) * 0.5
		"fusion": base = 420.0 + float(seed_value) * 0.5
	for i in range(samples):
		var t := float(i) / float(rate)
		var phase := t / length
		var gain := minf(1.0, t * 170.0) * pow(1.0 - phase, 1.65)
		var sweep := -0.52 if kind in ["mine", "missile", "engine"] else 0.28
		var pitch := base * (1.0 + sweep * phase)
		var note := sin(TAU * (base * t + base * sweep * t * t / (2.0 * length)))
		if kind == "drone":
			note = sin(TAU * (base * t + 24.0 * t * t)) * (0.3 + 0.7 * absf(sin(TAU * 10.0 * t)))
		elif kind == "mine":
			note = sin(TAU * pitch * t) * (0.35 + 0.65 * absf(sin(TAU * 7.0 * t)))
		elif kind == "shield":
			note = 0.60 * note + 0.40 * sin(TAU * base * 1.5 * t)
		elif kind == "fusion":
			note = 0.5 * note + 0.3 * sin(TAU * pitch * 1.5 * t) + 0.2 * sin(TAU * pitch * 2.0 * t)
		else:
			note = 0.75 * note + 0.25 * sin(TAU * (base * 2.0) * t)
		if ready:
			var pulse := 1.0 if t < 0.07 or (t > 0.10 and t < 0.17) else 0.0
			gain *= pulse * 0.50
		pcm.encode_s16(i * 2, clampi(roundi(note * gain * 21500.0), -32767, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = pcm
	return stream

func play_ability(id: String) -> void:
	if not sounds.has(id):
		sounds[id] = _synthesize_cue(id, false)
	if not sounds.has("ready-" + id):
		sounds["ready-" + id] = _synthesize_cue(id, true)
	play(id, -8.0)

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
	var flying := mode in ["playing", "stage_clear", "warp"]
	var intense: bool = sim.boss_spawned
	var ducked: bool = not sim.charges.is_empty()
	var music_gain := (-23.0 if ducked else -17.0) if flying else -28.0
	var fade := 1.0 - exp(-delta * 3.5)
	var in_archive: bool = sim.secret_entered and mode not in ["menu", "hangar", "loadout", "achievements", "briefing"]
	archive.volume_db = lerpf(archive.volume_db, music_gain - (1 if intense else 4) if music_enabled and in_archive else -80.0, fade)
	cruise.volume_db = lerpf(cruise.volume_db, music_gain if music_enabled and not intense and not in_archive else -80.0, fade)
	boss.volume_db = lerpf(boss.volume_db, music_gain if music_enabled and intense and not in_archive else -80.0, fade)
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
	for player in players + [cruise, boss, engine, archive]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	players.clear()
	sounds.clear()
