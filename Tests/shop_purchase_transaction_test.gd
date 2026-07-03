extends Node

var _game_controller: GameController
var _mod_manager: ModManager
var _test_complete := false


func _ready() -> void:
	print("=== Shop Purchase Transaction Test ===")
	_setup_dependencies()
	await get_tree().process_frame
	await get_tree().process_frame
	_run_tests()
	_test_complete = true
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()


func _setup_dependencies() -> void:
	_game_controller = GameController.new()
	var mod_manager_scene = preload("res://Scenes/Managers/mod_manager.tscn")
	_mod_manager = mod_manager_scene.instantiate() as ModManager
	_mod_manager.name = "ModManager"
	add_child(_mod_manager)
	_game_controller.mod_manager = _mod_manager


func _run_tests() -> void:
	_test_colored_dice_grant_after_charge()
	_test_mod_grant_after_charge()


func _test_colored_dice_grant_after_charge() -> void:
	DiceColorManager.clear_purchased_colors()
	var color_data = DiceColorManager.get_colored_dice_data("green_dice")
	if not color_data:
		print("✗ Missing green_dice test data")
		return

	PlayerEconomy.money = max(0, color_data.price - 1)
	var before_count = DiceColorManager.get_color_purchase_count(color_data.color_type)
	var granted: bool = _game_controller.process_shop_purchase("green_dice", "colored_dice")
	var after_count = DiceColorManager.get_color_purchase_count(color_data.color_type)

	print("Colored dice granted with post-charge low money: %s" % str(granted))
	print("Green count: %d -> %d" % [before_count, after_count])
	if granted and after_count == before_count + 1:
		print("✓ Colored dice transaction no longer depends on the pre-charge balance")
	else:
		print("✗ Colored dice transaction still failed after charge")


func _test_mod_grant_after_charge() -> void:
	if not _mod_manager:
		print("✗ ModManager missing")
		return

	var available_mods = _mod_manager.get_available_mods()
	if available_mods.is_empty():
		print("✗ No mods available for transaction test")
		return

	var mod_id = available_mods[0]
	PlayerEconomy.money = 0
	var before_count = int(_game_controller.mod_persistence_map.get(mod_id, 0))
	var granted: bool = _game_controller.process_shop_purchase(mod_id, "mod")
	var after_count = int(_game_controller.mod_persistence_map.get(mod_id, 0))

	print("Mod granted with post-charge zero money: %s" % str(granted))
	print("%s count: %d -> %d" % [mod_id, before_count, after_count])
	if granted and after_count == before_count + 1:
		print("✓ Mod transaction remains independent of post-charge balance")
	else:
		print("✗ Mod transaction failed after charge")


func _input(event):
	if _test_complete and event.is_action_pressed("ui_accept"):
		get_tree().quit()