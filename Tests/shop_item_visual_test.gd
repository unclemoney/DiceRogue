extends Control
class_name ShopItemVisualTest

## shop_item_visual_test.gd
##
## Visual + assertion test for the ShopItem restyle:
## glass Buy button (amber/gold), rarity badge shader, price tag shader,
## card panel depth shader, and the PowerUp tooltip footer
## (Mom Approval + Rarity lines).

const SHOP_ITEM_SCENE = preload("res://Scenes/Shop/shop_item.tscn")
const POWERUP_TEMPLATE = preload("res://Scripts/PowerUps/BonusMoneyPowerUp.tres")
const CONSUMABLE_TEMPLATE = preload("res://Scripts/Consumable/LossLeaderConsumable.tres")
const MOD_TEMPLATE = preload("res://Scripts/Mods/WildCardMod.tres")
const FALLBACK_ICON = preload("res://Resources/Art/Dice/dieWhite1.png")

@onready var instructions_label: Label = $Background/MarginContainer/VBoxContainer/InstructionsLabel
@onready var status_label: Label = $Background/MarginContainer/VBoxContainer/StatusLabel
@onready var grid: GridContainer = $Background/MarginContainer/VBoxContainer/GridContainer

var _spawned_items: Array[ShopItem] = []
var _failures: Array[String] = []


func _ready() -> void:
	_configure_scene_text()
	_prepare_test_state()
	_populate_items()
	_run_assertions()
	_schedule_headless_exit()


func _configure_scene_text() -> void:
	instructions_label.text = "ShopItem visual test: glass BUY button, rarity badge shader, price tag shader, card depth shader. Hover power-ups for Mom Approval + Rarity tooltip footer."
	status_label.text = "Samples: power-ups of all five rarities, consumable, mod, colored dice."


func _prepare_test_state() -> void:
	if PlayerEconomy:
		PlayerEconomy.money = 9999
		PlayerEconomy.emit_signal("money_changed", PlayerEconomy.money, 0)
	if DiceColorManager and DiceColorManager.has_method("clear_purchased_colors"):
		DiceColorManager.clear_purchased_colors()


func _populate_items() -> void:
	for child in grid.get_children():
		child.queue_free()
	_spawned_items.clear()

	var samples: Array[Dictionary] = [
		{"data": _make_power_up("visual_common", "Chore Skip", "Common sample with a G rating.", "common", "G", 60), "type": "power_up"},
		{"data": _make_power_up("visual_uncommon", "Bonus Money", "Uncommon sample with a PG rating.", "uncommon", "PG", 145), "type": "power_up"},
		{"data": _make_power_up("visual_rare", "Lucky Streak", "Rare sample with a PG-13 rating.", "rare", "PG-13", 240), "type": "power_up"},
		{"data": _make_power_up("visual_epic", "Dice Whisperer", "Epic sample with an R rating.", "epic", "R", 380), "type": "power_up"},
		{"data": _make_power_up("visual_legendary", "Midnight Marathon", "Legendary sample with an NC-17 rating.", "legendary", "NC-17", 420), "type": "power_up"},
		{"data": _make_consumable(), "type": "consumable"},
		{"data": _make_mod(), "type": "mod"},
		{"data": _make_colored_dice(), "type": "colored_dice"},
	]

	for sample in samples:
		_spawn_shop_item(sample.data, sample.type)


func _spawn_shop_item(data: Resource, type: String) -> void:
	if not data:
		push_error("[ShopItemVisualTest] Missing data for type: %s" % type)
		return
	var shop_item := SHOP_ITEM_SCENE.instantiate() as ShopItem
	if not shop_item:
		push_error("[ShopItemVisualTest] Failed to instantiate ShopItem scene")
		return
	grid.add_child(shop_item)
	shop_item.setup(data, type)
	_spawned_items.append(shop_item)


