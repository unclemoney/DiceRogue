extends Control

## Simple test to verify mouse input specifically

var shop_item: ShopItem

func _ready():
	print("[MouseInputTest] Starting mouse input test...")
	
	# Create shop item directly  
	var shop_item_scene = preload("res://Scenes/Shop/shop_item.tscn")
	shop_item = shop_item_scene.instantiate()
	
	add_child(shop_item)
	
	# Position it clearly visible
	shop_item.position = Vector2(200, 200)
	shop_item.size = Vector2(200, 200)
	
	# Setup with test data
	var bonus_money_data = load("res://Scripts/PowerUps/BonusMoneyPowerUp.tres") as PowerUpData
	shop_item.setup(bonus_money_data, "power_up")
	
	print("[MouseInputTest] Shop item created and positioned")
	print("[MouseInputTest] Position:", shop_item.global_position)
	print("[MouseInputTest] Size:", shop_item.size)
	
	# Connect to input events to see what's happening
	shop_item.gui_input.connect(_on_shop_item_input)
	
	await get_tree().create_timer(10.0).timeout
	get_tree().quit()

func _on_shop_item_input(event: InputEvent):
	print("[MouseInputTest] Received input event:", event.get_class())
	if event is InputEventMouseMotion:
		var mouse_event = event as InputEventMouseMotion
		print("[MouseInputTest] Mouse motion at:", mouse_event.position)
	elif event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		print("[MouseInputTest] Mouse button:", mouse_event.button_index, "pressed:", mouse_event.pressed)