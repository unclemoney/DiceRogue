extends Control
class_name MultiplierManagerDiceTest

## Test to verify dice color effects are properly registered with MultiplierManager

@onready var test_label: Label = $VBoxContainer/TestLabel
@onready var test_button: Button = $VBoxContainer/TestButton
@onready var debug_button: Button = $VBoxContainer/DebugButton
@onready var results_label: Label = $VBoxContainer/ResultsLabel

func _ready() -> void:
	if test_label:
		test_label.text = "MultiplierManager Dice Integration Test"
	
	if test_button:
		test_button.text = "Test Blue Dice Registration"
		test_button.pressed.connect(_on_test_pressed)
	
	if debug_button:
		debug_button.text = "Show MultiplierManager State"
		debug_button.pressed.connect(_on_debug_pressed)
	
	if results_label:
		results_label.text = "Ready to test MultiplierManager integration..."

func _on_test_pressed() -> void:
	print("[MultiplierManagerDiceTest] Testing dice color registration...")
	
	if not DiceColorManager:
		_show_result("✗ DiceColorManager not available")
		return
	
	if not ScoreModifierManager:
		_show_result("✗ ScoreModifierManager not available")
		return
	
	# Clear any existing effects first
	DiceColorManager.clear_color_effects()
	
	# Simulate calculating blue dice effects directly
	# Create a mock effects dictionary for testing
	var test_effects = {
		"green_money": 0,
		"red_additive": 0,
		"purple_multiplier": 1.0,
		"blue_score_multiplier": 1.5,  # Simulate blue dice multiplier
		"same_color_bonus": false,
		"rainbow_bonus": false,
		"yellow_scored": false,
		"yellow_count": 0,
		"green_count": 0,
		"red_count": 0,
		"purple_count": 0,
		"blue_count": 3  # Simulate 3 blue dice
	}
	
	# Manually call the registration method to test it
	DiceColorManager._register_color_effects_with_manager(test_effects)
	
	_show_result("✓ Manually registered blue dice effects")
	_show_result("Blue multiplier: " + str(test_effects.get("blue_score_multiplier", 1.0)))
	
	# Check if effects are registered
	var has_blue_multiplier = ScoreModifierManager.has_multiplier("blue_dice")
	if has_blue_multiplier:
		var blue_mult = ScoreModifierManager.get_multiplier("blue_dice")
		_show_result("✓ Blue dice registered with MultiplierManager: ×" + str(blue_mult))
	else:
		_show_result("✗ Blue dice NOT registered with MultiplierManager")

func _on_debug_pressed() -> void:
	print("[MultiplierManagerDiceTest] Showing MultiplierManager state...")
	
	if ScoreModifierManager:
		ScoreModifierManager.debug_print_state()
		_show_result("✓ MultiplierManager state printed to console")
		
		# Show active sources
		var active_sources = ScoreModifierManager.get_active_sources()
		_show_result("Active multiplier sources: " + str(active_sources))
		
		var active_additives = ScoreModifierManager.get_active_additive_sources()
		_show_result("Active additive sources: " + str(active_additives))
	else:
		_show_result("✗ ScoreModifierManager not available")

func _show_result(message: String) -> void:
	print("[MultiplierManagerDiceTest] " + message)
	if results_label:
		results_label.text += message + "\n"