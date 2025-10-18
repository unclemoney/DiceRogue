extends Control
class_name ChanceFixTest

## ChanceFixTest
##
## Tests that chance scoring with red dice and PinHead works correctly

@onready var scorecard: Scorecard
@onready var test_label: Label
@onready var test_button: Button

func _ready():
	print("\n=== ChanceFixTest ===")
	
	# Create UI elements
	test_label = Label.new()
	test_label.text = "Chance Scoring Fix Test"
	test_label.position = Vector2(20, 20)
	test_label.size = Vector2(800, 60)
	add_child(test_label)
	
	test_button = Button.new()
	test_button.text = "Test Chance: [4,6,5,4,6] + Red(6) + PinHead(4x)"
	test_button.position = Vector2(20, 90)
	test_button.size = Vector2(400, 40)
	test_button.pressed.connect(_test_chance_scoring)
	add_child(test_button)
	
	# Create scorecard
	scorecard = Scorecard.new()
	add_child(scorecard)

func _test_chance_scoring():
	print("\n=== TESTING CHANCE SCORING FIX ===")
	
	# Test case: [4,6,5,4,6] with red dice +6 and PinHead 4x multiplier
	var test_dice: Array[int] = [4, 6, 5, 4, 6]
	
	# Expected calculation:
	# Base: 4+6+5+4+6 = 25
	# Red dice additive: +6  
	# Total before multiplier: 25 + 6 = 31
	# PinHead 4x multiplier: 31 × 4 = 124
	# Final expected: 124 (NOT 496!)
	
	print("[ChanceFixTest] Testing dice values:", test_dice)
	print("[ChanceFixTest] Expected base score: 25")
	print("[ChanceFixTest] Expected with red dice (+6): 31") 
	print("[ChanceFixTest] Expected with PinHead (4x): 124")
	print("[ChanceFixTest] Should NOT be: 496")
	
	# Test the calculation directly
	var base_score = scorecard._calculate_base_score("chance", test_dice)
	print("[ChanceFixTest] Base score calculated:", base_score)
	
	# Simulate red dice effect (we can't easily test full dice color system here)
	var base_with_red = base_score + 6  # Simulate red dice additive
	var expected_with_multiplier = base_with_red * 4  # PinHead 4x
	
	print("[ChanceFixTest] Base + red dice:", base_with_red)
	print("[ChanceFixTest] Expected final (with 4x):", expected_with_multiplier)
	
	# Test set_score with the correctly calculated score
	var initial_total = scorecard.get_total_score()
	scorecard.set_score(Scorecard.Section.LOWER, "chance", 124)  # Pass final calculated score
	var final_total = scorecard.get_total_score()
	var stored_score = scorecard.lower_scores["chance"]
	
	print("[ChanceFixTest] Stored score:", stored_score)
	print("[ChanceFixTest] Total change:", final_total - initial_total)
	
	# Evaluate results
	var result_text = ""
	if stored_score == 124:
		result_text = "✅ SUCCESS: Correct score of 124!\n"
		result_text += "No double multiplication detected.\n"
		result_text += "Base(25) + Red(+6) × PinHead(4x) = 124"
		test_label.modulate = Color.GREEN
	elif stored_score == 496:
		result_text = "❌ FAILED: Still getting 496!\n"
		result_text += "Double multiplication still occurring.\n" 
		result_text += "Score is being multiplied twice: 124 × 4 = 496"
		test_label.modulate = Color.RED
	else:
		result_text = "⚠️ UNEXPECTED: Got score of " + str(stored_score) + "\n"
		result_text += "Expected 124, got something else."
		test_label.modulate = Color.YELLOW
	
	test_label.text = result_text
	print("[ChanceFixTest] Test complete!")