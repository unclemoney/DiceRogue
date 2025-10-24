extends Control

func _ready() -> void:
	print("=== Simple Priority Test ===")
	_test_priority_function()
	print("=== Test Complete ===")

func _test_priority_function() -> void:
	print("\n--- Testing Category Priority Function ---")
	
	# Test that we can create the scorecard and call priority function
	var scorecard_script = preload("res://Scenes/ScoreCard/score_card.gd")
	var test_scorecard = scorecard_script.new()
	
	# Test priority values
	var three_priority = test_scorecard._get_category_priority("three_of_a_kind")
	var four_priority = test_scorecard._get_category_priority("four_of_a_kind")
	var yahtzee_priority = test_scorecard._get_category_priority("yahtzee")
	var chance_priority = test_scorecard._get_category_priority("chance")
	
	print("Three of a Kind priority:", three_priority)
	print("Four of a Kind priority:", four_priority)
	print("Yahtzee priority:", yahtzee_priority)
	print("Chance priority:", chance_priority)
	
	# Verify priorities are correct
	assert(four_priority > three_priority, "Four of a Kind should have higher priority than Three of a Kind")
	assert(yahtzee_priority > four_priority, "Yahtzee should have highest priority")
	assert(three_priority > chance_priority, "Three of a Kind should have higher priority than Chance")
	
	# Test autoscoring selection logic (without actual score calculation)
	print("- Testing selection logic...")
	
	# Simulate same scores with different priorities
	var categories = [
		{"name": "three_of_a_kind", "score": 12, "priority": three_priority},
		{"name": "four_of_a_kind", "score": 12, "priority": four_priority},
		{"name": "chance", "score": 12, "priority": chance_priority}
	]
	
	var best_category = ""
	var best_score = -1
	var best_priority = -1
	
	for category_data in categories:
		var score = category_data.score
		var priority = category_data.priority
		var category_name = category_data.name
		
		print("  %s: score=%d, priority=%d" % [category_name, score, priority])
		
		if score > best_score or (score == best_score and priority > best_priority):
			best_score = score
			best_category = category_name
			best_priority = priority
	
	print("Selected category:", best_category)
	
	# Should select Four of a Kind
	assert(best_category == "four_of_a_kind", "Should select Four of a Kind when scores are tied")
	
	print("✓ Priority system correctly selects Four of a Kind over Three of a Kind")