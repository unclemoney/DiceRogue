extends Node
class_name TheConsumerIsAlwaysRightTest

func _ready() -> void:
	print("\n=== TheConsumerIsAlwaysRight Test Starting ===")
	await get_tree().create_timer(0.5).timeout
	_test_multiplier_calculation()

func _test_multiplier_calculation() -> void:
	print("\n--- Testing Multiplier Calculation ---")
	
	# Create a test instance of the PowerUp
	var powerup_script = preload("res://Scripts/PowerUps/the_consumer_is_always_right_power_up.gd")
	var powerup_instance = powerup_script.new()
	powerup_instance.id = "the_consumer_is_always_right"
	
	# Mock the Statistics reference with test data
	var mock_stats = Node.new()
	mock_stats.set_script(preload("res://Scripts/Managers/statistics_manager.gd"))
	mock_stats.consumables_used = 0
	powerup_instance.statistics_ref = mock_stats
	
	# Test with 0 consumables
	var mult_0 = powerup_instance.get_current_multiplier()
	assert(mult_0 == 1.0, "Expected 1.0x multiplier with 0 consumables, got " + str(mult_0))
	print("✓ 0 consumables = x%.2f multiplier" % mult_0)
	
	# Test with 3 consumables (example from requirements)
	mock_stats.consumables_used = 3
	var mult_3 = powerup_instance.get_current_multiplier()
	var expected_3 = 1.0 + (3 * 0.25)  # Should be 1.75
	assert(mult_3 == expected_3, "Expected %.2fx multiplier with 3 consumables, got %.2f" % [expected_3, mult_3])
	print("✓ 3 consumables = x%.2f multiplier" % mult_3)
	
	# Test with 4 consumables 
	mock_stats.consumables_used = 4
	var mult_4 = powerup_instance.get_current_multiplier()
	var expected_4 = 1.0 + (4 * 0.25)  # Should be 2.0
	assert(mult_4 == expected_4, "Expected %.2fx multiplier with 4 consumables, got %.2f" % [expected_4, mult_4])
	print("✓ 4 consumables = x%.2f multiplier" % mult_4)
	
	# Test description generation
	var desc = powerup_instance.get_current_description()
	print("✓ Description with 4 consumables: " + desc)
	
	# Test with 0 consumables again for description
	mock_stats.consumables_used = 0
	var desc_0 = powerup_instance.get_current_description()
	print("✓ Description with 0 consumables: " + desc_0)
	
	# Cleanup
	powerup_instance.queue_free()
	mock_stats.queue_free()
	
	print("TheConsumerIsAlwaysRightTest: ✓ All tests passed!")
	print("=== Test Complete ===\n")