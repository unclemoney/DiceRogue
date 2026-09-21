extends Node

## difficulty_mode_test.gd
##
## Validates the GameSettings difficulty-mode feature: in HARD mode a zero base
## score "scratches" the hand — all additive and multiplier bonuses (including
## dice-color score effects) are voided and the final score is 0. EASY mode is
## legacy behavior. Also covers bend PowerUps running before the scratch gate,
## the preserved auto-scoring path, mid-run toggling, trigger-on-nonzero
## PowerUps reading the final score, and debug_simulate_score purity.
##
## Run headless:
##   godot --headless --path . Tests/DifficultyModeTest.tscn -- --quit-after
## Exit code 0 = all checks passed, 1 = at least one failure.

const ScorecardScript := preload("res://Scenes/ScoreCard/score_card.gd")
const DiceColorClass := preload("res://Scripts/Core/dice_color.gd")
const HotStreakScene := preload("res://Scenes/PowerUp/HotStreakPowerUp.tscn")
const Chance520Scene := preload("res://Scenes/PowerUp/Chance520PowerUp.tscn")
const FullHouseScene := preload("res://Scenes/PowerUp/FullHousePowerUp.tscn")
const PlusTheLastScene := preload("res://Scenes/PowerUp/PlusTheLast.tscn")
const SweetSixteenScene := preload("res://Scenes/PowerUp/SweetSixteen.tscn")

var _failures: int = 0
var _scorecard: Scorecard
var _dice_hand: FakeDiceHand
var _money_start: int = 0


class FakeDiceHand extends Node:
	var dice_list: Array[Dice] = []

	func _ready() -> void:
		add_to_group("dice_hand")

	func get_all_dice() -> Array:
		return dice_list


func _ready() -> void:
	print("[DifficultyModeTest] Starting")
	_check("GameSettings autoload available", GameSettings != null)
	_check("ScoreModifierManager autoload available", ScoreModifierManager != null)
	_check("DiceColorManager autoload available", DiceColorManager != null)

	_setup_fixture()
	await get_tree().process_frame

	_test_default_mode_is_easy()
	_test_hard_scratch_voids_bonuses()
	_test_easy_zero_base_keeps_bonuses()
	_test_hard_nonzero_base_stacks()
	_test_colored_dice_under_scratch()
	_test_bend_rescue_not_scratched()
	_test_preserved_path_matches_manual()
	_test_mid_run_toggle()
	_test_hot_streak_trigger()
	_test_chance520_trigger()
	_test_full_house_fortune_trigger()
	_test_echoes_trigger()
	_test_sweet_sixteen_trigger()
	_test_debug_simulate_score()

	_teardown_fixture()
	await get_tree().process_frame

	if _failures == 0:
		print("[DifficultyModeTest] PASS - all checks passed")
	else:
		print("[DifficultyModeTest] FAIL - %d check(s) failed" % _failures)

	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(0 if _failures == 0 else 1)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[DifficultyModeTest] OK: " + label)
	else:
		push_error("[DifficultyModeTest] FAILED: " + label)
		_failures += 1


func _setup_fixture() -> void:
	_money_start = PlayerEconomy.money

	_scorecard = ScorecardScript.new()
	add_child(_scorecard)
	DiceResults.set_scorecard(_scorecard)

	_dice_hand = FakeDiceHand.new()
	add_child(_dice_hand)

	for _i in range(5):
		var die := Dice.new()
		_dice_hand.dice_list.append(die)

	_reset_fixture()


func _reset_fixture() -> void:
	if ScoreModifierManager:
		ScoreModifierManager.reset()
		ScoreModifierManager.set_division_mode(false)

	if GameSettings:
		GameSettings.set_difficulty_mode(GameSettings.DifficultyMode.EASY)

	_scorecard.allow_two_pair_full_house = false

	for category in _scorecard.upper_levels.keys():
		_scorecard.upper_levels[category] = 1
	for category in _scorecard.lower_levels.keys():
		_scorecard.lower_levels[category] = 1

	var default_values: Array[int] = [1, 1, 1, 1, 1]
	_set_dice(default_values, _none_colors())
	DiceResults.update_from_dice(_dice_hand.dice_list)


