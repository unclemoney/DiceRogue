extends Control

## bonus_double_counting_test.gd
## Test to verify that the bonus double-counting bug is fixed
## Yahtzee of 5s should give 25 points in 5s section, not 125

@onready var scorecard = $Scorecard
@onready var results_label = $VBoxContainer/ResultsLabel

func _ready():
	print("\n=== BONUS DOUBLE-COUNTING FIX TEST ===")
	
	# Wait for scorecard to be ready
	await get_tree().process_frame
	
	test_bonus_double_counting_fix()

func test_bonus_double_counting_fix():
	print("\n--- Testing Bonus Double-Counting Fix ---")
	update_results("=== BONUS DOUBLE-COUNTING TEST ===")
	
	# Step 1: Set up initial Yahtzee
	scorecard.lower_scores["yahtzee"] = 50
	update_results("Step 1: Initial Yahtzee scored (50 pts)")
	
	# Step 2: Test Yahtzee of 5s
	print("\nStep 2: Testing Yahtzee of 5s...")
	var yahtzee_fives: Array[int] = [5, 5, 5, 5, 5]
	
	# Test score calculation directly (this should give 25, not 125)
	var calculated_score = scorecard.evaluate_category("fives", yahtzee_fives)
	
	print("Calculated score for 5s with Yahtzee:", calculated_score)
	update_results("Step 2: Yahtzee of 5s")
	update_results("  Calculated score: " + str(calculated_score))
	
	if calculated_score == 25:
		print("✅ PASS: 5s correctly calculated as 25")
		update_results("  ✅ CORRECT: 5s = 25 points")
	else:
		print("❌ FAIL: 5s incorrectly calculated as", calculated_score)
		update_results("  ❌ WRONG: 5s = " + str(calculated_score) + " (expected 25)")
	
	# Step 3: Test Yahtzee of 1s
	print("\nStep 3: Testing Yahtzee of 1s...")
	var yahtzee_ones: Array[int] = [1, 1, 1, 1, 1]
	
	var calculated_ones = scorecard.evaluate_category("ones", yahtzee_ones)
	
	print("Calculated score for 1s with Yahtzee:", calculated_ones)
	update_results("Step 3: Yahtzee of 1s")
	update_results("  Calculated score: " + str(calculated_ones))
	
	if calculated_ones == 5:
		print("✅ PASS: 1s correctly calculated as 5")
		update_results("  ✅ CORRECT: 1s = 5 points")
	else:
		print("❌ FAIL: 1s incorrectly calculated as", calculated_ones)
		update_results("  ❌ WRONG: 1s = " + str(calculated_ones) + " (expected 5)")
	
	# Step 4: Test that bonus tracking still works
	print("\nStep 4: Testing bonus tracking...")
	var initial_bonus = scorecard.yahtzee_bonus_points
	
	# Simulate manual scoring of bonus Yahtzee
	scorecard.set_score(Scorecard.Section.UPPER, "fives", 25)
	scorecard.check_bonus_yahtzee(yahtzee_fives, "fives")
	
	var final_bonus = scorecard.yahtzee_bonus_points
	var bonus_increase = final_bonus - initial_bonus
	
	print("Bonus increase:", bonus_increase)
	update_results("Step 4: Bonus tracking")
	update_results("  Bonus increase: " + str(bonus_increase))
	
	if bonus_increase == 100:
		print("✅ PASS: Bonus correctly tracked as +100")
		update_results("  ✅ CORRECT: Bonus = +100 points")
	else:
		print("❌ FAIL: Bonus incorrectly tracked as", bonus_increase)
		update_results("  ❌ WRONG: Bonus = +" + str(bonus_increase) + " (expected +100)")
	
	# Final assessment
	if calculated_score == 25 and calculated_ones == 5 and bonus_increase == 100:
		update_results("")
		update_results("🎉 ALL TESTS PASSED!")
		update_results("✅ Bonus double-counting bug FIXED!")
	else:
		update_results("")
		update_results("❌ Some tests failed - bug still exists")

func update_results(text: String):
	if results_label:
		if results_label.text == "":
			results_label.text = text
		else:
			results_label.text += "\n" + text