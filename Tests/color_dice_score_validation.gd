extends Control

## ColorDiceScoreValidation
##
## Manual test scene for validating colored dice scoring effects.
## Tests Green (money), Red (additive), Purple (multiplicative), and Blue (conditional) dice.
##
## Usage: Run the scene and press buttons to execute specific tests.
## Console output shows detailed scoring calculations for manual review.

# UI References
@onready var log_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/LogContainer
@onready var test_button_green: Button = $MarginContainer/VBoxContainer/ButtonContainer/TestGreenButton
@onready var test_button_red: Button = $MarginContainer/VBoxContainer/ButtonContainer/TestRedButton
@onready var test_button_purple: Button = $MarginContainer/VBoxContainer/ButtonContainer/TestPurpleButton
@onready var test_button_blue: Button = $MarginContainer/VBoxContainer/ButtonContainer/TestBlueButton
@onready var test_all_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/TestAllButton
@onready var clear_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/ClearButton

# Font for log labels
var vcr_font: Font

func _ready() -> void:
	_log_header("=== Color Dice Score Validation Test ===")
	_log_info("Press buttons to run individual tests or 'Run All Tests'")
	_log_info("")
	
	# Load VCR font
	vcr_font = load("res://Resources/Font/VCR_OSD_MONO.ttf")
	
	# Connect button signals
	if test_button_green:
		test_button_green.pressed.connect(_test_green_dice)
	if test_button_red:
		test_button_red.pressed.connect(_test_red_dice)
	if test_button_purple:
		test_button_purple.pressed.connect(_test_purple_dice)
	if test_button_blue:
		test_button_blue.pressed.connect(_test_blue_dice)
	if test_all_button:
		test_all_button.pressed.connect(_run_all_tests)
	if clear_button:
		clear_button.pressed.connect(_clear_log)


## _run_all_tests()
##
## Executes all color dice tests in sequence.
func _run_all_tests() -> void:
	_log_header("=== Running All Color Dice Tests ===")
	_test_green_dice()
	_log_info("")
	_test_red_dice()
	_log_info("")
	_test_purple_dice()
	_log_info("")
	_test_blue_dice()
	_log_header("=== All Tests Complete ===")


## _test_green_dice()
##
## Tests Green dice money bonus effect.
## Green dice add their face value as money bonus.
func _test_green_dice() -> void:
	_log_header("--- GREEN DICE TESTS (Money Bonus) ---")
	
	# Test 1: Single green die
	_log_test("Test 1: Single Green Die")
	var dice_values_1 = [3, 3, 3, 4, 5]
	var dice_colors_1 = [DiceColor.Type.GREEN, DiceColor.Type.NONE, DiceColor.Type.NONE, DiceColor.Type.NONE, DiceColor.Type.NONE]
	_simulate_color_effects(dice_values_1, dice_colors_1, "green_single")
	
	# Test 2: Multiple green dice
	_log_test("Test 2: Multiple Green Dice")
	var dice_values_2 = [2, 4, 6, 3, 5]
	var dice_colors_2 = [DiceColor.Type.GREEN, DiceColor.Type.GREEN, DiceColor.Type.GREEN, DiceColor.Type.NONE, DiceColor.Type.NONE]
	_simulate_color_effects(dice_values_2, dice_colors_2, "green_multiple")
	
	# Test 3: All green dice (same color bonus)
	_log_test("Test 3: All Green Dice (Same Color Bonus)")
	var dice_values_3 = [1, 2, 3, 4, 5]
	var dice_colors_3 = [DiceColor.Type.GREEN, DiceColor.Type.GREEN, DiceColor.Type.GREEN, DiceColor.Type.GREEN, DiceColor.Type.GREEN]
	_simulate_color_effects(dice_values_3, dice_colors_3, "green_all")


