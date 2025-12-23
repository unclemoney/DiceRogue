extends Control
## multi_dice_scoring_test.gd
##
## Test scene for validating multi-dice scoring with 5-16 dice.
## Tests Yahtzee, Full House, and other patterns with variable dice counts.

@onready var output_label: RichTextLabel = $Panel/VBoxContainer/OutputLabel
@onready var run_button: Button = $Panel/VBoxContainer/RunButton

# Reference to the ScoreEvaluator singleton
var evaluator: Node

var test_results: Array[String] = []
var passed_count: int = 0
var failed_count: int = 0


func _ready() -> void:
	evaluator = get_node("/root/ScoreEvaluatorSingleton")
	run_button.pressed.connect(_run_all_tests)
	_log("Multi-Dice Scoring Test Ready")
	_log("Click 'Run Tests' to validate scoring with 5-16 dice")


func _run_all_tests() -> void:
	test_results.clear()
	passed_count = 0
	failed_count = 0
	
	_log("\n========================================")
	_log("MULTI-DICE SCORING TEST SUITE")
	_log("========================================\n")
	
	_test_yahtzee_detection()
	_test_full_house_detection()
	_test_edge_cases()
	
	_log("\n========================================")
	_log("RESULTS: %d PASSED, %d FAILED" % [passed_count, failed_count])
	_log("========================================")


func _test_yahtzee_detection() -> void:
	_log("\n--- YAHTZEE DETECTION TESTS ---\n")
	
	# Standard 5 dice Yahtzee
	var values_5_yahtzee: Array[int] = [4, 4, 4, 4, 4]
	_assert_true(evaluator.is_yahtzee(values_5_yahtzee), "5 dice all 4s = Yahtzee")
	
	# 5 dice NOT Yahtzee
	var values_5_not_yahtzee: Array[int] = [4, 4, 4, 4, 3]
	_assert_false(evaluator.is_yahtzee(values_5_not_yahtzee), "5 dice with one different = NOT Yahtzee")
	
	# 6 dice with 5 matching (should be Yahtzee)
	var values_6_yahtzee: Array[int] = [5, 5, 5, 5, 5, 3]
	_assert_true(evaluator.is_yahtzee(values_6_yahtzee), "6 dice with 5 matching = Yahtzee")
	
	# 6 dice all matching
	var values_6_all_match: Array[int] = [6, 6, 6, 6, 6, 6]
	_assert_true(evaluator.is_yahtzee(values_6_all_match), "6 dice all 6s = Yahtzee")
	
	# 6 dice with only 4 matching (NOT Yahtzee)
	var values_6_only_4: Array[int] = [2, 2, 2, 2, 3, 4]
	_assert_false(evaluator.is_yahtzee(values_6_only_4), "6 dice with only 4 matching = NOT Yahtzee")
	
	# 10 dice with 5 matching
	var values_10_yahtzee: Array[int] = [1, 1, 1, 1, 1, 2, 3, 4, 5, 6]
	_assert_true(evaluator.is_yahtzee(values_10_yahtzee), "10 dice with 5 matching = Yahtzee")
	
	# 10 dice with only 4 matching
	var values_10_not_yahtzee: Array[int] = [1, 1, 1, 1, 2, 2, 3, 4, 5, 6]
	_assert_false(evaluator.is_yahtzee(values_10_not_yahtzee), "10 dice with only 4 matching = NOT Yahtzee")
	
	# 16 dice with 7 matching (should be Yahtzee)
	var values_16_yahtzee: Array[int] = [3, 3, 3, 3, 3, 3, 3, 1, 2, 4, 5, 6, 1, 2, 4, 5]
	_assert_true(evaluator.is_yahtzee(values_16_yahtzee), "16 dice with 7 matching = Yahtzee")
	
	# 16 dice all the same
	var values_16_all_same: Array[int] = [2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2]
	_assert_true(evaluator.is_yahtzee(values_16_all_same), "16 dice all 2s = Yahtzee")


