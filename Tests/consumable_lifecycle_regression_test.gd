extends Control

## Consolidated regressions for consumable lifecycle, stacking, and apply rejection.
## Run headless with `-- --auto-test` to quit with a result code.

var _fail_count: int = 0
var game_controller: BareGameController
var scorecard: Scorecard
var scorecard_ui: ScoreCardUI
var powerup_ui: BarePowerUpUI
var turn_tracker: TurnTracker
var dice_hand: DiceHand


class BareGameController extends GameController:
	func _ready() -> void:
		pass


class BarePowerUpUI extends PowerUpUI:
	func _ready() -> void:
		pass


class BareDice extends Dice:
	func _ready() -> void:
		pass

	func _update_color_shader() -> void:
		pass


func _ready() -> void:
	ScoreModifierManager.reset()
	MusicManager.stop_music()
	AudioManager.streak_sound = null
	game_controller = BareGameController.new()
	add_child(game_controller)
	scorecard = Scorecard.new()
	add_child(scorecard)
	scorecard_ui = load("res://Scenes/UI/Scorecard/scorecard.tscn").instantiate() as ScoreCardUI
	add_child(scorecard_ui)
	scorecard_ui.bind_scorecard(scorecard)
	powerup_ui = BarePowerUpUI.new()
	add_child(powerup_ui)
	turn_tracker = TurnTracker.new()
	add_child(turn_tracker)
	turn_tracker.current_turn = 1
	turn_tracker.is_active = true
	dice_hand = DiceHand.new()
	game_controller.scorecard = scorecard
	game_controller.score_card_ui = scorecard_ui
	game_controller.powerup_ui = powerup_ui
	game_controller.turn_tracker = turn_tracker
	game_controller.dice_hand = dice_hand
	turn_tracker.score_streak_changed.connect(game_controller._on_score_streak_changed)
	turn_tracker.temporary_effect_expired.connect(game_controller._on_temporary_effect_expired)
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_rejected_apply_preserves_inventory()
	_test_score_streak_reset()
	_test_poor_house_rearm()
	_test_double_or_nothing_cleanup()
	_test_green_envy_manual_cleanup()
	_test_repeated_ui_consumables()
	_test_paint_job_reapplication()
	_test_additive_only_amplifier()
	ScoreModifierManager.reset()
	DiceResults.reset()
	PlayerEconomy.reset_to_starting_money()
	print("[ConsumableLifecycleRegression] COMPLETE: %s" % ("PASS" if _fail_count == 0 else "FAIL"))
	_quit_with_result.call_deferred()


func _quit_with_result() -> void:
	MusicManager.stop_music()
	for audio_manager in [MusicManager, AudioManager]:
		for child in audio_manager.get_children():
			if child is AudioStreamPlayer:
				child.stop()
				child.stream = null
	await get_tree().create_timer(0.1).timeout
	dice_hand.free()
	get_tree().quit(0 if _fail_count == 0 else 1)


func _test_rejected_apply_preserves_inventory() -> void:
	var consumable := EmptyShelvesConsumable.new()
	add_child(consumable)
	game_controller.active_consumables["empty_shelves"] = consumable
	game_controller.consumable_counts["empty_shelves"] = 2
	powerup_ui._power_up_data.clear()
	for index in range(powerup_ui.max_power_ups):
		powerup_ui._power_up_data["full_%d" % index] = null
	var applied: bool = game_controller._on_consumable_used("empty_shelves")
	_assert(not applied, "Empty Shelves rejects use with no empty slots")
	_assert(game_controller.consumable_counts.get("empty_shelves", 0) == 2,
		"Rejected apply preserves both inventory copies")
	powerup_ui._power_up_data.clear()
	applied = game_controller._on_consumable_used("empty_shelves")
	_assert(applied, "A later valid apply succeeds on the same instance")
	_assert(game_controller.consumable_counts.get("empty_shelves", 0) == 1,
		"A successful stacked apply removes exactly one copy")
	scorecard.set_score(Scorecard.Section.UPPER, "ones", 10)
	_assert(not ScoreModifierManager.has_multiplier(EmptyShelvesConsumable.MULTIPLIER_ID),
		"The successful stacked apply still cleans up after scoring")
	game_controller.active_consumables.erase("empty_shelves")
	game_controller.consumable_counts.erase("empty_shelves")
	scorecard.reset_scores()


