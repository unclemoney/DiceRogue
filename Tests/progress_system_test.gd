extends Node
## Test script for the Progress System functionality

func _ready():
	print("=== Progress System Test ===")
	
	# Wait a frame for autoloads to initialize
	await get_tree().process_frame
	
	test_progress_manager_availability()
	test_default_items_creation()
	test_unlock_conditions()
	test_progress_tracking()
	test_item_filtering()

func test_progress_manager_availability():
	print("\n--- Testing ProgressManager Availability ---")
	
	var progress_manager = get_node("/root/ProgressManager")
	if progress_manager:
		print("✓ ProgressManager autoload found")
		
		if progress_manager.has_method("start_game_tracking"):
			print("✓ ProgressManager has tracking methods")
		else:
			print("✗ ProgressManager missing tracking methods")
			
		if progress_manager.has_method("is_item_unlocked"):
			print("✓ ProgressManager has unlock checking methods")
		else:
			print("✗ ProgressManager missing unlock checking methods")
	else:
		print("✗ ProgressManager autoload not found")

func test_default_items_creation():
	print("\n--- Testing Default Items Creation ---")
	
	var progress_manager = get_node("/root/ProgressManager")
	if not progress_manager:
		print("✗ Cannot test - ProgressManager not available")
		return
	
	var item_count = progress_manager.unlockable_items.size()
	print("Found %d default unlockable items" % item_count)
	
	if item_count > 0:
		print("✓ Default items created successfully")
		
		# List a few items
		var count = 0
		for item_id in progress_manager.unlockable_items:
			var item = progress_manager.unlockable_items[item_id]
			print("  - %s (%s): %s" % [item.display_name, item.get_type_string(), item.get_unlock_description()])
			count += 1
			if count >= 3:
				break
	else:
		print("✗ No default items found")

func test_unlock_conditions():
	print("\n--- Testing Unlock Conditions ---")
	
	var progress_manager = get_node("/root/ProgressManager")
	if not progress_manager:
		print("✗ Cannot test - ProgressManager not available")
		return
	
	# Test a simple condition
	const UnlockConditionClass = preload("res://Scripts/Core/unlock_condition.gd")
	var test_condition = UnlockConditionClass.new()
	test_condition.condition_type = UnlockConditionClass.ConditionType.SCORE_POINTS
	test_condition.target_value = 100
	
	# Test with fake game stats
	var test_game_stats = {"max_category_score": 150}
	var test_progress_data = {}
	
	if test_condition.is_satisfied(test_game_stats, test_progress_data):
		print("✓ Unlock condition satisfied correctly (150 >= 100)")
	else:
		print("✗ Unlock condition failed when it should have passed")
	
	# Test failing condition
	test_game_stats["max_category_score"] = 50
	if not test_condition.is_satisfied(test_game_stats, test_progress_data):
		print("✓ Unlock condition failed correctly (50 < 100)")
	else:
		print("✗ Unlock condition passed when it should have failed")

func test_progress_tracking():
	print("\n--- Testing Progress Tracking ---")
	
	var progress_manager = get_node("/root/ProgressManager")
	if not progress_manager:
		print("✗ Cannot test - ProgressManager not available")
		return
	
	# Test starting tracking
	if not progress_manager.is_tracking_game:
		progress_manager.start_game_tracking()
		
	if progress_manager.is_tracking_game:
		print("✓ Game tracking started successfully")
	else:
		print("✗ Failed to start game tracking")
	
	# Test tracking some events
	progress_manager.track_score_assigned("yahtzee", 200)
	progress_manager.track_yahtzee_rolled()
	progress_manager.track_consumable_used()
	
	var game_stats = progress_manager.current_game_stats
	print("Tracked stats:")
	print("  Max score: %d" % game_stats.get("max_category_score", 0))
	print("  Yahtzees: %d" % game_stats.get("yahtzees_rolled", 0))
	print("  Consumables used: %d" % game_stats.get("consumables_used", 0))
	
	if game_stats.get("max_category_score", 0) == 200:
		print("✓ Score tracking works correctly")
	else:
		print("✗ Score tracking failed")

func test_item_filtering():
	print("\n--- Testing Item Filtering ---")
	
	var progress_manager = get_node("/root/ProgressManager")
	if not progress_manager:
		print("✗ Cannot test - ProgressManager not available")
		return
	
	# Test item unlocking/locking
	var test_item_id = "step_by_step"
	
	# Lock the item first
	progress_manager.debug_lock_item(test_item_id)
	if not progress_manager.is_item_unlocked(test_item_id):
		print("✓ Item successfully locked: %s" % test_item_id)
	else:
		print("✗ Failed to lock item: %s" % test_item_id)
	
	# Unlock the item
	progress_manager.debug_unlock_item(test_item_id)
	if progress_manager.is_item_unlocked(test_item_id):
		print("✓ Item successfully unlocked: %s" % test_item_id)
	else:
		print("✗ Failed to unlock item: %s" % test_item_id)
	
	# Test getting locked items
	const UnlockableItemClass = preload("res://Scripts/Core/unlockable_item.gd")
	var locked_power_ups = progress_manager.get_locked_items(UnlockableItemClass.ItemType.POWER_UP)
	print("Found %d locked PowerUps" % locked_power_ups.size())
	
	var unlocked_power_ups = progress_manager.get_unlocked_items(UnlockableItemClass.ItemType.POWER_UP)
	print("Found %d unlocked PowerUps" % unlocked_power_ups.size())
	
	print("\n=== Progress System Test Complete ===")