extends Control

## StatisticsComprehensiveTest
##
## Complete test suite for the Statistics system including:
## - Basic functionality test
## - UI panel test 
## - Integration test with game systems
## - Milestone and achievement testing

@onready var test_output: RichTextLabel = $VBoxContainer/ScrollContainer/TestOutput
@onready var run_button: Button = $VBoxContainer/RunTestsButton
@onready var clear_button: Button = $VBoxContainer/ClearOutputButton

var stats_node: Node
var test_results: Array[String] = []

func _ready() -> void:
	print("[StatisticsComprehensiveTest] Ready")
	run_button.pressed.connect(_run_all_tests)
	clear_button.pressed.connect(_clear_output)
	
	# Get reference to Statistics autoload
	stats_node = get_node_or_null("/root/Statistics")
	if not stats_node:
		_log_error("CRITICAL: Statistics autoload not found!")
		return
	
	_log_info("Statistics autoload found - ready for testing")

func _run_all_tests() -> void:
	_clear_output()
	_log_info("=== STATISTICS COMPREHENSIVE TEST SUITE ===")
	
	if not stats_node:
		_log_error("Cannot run tests - Statistics node not available")
		return
	
	_test_basic_functionality()
	_test_dice_tracking()
	_test_money_tracking()
	_test_milestone_system()
	_test_statistics_ui()
	_test_data_persistence()
	
	_log_info("=== TEST SUITE COMPLETE ===")
	_summarize_results()

func _test_basic_functionality() -> void:
	_log_info("\n--- Testing Basic Functionality ---")
	
	# Test initial values
	if stats_node.total_rolls == 0:
		_log_success("✓ Initial total_rolls is 0")
	else:
		_log_error("✗ Initial total_rolls should be 0, got: " + str(stats_node.total_rolls))
	
	# Test increment methods
	var initial_rolls = stats_node.total_rolls
	stats_node.increment_rolls()
	if stats_node.total_rolls == initial_rolls + 1:
		_log_success("✓ increment_rolls() working")
	else:
		_log_error("✗ increment_rolls() failed")
	
	var initial_turns = stats_node.total_turns
	stats_node.increment_turns()
	if stats_node.total_turns == initial_turns + 1:
		_log_success("✓ increment_turns() working")
	else:
		_log_error("✗ increment_turns() failed")

func _test_dice_tracking() -> void:
	_log_info("\n--- Testing Dice Tracking ---")
	
	# Test dice value tracking
	var initial_ones = stats_node.dice_values.get(1, 0)
	stats_node.track_dice_roll("white", 1)
	if stats_node.dice_values.get(1, 0) == initial_ones + 1:
		_log_success("✓ Dice value tracking working")
	else:
		_log_error("✗ Dice value tracking failed")
	
	# Test color tracking
	var initial_white = stats_node.dice_colors.get("white", 0)
	stats_node.track_dice_roll("white", 3)
	if stats_node.dice_colors.get("white", 0) == initial_white + 1:
		_log_success("✓ Dice color tracking working")
	else:
		_log_error("✗ Dice color tracking failed")
	
	# Test snake eyes detection
	var initial_snake_eyes = stats_node.snake_eyes_count
	stats_node.check_snake_eyes([1, 1, 1, 1, 1])
	if stats_node.snake_eyes_count == initial_snake_eyes + 1:
		_log_success("✓ Snake eyes detection working")
	else:
		_log_error("✗ Snake eyes detection failed")

func _test_money_tracking() -> void:
	_log_info("\n--- Testing Money Tracking ---")
	
	# Test money earned tracking
	var initial_earned = stats_node.total_money_earned
	stats_node.add_money_earned(100)
	if stats_node.total_money_earned == initial_earned + 100:
		_log_success("✓ Money earned tracking working")
	else:
		_log_error("✗ Money earned tracking failed")
	
	# Test money spent tracking
	var initial_spent = stats_node.total_money_spent
	stats_node.spend_money(50, "power_up")
	if stats_node.total_money_spent == initial_spent + 50:
		_log_success("✓ Money spent tracking working")
	else:
		_log_error("✗ Money spent tracking failed")

