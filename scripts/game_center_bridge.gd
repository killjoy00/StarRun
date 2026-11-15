extends RefCounted
## Optional iOS Game Center bridge. The game and local progression remain fully
## functional with no native plug-in, no connection or no Game Center account.
## GameCenterKit v1.0.1 (pinned on the iOS export runner) supplies the singleton.
const Progress = preload("res://scripts/meta_progress.gd")
const BOARD := "com.rsm.starrun.daily"

signal state_changed

var service: Object
var signed_in := false
var busy := false
var request_id := ""
var request_score := -1
var last_error := ""
var profile: Dictionary
var save_callback: Callable

func initialize(player_profile: Dictionary, save_profile: Callable) -> void:
	profile = player_profile
	save_callback = save_profile
	if not profile.get("game_center_synced", {}) is Dictionary:
		profile.game_center_synced = {}
	if not profile.has("game_center_synced"):
		profile.game_center_synced = {}
	if not Engine.has_singleton("GameCenterKit"):
		return
	service = Engine.get_singleton("GameCenterKit")
	service.authenticated.connect(_on_auth)
	service.score_submitted.connect(_on_score)
	service.achievement_reported.connect(_on_achievement)
	service.panel_failed.connect(_on_panel_failed)
	service.set_access_point_visible(false) # Menus own the navigation.
	service.authenticate()

func available() -> bool:
	return service != null and signed_in

func supports_game_center() -> bool:
	return service != null

func show_leaderboard() -> bool:
	if not available():
		return false
	service.show_leaderboard(BOARD)
	return true

func show_achievements() -> bool:
	if not available():
		return false
	service.show_achievements()
	return true

func _on_auth(ok: bool, error: String) -> void:
	signed_in = ok
	last_error = "" if ok else error
	state_changed.emit()
	if ok:
		sync()

func sync() -> void:
	if not available() or busy:
		return
	# Never post a stale suspended Daily into the next day's recurring board.
	# Current UTC is authoritative. Keep older results in local history only.
	var day := Progress.utc_day()
	var records: Dictionary = profile.get("daily_records",{})
	var record: Dictionary = records.get(day,{})
	var score: int = int(record.get("best_score",-1))
	var synced: Dictionary = profile.get("game_center_synced",{})
	if score >= 0 and score > int(synced.get("score_"+day,-1)):
		busy = true
		request_id = "score_"+day
		request_score = score
		service.submit_score(BOARD,score)
		return
	var awards: Dictionary = profile.get("achievements",{})
	for key in awards:
		var id: String = str(key)
		var ack := "achievement_"+id
		if not bool(synced.get(ack,false)):
			busy = true
			request_id = ack
			request_score = -1
			service.report_achievement("com.rsm.starrun."+id,100.0)
			return
	state_changed.emit()

func _on_score(ok: bool, leaderboard: String, error: String) -> void:
	if request_id.begins_with("score_") and leaderboard == BOARD:
		if ok:
			var synced: Dictionary = profile.game_center_synced
			synced[request_id] = maxi(int(synced.get(request_id,-1)),request_score)
			_save()
		else:
			last_error = error
		busy = false
		request_id = ""
		request_score = -1
		state_changed.emit()
		# Do not spin on network errors; retry on next session or next result.
		if ok:
			sync()

func _on_achievement(ok: bool, achievement_id: String, error: String) -> void:
	var expected: String = "com.rsm.starrun." + request_id.trim_prefix("achievement_")
	if request_id.begins_with("achievement_") and achievement_id == expected:
		if ok:
			profile.game_center_synced[request_id] = true
			_save()
		else:
			last_error = error
		busy = false
		request_id = ""
		state_changed.emit()
		if ok:
			sync()

func _on_panel_failed(_panel: String, error: String) -> void:
	last_error = error
	state_changed.emit()

func _save() -> void:
	if save_callback.is_valid():
		save_callback.call()
