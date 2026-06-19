extends Control
class_name ShopItemRefreshTest

## shop_item_refresh_test.gd
##
## Focused visual test for the hanging ShopItem refresh.
## Covers title fitting, tooltip styling, badge visibility, and hover swing.

const SHOP_ITEM_SCENE = preload("res://Scenes/Shop/shop_item.tscn")
const POWERUP_TEMPLATE = preload("res://Scripts/PowerUps/BonusMoneyPowerUp.tres")
const CONSUMABLE_TEMPLATE = preload("res://Scripts/Consumable/LossLeaderConsumable.tres")
const MOD_TEMPLATE = preload("res://Scripts/Mods/WildCardMod.tres")
const FALLBACK_ICON = preload("res://Resources/Art/Dice/dieWhite1.png")

@onready var instructions_label: Label = $Background/MarginContainer/VBoxContainer/InstructionsLabel
@onready var status_label: Label = $Background/MarginContainer/VBoxContainer/StatusLabel
@onready var grid: GridContainer = $Background/MarginContainer/VBoxContainer/GridContainer


func _ready() -> void:
	_configure_scene_text()
	_prepare_test_state()
	_populate_items()
	_schedule_headless_exit()


func _configure_scene_text() -> void:
	instructions_label.text = "Hover cards to verify the swing pivot, title fit, tooltip restyle, and badge visibility. Click BUY to confirm basic button states."
	status_label.text = "Samples: long legendary power-up, uncommon power-up, consumable, mod, colored dice, and gaming console."


func _prepare_test_state() -> void:
	if PlayerEconomy:
		PlayerEconomy.money = 9999
		PlayerEconomy.emit_signal("money_changed", PlayerEconomy.money, 0)
	if DiceColorManager and DiceColorManager.has_method("clear_purchased_colors"):
		DiceColorManager.clear_purchased_colors()


func _populate_items() -> void:
	for child in grid.get_children():
		child.queue_free()

	var samples: Array[Dictionary] = [
		{"data": _make_power_up("shop_refresh_long", "A Much Longer Power Name That Must Shrink Cleanly", "A long-name stress case for the hanging card title fitter.", "legendary", 420), "type": "power_up"},
		{"data": _make_power_up("shop_refresh_bonus", "Bonus Money", "Shorter power-up sample for the simpler rarity chip.", "uncommon", 145), "type": "power_up"},
		{"data": _make_consumable(), "type": "consumable"},
		{"data": _make_mod(), "type": "mod"},
		{"data": _make_colored_dice(), "type": "colored_dice"},
		{"data": _make_gaming_console(), "type": "gaming_console"},
	]

	for sample in samples:
		_spawn_shop_item(sample.data, sample.type)


func _spawn_shop_item(data: Resource, type: String) -> void:
	if not data:
		push_error("[ShopItemRefreshTest] Missing data for type: %s" % type)
		return
	var shop_item := SHOP_ITEM_SCENE.instantiate() as ShopItem
	if not shop_item:
		push_error("[ShopItemRefreshTest] Failed to instantiate ShopItem scene")
		return
	grid.add_child(shop_item)
	shop_item.setup(data, type)
	shop_item.purchased.connect(_on_item_purchased)


func _make_power_up(sample_id: String, display_name: String, description: String, rarity: String, price: int) -> PowerUpData:
	var data := POWERUP_TEMPLATE.duplicate(true) as PowerUpData
	if not data:
		data = PowerUpData.new()
		data.icon = FALLBACK_ICON
	data.id = sample_id
	data.display_name = display_name
	data.description = description
	data.rarity = rarity
	data.price = price
	data.rating = "PG"
	if not data.icon:
		data.icon = FALLBACK_ICON
	return data


func _make_consumable() -> ConsumableData:
	var data := CONSUMABLE_TEMPLATE.duplicate(true) as ConsumableData
	if not data:
		data = ConsumableData.new()
		data.icon = FALLBACK_ICON
	data.id = "shop_refresh_consumable"
	data.display_name = "Loss Leader"
	data.description = "Consumable sample to verify that the rarity chip stays hidden while the price badge remains visible."
	data.price = 55
	if not data.icon:
		data.icon = FALLBACK_ICON
	return data


func _make_mod() -> ModData:
	var data := MOD_TEMPLATE.duplicate(true) as ModData
	if not data:
		data = ModData.new()
		data.icon = FALLBACK_ICON
	data.id = "shop_refresh_mod"
	data.display_name = "Wild Card"
	data.description = "Mod sample for compact copy and button spacing inside the new hanging panel."
	data.price = 80
	if not data.icon:
		data.icon = FALLBACK_ICON
	return data


func _make_colored_dice() -> ColoredDiceData:
	var loaded = DiceColorManager.get_colored_dice_data("blue_dice") if DiceColorManager else null
	var data := loaded.duplicate(true) as ColoredDiceData if loaded else ColoredDiceData.new()
	data.id = "blue_dice"
	data.display_name = "Blue Dice"
	data.description = "Colored dice sample for dynamic pricing, tooltip state, and badge layout."
	data.effect_description = "Used blue dice multiply score; unused blue dice divide it."
	data.price = 150
	data.color_type = DiceColor.Type.BLUE
	if not data.icon:
		data.icon = FALLBACK_ICON
	return data


func _make_gaming_console() -> GamingConsoleData:
	var data := GamingConsoleData.new()
	data.id = "shop_refresh_console"
	data.display_name = "Pocket Console"
	data.description = "Console sample to verify the non-power-up card state without a rarity chip."
	data.price = 300
	data.icon = FALLBACK_ICON
	return data


func _on_item_purchased(item_id: String, item_type: String) -> void:
	status_label.text = "Purchased sample: %s (%s)" % [item_id, item_type]


func _schedule_headless_exit() -> void:
	if DisplayServer.get_name() != "headless":
		return
	await get_tree().create_timer(1.5).timeout
	print("[ShopItemRefreshTest] Headless validation complete - exiting.")
	get_tree().quit()