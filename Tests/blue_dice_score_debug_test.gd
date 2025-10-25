extends Control
class_name BlueDiceScoreDebugTest

## Test to debug Blue dice scoring issues

@onready var test_label: Label = $VBoxContainer/TestLabel
@onready var debug_button: Button = $VBoxContainer/DebugButton
@onready var results_label: Label = $VBoxContainer/ResultsLabel

func _ready() -> void:
	if test_label:
		test_label.text = "Blue Dice Score Debug Test"
	
	if debug_button:
		debug_button.text = "Test Blue Dice Scoring"
		debug_button.pressed.connect(_on_debug_pressed)
	
	if results_label:
		results_label.text = "Ready to debug Blue dice scoring..."

func _on_debug_pressed() -> void:
	print("\n=== Blue Dice Score Debug Test ===")
	
	# Check if we have access to required systems
	if not DiceColorManager:
		_show_result("✗ DiceColorManager not available")
		return
	
	# Try to access the scorecard
	var scorecard = get_tree().get_first_node_in_group("scorecard")
	if not scorecard:
		_show_result("✗ Scorecard not found")
		return
	
	# Try to access dice hand
	var dice_hand = get_tree().get_first_node_in_group("dice_hand")
	if not dice_hand:
		_show_result("✗ Dice hand not found")
		return
	
	_show_result("✓ All required systems found")
	
	# Test Blue dice color effects calculation
	if dice_hand.has_method("get_color_effects"):
		var color_effects = dice_hand.get_color_effects()
		_show_result("Color effects from dice_hand: " + str(color_effects))
		
		var blue_multiplier = color_effects.get("blue_score_multiplier", 1.0)
		_show_result("Blue score multiplier: " + str(blue_multiplier))
	else:
		_show_result("✗ dice_hand missing get_color_effects method")
	
	# Test scoring calculation
	var test_values = [6, 6, 6, 6, 2]  # Four of a kind
	_show_result("Testing with dice values: " + str(test_values))
	
	if scorecard.has_method("calculate_score_with_breakdown"):
		var breakdown = scorecard.calculate_score_with_breakdown("four_of_a_kind", test_values, false)
		_show_result("Base score: " + str(breakdown.get("base_score", 0)))
		_show_result("Final score: " + str(breakdown.get("final_score", 0)))
		
		var breakdown_info = breakdown.get("breakdown_info", {})
		var blue_mult = breakdown_info.get("blue_score_multiplier", 1.0)
		_show_result("Blue multiplier in breakdown: " + str(blue_mult))
	else:
		_show_result("✗ scorecard missing calculate_score_with_breakdown method")

func _show_result(message: String) -> void:
	print("[BlueDiceScoreDebugTest] " + message)
	if results_label:
		results_label.text += message + "\n"