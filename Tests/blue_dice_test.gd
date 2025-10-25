extends Control

## BluesDiceTest
## Test scene for verifying Blue dice functionality
## Tests both penalty (not used) and bonus (used) scenarios

@onready var test_output: RichTextLabel = $VBoxContainer/TestOutput
@onready var run_tests_button: Button = $VBoxContainer/RunTestsButton

var test_results: Array[String] = []

func _ready() -> void:
	run_tests_button.pressed.connect(_run_all_tests)
	add_log("Blue Dice Test Scene Ready")
	add_log("Click 'Run Tests' to verify Blue dice functionality")

func _run_all_tests() -> void:
	test_results.clear()
	clear_log()
	
	add_log("[color=yellow]Starting Blue Dice Tests...[/color]")
	
	# Test 1: Blue dice penalty scenario (not used in scoring)
	_test_blue_dice_penalty()
	
	# Test 2: Blue dice bonus scenario (used in scoring)
	_test_blue_dice_bonus()
	
	# Test 3: Multiple Blue dice scenario
	_test_multiple_blue_dice()
	
	# Test 4: Same color bonus with Blue dice
	_test_blue_same_color_bonus()
	
	# Test 5: Verify statistics tracking
	_test_blue_statistics_tracking()
	
	# Summary
	add_log("\n[color=yellow]=== TEST SUMMARY ===[/color]")
	var passed = 0
	var failed = 0
	for result in test_results:
		add_log(result)
		if "PASS" in result:
			passed += 1
		else:
			failed += 1
	
	add_log("\n[color=green]Tests Passed: %d[/color]" % passed)
	if failed > 0:
		add_log("[color=red]Tests Failed: %d[/color]" % failed)
	else:
		add_log("[color=green]All tests passed![/color]")

## Test Blue dice penalty scenario (dice not used in scoring)
## Example: Roll 4,4,4,4,5(blue) and score in Fours category
func _test_blue_dice_penalty() -> void:
	add_log("\n[color=cyan]Test 1: Blue Dice Penalty (Not Used)[/color]")
	
	# Create mock dice array: four 4s and one blue 5
	var dice_array = _create_mock_dice_array([4, 4, 4, 4, 5], ["none", "none", "none", "none", "blue"])
	var used_dice_array = [dice_array[0], dice_array[1], dice_array[2], dice_array[3]]  # Only the 4s are used
	
	var dice_color_manager = _get_dice_color_manager()
	if not dice_color_manager:
		_record_test_result("Test 1", false, "DiceColorManager not found")
		return
	
	var result = dice_color_manager.apply_color_effects_to_score(16, dice_array, used_dice_array)
	var expected_score = int(16 / 5)  # 16 divided by 5 (blue die value) = 3 (rounded down)
	
	add_log("  Base score: 16 (four 4s)")
	add_log("  Blue die value: 5 (not used)")
	add_log("  Expected: 16 ÷ 5 = 3")
	add_log("  Actual: %d" % result.final_score)
	
	var passed = result.final_score == expected_score
	_record_test_result("Test 1: Blue Dice Penalty", passed, 
		"Expected %d, got %d" % [expected_score, result.final_score])

## Test Blue dice bonus scenario (dice used in scoring)
## Example: Roll 1,2,3,4,5(blue) for Large Straight
func _test_blue_dice_bonus() -> void:
	add_log("\n[color=cyan]Test 2: Blue Dice Bonus (Used)[/color]")
	
	# Create mock dice array for large straight with blue 3
	var dice_array = _create_mock_dice_array([1, 2, 3, 4, 5], ["none", "none", "blue", "none", "none"])
	var used_dice_array = dice_array  # All dice used for straight
	
	var dice_color_manager = _get_dice_color_manager()
	if not dice_color_manager:
		_record_test_result("Test 2", false, "DiceColorManager not found")
		return
	
	var result = dice_color_manager.apply_color_effects_to_score(40, dice_array, used_dice_array)
	var expected_score = 40 * 3  # 40 × 3 (blue die value) = 120
	
	add_log("  Base score: 40 (Large Straight)")
	add_log("  Blue die value: 3 (used)")
	add_log("  Expected: 40 × 3 = 120")
	add_log("  Actual: %d" % result.final_score)
	
	var passed = result.final_score == expected_score
	_record_test_result("Test 2: Blue Dice Bonus", passed,
		"Expected %d, got %d" % [expected_score, result.final_score])

