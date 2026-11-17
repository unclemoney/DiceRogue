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
	print("Starting money: $%.2f" % starting_money)

	# Grant some test PowerUps of different rarities for testing
	print("\nGranting test PowerUps...")

	# Grant some common PowerUps (should pay $0.20 each)
	game_controller.grant_power_up("extra_dice")  # Common
	game_controller.grant_power_up("extra_rolls")  # Common

	# Grant an uncommon PowerUp (should pay $0.25)
	game_controller.grant_power_up("chance520")  # Uncommon

	# Grant a rare PowerUp (should pay $0.50)
	game_controller.grant_power_up("foursome")  # Rare

	print("PowerUps granted. Current active PowerUps:")
	for power_up_id in game_controller.active_power_ups.keys():
		var def = game_controller.pu_manager.get_def(power_up_id)
		if def:
			print("  - %s (rarity: %s)" % [power_up_id, def.rarity])

	# Expected payment calculation:
	# 2 Common × $0.20 = $0.40
	# 1 Uncommon × $0.25 = $0.25
	# 1 Rare × $0.50 = $0.50
	# Total expected: $1.15
	var expected_payment = 0.4 + 0.25 + 0.5  # $1.15

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
	print("Money before use: $%.2f" % money_before_use)

	# Simulate using the consumable
	game_controller._on_consumable_used("the_rarities")

	# Check the money after
	var money_after_use = PlayerEconomy.money
	var actual_payment = money_after_use - money_before_use

	print("Money after use: $%.2f" % money_after_use)
	print("Actual payment: $%.2f" % actual_payment)
	print("Expected payment: $%.2f" % expected_payment)

	# Verify the payment is correct
	if actual_payment == expected_payment:
		print("\n✓ SUCCESS: TheRarities consumable works correctly!")
		print("  Payment calculation is accurate")
	else:
		print("\n✗ FAILED: Payment mismatch")
		print("  Expected: $%.2f" % expected_payment)
		print("  Actual: $%.2f" % actual_payment)
		print("  Difference: $%.2f" % (actual_payment - expected_payment))

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
		print("✗ FAILED: Unexpected payment when no PowerUps owned: $%.2f" % (money_after_zero_test - money_before_zero_test))

	print("\n=== TheRarities Test Complete ===\n")

func _ready():
	# Wait a bit for the game to initialize, then run the test
	await get_tree().create_timer(1.0).timeout
	run_test()
