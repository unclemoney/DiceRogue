extends Control

## Test shop UI with real items to check mouse hover

func _ready():
	print("[ShopHoverRealTest] Starting real shop test...")
	
	# Load shop UI scene
	var shop_scene = preload("res://Scenes/UI/shop_ui.tscn")
	var shop_ui = shop_scene.instantiate()
	
	add_child(shop_ui)
	
	# Wait for it to initialize
	await get_tree().process_frame
	
	# Load some test data and manually add items
	var bonus_money_data = load("res://Scripts/PowerUps/BonusMoneyPowerUp.tres") as PowerUpData
	
	if bonus_money_data and shop_ui.has_method("_add_shop_item"):
		print("[ShopHoverRealTest] Adding test item to shop...")
		shop_ui._add_shop_item(bonus_money_data, "power_up")
		
		# Wait a moment for setup
		await get_tree().create_timer(1.0).timeout
		
		# Find the shop item that was created
		var power_up_container = shop_ui.power_up_container
		if power_up_container:
			print("[ShopHoverRealTest] PowerUp container found:", power_up_container.name)
			print("[ShopHoverRealTest] PowerUp container class:", power_up_container.get_class())
			print("[ShopHoverRealTest] PowerUp container children:", power_up_container.get_child_count())
			
			for child in power_up_container.get_children():
				print("[ShopHoverRealTest] Container child:", child.name, "class:", child.get_class())
				if child is ShopItem:
					var shop_item = child as ShopItem
					print("[ShopHoverRealTest] Found ShopItem:", shop_item.item_id)
					print("[ShopHoverRealTest] ShopItem position:", shop_item.global_position)
					print("[ShopHoverRealTest] ShopItem size:", shop_item.size)
					print("[ShopHoverRealTest] ShopItem mouse filter:", shop_item.mouse_filter)
					print("[ShopHoverRealTest] ShopItem has tooltip:", shop_item.hover_tooltip != null)
					print("[ShopHoverRealTest] ShopItem visible:", shop_item.visible)
					print("[ShopHoverRealTest] ShopItem parent clipping:", shop_item.get_parent().clip_contents)
					
					# Test manual hover
					await get_tree().create_timer(1.0).timeout
					print("[ShopHoverRealTest] Testing manual hover...")
					shop_item._on_mouse_entered()
					
					await get_tree().create_timer(2.0).timeout
					shop_item._on_mouse_exited()
					break
		else:
			print("[ShopHoverRealTest] PowerUp container not found!")
	else:
		print("[ShopHoverRealTest] Could not load test data or shop UI missing method")
	
	await get_tree().create_timer(5.0).timeout
	get_tree().quit()