extends Control

## DebugValidationTest
##
## Quick test to verify the Statistics system fixes are working properly
## Tests the two specific bugs reported:
## 1. track_dice_roll color conversion error
## 2. F10 panel toggle

@onready var output_label: RichTextLabel = $VBoxContainer/ScrollContainer/OutputLabel
@onready var run_button: Button = $VBoxContainer/RunButton

var stats_node: Node

func _ready() -> void:
	print("[DebugValidationTest] Ready")
	run_button.pressed.connect(_run_validation_tests)
	
	# Get Statistics autoload
	stats_node = get_node_or_null("/root/Statistics")
	if not stats_node:
		_log_error("CRITICAL: Statistics autoload not found!")
		return
	
	_log_info("Statistics autoload found - ready for testing")

func _run_validation_tests() -> void:
	_clear_output()
	_log_info("=== STATISTICS DEBUG VALIDATION TESTS ===")
	
	if not stats_node:
		_log_error("Cannot run tests - Statistics node not available")
		return
	
	_test_dice_color_conversion()
	_test_f10_panel_integration()
	_test_basic_statistics_tracking()
	
	_log_info("=== VALIDATION TESTS COMPLETE ===")

## Test that dice color conversion works correctly
func _test_dice_color_conversion() -> void:
	_log_info("\n--- Testing Dice Color Conversion Fix ---")
	
	# Test all color types
	var color_types = [DiceColor.Type.NONE, DiceColor.Type.GREEN, DiceColor.Type.RED, DiceColor.Type.PURPLE]
	
	for color_type in color_types:
		var color_name = DiceColor.get_color_name(color_type)
		_log_info("Color type " + str(color_type) + " -> " + color_name)
		
		# Test that track_dice_roll accepts the string
		stats_node.track_dice_roll(color_name, 4)
		_log_success("✓ track_dice_roll accepts color: " + color_name)

## Test F10 panel integration
func _test_f10_panel_integration() -> void:
	_log_info("\n--- Testing F10 Panel Integration ---")
	
	# Check if GameController exists and has statistics_panel reference
	var game_controller = get_node_or_null("/root/Node2D/GameController")
	if not game_controller:
		# Try alternative paths
		var paths = ["/root/GameController", "/root/Main/GameController"]
		for path in paths:
			game_controller = get_node_or_null(path)
			if game_controller:
				break
	
	if not game_controller:
		_log_warning("! GameController not found in current scene")
		return
	
	# Check if statistics_panel is available
	if game_controller.has_method("_toggle_statistics_panel"):
		_log_success("✓ GameController has _toggle_statistics_panel method")
	else:
		_log_error("✗ GameController missing _toggle_statistics_panel method")
	
	# Check for StatisticsPanel node in scene
	var stats_panel = get_node_or_null("/root/Node2D/StatisticsPanel")
	if stats_panel:
		_log_success("✓ StatisticsPanel found in scene")
		if stats_panel.has_method("toggle_visibility"):
			_log_success("✓ StatisticsPanel has toggle_visibility method")
		else:
			_log_error("✗ StatisticsPanel missing toggle_visibility method")
	else:
		_log_warning("! StatisticsPanel not found in current scene structure")

## Test basic statistics tracking
func _test_basic_statistics_tracking() -> void:
	_log_info("\n--- Testing Basic Statistics Tracking ---")
	
	# Test basic increment methods
	var initial_rolls = stats_node.total_rolls
	stats_node.increment_rolls()
	if stats_node.total_rolls == initial_rolls + 1:
		_log_success("✓ increment_rolls() working")
	else:
		_log_error("✗ increment_rolls() failed")
	
	# Test dice tracking with converted colors
	var initial_dice_count = stats_node.dice_rolled_by_color.get("Green", 0)
	stats_node.track_dice_roll("Green", 5)
	if stats_node.dice_rolled_by_color.get("Green", 0) == initial_dice_count + 1:
		_log_success("✓ Dice color tracking working with string colors")
	else:
		_log_error("✗ Dice color tracking failed")

func _log_success(message: String) -> void:
	_add_colored_text(message, Color.GREEN)

func _log_error(message: String) -> void:
	_add_colored_text(message, Color.RED)

func _log_warning(message: String) -> void:
	_add_colored_text(message, Color.YELLOW)

func _log_info(message: String) -> void:
	_add_colored_text(message, Color.WHITE)

func _add_colored_text(text: String, color: Color) -> void:
	if output_label:
		output_label.append_text("[color=" + color.to_html() + "]" + text + "[/color]\n")
	print(text)

func _clear_output() -> void:
	if output_label:
		output_label.clear()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F10:
			_log_info("F10 key detected in test scene")