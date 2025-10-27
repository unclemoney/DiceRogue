extends Control

## Test to debug shop item hover issues

func _ready():
	print("[ShopHoverDebugTest] Starting shop hover debug test...")
	
	# Load and instantiate a shop item
	var shop_item_scene = preload("res://Scenes/Shop/shop_item.tscn")
	var shop_item = shop_item_scene.instantiate()
	
	add_child(shop_item)
	
	# Position it where we can see it
	shop_item.position = Vector2(100, 100)
	shop_item.size = Vector2(200, 150)
	
	# Create test data using existing PowerUp resource
	var test_data = load("res://Scripts/PowerUps/BonusMoneyPowerUp.tres") as PowerUpData
	if not test_data:
		print("[ShopHoverDebugTest] ERROR: Could not load test PowerUp data!")
		return
	
	# Setup the shop item with test data
	shop_item.setup(test_data, "powerup")
	
	print("[ShopHoverDebugTest] Test shop item created at position: ", shop_item.position)
	print("[ShopHoverDebugTest] Test shop item size: ", shop_item.size)
	print("[ShopHoverDebugTest] Test shop item has hover tooltip: ", shop_item.hover_tooltip != null)
	
	# Wait a bit then manually check connections
	await get_tree().create_timer(1.0).timeout
	
	# Check if mouse signals are connected
	var mouse_entered_connections = shop_item.mouse_entered.get_connections()
	var mouse_exited_connections = shop_item.mouse_exited.get_connections()
	
	print("[ShopHoverDebugTest] Mouse entered connections: ", mouse_entered_connections.size())
	print("[ShopHoverDebugTest] Mouse exited connections: ", mouse_exited_connections.size())
	
	# Check if the shop item can receive input
	print("[ShopHoverDebugTest] Shop item mouse filter: ", shop_item.mouse_filter)
	
	# Let's also manually trigger the hover
	await get_tree().create_timer(2.0).timeout
	print("[ShopHoverDebugTest] Manually triggering mouse entered...")
	shop_item._on_mouse_entered()
	
	await get_tree().create_timer(3.0).timeout
	print("[ShopHoverDebugTest] Manually triggering mouse exited...")
	shop_item._on_mouse_exited()