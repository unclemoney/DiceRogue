extends Node
class_name FullHousePowerUpTest

func _ready() -> void:
	print("\n=== FullHousePowerUp Test Starting ===")
	await get_tree().create_timer(0.5).timeout
	_test_full_house_scaling()

func _test_full_house_scaling() -> void:
	print("\n--- Testing Full House Money Scaling ---")
	
	# Create the PowerUp instance
	var full_house_power_up = preload("res://Scenes/PowerUp/FullHousePowerUp.tscn").instantiate()
	add_child(full_house_power_up)
	
	# Apply the PowerUp (it doesn't use the target parameter)
	full_house_power_up.apply(null)
	
	print("Initial state:")
	print("- Total full houses: %d" % full_house_power_up.total_full_houses_earned)
	print("- Description: %s" % full_house_power_up.get_current_description())
	
	# Check initial money
	var initial_money = PlayerEconomy.get_money()
	print("- Initial money: $%d" % initial_money)
	
	# Simulate rolling multiple full houses
	print("\nSimulating full house rolls:")
	
	for i in range(1, 6):  # Test 5 full houses
		# Emit the signal that RollStats would emit
		RollStats.emit_signal("combination_achieved", "full_house")
		
		await get_tree().create_timer(0.1).timeout
		
		var current_money = PlayerEconomy.get_money()
		var money_gained = current_money - initial_money
		
		print("After full house #%d:" % i)
		print("  - Total money: $%d (gained: $%d)" % [current_money, money_gained])
		print("  - Expected gain: $%d" % (i * (i + 1) * 7 / 2))  # Sum of 7+14+21+...
		print("  - Description: %s" % full_house_power_up.get_current_description())
	
	# Verify the final expected money gain
	var final_money = PlayerEconomy.get_money()
	var total_gained = final_money - initial_money
	var expected_total = 7 + 14 + 21 + 28 + 35  # 1*7 + 2*7 + 3*7 + 4*7 + 5*7 = 105
	
	print("\nFinal Results:")
	print("- Total money gained: $%d" % total_gained)
	print("- Expected total gain: $%d" % expected_total)
	
	assert(total_gained == expected_total, "Money gain should match expected scaling pattern")
	assert(full_house_power_up.total_full_houses_earned == 5, "Should have tracked 5 full houses")
	
	print("FullHousePowerUpTest: ✓ All tests passed!")
	
	# Cleanup
	full_house_power_up.queue_free()