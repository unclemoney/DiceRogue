extends Control
class_name ShopDiceSetGateTest

## shop_dice_set_gate_test.gd
##
## Verifies the shop's dice-set gating for consumables:
## 1. On a d4 run the consumable pool can include evens_upgrade,
##    odds_upgrade and even_odd_full_house_upgrade, and excludes
##    fives_upgrade, sixes_upgrade and large_straight_upgrade.
## 2. On a d6 run the inverse holds.
## 3. Scorecard.upgrade_category still works on the re-purposed d4 keys
##    ("fives"->Evens, "sixes"->Odds, "large_straight"->Even Odd Full House).
##
## Run headless with `-- --auto-test` to run the suite and quit with an
## exit code (0 = pass, 1 = fail).

const D4_ONLY_IDS := ["evens_upgrade", "odds_upgrade", "even_odd_full_house_upgrade"]
const NON_D4_IDS := ["fives_upgrade", "sixes_upgrade", "large_straight_upgrade"]

const FIVES_UPGRADE_DEF := preload("res://Scripts/Consumable/FivesUpgradeConsumable.tres")
const SIXES_UPGRADE_DEF := preload("res://Scripts/Consumable/SixesUpgradeConsumable.tres")
const LARGE_STRAIGHT_UPGRADE_DEF := preload("res://Scripts/Consumable/LargeStraightUpgradeConsumable.tres")
const EVENS_UPGRADE_DEF := preload("res://Scripts/Consumable/EvensUpgradeConsumable.tres")
const ODDS_UPGRADE_DEF := preload("res://Scripts/Consumable/OddsUpgradeConsumable.tres")
const EVEN_ODD_FULL_HOUSE_UPGRADE_DEF := preload("res://Scripts/Consumable/EvenOddFullHouseUpgradeConsumable.tres")

## Minimal RoundManager stand-in: ShopUI reads run_dice_type off the first
## node in the "round_manager" group.
class StubRoundManager extends Node:
	var run_dice_type: String = "d6"

var shop_ui: ShopUI
var consumable_manager: ConsumableManager
var _stub_round_manager: StubRoundManager
var _fail_count := 0
var _test_completed := false

func _ready() -> void:
	print("=== Shop Dice Set Gate Test ===")
	_setup_managers()
	_register_consumable_defs()
	_unlock_test_consumables()
	_setup_stub_round_manager()
	_setup_shop_ui()
	await get_tree().process_frame
	await get_tree().process_frame
	_run_tests()
	_test_completed = true
	if "--auto-test" in OS.get_cmdline_user_args():
		_quit_with_result()
	elif DisplayServer.get_name() == "headless":
		_quit_with_result()

func _setup_managers() -> void:
	var power_up_manager = preload("res://Scripts/Managers/PowerUpManager.gd").new()
	power_up_manager.name = "PowerUpManager"
	add_child(power_up_manager)
	consumable_manager = preload("res://Scripts/Managers/ConsumableManager.gd").new()
	consumable_manager.name = "ConsumableManager"
	add_child(consumable_manager)
	var mod_manager = preload("res://Scripts/Managers/ModManager.gd").new()
	mod_manager.name = "ModManager"
	add_child(mod_manager)

func _register_consumable_defs() -> void:
	consumable_manager.register_consumable_def(FIVES_UPGRADE_DEF)
	consumable_manager.register_consumable_def(SIXES_UPGRADE_DEF)
	consumable_manager.register_consumable_def(LARGE_STRAIGHT_UPGRADE_DEF)
	consumable_manager.register_consumable_def(EVENS_UPGRADE_DEF)
	consumable_manager.register_consumable_def(ODDS_UPGRADE_DEF)
	consumable_manager.register_consumable_def(EVEN_ODD_FULL_HOUSE_UPGRADE_DEF)

## _unlock_test_consumables()
##
## Force-marks the six gated consumables as unlocked for this test without
## calling debug_unlock_item (which would write to the player's save file).
func _unlock_test_consumables() -> void:
	for id in D4_ONLY_IDS + NON_D4_IDS:
		if not ProgressManager.unlockable_items.has(id):
			_fail("ProgressManager does not track consumable: %s" % id)
			continue
		ProgressManager.unlockable_items[id].is_unlocked = true

func _setup_stub_round_manager() -> void:
	_stub_round_manager = StubRoundManager.new()
	_stub_round_manager.name = "StubRoundManager"
	add_child(_stub_round_manager)
	_stub_round_manager.add_to_group("round_manager")