## Test multiple Blue dice with mixed usage
func _test_multiple_blue_dice() -> void:
	add_log("\n[color=cyan]Test 3: Multiple Blue Dice (Mixed Usage)[/color]")
	
	# Create scenario: 2(blue), 2, 3(blue), 4, 5 scoring in Twos (only the 2s are used)
	var dice_array = _create_mock_dice_array([2, 2, 3, 4, 5], ["blue", "none", "blue", "none", "none"])
	var used_dice_array = [dice_array[0], dice_array[1]]  # Only the 2s are used
	
	var dice_color_manager = _get_dice_color_manager()
	if not dice_color_manager:
		_record_test_result("Test 3", false, "DiceColorManager not found")
		return
	
	var result = dice_color_manager.apply_color_effects_to_score(4, dice_array, used_dice_array)
	# Expected: 4 × 2 (blue 2 used) ÷ 3 (blue 3 not used) = 8 ÷ 3 = 2 (rounded down)
	var expected_score = int((4 * 2) / 3)
	
	add_log("  Base score: 4 (two 2s)")
	add_log("  Blue 2 (used): multiply by 2")
	add_log("  Blue 3 (not used): divide by 3") 
	add_log("  Expected: (4 × 2) ÷ 3 = 2")
	add_log("  Actual: %d" % result.final_score)
	
	var passed = result.final_score == expected_score
	_record_test_result("Test 3: Multiple Blue Dice", passed,
		"Expected %d, got %d" % [expected_score, result.final_score])

## Test same color bonus with 5+ Blue dice
func _test_blue_same_color_bonus() -> void:
	add_log("\n[color=cyan]Test 4: Blue Dice Same Color Bonus[/color]")
	
	# Create 5 blue dice scenario
	var dice_array = _create_mock_dice_array([1, 2, 3, 4, 5], ["blue", "blue", "blue", "blue", "blue"])
	var used_dice_array = dice_array  # All used for chance
	
	var dice_color_manager = _get_dice_color_manager()
	if not dice_color_manager:
		_record_test_result("Test 4", false, "DiceColorManager not found")
		return
	
	var result = dice_color_manager.apply_color_effects_to_score(15, dice_array, used_dice_array)
	# Expected: 15 × (1×2×3×4×5) × 2 (same color bonus) = 15 × 120 × 2 = 3600
	var expected_score = 15 * (1 * 2 * 3 * 4 * 5) * 2
	
	add_log("  Base score: 15 (sum of dice)")
	add_log("  Blue multiplier: 1×2×3×4×5 = 120")
	add_log("  Same color bonus: 2x")
	add_log("  Expected: 15 × 120 × 2 = 3600")
	add_log("  Actual: %d" % result.final_score)
	
	var passed = result.final_score == expected_score
	_record_test_result("Test 4: Blue Same Color Bonus", passed,
		"Expected %d, got %d" % [expected_score, result.final_score])

## Test Blue dice statistics tracking
func _test_blue_statistics_tracking() -> void:
	add_log("\n[color=cyan]Test 5: Blue Dice Statistics Tracking[/color]")
	
	var stats_manager = get_node_or_null("/root/Statistics")
	if not stats_manager:
		_record_test_result("Test 5", false, "Statistics Manager not found")
		return
	
	# Check if blue color is properly initialized in tracking
	var has_blue_rolled = stats_manager.dice_rolled_by_color.has("blue")
	var has_blue_scored = stats_manager.dice_scored_by_color.has("blue")
	
	add_log("  Blue dice rolled tracking: %s" % ("Present" if has_blue_rolled else "Missing"))
	add_log("  Blue dice scored tracking: %s" % ("Present" if has_blue_scored else "Missing"))
	
	var passed = has_blue_rolled and has_blue_scored
	_record_test_result("Test 5: Blue Statistics Tracking", passed,
		"Blue tracking in statistics: rolled=%s, scored=%s" % [has_blue_rolled, has_blue_scored])

## Helper function to create mock dice array
func _create_mock_dice_array(values: Array[int], colors: Array[String]) -> Array:
	var mock_dice = []
	for i in range(values.size()):
		var mock_die = MockDice.new()
		mock_die.value = values[i]
		mock_die.set_mock_color(colors[i])
		mock_dice.append(mock_die)
	return mock_dice

## Helper function to get DiceColorManager
func _get_dice_color_manager():
	return get_tree().get_first_node_in_group("dice_color_manager")

## Record test result for summary
func _record_test_result(test_name: String, passed: bool, details: String = "") -> void:
	var status = "[color=green]PASS[/color]" if passed else "[color=red]FAIL[/color]"
	var result_text = "%s: %s" % [test_name, status]
	if not details.is_empty():
		result_text += " - " + details
	test_results.append(result_text)

## Add log entry to output
func add_log(message: String) -> void:
	test_output.append_text(message + "\n")

## Clear log output
func clear_log() -> void:
	test_output.clear()

## Mock dice class for testing
class MockDice:
	var value: int = 1
	var color_string: String = "none"
	
	func set_mock_color(color_name: String) -> void:
		color_string = color_name.to_lower()
	
	func get_color():
		match color_string:
			"green":
				return preload("res://Scripts/Core/dice_color.gd").Type.GREEN
			"red":
				return preload("res://Scripts/Core/dice_color.gd").Type.RED
			"purple":
				return preload("res://Scripts/Core/dice_color.gd").Type.PURPLE
			"blue":
				return preload("res://Scripts/Core/dice_color.gd").Type.BLUE
			_:
				return preload("res://Scripts/Core/dice_color.gd").Type.NONE