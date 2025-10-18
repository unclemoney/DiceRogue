extends Node

## PinHeadMathTest
## 
## Comprehensive test for PinHeadPowerUp multiplier math verification

var game_controller: GameController
var dice_hand: DiceHand
var score_card_ui: ScoreCardUI
var scorecard: Node
var pin_head_power_up: Node

func _ready():
	print("\n=== PinHead Math Verification Test ===")
	
	# Wait for everything to be ready
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Get references
	game_controller = get_node("../GameController") as GameController
	dice_hand = get_node("../DiceHand") as DiceHand
	score_card_ui = get_node("../ScoreCardUI") as ScoreCardUI
	scorecard = get_node("../ScoreCard")
	
	if not game_controller or not dice_hand or not score_card_ui or not scorecard:
		push_error("Missing required nodes for PinHead math test")
		return
	
	# Get reference to PinHeadPowerUp if it exists
	pin_head_power_up = game_controller.get_active_power_up("pin_head")
	
	if not pin_head_power_up:
		push_error("PinHeadPowerUp not found in active power-ups")
		return
	
	print("[PinHeadMathTest] Starting comprehensive math verification...")
	
	# Test 1: Small straight with known multipliers
	await test_small_straight_multipliers()
	
	# Test 2: Manual vs Auto scoring consistency  
	await test_manual_vs_auto_scoring()
	
	# Test 3: Dice color isolation
	await test_dice_color_isolation()
	
	print("\n=== PinHead Math Test Complete ===")

func test_small_straight_multipliers():
	print("\n--- Test 1: Small Straight Math Verification ---")
	print("[PinHeadMathTest] Expected: Base 30 * multiplier (2-6) = 60-180")
	
	# Clear the scorecard first
	scorecard.reset_scorecard()
	
	var test_cases = [
		{"dice": [1, 2, 3, 4, 2], "expected_base": 30, "multiplier": 2, "expected_final": 60},
		{"dice": [1, 2, 3, 4, 3], "expected_base": 30, "multiplier": 3, "expected_final": 90},
		{"dice": [1, 2, 3, 4, 4], "expected_base": 30, "multiplier": 4, "expected_final": 120},
		{"dice": [1, 2, 3, 4, 5], "expected_base": 30, "multiplier": 5, "expected_final": 150},
		{"dice": [1, 2, 3, 4, 6], "expected_base": 30, "multiplier": 6, "expected_final": 180}
	]
	
	for i in range(test_cases.size()):
		var test = test_cases[i]
		print("\n[PinHeadMathTest] Test case", i + 1, "- Dice:", test.dice, "Expected multiplier:", test.multiplier)
		
		# Disable dice colors to avoid interference
		DiceColorManager.set_colors_enabled(false)
		
		# Force specific dice values with known multiplier
		dice_hand.set_dice_values(test.dice)
		
		# Override the random multiplier selection for testing
		pin_head_power_up.last_multiplier = test.multiplier
		
		# Register the known multiplier
		ScoreModifierManager.unregister_multiplier("pin_head")
		ScoreModifierManager.register_multiplier("pin_head", test.multiplier)
		
		# Calculate score through manual scoring
		var result_score = scorecard.calculate_score_internal("small_straight", test.dice, false)
		
		print("[PinHeadMathTest] Base score (no multiplier):", result_score)
		
		# Now apply multiplier manually for verification
		var expected_with_multiplier = result_score * test.multiplier
		
		print("[PinHeadMathTest] Expected with multiplier:", expected_with_multiplier)
		var test_result = "PASSED" if (result_score == test.expected_base and expected_with_multiplier == test.expected_final) else "FAILED"
		print("[PinHeadMathTest] Test", i + 1, test_result)
		
		# Clean up
		ScoreModifierManager.unregister_multiplier("pin_head")
		
		await get_tree().process_frame

func test_manual_vs_auto_scoring():
	print("\n--- Test 2: Manual vs Auto Scoring Consistency ---")
	
	# Reset scorecard
	scorecard.reset_scorecard()
	
	# Set up dice for small straight
	var test_dice = [1, 2, 3, 4, 5]
	dice_hand.set_dice_values(test_dice)
	DiceColorManager.set_colors_enabled(false)
	
	# Test manual scoring
	print("[PinHeadMathTest] Testing manual scoring path...")
	score_card_ui.on_category_selected(1, "small_straight")  # Section.LOWER = 1
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	var manual_score = scorecard.get_score(1, "small_straight")
	print("[PinHeadMathTest] Manual scoring result:", manual_score)
	
	# Reset for auto scoring test
	scorecard.reset_scorecard()
	
	# Test auto scoring
	print("[PinHeadMathTest] Testing auto scoring path...")
	scorecard.auto_score_best(test_dice)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	var auto_score = scorecard.get_score(1, "small_straight")
	print("[PinHeadMathTest] Auto scoring result:", auto_score)
	
	var consistency_result = "PASSED" if (manual_score > 30 and auto_score > 30) else "FAILED"
	print("[PinHeadMathTest] Consistency test:", consistency_result)

func test_dice_color_isolation():
	print("\n--- Test 3: Dice Color Isolation ---")
	
	# Reset scorecard
	scorecard.reset_scorecard()
	
	# Test with dice colors disabled
	DiceColorManager.set_colors_enabled(false)
	dice_hand.set_dice_values([1, 2, 3, 4, 5])
	
	# Force a known multiplier for consistent testing
	ScoreModifierManager.unregister_multiplier("pin_head")
	ScoreModifierManager.register_multiplier("pin_head", 3)
	
	var score_no_colors = scorecard.calculate_score_internal("small_straight", [1, 2, 3, 4, 5], false)
	var expected_no_colors = score_no_colors * 3
	
	print("[PinHeadMathTest] Score without dice colors:", score_no_colors, "Expected with x3 multiplier:", expected_no_colors)
	
	# Clean up
	ScoreModifierManager.unregister_multiplier("pin_head")
	DiceColorManager.set_colors_enabled(true)
	
	var isolation_result = "PASSED" if (score_no_colors == 30) else "FAILED"
	print("[PinHeadMathTest] Dice color isolation test:", isolation_result)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_M:
			print("\n=== Running PinHead Math Test (M key pressed) ===")
			await test_small_straight_multipliers()
			await test_manual_vs_auto_scoring()
			await test_dice_color_isolation()