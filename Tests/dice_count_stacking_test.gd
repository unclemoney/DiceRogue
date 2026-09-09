extends Node

## DiceCountStackingTest
##
## Verifies that dice_count / MAX_ROLLS mutations from ExtraDice, ExtraRolls,
## GreatExchange, YahtzeedDice and the OneShot debuff are relative and
## stacking-safe: applying/removing them in any sane buy/sell order returns
## DiceHand.dice_count and TurnTracker.MAX_ROLLS exactly to baseline.
##
## Note: TurnTracker.get_total_dice_count() (turn_tracker.gd) reconciles only
## the consumable dice-bonus stacks, not power-up dice, so the canonical
## values asserted here are hand.dice_count and tracker.MAX_ROLLS.
##
## Runs headless: quits with exit code 0 on PASS, 1 on FAIL.

const BASELINE_DICE: int = 5
const BASELINE_ROLLS: int = 3

var _fail_count: int = 0

var hand: DiceHand
var tracker: TurnTracker
var game_controller: GameController


func _ready() -> void:
	print("=== Dice Count Stacking Test ===")

	# Wait a frame so the scene root finishes setting up (YahtzeedDice's
	# floating-label juice add_child()s to the tree root)
	await get_tree().process_frame

	_setup_components()

	test_apply_all_remove_reverse()
	_reset_components()
	test_interleaved_apply_remove()
	_reset_components()
	test_apply_remove_twice()
	_reset_components()
	test_duplicate_stacking()

	print("")
	if _fail_count > 0:
		print("=== Dice Count Stacking Test: FAIL (%d) ===" % _fail_count)
		get_tree().quit(1)
	else:
		print("=== Dice Count Stacking Test: PASS ===")
		get_tree().quit(0)


## _setup_components()
##
## Builds the minimal real instances the effect scripts cast to:
## a DiceHand and a GameController kept out of the tree (so their _ready
## logic never runs), plus a TurnTracker added to the tree and the
## "turn_tracker" group because OneShotDebuff looks it up via get_tree().
func _setup_components() -> void:
	hand = DiceHand.new()

	tracker = TurnTracker.new()
	tracker.add_to_group("turn_tracker")
	add_child(tracker)

	game_controller = GameController.new()
	game_controller.dice_hand = hand
	game_controller.turn_tracker = tracker

	_assert_state(BASELINE_DICE, BASELINE_ROLLS, "setup baseline")


## _reset_components()
##
## Tears down the components from the previous case and builds fresh ones.
## The old tracker leaves the "turn_tracker" group and is freed immediately:
## queue_free() is deferred, so a queued tracker would still win
## get_first_node_in_group("turn_tracker") for the rest of the frame.
func _reset_components() -> void:
	remove_child(tracker)
	tracker.remove_from_group("turn_tracker")
	tracker.free()
	# hand and game_controller were never added to the tree
	hand.free()
	game_controller.free()
	_setup_components()


## test_apply_all_remove_reverse()
##
## Applies ExtraDice, ExtraRolls, GreatExchange, YahtzeedDice and OneShot,
## then removes them in exact reverse order.
func test_apply_all_remove_reverse() -> void:
	print("\n--- Case 1: apply all, remove in reverse ---")
	var extra_dice = _make_power_up("res://Scenes/PowerUp/ExtraDicePowerUp.tscn")
	var extra_rolls = _make_power_up("res://Scenes/PowerUp/ExtraRollsPowerUp.tscn")
	var great_exchange = _make_power_up("res://Scenes/PowerUp/GreatExchangePowerUp.tscn")
	var yahtzeed_dice = _make_power_up("res://Scenes/PowerUp/YahtzeedDicePowerUp.tscn")
	var one_shot = _make_debuff("res://Scenes/Debuff/OneShotDebuff.tscn")

	extra_dice.apply(hand)
	_assert_state(6, 3, "case1 apply ExtraDice")

	extra_rolls.apply(tracker)
	_assert_state(6, 4, "case1 apply ExtraRolls")

	great_exchange.apply(game_controller)
	_assert_state(8, 3, "case1 apply GreatExchange")

	yahtzeed_dice.apply(hand)
	_assert_state(8, 3, "case1 apply YahtzeedDice (no dice yet)")
	RollStats.emit_signal("yahtzee_rolled")
	_assert_state(9, 3, "case1 Yahtzee rolled (+1 die)")

	one_shot.apply(hand)
	_assert_state(9, 1, "case1 apply OneShotDebuff")

	one_shot.remove()
	_assert_state(9, 3, "case1 remove OneShotDebuff")

	yahtzeed_dice.remove(hand)
	_assert_state(8, 3, "case1 remove YahtzeedDice")

	great_exchange.remove(game_controller)
	_assert_state(6, 4, "case1 remove GreatExchange")

	extra_rolls.remove(tracker)
	_assert_state(6, 3, "case1 remove ExtraRolls")

	extra_dice.remove(hand)
	_assert_state(5, 3, "case1 remove ExtraDice (baseline)")