## _test_red_dice()
##
## Tests Red dice additive bonus effect.
## Red dice add their face value to the score.
func _test_red_dice() -> void:
	_log_header("--- RED DICE TESTS (Additive Bonus) ---")
	
	# Test 1: Single red die
	_log_test("Test 1: Single Red Die")
	var dice_values_1 = [4, 4, 4, 2, 6]
	var dice_colors_1 = [DiceColor.Type.NONE, DiceColor.Type.RED, DiceColor.Type.NONE, DiceColor.Type.NONE, DiceColor.Type.NONE]
	_simulate_color_effects(dice_values_1, dice_colors_1, "red_single")
	
	# Test 2: Multiple red dice
	_log_test("Test 2: Multiple Red Dice")
	var dice_values_2 = [5, 5, 3, 3, 2]
	var dice_colors_2 = [DiceColor.Type.RED, DiceColor.Type.RED, DiceColor.Type.NONE, DiceColor.Type.NONE, DiceColor.Type.NONE]
	_simulate_color_effects(dice_values_2, dice_colors_2, "red_multiple")
	
	# Test 3: All red dice (same color bonus)
	_log_test("Test 3: All Red Dice (Same Color Bonus)")
	var dice_values_3 = [6, 6, 6, 6, 6]
	var dice_colors_3 = [DiceColor.Type.RED, DiceColor.Type.RED, DiceColor.Type.RED, DiceColor.Type.RED, DiceColor.Type.RED]
	_simulate_color_effects(dice_values_3, dice_colors_3, "red_all")


## _test_purple_dice()
##
## Tests Purple dice multiplicative bonus effect.
## Purple dice multiply the score by their face value.
func _test_purple_dice() -> void:
	_log_header("--- PURPLE DICE TESTS (Multiplicative Bonus) ---")
	
	# Test 1: Single purple die
	_log_test("Test 1: Single Purple Die (value 2)")
	var dice_values_1 = [3, 3, 3, 4, 2]
	var dice_colors_1 = [DiceColor.Type.NONE, DiceColor.Type.NONE, DiceColor.Type.NONE, DiceColor.Type.NONE, DiceColor.Type.PURPLE]
	_simulate_color_effects(dice_values_1, dice_colors_1, "purple_single")
	
	# Test 2: Multiple purple dice
	_log_test("Test 2: Multiple Purple Dice (values 2, 3)")
	var dice_values_2 = [2, 3, 4, 4, 4]
	var dice_colors_2 = [DiceColor.Type.PURPLE, DiceColor.Type.PURPLE, DiceColor.Type.NONE, DiceColor.Type.NONE, DiceColor.Type.NONE]
	_simulate_color_effects(dice_values_2, dice_colors_2, "purple_multiple")
	
	# Test 3: All purple dice (same color bonus)
	_log_test("Test 3: All Purple Dice (Same Color Bonus)")
	var dice_values_3 = [2, 2, 2, 2, 2]
	var dice_colors_3 = [DiceColor.Type.PURPLE, DiceColor.Type.PURPLE, DiceColor.Type.PURPLE, DiceColor.Type.PURPLE, DiceColor.Type.PURPLE]
	_simulate_color_effects(dice_values_3, dice_colors_3, "purple_all")


## _test_blue_dice()
##
## Tests Blue dice conditional multiplier/divisor effect.
## Blue dice multiply when used in scoring, divide when not used.
func _test_blue_dice() -> void:
	_log_header("--- BLUE DICE TESTS (Conditional Effect) ---")
	
	# Test 1: Blue die USED in scoring (multiplier)
	_log_test("Test 1: Blue Die USED in Scoring")
	_log_info("  Scenario: Scoring '1-2-3-4-5' as Large Straight")
	_log_info("  Blue die value 3 is part of the straight")
	var dice_values_1 = [1, 2, 3, 4, 5]
	var dice_colors_1 = [DiceColor.Type.NONE, DiceColor.Type.NONE, DiceColor.Type.BLUE, DiceColor.Type.NONE, DiceColor.Type.NONE]
	var used_indices_1 = [0, 1, 2, 3, 4]  # All dice used in straight
	_simulate_blue_dice_effect(dice_values_1, dice_colors_1, used_indices_1, 40, "blue_used")
	
	# Test 2: Blue die NOT USED in scoring (divisor/penalty)
	_log_test("Test 2: Blue Die NOT USED in Scoring")
	_log_info("  Scenario: Scoring 'Four 4s' from roll 4-4-4-4-5")
	_log_info("  Blue die value 5 is NOT part of the 4s")
	var dice_values_2 = [4, 4, 4, 4, 5]
	var dice_colors_2 = [DiceColor.Type.NONE, DiceColor.Type.NONE, DiceColor.Type.NONE, DiceColor.Type.NONE, DiceColor.Type.BLUE]
	var used_indices_2 = [0, 1, 2, 3]  # Only the 4s are used
	_simulate_blue_dice_effect(dice_values_2, dice_colors_2, used_indices_2, 16, "blue_not_used")
	
	# Test 3: Multiple blue dice - mixed usage
	_log_test("Test 3: Multiple Blue Dice (Mixed Usage)")
	_log_info("  Scenario: Roll 3-3-3-4-5 scoring Three of a Kind")
	_log_info("  Blue 3 is USED, Blue 5 is NOT USED")
	var dice_values_3 = [3, 3, 3, 4, 5]
	var dice_colors_3 = [DiceColor.Type.BLUE, DiceColor.Type.NONE, DiceColor.Type.NONE, DiceColor.Type.NONE, DiceColor.Type.BLUE]
	var used_indices_3 = [0, 1, 2]  # Three 3s used
	_simulate_blue_dice_effect(dice_values_3, dice_colors_3, used_indices_3, 18, "blue_mixed")
	
	# Test 4: All blue dice (same color bonus)
	_log_test("Test 4: All Blue Dice - All USED (Same Color Bonus)")
	_log_info("  Scenario: Yahtzee with all blue dice")
	var dice_values_4 = [5, 5, 5, 5, 5]
	var dice_colors_4 = [DiceColor.Type.BLUE, DiceColor.Type.BLUE, DiceColor.Type.BLUE, DiceColor.Type.BLUE, DiceColor.Type.BLUE]
	var used_indices_4 = [0, 1, 2, 3, 4]  # All used in Yahtzee
	_simulate_blue_dice_effect(dice_values_4, dice_colors_4, used_indices_4, 50, "blue_all_used")


