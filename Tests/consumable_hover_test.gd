extends Control

## Simple test to create a ConsumableIcon and check its hover tooltip

@onready var test_label: Label = $TestLabel

func _ready() -> void:
	test_label = Label.new()
	test_label.text = "Testing Consumable Hover Tooltips - Hover over the consumable icon below"
	test_label.position = Vector2(10, 10)
	add_child(test_label)
	
	_create_test_consumable()

func _create_test_consumable() -> void:
	# Load test consumable data
	var test_consumable_data = load("res://Scripts/Consumable/QuickCashConsumable.tres") as ConsumableData
	
	if test_consumable_data:
		var consumable_icon = preload("res://Scenes/Consumable/consumable_icon.tscn").instantiate() as ConsumableIcon
		consumable_icon.position = Vector2(100, 100)
		consumable_icon.data = test_consumable_data
		add_child(consumable_icon)
		print("[ConsumableHoverTest] Created consumable icon: ", test_consumable_data.display_name)
	else:
		print("[ConsumableHoverTest] Failed to load consumable data")
		test_label.text = "ERROR: Failed to load consumable data"