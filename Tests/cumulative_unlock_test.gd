extends Node

## cumulative_unlock_test.gd
##
## Exercises the cumulative unlock conditions added to UnlockCondition:
##   1. CUMULATIVE_STRAIGHTS (any / small / large) against synthetic progress data.
##   2. CUMULATIVE_COLOR_BONUSES and CUMULATIVE_CONSUMABLES satisfied/failing.
##   3. get_formatted_description() returns target-containing text for new types.
##   4. ProgressManager registrations: no ROLL_STRAIGHT target above 3, and the
##      converted items use the new cumulative condition types.
##
## Run headless:
##   godot --headless --path . Tests/CumulativeUnlockTest.tscn -- --quit-after
## Exit code 0 = all checks passed, 1 = at least one failure.

var _failures: int = 0


func _ready() -> void:
	print("[CumulativeUnlockTest] Starting")
	_test_cumulative_straights_any()
	_test_cumulative_straights_typed()
	_test_cumulative_color_bonuses()
	_test_cumulative_consumables()
	_test_formatted_descriptions()
	_test_registrations()
	_finish()


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[CumulativeUnlockTest] OK: " + label)
	else:
		push_error("[CumulativeUnlockTest] FAILED: " + label)
		_failures += 1


func _make_condition(type: UnlockCondition.ConditionType, target: int, params: Dictionary = {}) -> UnlockCondition:
	var condition := UnlockCondition.new()
	condition.id = "test_condition"
	condition.condition_type = type
	condition.target_value = target
	condition.additional_params = params
	return condition


func _progress_data() -> Dictionary:
	return {
		"total_straights": 30,
		"total_small_straights": 12,
		"total_large_straights": 18,
		"total_color_bonuses": 10,
		"total_consumables_used": 25,
	}


func _test_cumulative_straights_any() -> void:
	var data := _progress_data()
	_check("any straights: 30 >= 25 satisfied",
		_make_condition(UnlockCondition.ConditionType.CUMULATIVE_STRAIGHTS, 25).is_satisfied({}, data))
	_check("any straights: 30 < 31 not satisfied",
		not _make_condition(UnlockCondition.ConditionType.CUMULATIVE_STRAIGHTS, 31).is_satisfied({}, data))
	_check("any straights: missing keys default to 0",
		not _make_condition(UnlockCondition.ConditionType.CUMULATIVE_STRAIGHTS, 1).is_satisfied({}, {}))


func _test_cumulative_straights_typed() -> void:
	var data := _progress_data()
	_check("large straights: 18 >= 18 satisfied",
		_make_condition(UnlockCondition.ConditionType.CUMULATIVE_STRAIGHTS, 18, {"straight_type": "large_straight"}).is_satisfied({}, data))
	_check("large straights: 18 < 20 not satisfied",
		not _make_condition(UnlockCondition.ConditionType.CUMULATIVE_STRAIGHTS, 20, {"straight_type": "large_straight"}).is_satisfied({}, data))
	_check("small straights: 12 >= 12 satisfied",
		_make_condition(UnlockCondition.ConditionType.CUMULATIVE_STRAIGHTS, 12, {"straight_type": "small_straight"}).is_satisfied({}, data))
	_check("small straights: 12 < 13 not satisfied",
		not _make_condition(UnlockCondition.ConditionType.CUMULATIVE_STRAIGHTS, 13, {"straight_type": "small_straight"}).is_satisfied({}, data))


func _test_cumulative_color_bonuses() -> void:
	var data := _progress_data()
	_check("color bonuses: 10 >= 10 satisfied",
		_make_condition(UnlockCondition.ConditionType.CUMULATIVE_COLOR_BONUSES, 10).is_satisfied({}, data))
	_check("color bonuses: 10 < 11 not satisfied",
		not _make_condition(UnlockCondition.ConditionType.CUMULATIVE_COLOR_BONUSES, 11).is_satisfied({}, data))


