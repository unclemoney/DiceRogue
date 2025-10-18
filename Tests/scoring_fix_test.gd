extends Control
class_name ScoringFixTest

## ScoringFixTest
##
## Tests that the scoring fixes work correctly - no double scoring, correct multipliers

@onready var scorecard: Scorecard
@onready var test_label: Label
@onready var test_button: Button

func _ready():
	print("\n=== ScoringFixTest ===")
	print("[ScoringFixTest] Testing scoring fix...")
	
	# Create UI elements
	test_label = Label.new()
	test_label.text = "Scoring Fix Test - Click to test Four of a Kind"
	test_label.position = Vector2(20, 20)
	test_label.size = Vector2(600, 30)
	add_child(test_label)
	
	test_button = Button.new()
	test_button.text = "Test Four of a Kind (6,6,6,5,6)"
	test_button.position = Vector2(20, 60)
	test_button.size = Vector2(300, 40)
	test_button.pressed.connect(_test_scoring_fix)
	add_child(test_button)
	
	# Create scorecard
	scorecard = Scorecard.new()
	add_child(scorecard)

func _test_scoring_fix():
	print("\n=== TESTING SCORING FIX ===")
	
	# Set up test dice values - same as the problematic case
	var test_dice: Array[int] = [6, 6, 6, 5, 6]
	DiceResults.values = test_dice
	
	# Expected scores:
	# Base score for four of a kind: 6+6+6+5+6 = 29
	# With PinHead 6x multiplier: 29 × 6 = 174
	# Should NOT be: 174 × 6 = 1044
	
	print("[ScoringFixTest] Testing dice:", test_dice)
	print("[ScoringFixTest] Expected base score: 29")
	print("[ScoringFixTest] Expected with 6x multiplier: 174")
	print("[ScoringFixTest] Should NOT be: 1044")
	
	# Test 1: Calculate base score without modifiers
	var base_score = scorecard._calculate_base_score("four_of_a_kind", test_dice)
	print("[ScoringFixTest] Base score calculation:", base_score)
	
	# Test 2: Calculate with internal method (should apply modifiers)
	var score_with_modifiers = scorecard.calculate_score_internal("four_of_a_kind", test_dice, false)
	print("[ScoringFixTest] Score with modifiers:", score_with_modifiers)
	
	# Test 3: Set score and check if it gets double-multiplied
	var initial_total = scorecard.get_total_score()
	scorecard.set_score(Scorecard.Section.LOWER, "four_of_a_kind", 174)  # Pass already-calculated score
	var final_total = scorecard.get_total_score()
	var actual_score = scorecard.lower_scores["four_of_a_kind"]
	
	print("[ScoringFixTest] Set score to 174, actual stored score:", actual_score)
	print("[ScoringFixTest] Total change:", final_total - initial_total)
	
	# Evaluate results
	var result_text = "Results:\n"
	result_text += "Base score: " + str(base_score) + " (expected: 29)\n"
	result_text += "Score with modifiers: " + str(score_with_modifiers) + "\n" 
	result_text += "Stored score: " + str(actual_score) + " (should be 174, NOT 1044)\n"
	
	if actual_score == 174:
		result_text += "✅ SUCCESS: No double multiplication!"
		test_label.modulate = Color.GREEN
	elif actual_score == 1044:
		result_text += "❌ FAILED: Still double multiplying!"
		test_label.modulate = Color.RED
	else:
		result_text += "⚠️ UNEXPECTED: Score is " + str(actual_score)
		test_label.modulate = Color.YELLOW
	
	test_label.text = result_text
	print("[ScoringFixTest] Test complete!")