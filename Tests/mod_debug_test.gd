extends Node2D
class_name ModDebugTest

@onready var game_controller: GameController
@onready var mod_manager: ModManager  
@onready var dice_hand: DiceHand

func _ready() -> void:
	print("\n=== Mod Debug Test Starting ===")
	_setup_minimal_test()
	await get_tree().create_timer(1.0).timeout
	_test_debug_console_mod_granting()
	_test_mod_icon_creation()

func _setup_minimal_test() -> void:
	# Create minimal required components
	game_controller = GameController.new()
	mod_manager = ModManager.new()
	dice_hand = DiceHand.new()
	
	add_child(game_controller)
	add_child(mod_manager)
	add_child(dice_hand)
	
	# Initialize PlayerEconomy if not already done
	if PlayerEconomy:
		PlayerEconomy.money = 500
		print("[ModDebugTest] Player money set to $500")

func _test_debug_console_mod_granting() -> void:
	print("\n--- Testing Debug Console Mod Granting ---")
	
	# Test if ModManager has the method
	if mod_manager.has_method("get_random_mod_id"):
		var random_mod = mod_manager.get_random_mod_id()
		print("[ModDebugTest] Random mod ID:", random_mod)
		
		if random_mod != "":
			# Test if GameController has grant_mod method
			if game_controller.has_method("grant_mod"):
				print("[ModDebugTest] ✓ GameController.grant_mod() exists")
				print("[ModDebugTest] Attempting to grant mod:", random_mod)
				game_controller.grant_mod(random_mod)
			else:
				print("[ModDebugTest] ✗ GameController.grant_mod() missing")
		else:
			print("[ModDebugTest] ✗ No random mod returned")
	else:
		print("[ModDebugTest] ✗ ModManager.get_random_mod_id() missing")

func _test_mod_icon_creation() -> void:
	print("\n--- Testing Mod Icon Creation ---")
	
	# Load the ModIcon scene
	var mod_icon_scene = preload("res://Scenes/Mods/ModIcon.tscn")
	if mod_icon_scene:
		var mod_icon = mod_icon_scene.instantiate() as ModIcon
		if mod_icon:
			add_child(mod_icon)
			
			# Create test mod data
			var test_mod_data = ModData.new()
			test_mod_data.id = "test_mod"
			test_mod_data.display_name = "Test Mod"
			test_mod_data.price = 100
			
			mod_icon.data = test_mod_data
			
			print("[ModDebugTest] ✓ ModIcon created successfully")
			print("[ModDebugTest] ModIcon children:", mod_icon.get_children())
			
			# Wait a moment for initialization
			await get_tree().create_timer(0.5).timeout
			
			# Check if sell button was created
			var sell_button = mod_icon.get_node_or_null("SellButton")
			if sell_button:
				print("[ModDebugTest] ✓ Sell button found:", sell_button)
				print("[ModDebugTest] Sell button position:", sell_button.position)
				print("[ModDebugTest] Sell button size:", sell_button.size)
				print("[ModDebugTest] Sell button visible:", sell_button.visible)
			else:
				print("[ModDebugTest] ✗ Sell button not found")
		else:
			print("[ModDebugTest] ✗ Failed to instantiate ModIcon")
	else:
		print("[ModDebugTest] ✗ Failed to load ModIcon scene")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			print("\n=== Running Manual Debug Test ===")
			_test_debug_console_mod_granting()
			_test_mod_icon_creation()