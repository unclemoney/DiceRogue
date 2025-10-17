extends Node
class_name RedPowerRangerTest

const RedPowerRangerPowerUpClass = preload("res://Scripts/PowerUps/red_power_ranger_power_up.gd")

func _ready() -> void:
	print("\n=== RedPowerRangerTest Starting ===")
	await get_tree().create_timer(0.5).timeout
	_test_red_dice_scoring()

func _test_red_dice_scoring() -> void:
	print("\n--- Testing Red Dice Scoring ---")
	
	# Create test objects
	var scorecard = Scorecard.new()
	var power_up = RedPowerRangerPowerUpClass.new()
	power_up.id = "red_power_ranger"
	
	# Apply the power-up to scorecard
	power_up.apply(scorecard)
	
	# Create mock red dice in DiceResults
	var mock_dice = []
	for i in range(2):
		var dice = Dice.new()
		dice.value = 5  # Red five
		dice.force_color(DiceColor.Type.RED)
		mock_dice.append(dice)
	
	# Add a normal dice
	var normal_dice = Dice.new()
	normal_dice.value = 3
	normal_dice.force_color(DiceColor.Type.NONE)
	mock_dice.append(normal_dice)
	
	# Update DiceResults
	DiceResults.dice_refs = mock_dice
	
	# Test initial state
	assert(power_up.total_red_dice_scored == 0, "Initial red dice count should be 0")
	assert(power_up.current_additive == 0, "Initial additive should be 0")
	print("RedPowerRangerTest: ✓ Initial state correct")
	
	# Simulate scoring with red dice
	scorecard.emit_signal("score_assigned", Scorecard.Section.LOWER, "chance", 15)
	
	# Verify red dice were counted
	assert(power_up.total_red_dice_scored == 2, "Should have counted 2 red dice")
	assert(power_up.current_additive == 10, "Should have +10 additive (5+5)")
	print("RedPowerRangerTest: ✓ Red dice scoring works")
	
	# Test ScoreModifierManager integration
	var total_additive = ScoreModifierManager.get_total_additive()
	assert(total_additive >= 10, "ScoreModifierManager should include our additive")
	print("RedPowerRangerTest: ✓ ScoreModifierManager integration works")
	
	# Test description update
	var description = power_up.get_current_description()
	assert("Red dice scored: 2" in description, "Description should show red dice count")
	assert("Current additive: +10" in description, "Description should show current additive")
	print("RedPowerRangerTest: ✓ Description updates correctly")
	
	# Test another scoring event
	var more_dice = []
	var red_dice = Dice.new()
	red_dice.value = 6
	red_dice.force_color(DiceColor.Type.RED)
	more_dice.append(red_dice)
	DiceResults.dice_refs = more_dice
	
	scorecard.emit_signal("score_assigned", Scorecard.Section.UPPER, "sixes", 6)
	
	# Verify cumulative effect
	assert(power_up.total_red_dice_scored == 3, "Should have counted 3 total red dice")
	assert(power_up.current_additive == 16, "Should have +16 additive (10+6)")
	print("RedPowerRangerTest: ✓ Cumulative scoring works")
	
	# Test cleanup
	power_up.remove(scorecard)
	var cleanup_additive = ScoreModifierManager.get_additive("red_power_ranger")
	assert(cleanup_additive == 0, "Additive should be removed after cleanup")
	print("RedPowerRangerTest: ✓ Cleanup works correctly")
	
	print("\n=== RedPowerRangerTest PASSED ===")

# Helper to create mock dice
func _create_mock_dice(value: int, color: DiceColor.Type) -> Dice:
	var dice = Dice.new()
	dice.value = value
	dice.force_color(color)
	return dice