func _teardown_fixture() -> void:
	_reset_fixture()
	GameSettings.set_difficulty_mode(GameSettings.DifficultyMode.EASY)
	PlayerEconomy.money = _money_start
	DiceResults.reset()
	DiceResults.set_scorecard(null)
	for die in _dice_hand.dice_list:
		if is_instance_valid(die):
			die.free()
	_dice_hand.dice_list.clear()
	if is_instance_valid(_dice_hand):
		_dice_hand.queue_free()
	if is_instance_valid(_scorecard):
		_scorecard.queue_free()


func _set_dice(values: Array[int], colors: Array) -> void:
	for i in range(_dice_hand.dice_list.size()):
		var die = _dice_hand.dice_list[i]
		die.value = values[i]
		die.color = colors[i]
	DiceResults.update_from_dice(_dice_hand.dice_list)


func _none_colors() -> Array:
	return [
		DiceColorClass.Type.NONE,
		DiceColorClass.Type.NONE,
		DiceColorClass.Type.NONE,
		DiceColorClass.Type.NONE,
		DiceColorClass.Type.NONE,
	]


func _score_case(category: String, values: Array[int], colors: Array, hard_mode: bool, additives: Dictionary = {}, multipliers: Dictionary = {}) -> Dictionary:
	_reset_fixture()
	_set_dice(values, colors)

	if hard_mode:
		GameSettings.set_difficulty_mode(GameSettings.DifficultyMode.HARD)

	for source_name in additives.keys():
		ScoreModifierManager.register_additive(source_name, int(additives[source_name]))
	for source_name in multipliers.keys():
		ScoreModifierManager.register_multiplier(source_name, float(multipliers[source_name]))

	return _scorecard.calculate_score_with_breakdown(category, values, false)


func _check_sources_voided(info: Dictionary, expect_voided: bool) -> void:
	var additive_sources: Array = info.get("additive_sources", [])
	var multiplier_sources: Array = info.get("multiplier_sources", [])
	_check("breakdown has %d additive source(s)" % additive_sources.size(), additive_sources.size() > 0)
	_check("breakdown has %d multiplier source(s)" % multiplier_sources.size(), multiplier_sources.size() > 0)
	for entry in additive_sources:
		_check("additive source '%s' voided == %s" % [entry.get("name", "?"), str(expect_voided)], entry.get("voided", false) == expect_voided)
	for entry in multiplier_sources:
		_check("multiplier source '%s' voided == %s" % [entry.get("name", "?"), str(expect_voided)], entry.get("voided", false) == expect_voided)


func _free_power_up(power_up) -> void:
	if power_up and power_up.has_method("remove"):
		power_up.remove(_scorecard)
	if is_instance_valid(power_up):
		power_up.queue_free()


func _test_default_mode_is_easy() -> void:
	_reset_fixture()
	_check("default mode is not HARD", GameSettings.is_hard_mode() == false)
	_check("default mode is EASY enum", GameSettings.get_difficulty_mode() == GameSettings.DifficultyMode.EASY)
	_check("default mode name is 'easy'", GameSettings.get_difficulty_mode_name() == "easy")


func _test_hard_scratch_voids_bonuses() -> void:
	var values: Array[int] = [2, 3, 4, 5, 6]
	var result = _score_case("ones", values, _none_colors(), true, {"step_by_step": 6}, {"upper_crust": 1.5})
	_check("HARD zero-base final is 0", int(result.get("final_score", -1)) == 0)

	var info: Dictionary = result.get("breakdown_info", {})
	_check("HARD scratch_applied flag set", info.get("scratch_applied", false) == true)
	_check("HARD breakdown reports difficulty 'hard'", info.get("difficulty_mode", "") == "hard")
	_check("HARD scratch keeps base 0", int(info.get("base_score", -1)) == 0)
	_check_sources_voided(info, true)


func _test_easy_zero_base_keeps_bonuses() -> void:
	var values: Array[int] = [2, 3, 4, 5, 6]
	var result = _score_case("ones", values, _none_colors(), false, {"step_by_step": 6}, {"upper_crust": 1.5})
	_check("EASY zero-base final is (0+6)x1.5 = 9", int(result.get("final_score", -1)) == 9)

	var info: Dictionary = result.get("breakdown_info", {})
	_check("EASY scratch_applied flag clear", info.get("scratch_applied", true) == false)
	_check("EASY breakdown reports difficulty 'easy'", info.get("difficulty_mode", "") == "easy")
	_check_sources_voided(info, false)


