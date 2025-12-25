extends Control

## ScalingTest
##
## Test scene for verifying round-based scaling for Upper Section Bonus
## and Goof-Off Meter thresholds.
##
## Tests:
## 1. Upper Section Bonus scaling (10% per round)
## 2. Goof-Off Meter scaling (5% decrease per round)
## 3. Bonus trigger when threshold is met (not requiring completion)
## 4. Progress clamping when round changes

var _output_label: RichTextLabel
var _round_label: Label
var _current_round: int = 1

# Mock scorecard for testing
var mock_scorecard: MockScorecard
var mock_chores_manager: MockChoresManager


func _ready() -> void:
	_create_ui()
	_initialize_mocks()
	_run_tests()


func _create_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Main container
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	margin.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "Scaling Test - Round-Based Difficulty"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.YELLOW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Round label
	_round_label = Label.new()
	_round_label.text = "Current Round: 1"
	_round_label.add_theme_font_size_override("font_size", 18)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_round_label)
	
	# Button container
	var btn_container = HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_container)
	
	# Round buttons
	for i in range(1, 11):
		var btn = Button.new()
		btn.text = "R%d" % i
		btn.custom_minimum_size = Vector2(50, 40)
		btn.pressed.connect(_on_round_button_pressed.bind(i))
		btn_container.add_child(btn)
	
	# Output label
	_output_label = RichTextLabel.new()
	_output_label.bbcode_enabled = true
	_output_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output_label.add_theme_color_override("default_color", Color.WHITE)
	vbox.add_child(_output_label)
	
	# Test buttons container
	var test_btn_container = HBoxContainer.new()
	test_btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	test_btn_container.add_theme_constant_override("separation", 10)
	vbox.add_child(test_btn_container)
	
	var run_tests_btn = Button.new()
	run_tests_btn.text = "Run All Tests"
	run_tests_btn.custom_minimum_size = Vector2(150, 40)
	run_tests_btn.pressed.connect(_run_tests)
	test_btn_container.add_child(run_tests_btn)
	
	var test_bonus_btn = Button.new()
	test_bonus_btn.text = "Test Bonus Trigger"
	test_bonus_btn.custom_minimum_size = Vector2(150, 40)
	test_bonus_btn.pressed.connect(_test_bonus_trigger)
	test_btn_container.add_child(test_bonus_btn)
	
	var test_clamp_btn = Button.new()
	test_clamp_btn.text = "Test Progress Clamp"
	test_clamp_btn.custom_minimum_size = Vector2(150, 40)
	test_clamp_btn.pressed.connect(_test_progress_clamping)
	test_btn_container.add_child(test_clamp_btn)


func _initialize_mocks() -> void:
	mock_scorecard = MockScorecard.new()
	mock_chores_manager = MockChoresManager.new()


func _on_round_button_pressed(round_number: int) -> void:
	_current_round = round_number
	_round_label.text = "Current Round: %d" % round_number
	mock_scorecard.update_round(round_number)
	mock_chores_manager.update_round(round_number)
	_update_display()


func _update_display() -> void:
	var text = "[b]Current Values (Round %d):[/b]\n\n" % _current_round
	
	text += "[color=#ffcc00]Upper Section Bonus:[/color]\n"
	text += "  Threshold: %d (base: 63)\n" % mock_scorecard.get_scaled_upper_bonus_threshold()
	text += "  Amount: %d (base: 35)\n" % mock_scorecard.get_scaled_upper_bonus_amount()
	text += "  Bonus Awarded: %s\n\n" % str(mock_scorecard.upper_bonus_awarded)
	
	text += "[color=#88ff88]Goof-Off Meter:[/color]\n"
	text += "  Max Progress: %d (base: 100)\n" % mock_chores_manager.get_scaled_max_progress()
	text += "  Current Progress: %d\n\n" % mock_chores_manager.current_progress
	
	_output_label.text = text


