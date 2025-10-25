extends Control

## first_yahtzee_bonus_test.gd
## Test to verify that the first Yahtzee scored doesn't trigger a bonus
## This test ensures the bonus system only activates for subsequent Yahtzees

@onready var scorecard = $Scorecard
@onready var results_label = $VBoxContainer/ResultsLabel

func _ready():
	print("\n=== FIRST YAHTZEE BONUS TEST ===")
	
	# Wait for scorecard to be ready
	await get_tree().process_frame
	
	# Test 1: Score first Yahtzee - should NOT trigger bonus
	test_first_yahtzee_no_bonus()
	
	# Test 2: Check bonus for subsequent Yahtzee - SHOULD trigger bonus 
	test_second_yahtzee_with_bonus()

func test_first_yahtzee_no_bonus():
	print("\n--- Test 1: First Yahtzee scored - no bonus ---")
	
	var initial_bonus_count = scorecard.yahtzee_bonuses
	var initial_bonus_points = scorecard.yahtzee_bonus_points
	
	# Create a Yahtzee (five 3s)
	var yahtzee_dice: Array[int] = [3, 3, 3, 3, 3]
	
	print("Initial bonus count:", initial_bonus_count)
	print("Initial bonus points:", initial_bonus_points)
	print("Dice values:", yahtzee_dice)
	
	# Directly set the yahtzee score to 50 (simulating it being scored)
	scorecard.lower_scores["yahtzee"] = 50
	
	# Now call the bonus check with the same category (should NOT trigger bonus)
	scorecard.check_bonus_yahtzee(yahtzee_dice, "yahtzee")
	
	# Check that NO bonus was awarded for the first Yahtzee
	var final_bonus_count = scorecard.yahtzee_bonuses
	var final_bonus_points = scorecard.yahtzee_bonus_points
	
	print("Final bonus count:", final_bonus_count)
	print("Final bonus points:", final_bonus_points)
	
	if final_bonus_count == initial_bonus_count and final_bonus_points == initial_bonus_points:
		print("✓ PASS: First Yahtzee correctly did NOT trigger bonus")
		update_results("Test 1: PASS - First Yahtzee no bonus")
	else:
		print("✗ FAIL: First Yahtzee incorrectly triggered bonus")
		update_results("Test 1: FAIL - First Yahtzee triggered bonus!")

func test_second_yahtzee_with_bonus():
	print("\n--- Test 2: Second Yahtzee in different category ---")
	
	# At this point, we should already have a Yahtzee scored from test 1
	var initial_bonus_count = scorecard.yahtzee_bonuses
	var initial_bonus_points = scorecard.yahtzee_bonus_points
	
	print("Before second Yahtzee - bonus count:", initial_bonus_count)
	print("Before second Yahtzee - bonus points:", initial_bonus_points)
	print("Yahtzee category score:", scorecard.lower_scores["yahtzee"])
	
	# Create another Yahtzee (five 4s)
	var second_yahtzee_dice: Array[int] = [4, 4, 4, 4, 4]
	
	# Now try to check for bonus with a different category (should trigger bonus)
	scorecard.check_bonus_yahtzee(second_yahtzee_dice, "full_house")
	
	# Check that bonus WAS awarded for the second Yahtzee
	var final_bonus_count = scorecard.yahtzee_bonuses
	var final_bonus_points = scorecard.yahtzee_bonus_points
	
	print("After second Yahtzee - bonus count:", final_bonus_count)
	print("After second Yahtzee - bonus points:", final_bonus_points)
	
	if final_bonus_count > initial_bonus_count and final_bonus_points > initial_bonus_points:
		print("✓ PASS: Second Yahtzee correctly triggered bonus")
		update_results("Test 2: PASS - Second Yahtzee triggered bonus")
	else:
		print("✗ FAIL: Second Yahtzee did not trigger bonus")
		update_results("Test 2: FAIL - Second Yahtzee no bonus!")

func update_results(text: String):
	if results_label:
		if results_label.text == "":
			results_label.text = text
		else:
			results_label.text += "\n" + text