## _run_assertions()
## Validates the restyle wiring on every spawned card and reports failures
## in the status label and the output log.
func _run_assertions() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	for shop_item in _spawned_items:
		var label := "%s (%s)" % [shop_item.item_id, shop_item.item_type]

		if not shop_item.buy_button is GlassActionButton:
			_failures.append(label + ": buy_button is not a GlassActionButton")
		elif shop_item.buy_button.get_button_text() == "":
			_failures.append(label + ": buy button text is empty")

		if not shop_item.get_node_or_null("CardPanel/CardFxRect"):
			_failures.append(label + ": missing CardFxRect shader overlay")
		if not shop_item.get_node_or_null("BadgeLayer/PriceBadge/PriceFxRect"):
			_failures.append(label + ": missing PriceFxRect shader overlay")

		if shop_item.item_type == "power_up":
			var current_tooltip_text: String = shop_item._get_current_tooltip_text()
			if not current_tooltip_text.contains("Mom Approval:"):
				_failures.append(label + ": tooltip missing Mom Approval line")
			if not current_tooltip_text.contains("Rarity: " + shop_item.item_data.rarity.capitalize()):
				_failures.append(label + ": tooltip missing Rarity line")
			if not shop_item.get_node_or_null("BadgeLayer/RarityBadge/RarityFxRect"):
				_failures.append(label + ": missing RarityFxRect shader overlay")
			if not shop_item.rarity_badge.visible:
				_failures.append(label + ": rarity badge not visible for power_up")

	if _failures.is_empty():
		status_label.text = "All visual assertions passed (%d cards)." % _spawned_items.size()
		print("[ShopItemVisualTest] PASS - all assertions passed")
	else:
		status_label.text = "%d assertion failure(s) - see output log." % _failures.size()
		for failure in _failures:
			push_error("[ShopItemVisualTest] FAIL: " + failure)


func _make_power_up(sample_id: String, display_name: String, description: String, rarity: String, rating: String, price: int) -> PowerUpData:
	var data := POWERUP_TEMPLATE.duplicate(true) as PowerUpData
	if not data:
		data = PowerUpData.new()
		data.icon = FALLBACK_ICON
	data.id = sample_id
	data.display_name = display_name
	data.description = description
	data.rarity = rarity
	data.rating = rating
	data.price = price
	if not data.icon:
		data.icon = FALLBACK_ICON
	return data


func _make_consumable() -> ConsumableData:
	var data := CONSUMABLE_TEMPLATE.duplicate(true) as ConsumableData
	if not data:
		data = ConsumableData.new()
		data.icon = FALLBACK_ICON
	data.id = "visual_consumable"
	data.display_name = "Loss Leader"
	data.description = "Consumable sample: no rarity badge, amber price tag."
	data.price = 55
	if not data.icon:
		data.icon = FALLBACK_ICON
	return data


func _make_mod() -> ModData:
	var data := MOD_TEMPLATE.duplicate(true) as ModData
	if not data:
		data = ModData.new()
		data.icon = FALLBACK_ICON
	data.id = "visual_mod"
	data.display_name = "Wild Card"
	data.description = "Mod sample: no rarity badge, amber price tag."
	data.price = 80
	if not data.icon:
		data.icon = FALLBACK_ICON
	return data


func _make_colored_dice() -> ColoredDiceData:
	var loaded = DiceColorManager.get_colored_dice_data("yellow_dice") if DiceColorManager else null
	var data := loaded.duplicate(true) as ColoredDiceData if loaded else ColoredDiceData.new()
	data.id = "yellow_dice"
	data.display_name = "Yellow Dice"
	data.description = "Colored dice sample for dynamic pricing on the new price tag."
	data.effect_description = "Scored yellow dice grant consumables."
	data.price = 100
	data.color_type = DiceColor.Type.YELLOW
	if not data.icon:
		data.icon = FALLBACK_ICON
	return data


func _schedule_headless_exit() -> void:
	if DisplayServer.get_name() != "headless":
		return
	await get_tree().create_timer(1.5).timeout
	if _failures.is_empty():
		print("[ShopItemVisualTest] Headless validation complete - exiting.")
	else:
		print("[ShopItemVisualTest] Headless validation finished with %d failure(s)." % _failures.size())
	get_tree().quit()
