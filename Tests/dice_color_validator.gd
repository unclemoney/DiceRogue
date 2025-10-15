extends Node

## DiceColorSystemValidator
##
## Comprehensive test script to validate dice color system functionality
## Run this to verify all components are working correctly

func _ready() -> void:
	print("=== DICE COLOR SYSTEM VALIDATION ===")
	await get_tree().create_timer(1.0).timeout  # Wait for autoloads
	run_validation_tests()

func run_validation_tests() -> void:
	var all_tests_passed = true
	
	# Test 1: DiceColorManager availability
	print("\n1. Testing DiceColorManager availability...")
	var color_manager = get_dice_color_manager()
	if color_manager:
		print("✓ DiceColorManager found and accessible")
	else:
		print("✗ DiceColorManager NOT found")
		all_tests_passed = false
	
	# Test 2: DiceColor enum functionality
	print("\n2. Testing DiceColor enum...")
	var test_passed = test_dice_color_enum()
	if test_passed:
		print("✓ DiceColor enum working correctly")
	else:
		print("✗ DiceColor enum has issues")
		all_tests_passed = false
	
	# Test 3: Color effect calculations
	print("\n3. Testing color effect calculations...")
	if color_manager:
		test_passed = test_color_calculations(color_manager)
		if test_passed:
			print("✓ Color calculations working correctly")
		else:
			print("✗ Color calculations have issues")
			all_tests_passed = false
	
	# Test 4: Dice creation and color assignment
	print("\n4. Testing dice color assignment...")
	test_passed = test_dice_color_assignment()
	if test_passed:
		print("✓ Dice color assignment working")
	else:
		print("✗ Dice color assignment has issues")
		all_tests_passed = false
	
	# Test 5: Shader integration
	print("\n5. Testing shader integration...")
	test_passed = test_shader_integration()
	if test_passed:
		print("✓ Shader integration working")
	else:
		print("✗ Shader integration has issues")
		all_tests_passed = false
	
	# Final result
	print("\n=== VALIDATION COMPLETE ===")
	if all_tests_passed:
		print("✓ ALL TESTS PASSED - Dice color system is functional!")
	else:
		print("✗ SOME TESTS FAILED - Please check the issues above")

func get_dice_color_manager():
	if get_tree():
		var manager = get_tree().get_first_node_in_group("dice_color_manager")
		if manager:
			return manager
		
		# Fallback: try to find autoload directly
		var autoload_node = get_node_or_null("/root/DiceColorManager")
		return autoload_node
	return null

func test_dice_color_enum() -> bool:
	var DiceColor = preload("res://Scripts/Core/dice_color.gd")
	
	# Test enum values
	if DiceColor.Type.NONE != 0:
		print("  ✗ NONE enum value incorrect")
		return false
	
	if DiceColor.Type.GREEN != 1:
		print("  ✗ GREEN enum value incorrect")
		return false
	
	# Test helper functions
	var green_name = DiceColor.get_color_name(DiceColor.Type.GREEN)
	if green_name != "Green":
		print("  ✗ get_color_name failed, got: ", green_name)
		return false
	
	var green_chance = DiceColor.get_color_chance(DiceColor.Type.GREEN)
	if green_chance != 10:
		print("  ✗ get_color_chance failed, got: ", green_chance)
		return false
	
	print("  ✓ Enum values and helper functions working")
	return true

func test_color_calculations(color_manager) -> bool:
	# Create mock dice array for testing
	var mock_dice = []
	for i in range(5):
		var mock_die = MockDie.new()
		mock_die.value = i + 1
		mock_die.color = preload("res://Scripts/Core/dice_color.gd").Type.GREEN if i < 2 else preload("res://Scripts/Core/dice_color.gd").Type.NONE
		mock_dice.append(mock_die)
	
	var effects = color_manager.calculate_color_effects(mock_dice)
	
	# Check if effects structure is correct
	if not effects.has("green_money"):
		print("  ✗ Missing green_money in effects")
		return false
	
	if not effects.has("red_additive"):
		print("  ✗ Missing red_additive in effects")
		return false
	
	if not effects.has("purple_multiplier"):
		print("  ✗ Missing purple_multiplier in effects")
		return false
	
	# Check green money calculation (first two dice: 1 + 2 = 3)
	if effects.green_money != 3:
		print("  ✗ Green money calculation wrong, expected 3, got: ", effects.green_money)
		return false
	
	print("  ✓ Color effect calculations working")
	return true

func test_dice_color_assignment() -> bool:
	# Load the dice scene
	var dice_scene = preload("res://Scenes/Dice/dice.tscn")
	if not dice_scene:
		print("  ✗ Could not load dice scene")
		return false
	
	var die = dice_scene.instantiate()
	add_child(die)
	
	# Test that the die has color property
	if not die.has_method("get_color"):
		print("  ✗ Die missing get_color method")
		die.queue_free()
		return false
	
	if not die.has_method("force_color"):
		print("  ✗ Die missing force_color method")
		die.queue_free()
		return false
	
	# Test color assignment
	var DiceColor = preload("res://Scripts/Core/dice_color.gd")
	die.force_color(DiceColor.Type.GREEN)
	
	if die.get_color() != DiceColor.Type.GREEN:
		print("  ✗ Color assignment failed")
		die.queue_free()
		return false
	
	die.queue_free()
	print("  ✓ Dice color assignment working")
	return true

func test_shader_integration() -> bool:
	# Test that the shader file exists
	var shader = load("res://Scripts/Shaders/dice_combined_effects.gdshader")
	if not shader:
		print("  ✗ Could not load dice shader")
		return false
	
	print("  ✓ Shader file loads successfully")
	return true

# Mock class for testing
class MockDie:
	var value: int = 1
	var color = preload("res://Scripts/Core/dice_color.gd").Type.NONE
	
	func get_color():
		return color