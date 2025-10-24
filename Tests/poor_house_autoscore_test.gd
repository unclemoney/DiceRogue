extends Control

var game_controller: GameController
var scorecard: Scorecard

func _ready() -> void:
	print("=== Poor House Autoscore Test ===")
	_setup_test_environment()
	_test_poor_house_autoscore_bug()
	print("=== Test Complete ===")

func _setup_test_environment() -> void:
	# Get references to game systems
	game_controller = get_tree().get_first_node_in_group("game_controller")
	if not game_controller:
		push_error("GameController not found")
		return
	
	scorecard = game_controller.scorecard
	if not scorecard:
		push_error("Scorecard not found")
		return
	
	print("✓ Test environment setup complete")

func _test_poor_house_autoscore_bug() -> void:
	print("\n--- Testing Poor House + Autoscore Bug ---")
	
	# Give player some money
	var player_economy = get_node("/root/PlayerEconomy")
	player_economy.money = 500
	
	# Grant Poor House consumable
	game_controller.grant_consumable("poor_house")
	
	# Activate Poor House - this should register the bonus
	var poor_house = game_controller.consumable_manager.get_consumable_by_id("poor_house")
	if poor_house:
		poor_house.apply(game_controller)
		print("✓ Poor House activated - bonus should be registered")
	
	# Check that bonus is registered
	var score_modifier = get_node("/root/ScoreModifierManager")
	if score_modifier:
		print("Additives before scoring:", score_modifier.get_total_additive())
	
	# Simulate manual scoring - this should remove the Poor House bonus
	print("- Simulating manual score...")
	scorecard.set_score(Scorecard.Section.UPPER, "ones", 145)  # This should trigger score_assigned signal
	
	# Check that bonus is removed
	print("Additives after manual scoring:", score_modifier.get_total_additive())
	
	# Now test autoscoring - should NOT have Poor House bonus
	print("- Testing autoscore calculation...")
	var dice_values = [3, 3, 3, 3, 3]  # Should score well in multiple categories
	
	# Check what autoscoring thinks the best score is
	var best_score = -1
	var best_category = ""
	
	for category in scorecard.lower_scores.keys():
		if scorecard.lower_scores[category] == null:
			var score = scorecard.evaluate_category(category, dice_values)
			print("  %s: %d points" % [category, score])
			if score > best_score:
				best_score = score
				best_category = category
	
	print("✓ Best autoscore option: %s = %d points" % [best_category, best_score])
	
	# The key test: best_score should NOT include Poor House bonus
	assert(best_score < 100, "Autoscore should not include Poor House bonus after manual scoring")
	
	print("✓ Poor House autoscore bug test passed!")