func _run_tests() -> void:
	_output_label.text = "[b]Running Scaling Tests...[/b]\n\n"
	
	# Test 1: Upper Bonus Scaling
	_output_label.text += "[color=#ffcc00]Test 1: Upper Bonus Threshold Scaling (10% per round)[/color]\n"
	var expected_thresholds = [63, 70, 77, 85, 93, 103, 113, 124, 137, 150]  # ceil values
	var all_passed = true
	
	for i in range(1, 11):
		mock_scorecard.update_round(i)
		var actual = mock_scorecard.get_scaled_upper_bonus_threshold()
		var expected = expected_thresholds[i - 1]
		var passed = actual == expected
		all_passed = all_passed and passed
		var status = "[color=green]✓[/color]" if passed else "[color=red]✗[/color]"
		_output_label.text += "  Round %d: %d (expected: %d) %s\n" % [i, actual, expected, status]
	
	_output_label.text += "  Result: %s\n\n" % ("[color=green]PASSED[/color]" if all_passed else "[color=red]FAILED[/color]")
	
	# Test 2: Upper Bonus Amount Scaling
	_output_label.text += "[color=#ffcc00]Test 2: Upper Bonus Amount Scaling (10% per round)[/color]\n"
	var expected_amounts = [35, 39, 43, 47, 52, 57, 63, 69, 76, 84]  # ceil values
	all_passed = true
	
	for i in range(1, 11):
		mock_scorecard.update_round(i)
		var actual = mock_scorecard.get_scaled_upper_bonus_amount()
		var expected = expected_amounts[i - 1]
		var passed = actual == expected
		all_passed = all_passed and passed
		var status = "[color=green]✓[/color]" if passed else "[color=red]✗[/color]"
		_output_label.text += "  Round %d: %d (expected: %d) %s\n" % [i, actual, expected, status]
	
	_output_label.text += "  Result: %s\n\n" % ("[color=green]PASSED[/color]" if all_passed else "[color=red]FAILED[/color]")
	
	# Test 3: Goof-Off Meter Scaling
	_output_label.text += "[color=#88ff88]Test 3: Goof-Off Meter Scaling (5% decrease per round)[/color]\n"
	var expected_max_progress = [100, 95, 91, 86, 82, 78, 74, 71, 67, 64]  # ceil values
	all_passed = true
	
	for i in range(1, 11):
		mock_chores_manager.update_round(i)
		var actual = mock_chores_manager.get_scaled_max_progress()
		var expected = expected_max_progress[i - 1]
		var passed = actual == expected
		all_passed = all_passed and passed
		var status = "[color=green]✓[/color]" if passed else "[color=red]✗[/color]"
		_output_label.text += "  Round %d: %d (expected: %d) %s\n" % [i, actual, expected, status]
	
	_output_label.text += "  Result: %s\n\n" % ("[color=green]PASSED[/color]" if all_passed else "[color=red]FAILED[/color]")
	
	_output_label.text += "[b]All tests complete![/b]\n"


func _test_bonus_trigger() -> void:
	_output_label.text = "[b]Testing Bonus Trigger (threshold-based, not completion-based)[/b]\n\n"
	
	mock_scorecard.update_round(1)
	mock_scorecard.upper_bonus_awarded = false
	mock_scorecard.upper_section_total = 0
	
	# Test: Bonus should trigger when threshold is met
	_output_label.text += "Round 1 - Threshold: %d\n" % mock_scorecard.get_scaled_upper_bonus_threshold()
	
	mock_scorecard.upper_section_total = 62
	mock_scorecard.check_upper_bonus()
	_output_label.text += "  Score 62: Bonus awarded = %s (expected: false)\n" % str(mock_scorecard.upper_bonus_awarded)
	
	mock_scorecard.upper_section_total = 63
	mock_scorecard.check_upper_bonus()
	_output_label.text += "  Score 63: Bonus awarded = %s (expected: true)\n" % str(mock_scorecard.upper_bonus_awarded)
	
	# Test at round 5
	mock_scorecard.update_round(5)
	mock_scorecard.upper_bonus_awarded = false
	var threshold_r5 = mock_scorecard.get_scaled_upper_bonus_threshold()
	
	_output_label.text += "\nRound 5 - Threshold: %d\n" % threshold_r5
	
	mock_scorecard.upper_section_total = threshold_r5 - 1
	mock_scorecard.check_upper_bonus()
	_output_label.text += "  Score %d: Bonus awarded = %s (expected: false)\n" % [threshold_r5 - 1, str(mock_scorecard.upper_bonus_awarded)]
	
	mock_scorecard.upper_section_total = threshold_r5
	mock_scorecard.check_upper_bonus()
	_output_label.text += "  Score %d: Bonus awarded = %s (expected: true)\n" % [threshold_r5, str(mock_scorecard.upper_bonus_awarded)]