func _test_hard_nonzero_base_stacks() -> void:
	var values: Array[int] = [3, 3, 3, 5, 6]
	var result = _score_case("three_of_a_kind", values, _none_colors(), true, {"step_by_step": 10}, {"upper_crust": 2.0})
	_check("HARD nonzero base is 20", int(result.get("breakdown_info", {}).get("base_score", -1)) == 20)
	_check("HARD nonzero base final is (20+10)x2 = 60", int(result.get("final_score", -1)) == 60)
	_check("HARD nonzero base not scratched", result.get("breakdown_info", {}).get("scratch_applied", true) == false)


func _test_colored_dice_under_scratch() -> void:
	var values: Array[int] = [2, 3, 4, 5, 6]
	# three_of_a_kind misses (base 0) but uses ALL dice, so color effects are live.
	var colors = [
		DiceColorClass.Type.NONE,
		DiceColorClass.Type.NONE,
		DiceColorClass.Type.NONE,
		DiceColorClass.Type.PURPLE,
		DiceColorClass.Type.RED,
	]

	var hard_result = _score_case("three_of_a_kind", values, colors, true)
	_check("HARD colored scratch final is 0", int(hard_result.get("final_score", -1)) == 0)
	_check("HARD colored scratch flag set", hard_result.get("breakdown_info", {}).get("scratch_applied", false) == true)

	var easy_result = _score_case("three_of_a_kind", values, colors, false)
	var easy_info: Dictionary = easy_result.get("breakdown_info", {})
	_check("EASY red additive lands (+6)", int(easy_info.get("dice_color_additive", -1)) == 6)
	_check("EASY purple multiplier lands (x2.0)", is_equal_approx(float(easy_info.get("dice_color_multiplier", 0.0)), 2.0))
	_check("EASY colored final is (0+6)x2 = 12", int(easy_result.get("final_score", -1)) == 12)
	_check("EASY colored hand not scratched", easy_info.get("scratch_applied", true) == false)


func _test_bend_rescue_not_scratched() -> void:
	var values: Array[int] = [2, 2, 3, 3, 5]

	# Control: without the bend flag, two pair on full_house is a zero base.
	var control = _score_case("full_house", values, _none_colors(), true, {"step_by_step": 10})
	_check("two pair without bend scratches under HARD", int(control.get("final_score", -1)) == 0)
	_check("control scratch flag set", control.get("breakdown_info", {}).get("scratch_applied", false) == true)

	# Bend runs before the scratch gate: rescued base 25 is not a scratch.
	_reset_fixture()
	_set_dice(values, _none_colors())
	_scorecard.allow_two_pair_full_house = true
	GameSettings.set_difficulty_mode(GameSettings.DifficultyMode.HARD)
	ScoreModifierManager.register_additive("step_by_step", 10)
	var result = _scorecard.calculate_score_with_breakdown("full_house", values, false)
	var info: Dictionary = result.get("breakdown_info", {})
	_check("bend rescues base to 25", int(info.get("base_score", -1)) == 25)
	_check("bend rescue not scratched under HARD", info.get("scratch_applied", true) == false)
	_check("bend rescue final is 25+10 = 35", int(result.get("final_score", -1)) == 35)
	_scorecard.allow_two_pair_full_house = false


func _test_preserved_path_matches_manual() -> void:
	var values: Array[int] = [2, 3, 4, 5, 6]
	var manual_result = _score_case("ones", values, _none_colors(), true, {"step_by_step": 6}, {"upper_crust": 1.5})
	var manual_score = int(manual_result.get("final_score", -1))
	_check("HARD manual scratch final is 0", manual_score == 0)

	var color_capture = _scorecard._capture_color_effects_for_score("ones", values, false)
	var preserved_score = _scorecard._calculate_score_with_preserved_effects("ones", values, false, color_capture.get("effects", {}))
	_check("HARD preserved (auto-score) path also scratches to 0", preserved_score == 0)
	_check("preserved path matches manual under HARD", preserved_score == manual_score)


