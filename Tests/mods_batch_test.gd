extends Node

## ModsBatchTest
##
## Headless auto-running batch test for the wildcard evaluator fix and the
## painted_die / cursed_six mods. Prints OK/FAILED per check, then a summary
## and quits with exit code 0 (all passed) or 1 (any failure).

const ScorecardScript := preload("res://Scenes/ScoreCard/score_card.gd")
const DiceHandScene := preload("res://Scenes/Dice/dice_hand.tscn")
const WildcardModScript := preload("res://Scripts/Mods/wild_card_mod.gd")
const DiceColorClass := preload("res://Scripts/Core/dice_color.gd")

var painted_die_data: ModData = preload("res://Scripts/Mods/PaintedDieMod.tres")
var cursed_six_data: ModData = preload("res://Scripts/Mods/CursedSixMod.tres")

var _pass_count: int = 0
var _fail_count: int = 0
var _scorecard: Scorecard = null
var _stub_nodes: Array = []


func _ready() -> void:
	print("[ModsBatchTest] Starting")
	await _run_all_tests()
	_finish()


func _run_all_tests() -> void:
	_test_wildcard_evaluator()
	await _test_dice_mods()
	_test_mod_registration()


## _check(label, condition)
##
## Records a test result and prints OK/FAILED.
func _check(label: String, condition: bool) -> void:
	if condition:
		_pass_count += 1
		print("OK: " + label)
	else:
		_fail_count += 1
		print("FAILED: " + label)


func _finish() -> void:
	print("[ModsBatchTest] RESULTS: %d passed, %d failed" % [_pass_count, _fail_count])
	if _fail_count == 0:
		print("[ModsBatchTest] OK - all checks passed")
		get_tree().quit(0)
	else:
		print("[ModsBatchTest] FAILED - %d check(s) failed" % _fail_count)
		get_tree().quit(1)


# ---------------------------------------------------------------------------
# Wildcard evaluator restriction
# ---------------------------------------------------------------------------

## _make_wildcard_die(shown_value, sides, use_real_mod)
##
## Builds a stub Dice (not added to the tree) with the wildcard mod attached.
## With use_real_mod, a real WildcardMod is applied so get_possible_values()
## is populated (every face except the shown one). Otherwise a plain Node
## stub simulates a wildcard die lacking the method (legacy behavior).
func _make_wildcard_die(shown_value: int, sides: int = 6, use_real_mod: bool = true) -> Dice:
	var die := Dice.new()
	var data := DiceData.new()
	data.sides = sides
	die.dice_data = data
	die.value = shown_value
	if use_real_mod:
		var mod = WildcardModScript.new()
		_stub_nodes.append(mod)
		die.active_mods["wildcard"] = mod
		mod.apply(die)
	else:
		var stub := Node.new()
		_stub_nodes.append(stub)
		die.active_mods["wildcard"] = stub
	return die


func _make_plain_die(shown_value: int) -> Dice:
	var die := Dice.new()
	die.dice_data = DiceData.new()
	die.value = shown_value
	return die


func _free_dice(dice: Array) -> void:
	for die in dice:
		if is_instance_valid(die):
			die.free()


func _test_wildcard_evaluator() -> void:
	print("-- Wildcard evaluator restriction --")
	_scorecard = ScorecardScript.new()
	add_child(_scorecard)
	DiceResults.set_scorecard(_scorecard)

	# Case 1: wildcard showing 3 alongside [4,4,4,4] must evaluate Yahtzee,
	# and must NOT count as a 3 for the threes category.
	var dice: Array = []
	dice.append(_make_wildcard_die(3))
	for i in range(4):
		dice.append(_make_plain_die(4))
	DiceResults.update_from_dice(dice)
	_check("wildcard refs registered", DiceResults.dice_refs.size() == 5)

	var scores: Dictionary = ScoreEvaluatorSingleton.evaluate_with_wildcards(DiceResults.values)
	_check("wildcard showing 3 with [4,4,4,4] evaluates Yahtzee", scores.get("yahtzee", 0) == 50)
	# Note: zero-scoring categories are omitted from the result dict
	_check("wildcard showing 3 does NOT count as a 3 (threes = 0)", scores.get("threes", 0) == 0)
	_check("is_yahtzee agrees (wild joins 4s)", ScoreEvaluatorSingleton.is_yahtzee(DiceResults.values))

	var combos: Array = ScoreEvaluatorSingleton.generate_wildcard_combinations(1, 6)
	var combo_has_three := false
	for combo in combos:
		if combo.has(3):
			combo_has_three = true
	_check("no generated substitute is the shown face (3)", not combo_has_three)
	_check("combinations still generated", combos.size() > 0)
	_free_dice(dice)

	# Case 2: wildcard showing 3 with four 3s must NOT complete a Yahtzee
	# (the wildcard cannot count as its own shown face).
	dice = []
	dice.append(_make_wildcard_die(3))
	for i in range(4):
		dice.append(_make_plain_die(3))
	DiceResults.update_from_dice(dice)
	_check("wildcard showing 3 must NOT join four 3s into Yahtzee", not ScoreEvaluatorSingleton.is_yahtzee(DiceResults.values))
	scores = ScoreEvaluatorSingleton.evaluate_with_wildcards(DiceResults.values)
	_check("evaluate_with_wildcards agrees (yahtzee = 0)", scores.get("yahtzee", 0) == 0)
	_free_dice(dice)

	# Case 3: a wildcard die whose mod lacks get_possible_values() keeps the
	# legacy unrestricted behavior.
	dice = []
	dice.append(_make_wildcard_die(3, 6, false))
	for i in range(4):
		dice.append(_make_plain_die(3))
	DiceResults.update_from_dice(dice)
	_check("legacy stub wildcard still counts as any face (Yahtzee)", ScoreEvaluatorSingleton.is_yahtzee(DiceResults.values))
	_free_dice(dice)

	# Case 4: possible_values refreshes when the die rolls a new face.
	var refresh_die := _make_wildcard_die(3)
	var refresh_mod = refresh_die.get_mod("wildcard")
	_check("possible values exclude shown face 3", not refresh_mod.get_possible_values().has(3))
	_check("possible values cover all other faces", refresh_mod.get_possible_values() == [1, 2, 4, 5, 6])
	refresh_die.value = 5
	refresh_die.emit_signal("rolled", 5)
	_check("possible values refresh on roll (3 allowed, 5 excluded)",
		refresh_mod.get_possible_values() == [1, 2, 3, 4, 6])
	_free_dice([refresh_die])

	for stub in _stub_nodes:
		if is_instance_valid(stub):
			stub.free()
	_stub_nodes.clear()

	DiceResults.reset()
	DiceResults.set_scorecard(null)
	_scorecard.free()
	_scorecard = null


