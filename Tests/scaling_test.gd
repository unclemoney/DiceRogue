extends Control

## ScalingTest
##
## Test scene for verifying that the Upper Section Bonus and Goof-Off Meter
## thresholds are FLAT across rounds (round-based scaling was removed).
##
## Tests:
## 1. Upper Section Bonus threshold stays at base (63) every round
## 2. Upper Section Bonus amount stays at base (35) every round
## 3. Goof-Off Meter max progress stays at 100 every round
## 4. Bonus trigger when threshold is met (not requiring completion)
## 5. Progress clamping when round changes

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
	if OS.get_cmdline_user_args().has("--quit-after"):
		await get_tree().create_timer(0.2).timeout
		get_tree().quit()


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
	title.text = "Scaling Test - Flat Values (No Round Scaling)"
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
	var results: Array[bool] = []
	
	# Test 1: Upper Bonus Threshold (flat)
	_output_label.text += "[color=#ffcc00]Test 1: Upper Bonus Threshold (flat at 63, no round scaling)[/color]\n"
	var expected_thresholds = [63, 63, 63, 63, 63, 63, 63, 63, 63, 63]
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
	results.append(all_passed)
	
	# Test 2: Upper Bonus Amount (flat)
	_output_label.text += "[color=#ffcc00]Test 2: Upper Bonus Amount (flat at 35, no round scaling)[/color]\n"
	var expected_amounts = [35, 35, 35, 35, 35, 35, 35, 35, 35, 35]
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
	results.append(all_passed)
	
	# Test 3: Goof-Off Meter Max (flat)
	_output_label.text += "[color=#88ff88]Test 3: Goof-Off Meter Max Progress (flat at 100, no round scaling)[/color]\n"
	var expected_max_progress = [100, 100, 100, 100, 100, 100, 100, 100, 100, 100]
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
	results.append(all_passed)
	
	_output_label.text += "[b]All tests complete![/b]\n"
	print("[ScalingTest] Test1 UpperBonusThreshold: %s" % ("PASS" if results[0] else "FAIL"))
	print("[ScalingTest] Test2 UpperBonusAmount: %s" % ("PASS" if results[1] else "FAIL"))
	print("[ScalingTest] Test3 GoofOffMeterMax: %s" % ("PASS" if results[2] else "FAIL"))


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
	
	# Max is flat at 100, so 90 progress is untouched on round change
	mock_chores_manager.update_round(5)
	_output_label.text += "After Round 5: Progress = %d, Max = %d\n" % [mock_chores_manager.current_progress, mock_chores_manager.get_scaled_max_progress()]
	_output_label.text += "  (Should remain 90 since max is flat at 100)\n\n"
	
	# Edge case: progress at the cap gets clamped to max-1
	mock_chores_manager.current_round_number = 1
	mock_chores_manager.current_progress = 100
	
	_output_label.text += "Starting: Round 1, Progress = 100, Max = %d\n" % mock_chores_manager.get_scaled_max_progress()
	
	mock_chores_manager.update_round(10)
	_output_label.text += "After Round 10: Progress = %d, Max = %d\n" % [mock_chores_manager.current_progress, mock_chores_manager.get_scaled_max_progress()]
	_output_label.text += "  (Should be clamped to max-1 = 99)\n"


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
		return UPPER_BONUS_THRESHOLD
	
	func get_scaled_upper_bonus_amount() -> int:
		return UPPER_BONUS_AMOUNT
	
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
		return MAX_PROGRESS