## _simulate_color_effects()
##
## Simulates color effect calculations and logs results.
## Uses DiceColorManager.calculate_color_effects() for actual calculations.
func _simulate_color_effects(dice_values: Array, dice_colors: Array, test_name: String) -> void:
	_log_info("  Dice values: %s" % str(dice_values))
	_log_info("  Dice colors: %s" % _format_colors(dice_colors))
	
	# Use DiceColorManager to calculate effects
	var effects = DiceColorManager.calculate_color_effects(dice_values, dice_colors)
	
	_log_result("Results:")
	_log_result("  Green (money): $%d" % effects.get("green_money", 0))
	_log_result("  Red (additive): +%d" % effects.get("red_additive", 0))
	_log_result("  Purple (multiplier): x%.1f" % effects.get("purple_multiplier", 1.0))
	_log_result("  Same Color Bonus: %s" % str(effects.get("same_color_bonus", false)))
	
	# Validate expected results based on test_name
	_validate_color_test(test_name, effects, dice_values, dice_colors)


## _simulate_blue_dice_effect()
##
## Simulates Blue dice conditional effect with used/unused tracking.
func _simulate_blue_dice_effect(dice_values: Array, dice_colors: Array, used_indices: Array, base_score: int, test_name: String) -> void:
	_log_info("  Dice values: %s" % str(dice_values))
	_log_info("  Dice colors: %s" % _format_colors(dice_colors))
	_log_info("  Used indices: %s" % str(used_indices))
	_log_info("  Base score: %d" % base_score)
	
	# Calculate Blue dice effects manually for validation
	var blue_multiplier = 1.0
	var blue_divisor = 1.0
	var blue_used_count = 0
	var blue_unused_count = 0
	
	for i in range(dice_colors.size()):
		if dice_colors[i] == DiceColor.Type.BLUE:
			if used_indices.has(i):
				blue_multiplier *= dice_values[i]
				blue_used_count += 1
				_log_info("  Blue die at index %d (value %d) is USED -> multiply by %d" % [i, dice_values[i], dice_values[i]])
			else:
				blue_divisor *= dice_values[i]
				blue_unused_count += 1
				_log_info("  Blue die at index %d (value %d) is NOT USED -> divide by %d" % [i, dice_values[i], dice_values[i]])
	
	# Check for same color bonus (all 5 dice are blue)
	var all_blue = true
	for c in dice_colors:
		if c != DiceColor.Type.BLUE:
			all_blue = false
			break
	
	if all_blue:
		_log_info("  SAME COLOR BONUS: All dice are Blue - effects doubled!")
		blue_multiplier *= 2.0
		blue_divisor *= 2.0
	
	# Calculate final score
	var final_score = base_score
	if blue_multiplier > 1.0:
		final_score = int(final_score * blue_multiplier)
		_log_result("  Applied Blue multiplier: %d × %.0f = %d" % [base_score, blue_multiplier, final_score])
	if blue_divisor > 1.0:
		var pre_div_score = final_score
		final_score = int(final_score / blue_divisor)
		_log_result("  Applied Blue divisor: %d ÷ %.0f = %d (rounded down)" % [pre_div_score, blue_divisor, final_score])
	
	_log_result("Results for '%s':" % test_name)
	_log_result("  Blue dice USED (multiply): %d" % blue_used_count)
	_log_result("  Blue dice NOT USED (divide): %d" % blue_unused_count)
	_log_result("  Final score: %d -> %d" % [base_score, final_score])


