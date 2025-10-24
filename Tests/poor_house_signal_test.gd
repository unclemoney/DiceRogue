extends Control

func _ready() -> void:
	print("=== Poor House Signal Test ===")
	_test_score_assigned_signal()
	print("=== Test Complete ===")

func _test_score_assigned_signal() -> void:
	print("\n--- Testing score_assigned signal behavior ---")
	
	# Test that ScoreModifierManager can register and unregister additives
	var score_modifier = get_node("/root/ScoreModifierManager")
	if not score_modifier:
		push_error("ScoreModifierManager not found")
		return
	
	print("Initial additives:", score_modifier.get_total_additive())
	
	# Register a test additive (simulating Poor House)
	score_modifier.register_additive("test_poor_house", 500)
	print("After registering test Poor House:", score_modifier.get_total_additive())
	
	# Create a test scorecard to verify signal emission
	var scorecard_script = preload("res://Scenes/ScoreCard/score_card.gd")
	var test_scorecard = scorecard_script.new()
	
	# Connect to the score_assigned signal
	test_scorecard.score_assigned.connect(_on_test_score_assigned)
	
	# Create a simple mock Poor House behavior
	var remove_bonus_callback = func(_section: int, _category: String, _score: int):
		score_modifier.unregister_additive("test_poor_house")
		print("Test: Removed poor house bonus after score_assigned signal")
	
	# Connect the callback to the signal
	test_scorecard.score_assigned.connect(remove_bonus_callback)
	
	# Trigger the signal
	print("- Emitting score_assigned signal...")
	test_scorecard.emit_signal("score_assigned", 0, "ones", 145)
	
	# Check that the bonus was removed
	print("After signal emission:", score_modifier.get_total_additive())
	
	# Verify the bonus was actually removed
	assert(score_modifier.get_total_additive() == 0, "Poor House bonus should be removed after scoring")
	
	print("✓ score_assigned signal correctly triggers Poor House bonus removal")

func _on_test_score_assigned(_section: int, category: String, score: int) -> void:
	print("Test signal received: %s = %d" % [category, score])