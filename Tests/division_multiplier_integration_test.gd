extends Node

## division_multiplier_integration_test.gd
##
## Validates The Division scoring behavior across all multiplicative factors:
## category levels, ScoreModifierManager multipliers, purple dice, blue dice,
## and the preserved auto-scoring calculation path.
##
## Run headless:
##   godot --headless --path . Tests/DivisionMultiplierIntegrationTest.tscn -- --quit-after
## Exit code 0 = all checks passed, 1 = at least one failure.

const ScorecardScript := preload("res://Scenes/ScoreCard/score_card.gd")
const DiceColorClass := preload("res://Scripts/Core/dice_color.gd")

var _failures: int = 0
var _scorecard: Scorecard
var _dice_hand: FakeDiceHand


class FakeDiceHand extends Node:
	var dice_list: Array[Dice] = []

	func _ready() -> void:
		add_to_group("dice_hand")

	func get_all_dice() -> Array:
		return dice_list


func _ready() -> void:
	print("[DivisionMultiplierTest] Starting")
	_check("ScoreModifierManager autoload available", ScoreModifierManager != null)
	_check("DiceColorManager autoload available", DiceColorManager != null)

	_setup_fixture()
	await get_tree().process_frame

	_test_manager_factor_helper()
	_test_regular_multiplier_inversion()
	_test_category_level_inversion()
	_test_purple_dice_inversion()
	_test_blue_used_inversion()
	_test_blue_unused_inversion()
	_test_mixed_stack_inversion()
	_test_preserved_scoring_matches_manual()

	_teardown_fixture()
	await get_tree().process_frame

	if _failures == 0:
		print("[DivisionMultiplierTest] PASS - all checks passed")
	else:
		print("[DivisionMultiplierTest] FAIL - %d check(s) failed" % _failures)

	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(0 if _failures == 0 else 1)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[DivisionMultiplierTest] OK: " + label)
	else:
		push_error("[DivisionMultiplierTest] FAILED: " + label)
		_failures += 1


func _setup_fixture() -> void:
	_scorecard = ScorecardScript.new()
	add_child(_scorecard)
	DiceResults.set_scorecard(_scorecard)

	_dice_hand = FakeDiceHand.new()
	add_child(_dice_hand)

	for _i in range(5):
		var die := Dice.new()
		_dice_hand.dice_list.append(die)

	_reset_fixture()


func _reset_fixture() -> void:
	if ScoreModifierManager:
		ScoreModifierManager.reset()
		ScoreModifierManager.set_division_mode(false)

	for category in _scorecard.upper_levels.keys():
		_scorecard.upper_levels[category] = 1
	for category in _scorecard.lower_levels.keys():
		_scorecard.lower_levels[category] = 1

	var default_values: Array[int] = [1, 1, 1, 1, 1]
	var default_colors = [
		DiceColorClass.Type.NONE,
		DiceColorClass.Type.NONE,
		DiceColorClass.Type.NONE,
		DiceColorClass.Type.NONE,
		DiceColorClass.Type.NONE,
	]
	_set_dice(default_values, default_colors)
	DiceResults.update_from_dice(_dice_hand.dice_list)


func _teardown_fixture() -> void:
	_reset_fixture()
	DiceResults.reset()
	DiceResults.set_scorecard(null)
	for die in _dice_hand.dice_list:
		if is_instance_valid(die):
			die.free()
	_dice_hand.dice_list.clear()
	if is_instance_valid(_dice_hand):
		_dice_hand.queue_free()
	if is_instance_valid(_scorecard):
		_scorecard.queue_free()


func _set_dice(values: Array[int], colors: Array) -> void:
	for i in range(_dice_hand.dice_list.size()):
		var die = _dice_hand.dice_list[i]
		die.value = values[i]
		die.color = colors[i]
	DiceResults.update_from_dice(_dice_hand.dice_list)