## test_interleaved_apply_remove()
##
## Interleaves buys and sells. OneShotDebuff stays innermost (applied last,
## removed first) because it snapshots and restores MAX_ROLLS absolutely.
func test_interleaved_apply_remove() -> void:
	print("\n--- Case 2: interleaved apply/remove ---")
	var extra_dice = _make_power_up("res://Scenes/PowerUp/ExtraDicePowerUp.tscn")
	var extra_rolls = _make_power_up("res://Scenes/PowerUp/ExtraRollsPowerUp.tscn")
	var great_exchange = _make_power_up("res://Scenes/PowerUp/GreatExchangePowerUp.tscn")
	var yahtzeed_dice = _make_power_up("res://Scenes/PowerUp/YahtzeedDicePowerUp.tscn")
	var one_shot = _make_debuff("res://Scenes/Debuff/OneShotDebuff.tscn")

	extra_dice.apply(hand)
	_assert_state(6, 3, "case2 apply ExtraDice")

	great_exchange.apply(game_controller)
	_assert_state(8, 2, "case2 apply GreatExchange")

	extra_dice.remove(hand)
	_assert_state(7, 2, "case2 remove ExtraDice early")

	extra_rolls.apply(tracker)
	_assert_state(7, 3, "case2 apply ExtraRolls")

	yahtzeed_dice.apply(hand)
	RollStats.emit_signal("yahtzee_rolled")
	_assert_state(8, 3, "case2 YahtzeedDice + Yahtzee")

	one_shot.apply(hand)
	_assert_state(8, 1, "case2 apply OneShotDebuff")

	one_shot.remove()
	_assert_state(8, 3, "case2 remove OneShotDebuff")

	great_exchange.remove(game_controller)
	_assert_state(6, 4, "case2 remove GreatExchange")

	yahtzeed_dice.remove(hand)
	_assert_state(5, 4, "case2 remove YahtzeedDice")

	extra_rolls.remove(tracker)
	_assert_state(5, 3, "case2 remove ExtraRolls (baseline)")


## test_apply_remove_twice()
##
## Applies and removes each effect twice in a row (buy/sell/buy/sell).
func test_apply_remove_twice() -> void:
	print("\n--- Case 3: each effect applied and removed twice ---")

	for i in 2:
		var extra_dice = _make_power_up("res://Scenes/PowerUp/ExtraDicePowerUp.tscn")
		extra_dice.apply(hand)
		_assert_state(6, 3, "case3 ExtraDice apply #%d" % (i + 1))
		extra_dice.remove(hand)
		_assert_state(5, 3, "case3 ExtraDice remove #%d" % (i + 1))
		extra_dice.queue_free()

	for i in 2:
		var extra_rolls = _make_power_up("res://Scenes/PowerUp/ExtraRollsPowerUp.tscn")
		extra_rolls.apply(tracker)
		_assert_state(5, 4, "case3 ExtraRolls apply #%d" % (i + 1))
		extra_rolls.remove(tracker)
		_assert_state(5, 3, "case3 ExtraRolls remove #%d" % (i + 1))
		extra_rolls.queue_free()

	for i in 2:
		var great_exchange = _make_power_up("res://Scenes/PowerUp/GreatExchangePowerUp.tscn")
		great_exchange.apply(game_controller)
		_assert_state(7, 2, "case3 GreatExchange apply #%d" % (i + 1))
		great_exchange.remove(game_controller)
		_assert_state(5, 3, "case3 GreatExchange remove #%d" % (i + 1))
		great_exchange.queue_free()

	for i in 2:
		var yahtzeed_dice = _make_power_up("res://Scenes/PowerUp/YahtzeedDicePowerUp.tscn")
		yahtzeed_dice.apply(hand)
		RollStats.emit_signal("yahtzee_rolled")
		_assert_state(6, 3, "case3 YahtzeedDice + Yahtzee #%d" % (i + 1))
		yahtzeed_dice.remove(hand)
		_assert_state(5, 3, "case3 YahtzeedDice remove #%d" % (i + 1))
		yahtzeed_dice.queue_free()

	for i in 2:
		var one_shot = _make_debuff("res://Scenes/Debuff/OneShotDebuff.tscn")
		one_shot.apply(hand)
		_assert_state(5, 1, "case3 OneShotDebuff apply #%d" % (i + 1))
		one_shot.remove()
		_assert_state(5, 3, "case3 OneShotDebuff remove #%d" % (i + 1))
		one_shot.queue_free()


