extends Control

func _ready() -> void:
	print("=== Autoscoring Priority Test ===")
	_test_four_of_a_kind_priority()
	print("=== Test Complete ===")

func _test_four_of_a_kind_priority() -> void:
	print("\n--- Testing Four of a Kind vs Three of a Kind Priority ---")
	
	# Create test scorecard
	var scorecard_script = preload("res://Scenes/ScoreCard/score_card.gd")
	var test_scorecard = scorecard_script.new()
	
	# Test dice that qualify for both 3 of a kind and 4 of a kind
	var test_dice: Array[int] = [2, 2, 2, 4, 2]  # Four 2s + one 4 = sum 12
	
	print("Test dice:", test_dice)
	
	# Calculate scores for both categories
	var three_of_kind_score = test_scorecard.evaluate_category("three_of_a_kind", test_dice)
	var four_of_kind_score = test_scorecard.evaluate_category("four_of_a_kind", test_dice)
	
	print("Three of a Kind score:", three_of_kind_score)
	print("Four of a Kind score:", four_of_kind_score)
	
	# Both should be 12 (sum of all dice)
	assert(three_of_kind_score == 12, "Three of a Kind should score 12")
	assert(four_of_kind_score == 12, "Four of a Kind should score 12")
	
	# Test category priorities
	var three_priority = test_scorecard._get_category_priority("three_of_a_kind")
	var four_priority = test_scorecard._get_category_priority("four_of_a_kind")
	
	print("Three of a Kind priority:", three_priority)
	print("Four of a Kind priority:", four_priority)
	
	# Four of a Kind should have higher priority
	assert(four_priority > three_priority, "Four of a Kind should have higher priority than Three of a Kind")
	
	# Test autoscoring selection
	print("- Testing autoscoring logic...")
	
	# Clear scorecard first to ensure clean test
	for category in test_scorecard.lower_scores.keys():
		test_scorecard.lower_scores[category] = null
	
	# Manually simulate the autoscoring logic
	var best_score = -1
	var best_category = ""
	var best_priority = -1
	
	for category in test_scorecard.lower_scores.keys():
		if test_scorecard.lower_scores[category] == null:
			var score = test_scorecard.evaluate_category(category, test_dice)
			var priority = test_scorecard._get_category_priority(category)
			
			print("  %s: score=%d, priority=%d" % [category, score, priority])
			
			if score > best_score or (score == best_score and priority > best_priority):
				best_score = score
				best_category = category
				best_priority = priority
	
	print("Best category selected:", best_category, "with score:", best_score)
	
	# Should select Four of a Kind over Three of a Kind
	assert(best_category == "four_of_a_kind", "Autoscoring should prefer Four of a Kind over Three of a Kind")
	
	print("✓ Autoscoring correctly prefers Four of a Kind over Three of a Kind")