func _set_category_level(category: String, level: int) -> void:
	if _scorecard.upper_levels.has(category):
		_scorecard.upper_levels[category] = level
	elif _scorecard.lower_levels.has(category):
		_scorecard.lower_levels[category] = level


func _score_case(category: String, values: Array[int], colors: Array, division_enabled: bool, raw_multipliers: Dictionary = {}, level_overrides: Dictionary = {}) -> Dictionary:
	_reset_fixture()
	_set_dice(values, colors)

	for level_category in level_overrides.keys():
		_set_category_level(level_category, int(level_overrides[level_category]))

	for source_name in raw_multipliers.keys():
		ScoreModifierManager.register_multiplier(source_name, float(raw_multipliers[source_name]))

	ScoreModifierManager.set_division_mode(division_enabled)
	return _scorecard.calculate_score_with_breakdown(category, values, false)


func _check_score(label: String, result: Dictionary, expected_score: int) -> void:
	var actual_score = int(result.get("final_score", -1))
	_check(label + " score", actual_score == expected_score)


func _test_manager_factor_helper() -> void:
	_reset_fixture()
	_check("factor helper preserves 2.0 when division inactive", is_equal_approx(ScoreModifierManager.get_effective_multiplier_factor(2.0), 2.0))
	ScoreModifierManager.set_division_mode(true)
	_check("factor helper inverts 2.0 to 0.5", is_equal_approx(ScoreModifierManager.get_effective_multiplier_factor(2.0), 0.5))
	_check("factor helper inverts 0.25 to 4.0", is_equal_approx(ScoreModifierManager.get_effective_multiplier_factor(0.25), 4.0))
	_check("factor helper preserves 1.0", is_equal_approx(ScoreModifierManager.get_effective_multiplier_factor(1.0), 1.0))


func _test_regular_multiplier_inversion() -> void:
	var values: Array[int] = [1, 2, 3, 4, 5]
	var colors = [DiceColorClass.Type.NONE, DiceColorClass.Type.NONE, DiceColorClass.Type.NONE, DiceColorClass.Type.NONE, DiceColorClass.Type.NONE]
	var raw_multipliers = {"division_test_regular": 3.0}

	var normal_result = _score_case("chance", values, colors, false, raw_multipliers)
	_check_score("regular multiplier without division", normal_result, 45)

	var division_result = _score_case("chance", values, colors, true, raw_multipliers)
	_check_score("regular multiplier with division", division_result, 5)
	var breakdown_info = division_result.get("breakdown_info", {})
	_check("regular multiplier display operator flips to divide", breakdown_info.get("regular_multiplier_display_operator", "") == "÷")
	_check("regular multiplier display value is 3.0", is_equal_approx(float(breakdown_info.get("regular_multiplier_display_value", 0.0)), 3.0))


func _test_category_level_inversion() -> void:
	var values: Array[int] = [5, 5, 1, 1, 1]
	var colors = [DiceColorClass.Type.NONE, DiceColorClass.Type.NONE, DiceColorClass.Type.NONE, DiceColorClass.Type.NONE, DiceColorClass.Type.NONE]
	var levels = {"fives": 2}

	var normal_result = _score_case("fives", values, colors, false, {}, levels)
	_check_score("category level without division", normal_result, 20)

	var division_result = _score_case("fives", values, colors, true, {}, levels)
	_check_score("category level with division", division_result, 5)
	var breakdown_info = division_result.get("breakdown_info", {})
	_check("category level display operator flips to divide", breakdown_info.get("category_level_display_operator", "") == "÷")
	_check("category level display value is 2.0", is_equal_approx(float(breakdown_info.get("category_level_display_value", 0.0)), 2.0))


