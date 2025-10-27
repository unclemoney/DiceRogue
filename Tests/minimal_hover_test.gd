extends Control

## Minimal test to verify mouse hover works with shop items

func _ready():
	print("[MinimalHoverTest] Creating minimal shop item test...")
	
	# Create a simple background
	var bg = ColorRect.new()
	bg.color = Color(0.2, 0.2, 0.3, 1.0)
	bg.size = get_viewport().get_visible_rect().size
	add_child(bg)
	
	# Create shop item directly
	var shop_item_scene = preload("res://Scenes/Shop/shop_item.tscn")
	var shop_item = shop_item_scene.instantiate()
	
	add_child(shop_item)
	
	# Position it clearly
	shop_item.position = Vector2(300, 200)
	shop_item.custom_minimum_size = Vector2(150, 180)
	
	# Setup with real data
	var bonus_money_data = load("res://Scripts/PowerUps/BonusMoneyPowerUp.tres") as PowerUpData
	if bonus_money_data:
		shop_item.setup(bonus_money_data, "power_up")
		print("[MinimalHoverTest] Shop item setup complete")
		print("[MinimalHoverTest] Item ID:", shop_item.item_id)
		print("[MinimalHoverTest] Tooltip exists:", shop_item.hover_tooltip != null)
		
		# Add some debug prints to verify connections
		var connections = shop_item.mouse_entered.get_connections()
		print("[MinimalHoverTest] Mouse entered connections:", connections.size())
		for connection in connections:
			print("[MinimalHoverTest] Connected to:", connection.callable.get_method())
		
		# Let's also manually test the tooltip visibility
		await get_tree().create_timer(2.0).timeout
		print("[MinimalHoverTest] Testing tooltip manually...")
		shop_item._on_mouse_entered()
		print("[MinimalHoverTest] Tooltip should now be visible:", shop_item.hover_tooltip.visible)
		print("[MinimalHoverTest] Tooltip position:", shop_item.hover_tooltip.global_position)
		
		await get_tree().create_timer(3.0).timeout
		shop_item._on_mouse_exited()
		print("[MinimalHoverTest] Tooltip should now be hidden:", shop_item.hover_tooltip.visible)
	else:
		print("[MinimalHoverTest] Failed to load test data")
	
	# Create label for instructions
	var label = Label.new()
	label.text = "Hover over the shop item to test tooltip\nPosition: (300, 200)\nSize: (150, 180)"
	label.position = Vector2(50, 50)
	label.add_theme_font_size_override("font_size", 16)
	add_child(label)
	
	print("[MinimalHoverTest] Test setup complete. Try hovering over the shop item.")