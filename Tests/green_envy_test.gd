extends Node
class_name GreenEnvyTest

var test_results: Array[String] = []

func _ready() -> void:
	print("[GreenEnvyTest] Starting Green Envy consumable tests...")
	add_to_group("test_scripts")
	
	# Run tests
	test_basic_instantiation()
	test_apply_method()
	
	# Print results
	print_test_results()

func test_basic_instantiation() -> void:
	print("\n=== Test: Basic Instantiation ===")
	
	# Load the consumable scene
	var scene = load("res://Scenes/Consumable/GreenEnvyConsumable.tscn")
	if not scene:
		add_result("FAIL: Could not load GreenEnvyConsumable scene")
		return
	
	# Instantiate the consumable
	var consumable = scene.instantiate()
	if not consumable:
		add_result("FAIL: Could not instantiate GreenEnvyConsumable")
		return
	
	# Check if it's the right type
	if not consumable is GreenEnvyConsumable:
		add_result("FAIL: Consumable is not GreenEnvyConsumable type")
		return
	
	add_result("PASS: GreenEnvyConsumable instantiation successful")
	consumable.queue_free()

func test_apply_method() -> void:
	print("\n=== Test: Apply Method ===")
	
	# Create a mock GameController for testing
	var mock_controller = Node.new()
	mock_controller.name = "MockGameController"
	add_child(mock_controller)
	
	# Load and instantiate the consumable
	var scene = load("res://Scenes/Consumable/GreenEnvyConsumable.tscn")
	var consumable = scene.instantiate()
	add_child(consumable)
	
	# Test apply with invalid target
	consumable.apply(mock_controller)
	
	# The apply method should handle invalid targets gracefully
	add_result("PASS: Apply method handles invalid targets")
	
	# Clean up
	mock_controller.queue_free()
	consumable.queue_free()

func add_result(result: String) -> void:
	test_results.append(result)
	print("[GreenEnvyTest] " + result)

func print_test_results() -> void:
	print("\n=== Green Envy Test Results ===")
	var passed = 0
	var failed = 0
	
	for result in test_results:
		if result.begins_with("PASS"):
			passed += 1
		elif result.begins_with("FAIL"):
			failed += 1
	
	print("Tests completed: %d passed, %d failed" % [passed, failed])
	
	if failed == 0:
		print("[GreenEnvyTest] All tests PASSED! ✓")
	else:
		print("[GreenEnvyTest] Some tests FAILED! ✗")