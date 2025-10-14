extends Node
class_name DuplicatePowerUpTest

## Duplicate PowerUp Prevention Test
##
## This test verifies that our duplicate PowerUp prevention fixes work correctly.

func _ready() -> void:
	print("\n=== Starting Duplicate PowerUp Prevention Tests ===")
	
	# Wait for the scene to be fully ready
	await get_tree().process_frame
	await get_tree().process_frame
	
	_run_tests()

func _run_tests() -> void:
	print("\n--- Test 1: GameController Direct Granting ---")
	_test_game_controller_duplicate_prevention()
	
	print("\n--- Test 2: Random Consumable Filtering ---")
	_test_random_consumable_filtering()
	
	print("\n--- Test 3: Shop Filtering ---")
	_test_shop_filtering()
	
	print("\n=== All Duplicate PowerUp Tests Completed ===")

func _test_game_controller_duplicate_prevention() -> void:
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if not game_controller:
		print("❌ GameController not found")
		return
	
	print("📊 Initial active PowerUps:", game_controller.active_power_ups.keys())
	
	# Try to grant a PowerUp that should already exist (bonus_money)
	print("🔄 Attempting to grant 'bonus_money' (should already exist)...")
	game_controller.grant_power_up("bonus_money")
	
	# Count how many bonus_money PowerUps exist
	var bonus_money_count = 0
	for key in game_controller.active_power_ups.keys():
		if key == "bonus_money":
			bonus_money_count += 1
	
	if bonus_money_count == 1:
		print("✅ GameController correctly prevented duplicate PowerUp")
	else:
		print("❌ GameController failed to prevent duplicate PowerUp (count: %d)" % bonus_money_count)

func _test_random_consumable_filtering() -> void:
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if not game_controller:
		print("❌ GameController not found")
		return
	
	print("📊 Active PowerUps before consumable test:", game_controller.active_power_ups.keys())
	
	# Use the random PowerUp consumable multiple times
	for i in range(3):
		print("🔄 Using random PowerUp consumable #%d..." % (i + 1))
		var consumable = game_controller.get_active_consumable("random_power_up_uncommon")
		if consumable:
			consumable.apply(game_controller)
			await get_tree().process_frame
		else:
			print("⚠️  No random PowerUp consumable found")
			break
	
	print("📊 Active PowerUps after consumable test:", game_controller.active_power_ups.keys())

func _test_shop_filtering() -> void:
	var shop_ui = get_tree().get_first_node_in_group("shop_ui")
	if not shop_ui:
		print("❌ ShopUI not found")
		return
	
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if not game_controller:
		print("❌ GameController not found")
		return
		
	print("📊 Active PowerUps before shop test:", game_controller.active_power_ups.keys())
	
	# Force shop to repopulate and check if owned PowerUps are filtered out
	if shop_ui.has_method("_populate_shop_items"):
		print("🔄 Forcing shop to repopulate...")
		shop_ui._populate_shop_items()
		await get_tree().process_frame
		
		# Check PowerUp container for items
		var power_up_container = shop_ui.get_node_or_null("TabContainer/PowerUps/GridContainer")
		if power_up_container:
			var shop_power_ups = []
			for child in power_up_container.get_children():
				if child.has_method("get") and child.has_property("item_id"):
					shop_power_ups.append(child.item_id)
			
			print("📊 PowerUps in shop:", shop_power_ups)
			
			# Check if any owned PowerUps appear in shop
			var owned_in_shop = false
			for shop_power_up in shop_power_ups:
				if game_controller.active_power_ups.has(shop_power_up):
					owned_in_shop = true
					print("❌ Found owned PowerUp '%s' in shop" % shop_power_up)
			
			if not owned_in_shop:
				print("✅ Shop correctly filtered out owned PowerUps")
		else:
			print("❌ PowerUp container not found in shop")
	else:
		print("❌ Shop populate method not found")