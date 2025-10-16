extends Node
class_name GreenMonsterTest

func _ready() -> void:
    print("\n=== Green Monster PowerUp Test Starting ===")
    await get_tree().create_timer(0.5).timeout
    _test_green_dice_multiplier()

func _test_green_dice_multiplier() -> void:
    print("--- Testing Green Dice Multiplier ---")
    
    # Get the game controller and scorecard
    var game_controller = get_tree().get_first_node_in_group("game_controllers")
    if not game_controller:
        print("❌ Could not find GameController")
        return
    
    var scorecard = game_controller.scorecard
    if not scorecard:
        print("❌ Could not find Scorecard")
        return
    
    	# Create a GreenMonsterPU instance
    var power_up_scene = load("res://Scenes/PowerUp/GreenWithEnvy.tscn")
    var power_up = power_up_scene.instantiate()
    add_child(power_up)
    
    # Set initial state
    power_up.total_green_dice_scored = 5  # 5 green dice already scored
    
    # Apply the power up (will connect to scorecard signals)
    power_up.apply(self)
    
    # Get initial money
    var initial_money = PlayerEconomy.get_money()
    print("Initial money: $%d" % initial_money)
    
    # Create mock dice array with green dice
    var mock_dice_array = _create_mock_green_dice_array()
    
    # Simulate score assignment by calling the signal handler directly
    print("Simulating score assignment with 3 green dice of value 4 each")
    power_up._on_score_assigned("ones", mock_dice_array, 12, 12)
    
    # Check final money
    var final_money = PlayerEconomy.get_money()
    var money_gained = final_money - initial_money
    
    print("Final money: $%d" % final_money)
    print("Money gained: $%d" % money_gained)
    
    var expected_bonus = 5
    
    if money_gained >= expected_bonus:
        print("✓ Green Monster multiplier working correctly!")
        print("  Expected: $%d bonus" % expected_bonus)
        print("  Actual gained: $%d" % money_gained)
    else:
        print("❌ Green Monster multiplier not working properly")
        print("  Expected: $%d bonus" % expected_bonus)
        print("  Actual gained: $%d" % money_gained)
    
    # Test description update
    var description = power_up.get_current_description()
    print("Current description: %s" % description)
    
    # Cleanup
    power_up.remove(self)
    power_up.queue_free()
    
    print("GreenMonsterTest: Test completed")

func _create_mock_green_dice_array() -> Array:
    var dice_array = []
    const DiceColorClass = preload("res://Scripts/Core/dice_color.gd")
    
    for i in range(3):  # 3 green dice
        var mock_dice = MockDice.new()
        mock_dice.value = 4
        mock_dice.color = DiceColorClass.Type.GREEN
        dice_array.append(mock_dice)
    
    return dice_array

# Simple mock dice class for testing
class MockDice:
    var value: int = 1
    var color: int = 0  # DiceColor.Type.NONE
    
    func get_value() -> int:
        return value
    
    func get_color() -> int:
        return color
