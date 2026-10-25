extends Node
class_name ModSystemRefactorTest

var _failures := 0


class UnlockStub:
	extends Node
	var unlocked_ids: Array[String] = []

	func is_item_unlocked(item_id: String) -> bool:
		return item_id in unlocked_ids


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		call_deferred("_run_all")
	else:
		_build_debug_buttons()
		_build_visual_fixture()


func _build_visual_fixture() -> void:
	var mod_ids := ["res://Scripts/Mods/WildCardMod.tres", "res://Scripts/Mods/PaintedDieMod.tres", "res://Scripts/Mods/FiveByOneMod.tres"]
	for i in range(mod_ids.size()):
		var die := _make_die()
		die.value = i + 4
		die.update_visual()
		die.position = Vector2(650 + i * 150, 300)
		die.add_mod(load(mod_ids[i]))
		die.color_label_bg.hide()
		for icon in die.mod_container.get_children():
			if icon is ModIcon:
				icon.sell_button.visible = true
				icon.sell_button.position = icon.get_global_rect().position + Vector2(-4, -24)

	var inventory := ShopOwnedItemsPanel.new()
	inventory.position = Vector2(650, 430)
	inventory.custom_minimum_size = Vector2(400, 220)
	inventory.size = Vector2(400, 220)
	add_child(inventory)
	inventory.set_panel_content("MOD STOCK", [{
		"item_id": "five_by_one",
		"display_name": "Five By One",
		"count": 2,
		"sell_price": 25,
	}])


func _build_debug_buttons() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var buttons := VBoxContainer.new()
	buttons.position = Vector2(20, 20)
	layer.add_child(buttons)
	_add_debug_button(buttons, "Wildcard scoring", _test_wildcards)
	_add_debug_button(buttons, "Disabled mod cleanup", _test_disabled_mod_cleanup)
	_add_debug_button(buttons, "Painted color unlocks", _test_painted_unlocks)
	_add_debug_button(buttons, "Tutorial painted attachment", _test_tutorial_painted_attachment)
	_add_debug_button(buttons, "Duplicate mod sales", _test_duplicate_mod_sales)
	_add_debug_button(buttons, "Run all", _run_all)