# ---------------------------------------------------------------------------
# painted_die / cursed_six on real dice
# ---------------------------------------------------------------------------

func _test_dice_mods() -> void:
	print("-- Painted Die mod --")
	var hand = DiceHandScene.instantiate()
	add_child(hand)
	hand.spawn_dice()
	await hand.dice_spawned
	_check("dice hand spawned", hand.dice_list.size() > 1)

	var painted_die: Dice = hand.dice_list[0]
	painted_die.add_mod(painted_die_data)
	_check("painted_die mod applied", painted_die.has_mod("painted_die"))
	var painted_mod = painted_die.get_mod("painted_die")
	_check("die got a non-NONE color", painted_die.color != DiceColorClass.Type.NONE)
	_check("mod stored the painted color", painted_mod.painted_color == painted_die.color)
	_check("color name getter matches",
		painted_mod.get_painted_color_name() == DiceColorClass.get_color_name(painted_die.color))

	# The painted color must survive a roll (Dice.roll() re-runs its own
	# random color assignment).
	var painted_color = painted_die.color
	painted_die.roll()
	_check("painted color re-asserted after roll", painted_die.color == painted_color)

	painted_die.remove_mod("painted_die")
	_check("mod removed", not painted_die.has_mod("painted_die"))
	_check("color cleared to NONE on remove", painted_die.color == DiceColorClass.Type.NONE)

	print("-- Cursed Six mod --")
	_check("cursed_six buy price is $25", cursed_six_data.price == 25)
	_check("cursed_six sell price is $0", cursed_six_data.sell_price == 0)

	var cursed_die: Dice = hand.dice_list[1]
	PlayerEconomy.money = 100
	cursed_die.add_mod(cursed_six_data)
	_check("cursed_six mod applied", cursed_die.has_mod("cursed_six"))

	cursed_die.roll()
	_check("cursed die always rolls 6", cursed_die.value == 6)
	_check("roll charged $5", PlayerEconomy.money == 95)

	# Fixed face clamps to the highest face on smaller dice (d4 -> 4).
	var d4_data := DiceData.new()
	d4_data.sides = 4
	cursed_die.dice_data = d4_data
	cursed_die.make_rollable()
	cursed_die.roll()
	_check("d4 clamps forced face to 4", cursed_die.value == 4)
	_check("d4 roll still charged $5", PlayerEconomy.money == 90)

	# The charge is mandatory even when the player cannot afford it.
	PlayerEconomy.money = 2
	cursed_die.make_rollable()
	cursed_die.roll()
	_check("charge applies even when broke", PlayerEconomy.money == -3)

	PlayerEconomy.money = 100
	cursed_die.remove_mod("cursed_six")
	_check("cursed_six mod removed", not cursed_die.has_mod("cursed_six"))

	hand.queue_free()


# ---------------------------------------------------------------------------
# ModManager registration
# ---------------------------------------------------------------------------

func _test_mod_registration() -> void:
	print("-- Mod registration --")
	var mod_manager = load("res://Scenes/Managers/mod_manager.tscn").instantiate()
	add_child(mod_manager)
	_check("painted_die registered in ModManager", mod_manager.get_def("painted_die") != null)
	_check("cursed_six registered in ModManager", mod_manager.get_def("cursed_six") != null)
	_check("painted_die display name", mod_manager.get_def("painted_die").display_name == "Painted Die")
	_check("cursed_six display name", mod_manager.get_def("cursed_six").display_name == "Cursed Six")
	mod_manager.queue_free()
