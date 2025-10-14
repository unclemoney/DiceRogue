extends Node
class_name StepByStepPowerUpTest

const StepByStepPowerUp = preload("res://Scripts/PowerUps/step_by_step_power_up.gd")

func _ready() -> void:
	print("\n=== StepByStepPowerUp Test Starting ===")
	await get_tree().create_timer(1.0).timeout
	_test_score_modifier_system()
	await get_tree().create_timer(1.0).timeout
	print("=== Test Complete ===")
	get_tree().quit()

func _test_score_modifier_system() -> void:
	print("\n--- Testing Score Modifier System ---")
	
	# Create a scorecard
	var scorecard = Scorecard.new()
	add_child(scorecard)
	
	# Create and apply the PowerUp
	var step_by_step_powerup = StepByStepPowerUp.new()
	add_child(step_by_step_powerup)
	step_by_step_powerup.apply(scorecard)
	
	# Test that the PowerUp is registered as a score modifier
	assert(scorecard.score_modifiers.has(step_by_step_powerup), "StepByStepPowerUpTest: Expected PowerUp to be registered as score modifier")
	
	# Test upper section score modification
	print("\n--- Testing Upper Section Score Modification ---")
	var upper_result = step_by_step_powerup.modify_score(Scorecard.Section.UPPER, "ones", 3)
	print("StepByStepPowerUpTest: Upper section modify_score result: %s" % str(upper_result))
	assert(upper_result == 9, "StepByStepPowerUpTest: Expected upper section score 3 + 6 = 9, got %s" % str(upper_result))
	
	# Test lower section score modification (should return null)
	print("\n--- Testing Lower Section Score Modification ---")
	var lower_result = step_by_step_powerup.modify_score(Scorecard.Section.LOWER, "full_house", 25)
	print("StepByStepPowerUpTest: Lower section modify_score result: %s" % str(lower_result))
	assert(lower_result == null, "StepByStepPowerUpTest: Expected lower section score to not be modified, got %s" % str(lower_result))
	
	# Test signal tracking
	print("\n--- Testing Signal Tracking ---")
	assert(step_by_step_powerup.upper_scores_applied == 0, "StepByStepPowerUpTest: Expected initial applied count to be 0")
	
	# Simulate score assignment
	scorecard.emit_signal("score_assigned", Scorecard.Section.UPPER, "twos", 8)
	await get_tree().process_frame
	
	assert(step_by_step_powerup.upper_scores_applied == 1, "StepByStepPowerUpTest: Expected applied count to be 1 after upper section score")
	
	# Simulate lower section score assignment (should not increment counter)
	scorecard.emit_signal("score_assigned", Scorecard.Section.LOWER, "chance", 23)
	await get_tree().process_frame
	
	assert(step_by_step_powerup.upper_scores_applied == 1, "StepByStepPowerUpTest: Expected applied count to remain 1 after lower section score")
	
	# Test removal
	step_by_step_powerup.remove(scorecard)
	assert(not scorecard.score_modifiers.has(step_by_step_powerup), "StepByStepPowerUpTest: Expected PowerUp to be unregistered after remove")
	assert(step_by_step_powerup.upper_scores_applied == 0, "StepByStepPowerUpTest: Expected applied count to reset after remove")
	
	# Clean up
	step_by_step_powerup.queue_free()
	scorecard.queue_free()
	
	print("StepByStepPowerUpTest: ✓ All tests passed - PowerUp correctly modifies only upper section scores")