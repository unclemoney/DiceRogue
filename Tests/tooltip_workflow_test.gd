extends Control

## Test to verify complete tooltip workflow including deferred creation

var test_shop_item: ShopItem

func _ready():
	print("[TooltipWorkflowTest] Starting complete tooltip workflow test...")
	
	# Create background that could interfere (to test our mouse filter fix)
	var background = ColorRect.new()
	background.color = Color(0.2, 0.2, 0.3, 1.0)
	background.size = get_viewport().get_visible_rect().size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE  # This should be set by our fix
	add_child(background)
	
	# Create a container to simulate shop layout
	var container = VBoxContainer.new()
	container.position = Vector2(200, 150)
	add_child(container)
	
	# Load shop item scene and data
	var shop_item_scene = preload("res://Scenes/Shop/shop_item.tscn")
	test_shop_item = shop_item_scene.instantiate()
	
	# Add to container (simulating shop layout)
	container.add_child(test_shop_item)
	
	# Setup with real data
	var bonus_money_data = load("res://Scripts/PowerUps/BonusMoneyPowerUp.tres") as PowerUpData
	if bonus_money_data:
		test_shop_item.setup(bonus_money_data, "power_up")
		print("[TooltipWorkflowTest] Shop item setup initiated")
		
		# Wait for deferred tooltip creation
		await get_tree().process_frame
		await get_tree().process_frame  # Extra frame to ensure deferred operations complete
		
		print("[TooltipWorkflowTest] After deferred frames:")
		print("[TooltipWorkflowTest]   Tooltip exists: ", test_shop_item.hover_tooltip != null)
		if test_shop_item.hover_tooltip:
			print("[TooltipWorkflowTest]   Tooltip parent: ", test_shop_item.hover_tooltip.get_parent().name)
			print("[TooltipWorkflowTest]   Tooltip visible: ", test_shop_item.hover_tooltip.visible)
		
		# Test manual mouse events
		print("[TooltipWorkflowTest] Testing manual mouse entered...")
		test_shop_item._on_mouse_entered()
		
		if test_shop_item.hover_tooltip:
			print("[TooltipWorkflowTest]   After mouse entered - visible: ", test_shop_item.hover_tooltip.visible)
			print("[TooltipWorkflowTest]   Tooltip position: ", test_shop_item.hover_tooltip.global_position)
		
		await get_tree().create_timer(2.0).timeout
		
		print("[TooltipWorkflowTest] Testing manual mouse exited...")
		test_shop_item._on_mouse_exited()
		
		if test_shop_item.hover_tooltip:
			print("[TooltipWorkflowTest]   After mouse exited - visible: ", test_shop_item.hover_tooltip.visible)
		
		# Final connection verification
		var connections = test_shop_item.mouse_entered.get_connections()
		print("[TooltipWorkflowTest] Mouse entered connections: ", connections.size())
		
	else:
		print("[TooltipWorkflowTest] Failed to load test data")
	
	# Create instruction label
	var instruction = Label.new()
	instruction.text = "Tooltip Workflow Test\nShop item should have working hover tooltip"
	instruction.position = Vector2(50, 50)
	instruction.add_theme_font_size_override("font_size", 16)
	add_child(instruction)
	
	print("[TooltipWorkflowTest] Test complete. Try hovering over the shop item.")