func _add_debug_button(parent: Node, label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(260, 42)
	button.pressed.connect(action)
	parent.add_child(button)


func _run_all() -> void:
	_failures = 0
	_test_wildcards()
	_test_disabled_mod_cleanup()
	_test_painted_unlocks()
	_test_tutorial_painted_attachment()
	_test_duplicate_mod_sales()
	await get_tree().process_frame
	print("[ModSystemRefactorTest] failures=%d" % _failures)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[ModSystemRefactorTest] PASS: " + label)
	else:
		_failures += 1
		push_error("[ModSystemRefactorTest] FAIL: " + label)


func _make_die() -> Dice:
	var die := Dice.new()
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var data := DiceData.new()
	data.sides = 6
	data.textures = [texture, texture, texture, texture, texture, texture]
	die.dice_data = data

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	die.add_child(sprite)
	var overlay := ColorRect.new()
	overlay.name = "StateOverlay"
	die.add_child(overlay)
	var mod_container := Control.new()
	mod_container.name = "ModContainer"
	die.add_child(mod_container)
	var color_bg := PanelContainer.new()
	color_bg.name = "ColorLabelBg"
	var color_label := Label.new()
	color_label.name = "ColorHoverLabel"
	color_bg.add_child(color_label)
	die.add_child(color_bg)
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(64, 64)
	collision.shape = shape
	die.add_child(collision)

	add_child(die)
	die.set_process(false)
	return die


func _install_dice(values: Array[int], wildcard_index: int = -1) -> Array[Dice]:
	var dice: Array[Dice] = []
	DiceResults.dice_refs.clear()
	DiceResults.values = values
	for i in range(values.size()):
		var die := _make_die()
		die.value = values[i]
		dice.append(die)
		DiceResults.dice_refs.append(die)
		if i == wildcard_index:
			die.add_mod(load("res://Scripts/Mods/WildCardMod.tres"))
	return dice


func _clear_dice(dice: Array[Dice]) -> void:
	DiceResults.dice_refs.clear()
	DiceResults.values.clear()
	for die in dice:
		if is_instance_valid(die):
			die.queue_free()


func _test_wildcards() -> void:
	var scorecard := Scorecard.new()
	add_child(scorecard)
	DiceResults.scorecard = scorecard

	var dice := _install_dice([6, 2, 6, 3, 6], 0)
	ScoreEvaluatorSingleton.reset_evaluation_count()
	_check(ScoreEvaluatorSingleton.calculate_score_for_category("three_of_a_kind", [6, 2, 6, 3, 6]) == 23, "wildcard preserves natural three-of-a-kind")
	_clear_dice(dice)

	dice = _install_dice([6, 6, 6, 6, 2], 0)
	ScoreEvaluatorSingleton.reset_evaluation_count()
	_check(ScoreEvaluatorSingleton.calculate_score_for_category("four_of_a_kind", [6, 6, 6, 6, 2]) == 26, "wildcard preserves natural four-of-a-kind")
	_clear_dice(dice)

	dice = _install_dice([6, 6, 6, 6, 6], 0)
	ScoreEvaluatorSingleton.reset_evaluation_count()
	_check(ScoreEvaluatorSingleton.is_yahtzee([6, 6, 6, 6, 6]), "wildcard preserves natural Yahtzee")
	_check(ScoreEvaluatorSingleton.calculate_score_for_category("yahtzee", [6, 6, 6, 6, 6]) == 50, "natural Yahtzee scores 50")
	_clear_dice(dice)
	DiceResults.scorecard = null
	scorecard.queue_free()


func _test_disabled_mod_cleanup() -> void:
	var die := _make_die()
	die.value = 5
	die.add_mod(load("res://Scripts/Mods/FiveByOneMod.tres"))
	die.rolled.emit(5)
	_check(ScoreModifierManager.get_active_additive_sources().has("five_by_one"), "five_by_one registered before cleanup")
	die.disable_all_mods()
	die.remove_mod("five_by_one")
	die.reset_mods_for_roll()
	_check(not die.has_mod("five_by_one") and not die._disabled_mods.has("five_by_one"), "removed mod absent from active and disabled stores")
	_check(not ScoreModifierManager.get_active_additive_sources().has("five_by_one"), "five_by_one absent after removal and next-roll reset")
	die.queue_free()


func _test_painted_unlocks() -> void:
	var painted := PaintedDieMod.new()
	add_child(painted)
	var stub := UnlockStub.new()
	add_child(stub)
	_check(painted._get_unlocked_paint_colors(stub).is_empty(), "no unlocked paint colors yields no candidates")
	stub.unlocked_ids = ["red_dice"]
	var candidates := painted._get_unlocked_paint_colors(stub)
	_check(candidates.size() == 1 and candidates[0] == DiceColor.Type.RED, "paint candidates contain only unlocked red")
	stub.unlocked_ids = ["red_dice", "blue_dice"]
	candidates = painted._get_unlocked_paint_colors(stub)
	_check(candidates.size() == 2 and not candidates.has(DiceColor.Type.GREEN), "locked colors excluded from multi-color candidate set")
	stub.queue_free()
	painted.queue_free()


func _test_tutorial_painted_attachment() -> void:
	var old_session: bool = TutorialManager.is_tutorial_session_active
	var old_active: bool = TutorialManager.is_active
	TutorialManager.is_tutorial_session_active = true
	TutorialManager.is_active = true
	var die := _make_die()
	var old_color := die.color
	die.add_mod(load("res://Scripts/Mods/PaintedDieMod.tres"))
	_check(is_instance_valid(die) and die.visible and die.has_mod("painted_die"), "painted purchase keeps tutorial die present and visible")
	var painted_color := (die.get_mod("painted_die") as PaintedDieMod).painted_color
	die.reset_mods_for_roll()
	_check(die.visible and (die.get_mod("painted_die") as PaintedDieMod).painted_color == painted_color, "painted color and die survive roll reset")
	if painted_color == DiceColor.Type.NONE:
		_check(die.color == old_color, "no eligible paint color leaves die color unchanged")
	die.queue_free()
	TutorialManager.is_tutorial_session_active = old_session
	TutorialManager.is_active = old_active


func _test_duplicate_mod_sales() -> void:
	var controller := GameController.new()
	var manager := ModManager.new()
	var definition: ModData = load("res://Scripts/Mods/FiveByOneMod.tres")
	manager.mod_defs = [definition]
	controller.mod_manager = manager
	add_child(manager)
	controller.active_mods[definition.id] = definition
	controller.mod_persistence_map[definition.id] = 2
	var money_before := PlayerEconomy.get_money()
	var refund := definition.sell_price if definition.sell_price >= 0 else int(definition.price / 2.0)

	var first_die := _make_die()
	first_die.add_mod(definition)
	controller._on_mod_sold(definition.id, first_die)
	_check(int(controller.mod_persistence_map.get(definition.id, 0)) == 1, "first duplicate sale leaves one owned mod")
	_check(PlayerEconomy.get_money() == money_before + refund, "first sale refunds exactly once")
	_check(controller.active_mods.has(definition.id), "duplicate definition remains available after first sale")

	var second_die := _make_die()
	second_die.add_mod(definition)
	controller._on_mod_sold(definition.id, second_die)
	_check(not controller.mod_persistence_map.has(definition.id) and not controller.active_mods.has(definition.id), "last duplicate sale clears ownership")
	_check(PlayerEconomy.get_money() == money_before + refund * 2, "second sale refunds exactly once")
	PlayerEconomy.add_money(money_before - PlayerEconomy.get_money())
	first_die.queue_free()
	second_die.queue_free()
	controller.queue_free()
	manager.queue_free()
