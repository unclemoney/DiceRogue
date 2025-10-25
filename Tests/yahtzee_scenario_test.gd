extends Node

## Test script for Yahtzee bonus in different category scenario
## Tests the exact user scenario: First Yahtzee scored in Yahtzee category, 
## second Yahtzee (5 sixes) scored in Four of a Kind category

func _ready():
	print("=== Yahtzee Bonus Scenario Test ===")
	print("Simulating: First Yahtzee scored, then 5 sixes scored in Four of a Kind")
	
	# Give the scene tree a moment to initialize
	await get_tree().process_frame
	
	# Test 1: Setup a complete scenario
	print("\n--- Test 1: Setup Complete Scenario ---")
	var scorecard = Scorecard.new()
	add_child(scorecard)  # Add to scene tree
	
	# Step 1: Score initial Yahtzee in Yahtzee category
	print("\n1. Scoring initial Yahtzee in Yahtzee category...")
	scorecard.lower_scores["yahtzee"] = 50
	print("   ✓ Yahtzee category scored: 50 points")
	
	# Step 2: Roll 5 sixes (another Yahtzee)
	print("\n2. Rolling 5 sixes (second Yahtzee)...")
	var five_sixes: Array[int] = [6, 6, 6, 6, 6]
	print("   Dice rolled: ", five_sixes)
	
	# Verify this is detected as a Yahtzee
	var is_yahtzee = ScoreEvaluatorSingleton.is_yahtzee(five_sixes)
	print("   Is this a Yahtzee? ", is_yahtzee)
	
	if not is_yahtzee:
		print("   ❌ ERROR: ScoreEvaluator doesn't recognize 5 sixes as Yahtzee!")
		get_tree().quit()
		return
	
	# Step 3: Score the 5 sixes in Four of a Kind category
	print("\n3. Scoring 5 sixes in Four of a Kind category...")
	
	# Calculate Four of a Kind score for 5 sixes
	var four_kind_score = ScoreEvaluatorSingleton.calculate_of_a_kind_score(five_sixes, 4)
	print("   Four of a Kind score for 5 sixes: ", four_kind_score, " points")
	
	# Set the score in scorecard
	scorecard.lower_scores["four_of_a_kind"] = four_kind_score
	print("   ✓ Four of a Kind category scored: ", four_kind_score, " points")
	
	# Step 4: Check initial bonus state
	print("\n4. Checking bonus state before bonus check...")
	print("   Yahtzee bonuses before: ", scorecard.yahtzee_bonuses)
	print("   Yahtzee bonus points before: ", scorecard.yahtzee_bonus_points)
	print("   Statistics bonuses before: ", Statistics.yahtzee_bonuses_earned)
	
	# Step 5: Trigger bonus check (this is what happens after scoring)
	print("\n5. Triggering bonus Yahtzee check...")
	scorecard.check_bonus_yahtzee(five_sixes)
	
	# Step 6: Verify bonus was awarded
	print("\n6. Verifying bonus was awarded...")
	print("   Yahtzee bonuses after: ", scorecard.yahtzee_bonuses)
	print("   Yahtzee bonus points after: ", scorecard.yahtzee_bonus_points)
	print("   Statistics bonuses after: ", Statistics.yahtzee_bonuses_earned)
	
	# Step 7: Calculate total score
	print("\n7. Calculating total scores...")
	var yahtzee_score = scorecard.lower_scores["yahtzee"]
	var four_kind_score_final = scorecard.lower_scores["four_of_a_kind"]
	var bonus_points = scorecard.yahtzee_bonus_points
	var total_lower = yahtzee_score + four_kind_score_final + bonus_points
	
	print("   Yahtzee category: ", yahtzee_score, " points")
	print("   Four of a Kind category: ", four_kind_score_final, " points")
	print("   Yahtzee bonus: ", bonus_points, " points")
	print("   Total lower section: ", total_lower, " points")
	
	# Step 8: Final verification
	print("\n8. Final Verification...")
	if scorecard.yahtzee_bonuses == 1 and scorecard.yahtzee_bonus_points == 100:
		print("   ✅ SUCCESS: Bonus Yahtzee awarded correctly!")
		print("   ✅ You should see 100 bonus points in your game!")
	else:
		print("   ❌ FAILED: Bonus Yahtzee not awarded correctly")
	
	if Statistics.yahtzee_bonuses_earned == 1:
		print("   ✅ SUCCESS: Statistics tracking working!")
		print("   ✅ Bonus will appear in Statistics panel!")
	else:
		print("   ❌ FAILED: Statistics not tracking bonus")
	
	print("\n=== Scenario Test Complete ===")
	print("The exact user scenario should now work correctly!")
	print("When you roll 5 sixes after scoring an initial Yahtzee,")
	print("you should get 100 bonus points regardless of which category you score in.")
	
	# Exit after a moment
	await get_tree().create_timer(4.0).timeout
	get_tree().quit()