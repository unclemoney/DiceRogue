extends Control

## manual_scoring_test.gd
## Test to reproduce the issue where manual scoring of bonus Yahtzee
## adds 100 points to the category score instead of keeping them separate

@onready var scorecard = $Scorecard
@onready var results_label = $VBoxContainer/ResultsLabel

func _ready():
	print("\n=== MANUAL SCORING BONUS YAHTZEE TEST ===")
	
	# Wait for scorecard to be ready
	await get_tree().process_frame
	
	test_manual_scoring_issue()

func test_manual_scoring_issue():
	print("\n--- Reproducing manual scoring issue ---")
	update_results("=== MANUAL SCORING TEST ===")
	
	# Step 1: Set up initial Yahtzee
	scorecard.lower_scores["yahtzee"] = 50
	update_results("Step 1: Initial Yahtzee scored (50 pts)")
	
	# Step 2: Manually score bonus Yahtzee in 5s section
	print("\nStep 2: Manually scoring bonus Yahtzee in 5s section...")
	var yahtzee_dice: Array[int] = [5, 5, 5, 5, 5]
	
	# Simulate the manual scoring process
	# This mimics what happens when user clicks 5s button with Yahtzee dice
	
	# First set DiceResults (this is what happens in the UI)
	DiceResults.set_values(yahtzee_dice)
	
	# Get initial state
	var initial_fives_score = scorecard.upper_scores["fives"]
	var initial_bonus_count = scorecard.yahtzee_bonuses
	var initial_bonus_points = scorecard.yahtzee_bonus_points
	var initial_total = scorecard.get_total_score()
	
	print("Initial fives score:", initial_fives_score)
	print("Initial bonus count:", initial_bonus_count) 
	print("Initial bonus points:", initial_bonus_points)
	print("Initial total:", initial_total)
	
	# Simulate the manual scoring sequence (what on_category_selected does)
	print("\nSimulating manual category selection for 'fives'...")
	
	# Manually calculate what 5 fives should score (bypass DiceResults issues)
	var base_fives_score = 25  # 5 fives = 25 points
	var calculated_score = base_fives_score  # Use expected score to bypass DiceResults issue
	print("Using expected score for fives:", calculated_score)
	
	# Set the score (this is what on_category_selected does)
	scorecard.set_score(Scorecard.Section.UPPER, "fives", calculated_score)
	
	# Check bonus (this is what UI does after scoring)
	scorecard.check_bonus_yahtzee(yahtzee_dice, "fives")
	
	# Get final state
	var final_fives_score = scorecard.upper_scores["fives"]
	var final_bonus_count = scorecard.yahtzee_bonuses
	var final_bonus_points = scorecard.yahtzee_bonus_points
	var final_total = scorecard.get_total_score()
	
	print("\nFinal state:")
	print("Final fives score:", final_fives_score)
	print("Final bonus count:", final_bonus_count)
	print("Final bonus points:", final_bonus_points)
	print("Final total:", final_total)
	
	# Analysis
	update_results("Step 2: Scoring bonus Yahtzee in 5s...")
	update_results("  Calculated 5s score: " + str(calculated_score))
	update_results("  Final 5s score: " + str(final_fives_score))
	update_results("  Bonus count: " + str(final_bonus_count))
	update_results("  Bonus points: " + str(final_bonus_points))
	
	# Check if the issue exists
	var expected_fives_score = 25  # 5 fives = 25 points
	var expected_bonus_increase = 100
	
	if final_fives_score != expected_fives_score:
		print("❌ ISSUE CONFIRMED: 5s score is wrong!")
		update_results("❌ ISSUE CONFIRMED:")
		update_results("  Expected 5s score: " + str(expected_fives_score))
		update_results("  Actual 5s score: " + str(final_fives_score))
		update_results("  Difference: " + str(final_fives_score - expected_fives_score))
		
		if final_fives_score - expected_fives_score == 100:
			update_results("  ➤ 100 points incorrectly added to category!")
		
	else:
		print("✅ 5s score is correct")
		update_results("✅ 5s score correct: " + str(final_fives_score))
	
	if final_bonus_points == initial_bonus_points + expected_bonus_increase:
		print("✅ Bonus points tracked correctly")
		update_results("✅ Bonus points correct: +" + str(expected_bonus_increase))
	else:
		print("❌ Bonus points tracking issue")
		update_results("❌ Bonus points wrong: " + str(final_bonus_points - initial_bonus_points))

func update_results(text: String):
	if results_label:
		if results_label.text == "":
			results_label.text = text
		else:
			results_label.text += "\n" + text