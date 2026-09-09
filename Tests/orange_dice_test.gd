extends Node

## orange_dice_test.gd
##
## Validates the Orange dice color (6th dice color):
##   1. Enum value, display name, display color, and get_all_colors() inclusion
##   2. COLOR_CHANCES entry (1 in 150)
##   3. OrangeDice.tres data load and $175 base cost via get_current_color_cost()
##   4. Rainbow bonus triggers with exactly 5 unique colors (with and without Orange)
##   5. Same-color doubling for 5+ Orange dice (doubles the roll grant)
##   6. Orange roll-grant appears in the effects dict (orange_rolls)
##   7. Shader parameter application for the ORANGE color
##   8. Temporary roll lifecycle: scored rolls queue as pending, apply to the
##      NEXT turn only, expire after that turn, carry across a round boundary
##      (TurnTracker.reset), and are wiped by clear_temporary_rolls()
##
## Scene-based test (needs DiceColorManager autoload).
## Run headless:
##   godot --headless --path . Tests/orange_dice_test.tscn
## Exit code 0 = all checks passed, 1 = at least one failure.

const DiceColorClass = preload("res://Scripts/Core/dice_color.gd")
const DICE_SCENE = preload("res://Scenes/Dice/dice.tscn")
const DICE_SHADER = preload("res://Scripts/Shaders/dice_combined_effects.gdshader")

var _failures: int = 0
var _mock_dice: Array = []


func _ready() -> void:
	print("[OrangeDiceTest] Starting")
	# Allow autoloads to finish initializing
	await get_tree().process_frame
	await get_tree().process_frame

	_test_orange_enum_and_utils()
	_test_orange_chance()
	_test_orange_data_and_cost()
	_test_rainbow_rule()
	_test_same_color_doubling()
	_test_orange_roll_grant()
	_test_orange_shader_params()
	_test_orange_temporary_rolls()

	_cleanup_mock_dice()

	if _failures == 0:
		print("[OrangeDiceTest] PASS - all checks passed")
		get_tree().quit(0)
	else:
		print("[OrangeDiceTest] FAIL - %d check(s) failed" % _failures)
		get_tree().quit(1)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[OrangeDiceTest] OK: " + label)
	else:
		push_error("[OrangeDiceTest] FAILED: " + label)
		_failures += 1


func _make_die(color_type: int, value: int) -> Dice:
	var die = DICE_SCENE.instantiate() as Dice
	die.value = value
	die.color = color_type
	add_child(die)
	_mock_dice.append(die)
	return die


func _cleanup_mock_dice() -> void:
	for die in _mock_dice:
		if is_instance_valid(die):
			die.queue_free()
	_mock_dice.clear()


func _test_orange_enum_and_utils() -> void:
	_check("ORANGE enum value is 6 (appended after YELLOW)", DiceColorClass.Type.ORANGE == 6)
	_check("COLOR_NAMES has Orange", DiceColorClass.get_color_name(DiceColorClass.Type.ORANGE) == "Orange")
	_check("get_all_colors() has 6 colors", DiceColorClass.get_all_colors().size() == 6)
	_check("get_all_colors() contains ORANGE", DiceColorClass.Type.ORANGE in DiceColorClass.get_all_colors())
	_check("is_colored(ORANGE) is true", DiceColorClass.is_colored(DiceColorClass.Type.ORANGE))
	_check("display color is not WHITE fallback", DiceColorClass.get_display_color(DiceColorClass.Type.ORANGE) != Color.WHITE)


func _test_orange_chance() -> void:
	_check("COLOR_CHANCES orange is 150", DiceColorClass.get_color_chance(DiceColorClass.Type.ORANGE) == 150)
	_check("orange rarer than yellow (150 > 120)", DiceColorClass.get_color_chance(DiceColorClass.Type.ORANGE) > DiceColorClass.get_color_chance(DiceColorClass.Type.YELLOW))


func _test_orange_data_and_cost() -> void:
	var data = DiceColorManager.get_colored_dice_data("orange_dice")
	_check("orange_dice data loaded by DiceColorManager", data != null)
	if data:
		_check("orange_dice display_name", data.display_name == "Orange Dice")
		_check("orange_dice color_type is ORANGE (6)", data.color_type == DiceColorClass.Type.ORANGE)
		_check("orange_dice price is $175", data.price == 175)
		_check("orange_dice is_valid()", data.is_valid())

	# Reset purchases so the base cost check is deterministic
	DiceColorManager._reset_purchased_colors()
	_check("purchased_colors tracks ORANGE", DiceColorManager.purchased_colors.has(DiceColorClass.Type.ORANGE))
	_check("base color cost is $175", DiceColorManager.get_current_color_cost(DiceColorClass.Type.ORANGE) == 175)
	_check("base color chance is 1 in 150", DiceColorManager.get_current_color_chance(DiceColorClass.Type.ORANGE) == 150)


