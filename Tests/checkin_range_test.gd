extends Node

## checkin_range_test.gd
##
## Exercises the ChoresManager random check-in scheduling:
##   1. _schedule_checkin() roll targets always fall within 2-7 (zone-1 max;
##      no game_controller in this test, so the fallback applies).
##   2. get_checkin_max() falls back to 7 without a zone.
##   3. The mom_checkin signal fires exactly once when the roll target is hit.
##
## Scene-based test (autoloads must be compiled first).
## Run headless:
##   godot --headless --path . Tests/CheckinRangeTest.tscn -- --quit-after
## Exit code 0 = all checks passed, 1 = at least one failure.

const ChoresManagerScript := preload("res://Scripts/Managers/ChoresManager.gd")

const ITERATIONS: int = 500

var _failures: int = 0
var _checkin_signals: int = 0


func _ready() -> void:
	print("[CheckinRangeTest] Starting")
	var cm = ChoresManagerScript.new()
	add_child(cm)
	cm.mom_checkin.connect(_on_mom_checkin)

	_test_target_range(cm)
	_test_trigger_fires_once(cm)

	if _failures == 0:
		print("[CheckinRangeTest] PASS - all checks passed")
	else:
		print("[CheckinRangeTest] FAIL - %d check(s) failed" % _failures)

	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(0 if _failures == 0 else 1)


func _on_mom_checkin() -> void:
	_checkin_signals += 1


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[CheckinRangeTest] OK: " + label)
	else:
		push_error("[CheckinRangeTest] FAILED: " + label)
		_failures += 1


func _test_target_range(cm) -> void:
	_check("get_checkin_max() falls back to zone-1 max without a zone",
		cm.get_checkin_max() == 7)
	var lowest: int = 7
	var highest: int = ChoresManagerScript.CHECKIN_TARGET_MIN
	var in_range := true
	for i in range(ITERATIONS):
		cm._schedule_checkin()
		var target: int = cm._checkin_roll_target
		if target < ChoresManagerScript.CHECKIN_TARGET_MIN or target > 7:
			in_range = false
		lowest = mini(lowest, target)
		highest = maxi(highest, target)
	_check("%d scheduled targets all within %d-%d" % [ITERATIONS, ChoresManagerScript.CHECKIN_TARGET_MIN, 7], in_range)
	_check("targets spread across the range (min %d, max %d)" % [lowest, highest],
		lowest <= 3 and highest >= 6)


func _test_trigger_fires_once(cm) -> void:
	_checkin_signals = 0
	cm._rolls_this_round = 0
	cm._checkin_done_this_round = false
	cm._checkin_roll_target = 2
	cm.increment_progress(1)
	_check("no check-in before the target roll", _checkin_signals == 0 and not cm._checkin_done_this_round)
	cm.increment_progress(1)
	_check("check-in fires at the target roll", _checkin_signals == 1)
	_check("flag set after the signal", cm._checkin_done_this_round)
	cm.increment_progress(1)
	cm.increment_progress(1)
	_check("check-in does not fire twice in one round", _checkin_signals == 1)
