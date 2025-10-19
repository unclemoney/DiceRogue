extends Node
## Test script to debug auto-scoring display issues
##
## Run this scene to test auto-scoring logic

func _ready():
	print("\n=== Auto-Scoring Debug Test ===")
	
	# Get references to scorecard and UI
	var scorecard = get_tree().get_first_node_in_group("scorecard")
	var score_card_ui = get_tree().get_first_node_in_group("score_card_ui")
	
	if not scorecard:
		print("ERROR: No scorecard found!")
		return
		
	if not score_card_ui:
		print("ERROR: No score card UI found!")
		return
	
	print("Found scorecard and UI")
	
	# Test with some dice values
	var test_dice = [1, 2, 3, 4, 5]
	
	print("\n--- Initial State ---")
	print("Upper scores:", scorecard.upper_scores)
	print("Lower scores:", scorecard.lower_scores)
	
	# Test the display preview
	print("\n--- Testing Display Preview ---")
	score_card_ui.update_best_hand_preview(test_dice)
	
	# Manually check what auto-score would do
	print("\n--- Testing Auto-Score Logic ---")
	var best_score = -1
	var best_category = ""
	
	# Check upper section
	for category in scorecard.upper_scores.keys():
		if scorecard.upper_scores[category] == null:
			var score = scorecard.evaluate_category(category, test_dice)
			print("Upper category:", category, "is null:", scorecard.upper_scores[category] == null, "score:", score)
			if score > best_score:
				best_score = score
				best_category = category
	
	# Check lower section
	for category in scorecard.lower_scores.keys():
		if scorecard.lower_scores[category] == null:
			var score = scorecard.evaluate_category(category, test_dice)
			print("Lower category:", category, "is null:", scorecard.lower_scores[category] == null, "score:", score)
			if score > best_score:
				best_score = score
				best_category = category
	
	print("Manual calculation - Best category:", best_category, "with score:", best_score)
	
	# Now fill chance and test again
	print("\n--- Filling Chance Category ---")
	scorecard.set_score(Scorecard.Section.LOWER, "chance", 15)
	print("Chance filled with 15")
	print("Chance is now:", scorecard.lower_scores["chance"])
	
	# Test again
	print("\n--- Testing After Filling Chance ---")
	score_card_ui.update_best_hand_preview(test_dice)
	
	# Manual check again
	best_score = -1
	best_category = ""
	
	for category in scorecard.upper_scores.keys():
		if scorecard.upper_scores[category] == null:
			var score = scorecard.evaluate_category(category, test_dice)
			print("Upper category:", category, "is null:", scorecard.upper_scores[category] == null, "score:", score)
			if score > best_score:
				best_score = score
				best_category = category
	
	for category in scorecard.lower_scores.keys():
		if scorecard.lower_scores[category] == null:
			var score = scorecard.evaluate_category(category, test_dice)
			print("Lower category:", category, "is null:", scorecard.lower_scores[category] == null, "score:", score)
			if score > best_score:
				best_score = score
				best_category = category
	
	print("After filling chance - Best category:", best_category, "with score:", best_score)