func _test_mid_run_toggle() -> void:
	var values: Array[int] = [2, 3, 4, 5, 6]
	_reset_fixture()
	_set_dice(values, _none_colors())
	ScoreModifierManager.register_additive("step_by_step", 6)
	ScoreModifierManager.register_multiplier("upper_crust", 1.5)

	var easy_first = _scorecard.calculate_score_with_breakdown("ones", values, false)
	_check("toggle: EASY first lands bonuses (9)", int(easy_first.get("final_score", -1)) == 9)

	GameSettings.set_difficulty_mode(GameSettings.DifficultyMode.HARD)
	var hard_result = _scorecard.calculate_score_with_breakdown("ones", values, false)
	_check("toggle: HARD scratches same hand (0)", int(hard_result.get("final_score", -1)) == 0)
	_check("toggle: HARD scratch flag set", hard_result.get("breakdown_info", {}).get("scratch_applied", false) == true)

	GameSettings.set_difficulty_mode(GameSettings.DifficultyMode.EASY)
	var easy_second = _scorecard.calculate_score_with_breakdown("ones", values, false)
	_check("toggle: EASY again lands bonuses (9)", int(easy_second.get("final_score", -1)) == 9)
	_check("toggle: EASY again scratch flag clear", easy_second.get("breakdown_info", {}).get("scratch_applied", true) == false)


func _test_hot_streak_trigger() -> void:
	var values: Array[int] = [2, 3, 4, 5, 6]
	_reset_fixture()
	_set_dice(values, _none_colors())
	GameSettings.set_difficulty_mode(GameSettings.DifficultyMode.HARD)

	var power_up = HotStreakScene.instantiate()
	add_child(power_up)
	power_up.apply(_scorecard)

	# Simulated scratch: final 0 is what score_assigned reports on a scratched hand.
	var breakdown = _scorecard.calculate_score_with_breakdown("ones", values, false)
	_check("hot streak: HARD hand scratches", int(breakdown.get("final_score", -1)) == 0)
	_scorecard.set_score(Scorecard.Section.UPPER, "ones", 0)
	_check("hot streak: scratched 0 does not grow streak", power_up.streak_count == 0)
	_check("hot streak: no additive registered after scratch", not ScoreModifierManager.has_additive("hot_streak"))

	GameSettings.set_difficulty_mode(GameSettings.DifficultyMode.EASY)
	_scorecard.set_score(Scorecard.Section.LOWER, "chance", 25)
	_check("hot streak: EASY 25 grows streak to 1", power_up.streak_count == 1)
	_check("hot streak: additive +3 registered", ScoreModifierManager.get_additive("hot_streak") == 3)

	_free_power_up(power_up)
	_reset_fixture()


func _test_chance520_trigger() -> void:
	_reset_fixture()
	GameSettings.set_difficulty_mode(GameSettings.DifficultyMode.HARD)

	var power_up = Chance520Scene.instantiate()
	add_child(power_up)
	power_up.apply(_scorecard)

	# Simulated scratch on Chance.
	_scorecard.set_score(Scorecard.Section.LOWER, "chance", 0)
	_check("chance520: scratched Chance does not stack", power_up.bonus_count == 0)

	GameSettings.set_difficulty_mode(GameSettings.DifficultyMode.EASY)
	_scorecard.set_score(Scorecard.Section.LOWER, "chance", 25)
	_check("chance520: EASY Chance 25 stacks once", power_up.bonus_count == 1)
	_check("chance520: additive +5 registered", ScoreModifierManager.get_additive("chance520") == 5)

	_free_power_up(power_up)
	_reset_fixture()


func _test_full_house_fortune_trigger() -> void:
	var values: Array[int] = [2, 2, 3, 3, 3]
	_reset_fixture()
	_set_dice(values, _none_colors())
	GameSettings.set_difficulty_mode(GameSettings.DifficultyMode.HARD)

	var power_up = FullHouseScene.instantiate()
	add_child(power_up)
	power_up.apply(_scorecard)
	_check("full house fortune: found scorecard via group", power_up.scorecard_ref == _scorecard)

	# Simulated scratch: full house dice on the table but final score 0.
	var money_before = PlayerEconomy.money
	_scorecard.set_score(Scorecard.Section.LOWER, "full_house", 0)
	_check("full house fortune: scratch pays nothing", PlayerEconomy.money == money_before)
	_check("full house fortune: scratch does not count full house", power_up.total_full_houses_earned == 0)

	GameSettings.set_difficulty_mode(GameSettings.DifficultyMode.EASY)
	_scorecard.set_score(Scorecard.Section.LOWER, "full_house", 25)
	_check("full house fortune: EASY full house pays $7", PlayerEconomy.money == money_before + 7)
	_check("full house fortune: EASY full house counted", power_up.total_full_houses_earned == 1)

	_free_power_up(power_up)
	_reset_fixture()


