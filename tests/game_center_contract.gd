extends SceneTree
## Offline Game Center contract. The mock represents the exact native callback
## names; this does not claim Apple approval or physical-device acceptance.
const Bridge = preload("res://scripts/game_center_bridge.gd")
const Progress = preload("res://scripts/meta_progress.gd")

class FakeKit extends RefCounted:
	signal authenticated(ok: bool, error: String)
	signal score_submitted(ok: bool, leaderboard: String, error: String)
	signal achievement_reported(ok: bool, achievement_id: String, error: String)
	signal panel_failed(panel: String, error: String)
	var submits: Array = []
	var awards: Array = []
	var panels: Array = []
	var authenticated_called := 0
	func authenticate() -> void:
		authenticated_called += 1
	func set_access_point_visible(_visible: bool) -> void:
		pass
	func submit_score(board: String, score: int) -> void:
		submits.append({"board":board, "score":score})
	func report_achievement(id: String, percent: float) -> void:
		awards.append({"id":id, "percent":percent})
	func show_leaderboard(board: String) -> void:
		panels.append(board)
	func show_achievements() -> void:
		panels.append("achievements")

var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("GAME_CENTER_CONTRACT: " + message)

func _run() -> void:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_center.json"))
	check(manifest is Dictionary, "Apple resource manifest loads")
	if not manifest is Dictionary:
		quit(1)
		return
	check(str(manifest.app_bundle) == "com.rsm.starrun" and str(manifest.leaderboard.id) == Bridge.BOARD,
		"Native board and bundle identifiers agree with the Apple resources manifest")
	var expected: Dictionary = {}
	for achievement in Progress.ACHIEVEMENTS:
		if not bool(achievement.get("local_only", false)):
			expected[str(achievement.id)] = true
	var declared: Dictionary = {}
	for achievement in manifest.achievements:
		var id: String = str(achievement.id)
		check(expected.has(id) and not declared.has(id), "Apple manifest has one approved, non-local achievement for " + id)
		declared[id] = true
	check(declared.size() == expected.size(), "Every native achievement matches the provisioned manifest")
	check(not declared.has("open_frequency"), "The hidden local-only discovery must never be submitted to Apple")

	var profile := {"daily_records":{"2026-11-18":{"best_score":120}},
		"achievements":{"open_frequency":"2026-11-18", "daily_first":"2026-11-18"},
		"game_center_synced":[]}
	var saves := {"count":0}
	var bridge := Bridge.new()
	bridge.initialize(profile, func(): saves.count += 1)
	bridge.utc_day_override = "2026-11-18"
	check(not bridge.available() and not bridge.supports_game_center(), "No native plug-in leaves offline play usable")
	check(profile.game_center_synced is Dictionary, "Malformed old sync state is repaired")
	var client := FakeKit.new()
	bridge.attach_test_service(client)
	check(client.authenticated_called == 1 and not bridge.available(), "A native service must authenticate before leaderboard access")
	client.authenticated.emit(true, "")
	check(bridge.available() and bridge.busy and client.submits.size() == 1
		and client.submits[0].board == Bridge.BOARD and client.submits[0].score == 120,
		"Authentication submits only today's best Daily score")
	client.score_submitted.emit(true, "unrelated.board", "")
	client.achievement_reported.emit(true, "com.rsm.starrun.daily_first", "")
	check(bridge.busy and bridge.request_id == "score_2026-11-18" and saves.count == 0,
		"Unrelated score and out-of-order award callbacks cannot release the pending score")
	client.score_submitted.emit(false, Bridge.BOARD, "Network unavailable")
	check(bridge.last_error == "Network unavailable" and not profile.game_center_synced.has("score_2026-11-18")
		and bridge.busy and bridge.request_id == "achievement_daily_first" and client.awards.size() == 1,
		"A failed score persists no false success and no longer blocks the rest of the queue")
	client.achievement_reported.emit(true, "com.rsm.starrun.daily_first", "")
	check(not bridge.busy and bool(profile.game_center_synced.get("achievement_daily_first", false)) and client.submits.size() == 1,
		"The failed item is skipped for the rest of this pass instead of looping")
	bridge.sync()
	check(client.submits.size() == 2 and bridge.busy, "Later sync retries the still-unsent best score")
	client.score_submitted.emit(true, Bridge.BOARD, "")
	check(int(profile.game_center_synced.get("score_2026-11-18", -1)) == 120 and not bridge.busy and client.awards.size() == 1,
		"Successful retry is saved without re-reporting confirmed achievements")
	client.achievement_reported.emit(true, "com.rsm.starrun.open_frequency", "")
	client.score_submitted.emit(true, Bridge.BOARD, "")
	check(not bridge.busy and client.awards.size() == 1, "Local-only or duplicate responses are ignored")
	# One failing achievement must not block a later real one.
	profile.achievements["first_finish"] = "2026-11-18"
	profile.achievements["five_runs"] = "2026-11-18"
	bridge.sync()
	var first_id: String = str(client.awards[-1].id)
	check(bridge.busy and client.awards.size() == 2, "A new achievement uploads")
	client.achievement_reported.emit(false, first_id, "Unknown identifier")
	check(bridge.busy and client.awards.size() == 3 and str(client.awards[-1].id) != first_id,
		"A rejected achievement is skipped and the next one still uploads")
	client.achievement_reported.emit(true, str(client.awards[-1].id), "")
	check(not bridge.busy and not profile.game_center_synced.has("achievement_" + first_id.trim_prefix("com.rsm.starrun.")),
		"The rejected achievement stays retryable")
	# A native callback that never arrives cannot wedge the queue forever.
	bridge.sync()
	check(bridge.busy and client.awards.size() == 4 and str(client.awards[-1].id) == first_id, "Sync retries the rejected achievement")
	bridge.update(Bridge.REQUEST_TIMEOUT + 0.1)
	check(not bridge.busy and bridge.last_error == "Game Center did not respond", "A lost callback times out and releases the queue")
	client.achievement_reported.emit(true, first_id, "")
	check(not profile.game_center_synced.has("achievement_" + first_id.trim_prefix("com.rsm.starrun.")),
		"A callback that arrives after its timeout cannot falsely acknowledge")
	bridge.update(Bridge.RETRY_INTERVAL + 0.1)
	check(bridge.busy and client.awards.size() == 5, "Failed items retry in the background while signed in")
	client.achievement_reported.emit(true, first_id, "")
	check(not bridge.busy and bool(profile.game_center_synced.get("achievement_" + first_id.trim_prefix("com.rsm.starrun."), false)),
		"Background retry completes the award")
	bridge.sync()
	check(client.awards.size() == 5 and client.submits.size() == 2, "Duplicate sync is idempotent")
	check(bridge.show_leaderboard() and bridge.show_achievements() and client.panels.size() == 2,
		"Native Game Center menus use the correct board and achievement panel")

	bridge.utc_day_override = "2026-11-19"
	bridge.sync()
	check(client.submits.size() == 2, "Previous UTC day's local best is never submitted as today's score")
	profile.daily_records["2026-11-19"] = {"best_score":240}
	bridge.sync()
	check(bridge.busy and client.submits.size() == 3 and client.submits[-1].score == 240,
		"A new UTC date submits only that date's best")
	client.panel_failed.emit("leaderboard", "Offline")
	check(bridge.busy and bridge.request_id == "score_2026-11-19", "Panel failure does not interrupt a pending score")
	client.authenticated.emit(false, "Signed out")
	check(not bridge.busy and not bridge.available() and bridge.request_id.is_empty(),
		"Logout clears in-flight request without corrupting local score history")
	client.score_submitted.emit(true, Bridge.BOARD, "")
	check(not profile.game_center_synced.has("score_2026-11-19"),
		"A late callback after logout cannot falsely acknowledge the score")
	client.authenticated.emit(true, "")
	check(client.submits.size() == 4 and client.submits[-1].score == 240,
		"Reauthentication retries the current day's unsent best")
	client.score_submitted.emit(true, Bridge.BOARD, "")
	check(int(profile.game_center_synced.get("score_2026-11-19", -1)) == 240,
		"Acknowledgement records the correct UTC day, not the prior period")
	profile.daily_records["2026-11-19"] = {"best_score":360}
	bridge.sync()
	check(client.submits.size() == 5 and client.submits[-1].score == 360,
		"A better same-day replay updates the leaderboard instead of resending a lower best")
	client.score_submitted.emit(true, Bridge.BOARD, "")
	check(int(profile.game_center_synced.get("score_2026-11-19", -1)) == 360
		and saves.count >= 4, "Improved score is durably recorded")
	print("GAME_CENTER_CONTRACT_RESULT %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
