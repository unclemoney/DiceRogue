extends Control
class_name GreenDiceMoneyTest

## Test to debug Green dice money issues

@onready var test_label: Label = $VBoxContainer/TestLabel
@onready var test_button: Button = $VBoxContainer/TestButton  
@onready var results_label: Label = $VBoxContainer/ResultsLabel

func _ready() -> void:
	if test_label:
		test_label.text = "Green Dice Money Debug Test"
	
	if test_button:
		test_button.text = "Test Green Dice Money"
		test_button.pressed.connect(_on_test_pressed)
	
	if results_label:
		results_label.text = "Ready to test Green dice money..."

func _on_test_pressed() -> void:
	print("\n=== Green Dice Money Debug Test ===")
	
	if not DiceColorManager:
		_show_result("✗ DiceColorManager not available")
		return
	
	# Create a mock dice with Green color and value 2
	var _mock_dice_array = []
	
	# Simulate Green dice effects calculation
	_show_result("✓ Testing Green dice money calculation...")
	
	# Test direct DiceColorManager calculation
	var empty_effects = DiceColorManager.calculate_color_effects([])
	_show_result("Empty array effects: " + str(empty_effects))
	
	# Check if we can access PlayerEconomy
	if PlayerEconomy:
		var current_money = PlayerEconomy.money
		_show_result("Current player money: $" + str(current_money))
		
		# Test adding money directly
		PlayerEconomy.add_money(5)
		var new_money = PlayerEconomy.money
		_show_result("After adding $5: $" + str(new_money))
	else:
		_show_result("✗ PlayerEconomy not available")

func _show_result(message: String) -> void:
	print("[GreenDiceMoneyTest] " + message)
	if results_label:
		results_label.text += message + "\n"