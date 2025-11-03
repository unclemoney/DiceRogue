extends Node

## Simple progress test to verify item tracking

func _ready() -> void:
	print("=== PROGRESS MANAGER ITEM COUNT TEST ===")
	await get_tree().process_frame  # Wait for autoloads
	
	var progress_manager = get_node("/root/ProgressManager")
	if not progress_manager:
		print("ERROR: ProgressManager not found")
		get_tree().quit()
		return
	
	print("ProgressManager found, waiting for initialization...")
	await get_tree().create_timer(2.0).timeout  # Give time for initialization
	
	print("Total unlockable items tracked: %d" % progress_manager.unlockable_items.size())
	
	# Count by type
	var power_up_count = 0
	var consumable_count = 0
	var mod_count = 0
	var colored_dice_count = 0
	var locked_count = 0
	var unlocked_count = 0
	
	for item_id in progress_manager.unlockable_items:
		var item = progress_manager.unlockable_items[item_id]
		match item.item_type:
			0: # POWER_UP
				power_up_count += 1
			1: # CONSUMABLE
				consumable_count += 1
			2: # MOD
				mod_count += 1
			3: # COLORED_DICE_FEATURE
				colored_dice_count += 1
		
		if item.is_unlocked:
			unlocked_count += 1
			print("UNLOCKED: %s (%s)" % [item.display_name, item_id])
		else:
			locked_count += 1
			print("LOCKED: %s (%s)" % [item.display_name, item_id])
	
	print("\n=== SUMMARY ===")
	print("PowerUps: %d" % power_up_count)
	print("Consumables: %d" % consumable_count)
	print("Mods: %d" % mod_count)
	print("Colored Dice: %d" % colored_dice_count)
	print("Total: %d" % progress_manager.unlockable_items.size())
	print("Unlocked: %d" % unlocked_count)
	print("Locked: %d" % locked_count)
	
	get_tree().quit()