func _test_milestone_system() -> void:
	_log_info("\n--- Testing Milestone System ---")
	
	# Set up milestone that should trigger
	stats_node.total_rolls = 9  # Just below milestone
	
	# Connect to milestone signal
	if not stats_node.is_connected("milestone_reached", _on_milestone_reached):
		stats_node.milestone_reached.connect(_on_milestone_reached)
	
	# Trigger milestone
	stats_node.increment_rolls()  # Should trigger "first_10_rolls" milestone
	
	# Allow a frame for signal processing
	await get_tree().process_frame
	
	# Check if milestone was recorded (we'll verify in the signal handler)
	_log_info("Milestone system test completed (check signal output)")

func _on_milestone_reached(milestone_name: String, description: String) -> void:
	_log_success("✓ Milestone triggered: " + milestone_name + " - " + description)

func _test_statistics_ui() -> void:
	_log_info("\n--- Testing Statistics UI ---")
	
	# Try to find and test the statistics panel
	var stats_panel = get_node_or_null("/root/Game/StatisticsPanel")
	if not stats_panel:
		# Try alternative paths
		var possible_paths = [
			"/root/GameController/StatisticsPanel",
			"/root/Main/StatisticsPanel",
			"../StatisticsPanel"
		]
		
		for path in possible_paths:
			stats_panel = get_node_or_null(path)
			if stats_panel:
				break
	
	if stats_panel:
		_log_success("✓ Statistics panel found")
		if stats_panel.has_method("toggle_visibility"):
			_log_success("✓ Statistics panel has toggle_visibility method")
		else:
			_log_error("✗ Statistics panel missing toggle_visibility method")
	else:
		_log_warning("! Statistics panel not found (may need to be in game scene)")

func _test_data_persistence() -> void:
	_log_info("\n--- Testing Data Persistence ---")
	
	# Test getting formatted data
	var session_data = stats_node.get_session_summary()
	if session_data is Dictionary and session_data.has("total_rolls"):
		_log_success("✓ Session data export working")
	else:
		_log_error("✗ Session data export failed")
	
	# Test statistics calculations
	var favorite_color = stats_node.get_favorite_dice_color()
	_log_info("Favorite dice color: " + str(favorite_color))
	
	var scoring_percentage = stats_node.get_scoring_percentage()
	_log_info("Scoring percentage: " + str(scoring_percentage) + "%")

func _summarize_results() -> void:
	var success_count = 0
	var error_count = 0
	var warning_count = 0
	
	for result in test_results:
		if result.begins_with("✓"):
			success_count += 1
		elif result.begins_with("✗"):
			error_count += 1
		elif result.begins_with("!"):
			warning_count += 1
	
	_log_info("\n=== TEST SUMMARY ===")
	_log_info("Successes: " + str(success_count))
	_log_info("Errors: " + str(error_count))
	_log_info("Warnings: " + str(warning_count))
	
	if error_count == 0:
		_log_success("🎉 ALL CRITICAL TESTS PASSED!")
	else:
		_log_error("❌ " + str(error_count) + " CRITICAL ERRORS FOUND")

func _log_success(message: String) -> void:
	test_results.append(message)
	_add_colored_text(message, Color.GREEN)

func _log_error(message: String) -> void:
	test_results.append(message)
	_add_colored_text(message, Color.RED)

func _log_warning(message: String) -> void:
	test_results.append(message)
	_add_colored_text(message, Color.YELLOW)

func _log_info(message: String) -> void:
	test_results.append(message)
	_add_colored_text(message, Color.WHITE)

func _add_colored_text(text: String, color: Color) -> void:
	if test_output:
		test_output.append_text("[color=" + color.to_html() + "]" + text + "[/color]\n")
	print(text)

func _clear_output() -> void:
	test_results.clear()
	if test_output:
		test_output.clear()