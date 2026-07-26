extends Node

## mom_checkin_test.gd
##
## Exercises the ChoresManager check-in, grudge, and escalation plumbing:
##   1. Check-in fires exactly once per round at the scheduled roll.
##   2. Check-in defers while a meter visit is active, fires after.
##   3. Grudge add/consume/decay behavior and grudge_changed signal.
##   4. Save/load round-trip preserves grudge and check-in state.
##
## Scene-based test (autoloads must be compiled before ChoresManager).
## Run headless:
##   godot --headless --path . Tests/MomCheckinTest.tscn -- --quit-after
## Exit code 0 = all checks passed, 1 = at least one failure.

const ChoresManagerScript := preload("res://Scripts/Managers/ChoresManager.gd")

var _failures: int = 0
var _checkin_count: int = 0
var _grudge_signals: Array[int] = []


func _ready() -> void:
	print("[MomCheckinTest] Starting")
	var cm = ChoresManagerScript.new()
	add_child(cm)
	cm.mom_checkin.connect(_on_checkin)
	cm.grudge_changed.connect(_on_grudge_changed)

	_test_checkin_once_per_round(cm)
	_test_checkin_deferred_while_mom_active(cm)
	_test_grudge(cm)
	_test_save_load_roundtrip(cm)

	if _failures == 0:
		print("[MomCheckinTest] PASS - all checks passed")
	else:
		print("[MomCheckinTest] FAIL - %d check(s) failed" % _failures)

	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(0 if _failures == 0 else 1)


func _on_checkin() -> void:
	_checkin_count += 1


func _on_grudge_changed(new_grudge: int) -> void:
	_grudge_signals.append(new_grudge)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[MomCheckinTest] OK: " + label)
	else:
		push_error("[MomCheckinTest] FAILED: " + label)
		_failures += 1


func _roll(cm, times: int) -> void:
	for i in range(times):
		cm.increment_progress()


func _test_checkin_once_per_round(cm) -> void:
	_checkin_count = 0
	var target: int = cm._checkin_roll_target
	_check("round 1 target in range 2-5", target >= 2 and target <= 5)

	# Roll past the target but stay well under the meter (1 progress/roll)
	_roll(cm, 8)
	_check("check-in fired exactly once in round 1", _checkin_count == 1)
	_check("check-in fired at scheduled roll", cm._checkin_done_this_round)

	# Extra rolls must not re-fire
	_roll(cm, 4)
	_check("no second check-in in round 1", _checkin_count == 1)

	# New round resets and reschedules
	cm.update_round(2)
	_check("round 2 resets roll count", cm._rolls_this_round == 0)
	_check("round 2 resets done flag", not cm._checkin_done_this_round)
	_check("round 2 has a fresh target", cm._checkin_roll_target >= 2)

	_roll(cm, 8)
	_check("check-in fired exactly once in round 2", _checkin_count == 2)


func _test_checkin_deferred_while_mom_active(cm) -> void:
	_checkin_count = 0
	cm.update_round(3)
	var target: int = cm._checkin_roll_target

	# Simulate a meter visit covering the target roll
	cm.is_mom_active = true
	_roll(cm, target + 2)
	_check("no check-in while Mom active", _checkin_count == 0)
	_check("check-in still pending after defer", not cm._checkin_done_this_round)

	# Meter visit over - next roll fires the deferred check-in
	cm.is_mom_active = false
	_roll(cm, 1)
	_check("deferred check-in fires after visit", _checkin_count == 1)


func _test_grudge(cm) -> void:
	_grudge_signals.clear()
	cm.grudge = 0
	cm.add_grudge(1)
	_check("grudge raised to 1", cm.grudge == 1)
	cm.add_grudge(5)
	_check("grudge clamped to MAX_GRUDGE", cm.grudge == ChoresManagerScript.MAX_GRUDGE)
	var consumed: int = cm.consume_grudge()
	_check("consume returns pre-decay grudge", consumed == ChoresManagerScript.MAX_GRUDGE)
	_check("consume decays grudge by 1", cm.grudge == ChoresManagerScript.MAX_GRUDGE - 1)
	_check("grudge_changed emitted for each change", _grudge_signals.size() == 3)

	cm.low_mood_visits_this_run = 0
	cm.register_low_mood_visit()
	cm.register_low_mood_visit()
	_check("low-mood visit counter increments", cm.low_mood_visits_this_run == 2)


func _test_save_load_roundtrip(cm) -> void:
	cm.grudge = 2
	cm.low_mood_visits_this_run = 1
	var state: Dictionary = cm.get_state()

	var cm2 = ChoresManagerScript.new()
	add_child(cm2)
	cm2.load_state(state)
	_check("grudge survives save/load", cm2.grudge == 2)
	_check("escalation counter survives save/load", cm2.low_mood_visits_this_run == 1)
	_check("check-in target survives save/load", cm2._checkin_roll_target == cm._checkin_roll_target)
	_check("check-in done flag survives save/load", cm2._checkin_done_this_round == cm._checkin_done_this_round)
	cm2.queue_free()
