extends Node

## Test script for Yahtzee bonus detection
## Tests that bonus Yahtzee is properly awarded when rolling a second Yahtzee

func _ready():
	print("=== Yahtzee Bonus Test ===")
	
	# Give the scene tree a moment to initialize
	await get_tree().process_frame
	
	# Test 1: Setup a scorecard with an initial Yahtzee scored
	print("\n--- Test 1: Setup Initial Yahtzee ---")
	var scorecard = Scorecard.new()
	add_child(scorecard)  # Add to scene tree
	
	# Manually set up a Yahtzee already scored
	scorecard.lower_scores["yahtzee"] = 50
	print("Initial Yahtzee set to 50 points")
	
	# Verify initial state
	print("Yahtzee bonuses before: ", scorecard.yahtzee_bonuses)
	print("Yahtzee bonus points before: ", scorecard.yahtzee_bonus_points)
	
	# Test 2: Check Statistics initial state
	print("\n--- Test 2: Statistics Initial State ---")
	var stats_before = Statistics.yahtzee_bonuses_earned
	print("Statistics yahtzee bonuses before: ", stats_before)
	
	# Test 3: Simulate rolling a second Yahtzee
	print("\n--- Test 3: Simulate Second Yahtzee ---")
	var yahtzee_dice: Array[int] = [6, 6, 6, 6, 6]  # All sixes = Yahtzee
	print("Rolling second Yahtzee: ", yahtzee_dice)
	
	# Simulate the bonus check
	scorecard.check_bonus_yahtzee(yahtzee_dice)
	
	# Verify the bonus was awarded
	print("\n--- Test 4: Verify Bonus Awarded ---")
	print("Yahtzee bonuses after: ", scorecard.yahtzee_bonuses)
	print("Yahtzee bonus points after: ", scorecard.yahtzee_bonus_points)
	
	var stats_after = Statistics.yahtzee_bonuses_earned
	print("Statistics yahtzee bonuses after: ", stats_after)
	
	# Expected results
	if scorecard.yahtzee_bonuses == 1 and scorecard.yahtzee_bonus_points == 100:
		print("✅ SUCCESS: Scorecard bonus tracking works!")
	else:
		print("❌ FAILED: Scorecard bonus tracking failed")
	
	if stats_after == stats_before + 1:
		print("✅ SUCCESS: Statistics bonus tracking works!")
	else:
		print("❌ FAILED: Statistics bonus tracking failed")
	
	# Test 5: Test invalid scenarios
	print("\n--- Test 5: Test Invalid Scenarios ---")
	
	# Test without initial Yahtzee
	var scorecard2 = Scorecard.new()
	add_child(scorecard2)
	scorecard2.lower_scores["yahtzee"] = null  # No initial Yahtzee
	
	var bonuses_before_invalid = scorecard2.yahtzee_bonuses
	scorecard2.check_bonus_yahtzee(yahtzee_dice)
	var bonuses_after_invalid = scorecard2.yahtzee_bonuses
	
	if bonuses_before_invalid == bonuses_after_invalid:
		print("✅ SUCCESS: No bonus awarded without initial Yahtzee")
	else:
		print("❌ FAILED: Bonus awarded incorrectly without initial Yahtzee")
	
	# Test with non-Yahtzee dice
	var non_yahtzee_dice: Array[int] = [1, 2, 3, 4, 5]
	var bonuses_before_non = scorecard.yahtzee_bonuses
	scorecard.check_bonus_yahtzee(non_yahtzee_dice)
	var bonuses_after_non = scorecard.yahtzee_bonuses
	
	if bonuses_before_non == bonuses_after_non:
		print("✅ SUCCESS: No bonus awarded for non-Yahtzee")
	else:
		print("❌ FAILED: Bonus awarded incorrectly for non-Yahtzee")
	
	print("\n=== Test Complete ===")
	print("The bonus Yahtzee system should now work correctly in gameplay!")
	
	# Exit after a moment
	await get_tree().create_timer(3.0).timeout
	get_tree().quit()