func _test_rainbow_rule() -> void:
	# 5 unique colors including ORANGE -> rainbow
	var dice_with_orange = [
		_make_die(DiceColorClass.Type.GREEN, 1),
		_make_die(DiceColorClass.Type.RED, 2),
		_make_die(DiceColorClass.Type.PURPLE, 3),
		_make_die(DiceColorClass.Type.BLUE, 4),
		_make_die(DiceColorClass.Type.ORANGE, 5)
	]
	var effects = DiceColorManager.calculate_color_effects(dice_with_orange, [])
	_check("rainbow triggers with 5 unique colors including orange", effects.get("rainbow_bonus", false))

	# 5 unique colors excluding ORANGE (old full set) -> rainbow
	var dice_without_orange = [
		_make_die(DiceColorClass.Type.GREEN, 1),
		_make_die(DiceColorClass.Type.RED, 2),
		_make_die(DiceColorClass.Type.PURPLE, 3),
		_make_die(DiceColorClass.Type.BLUE, 4),
		_make_die(DiceColorClass.Type.YELLOW, 5)
	]
	effects = DiceColorManager.calculate_color_effects(dice_without_orange, [])
	_check("rainbow triggers with 5 unique colors excluding orange", effects.get("rainbow_bonus", false))

	# Only 4 unique colors -> no rainbow
	var dice_four_colors = [
		_make_die(DiceColorClass.Type.GREEN, 1),
		_make_die(DiceColorClass.Type.RED, 2),
		_make_die(DiceColorClass.Type.PURPLE, 3),
		_make_die(DiceColorClass.Type.ORANGE, 4),
		_make_die(DiceColorClass.Type.NONE, 5)
	]
	effects = DiceColorManager.calculate_color_effects(dice_four_colors, [])
	_check("no rainbow with only 4 unique colors", not effects.get("rainbow_bonus", true))


func _test_same_color_doubling() -> void:
	# 5 orange dice -> same color bonus doubles the roll grant (5 -> 10)
	var five_orange = [
		_make_die(DiceColorClass.Type.ORANGE, 1),
		_make_die(DiceColorClass.Type.ORANGE, 2),
		_make_die(DiceColorClass.Type.ORANGE, 3),
		_make_die(DiceColorClass.Type.ORANGE, 4),
		_make_die(DiceColorClass.Type.ORANGE, 5)
	]
	var effects = DiceColorManager.calculate_color_effects(five_orange, [])
	_check("same color bonus with 5 orange dice", effects.get("same_color_bonus", false))
	_check("orange roll grant doubled to 10", effects.get("orange_rolls", 0) == 10)


func _test_orange_roll_grant() -> void:
	# 2 orange dice scored -> +2 rolls in the effects dict
	var dice = [
		_make_die(DiceColorClass.Type.ORANGE, 3),
		_make_die(DiceColorClass.Type.ORANGE, 4),
		_make_die(DiceColorClass.Type.NONE, 1),
		_make_die(DiceColorClass.Type.NONE, 2),
		_make_die(DiceColorClass.Type.NONE, 6)
	]
	var effects = DiceColorManager.calculate_color_effects(dice, [])
	_check("orange_scored flag set", effects.get("orange_scored", false))
	_check("orange_count is 2", effects.get("orange_count", 0) == 2)
	_check("orange_rolls is 2 (+1 per orange die scored)", effects.get("orange_rolls", 0) == 2)

	# Unused orange dice (not in used_dice_array) grant no rolls
	var used_indices: Array = [2, 3, 4]  # only the NONE dice are "used"
	effects = DiceColorManager.calculate_color_effects(dice, used_indices)
	_check("orange not scored when unused", not effects.get("orange_scored", true))
	_check("orange_rolls is 0 when unused", effects.get("orange_rolls", 1) == 0)


func _test_orange_shader_params() -> void:
	var material := ShaderMaterial.new()
	material.shader = DICE_SHADER
	Dice.apply_color_shader_parameters(material, DiceColorClass.Type.ORANGE)
	_check("orange_color_strength applied", is_equal_approx(material.get_shader_parameter("orange_color_strength"), 0.8))
	_check("other colors cleared when orange applied", is_equal_approx(material.get_shader_parameter("yellow_color_strength"), 0.0))
	Dice.clear_color_shader_parameters(material)
	_check("orange_color_strength cleared", is_equal_approx(material.get_shader_parameter("orange_color_strength"), 0.0))


