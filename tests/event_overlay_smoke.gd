extends SceneTree
## Native-sized UI regression for overlapping modal choices and persisted
## Quartermaster receipts. No real iPhone/Apple SDK claims.
const Sim = preload("res://scripts/simulation.gd")
class MemoryServices extends "res://scripts/platform_services.gd":
	var values: Dictionary = {}
	func write_atomic(path: String, value: Dictionary) -> bool:
		values[path] = value.duplicate(true)
		return true
	func read_save(path: String) -> Dictionary:
		return values.get(path, {}).duplicate(true)
	func delete_run() -> void:
		values.erase(RUN)

var checks := 0
var failures := 0
func _initialize() -> void:
	create_timer(20.0).timeout.connect(func(): push_error("EVENT_OVERLAY: timed out"); quit(1))
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("EVENT_OVERLAY: " + message)

func _run() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.services = MemoryServices.new()
	root.add_child(scene)
	scene.set_process(false)
	scene.world.set_process(false)
	scene.sound.enabled = false
	scene.sound.music_enabled = false
	await process_frame
	for width in [360, 390]:
		root.size = Vector2i(width, 844)
		await process_frame
		scene._layout()
		var sim := Sim.new(51100 + width)
		sim.enable_merchant()
		sim.stage = 2
		sim.time = 82.0
		sim.merchant_next_at = 78.0
		check(sim._try_merchant_signal(), "Merchant encounter starts from a legitimate seeded hail")
		scene.sim = sim
		scene._show_merchant_signal()
		check(scene.mode == "merchant_signal", "Merchant hail occupies its own modal screen")
		# A coordinate signal arriving during a merchant conversation must
		# remain pending rather than being erased by the receipt/restart.
		sim.signal_status = "offer"
		sim.signal_until = sim.time + 52.0
		scene._merchant_hail()
		check(scene.mode == "merchant_shop", "Hailing opens the actual offers")
		scene._merchant_preview("sell_hull")
		check(scene.mode == "merchant_confirm" and sim.merchant_trade_count == 0,
			"Trade preview cannot charge money or mutate hull")
		scene._save_run()
		scene._resume_run()
		check(scene.mode == "merchant_confirm" and scene.sim.merchant_trade_count == 0
			and scene.sim.signal_status == "offer", "Restart at confirmation restores exact trade and pending signal")
		var initial_hull: float = scene.sim.max_hull
		scene._merchant_accept()
		check(scene.mode == "merchant_receipt" and scene.sim.merchant_state == "receipt"
			and scene.sim.merchant_trade_count == 1 and scene.sim.max_hull < initial_hull,
			"Accepted trade charges once and enters a persistable receipt")
		var paid_hull: float = scene.sim.max_hull
		var saved: Dictionary = scene.services.read_save(scene.Services.RUN)
		check(str(saved.get("merchant_state", "")) == "receipt",
			"Receipt is on disk before the user can dismiss or background the app")
		scene._resume_run()
		check(scene.mode == "merchant_receipt" and scene.sim.merchant_state == "receipt"
			and scene.sim.merchant_trade_count == 1 and is_equal_approx(scene.sim.max_hull, paid_hull),
			"Restart after purchase displays the receipt without a second charge")
		scene._merchant_resume()
		check(scene.mode == "archive_signal" and scene.sim.merchant_state.is_empty()
			and scene.sim.signal_status == "offer",
			"Closing saved receipt surfaces the still-pending Archive choice rather than losing it")
		scene._choose_signal("courier")
		check(scene.mode == "playing" and scene.sim.signal_status == "courier"
			and scene.sim.enemies.any(func(e): return e.kind == "archive_courier"),
			"Archive choice follows the Quartermaster without losing the courier")
		var last_trade: int = scene.sim.merchant_trade_count
		scene._save_run()
		scene._resume_run()
		check(scene.sim.merchant_trade_count == last_trade and scene.sim.signal_status == "courier"
			and scene.mode == "playing", "Restart preserves ongoing courier chase and no duplicate market trade")
	# An expired or superseded offer must not trap a resumed flight in a
	# modal whose choose_signal() action would now be rejected.
	var cleared := Sim.new(61829)
	cleared.stage = 2
	cleared.stage_clears = 2
	cleared.stage_transition_queued = true
	cleared.signal_status = "offer"
	cleared.signal_until = cleared.time + 40.0
	scene.sim = cleared
	scene._start_flight()
	check(scene.mode == "stage_clear", "A completed boss takes precedence over a stale, now-unselectable coordinate offer")
	var expired := Sim.new(61830)
	expired.stage = 2
	expired.signal_status = "offer"
	expired.signal_until = expired.time - 1.0
	scene.sim = expired
	scene._start_flight()
	check(scene.mode == "playing", "An expired coordinate offer cannot open an unanswerable modal on restart")
	scene.queue_free()
	await process_frame
	print("EVENT_OVERLAY_RESULT %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
