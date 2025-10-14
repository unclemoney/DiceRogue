extends Node
class_name ConsumableDuplicateTest

## Consumable Duplicate and PowerUp Slot Test
##
## This test verifies that our consumable duplicate fixes and PowerUp slot limits work correctly.

func _ready() -> void:
	print("\n=== Starting Consumable and PowerUp Slot Tests ===")
	
	# Wait for the scene to be fully ready
	await get_tree().process_frame
	await get_tree().process_frame
	
	_run_tests()

func _run_tests() -> void:
	print("\n--- Test 1: Multiple Consumable Granting ---")
	_test_multiple_consumable_granting()
	
	print("\n--- Test 2: Random PowerUp Consumable Usability ---")
	_test_random_powerup_consumable_usability()
	
	print("\n=== All Consumable Tests Completed ===")

func _test_multiple_consumable_granting() -> void:
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if not game_controller:
		print("❌ GameController not found")
		return
	
	print("📊 Initial consumables:", game_controller.active_consumables.keys())
	print("📊 Initial counts:", game_controller.consumable_counts)
	
	# Grant the same consumable multiple times
	print("🔄 Granting quick_cash consumable 3 times...")
	for i in range(3):
		game_controller.grant_consumable("quick_cash")
		await get_tree().process_frame
	
	print("📊 Final consumables:", game_controller.active_consumables.keys())
	print("📊 Final counts:", game_controller.consumable_counts)
	
	# Check if count system worked
	if game_controller.consumable_counts.has("quick_cash"):
		var count = game_controller.consumable_counts["quick_cash"]
		if count == 3:
			print("✅ Multiple consumable granting works correctly (count: %d)" % count)
		else:
			print("❌ Multiple consumable granting failed (expected: 3, got: %d)" % count)
	else:
		print("❌ Consumable count not found")

func _test_random_powerup_consumable_usability() -> void:
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if not game_controller:
		print("❌ GameController not found")
		return
	
	var consumable_ui = game_controller.consumable_ui
	if not consumable_ui:
		print("❌ ConsumableUI not found")
		return
	
	print("📊 Current PowerUp count:", game_controller.active_power_ups.size())
	
	# Test usability when slots are not full
	var random_powerup_data = game_controller.consumable_manager.get_def("random_power_up_uncommon")
	if random_powerup_data:
		var is_usable_before = consumable_ui._can_use_consumable(random_powerup_data)
		print("🔄 Random PowerUp consumable usable when slots not full:", is_usable_before)
	
	# Fill up PowerUp slots by granting many PowerUps
	print("🔄 Filling PowerUp slots...")
	var power_up_ids = ["extra_dice", "extra_rolls", "foursome", "upper_bonus_mult", "yahtzee_bonus_mult"]
	for power_up_id in power_up_ids:
		if not game_controller.active_power_ups.has(power_up_id):
			game_controller.grant_power_up(power_up_id)
			await get_tree().process_frame
	
	print("📊 PowerUp count after filling:", game_controller.active_power_ups.size())
	
	# Test usability when slots are full
	if random_powerup_data:
		var is_usable_after = consumable_ui._can_use_consumable(random_powerup_data)
		print("🔄 Random PowerUp consumable usable when slots full:", is_usable_after)
		
		if not is_usable_after:
			print("✅ Random PowerUp consumable correctly disabled when slots are full")
		else:
			print("❌ Random PowerUp consumable should be disabled when slots are full")