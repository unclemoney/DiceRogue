extends Node

const DiceHandScene := preload("res://Scenes/Dice/dice_hand.tscn")
const ShopItemScript := preload("res://Scripts/Shop/shop_item.gd")
const ShopUIScript := preload("res://Scripts/UI/shop_ui.gd")

var _pass_count: int = 0
var _fail_count: int = 0
var _game_controller: GameController = null
var _dice_hand: DiceHand = null


func _ready() -> void:
	print("[ShopModLimitLogicTest] Starting")
	await _setup_dice_hand()
	_run_tests()
	_finish()


func _setup_dice_hand() -> void:
	_game_controller = GameController.new()
	_dice_hand = DiceHandScene.instantiate() as DiceHand
	add_child(_dice_hand)
	_dice_hand.spawn_dice()
	await _dice_hand.dice_spawned
	_game_controller.dice_hand = _dice_hand


func _run_tests() -> void:
	_check("live dice count matches spawned hand",
		_game_controller.get_current_dice_hand_count() == _dice_hand.dice_list.size())

	_clear_mod_slots()
	_check("mod limit starts below cap", not _game_controller.has_reached_mod_limit())
	_check("shop item helper follows controller before cap",
		ShopItemScript.new()._has_reached_mod_limit(_game_controller) == _game_controller.has_reached_mod_limit())
	_check("shop ui helper follows controller before cap",
		ShopUIScript.new()._has_reached_mod_limit(_game_controller) == _game_controller.has_reached_mod_limit())

	_fill_all_mod_slots()
	_check("mod limit reaches cap at one mod per die", _game_controller.has_reached_mod_limit())
	_check("shop item helper follows controller at cap",
		ShopItemScript.new()._has_reached_mod_limit(_game_controller))
	_check("shop ui helper follows controller at cap",
		ShopUIScript.new()._has_reached_mod_limit(_game_controller))

	_remove_one_mod_slot()
	_check("mod limit clears when one die frees a slot", not _game_controller.has_reached_mod_limit())


func _fill_all_mod_slots() -> void:
	for i in range(_dice_hand.dice_list.size()):
		var die: Dice = _dice_hand.dice_list[i]
		die.active_mods.clear()
		die.active_mods["test_mod_%d" % i] = true


func _remove_one_mod_slot() -> void:
	if _dice_hand.dice_list.is_empty():
		return
	_dice_hand.dice_list[0].active_mods.clear()


func _clear_mod_slots() -> void:
	for die in _dice_hand.dice_list:
		die.active_mods.clear()


func _check(label: String, condition: bool) -> void:
	if condition:
		_pass_count += 1
		print("OK: " + label)
	else:
		_fail_count += 1
		push_error("FAILED: " + label)


func _finish() -> void:
	print("[ShopModLimitLogicTest] RESULTS: %d passed, %d failed" % [_pass_count, _fail_count])
	if _fail_count == 0:
		print("[ShopModLimitLogicTest] OK - all checks passed")
		get_tree().quit(0)
	else:
		print("[ShopModLimitLogicTest] FAILED - %d check(s) failed" % _fail_count)
		get_tree().quit(1)