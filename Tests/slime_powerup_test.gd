extends Node
class_name SlimePowerUpTest

## Test the Slime PowerUps functionality
## This test verifies that the Slime PowerUps properly modify dice color probabilities

func _ready() -> void:
	print("\n=== Slime PowerUp Functionality Test ===")
	await get_tree().create_timer(1.0).timeout
	_test_color_probability_modifiers()
	await get_tree().create_timer(1.0).timeout
	_test_slime_powerup_integration()

func _test_color_probability_modifiers() -> void:
	print("\n--- Testing Color Probability Modifiers ---")
	
	# Get DiceColorManager
	var dice_color_manager = get_tree().get_first_node_in_group("dice_color_manager")
	if not dice_color_manager:
		dice_color_manager = get_node_or_null("/root/DiceColorManager")
	
	if not dice_color_manager:
		print("❌ DiceColorManager not found")
		return
	
	# Test base color chances
	print("Base color chances:")
	print("  Green: 1 in %d" % DiceColor.get_color_chance(DiceColor.Type.GREEN))
	print("  Red: 1 in %d" % DiceColor.get_color_chance(DiceColor.Type.RED))
	print("  Purple: 1 in %d" % DiceColor.get_color_chance(DiceColor.Type.PURPLE))
	print("  Blue: 1 in %d" % DiceColor.get_color_chance(DiceColor.Type.BLUE))
	
	# Test registering a modifier
	dice_color_manager.register_color_chance_modifier(DiceColor.Type.GREEN, 0.5)
	var modified_green_chance = dice_color_manager.get_modified_color_chance(DiceColor.Type.GREEN)
	print("Green chance after 0.5 modifier: 1 in %d" % modified_green_chance)
	
	# Verify the calculation
	var expected_green = int(25 * 0.5)  # 25 * 0.5 = 12.5 -> 12
	if modified_green_chance == expected_green:
		print("✅ Green dice probability modifier working correctly")
	else:
		print("❌ Green dice probability modifier failed. Expected: %d, Got: %d" % [expected_green, modified_green_chance])
	
	# Test unregistering
	dice_color_manager.unregister_color_chance_modifier(DiceColor.Type.GREEN)
	var reset_green_chance = dice_color_manager.get_modified_color_chance(DiceColor.Type.GREEN)
	if reset_green_chance == 25:
		print("✅ Green dice probability reset correctly")
	else:
		print("❌ Green dice probability reset failed. Expected: 25, Got: %d" % reset_green_chance)

func _test_slime_powerup_integration() -> void:
	print("\n--- Testing Slime PowerUp Integration ---")
	
	# Test if PowerUps exist in PowerUpManager
	var power_up_manager = get_tree().get_first_node_in_group("power_up_manager")
	if not power_up_manager:
		print("❌ PowerUpManager not found")
		return
	
	var slime_powerups = ["green_slime", "red_slime", "purple_slime", "blue_slime"]
	var found_count = 0
	
	for powerup_id in slime_powerups:
		var def = power_up_manager.get_def(powerup_id)
		if def:
			print("✅ Found %s PowerUp: %s" % [powerup_id, def.display_name])
			found_count += 1
		else:
			print("❌ Missing %s PowerUp" % powerup_id)
	
	if found_count == 4:
		print("✅ All Slime PowerUps registered successfully")
	else:
		print("❌ Only %d/4 Slime PowerUps found" % found_count)
	
	# Test if PowerUps are in ProgressManager
	var progress_manager = get_node_or_null("/root/ProgressManager")
	if progress_manager:
		var locked_count = 0
		for powerup_id in slime_powerups:
			var is_unlocked = progress_manager.is_item_unlocked(powerup_id)
			if is_unlocked:
				print("✅ %s is unlocked" % powerup_id)
			else:
				print("🔒 %s is locked (expected for new PowerUps)" % powerup_id)
				locked_count += 1
		
		if locked_count == 4:
			print("✅ All Slime PowerUps properly locked by default")
		elif locked_count > 0:
			print("⚠️ %d/4 Slime PowerUps are locked (some may be unlocked from previous play)" % locked_count)
	else:
		print("❌ ProgressManager not found")
	
	print("\n=== Slime PowerUp Test Complete ===")
	print("Use the debug console to grant PowerUps and test color probability changes in practice!")