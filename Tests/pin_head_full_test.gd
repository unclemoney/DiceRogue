extends Node

## PinHeadFullTest
## 
## Comprehensive test for PinHeadPowerUp with both manual and autoscoring

var game_controller: GameController
var dice_hand: DiceHand
var score_card_ui: ScoreCardUI
var scorecard: Node

func _ready():
	print("\n=== PinHead Full Functionality Test ===")
	
	# Get references
	game_controller = get_node("../GameController") as GameController
	dice_hand = get_node("../DiceHand") as DiceHand
	score_card_ui = get_node("../ScoreCardUI") as ScoreCardUI
	scorecard = get_node("../ScoreCard")
	
	if not game_controller or not dice_hand or not score_card_ui or not scorecard:
		push_error("Missing required nodes for PinHead test")
		return
	
	# Wait for everything to be ready
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("[PinHeadFullTest] Starting test sequence...")
	
	# Test 1: Manual scoring through ScoreCardUI
	await test_manual_scoring()
	
	# Test 2: Auto scoring through scorecard
	await test_auto_scoring()
	
	print("\n=== PinHead Full Test Complete ===")

func test_manual_scoring():
	print("\n--- Test 1: Manual Scoring ---")
	
	# Set up dice values
	dice_hand.set_dice_values([3, 4, 4, 4, 5])  # Good for four of a kind
	print("[PinHeadFullTest] Set dice to [3, 4, 4, 4, 5]")
	
	# Manually trigger scoring through ScoreCardUI
	print("[PinHeadFullTest] Triggering manual score through ScoreCardUI.on_category_selected...")
	score_card_ui.on_category_selected(Scorecard.Section.LOWER, "four_of_a_kind")
	
	await get_tree().process_frame
	print("[PinHeadFullTest] Manual scoring test complete")

func test_auto_scoring():
	print("\n--- Test 2: Auto Scoring ---")
	
	# Set up different dice values
	dice_hand.set_dice_values([1, 2, 3, 4, 5])  # Large straight = 40 points
	print("[PinHeadFullTest] Set dice to [1, 2, 3, 4, 5]")
	
	# Trigger auto scoring through scorecard.auto_score_best
	print("[PinHeadFullTest] Triggering auto score through scorecard.auto_score_best...")
	scorecard.auto_score_best([1, 2, 3, 4, 5])
	
	await get_tree().process_frame
	print("[PinHeadFullTest] Auto scoring test complete")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			print("\n=== Running PinHead Test (T key pressed) ===")
			await test_manual_scoring()
			await test_auto_scoring()