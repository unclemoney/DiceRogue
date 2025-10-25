extends Control

## comprehensive_yahtzee_bonus_test.gd
## Comprehensive test to verify both Yahtzee bonus issues are fixed:
## 1. First Yahtzee should NOT trigger bonus
## 2. Bonus points should be separate from category scores

@onready var scorecard = $Scorecard
@onready var results_label = $VBoxContainer/ResultsLabel

func _ready():
	print("\n=== COMPREHENSIVE YAHTZEE BONUS TEST ===")
	
	# Wait for scorecard to be ready
	await get_tree().process_frame
	
	# Reset any previous state
	scorecard.yahtzee_bonuses = 0
	scorecard.yahtzee_bonus_points = 0
	
	# Test complete scenario
	test_complete_yahtzee_bonus_scenario()

func test_complete_yahtzee_bonus_scenario():
	print("\n--- Complete Yahtzee Bonus Scenario ---")
	update_results("=== YAHTZEE BONUS SYSTEM TEST ===")
	
	# Step 1: Score first Yahtzee in yahtzee category (should NOT get bonus)
	print("\nStep 1: Scoring first Yahtzee...")
	scorecard.lower_scores["yahtzee"] = 50
	
	var first_yahtzee_dice: Array[int] = [1, 1, 1, 1, 1]
	scorecard.check_bonus_yahtzee(first_yahtzee_dice, "yahtzee")
	
	var after_first_bonus_count = scorecard.yahtzee_bonuses
	var after_first_bonus_points = scorecard.yahtzee_bonus_points
	var after_first_total = scorecard.get_total_score()
	
	print("After first Yahtzee - bonuses:", after_first_bonus_count, "points:", after_first_bonus_points, "total:", after_first_total)
	
	if after_first_bonus_count == 0 and after_first_bonus_points == 0:
		print("✓ PASS: First Yahtzee correctly did NOT trigger bonus")
		update_results("✓ Issue 1 FIXED: First Yahtzee no bonus")
	else:
		print("✗ FAIL: First Yahtzee incorrectly triggered bonus")
		update_results("✗ Issue 1 BROKEN: First Yahtzee triggered bonus!")
		return
	
	# Step 2: Score bonus Yahtzee in Full House (should get bonus + separate scoring)
	print("\nStep 2: Scoring bonus Yahtzee as Full House...")
	
	var _initial_full_house = scorecard.lower_scores["full_house"]
	var initial_total = scorecard.get_total_score()
	
	# Score the Full House category first
	scorecard.lower_scores["full_house"] = 25
	
	# Then check for bonus
	var bonus_yahtzee_dice: Array[int] = [2, 2, 2, 2, 2]
	scorecard.check_bonus_yahtzee(bonus_yahtzee_dice, "full_house")
	
	var final_full_house = scorecard.lower_scores["full_house"]
	var final_bonus_count = scorecard.yahtzee_bonuses
	var final_bonus_points = scorecard.yahtzee_bonus_points
	var final_total = scorecard.get_total_score()
	
	print("After bonus Yahtzee:")
	print("  Full House score:", final_full_house)
	print("  Bonus count:", final_bonus_count)
	print("  Bonus points:", final_bonus_points) 
	print("  Total score:", final_total)
	
	# Check separation
	var full_house_correct = (final_full_house == 25)
	var bonus_triggered = (final_bonus_count == 1 and final_bonus_points == 100)
	var total_increase = final_total - initial_total
	var total_correct = (total_increase == 125)  # 25 (full house) + 100 (bonus)
	
	if full_house_correct and bonus_triggered and total_correct:
		print("✓ PASS: Bonus Yahtzee correctly separated scoring")
		update_results("✓ Issue 2 FIXED: Bonus points separate")
		update_results("  - Full House: 25 points")
		update_results("  - Bonus: +100 points")
		update_results("  - Total increase: 125 points")
	else:
		print("✗ FAIL: Bonus separation not working")
		update_results("✗ Issue 2 BROKEN: Bonus separation failed!")
		if not full_house_correct:
			update_results("  - Full House wrong: " + str(final_full_house))
		if not bonus_triggered:
			update_results("  - Bonus not triggered properly")
		if not total_correct:
			update_results("  - Total increase wrong: " + str(total_increase))
		return
	
	# Step 3: Verify total system integrity
	print("\nStep 3: System integrity check...")
	var expected_total = 50 + 25 + 100  # yahtzee + full_house + bonus
	
	if final_total == expected_total:
		print("✓ PASS: Total score calculation correct")
		update_results("✓ System integrity confirmed")
		update_results("")
		update_results("🎉 ALL YAHTZEE BONUS ISSUES FIXED!")
		update_results("1. First Yahtzee no longer triggers bonus")
		update_results("2. Bonus points properly separated")
	else:
		print("✗ FAIL: Total score calculation error")
		update_results("✗ System integrity issue!")
		update_results("Expected total: " + str(expected_total))
		update_results("Actual total: " + str(final_total))

func update_results(text: String):
	if results_label:
		if results_label.text == "":
			results_label.text = text
		else:
			results_label.text += "\n" + text