func _test_orange_temporary_rolls() -> void:
	# Fresh tracker standing in for the game's TurnTracker (found via group)
	var tracker = TurnTracker.new()
	add_child(tracker)
	tracker.add_to_group("turn_tracker")
	tracker.MAX_ROLLS = 3
	tracker.current_turn = 1
	tracker.is_active = true

	var dice = [
		_make_die(DiceColorClass.Type.ORANGE, 3),
		_make_die(DiceColorClass.Type.ORANGE, 4),
		_make_die(DiceColorClass.Type.NONE, 1),
		_make_die(DiceColorClass.Type.NONE, 2),
		_make_die(DiceColorClass.Type.NONE, 6)
	]

	# (1) Score 2 orange mid-turn -> pending 2, MAX_ROLLS unchanged now
	DiceColorManager.calculate_color_effects(dice, [], true)
	_check("scoring 2 orange queues 2 pending rolls", tracker.orange_rolls_pending == 2)
	_check("MAX_ROLLS unchanged when scored mid-turn", tracker.MAX_ROLLS == 3)

	# (2) Start next turn -> MAX_ROLLS = base + 2
	tracker.start_new_turn()
	_check("next turn applies pending bonus (MAX_ROLLS 5)", tracker.MAX_ROLLS == 5)
	_check("active bonus is 2", tracker.orange_rolls_active == 2)
	_check("pending cleared after application", tracker.orange_rolls_pending == 0)
	_check("rolls_left matches boosted max", tracker.rolls_left == 5)

	# (3) Following turn -> MAX_ROLLS back to base
	tracker.start_new_turn()
	_check("bonus expires after boosted turn (MAX_ROLLS 3)", tracker.MAX_ROLLS == 3)
	_check("active bonus cleared after boosted turn", tracker.orange_rolls_active == 0)

	# (3b) Multiple scores before the boosted turn accumulate
	DiceColorManager.calculate_color_effects(dice, [], true)
	DiceColorManager.calculate_color_effects(dice, [], true)
	_check("multiple scores accumulate (pending 4)", tracker.orange_rolls_pending == 4)
	tracker.start_new_turn()
	_check("accumulated bonus applies (MAX_ROLLS 7)", tracker.MAX_ROLLS == 7)
	tracker.start_new_turn()
	_check("accumulated bonus expires (MAX_ROLLS 3)", tracker.MAX_ROLLS == 3)

	# (4) Carry across a round boundary (RoundManager calls turn_tracker.reset())
	DiceColorManager.calculate_color_effects(dice, [], true)
	_check("pending 2 before round boundary", tracker.orange_rolls_pending == 2)
	tracker.reset()
	_check("bonus carries across round boundary (MAX_ROLLS 5)", tracker.MAX_ROLLS == 5)
	_check("active bonus is 2 after round reset", tracker.orange_rolls_active == 2)
	tracker.start_new_turn()
	_check("carried bonus expires next turn (MAX_ROLLS 3)", tracker.MAX_ROLLS == 3)

	# (5) clear_temporary_rolls() wipes pending and active (Mall Zone transition)
	DiceColorManager.calculate_color_effects(dice, [], true)
	tracker.start_new_turn()
	DiceColorManager.calculate_color_effects(dice, [], true)
	tracker.clear_temporary_rolls()
	_check("clear_temporary_rolls wipes pending", tracker.orange_rolls_pending == 0)
	_check("clear_temporary_rolls wipes active", tracker.orange_rolls_active == 0)
	_check("clear_temporary_rolls restores base MAX_ROLLS", tracker.MAX_ROLLS == 3)

	# (6) Save/load: the bonus is session-scoped and never persisted
	DiceColorManager.calculate_color_effects(dice, [], true)
	tracker.start_new_turn()
	var saved = tracker.get_state()
	_check("get_state saves base MAX_ROLLS (active bonus stripped)", saved.get("MAX_ROLLS", -1) == 3)
	tracker.load_state(saved)
	_check("load_state clears pending orange rolls", tracker.orange_rolls_pending == 0)
	_check("load_state clears active orange rolls", tracker.orange_rolls_active == 0)

	tracker.remove_from_group("turn_tracker")
	tracker.queue_free()
