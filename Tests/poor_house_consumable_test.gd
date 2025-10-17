extends Node
class_name PoorHouseConsumableTest

var game_controller: GameController

func _ready() -> void:
	print("\n=== PoorHouse Consumable Test Starting ===")
	
	# Set up test environment
	_setup_test_environment()
	
	# Run tests
	_test_basic_functionality()
	_test_with_no_money()
	_test_money_bonus_application()
	
	print("=== All PoorHouse Consumable Tests Complete ===")

func _setup_test_environment() -> void:
	print("[PoorHouseTest] Setting up test environment")
	
	# Initialize PlayerEconomy with test money
	if PlayerEconomy:
		PlayerEconomy.money = 200
		print("[PoorHouseTest] Set initial money to $200")
	
	# Get or create a basic game setup
	game_controller = get_node_or_null("../GameController")
	if not game_controller:
		print("[PoorHouseTest] No GameController found - creating minimal test setup")
		game_controller = preload("res://Scripts/Core/game_controller.gd").new()
		add_child(game_controller)

func _test_basic_functionality() -> void:
	print("\n[PoorHouseTest] Testing basic functionality...")
	
	# Create and test the poor house consumable
	var poor_house_scene = preload("res://Scenes/Consumable/PoorHouseConsumable.tscn")
	var poor_house_instance = poor_house_scene.instantiate()
	add_child(poor_house_instance)
	
	var initial_money = PlayerEconomy.money
	print("[PoorHouseTest] Initial money: $%d" % initial_money)
	
	# Test apply method
	poor_house_instance.apply(game_controller)
	
	var final_money = PlayerEconomy.money
	print("[PoorHouseTest] Final money: $%d" % final_money)
	
	# Verify money was transferred
	assert(final_money == 0, "Money should be 0 after using Poor House")
	
	# Check if additive was registered
	var total_additive = ScoreModifierManager.get_total_additive()
	assert(total_additive == initial_money, "Additive should equal the initial money amount")
	
	print("[PoorHouseTest] ✓ Basic functionality works correctly")
	
	# Clean up
	poor_house_instance.queue_free()

func _test_with_no_money() -> void:
	print("\n[PoorHouseTest] Testing with no money...")
	
	# Set money to 0
	PlayerEconomy.money = 0
	
	var poor_house_scene = preload("res://Scenes/Consumable/PoorHouseConsumable.tscn")
	var poor_house_instance = poor_house_scene.instantiate()
	add_child(poor_house_instance)
	
	var initial_additive = ScoreModifierManager.get_total_additive()
	
	# Apply consumable
	poor_house_instance.apply(game_controller)
	
	var final_additive = ScoreModifierManager.get_total_additive()
	
	# Verify no change in additive when no money
	assert(final_additive == initial_additive, "Additive should not change when player has no money")
	
	print("[PoorHouseTest] ✓ Correctly handles zero money")
	
	# Clean up
	poor_house_instance.queue_free()

func _test_money_bonus_application() -> void:
	print("\n[PoorHouseTest] Testing money bonus application...")
	
	# Reset environment
	PlayerEconomy.money = 150
	ScoreModifierManager.reset()
	
	var poor_house_scene = preload("res://Scenes/Consumable/PoorHouseConsumable.tscn")
	var poor_house_instance = poor_house_scene.instantiate()
	add_child(poor_house_instance)
	
	# Apply the consumable
	poor_house_instance.apply(game_controller)
	
	# Verify additive is registered
	var has_bonus = ScoreModifierManager.has_additive("poor_house_bonus")
	assert(has_bonus, "Poor house bonus should be registered")
	
	var bonus_amount = ScoreModifierManager.get_additive("poor_house_bonus")
	assert(bonus_amount == 150, "Bonus amount should be $150")
	
	print("[PoorHouseTest] ✓ Money bonus application works correctly")
	
	# Clean up
	ScoreModifierManager.reset()
	poor_house_instance.queue_free()

func _exit_tree() -> void:
	# Clean up any test state
	if ScoreModifierManager:
		ScoreModifierManager.reset()
	if PlayerEconomy:
		PlayerEconomy.money = 500  # Reset to default