## _validate_color_test()
##
## Validates test results against expected values and logs pass/fail.
func _validate_color_test(test_name: String, effects: Dictionary, _dice_values: Array, _dice_colors: Array) -> void:
	var passed = true
	var issues = []
	
	match test_name:
		"green_single":
			# First die (value 3) is green, should give $3
			if effects.get("green_money", 0) != 3:
				passed = false
				issues.append("Expected green_money=3, got %d" % effects.get("green_money", 0))
		
		"green_multiple":
			# Values 2, 4, 6 are green = $12
			if effects.get("green_money", 0) != 12:
				passed = false
				issues.append("Expected green_money=12, got %d" % effects.get("green_money", 0))
		
		"green_all":
			# All green, values 1+2+3+4+5 = $15, doubled for same color = $30
			var expected = 30
			if effects.get("green_money", 0) != expected:
				passed = false
				issues.append("Expected green_money=%d (same color bonus), got %d" % [expected, effects.get("green_money", 0)])
		
		"red_single":
			# Second die (value 4) is red, should add 4
			if effects.get("red_additive", 0) != 4:
				passed = false
				issues.append("Expected red_additive=4, got %d" % effects.get("red_additive", 0))
		
		"red_multiple":
			# Values 5, 5 are red = +10
			if effects.get("red_additive", 0) != 10:
				passed = false
				issues.append("Expected red_additive=10, got %d" % effects.get("red_additive", 0))
		
		"red_all":
			# All red, 6×5 = 30, doubled for same color = 60
			var expected = 60
			if effects.get("red_additive", 0) != expected:
				passed = false
				issues.append("Expected red_additive=%d (same color bonus), got %d" % [expected, effects.get("red_additive", 0)])
		
		"purple_single":
			# Fifth die (value 2) is purple, multiplier = 2.0
			if abs(effects.get("purple_multiplier", 1.0) - 2.0) > 0.01:
				passed = false
				issues.append("Expected purple_multiplier=2.0, got %.2f" % effects.get("purple_multiplier", 1.0))
		
		"purple_multiple":
			# Values 2, 3 are purple, multiplier = 2 × 3 = 6.0
			if abs(effects.get("purple_multiplier", 1.0) - 6.0) > 0.01:
				passed = false
				issues.append("Expected purple_multiplier=6.0, got %.2f" % effects.get("purple_multiplier", 1.0))
		
		"purple_all":
			# All purple, 2^5 = 32, doubled for same color = 64
			var expected = 64.0
			if abs(effects.get("purple_multiplier", 1.0) - expected) > 0.01:
				passed = false
				issues.append("Expected purple_multiplier=%.0f (same color bonus), got %.2f" % [expected, effects.get("purple_multiplier", 1.0)])
	
	if passed:
		_log_pass("PASS: %s" % test_name)
	else:
		_log_fail("FAIL: %s" % test_name)
		for issue in issues:
			_log_fail("  - %s" % issue)


## _format_colors()
##
## Formats dice colors array for display.
func _format_colors(colors: Array) -> String:
	var names = []
	for c in colors:
		names.append(DiceColor.get_color_name(c))
	return str(names)


## _clear_log()
##
## Clears all log entries.
func _clear_log() -> void:
	if log_container:
		for child in log_container.get_children():
			child.queue_free()


## Logging helper functions
func _log_header(text: String) -> void:
	_add_log_label(text, Color(1, 1, 0))  # Yellow
	print(text)

func _log_test(text: String) -> void:
	_add_log_label(text, Color(0.7, 0.7, 1))  # Light blue
	print(text)

func _log_info(text: String) -> void:
	_add_log_label(text, Color(0.8, 0.8, 0.8))  # Light gray
	print(text)

func _log_result(text: String) -> void:
	_add_log_label(text, Color(0.5, 1, 0.5))  # Light green
	print(text)

func _log_pass(text: String) -> void:
	_add_log_label(text, Color(0, 1, 0))  # Green
	print(text)

func _log_fail(text: String) -> void:
	_add_log_label(text, Color(1, 0, 0))  # Red
	print(text)

func _add_log_label(text: String, color: Color) -> void:
	if not log_container:
		return
	
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	if vcr_font:
		label.add_theme_font_override("font", vcr_font)
		label.add_theme_font_size_override("font_size", 12)
	log_container.add_child(label)