## test_duplicate_stacking()
##
## Buys two copies of ExtraDice and two of ExtraRolls at once — the case the
## old absolute assignments (= 6 / = 4) got wrong — then sells them off.
func test_duplicate_stacking() -> void:
	print("\n--- Case 4: duplicate copies stack ---")
	var extra_dice_a = _make_power_up("res://Scenes/PowerUp/ExtraDicePowerUp.tscn")
	var extra_dice_b = _make_power_up("res://Scenes/PowerUp/ExtraDicePowerUp.tscn")
	var extra_rolls_a = _make_power_up("res://Scenes/PowerUp/ExtraRollsPowerUp.tscn")
	var extra_rolls_b = _make_power_up("res://Scenes/PowerUp/ExtraRollsPowerUp.tscn")

	extra_dice_a.apply(hand)
	extra_dice_b.apply(hand)
	_assert_state(7, 3, "case4 two ExtraDice applied")

	extra_rolls_a.apply(tracker)
	extra_rolls_b.apply(tracker)
	_assert_state(7, 5, "case4 two ExtraRolls applied")

	extra_dice_a.remove(hand)
	_assert_state(6, 5, "case4 one ExtraDice removed")

	extra_rolls_b.remove(tracker)
	_assert_state(6, 4, "case4 one ExtraRolls removed")

	extra_dice_b.remove(hand)
	extra_rolls_a.remove(tracker)
	_assert_state(5, 3, "case4 all duplicates removed (baseline)")


## _make_power_up(scene_path) -> PowerUp
##
## Instantiates a PowerUp scene and adds it to the tree (its _ready joins
## the "power_ups" group and tree_exiting hooks need the tree).
func _make_power_up(scene_path: String) -> PowerUp:
	var scene: PackedScene = load(scene_path)
	_auto_assert(scene != null, "power-up scene loads: %s" % scene_path)
	var power_up: PowerUp = scene.instantiate()
	add_child(power_up)
	return power_up


## _make_debuff(scene_path) -> Debuff
##
## Instantiates a Debuff scene and adds it to the tree (OneShotDebuff finds
## the TurnTracker via get_tree()).
func _make_debuff(scene_path: String) -> Debuff:
	var scene: PackedScene = load(scene_path)
	_auto_assert(scene != null, "debuff scene loads: %s" % scene_path)
	var debuff: Debuff = scene.instantiate()
	add_child(debuff)
	return debuff


## _assert_state(expected_dice, expected_rolls, label)
##
## Asserts both mutated values after a step.
func _assert_state(expected_dice: int, expected_rolls: int, label: String) -> void:
	_auto_assert(hand.dice_count == expected_dice, "%s: dice_count == %d (got %d)" % [label, expected_dice, hand.dice_count])
	_auto_assert(tracker.MAX_ROLLS == expected_rolls, "%s: MAX_ROLLS == %d (got %d)" % [label, expected_rolls, tracker.MAX_ROLLS])


func _auto_assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_fail_count += 1
		push_error("[DiceCountStackingTest] FAIL: %s" % message)
		print("FAIL: %s" % message)
