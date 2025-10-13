extends Node2D
class_name ModSellingTest

@onready var dice_hand: DiceHand = $DiceHand
@onready var game_controller: GameController = $GameController
@onready var mod_manager: ModManager = $ModManager

var test_mod_id: String = "wildcard"  # Use existing mod for testing

func _ready() -> void:
	add_to_group("test")
	print("\n=== Mod Selling Test Starting ===")
	
	# Setup test environment
	_setup_test_environment()
	
	# Run tests after a short delay to ensure everything is initialized
	await get_tree().create_timer(0.5).timeout
	run_all_tests()

func _setup_test_environment() -> void:
	# Initialize PlayerEconomy with test money
	if PlayerEconomy:
		PlayerEconomy.money = 1000
		print("[ModSellingTest] Set player money to $1000")

func run_all_tests() -> void:
	test_basic_mod_selling()
	test_persistence_map_update()
	test_half_price_refund()
	print("\n=== All Mod Selling Tests Complete ===")

func test_basic_mod_selling() -> void:
	print("\n--- Test: Basic Mod Selling ---")
	
	# Spawn dice
	if dice_hand:
		dice_hand.spawn_dice()
		await get_tree().create_timer(0.1).timeout
	
	# Grant a test mod
	if game_controller and game_controller.has_method("grant_mod"):
		var _initial_money = PlayerEconomy.money
		game_controller.grant_mod(test_mod_id)
		
		# Check that mod was added
		assert(game_controller.active_mods.has(test_mod_id), "Mod should be in active_mods")
		assert(game_controller.mod_persistence_map.has(test_mod_id), "Mod should be in persistence_map")
		
		# Get the first die and check if mod was applied
		if dice_hand.dice_list.size() > 0:
			var die = dice_hand.dice_list[0]
			assert(die.has_mod(test_mod_id), "Die should have the mod applied")
		
		print("[ModSellingTest] ✓ Basic mod granting works")
	else:
		print("[ModSellingTest] ✗ GameController.grant_mod not available")

func test_persistence_map_update() -> void:
	print("\n--- Test: Persistence Map Update ---")
	
	# Check initial persistence count
	var initial_count = game_controller.mod_persistence_map.get(test_mod_id, 0)
	assert(initial_count > 0, "Mod should have persistence count > 0")
	
	# Simulate selling the mod by calling the handler directly
	if dice_hand.dice_list.size() > 0:
		var die = dice_hand.dice_list[0]
		game_controller._on_mod_sold(test_mod_id, die)
		
		# Check that persistence count decreased
		var new_count = game_controller.mod_persistence_map.get(test_mod_id, 0)
		assert(new_count == initial_count - 1, "Persistence count should decrease by 1")
		
		print("[ModSellingTest] ✓ Persistence map updates correctly")
	else:
		print("[ModSellingTest] ✗ No dice available for testing")

func test_half_price_refund() -> void:
	print("\n--- Test: Half Price Refund ---")
	
	# Get mod definition to check price
	var mod_def = mod_manager.get_def(test_mod_id)
	if mod_def:
		var initial_money = PlayerEconomy.money
		var expected_refund = int(mod_def.price / 2)
		
		# Grant another mod to test selling
		game_controller.grant_mod(test_mod_id)
		
		# Sell the mod
		if dice_hand.dice_list.size() > 0:
			var die = dice_hand.dice_list[0]
			game_controller._on_mod_sold(test_mod_id, die)
			
			# Check money increase
			var final_money = PlayerEconomy.money
			var actual_refund = final_money - initial_money
			assert(actual_refund == expected_refund, "Should receive half price as refund")
			
			print("[ModSellingTest] ✓ Half price refund works correctly")
			print("[ModSellingTest] Expected refund: $%d, Actual refund: $%d" % [expected_refund, actual_refund])
		else:
			print("[ModSellingTest] ✗ No dice available for selling test")
	else:
		print("[ModSellingTest] ✗ Could not get mod definition")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			print("\n=== Running Manual Mod Selling Tests ===")
			run_all_tests()