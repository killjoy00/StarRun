extends "res://tests/run.gd"
## Fast regression for test fixtures that must traverse real boss objectives.
## The full test/run.gd suite still runs as the required Playable CI gate.

func _run() -> void:
	_test_stage_rerolls_and_shield_breaks()
	_test_four_stage_campaign()
	_test_prototype_and_route_choices()
	_test_route_prototype_balance_grid()
	print("BOSS_WARP_FIXTURES: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
