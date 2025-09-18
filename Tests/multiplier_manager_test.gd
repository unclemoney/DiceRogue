extends Node
class_name ScoreModifierManagerTest

# Test script to verify ScoreModifierManager functionality

func _ready() -> void:
	add_to_group("test")
	print("\n=== ScoreModifierManager Test Starting ===")
	run_all_tests()

func run_all_tests() -> void:
	test_basic_functionality()
	test_multiplier_stacking()
	test_validation()
	test_reset_functionality()
	print("\n=== All ScoreModifierManager Tests Complete ===")

func test_basic_functionality() -> void:
	print("\n--- Test: Basic Functionality ---")
	
	# Start with clean state
	ScoreModifierManager.reset()
	
	# Test initial state
	assert(ScoreModifierManager.get_total_multiplier() == 1.0, "Initial multiplier should be 1.0")
	assert(ScoreModifierManager.get_multiplier_count() == 0, "Initial count should be 0")
	
	# Test registering a multiplier
	ScoreModifierManager.register_multiplier("test_source", 2.0)
	assert(ScoreModifierManager.get_total_multiplier() == 2.0, "Single multiplier should be 2.0")
	assert(ScoreModifierManager.has_multiplier("test_source"), "Should have test_source multiplier")
	
	# Test unregistering
	ScoreModifierManager.unregister_multiplier("test_source")
	assert(ScoreModifierManager.get_total_multiplier() == 1.0, "After unregister should be 1.0")
	assert(!ScoreModifierManager.has_multiplier("test_source"), "Should not have test_source multiplier")
	
	print("✓ Basic functionality tests passed")

func test_multiplier_stacking() -> void:
	print("\n--- Test: Multiplier Stacking ---")
	
	# Start with clean state
	ScoreModifierManager.reset()
	
	# Test multiple multipliers stack correctly (multiply together)
	ScoreModifierManager.register_multiplier("upper_bonus_mult", 2.0)
	ScoreModifierManager.register_multiplier("foursome", 4.0)
	
	var expected_total = 2.0 * 4.0  # Should be 8.0
	var actual_total = ScoreModifierManager.get_total_multiplier()
	
	assert(abs(actual_total - expected_total) < 0.001, "Stacked multipliers should multiply: expected " + str(expected_total) + " got " + str(actual_total))
	assert(ScoreModifierManager.get_multiplier_count() == 2, "Should have 2 active multipliers")
	
	# Test updating existing multiplier
	ScoreModifierManager.register_multiplier("upper_bonus_mult", 3.0)  # Update to 3x
	expected_total = 3.0 * 4.0  # Should be 12.0
	actual_total = ScoreModifierManager.get_total_multiplier()
	
	assert(abs(actual_total - expected_total) < 0.001, "Updated multiplier should stack correctly: expected " + str(expected_total) + " got " + str(actual_total))
	assert(ScoreModifierManager.get_multiplier_count() == 2, "Should still have 2 active multipliers")
	
	# Test partial removal
	ScoreModifierManager.unregister_multiplier("foursome")
	assert(ScoreModifierManager.get_total_multiplier() == 3.0, "After removing foursome should be 3.0")
	assert(ScoreModifierManager.get_multiplier_count() == 1, "Should have 1 active multiplier")
	
	print("✓ Multiplier stacking tests passed")

func test_validation() -> void:
	print("\n--- Test: Validation ---")
	
	# Start with clean state
	ScoreModifierManager.reset()
	
	# Test invalid multiplier values
	var original_count = ScoreModifierManager.get_multiplier_count()
	
	# These should be rejected
	ScoreModifierManager.register_multiplier("invalid_zero", 0.0)
	ScoreModifierManager.register_multiplier("invalid_negative", -1.0)
	
	# Count should not change
	assert(ScoreModifierManager.get_multiplier_count() == original_count, "Invalid multipliers should be rejected")
	assert(ScoreModifierManager.get_total_multiplier() == 1.0, "Total should remain 1.0 after invalid attempts")
	
	# Test validation function
	ScoreModifierManager.register_multiplier("valid_test", 2.0)
	var issues = ScoreModifierManager.validate_and_report()
	assert(issues.size() == 0, "Valid state should have no issues")
	
	print("✓ Validation tests passed")

func test_reset_functionality() -> void:
	print("\n--- Test: Reset Functionality ---")
	
	# Set up some multipliers
	ScoreModifierManager.register_multiplier("test1", 2.0)
	ScoreModifierManager.register_multiplier("test2", 3.0)
	
	# Verify they exist
	assert(ScoreModifierManager.get_multiplier_count() == 2, "Should have 2 multipliers before reset")
	assert(ScoreModifierManager.get_total_multiplier() == 6.0, "Total should be 6.0 before reset")
	
	# Test reset
	ScoreModifierManager.reset()
	
	# Verify clean state
	assert(ScoreModifierManager.get_multiplier_count() == 0, "Should have 0 multipliers after reset")
	assert(ScoreModifierManager.get_total_multiplier() == 1.0, "Total should be 1.0 after reset")
	assert(!ScoreModifierManager.has_multiplier("test1"), "Should not have test1 after reset")
	assert(!ScoreModifierManager.has_multiplier("test2"), "Should not have test2 after reset")
	
	print("✓ Reset functionality tests passed")
