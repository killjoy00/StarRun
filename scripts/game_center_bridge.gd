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
# Items that failed during the current pass are skipped so one bad request
# (a network error, or an identifier Apple rejects) cannot block the rest
# of the queue. An explicit sync() starts a fresh pass and retries them.
var _skipped: Dictionary = {}
var _request_age := 0.0
var _retry_clock := 0.0
const REQUEST_TIMEOUT := 30.0 # A native callback that never arrives counts as a failure.
const RETRY_INTERVAL := 120.0 # Signed-in sessions retry failed items in the background.
# Tests can inject a UTC day without changing the production system clock.
var utc_day_override := ""

func initialize(player_profile: Dictionary, save_profile: Callable) -> void:
	profile = player_profile
	save_callback = save_profile
	if not profile.get("game_center_synced", {}) is Dictionary:
		profile.game_center_synced = {}
	if not profile.has("game_center_synced"):
		profile.game_center_synced = {}
	if Engine.has_singleton("GameCenterKit"):
		_bind_service(Engine.get_singleton("GameCenterKit"))

func _bind_service(client: Object) -> void:
	service = client
	service.authenticated.connect(_on_auth)
	service.score_submitted.connect(_on_score)
	service.achievement_reported.connect(_on_achievement)
	service.panel_failed.connect(_on_panel_failed)
	service.set_access_point_visible(false) # Menus own the navigation.
	service.authenticate()

func attach_test_service(client: Object) -> void:
	# Test seam only; production always obtains the iOS singleton above.
	_bind_service(client)

func _today() -> String:
	return utc_day_override if not utc_day_override.is_empty() else Progress.utc_day()

func _cloud_achievement(id: String) -> bool:
	for achievement in Progress.ACHIEVEMENTS:
		if str(achievement.id) == id:
			return not bool(achievement.get("local_only", false))
	return false

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
	if not ok:
		# A logout while a native request is pending must not permanently
		# wedge synchronization. Ignore any late acknowledgements afterward.
		busy = false
		request_id = ""
		request_score = -1
	state_changed.emit()
	if ok:
		sync()

func sync() -> void:
	if not available() or busy:
		return
	_skipped.clear()
	_retry_clock = 0.0
	_advance()

## Call every frame. Times out a lost native callback and retries failures.
func update(delta: float) -> void:
	if not available():
		return
	if busy:
		_request_age += delta
		if _request_age >= REQUEST_TIMEOUT:
			_fail_request("Game Center did not respond")
	elif not _skipped.is_empty():
		_retry_clock += delta
		if _retry_clock >= RETRY_INTERVAL:
			sync()

func _begin_request(id: String, score: int) -> void:
	busy = true
	request_id = id
	request_score = score
	_request_age = 0.0

func _fail_request(error: String) -> void:
	last_error = error
	_skipped[request_id] = true
	busy = false
	request_id = ""
	request_score = -1
	state_changed.emit()
	_advance()

func _advance() -> void:
	if not available() or busy:
		return
	# Never post a stale suspended Daily into the next day's recurring board.
	# Current UTC is authoritative. Keep older results in local history only.
	var day := _today()
	var records: Dictionary = profile.get("daily_records",{})
	var record: Dictionary = records.get(day,{})
	var score: int = int(record.get("best_score",-1))
	var synced: Dictionary = profile.get("game_center_synced",{})
	if score >= 0 and score > int(synced.get("score_"+day,-1)) and not _skipped.has("score_"+day):
		_begin_request("score_"+day, score)
		service.submit_score(BOARD,score)
		return
	var awards: Dictionary = profile.get("achievements",{})
	for key in awards:
		var id: String = str(key)
		# Secret/local-only milestones have no Apple resource. Never let a
		# permanently failing unknown identifier block later real awards.
		if not _cloud_achievement(id):
			continue
		var ack := "achievement_"+id
		if not bool(synced.get(ack,false)) and not _skipped.has(ack):
			_begin_request(ack, -1)
			service.report_achievement("com.rsm.starrun."+id,100.0)
			return
	state_changed.emit()

func _on_score(ok: bool, leaderboard: String, error: String) -> void:
	if not busy or not request_id.begins_with("score_") or leaderboard != BOARD:
		return # Duplicate, unrelated or late native callbacks cannot erase an active request.
	if not ok:
		# Stays unsynced; skip it for this pass and continue with the rest.
		_fail_request(error)
		return
	var synced: Dictionary = profile.game_center_synced
	synced[request_id] = maxi(int(synced.get(request_id,-1)),request_score)
	last_error = ""
	_save()
	busy = false
	request_id = ""
	request_score = -1
	state_changed.emit()
	_advance()

func _on_achievement(ok: bool, achievement_id: String, error: String) -> void:
	var expected: String = "com.rsm.starrun." + request_id.trim_prefix("achievement_")
	if not busy or not request_id.begins_with("achievement_") or achievement_id != expected:
		return # A stale award callback must not release another pending request.
	if not ok:
		_fail_request(error)
		return
	profile.game_center_synced[request_id] = true
	last_error = ""
	_save()
	busy = false
	request_id = ""
	request_score = -1
	state_changed.emit()
	_advance()

func _on_panel_failed(_panel: String, error: String) -> void:
	last_error = error
	state_changed.emit()

func _save() -> void:
	if save_callback.is_valid():
		save_callback.call()