func _test_echoes_trigger() -> void:
	_reset_fixture()
	GameSettings.set_difficulty_mode(GameSettings.DifficultyMode.HARD)

	var power_up = PlusTheLastScene.instantiate()
	add_child(power_up)
	# apply() also wires ScoreCardUI's about_to_score via GameController; that
	# node does not exist headless, so only the score_assigned tracking half is
	# connected — which is the half under test.
	power_up.apply(_scorecard)

	_scorecard.set_score(Scorecard.Section.UPPER, "threes", 0)
	_check("echoes: scratched score stores last score 0", power_up.last_scored_value == 0)

	GameSettings.set_difficulty_mode(GameSettings.DifficultyMode.EASY)
	_scorecard.set_score(Scorecard.Section.LOWER, "chance", 25)
	_check("echoes: EASY nonzero score stores 25", power_up.last_scored_value == 25)

	_free_power_up(power_up)
	_reset_fixture()


func _test_sweet_sixteen_trigger() -> void:
	_reset_fixture()
	GameSettings.set_difficulty_mode(GameSettings.DifficultyMode.HARD)

	var power_up = SweetSixteenScene.instantiate()
	add_child(power_up)
	# NOTE: apply() needs GameController.turn_tracker, which does not exist
	# headless, so the turn/score handlers are driven directly instead.
	power_up._on_turn_updated(16)
	_check("sweet sixteen: turn 16 grants $16", power_up.total_earned == 16)

	# Scratched (0) score on turn 16: no $256 bonus.
	var money_before = PlayerEconomy.money
	power_up._on_score_assigned(Scorecard.Section.LOWER, "ones", 0)
	_check("sweet sixteen: scratched turn-16 score pays no bonus", PlayerEconomy.money == money_before)
	_check("sweet sixteen: bonus not awarded after scratch", power_up._turn_16_bonus_awarded == false)

	# Nonzero EASY score on turn 16: bonus lands.
	GameSettings.set_difficulty_mode(GameSettings.DifficultyMode.EASY)
	power_up._on_score_assigned(Scorecard.Section.LOWER, "ones", 25)
	_check("sweet sixteen: EASY turn-16 score pays $256", PlayerEconomy.money == money_before + 256)
	_check("sweet sixteen: bonus awarded", power_up._turn_16_bonus_awarded == true)
	_check("sweet sixteen: total earned 16+256 = 272", power_up.total_earned == 272)

	_free_power_up(power_up)
	_reset_fixture()


func _test_debug_simulate_score() -> void:
	var values: Array[int] = [2, 3, 4, 5, 6]
	var colors = [
		DiceColorClass.Type.GREEN,
		DiceColorClass.Type.NONE,
		DiceColorClass.Type.NONE,
		DiceColorClass.Type.NONE,
		DiceColorClass.Type.NONE,
	]
	_reset_fixture()
	_set_dice(values, colors)
	GameSettings.set_difficulty_mode(GameSettings.DifficultyMode.HARD)

	var money_before = PlayerEconomy.money
	var info = _scorecard.debug_simulate_score("ones", values)
	_check("debug_simulate_score returns non-empty dict", info is Dictionary and not info.is_empty())
	_check("debug_simulate_score has base_score key", info.has("base_score"))
	_check("debug_simulate_score has final_score key", info.has("final_score"))
	_check("debug_simulate_score has scratch_applied key", info.has("scratch_applied"))
	_check("debug_simulate_score base is 0", int(info.get("base_score", -1)) == 0)
	_check("debug_simulate_score final is 0 under HARD", int(info.get("final_score", -1)) == 0)
	_check("debug_simulate_score scratch flag set", info.get("scratch_applied", false) == true)
	_check("debug_simulate_score reports difficulty 'hard'", info.get("difficulty_mode", "") == "hard")
	_check("debug_simulate_score causes no money change (green die present)", PlayerEconomy.money == money_before)
