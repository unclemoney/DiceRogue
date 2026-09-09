extends Node

## loaded_paint_test.gd
##
## Headless auto-run test for the Loaded Dice upgrade and the Paint Job coupon:
##   1. loaded_dice: set_die_value() sets the chosen value on the chosen die,
##      respects the die's side count (rejects out-of-range on a d4).
##   2. loaded_dice: LoadedDiePicker builds one button per face for a d6/d4.
##   3. paint_job: paint_dice() gives every die a random non-NONE color and
##      stores the prior colors; a manually driven roll_complete restores the
##      prior colors and disconnects (one-shot).
##
## Run headless:
##   godot --headless --path . Tests/loaded_paint_test.tscn
## Exit code 0 = all checks passed, 1 = at least one failure.

const DiceColorClass = preload("res://Scripts/Core/dice_color.gd")
const DICE_SCENE = preload("res://Scenes/Dice/dice.tscn")
const D6_DATA = preload("res://Scripts/Dice/d6_dice.tres")
const D4_DATA = preload("res://Scripts/Dice/d4_dice.tres")
const LOADED_SCENE = preload("res://Scenes/Consumable/LoadedDiceConsumable.tscn")
const PAINT_SCENE = preload("res://Scenes/Consumable/PaintJobConsumable.tscn")
const PICKER_SCENE = preload("res://Scenes/UI/loaded_die_picker.tscn")

var _failures: int = 0
var _spawned: Array = []


func _ready() -> void:
	print("[LoadedPaintTest] Starting")
	# Allow autoloads to finish initializing
	await get_tree().process_frame
	await get_tree().process_frame

	_test_loaded_set_value()
	_test_loaded_sides_respect()
	await _test_picker_buttons()
	_test_paint_job()

	_cleanup()

	if _failures == 0:
		print("[LoadedPaintTest] PASS - all checks passed")
		get_tree().quit(0)
	else:
		print("[LoadedPaintTest] FAIL - %d check(s) failed" % _failures)
		get_tree().quit(1)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[LoadedPaintTest] OK: " + label)
	else:
		push_error("[LoadedPaintTest] FAILED: " + label)
		_failures += 1


func _make_die(dice_data: DiceData) -> Dice:
	var die = DICE_SCENE.instantiate() as Dice
	die.dice_data = dice_data
	add_child(die)
	_spawned.append(die)
	return die


func _cleanup() -> void:
	for node in _spawned:
		if is_instance_valid(node):
			node.queue_free()
	_spawned.clear()


func _test_loaded_set_value() -> void:
	var loaded = LOADED_SCENE.instantiate() as LoadedDiceConsumable
	add_child(loaded)
	_spawned.append(loaded)

	var die = _make_die(D6_DATA)
	die.value = 1

	_check("set_die_value returns true for valid value", loaded.set_die_value(die, 4))
	_check("die value is now 4", die.value == 4)
	_check("set_die_value(6) valid on d6", loaded.set_die_value(die, 6))
	_check("die value is now 6", die.value == 6)


func _test_loaded_sides_respect() -> void:
	var loaded = LOADED_SCENE.instantiate() as LoadedDiceConsumable
	add_child(loaded)
	_spawned.append(loaded)

	var die = _make_die(D4_DATA)
	die.value = 1

	_check("set_die_value(4) valid on d4", loaded.set_die_value(die, 4))
	_check("d4 value is now 4", die.value == 4)
	_check("set_die_value(5) rejected on d4", not loaded.set_die_value(die, 5))
	_check("d4 value unchanged after rejection", die.value == 4)
	_check("set_die_value(0) rejected on d4", not loaded.set_die_value(die, 0))
	_check("d4 value unchanged after 0", die.value == 4)


func _test_picker_buttons() -> void:
	var picker_d6 = PICKER_SCENE.instantiate() as LoadedDiePicker
	add_child(picker_d6)
	_spawned.append(picker_d6)

	var die6 = _make_die(D6_DATA)
	picker_d6.open([die6])
	await get_tree().process_frame
	_check("picker visible after open", picker_d6.visible)
	_check("die locking disabled during pick mode", die6.locking_disabled)

	picker_d6._on_die_picked(die6)
	await get_tree().process_frame
	# Count value buttons anywhere under the panel
	var button_count := 0
	if picker_d6._panel:
		for child in picker_d6._panel.find_children("Value*", "Button", true, false):
			button_count += 1
	_check("d6 picker has 6 value buttons", button_count == 6)
	_check("locking restored after die picked", not die6.locking_disabled)
	picker_d6.queue_free()
	await get_tree().process_frame

	var picker_d4 = PICKER_SCENE.instantiate() as LoadedDiePicker
	add_child(picker_d4)
	_spawned.append(picker_d4)
	var die4 = _make_die(D4_DATA)
	picker_d4.open([die4])
	picker_d4._on_die_picked(die4)
	await get_tree().process_frame
	var button_count_d4 := 0
	if picker_d4._panel:
		for child in picker_d4._panel.find_children("Value*", "Button", true, false):
			button_count_d4 += 1
	_check("d4 picker has 4 value buttons", button_count_d4 == 4)
	picker_d4.queue_free()
	await get_tree().process_frame


func _test_paint_job() -> void:
	var paint = PAINT_SCENE.instantiate() as PaintJobConsumable
	add_child(paint)
	_spawned.append(paint)

	var die_a = _make_die(D6_DATA)
	var die_b = _make_die(D6_DATA)
	var die_c = _make_die(D6_DATA)
	die_a.force_color(DiceColorClass.Type.NONE)
	die_b.force_color(DiceColorClass.Type.GREEN)
	die_c.force_color(DiceColorClass.Type.NONE)
	var dice: Array = [die_a, die_b, die_c]

	paint.paint_dice(dice)
	_check("paint_job is active after paint_dice", paint.is_active)
	_check("paint_job stored 3 prior colors", paint._saved_colors.size() == 3)
	_check("prior color of die B stored as GREEN", paint._saved_colors.get(die_b) == DiceColorClass.Type.GREEN)
	_check("die A painted to a real color", DiceColorClass.is_colored(die_a.color))
	_check("die B painted to a real color", DiceColorClass.is_colored(die_b.color))
	_check("die C painted to a real color", DiceColorClass.is_colored(die_c.color))

	# Drive the restore signal manually with a fake hand
	var fake_hand = Node.new()
	fake_hand.name = "FakeDiceHand"
	fake_hand.add_user_signal("roll_complete")
	add_child(fake_hand)
	_spawned.append(fake_hand)

	paint.connect_restore(fake_hand)
	var callback := Callable(paint, "_on_roll_complete")
	_check("paint_job connected to roll_complete", fake_hand.is_connected("roll_complete", callback))

	fake_hand.emit_signal("roll_complete")
	_check("die A color restored to NONE", die_a.color == DiceColorClass.Type.NONE)
	_check("die B color restored to GREEN", die_b.color == DiceColorClass.Type.GREEN)
	_check("die C color restored to NONE", die_c.color == DiceColorClass.Type.NONE)
	_check("saved colors cleared", paint._saved_colors.is_empty())
	_check("one-shot disconnect", not fake_hand.is_connected("roll_complete", callback))
	_check("paint_job no longer active", not paint.is_active)

	# Second emit must be a no-op (no listener left)
	fake_hand.emit_signal("roll_complete")
	_check("die B still GREEN after extra emit", die_b.color == DiceColorClass.Type.GREEN)
