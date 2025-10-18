extends Node

## PinHeadQuickTest  
## Simple test to verify PinHeadPowerUp is working correctly with fixes

var game_controller: GameController
var dice_hand: DiceHand
var scorecard: Node

func _ready():
	print("\n=== PinHead Quick Verification Test ===")
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	game_controller = get_node("../GameController") as GameController
	dice_hand = get_node("../DiceHand") as DiceHand  
	scorecard = get_node("../ScoreCard")
	
	if not game_controller or not dice_hand or not scorecard:
		push_error("[PinHeadQuickTest] Missing required nodes")
		return
		
	print("[PinHeadQuickTest] Testing autoscoring with multiplier...")
	
	# Test auto scoring with known dice
	test_autoscoring()

func test_autoscoring():
	print("\n--- Testing Auto Scoring ---")
	
	# Reset scorecard
	scorecard.reset_scorecard()
	
	# Disable dice colors to avoid interference 
	DiceColorManager.set_colors_enabled(false)
	
	# Set dice for small straight (1,2,3,4,5) = 30 base points
	var test_dice = [1, 2, 3, 4, 5]
	dice_hand.set_dice_values(test_dice)
	
	print("[PinHeadQuickTest] Set dice values to:", test_dice)
	print("[PinHeadQuickTest] Expected: Small straight base 30, multiplied by random dice value")
	
	# Trigger autoscoring
	scorecard.auto_score_best(test_dice)
	
	# Wait a couple frames for deferred processing
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Check the result
	var final_score = scorecard.get_score(1, "small_straight")  # Section.LOWER = 1
	print("[PinHeadQuickTest] Final score for small_straight:", final_score)
	
	if final_score > 30:
		print("[PinHeadQuickTest] SUCCESS: Multiplier was applied! (", final_score, " > 30)")
		var multiplier = final_score / 30.0
		print("[PinHeadQuickTest] Effective multiplier was:", multiplier)
		
		if multiplier >= 2.0 and multiplier <= 6.0:
			print("[PinHeadQuickTest] PERFECT: Multiplier is within expected range (2-6)")
		else:
			print("[PinHeadQuickTest] WARNING: Multiplier outside expected range")
	else:
		print("[PinHeadQuickTest] FAILED: No multiplier was applied")
		
	# Re-enable dice colors
	DiceColorManager.set_colors_enabled(true)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q:
			print("\n=== Quick Test (Q key pressed) ===")
			test_autoscoring()