func _test_score_streak_reset() -> void:
	var consumable := ScoreStreakConsumable.new()
	add_child(consumable)
	consumable.apply(game_controller)
	_assert(ScoreModifierManager.has_multiplier("score_streak"), "Score Streak registers its multiplier")
	turn_tracker.reset()
	_assert(not ScoreModifierManager.has_multiplier("score_streak"),
		"Round reset removes the Score Streak multiplier")
	consumable.apply(game_controller)
	turn_tracker.break_score_streak()
	_assert(not ScoreModifierManager.has_multiplier("score_streak"),
		"Breaking a streak does not leave a registered 1x source")


func _test_poor_house_rearm() -> void:
	var consumable := PoorHouseConsumable.new()
	add_child(consumable)
	PlayerEconomy.money = 100
	consumable.apply(game_controller)
	_assert(ScoreModifierManager.get_additive("poor_house_bonus") == 50,
		"Poor House registers its first additive bonus")
	scorecard.set_score(Scorecard.Section.UPPER, "ones", 10)
	_assert(not ScoreModifierManager.has_additive("poor_house_bonus"),
		"Poor House cleans up its first score")
	PlayerEconomy.money = 100
	consumable.apply_succeeded = true
	consumable.apply(game_controller)
	_assert(ScoreModifierManager.get_additive("poor_house_bonus") == 50,
		"Poor House re-arms for a second inventory copy")
	scorecard.set_score(Scorecard.Section.UPPER, "twos", 10)
	_assert(not ScoreModifierManager.has_additive("poor_house_bonus"),
		"Poor House cleans up its second score")
	scorecard.reset_scores()


func _test_double_or_nothing_cleanup() -> void:
	var consumable := DoubleOrNothingConsumable.new()
	add_child(consumable)
	consumable.apply(game_controller)
	_assert(ScoreModifierManager.has_multiplier("double_or_nothing_zero"),
		"Double or Nothing registers its zero multiplier")
	scorecard.set_score(Scorecard.Section.UPPER, "ones", 0)
	_assert(not ScoreModifierManager.has_multiplier("double_or_nothing_zero"),
		"Immediate score_assigned removes the zero multiplier")
	_assert(not consumable.is_active, "Double or Nothing deactivates after scoring")
	consumable.apply(game_controller)
	consumable._on_yahtzee_rolled()
	scorecard.set_score(Scorecard.Section.UPPER, "twos", 10)
	_assert(not ScoreModifierManager.has_multiplier("double_or_nothing_yahtzee"),
		"A non-Yahtzee score cannot retain the Yahtzee multiplier")
	_assert(not consumable.is_active, "Double or Nothing also deactivates after a non-target score")
	scorecard.reset_scores()


func _test_green_envy_manual_cleanup() -> void:
	dice_hand.dice_list.clear()
	var consumable := GreenEnvyConsumable.new()
	add_child(consumable)
	consumable.apply(game_controller)
	_assert(scorecard.is_connected("score_assigned", consumable._on_score_assigned),
		"Green Envy listens to immediate score_assigned")
	scorecard.set_score(Scorecard.Section.UPPER, "ones", 0)
	_assert(not scorecard.is_connected("score_assigned", consumable._on_score_assigned),
		"Manual scoring disconnects Green Envy")
	scorecard.reset_scores()


