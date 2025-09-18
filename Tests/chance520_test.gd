extends Node
class_name Chance520Test

# Test script to verify Chance520PowerUp functionality

var scorecard: Scorecard
var chance520_power_up: Chance520PowerUp
var score_modifier_manager

func _ready() -> void:
	add_to_group("test")
	print("\n=== Chance520PowerUp Test Starting ===")
	setup_test_environment()
	run_all_tests()

func setup_test_environment() -> void:
	print("\n--- Setting up test environment ---")
	
	# Create a test scorecard
	scorecard = Scorecard.new()
	add_child(scorecard)
	
	# Create or get the ScoreModifierManager
	var manager_scene = load("res://Scripts/Managers/ScoreModifierManager.gd")
	score_modifier_manager = manager_scene.new()
	add_child(score_modifier_manager)
	
	# Create the Chance520PowerUp
	var chance520_scene = load("res://Scenes/PowerUp/Chance520PowerUp.tscn")
	chance520_power_up = chance520_scene.instantiate() as Chance520PowerUp
	add_child(chance520_power_up)
	
	print("✓ Test environment setup complete")

func run_all_tests() -> void:
	test_initial_state()
	test_chance_scoring_below_20()
	test_chance_scoring_20_or_above()
	test_additive_application()
	test_multiple_chance_scores()
	print("\n=== All Chance520PowerUp Tests Complete ===")

func test_initial_state() -> void:
	print("\n--- Test: Initial State ---")
	
	# Reset the modifier manager
	score_modifier_manager.reset()
	
	# Apply the power-up to the scorecard
	chance520_power_up.apply(scorecard)
	
	# Check initial state
	assert(chance520_power_up.bonus_count == 0, "Initial bonus count should be 0")
	assert(chance520_power_up.get_current_additive() == 0, "Initial additive should be 0")
	assert(score_modifier_manager.get_total_additive() == 0, "ScoreModifierManager total additive should be 0")
	
	print("✓ Initial state tests passed")

func test_chance_scoring_below_20() -> void:
	print("\n--- Test: Chance Scoring Below 20 ---")
	
	# Reset state
	score_modifier_manager.reset()
	chance520_power_up.bonus_count = 0
	chance520_power_up.apply(scorecard)
	
	# Simulate scoring chance with less than 20
	scorecard.emit_signal("score_assigned", Scorecard.Section.LOWER, "chance", 15)
	
	# Should not trigger bonus
	assert(chance520_power_up.bonus_count == 0, "Bonus count should remain 0 for score < 20")
	assert(chance520_power_up.get_current_additive() == 0, "Additive should remain 0 for score < 20")
	assert(score_modifier_manager.get_total_additive() == 0, "Total additive should remain 0 for score < 20")
	
	print("✓ Chance scoring below 20 tests passed")

func test_chance_scoring_20_or_above() -> void:
	print("\n--- Test: Chance Scoring 20 or Above ---")
	
	# Reset state
	score_modifier_manager.reset()
	chance520_power_up.bonus_count = 0
	chance520_power_up.apply(scorecard)
	
	# Simulate scoring chance with 20
	scorecard.emit_signal("score_assigned", Scorecard.Section.LOWER, "chance", 20)
	
	# Should trigger bonus
	assert(chance520_power_up.bonus_count == 1, "Bonus count should be 1 for score >= 20")
	assert(chance520_power_up.get_current_additive() == 5, "Additive should be 5 for score >= 20")
	assert(score_modifier_manager.get_total_additive() == 5, "Total additive should be 5 for score >= 20")
	
	# Test with higher score
	scorecard.emit_signal("score_assigned", Scorecard.Section.LOWER, "chance", 25)
	
	assert(chance520_power_up.bonus_count == 2, "Bonus count should be 2 after second trigger")
	assert(chance520_power_up.get_current_additive() == 10, "Additive should be 10 after second trigger")
	assert(score_modifier_manager.get_total_additive() == 10, "Total additive should be 10 after second trigger")
	
	print("✓ Chance scoring 20 or above tests passed")

func test_additive_application() -> void:
	print("\n--- Test: Additive Application ---")
	
	# Reset state and set up a bonus
	score_modifier_manager.reset()
	chance520_power_up.bonus_count = 0
	chance520_power_up.apply(scorecard)
	
	# Trigger the bonus
	scorecard.emit_signal("score_assigned", Scorecard.Section.LOWER, "chance", 21)
	
	# Verify additive is properly registered
	assert(score_modifier_manager.has_additive("chance520"), "ScoreModifierManager should have chance520 additive")
	assert(score_modifier_manager.get_additive("chance520") == 5, "chance520 additive should be 5")
	
	# Test that it affects score calculation
	var test_dice_values = [1, 2, 3, 4, 5]  # Sum = 15
	var calculated_score = scorecard.calculate_score("ones", test_dice_values)
	
	# Base score for ones with these dice would be 1, plus +5 additive = 6, times 1.0 multiplier = 6
	var expected_score = (1 + 5) * 1  # Base + additive, then multiply
	assert(calculated_score == expected_score, "Score should include additive bonus: expected " + str(expected_score) + " got " + str(calculated_score))
	
	print("✓ Additive application tests passed")

func test_multiple_chance_scores() -> void:
	print("\n--- Test: Multiple Chance Scores ---")
	
	# Reset state
	score_modifier_manager.reset()
	chance520_power_up.bonus_count = 0
	chance520_power_up.apply(scorecard)
	
	# Trigger multiple bonuses
	scorecard.emit_signal("score_assigned", Scorecard.Section.LOWER, "chance", 22)  # +5
	scorecard.emit_signal("score_assigned", Scorecard.Section.LOWER, "chance", 30)  # +10 total
	scorecard.emit_signal("score_assigned", Scorecard.Section.LOWER, "chance", 19)  # Still +10 (doesn't trigger)
	scorecard.emit_signal("score_assigned", Scorecard.Section.LOWER, "chance", 24)  # +15 total
	
	assert(chance520_power_up.bonus_count == 3, "Should have 3 bonuses (scores: 22, 30, 24)")
	assert(chance520_power_up.get_current_additive() == 15, "Should have +15 additive")
	assert(score_modifier_manager.get_total_additive() == 15, "Total additive should be 15")
	
	print("✓ Multiple chance scores tests passed")

func cleanup() -> void:
	if chance520_power_up:
		chance520_power_up.remove(scorecard)
		chance520_power_up.queue_free()
	
	if scorecard:
		scorecard.queue_free()
		
	if score_modifier_manager:
		score_modifier_manager.reset()
		score_modifier_manager.queue_free()
	
	print("✓ Test cleanup complete")