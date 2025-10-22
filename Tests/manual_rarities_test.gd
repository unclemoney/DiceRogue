extends Node

# Quick test script for TheRarities
# This can be attached to any node and run manually

func test_the_rarities():
	print("\n=== Manual TheRarities Test ===")
	
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if not game_controller:
		print("No GameController found")
		return
	
	# Show current money
	print("Starting money: $%d" % PlayerEconomy.money)
	
	# Show current PowerUps and their rarities
	print("\nCurrent PowerUps:")
	if game_controller.active_power_ups.is_empty():
		print("  No PowerUps owned")
	else:
		for power_up_id in game_controller.active_power_ups.keys():
			var def = game_controller.pu_manager.get_def(power_up_id)
			if def:
				print("  - %s (rarity: %s)" % [def.display_name, def.rarity])
	
	# Grant TheRarities and test
	print("\nGranting TheRarities consumable...")
	game_controller.grant_consumable("the_rarities")
	
	# Show usage instructions
	print("\nTo test TheRarities:")
	print("1. Use debug panel (F12) to grant some PowerUps of different rarities")
	print("2. Click on TheRarities in the consumable UI to use it")
	print("3. Observe the money increase in the UI")
	print("4. Check console for payment breakdown")
	print("\nExpected payments per rarity:")
	print("  Common: $20 each")
	print("  Uncommon: $25 each") 
	print("  Rare: $50 each")
	print("  Epic: $75 each")
	print("  Legendary: $150 each")

# Call this manually in the debugger or via debug panel
func _ready():
	print("TheRarities test script loaded. Call test_the_rarities() to run test.")