func _setup_shop_ui() -> void:
	var shop_scene = preload("res://Scenes/UI/shop_ui.tscn")
	shop_ui = shop_scene.instantiate()
	shop_ui.power_up_manager_path = get_node("PowerUpManager").get_path()
	shop_ui.consumable_manager_path = consumable_manager.get_path()
	shop_ui.mod_manager_path = get_node("ModManager").get_path()
	# Take every filtered item so random selection cannot hide a gated id.
	shop_ui.consumable_items = 100
	add_child(shop_ui)

func _run_tests() -> void:
	if not shop_ui:
		_fail("ShopUI missing")
		return

	print("--- d4 run gating ---")
	_stub_round_manager.run_dice_type = "d4"
	_assert_equals(shop_ui._get_current_dice_sides(), 4, "d4 resolves to 4 sides")
	var d4_pool_ids := _build_pool_ids()
	for id in D4_ONLY_IDS:
		_assert(d4_pool_ids.has(id), "d4 pool includes %s" % id)
	for id in NON_D4_IDS:
		_assert(not d4_pool_ids.has(id), "d4 pool excludes %s" % id)

	print("--- d6 run gating ---")
	_stub_round_manager.run_dice_type = "d6"
	_assert_equals(shop_ui._get_current_dice_sides(), 6, "d6 resolves to 6 sides")
	var d6_pool_ids := _build_pool_ids()
	for id in D4_ONLY_IDS:
		_assert(not d6_pool_ids.has(id), "d6 pool excludes %s" % id)
	for id in NON_D4_IDS:
		_assert(d6_pool_ids.has(id), "d6 pool includes %s" % id)

	print("--- ConsumableData gating flags ---")
	_assert_equals(EVENS_UPGRADE_DEF.required_dice_sides, 4, "evens_upgrade requires d4")
	_assert_equals(ODDS_UPGRADE_DEF.required_dice_sides, 4, "odds_upgrade requires d4")
	_assert_equals(EVEN_ODD_FULL_HOUSE_UPGRADE_DEF.required_dice_sides, 4, "even_odd_full_house_upgrade requires d4")
	_assert(FIVES_UPGRADE_DEF.excluded_dice_sides.has(4), "fives_upgrade excludes d4")
	_assert(SIXES_UPGRADE_DEF.excluded_dice_sides.has(4), "sixes_upgrade excludes d4")
	_assert(LARGE_STRAIGHT_UPGRADE_DEF.excluded_dice_sides.has(4), "large_straight_upgrade excludes d4")

	print("--- Scorecard re-purposed key upgrades ---")
	var scorecard := Scorecard.new()
	scorecard.upgrade_category(Scorecard.Section.UPPER, "fives")
	_assert_equals(scorecard.get_category_level(Scorecard.Section.UPPER, "fives"), 2, "Evens (fives) upgrades to level 2")
	scorecard.upgrade_category(Scorecard.Section.UPPER, "sixes")
	_assert_equals(scorecard.get_category_level(Scorecard.Section.UPPER, "sixes"), 2, "Odds (sixes) upgrades to level 2")
	scorecard.upgrade_category(Scorecard.Section.LOWER, "large_straight")
	_assert_equals(scorecard.get_category_level(Scorecard.Section.LOWER, "large_straight"), 2, "EO Full House (large_straight) upgrades to level 2")
	scorecard.free()

	var result_text := "PASS"
	if _fail_count > 0:
		result_text = "FAIL"
	print("=== Dice Set Gate Test Complete: %s ===" % result_text)

## _build_pool_ids() -> Array[String]
##
## Builds the consumable shop pool through ShopUI and returns the item ids.
func _build_pool_ids() -> Array[String]:
	var ids: Array[String] = []
	for data in shop_ui._build_consumable_pool():
		ids.append(data.id)
	return ids

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("✓ %s" % message)
	else:
		_fail_count += 1
		push_error("[ShopDiceSetGateTest] FAIL: %s" % message)
		print("✗ %s" % message)

func _assert_equals(actual, expected, message: String) -> void:
	_assert(actual == expected, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])

func _fail(message: String) -> void:
	_fail_count += 1
	push_error("[ShopDiceSetGateTest] FAIL: %s" % message)
	print("✗ %s" % message)

func _quit_with_result() -> void:
	if _fail_count > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)

func _input(event: InputEvent) -> void:
	if _test_completed and event.is_action_pressed("ui_accept"):
		_quit_with_result()