func _test_purple_dice_inversion() -> void:
	var values: Array[int] = [1, 2, 3, 4, 5]
	var colors = [DiceColorClass.Type.PURPLE, DiceColorClass.Type.NONE, DiceColorClass.Type.NONE, DiceColorClass.Type.NONE, DiceColorClass.Type.NONE]

	var normal_result = _score_case("chance", values, colors, false)
	_check_score("purple dice without division", normal_result, 30)

	var division_result = _score_case("chance", values, colors, true)
	_check_score("purple dice with division", division_result, 7)
	var breakdown_info = division_result.get("breakdown_info", {})
	_check("purple multiplier display operator flips to divide", breakdown_info.get("dice_color_multiplier_display_operator", "") == "÷")
	_check("purple multiplier display value is 2.0", is_equal_approx(float(breakdown_info.get("dice_color_multiplier_display_value", 0.0)), 2.0))


func _test_blue_used_inversion() -> void:
	var values: Array[int] = [4, 4, 4, 4, 4]
	var colors = [DiceColorClass.Type.BLUE, DiceColorClass.Type.NONE, DiceColorClass.Type.NONE, DiceColorClass.Type.NONE, DiceColorClass.Type.NONE]

	var normal_result = _score_case("chance", values, colors, false)
	_check_score("used blue die without division", normal_result, 80)

	var division_result = _score_case("chance", values, colors, true)
	_check_score("used blue die with division", division_result, 5)
	var breakdown_info = division_result.get("breakdown_info", {})
	_check("used blue display operator flips to divide", breakdown_info.get("blue_score_multiplier_display_operator", "") == "÷")
	_check("used blue display value is 4.0", is_equal_approx(float(breakdown_info.get("blue_score_multiplier_display_value", 0.0)), 4.0))


func _test_blue_unused_inversion() -> void:
	var values: Array[int] = [5, 5, 4, 1, 1]
	var colors = [DiceColorClass.Type.NONE, DiceColorClass.Type.NONE, DiceColorClass.Type.BLUE, DiceColorClass.Type.NONE, DiceColorClass.Type.NONE]

	var normal_result = _score_case("fives", values, colors, false)
	_check_score("unused blue die without division", normal_result, 2)

	var division_result = _score_case("fives", values, colors, true)
	_check_score("unused blue die with division", division_result, 40)
	var breakdown_info = division_result.get("breakdown_info", {})
	_check("unused blue display operator flips to multiply", breakdown_info.get("blue_score_multiplier_display_operator", "") == "×")
	_check("unused blue display value is 4.0", is_equal_approx(float(breakdown_info.get("blue_score_multiplier_display_value", 0.0)), 4.0))


func _test_mixed_stack_inversion() -> void:
	var values: Array[int] = [5, 5, 4, 1, 1]
	var colors = [DiceColorClass.Type.PURPLE, DiceColorClass.Type.NONE, DiceColorClass.Type.BLUE, DiceColorClass.Type.NONE, DiceColorClass.Type.NONE]
	var raw_multipliers = {"division_test_regular": 3.0}
	var levels = {"fives": 2}

	var normal_result = _score_case("fives", values, colors, false, raw_multipliers, levels)
	_check_score("mixed stack without division", normal_result, 30)

	var division_result = _score_case("fives", values, colors, true, raw_multipliers, levels)
	_check_score("mixed stack with division", division_result, 3)


func _test_preserved_scoring_matches_manual() -> void:
	var values: Array[int] = [5, 5, 4, 1, 1]
	var colors = [DiceColorClass.Type.PURPLE, DiceColorClass.Type.NONE, DiceColorClass.Type.BLUE, DiceColorClass.Type.NONE, DiceColorClass.Type.NONE]
	var raw_multipliers = {"division_test_regular": 3.0}
	var levels = {"fives": 2}

	var manual_result = _score_case("fives", values, colors, true, raw_multipliers, levels)
	var manual_score = int(manual_result.get("final_score", -1))
	var color_capture = _scorecard._capture_color_effects_for_score("fives", values, false)
	var preserved_score = _scorecard._calculate_score_with_preserved_effects("fives", values, false, color_capture.get("effects", {}))

	_check("preserved scoring matches manual scoring under division", preserved_score == manual_score)