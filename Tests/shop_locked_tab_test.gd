extends Control

## Test script for verifying the LOCKED tab functionality in ShopUI
##
## This test validates that:
## 1. The LOCKED tab appears in the shop
## 2. Locked items are filtered out from regular shop tabs
## 3. Locked items appear in the LOCKED tab with unlock requirements

var shop_ui: ShopUI
var progress_manager
var test_completed: bool = false

func _ready():
	print("=== Shop LOCKED Tab Test ===")
	
	# Get the ProgressManager
	progress_manager = get_node("/root/ProgressManager")
	if not progress_manager:
		print("✗ ProgressManager not available")
		return
	
	# Create managers needed for ShopUI
	_setup_managers()
	
	# Create and setup ShopUI
	_setup_shop_ui()
	
	# Wait a frame for everything to initialize
	await get_tree().process_frame
	
	# Run the tests
	_run_tests()

func _setup_managers():
	print("Setting up managers...")
	
	# Create PowerUpManager
	var power_up_manager = preload("res://Scripts/Managers/PowerUpManager.gd").new()
	power_up_manager.name = "PowerUpManager"
	add_child(power_up_manager)
	
	# Create ConsumableManager  
	var consumable_manager = preload("res://Scripts/Managers/ConsumableManager.gd").new()
	consumable_manager.name = "ConsumableManager"
	add_child(consumable_manager)
	
	# Create ModManager
	var mod_manager = preload("res://Scripts/Managers/ModManager.gd").new()
	mod_manager.name = "ModManager"
	add_child(mod_manager)

func _setup_shop_ui():
	print("Setting up ShopUI...")
	
	# Load the ShopUI scene
	var shop_scene = preload("res://Scenes/UI/shop_ui.tscn")
	shop_ui = shop_scene.instantiate()
	
	# Set the manager paths to match our test setup (use absolute paths)
	shop_ui.power_up_manager_path = get_node("PowerUpManager").get_path()
	shop_ui.consumable_manager_path = get_node("ConsumableManager").get_path()
	shop_ui.mod_manager_path = get_node("ModManager").get_path()
	
	add_child(shop_ui)
	shop_ui.show()

func _run_tests():
	print("\n--- Testing LOCKED Tab Presence ---")
	
	# Check if TabContainer exists
	var tab_container = shop_ui.get_node("TabContainer")
	if not tab_container:
		print("✗ TabContainer not found")
		return
	
	# Check if we have the expected tabs
	var tab_count = tab_container.get_tab_count()
	print("Total tabs found: %d" % tab_count)
	
	# Expected tabs: PowerUps, Consumables, Mods, Locked
	var expected_tabs = ["PowerUps", "Consumables", "Mods", "Locked"]
	var found_tabs = []
	
	for i in range(tab_count):
		var tab_name = tab_container.get_tab_title(i)
		found_tabs.append(tab_name)
		print("Tab %d: %s" % [i, tab_name])
	
	# Check if LOCKED tab exists
	if "Locked" in found_tabs:
		print("✓ LOCKED tab found")
	else:
		print("✗ LOCKED tab not found")
		print("Available tabs: %s" % str(found_tabs))
	
	# Test locked container access
	print("\n--- Testing LOCKED Container ---")
	var locked_container = shop_ui.get_node_or_null("TabContainer/Locked/GridContainer")
	if locked_container:
		print("✓ LOCKED container accessible")
	else:
		print("✗ LOCKED container not accessible")
	
	# Test populate_locked_items function
	print("\n--- Testing populate_locked_items() ---")
	if shop_ui.has_method("populate_locked_items"):
		print("✓ populate_locked_items method exists")
		shop_ui.populate_locked_items()
		
		# Check if any locked items were added
		if locked_container:
			var locked_item_count = locked_container.get_child_count()
			print("Locked items displayed: %d" % locked_item_count)
			if locked_item_count > 0:
				print("✓ Locked items populated successfully")
			else:
				print("! No locked items found (might be all unlocked)")
		else:
			print("✗ Cannot check locked items - container not found")
	else:
		print("✗ populate_locked_items method not found")
	
	# Test filtering functionality
	print("\n--- Testing Item Filtering ---")
	if shop_ui.has_method("_filter_unlocked_items"):
		print("✓ _filter_unlocked_items method exists")
		
		# Test with some sample items
		var test_items = ["step_by_step", "evens_no_odds", "wild_dots"]
		var filtered_items = shop_ui._filter_unlocked_items(test_items, "power_up")
		print("Test items: %s" % str(test_items))
		print("Filtered (unlocked) items: %s" % str(filtered_items))
		
		if filtered_items.size() < test_items.size():
			print("✓ Filtering is working - some items are locked")
		else:
			print("! All test items are unlocked")
	else:
		print("✗ _filter_unlocked_items method not found")
	
	print("\n=== Test Complete ===")
	test_completed = true

func _input(event):
	if test_completed and event.is_action_pressed("ui_accept"):
		print("Closing test...")
		get_tree().quit()