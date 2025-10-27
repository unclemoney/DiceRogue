extends Control

## shop_hover_test.gd
## Simple test to verify shop item hover tooltips work correctly

@onready var shop_item_scene = preload("res://Scenes/Shop/shop_item.tscn")
@onready var test_label: Label = $TestLabel

func _ready() -> void:
	test_label.text = "Testing Shop Hover Tooltips - Hover over items to see descriptions"
	_create_test_shop_items()

func _create_test_shop_items() -> void:
	# Load some test data
	var test_power_up_data = load("res://Scripts/PowerUps/ExtraDice.tres") as PowerUpData
	var test_consumable_data = load("res://Scripts/Consumable/QuickCashConsumable.tres") as ConsumableData
	
	if test_power_up_data:
		_create_shop_item(test_power_up_data, "power_up", Vector2(100, 100))
	else:
		print("[ShopHoverTest] Failed to load power up data")
	
	if test_consumable_data:
		_create_shop_item(test_consumable_data, "consumable", Vector2(250, 100))
	else:
		print("[ShopHoverTest] Failed to load consumable data")

func _create_shop_item(data: Resource, type: String, pos: Vector2) -> void:
	var shop_item = shop_item_scene.instantiate() as ShopItem
	add_child(shop_item)
	shop_item.position = pos
	shop_item.setup(data, type)
	
	print("[ShopHoverTest] Created shop item: ", data.display_name, " at ", pos)