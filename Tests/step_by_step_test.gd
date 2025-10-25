extends Node

## Test script for StepByStep PowerUp logbook integration
## Tests conditional registration with ScoreModifierManager

func _ready():
	print("=== StepByStep PowerUp Test ===")
	
	# Give the scene tree a moment to initialize
	await get_tree().process_frame
	
	# Test 1: Check PowerUp creation and initial state
	print("\n--- Test 1: PowerUp Creation ---")
	var step_by_step = preload("res://Scripts/PowerUps/step_by_step_power_up.gd").new()
	print("StepByStep PowerUp created")
	
	# Test 2: Create a mock scorecard and add to scene tree
	print("\n--- Test 2: Mock Scorecard Setup ---")
	var mock_scorecard = Scorecard.new()
	add_child(mock_scorecard)  # Add to scene tree so get_tree() works
	print("Mock scorecard created and added to scene tree")
	
	# Test 3: Apply the PowerUp
	print("\n--- Test 3: Apply PowerUp ---")
	step_by_step.apply(mock_scorecard)
	print("PowerUp applied to scorecard")
	
	# Test 4: Check ScoreModifierManager state initially
	print("\n--- Test 4: Initial ScoreModifierManager State ---")
	var manager = ScoreModifierManager
	if manager:
		var active_sources = manager.get_active_additive_sources()
		print("Active additive sources initially: ", active_sources)
		if active_sources.has("step_by_step"):
			print("[UNEXPECTED] step_by_step should NOT be registered initially")
		else:
			print("[EXPECTED] step_by_step not registered initially (conditional)")
	
	# Test 5: Direct method testing (bypass ScoreCardUI)
	print("\n--- Test 5: Direct Method Testing ---")
	
	# Test direct registration for upper section
	print("Testing direct registration for upper section:")
	step_by_step._on_about_to_score(Scorecard.Section.UPPER, "ones", [1, 1, 1, 1, 1])
	var active_sources_after_ones = manager.get_active_additive_sources()
	print("Active additive sources after ones: ", active_sources_after_ones)
	
	if active_sources_after_ones.has("step_by_step"):
		print("[EXPECTED] step_by_step registered for upper section")
		var additive_value = manager.get_additive("step_by_step")
		print("step_by_step additive value: ", additive_value)
	else:
		print("[ISSUE] step_by_step should be registered for upper section")
	
	# Test scoring completion cleanup
	print("\nTesting scoring completion cleanup:")
	step_by_step._on_score_assigned(Scorecard.Section.UPPER, "ones", 5)
	var active_sources_after_scoring = manager.get_active_additive_sources()
	print("Active additive sources after score_assigned: ", active_sources_after_scoring)
	
	if active_sources_after_scoring.has("step_by_step"):
		print("[ISSUE] step_by_step should be unregistered after scoring")
	else:
		print("[EXPECTED] step_by_step unregistered after scoring")
	
	# Test 6: Test lower section (should not register)
	print("\n--- Test 6: Lower Section Testing ---")
	step_by_step._on_about_to_score(Scorecard.Section.LOWER, "full_house", [1, 1, 1, 2, 2])
	var active_sources_lower = manager.get_active_additive_sources()
	print("Active additive sources after full_house: ", active_sources_lower)
	
	if active_sources_lower.has("step_by_step"):
		print("[ISSUE] step_by_step should NOT register for lower section")
	else:
		print("[EXPECTED] step_by_step not registered for lower section")
	
	# Test 7: Cleanup
	print("\n--- Test 7: Cleanup ---")
	step_by_step.remove(mock_scorecard)
	var active_sources_final = manager.get_active_additive_sources()
	print("Active additive sources after removal: ", active_sources_final)
	
	print("\n=== Test Complete ===")
	print("StepByStep PowerUp is ready for logbook integration!")
	
	# Exit after a moment
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()