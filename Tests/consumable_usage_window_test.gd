extends Control
class_name ConsumableUsageWindowTest

## consumable_usage_window_test.gd
##
## Verifies the ConsumableData.UsageWindow -> GameController.GamePhase mapping
## used by the data-driven consumable usability check:
## 1. ANY_TIME is usable in every phase.
## 2. BEFORE_ROLL_INITIATED is usable only in IDLE.
## 3. DURING_ACTIVE_ROUND is usable only in ROUND_ACTIVE.
## 4. AFTER_SCORING is usable only in AFTER_SCORE.
## 5. Defaults keep un-migrated resources usable (ANY_TIME, empty sets).
## 6. Migrated anchor .tres files carry their intended windows/conditions.
##
## Run headless with `-- --auto-test` to run the suite and quit with an
## exit code (0 = pass, 1 = fail).

var _fail_count := 0
var _test_completed := false

func _ready() -> void:
	print("=== Consumable Usage Window Test ===")
	_run_tests()
	_test_completed = true
	if "--auto-test" in OS.get_cmdline_user_args():
		_quit_with_result()
	elif DisplayServer.get_name() == "headless":
		_quit_with_result()

func _run_tests() -> void:
	var phases := {
		"IDLE": GameController.GamePhase.IDLE,
		"ROUND_ACTIVE": GameController.GamePhase.ROUND_ACTIVE,
		"AFTER_SCORE": GameController.GamePhase.AFTER_SCORE,
	}

	print("--- Window x Phase matrix ---")
	var expectations := {
		ConsumableData.UsageWindow.ANY_TIME: {"IDLE": true, "ROUND_ACTIVE": true, "AFTER_SCORE": true},
		ConsumableData.UsageWindow.BEFORE_ROLL_INITIATED: {"IDLE": true, "ROUND_ACTIVE": false, "AFTER_SCORE": false},
		ConsumableData.UsageWindow.DURING_ACTIVE_ROUND: {"IDLE": false, "ROUND_ACTIVE": true, "AFTER_SCORE": false},
		ConsumableData.UsageWindow.AFTER_SCORING: {"IDLE": false, "ROUND_ACTIVE": false, "AFTER_SCORE": true},
	}
	for window in expectations.keys():
		var data := ConsumableData.new()
		data.usage_window = window
		var window_name: String = ConsumableData.UsageWindow.keys()[window]
		for phase_name in phases.keys():
			var expected: bool = expectations[window][phase_name]
			_assert_equals(data.is_usable_in_phase(phases[phase_name]), expected,
				"%s in %s" % [window_name, phase_name])

	print("--- Defaults keep un-migrated resources usable ---")
	var fresh := ConsumableData.new()
	_assert_equals(fresh.usage_window, ConsumableData.UsageWindow.ANY_TIME, "default usage_window is ANY_TIME")
	_assert(fresh.allowed_dice_sets.is_empty(), "default allowed_dice_sets is empty")
	_assert(fresh.is_available_for_dice_sides(4), "fresh data available for d4")
	_assert(fresh.is_available_for_dice_sides(6), "fresh data available for d6")
	_assert(fresh.is_usable_in_phase(GameController.GamePhase.IDLE), "fresh data usable in IDLE")

	print("--- Migrated anchor resources ---")
	var go_broke := preload("res://Scripts/Consumable/GoBrokeOrGoHomeConsumable.tres") as ConsumableData
	_assert_equals(go_broke.usage_window, ConsumableData.UsageWindow.BEFORE_ROLL_INITIATED,
		"go_broke_or_go_home is BEFORE_ROLL_INITIATED")
	_assert(go_broke.usage_conditions.has(&"open_lower_category"),
		"go_broke_or_go_home keeps open_lower_category condition")
	var visit_shop := preload("res://Scripts/Consumable/VisitTheShopConsumable.tres") as ConsumableData
	_assert_equals(visit_shop.usage_window, ConsumableData.UsageWindow.AFTER_SCORING,
		"visit_the_shop is AFTER_SCORING")
	var mulligan := preload("res://Scripts/Consumable/MulliganConsumable.tres") as ConsumableData
	_assert_equals(mulligan.usage_window, ConsumableData.UsageWindow.DURING_ACTIVE_ROUND,
		"mulligan is DURING_ACTIVE_ROUND")
	_assert(mulligan.usage_conditions.has(&"dice_rolled") and mulligan.usage_conditions.has(&"has_placed_score"),
		"mulligan keeps dice_rolled + has_placed_score conditions")

	var result_text := "PASS"
	if _fail_count > 0:
		result_text = "FAIL"
	print("=== Usage Window Test Complete: %s ===" % result_text)

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("✓ %s" % message)
	else:
		_fail_count += 1
		push_error("[ConsumableUsageWindowTest] FAIL: %s" % message)
		print("✗ %s" % message)

func _assert_equals(actual, expected, message: String) -> void:
	_assert(actual == expected, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])

func _quit_with_result() -> void:
	if _fail_count > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)

func _input(event: InputEvent) -> void:
	if _test_completed and event.is_action_pressed("ui_accept"):
		_quit_with_result()
