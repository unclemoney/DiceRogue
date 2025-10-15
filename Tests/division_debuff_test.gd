extends Node
class_name DivisionDebuffTest

## DivisionDebuffTest
##
## Test script to verify TheDivisionDebuff functionality

func _ready():
	print("=== Division Debuff Test ===")
	
	# Get the ScoreModifierManager
	var score_modifier_manager = get_tree().get_first_node_in_group("score_modifier_manager")
	if not score_modifier_manager:
		print("❌ Failed to find ScoreModifierManager")
		return
	
	# Test normal mode first
	print("\n--- Testing Normal Mode ---")
	score_modifier_manager.add_multiplier("test_power_up", 2.0)
	var normal_multiplier = score_modifier_manager.get_total_multiplier()
	print("Added 2.0x multiplier, total: %f (expected: 2.0)" % normal_multiplier)
	
	# Apply division mode
	print("\n--- Testing Division Mode ---")
	score_modifier_manager.set_division_mode(true)
	var division_multiplier = score_modifier_manager.get_total_multiplier()
	print("Division mode enabled, total: %f (expected: 0.5)" % division_multiplier)
	
	# Verify division calculation
	var expected_division = 1.0 / 2.0  # 0.5
	var is_correct = abs(division_multiplier - expected_division) < 0.001
	print("Division calculation correct: %s" % ("✓" if is_correct else "❌"))
	
	# Test with multiple multipliers
	print("\n--- Testing Multiple Multipliers ---")
	score_modifier_manager.add_multiplier("test_power_up_2", 3.0)
	var multi_division = score_modifier_manager.get_total_multiplier()
	var expected_multi = (1.0 / 2.0) * (1.0 / 3.0)  # 0.166...
	print("Multiple dividers: %f (expected: %f)" % [multi_division, expected_multi])
	
	# Restore normal mode
	print("\n--- Restoring Normal Mode ---")
	score_modifier_manager.set_division_mode(false)
	var restored_multiplier = score_modifier_manager.get_total_multiplier()
	print("Normal mode restored, total: %f (expected: 6.0)" % restored_multiplier)
	
	# Clean up
	score_modifier_manager.remove_multiplier("test_power_up")
	score_modifier_manager.remove_multiplier("test_power_up_2")
	
	print("\n=== Test Complete ===")