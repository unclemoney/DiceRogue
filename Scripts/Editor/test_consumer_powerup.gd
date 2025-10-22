extends Node

## Test script to verify TheConsumerIsAlwaysRight PowerUp works correctly
## This script manually tests the flow: grant power-up -> use consumable -> check multiplier

func _ready() -> void:
	print("=== Testing TheConsumerIsAlwaysRight PowerUp ===")
	
	# Wait a frame for everything to initialize
	await get_tree().process_frame
	
	# Get required managers
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	var power_up_manager = get_tree().get_first_node_in_group("power_up_manager")
	var statistics = Statistics
	var score_modifier_manager = ScoreModifierManager
	
	if not game_controller:
		print("ERROR: No GameController found")
		return
	if not power_up_manager:
		print("ERROR: No PowerUpManager found")
		return
		
	print("Found required managers")
	
	# 1. Check initial state
	print("Initial consumables used:", statistics.consumables_used)
	print("Initial total multiplier:", score_modifier_manager.get_total_multiplier())
	
	# 2. Grant the PowerUp
	print("\n--- Granting PowerUp ---")
	game_controller.grant_power_up("the_consumer_is_always_right")
	await get_tree().process_frame
	
	print("Granted PowerUp, checking multiplier:", score_modifier_manager.get_total_multiplier())
	
	# 3. Simulate using a consumable
	print("\n--- Using a consumable ---")
	
	# Method 1: Direct signal emission
	print("Emitting consumable_used signal...")
	game_controller.emit_signal("consumable_used", "test_consumable", null)
	await get_tree().process_frame
	
	print("After first consumable use:")
	print("  Consumables used:", statistics.consumables_used)
	print("  Total multiplier:", score_modifier_manager.get_total_multiplier())
	
	# 4. Use another consumable
	print("\n--- Using second consumable ---")
	game_controller.emit_signal("consumable_used", "test_consumable_2", null)
	await get_tree().process_frame
	
	print("After second consumable use:")
	print("  Consumables used:", statistics.consumables_used)
	print("  Total multiplier:", score_modifier_manager.get_total_multiplier())
	
	# 5. Test score calculation
	print("\n--- Testing score calculation ---")
	var scorecard = get_tree().get_first_node_in_group("scorecard")
	if scorecard:
		var test_dice = [1, 1, 1, 2, 3]  # Three of a kind
		var result = scorecard.calculate_score_with_breakdown("three_of_a_kind", test_dice)
		print("Base score for 3-of-a-kind with", test_dice, ":", result.breakdown_info.base_score)
		print("Total multiplier applied:", result.breakdown_info.total_multiplier)
		print("Final score:", result.breakdown_info.final_score)
	else:
		print("ERROR: No Scorecard found")
	
	print("\n=== Test Complete ===")