func _test_cumulative_consumables() -> void:
	var data := _progress_data()
	_check("consumables: 25 >= 25 satisfied",
		_make_condition(UnlockCondition.ConditionType.CUMULATIVE_CONSUMABLES, 25).is_satisfied({}, data))
	_check("consumables: 25 < 26 not satisfied",
		not _make_condition(UnlockCondition.ConditionType.CUMULATIVE_CONSUMABLES, 26).is_satisfied({}, data))


func _test_formatted_descriptions() -> void:
	var straight_desc := _make_condition(UnlockCondition.ConditionType.CUMULATIVE_STRAIGHTS, 20, {"straight_type": "large_straight"}).get_formatted_description()
	_check("large-straight description mentions 20 and 'large straight'",
		straight_desc.contains("20") and straight_desc.contains("large straight"))
	var any_desc := _make_condition(UnlockCondition.ConditionType.CUMULATIVE_STRAIGHTS, 15).get_formatted_description()
	_check("any-straight description mentions 15 and 'straight'",
		any_desc.contains("15") and any_desc.contains("straight"))
	var color_desc := _make_condition(UnlockCondition.ConditionType.CUMULATIVE_COLOR_BONUSES, 10).get_formatted_description()
	_check("color-bonus description mentions 10",
		color_desc.contains("10"))
	var consumable_desc := _make_condition(UnlockCondition.ConditionType.CUMULATIVE_CONSUMABLES, 25).get_formatted_description()
	_check("consumable description mentions 25",
		consumable_desc.contains("25"))


func _test_registrations() -> void:
	var progress_manager = get_node_or_null("/root/ProgressManager")
	_check("ProgressManager autoload available", progress_manager != null)
	if progress_manager == null:
		return

	# No per-game ROLL_STRAIGHT registration may require more than 3 (the
	# maximum number of straights scorable in a round).
	for item_id in progress_manager.unlockable_items:
		var condition = progress_manager.unlockable_items[item_id].unlock_condition
		if condition and condition.condition_type == UnlockCondition.ConditionType.ROLL_STRAIGHT:
			_check("ROLL_STRAIGHT target <= 3 for %s" % item_id, condition.target_value <= 3)

	var expected := {
		"daring_dice": [UnlockCondition.ConditionType.CUMULATIVE_STRAIGHTS, 12],
		"different_straights": [UnlockCondition.ConditionType.CUMULATIVE_STRAIGHTS, 15],
		"three_but_three": [UnlockCondition.ConditionType.CUMULATIVE_STRAIGHTS, 15],
		"perfect_strangers": [UnlockCondition.ConditionType.CUMULATIVE_STRAIGHTS, 25],
		"straight_triplet_master": [UnlockCondition.ConditionType.CUMULATIVE_STRAIGHTS, 20],
		"extra_rainbow": [UnlockCondition.ConditionType.CUMULATIVE_COLOR_BONUSES, 10],
		"orange_dice": [UnlockCondition.ConditionType.CUMULATIVE_CONSUMABLES, 25],
	}
	for item_id in expected:
		if not progress_manager.unlockable_items.has(item_id):
			_check("%s is registered" % item_id, false)
			continue
		var condition = progress_manager.unlockable_items[item_id].unlock_condition
		_check("%s uses expected condition type" % item_id,
			condition.condition_type == expected[item_id][0])
		_check("%s has expected target %d" % [item_id, expected[item_id][1]],
			condition.target_value == expected[item_id][1])

	var stm = progress_manager.unlockable_items["straight_triplet_master"].unlock_condition
	_check("straight_triplet_master requires large straights",
		stm.additional_params.get("straight_type", "") == "large_straight")


func _finish() -> void:
	if _failures == 0:
		print("[CumulativeUnlockTest] PASS - all checks passed")
	else:
		print("[CumulativeUnlockTest] FAIL - %d check(s) failed" % _failures)

	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(0 if _failures == 0 else 1)
