extends Control
class_name LockConstraintTest

## LockConstraintTest
##
## Standalone test scene for validating LockConstraintTracker logic
## and LOCK_CONSTRAINT chore flow. Can be run directly in Godot editor.

const LockConstraintTrackerScript = preload("res://Scripts/Core/lock_constraint_tracker.gd")

@onready var output_label: RichTextLabel = $OutputLabel
@onready var tracker: LockConstraintTracker = null

func _ready() -> void:
	output_label.text = ""
	_log("=== Lock Constraint Tracker Tests ===")
	_log("")
	
	_run_all_tests()

func _log(text: String) -> void:
	output_label.text += text + "\n"
	print(text)

func _run_all_tests() -> void:
	var passed := 0
	var failed := 0
	
	# Test 1: Basic satisfaction
	if _test_basic_satisfaction():
		passed += 1
	else:
		failed += 1
	
	# Test 2: Lock limit violation
	if _test_lock_violation():
		passed += 1
	else:
		failed += 1
	
	# Test 3: Score threshold not met
	if _test_score_shortfall():
		passed += 1
	else:
		failed += 1
	
	# Test 4: Expiration
	if _test_expiration():
		passed += 1
	else:
		failed += 1
	
	# Test 5: Zero-lock constraint
	if _test_zero_lock_constraint():
		passed += 1
	else:
		failed += 1
	
	# Test 6: Fixed window filtering
	if _test_fixed_window_filtering():
		passed += 1
	else:
		failed += 1
	
	_log("")
	_log("=== Results: %d passed, %d failed ===" % [passed, failed])

func _test_basic_satisfaction() -> bool:
	_log("Test 1: Basic satisfaction")
	var t = LockConstraintTrackerScript.new()
	t.setup(1, 3, 50, 1)
	
	# Turn 1: score 20, lock 1
	t.record_roll(1, 1)
	t.record_turn_score(1, 20)
	
	# Turn 2: score 20, lock 0
	t.record_roll(2, 0)
	t.record_turn_score(2, 20)
	
	# Should not be satisfied yet (score 40 / 50)
	if t.is_satisfied():
		_log("  FAIL: satisfied too early")
		return false
	
	# Turn 3: score 15, lock 1
	t.record_roll(3, 1)
	t.record_turn_score(3, 15)
	
	if not t.is_satisfied():
		_log("  FAIL: should be satisfied (score 55 >= 50, locks <= 1)")
		return false
	
	_log("  PASS")
	return true

func _test_lock_violation() -> bool:
	_log("Test 2: Lock limit violation")
	var t = LockConstraintTrackerScript.new()
	t.setup(1, 3, 50, 1)
	
	# Turn 1: score 30, lock 2 (violation)
	t.record_roll(1, 2)
	t.record_turn_score(1, 30)
	
	if not t.is_violated():
		_log("  FAIL: should detect violation")
		return false
	
	# Turn 2: score 30, lock 0
	t.record_roll(2, 0)
	t.record_turn_score(2, 30)
	
	# Total score 60 >= 50, but violation occurred
	if t.is_satisfied():
		_log("  FAIL: should not be satisfied due to violation")
		return false
	
	_log("  PASS")
	return true

func _test_score_shortfall() -> bool:
	_log("Test 3: Score threshold not met")
	var t = LockConstraintTrackerScript.new()
	t.setup(1, 3, 100, 5)
	
	# 3 turns with low scores
	for i in range(1, 4):
		t.record_roll(i, 0)
		t.record_turn_score(i, 20)
	
	if t.is_satisfied():
		_log("  FAIL: should not be satisfied (score 60 < 100)")
		return false
	
	if not t.is_expired(3):
		_log("  FAIL: should be expired")
		return false
	
	_log("  PASS")
	return true

func _test_expiration() -> bool:
	_log("Test 4: Expiration")
	var t = LockConstraintTrackerScript.new()
	t.setup(1, 2, 50, 1)
	
	# Only 1 turn recorded
	t.record_roll(1, 0)
	t.record_turn_score(1, 20)
	
	if t.is_expired(2):
		_log("  FAIL: should not expire yet (only turn 2, window is 2 turns starting at 1)")
		return false
	
	# Turn 2 recorded, still not enough score
	t.record_roll(2, 0)
	t.record_turn_score(2, 20)
	
	if not t.is_expired(2):
		_log("  FAIL: should be expired after window closes")
		return false
	
	_log("  PASS")
	return true

func _test_zero_lock_constraint() -> bool:
	_log("Test 5: Zero-lock constraint")
	var t = LockConstraintTrackerScript.new()
	t.setup(1, 3, 50, 0)
	
	# 3 turns, no locks, enough score
	for i in range(1, 4):
		t.record_roll(i, 0)
		t.record_turn_score(i, 20)
	
	if not t.is_satisfied():
		_log("  FAIL: should be satisfied with 0 locks")
		return false
	
	# Now violate with a lock
	var t2 = LockConstraintTrackerScript.new()
	t2.setup(1, 3, 50, 0)
	t2.record_roll(1, 1)
	t2.record_turn_score(1, 50)
	
	if t2.is_satisfied():
		_log("  FAIL: should not be satisfied with lock > 0")
		return false
	
	_log("  PASS")
	return true

func _test_fixed_window_filtering() -> bool:
	_log("Test 6: Fixed window filtering")
	var t = LockConstraintTrackerScript.new()
	t.setup(2, 2, 50, 5)
	
	# Turn 1: high score but outside the fixed window [2, 3]
	t.record_roll(1, 0)
	t.record_turn_score(1, 100)
	
	# Turn 2: within window
	t.record_roll(2, 0)
	t.record_turn_score(2, 30)
	
	# Should not be satisfied yet (only 1 turn in window)
	if t.is_satisfied():
		_log("  FAIL: satisfied too early")
		return false
	
	# Turn 3: within window
	t.record_roll(3, 0)
	t.record_turn_score(3, 25)
	
	# Total in window: 55 >= 50
	if not t.is_satisfied():
		_log("  FAIL: should be satisfied (window turns 2+3 = 55)")
		return false
	
	_log("  PASS")
	return true

## UI Handlers

func _on_test_basic_pressed() -> void:
	output_label.text = ""
	_test_basic_satisfaction()

func _on_test_violation_pressed() -> void:
	output_label.text = ""
	_test_lock_violation()

func _on_test_zero_lock_pressed() -> void:
	output_label.text = ""
	_test_zero_lock_constraint()

func _on_test_window_pressed() -> void:
	output_label.text = ""
	_test_fixed_window_filtering()

func _on_run_all_pressed() -> void:
	output_label.text = ""
	_run_all_tests()
