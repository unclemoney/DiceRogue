extends Node

## TheRarities Consumable Test
##
## Tests the TheRarities consumable functionality including:
## - PowerUp counting by rarity
## - Payment calculation
## - Integration with PlayerEconomy

func run_test():
	print("\n=== TheRarities Consumable Test ===")
	
	# Get the game controller
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if not game_controller:
		print("ERROR: No GameController found")
		return
	
	# Get starting money
	var starting_money = PlayerEconomy.money
	print("Starting money: $%d" % starting_money)
	
	# Grant some test PowerUps of different rarities for testing
	print("\nGranting test PowerUps...")
	
	# Grant some common PowerUps (should pay $20 each)
	game_controller.grant_power_up("extra_dice")  # Common
	game_controller.grant_power_up("extra_rolls")  # Common
	
	# Grant an uncommon PowerUp (should pay $25)
	game_controller.grant_power_up("chance520")  # Uncommon
	
	# Grant a rare PowerUp (should pay $50)
	game_controller.grant_power_up("foursome")  # Rare
	
	print("PowerUps granted. Current active PowerUps:")
	for power_up_id in game_controller.active_power_ups.keys():
		var def = game_controller.pu_manager.get_def(power_up_id)
		if def:
			print("  - %s (rarity: %s)" % [power_up_id, def.rarity])
	
	# Expected payment calculation:
	# 2 Common × $20 = $40
	# 1 Uncommon × $25 = $25  
	# 1 Rare × $50 = $50
	# Total expected: $115
	var expected_payment = 40 + 25 + 50  # $115
	
	# Grant TheRarities consumable
	print("\nGranting TheRarities consumable...")
	game_controller.grant_consumable("the_rarities")
	
	# Check that it was granted
	if not game_controller.active_consumables.has("the_rarities"):
		print("ERROR: TheRarities consumable was not granted properly")
		return
	
	print("TheRarities consumable granted successfully")
	
	# Use the consumable
	print("\nUsing TheRarities consumable...")
	var money_before_use = PlayerEconomy.money
	print("Money before use: $%d" % money_before_use)
	
	# Simulate using the consumable
	game_controller._on_consumable_used("the_rarities")
	
	# Check the money after
	var money_after_use = PlayerEconomy.money
	var actual_payment = money_after_use - money_before_use
	
	print("Money after use: $%d" % money_after_use)
	print("Actual payment: $%d" % actual_payment)
	print("Expected payment: $%d" % expected_payment)
	
	# Verify the payment is correct
	if actual_payment == expected_payment:
		print("\n✓ SUCCESS: TheRarities consumable works correctly!")
		print("  Payment calculation is accurate")
	else:
		print("\n✗ FAILED: Payment mismatch")
		print("  Expected: $%d" % expected_payment)
		print("  Actual: $%d" % actual_payment)
		print("  Difference: $%d" % (actual_payment - expected_payment))
	
	# Test with no PowerUps
	print("\n--- Testing with no PowerUps ---")
	
	# Clear all PowerUps
	var powerup_ids_to_clear = []
	for power_up_id in game_controller.active_power_ups.keys():
		powerup_ids_to_clear.append(power_up_id)
	
	for power_up_id in powerup_ids_to_clear:
		game_controller.revoke_power_up(power_up_id)
	
	print("All PowerUps cleared. Active PowerUps: %d" % game_controller.active_power_ups.size())
	
	# Grant TheRarities again
	game_controller.grant_consumable("the_rarities")
	
	var money_before_zero_test = PlayerEconomy.money
	game_controller._on_consumable_used("the_rarities")
	var money_after_zero_test = PlayerEconomy.money
	
	if money_after_zero_test == money_before_zero_test:
		print("✓ SUCCESS: No payment when no PowerUps owned")
	else:
		print("✗ FAILED: Unexpected payment when no PowerUps owned: $%d" % (money_after_zero_test - money_before_zero_test))
	
	print("\n=== TheRarities Test Complete ===\n")

func _ready():
	# Wait a bit for the game to initialize, then run the test
	await get_tree().create_timer(1.0).timeout
	run_test()