func _test_full_house_detection() -> void:
	_log("\n--- FULL HOUSE DETECTION TESTS ---\n")
	
	# Standard 5 dice Full House (3+2)
	var values_5_fh: Array[int] = [3, 3, 3, 5, 5]
	_assert_true(evaluator.is_full_house(values_5_fh), "5 dice 3+2 = Full House")
	
	# 5 dice NOT Full House (4+1)
	var values_5_not_fh: Array[int] = [3, 3, 3, 3, 5]
	_assert_false(evaluator.is_full_house(values_5_not_fh), "5 dice 4+1 = NOT Full House")
	
	# 5 dice NOT Full House (all same - Yahtzee, not FH)
	var values_5_yahtzee: Array[int] = [4, 4, 4, 4, 4]
	_assert_false(evaluator.is_full_house(values_5_yahtzee), "5 dice all same = NOT Full House")
	
	# 6 dice with valid 3+2 pattern (extra die doesn't matter)
	var values_6_fh: Array[int] = [2, 2, 2, 6, 6, 1]
	_assert_true(evaluator.is_full_house(values_6_fh), "6 dice with 3+2 pattern = Full House")
	
	# 6 dice with 3+3 pattern (still valid - has 3 and different 2+)
	var values_6_3_3: Array[int] = [1, 1, 1, 4, 4, 4]
	_assert_true(evaluator.is_full_house(values_6_3_3), "6 dice with 3+3 = Full House")
	
	# 6 dice with no valid pattern
	var values_6_no_fh: Array[int] = [1, 2, 3, 4, 5, 6]
	_assert_false(evaluator.is_full_house(values_6_no_fh), "6 dice all different = NOT Full House")
	
	# 10 dice with valid Full House
	var values_10_fh: Array[int] = [5, 5, 5, 2, 2, 1, 3, 4, 6, 1]
	_assert_true(evaluator.is_full_house(values_10_fh), "10 dice with 3+2 pattern = Full House")
	
	# 10 dice with multiple pairs but no three
	var values_10_no_three: Array[int] = [1, 1, 2, 2, 3, 3, 4, 4, 5, 6]
	_assert_false(evaluator.is_full_house(values_10_no_three), "10 dice with no 3-of-kind = NOT Full House")
	
	# 16 dice with complex pattern
	var values_16_fh: Array[int] = [6, 6, 6, 6, 6, 3, 3, 3, 1, 2, 4, 5, 1, 2, 4, 5]
	_assert_true(evaluator.is_full_house(values_16_fh), "16 dice with 5+3 = Full House")
	
	# Less than 5 dice (should always fail)
	var values_4: Array[int] = [1, 1, 1, 2]
	_assert_false(evaluator.is_full_house(values_4), "4 dice = NOT Full House (need 5+)")


func _test_edge_cases() -> void:
	_log("\n--- EDGE CASE TESTS ---\n")
	
	# Empty array
	var empty: Array[int] = []
	_assert_false(evaluator.is_yahtzee(empty), "Empty array = NOT Yahtzee")
	_assert_false(evaluator.is_full_house(empty), "Empty array = NOT Full House")
	
	# Single die
	var single: Array[int] = [5]
	_assert_false(evaluator.is_yahtzee(single), "Single die = NOT Yahtzee")
	_assert_false(evaluator.is_full_house(single), "Single die = NOT Full House")
	
	# Exactly 5 matching in larger set (boundary case)
	var exactly_5_in_8: Array[int] = [3, 3, 3, 3, 3, 1, 2, 4]
	_assert_true(evaluator.is_yahtzee(exactly_5_in_8), "Exactly 5 matching in 8 dice = Yahtzee")
	
	# Full House where three-of-kind value could also satisfy the pair
	var tricky_fh: Array[int] = [4, 4, 4, 4, 2, 2]
	_assert_true(evaluator.is_full_house(tricky_fh), "6 dice 4+2 with extra = Full House")
	
	# Three of a kind but no pair (should NOT be Full House)
	var three_no_pair: Array[int] = [1, 1, 1, 2, 3, 4, 5]
	_assert_false(evaluator.is_full_house(three_no_pair), "Three of kind + all singles = NOT Full House")


func _assert_true(condition: bool, test_name: String) -> void:
	if condition:
		_log("[color=green]✓ PASS:[/color] " + test_name)
		passed_count += 1
	else:
		_log("[color=red]✗ FAIL:[/color] " + test_name)
		failed_count += 1


func _assert_false(condition: bool, test_name: String) -> void:
	_assert_true(not condition, test_name)


func _log(message: String) -> void:
	test_results.append(message)
	if output_label:
		output_label.text = "\n".join(test_results)
		# Auto-scroll to bottom
		await get_tree().process_frame
		output_label.scroll_to_line(output_label.get_line_count() - 1)
	print(message)