func _test_progress_clamping() -> void:
	_output_label.text = "[b]Testing Progress Clamping on Round Change[/b]\n\n"
	
	# Start at round 1 with 90 progress
	mock_chores_manager.current_round_number = 1
	mock_chores_manager.current_progress = 90
	
	_output_label.text += "Starting: Round 1, Progress = 90, Max = %d\n" % mock_chores_manager.get_scaled_max_progress()
	
	# Move to round 5 where max is 82
	mock_chores_manager.update_round(5)
	_output_label.text += "After Round 5: Progress = %d, Max = %d\n" % [mock_chores_manager.current_progress, mock_chores_manager.get_scaled_max_progress()]
	_output_label.text += "  (Should be clamped to max-1 = 81)\n\n"
	
	# Reset and test edge case
	mock_chores_manager.current_round_number = 1
	mock_chores_manager.current_progress = 50
	
	_output_label.text += "Starting: Round 1, Progress = 50, Max = %d\n" % mock_chores_manager.get_scaled_max_progress()
	
	mock_chores_manager.update_round(10)
	_output_label.text += "After Round 10: Progress = %d, Max = %d\n" % [mock_chores_manager.current_progress, mock_chores_manager.get_scaled_max_progress()]
	_output_label.text += "  (Should remain 50 since 50 < 64)\n"


# Mock classes for testing without actual game systems
class MockScorecard:
	const UPPER_BONUS_THRESHOLD := 63
	const UPPER_BONUS_AMOUNT := 35
	
	var current_round_number: int = 1
	var upper_bonus_awarded: bool = false
	var upper_bonus: int = 0
	var upper_section_total: int = 0
	
	func update_round(round_number: int) -> void:
		current_round_number = round_number
	
	func get_scaled_upper_bonus_threshold() -> int:
		var scale_factor = pow(1.1, max(0, current_round_number - 1))
		return int(ceil(UPPER_BONUS_THRESHOLD * scale_factor))
	
	func get_scaled_upper_bonus_amount() -> int:
		var scale_factor = pow(1.1, max(0, current_round_number - 1))
		return int(ceil(UPPER_BONUS_AMOUNT * scale_factor))
	
	func check_upper_bonus() -> void:
		var scaled_threshold = get_scaled_upper_bonus_threshold()
		var scaled_amount = get_scaled_upper_bonus_amount()
		
		if upper_section_total >= scaled_threshold and not upper_bonus_awarded:
			upper_bonus = scaled_amount
			upper_bonus_awarded = true


class MockChoresManager:
	const MAX_PROGRESS: int = 100
	
	var current_round_number: int = 1
	var current_progress: int = 0
	
	func update_round(round_number: int) -> void:
		current_round_number = round_number
		var new_threshold = get_scaled_max_progress()
		
		if current_progress >= new_threshold:
			current_progress = max(0, new_threshold - 1)
	
	func get_scaled_max_progress() -> int:
		var scale_factor = pow(0.95, max(0, current_round_number - 1))
		return int(ceil(MAX_PROGRESS * scale_factor))