func _test_repeated_ui_consumables() -> void:
	DiceResults.set_values([1, 2, 3, 4, 5])
	var any_score := AnyScoreConsumable.new()
	add_child(any_score)
	any_score.apply(game_controller)
	any_score.complete_any_score()
	any_score.apply(game_controller)
	_assert(any_score.is_active, "Any Score can activate a second inventory copy")
	any_score.complete_any_score()

	scorecard.set_score(Scorecard.Section.UPPER, "ones", 1)
	var mulligan := MulliganConsumable.new()
	add_child(mulligan)
	mulligan.apply(game_controller)
	_assert(mulligan.apply_succeeded, "Mulligan applies its first copy")
	mulligan.apply_succeeded = true
	mulligan.apply(game_controller)
	_assert(mulligan.apply_succeeded, "Mulligan applies its second copy")

	var reroll := ScoreRerollConsumable.new()
	add_child(reroll)
	game_controller.active_consumables["score_reroll"] = reroll
	game_controller.consumable_counts["score_reroll"] = 1
	_assert(game_controller._on_consumable_used("score_reroll"), "Score Reroll applies through GameController")
	_assert(is_instance_valid(game_controller._score_reroll_instance),
		"GameController retains the reroll instance after inventory removal")
	game_controller._on_score_rerolled(Scorecard.Section.UPPER, "ones", 1)
	_assert(not reroll.is_active and game_controller._score_reroll_instance == null,
		"Reroll completion reaches the retained instance")
	game_controller.active_consumables["score_reroll"] = reroll
	game_controller.consumable_counts["score_reroll"] = 1
	_assert(game_controller._on_consumable_used("score_reroll"), "Score Reroll accepts a second copy")
	game_controller._on_score_rerolled(Scorecard.Section.UPPER, "ones", 1)

	var double_existing := DoubleExistingConsumable.new()
	add_child(double_existing)
	game_controller.active_consumables["double_existing"] = double_existing
	game_controller.consumable_counts["double_existing"] = 1
	_assert(game_controller._on_consumable_used("double_existing"), "Double Existing applies through GameController")
	_assert(is_instance_valid(game_controller._double_existing_instance),
		"GameController retains the double instance after inventory removal")
	game_controller._on_score_doubled(Scorecard.Section.UPPER, "ones", 2)
	_assert(not double_existing.is_active and game_controller._double_existing_instance == null,
		"Double completion reaches the retained instance")
	game_controller.active_consumables["double_existing"] = double_existing
	game_controller.consumable_counts["double_existing"] = 1
	_assert(game_controller._on_consumable_used("double_existing"), "Double Existing accepts a second copy")
	game_controller._on_score_doubled(Scorecard.Section.UPPER, "ones", 2)
	scorecard.reset_scores()


func _test_paint_job_reapplication() -> void:
	var die := BareDice.new()
	die.color = DiceColor.Type.BLUE
	dice_hand.dice_list.append(die)
	var consumable := PaintJobConsumable.new()
	add_child(consumable)
	consumable.apply(game_controller)
	consumable.apply_succeeded = true
	consumable.apply(game_controller)
	_assert(consumable._saved_colors.get(die) == DiceColor.Type.BLUE,
		"Repeated Paint Job uses preserve the original color")
	consumable._on_roll_complete()
	_assert(die.color == DiceColor.Type.BLUE, "Paint Job restores the original color after two uses")
	_assert(not consumable.is_active, "Paint Job still disarms after its next roll")
	dice_hand.dice_list.clear()
	die.free()


func _test_additive_only_amplifier() -> void:
	ScoreModifierManager.register_additive("test_additive", 10)
	ScoreModifierManager.register_multiplier("test_regular_multiplier", 3.0)
	var consumable := ScoreAmplifierConsumable.new()
	add_child(consumable)
	consumable.apply(game_controller)
	_assert(consumable.apply_succeeded, "Score Amplifier arms with an additive present")
	_assert(ScoreModifierManager.get_total_additive_multiplier() == 2.0,
		"Score Amplifier registers a 2x additive multiplier")
	_assert(ScoreModifierManager.get_total_multiplier() == 3.0,
		"Score Amplifier leaves the regular multiplier unchanged")
	var score: int = scorecard.calculate_score("chance", [1, 2, 3, 4, 5])
	_assert(score == 105, "Base 15 plus doubled additive 20, then regular 3x, scores 105")
	scorecard.set_score(Scorecard.Section.LOWER, "chance", score)
	_assert(not ScoreModifierManager.has_additive_multiplier(ScoreAmplifierConsumable.MODIFIER_SOURCE),
		"Score Amplifier disarms after scoring")
	var second_score: int = scorecard.calculate_score("chance", [1, 2, 3, 4, 5])
	_assert(second_score == 75, "The next score returns to base 15 plus additive 10, times 3")
	ScoreModifierManager.unregister_additive("test_additive")
	consumable.apply_succeeded = true
	consumable.apply(game_controller)
	_assert(not consumable.apply_succeeded, "Score Amplifier rejects use without additives")
	ScoreModifierManager.unregister_multiplier("test_regular_multiplier")
	scorecard.reset_scores()


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("[ConsumableLifecycleRegression] PASS: %s" % message)
	else:
		_fail_count += 1
		push_error("[ConsumableLifecycleRegression] FAIL: %s" % message)
