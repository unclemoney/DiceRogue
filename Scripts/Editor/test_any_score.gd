@tool
extends EditorScript

func _run():
	print("=== Testing AnyScore Consumable ===")
	
	# Test script instantiation
	var script = load("res://Scripts/Consumable/any_score_consumable.gd")
	if script:
		print("✓ AnyScore script loads successfully")
		
		# Try to instantiate the consumable
		var instance = Node.new()
		instance.set_script(script)
		
		if instance.has_method("apply"):
			print("✓ AnyScore has apply() method")
		else:
			print("✗ AnyScore missing apply() method")
			
		if instance.get("id") != null:
			print("✓ AnyScore has id property")
		else:
			print("✗ AnyScore missing id property")
			
		instance.queue_free()
	else:
		print("✗ Failed to load AnyScore script")
	
	# Test scene instantiation
	var scene = load("res://Scenes/Consumable/AnyScoreConsumable.tscn")
	if scene:
		print("✓ AnyScore scene loads successfully")
		if scene.can_instantiate():
			print("✓ AnyScore scene can be instantiated")
			var scene_instance = scene.instantiate()
			if scene_instance:
				print("✓ AnyScore scene instantiated successfully")
				scene_instance.queue_free()
			else:
				print("✗ AnyScore scene instantiation failed")
		else:
			print("✗ AnyScore scene cannot be instantiated")
	else:
		print("✗ Failed to load AnyScore scene")
	
	# Test data resource
	var data = load("res://Scripts/Consumable/AnyScoreConsumable.tres")
	if data:
		print("✓ AnyScore data resource loads successfully")
		print("  ID:", data.id)
		print("  Display Name:", data.display_name)
		print("  Description:", data.description)
		print("  Price:", data.price)
		if data.scene:
			print("✓ Data resource has scene reference")
		else:
			print("✗ Data resource missing scene reference")
		if data.icon:
			print("✓ Data resource has icon")
		else:
			print("✗ Data resource missing icon")
	else:
		print("✗ Failed to load AnyScore data resource")
	
	print("=== Test Complete ===")