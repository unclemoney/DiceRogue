extends Control

## bonus_separation_test.gd
## Test to verify that bonus Yahtzee points are kept separate from category scores
## A bonus Yahtzee scored as Full House should give: Full House = 25 points, Bonus = +100 points (separate)

@onready var scorecard = $Scorecard
@onready var results_label = $VBoxContainer/ResultsLabel

func _ready():
	print("\n=== BONUS SEPARATION TEST ===")
	
	# Wait for scorecard to be ready
	await get_tree().process_frame
	
	# Test: Bonus Yahtzee scored in Full House should keep points separate
	test_bonus_yahtzee_separation()

func test_bonus_yahtzee_separation():
	print("\n--- Test: Bonus Yahtzee scored as Full House ---")
	
	# Step 1: First score a regular Yahtzee in the yahtzee category
	scorecard.lower_scores["yahtzee"] = 50
	print("Step 1: Set yahtzee category to 50")
	
	# Step 2: Get initial state
	var initial_full_house_score = scorecard.lower_scores["full_house"]
	var initial_yahtzee_bonus_count = scorecard.yahtzee_bonuses
	var initial_yahtzee_bonus_points = scorecard.yahtzee_bonus_points
	var initial_total = scorecard.get_total_score()
	
	print("Initial full_house score:", initial_full_house_score)
	print("Initial yahtzee bonus count:", initial_yahtzee_bonus_count)
	print("Initial yahtzee bonus points:", initial_yahtzee_bonus_points)
	print("Initial total score:", initial_total)
	
	# Step 3: Score a bonus Yahtzee as Full House
	var yahtzee_dice: Array[int] = [4, 4, 4, 4, 4]
	
	# First set the full house score (normally 25, but Yahtzee rules allow using Yahtzee as any lower category)
	scorecard.lower_scores["full_house"] = 25  # Standard full house score
	
	# Then check for bonus (this should add 100 to bonus points, not to full house score)
	scorecard.check_bonus_yahtzee(yahtzee_dice, "full_house")
	
	# Step 4: Check results
	var final_full_house_score = scorecard.lower_scores["full_house"]
	var final_yahtzee_bonus_count = scorecard.yahtzee_bonuses
	var final_yahtzee_bonus_points = scorecard.yahtzee_bonus_points
	var final_total = scorecard.get_total_score()
	
	print("Final full_house score:", final_full_house_score)
	print("Final yahtzee bonus count:", final_yahtzee_bonus_count)
	print("Final yahtzee bonus points:", final_yahtzee_bonus_points)
	print("Final total score:", final_total)
	
	# Expected behavior:
	# - full_house score should remain 25 (not become 125)
	# - yahtzee_bonus_count should increase by 1
	# - yahtzee_bonus_points should increase by 100
	# - total score should increase by 125 (25 for full house + 100 for bonus)
	
	var full_house_correct = (final_full_house_score == 25)
	var bonus_count_correct = (final_yahtzee_bonus_count == initial_yahtzee_bonus_count + 1)
	var bonus_points_correct = (final_yahtzee_bonus_points == initial_yahtzee_bonus_points + 100)
	var total_increase = final_total - initial_total
	var total_correct = (total_increase == 125)  # 25 (full house) + 100 (bonus)
	
	print("\n=== RESULTS ===")
	print("Full House score correct (25):", full_house_correct)
	print("Bonus count increased by 1:", bonus_count_correct)
	print("Bonus points increased by 100:", bonus_points_correct)
	print("Total increased by 125:", total_correct, "(actual increase:", total_increase, ")")
	
	if full_house_correct and bonus_count_correct and bonus_points_correct and total_correct:
		print("✓ PASS: Bonus points correctly separated from category score")
		update_results("PASS: Bonus Yahtzee separation working correctly")
		update_results("- Full House: 25 points")
		update_results("- Bonus: +100 points (separate)")
		update_results("- Total increase: 125 points")
	else:
		print("✗ FAIL: Bonus points not properly separated")
		update_results("FAIL: Bonus separation issues:")
		if not full_house_correct:
			update_results("- Full House score wrong: " + str(final_full_house_score) + " (expected 25)")
		if not bonus_count_correct:
			update_results("- Bonus count wrong: " + str(final_yahtzee_bonus_count) + " (expected " + str(initial_yahtzee_bonus_count + 1) + ")")
		if not bonus_points_correct:
			update_results("- Bonus points wrong: " + str(final_yahtzee_bonus_points) + " (expected " + str(initial_yahtzee_bonus_points + 100) + ")")
		if not total_correct:
			update_results("- Total increase wrong: " + str(total_increase) + " (expected 125)")

func update_results(text: String):
	if results_label:
		if results_label.text == "":
			results_label.text = text
		else:
			results_label.text += "\n" + text