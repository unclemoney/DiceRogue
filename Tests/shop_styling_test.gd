extends Control

## Simple test to verify shop UI styling is working without dependencies

func _ready():
	print("[ShopStylingTest] Starting styling verification test...")
	
	# Create a test shop UI instance
	var shop_scene = preload("res://Scenes/UI/shop_ui.tscn")
	var shop_instance = shop_scene.instantiate()
	
	# Add it to our test scene
	add_child(shop_instance)
	
	# Wait a frame for _ready to run
	await get_tree().process_frame
	
	# Test that the styling methods exist and can be called
	if shop_instance.has_method("_style_shop_background"):
		print("[ShopStylingTest] ✓ _style_shop_background method found")
		shop_instance._style_shop_background()
		print("[ShopStylingTest] ✓ Background styling applied successfully")
	else:
		print("[ShopStylingTest] ✗ _style_shop_background method missing")
	
	if shop_instance.has_method("_style_tab_container"):
		print("[ShopStylingTest] ✓ _style_tab_container method found")
		var tab_container = shop_instance.get_node_or_null("TabContainer")
		if tab_container:
			shop_instance._style_tab_container()
			print("[ShopStylingTest] ✓ Tab container styling applied successfully")
		else:
			print("[ShopStylingTest] ⚠ TabContainer not found")
	else:
		print("[ShopStylingTest] ✗ _style_tab_container method missing")
	
	if shop_instance.has_method("_style_shop_title"):
		print("[ShopStylingTest] ✓ _style_shop_title method found")
		var title_label = shop_instance.get_node_or_null("ShopTitle")
		if title_label:
			shop_instance._style_shop_title()
			print("[ShopStylingTest] ✓ Shop title styling applied successfully")
		else:
			print("[ShopStylingTest] ⚠ ShopTitle not found")
	else:
		print("[ShopStylingTest] ✗ _style_shop_title method missing")
	
	# Test container type handling
	var containers = [
		shop_instance.power_up_container,
		shop_instance.consumable_container,
		shop_instance.mod_container
	]
	
	var container_count = 0
	for container in containers:
		if container:
			container_count += 1
			print("[ShopStylingTest] ✓ Container found: ", container.get_class())
	
	print("[ShopStylingTest] Found ", container_count, "/3 containers")
	
	# Test layout replacement
	if shop_instance.has_method("_replace_grid_with_centered_layout"):
		print("[ShopStylingTest] ✓ _replace_grid_with_centered_layout method found")
		shop_instance._replace_grid_with_centered_layout()
		print("[ShopStylingTest] ✓ Layout replacement completed successfully")
	else:
		print("[ShopStylingTest] ✗ _replace_grid_with_centered_layout method missing")
	
	print("[ShopStylingTest] Styling verification test completed!")
	
	# Allow time to see the visual results
	await get_tree().create_timer(3.0).timeout
	get_tree().quit()