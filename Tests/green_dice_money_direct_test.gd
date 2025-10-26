extends Control

## Green Dice Money Direct Test
##
## Test Green dice money distribution directly without UI interaction.
## This test will:
## 1. Create dice with Green colors  
## 2. Test DiceColorManager.calculate_color_effects()
## 3. Test PlayerEconomy.add_money() integration
## 4. Verify money is actually awarded

@onready var result_label: Label = %ResultLabel

func _ready() -> void:
	print("[GreenDiceMoneyDirectTest] Starting Green dice money test...")
	
	# Allow some time for autoloads to initialize
	await get_tree().process_frame
	await get_tree().process_frame
	
	_run_green_dice_money_test()

func _run_green_dice_money_test() -> void:
	var results = []
	var test_passed = true
	var mock_dice_instances = []  # Track created mock dice for cleanup
	
	results.append("=== GREEN DICE MONEY DIRECT TEST ===")
	
	# Test 1: Check if PlayerEconomy is available
	results.append("\n1. PlayerEconomy Availability:")
	if PlayerEconomy:
		var initial_money = PlayerEconomy.money
		results.append("✓ PlayerEconomy available - Initial money: $%d" % initial_money)
	else:
		results.append("✗ PlayerEconomy not available")
		test_passed = false
	
	# Test 2: Check if DiceColorManager is available
	results.append("\n2. DiceColorManager Availability:")
	if DiceColorManager:
		results.append("✓ DiceColorManager available")
	else:
		results.append("✗ DiceColorManager not available")
		test_passed = false
	
	# Test 3: Create test dice and check color effects
	results.append("\n3. Direct Color Effects Test:")
	if DiceColorManager:
		# Create mock dice with green colors and various values
		var mock_dice = _create_mock_green_dice([1, 2, 3, 4, 5])
		mock_dice_instances.append_array(mock_dice)
		
		# Test color effects calculation
		var color_effects = DiceColorManager.calculate_color_effects(mock_dice, [])
		results.append("Mock dice values: [1, 2, 3, 4, 5] (all Green)")
		results.append("Color effects returned: %s" % str(color_effects))
		
		var base_green_money = 1 + 2 + 3 + 4 + 5  # Sum of all dice values
		var expected_green_money = base_green_money * 2  # Same color bonus (5 green dice doubles the effect)
		var actual_green_money = color_effects.get("green_money", 0)
		
		if actual_green_money == expected_green_money:
			results.append("✓ Green money calculation correct: $%d (base: $%d, doubled by same color bonus)" % [actual_green_money, base_green_money])
		else:
			results.append("✗ Green money calculation incorrect: Expected $%d, got $%d" % [expected_green_money, actual_green_money])
			test_passed = false
	
	# Test 4: Test PlayerEconomy money addition
	results.append("\n4. PlayerEconomy Money Addition Test:")
	if PlayerEconomy:
		var money_before = PlayerEconomy.money
		var test_amount = 10
		
		PlayerEconomy.add_money(test_amount)
		
		var money_after = PlayerEconomy.money
		var actual_increase = money_after - money_before
		
		if actual_increase == test_amount:
			results.append("✓ PlayerEconomy.add_money() works: $%d -> $%d (+$%d)" % [money_before, money_after, actual_increase])
		else:
			results.append("✗ PlayerEconomy.add_money() failed: Expected +$%d, actual +$%d" % [test_amount, actual_increase])
			test_passed = false
	
	# Test 5: Full integration test with realistic dice values (no same color bonus)
	results.append("\n5. Full Integration Test:")
	if PlayerEconomy and DiceColorManager:
		var money_before_integration = PlayerEconomy.money
		
		# Create dice for a simple scenario: 3 Green dice with values [2, 2, 2] (less than 5, no same color bonus)
		var test_dice = _create_mock_green_dice([2, 2, 2])
		mock_dice_instances.append_array(test_dice)
		var color_effects = DiceColorManager.calculate_color_effects(test_dice, [])
		var green_money = color_effects.get("green_money", 0)
		
		results.append("Test scenario: 3 Green dice with values [2, 2, 2] (no same color bonus)")
		results.append("Calculated green_money: $%d" % green_money)
		
		# Expected: 2+2+2 = 6 (no doubling since less than 5 dice)
		var expected_green_money_simple = 6
		if green_money == expected_green_money_simple:
			results.append("✓ Simple green money calculation correct: $%d" % green_money)
		else:
			results.append("✗ Simple green money calculation incorrect: Expected $%d, got $%d" % [expected_green_money_simple, green_money])
			test_passed = false
		
		# Apply the money using the same logic as scorecard
		if green_money > 0:
			PlayerEconomy.add_money(green_money)
			results.append("Applied green money bonus: +$%d" % green_money)
		
		var money_after_integration = PlayerEconomy.money
		var actual_integration_increase = money_after_integration - money_before_integration
		
		if actual_integration_increase == green_money:
			results.append("✓ Full integration test passed: Money increased by $%d" % actual_integration_increase)
		else:
			results.append("✗ Full integration test failed: Expected +$%d, actual +$%d" % [green_money, actual_integration_increase])
			test_passed = false
	
	# Cleanup mock dice
	for dice in mock_dice_instances:
		if is_instance_valid(dice):
			dice.queue_free()
	
	# Final result
	results.append("\n" + "=".repeat(50))
	if test_passed:
		results.append("🎉 ALL TESTS PASSED - Green dice money system working!")
	else:
		results.append("❌ SOME TESTS FAILED - Green dice money system has issues")
	
	# Display results
	var final_text = "\n".join(results)
	if result_label:
		result_label.text = final_text
	
	print(final_text)

## Create mock dice with green colors and specified values
func _create_mock_green_dice(values: Array) -> Array:
	var mock_dice = []
	
	# Load the actual Dice scene to create real dice instances
	var dice_scene = preload("res://Scenes/Dice/Dice.tscn")
	
	for value in values:
		# Create a real Dice instance
		var mock_die = dice_scene.instantiate()
		
		# Set up the dice properties
		mock_die.value = value
		mock_die.color = preload("res://Scripts/Core/dice_color.gd").Type.GREEN
		
		# Add to tree temporarily so methods work
		add_child(mock_die)
		
		mock_dice.append(mock_die)
	
	return mock_dice

func _show_result(text: String) -> void:
	if result_label:
		result_label.text += text + "\n"
	print(text)