extends Node

class_name PinHeadTest

## Test scene for PinHeadPowerUp functionality
## Verifies that random dice multiplier is applied correctly to scored hands

@onready var dice_hand: DiceHand = $DiceHand
@onready var scorecard: Scorecard = $ScoreCard
@onready var score_card_ui: ScoreCardUI = $ScoreCardUI
@onready var game_controller: GameController = $GameController
@onready var pin_head_power_up: Node = $PinHeadPowerUp

var test_results: Array[String] = []

func _ready():
	print("=== PinHead PowerUp Test Starting ===")
	
	# Wait a frame for everything to initialize
	await get_tree().process_frame
	
	# Run test sequence
	await _run_tests()
	
	# Print results
	_print_test_results()

func _run_tests():
	test_results.clear()
	
	# Test 1: Check if PowerUp is properly initialized
	await _test_power_up_initialization()
	
	# Test 2: Check signal connections
	await _test_signal_connections()
	
	# Test 3: Test multiplier application
	await _test_multiplier_application()
	
	# Test 4: Test cleanup
	await _test_cleanup()

func _test_power_up_initialization():
	print("\n--- Test 1: PowerUp Initialization ---")
	
	if pin_head_power_up == null:
		test_results.append("❌ FAIL: PinHeadPowerUp not found")
		return
	
	# Apply the PowerUp
	pin_head_power_up.apply()
	await get_tree().process_frame
	
	test_results.append("✅ PASS: PowerUp initialized and applied")

func _test_signal_connections():
	print("\n--- Test 2: Signal Connections ---")
	
	# Check if about_to_score signal exists and is connected
	var about_to_score_connected = score_card_ui.about_to_score.is_connected(pin_head_power_up._on_about_to_score)
	
	if about_to_score_connected:
		test_results.append("✅ PASS: about_to_score signal connected")
	else:
		test_results.append("❌ FAIL: about_to_score signal not connected")
	
	# Check if score_assigned signal is connected
	var score_assigned_connected = score_card_ui.score_assigned.is_connected(pin_head_power_up._on_score_assigned)
	
	if score_assigned_connected:
		test_results.append("✅ PASS: score_assigned signal connected")
	else:
		test_results.append("❌ FAIL: score_assigned signal not connected")

func _test_multiplier_application():
	print("\n--- Test 3: Multiplier Application ---")
	
	# Set up test dice hand
	dice_hand.dice_values = [1, 2, 3, 4, 5]  # Small straight
	
	# Store initial score modifier state
	var initial_multipliers = ScoreModifierManager.get_multipliers()
	print("Initial multipliers: ", initial_multipliers)
	
	# Simulate the about_to_score signal
	score_card_ui.about_to_score.emit("upper", "ones", dice_hand.dice_values)
	await get_tree().process_frame
	
	# Check if multiplier was registered
	var post_signal_multipliers = ScoreModifierManager.get_multipliers()
	print("Post-signal multipliers: ", post_signal_multipliers)
	
	if post_signal_multipliers.has("pin_head"):
		var multiplier_value = post_signal_multipliers["pin_head"]
		if multiplier_value >= 1 and multiplier_value <= 6:
			test_results.append("✅ PASS: Multiplier registered with valid dice value: " + str(multiplier_value))
		else:
			test_results.append("❌ FAIL: Multiplier value out of range: " + str(multiplier_value))
	else:
		test_results.append("❌ FAIL: No multiplier registered after about_to_score signal")
	
	# Test actual scoring with multiplier
	var base_score = scorecard.calculate_score("ones", dice_hand.dice_values)
	print("Base score (ones): ", base_score)
	print("Expected multiplied score: ", base_score * post_signal_multipliers.get("pin_head", 1))
	
	test_results.append("ℹ️  INFO: Base score for 'ones' with dice [1,2,3,4,5]: " + str(base_score))
	if post_signal_multipliers.has("pin_head"):
		test_results.append("ℹ️  INFO: Random dice multiplier: " + str(post_signal_multipliers["pin_head"]))

func _test_cleanup():
	print("\n--- Test 4: Cleanup ---")
	
	# Remove the PowerUp
	pin_head_power_up.remove()
	await get_tree().process_frame
	
	# Check if multiplier was cleared
	var final_multipliers = ScoreModifierManager.get_multipliers()
	print("Final multipliers: ", final_multipliers)
	
	if not final_multipliers.has("pin_head"):
		test_results.append("✅ PASS: Multiplier properly cleaned up")
	else:
		test_results.append("❌ FAIL: Multiplier not cleaned up")

func _print_test_results():
	print("\n=== PinHead PowerUp Test Results ===")
	for result in test_results:
		print(result)
	print("=== Test Complete ===")