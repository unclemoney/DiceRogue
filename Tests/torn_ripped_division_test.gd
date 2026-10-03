extends Node

## torn_ripped_division_test.gd
##
## Validates the Torn Scorecard and Ripped POGs debuffs plus the HARD-mode
## pool gate on The Division:
## - Torn Scorecard: scorecard category levels divide instead of multiply
##   (level 1 unaffected, other factors still multiply).
## - Ripped POGs: PowerUp-registered multipliers divide; purple/blue dice
##   multipliers still multiply.
## - Regression: full division mode still flips all four factors.
## - HARD gate: the_division is excluded from DebuffManager and Mom pools in
##   EASY and eligible in HARD.
##
## Run headless:
##   godot --headless --path . Tests/TornRippedDivisionTest.tscn -- --quit-after
## Exit code 0 = all checks passed, 1 = at least one failure.

const ScorecardScript := preload("res://Scenes/ScoreCard/score_card.gd")
const DiceColorClass := preload("res://Scripts/Core/dice_color.gd")

var _failures: int = 0
var _scorecard: Scorecard
var _dice_hand: FakeDiceHand


class FakeDiceHand extends Node:
	var dice_list: Array[Dice] = []

	func _ready() -> void:
		add_to_group("dice_hand")

	func get_all_dice() -> Array:
		return dice_list


func _ready() -> void:
	print("[TornRippedDivisionTest] Starting")
	_check("ScoreModifierManager autoload available", ScoreModifierManager != null)
	_check("DiceColorManager autoload available", DiceColorManager != null)
	_check("GameSettings autoload available", GameSettings != null)

	_setup_fixture()
	await get_tree().process_frame

	_test_torn_scorecard_level_divides()
	_test_torn_scorecard_level_one_unaffected()
	_test_torn_scorecard_powerup_still_multiplies()
	_test_ripped_pogs_powerup_divides()
	_test_ripped_pogs_blue_still_multiplies()
	_test_ripped_pogs_purple_still_multiplies()
	_test_full_division_regression()
	_test_hard_gate_debuff_manager()
	_test_hard_gate_mom_pool()

	_teardown_fixture()
	await get_tree().process_frame

	if _failures == 0:
		print("[TornRippedDivisionTest] PASS - all checks passed")
	else:
		print("[TornRippedDivisionTest] FAIL - %d check(s) failed" % _failures)

	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(0 if _failures == 0 else 1)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[TornRippedDivisionTest] OK: " + label)
	else:
		push_error("[TornRippedDivisionTest] FAILED: " + label)
		_failures += 1


func _setup_fixture() -> void:
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
		ScoreModifierManager.set_level_division_mode(false)
		ScoreModifierManager.set_powerup_division_mode(false)

	if GameSettings:
		GameSettings.set_difficulty_mode(GameSettings.DifficultyMode.EASY)

	for category in _scorecard.upper_levels.keys():
		_scorecard.upper_levels[category] = 1
	for category in _scorecard.lower_levels.keys():
		_scorecard.lower_levels[category] = 1

	_set_dice([1, 1, 1, 1, 1], _none_colors())


func _teardown_fixture() -> void:
	_reset_fixture()
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


func _set_category_level(category: String, level: int) -> void:
	if _scorecard.upper_levels.has(category):
		_scorecard.upper_levels[category] = level
	elif _scorecard.lower_levels.has(category):
		_scorecard.lower_levels[category] = level


func _score_case(category: String, values: Array[int], colors: Array, division: bool = false, level_div: bool = false, powerup_div: bool = false, raw_multipliers: Dictionary = {}, level_overrides: Dictionary = {}) -> Dictionary:
	_reset_fixture()
	_set_dice(values, colors)

	for level_category in level_overrides.keys():
		_set_category_level(level_category, int(level_overrides[level_category]))

	for source_name in raw_multipliers.keys():
		ScoreModifierManager.register_multiplier(source_name, float(raw_multipliers[source_name]))

	ScoreModifierManager.set_division_mode(division)
	ScoreModifierManager.set_level_division_mode(level_div)
	ScoreModifierManager.set_powerup_division_mode(powerup_div)
	return _scorecard.calculate_score_with_breakdown(category, values, false)


func _check_score(label: String, result: Dictionary, expected_score: int) -> void:
	var actual_score = int(result.get("final_score", -1))
	_check(label + " score", actual_score == expected_score)


func _test_torn_scorecard_level_divides() -> void:
	var values: Array[int] = [5, 5, 1, 1, 1]
	var levels = {"fives": 3}

	var normal_result = _score_case("fives", values, _none_colors(), false, false, false, {}, levels)
	_check_score("torn: level 3 without debuff (10x3=30)", normal_result, 30)

	var torn_result = _score_case("fives", values, _none_colors(), false, true, false, {}, levels)
	_check_score("torn: level 3 divides (10/3=3)", torn_result, 3)
	var info: Dictionary = torn_result.get("breakdown_info", {})
	_check("torn: category level operator flips to divide", info.get("category_level_display_operator", "") == "÷")
	_check("torn: category level display value is 3.0", is_equal_approx(float(info.get("category_level_display_value", 0.0)), 3.0))


func _test_torn_scorecard_level_one_unaffected() -> void:
	var values: Array[int] = [1, 2, 3, 4, 5]

	var torn_result = _score_case("chance", values, _none_colors(), false, true, false)
	_check_score("torn: level 1 category unchanged (15/1=15)", torn_result, 15)
	var info: Dictionary = torn_result.get("breakdown_info", {})
	_check("torn: level 1 operator stays neutral", info.get("category_level_display_operator", "") == "×")


func _test_torn_scorecard_powerup_still_multiplies() -> void:
	var values: Array[int] = [5, 5, 1, 1, 1]
	var levels = {"fives": 3}
	var raw_multipliers = {"powerup_test_mult": 2.0}

	var torn_result = _score_case("fives", values, _none_colors(), false, true, false, raw_multipliers, levels)
	_check_score("torn: powerup x2 still multiplies (10/3x2=6)", torn_result, 6)
	var info: Dictionary = torn_result.get("breakdown_info", {})
	_check("torn: regular multiplier operator stays multiply", info.get("regular_multiplier_display_operator", "") == "×")


func _test_ripped_pogs_powerup_divides() -> void:
	var values: Array[int] = [1, 2, 3, 4, 5]
	var raw_multipliers = {"powerup_test_mult": 3.0}

	var normal_result = _score_case("chance", values, _none_colors(), false, false, false, raw_multipliers)
	_check_score("ripped: powerup x3 without debuff (15x3=45)", normal_result, 45)

	var ripped_result = _score_case("chance", values, _none_colors(), false, false, true, raw_multipliers)
	_check_score("ripped: powerup x3 divides (15/3=5)", ripped_result, 5)
	var info: Dictionary = ripped_result.get("breakdown_info", {})
	_check("ripped: regular multiplier operator flips to divide", info.get("regular_multiplier_display_operator", "") == "÷")
	_check("ripped: regular multiplier display value is 3.0", is_equal_approx(float(info.get("regular_multiplier_display_value", 0.0)), 3.0))


func _test_ripped_pogs_blue_still_multiplies() -> void:
	var values: Array[int] = [4, 4, 4, 4, 4]
	var colors = [DiceColorClass.Type.BLUE, DiceColorClass.Type.NONE, DiceColorClass.Type.NONE, DiceColorClass.Type.NONE, DiceColorClass.Type.NONE]
	var raw_multipliers = {"powerup_test_mult": 2.0}

	var ripped_result = _score_case("chance", values, colors, false, false, true, raw_multipliers)
	_check_score("ripped: blue x4 still multiplies (20/2x4=40)", ripped_result, 40)
	var info: Dictionary = ripped_result.get("breakdown_info", {})
	_check("ripped: blue operator stays multiply", info.get("blue_score_multiplier_display_operator", "") == "×")
	_check("ripped: blue display value is 4.0", is_equal_approx(float(info.get("blue_score_multiplier_display_value", 0.0)), 4.0))


func _test_ripped_pogs_purple_still_multiplies() -> void:
	var values: Array[int] = [1, 2, 3, 4, 5]
	var colors = [DiceColorClass.Type.PURPLE, DiceColorClass.Type.NONE, DiceColorClass.Type.NONE, DiceColorClass.Type.NONE, DiceColorClass.Type.NONE]

	var ripped_result = _score_case("chance", values, colors, false, false, true)
	_check_score("ripped: purple x2 still multiplies (15x2=30)", ripped_result, 30)
	var info: Dictionary = ripped_result.get("breakdown_info", {})
	_check("ripped: purple operator stays multiply", info.get("dice_color_multiplier_display_operator", "") == "×")


func _test_full_division_regression() -> void:
	var values: Array[int] = [5, 5, 4, 1, 1]
	var colors = [DiceColorClass.Type.PURPLE, DiceColorClass.Type.NONE, DiceColorClass.Type.BLUE, DiceColorClass.Type.NONE, DiceColorClass.Type.NONE]
	var raw_multipliers = {"division_test_regular": 3.0}
	var levels = {"fives": 2}

	var normal_result = _score_case("fives", values, colors, false, false, false, raw_multipliers, levels)
	_check_score("regression: mixed stack without division (30)", normal_result, 30)

	var division_result = _score_case("fives", values, colors, true, false, false, raw_multipliers, levels)
	_check_score("regression: mixed stack with division (3)", division_result, 3)
	var info: Dictionary = division_result.get("breakdown_info", {})
	_check("regression: level operator flips", info.get("category_level_display_operator", "") == "÷")
	_check("regression: regular operator flips", info.get("regular_multiplier_display_operator", "") == "÷")
	_check("regression: purple operator flips", info.get("dice_color_multiplier_display_operator", "") == "÷")
	_check("regression: blue operator flips", info.get("blue_score_multiplier_display_operator", "") == "×")


func _make_test_debuff_manager() -> DebuffManager:
	var manager := DebuffManager.new()
	var defs: Array[DebuffData] = []

	var division_def := DebuffData.new()
	division_def.id = "the_division"
	division_def.difficulty_rating = 5
	defs.append(division_def)

	var torn_def := DebuffData.new()
	torn_def.id = "torn_scorecard"
	torn_def.difficulty_rating = 4
	defs.append(torn_def)

	var ripped_def := DebuffData.new()
	ripped_def.id = "ripped_pogs"
	ripped_def.difficulty_rating = 4
	defs.append(ripped_def)

	manager.debuff_defs = defs
	add_child(manager)  # triggers _ready -> _load_definitions
	return manager


func _def_ids(defs: Array[DebuffData]) -> Array[String]:
	var ids: Array[String] = []
	for def in defs:
		ids.append(def.id)
	return ids


func _test_hard_gate_debuff_manager() -> void:
	_reset_fixture()
	var manager := _make_test_debuff_manager()

	# EASY: the_division excluded, both new debuffs included
	GameSettings.set_difficulty_mode(GameSettings.DifficultyMode.EASY)
	var easy_ids := _def_ids(manager.get_debuffs_by_difficulty(5))
	_check("gate: EASY pool excludes the_division", "the_division" not in easy_ids)
	_check("gate: EASY pool includes torn_scorecard", "torn_scorecard" in easy_ids)
	_check("gate: EASY pool includes ripped_pogs", "ripped_pogs" in easy_ids)

	var boss_hit_division := false
	for _i in range(20):
		if manager.select_boss_debuff(5) == "the_division":
			boss_hit_division = true
	_check("gate: EASY boss draw (20x) never returns the_division", not boss_hit_division)

	# HARD: all three eligible; boss level 5 draw returns the_division
	GameSettings.set_difficulty_mode(GameSettings.DifficultyMode.HARD)
	var hard_ids := _def_ids(manager.get_debuffs_by_difficulty(5))
	_check("gate: HARD pool includes the_division", "the_division" in hard_ids)
	_check("gate: HARD pool includes torn_scorecard", "torn_scorecard" in hard_ids)
	_check("gate: HARD pool includes ripped_pogs", "ripped_pogs" in hard_ids)
	manager.reset_zone_pool()
	_check("gate: HARD boss draw returns the_division", manager.select_boss_debuff(5) == "the_division")

	GameSettings.set_difficulty_mode(GameSettings.DifficultyMode.EASY)
	manager.queue_free()


func _test_hard_gate_mom_pool() -> void:
	_reset_fixture()

	# EASY: Mom never draws the_division, but can draw the new debuffs
	GameSettings.set_difficulty_mode(GameSettings.DifficultyMode.EASY)
	var easy_draws := {}
	for _i in range(200):
		easy_draws[MomLogicHandler._get_random_non_active_debuff({}, [])] = true
	_check("gate: Mom EASY never draws the_division (200x)", not easy_draws.has("the_division"))
	_check("gate: Mom EASY can draw torn_scorecard", easy_draws.has("torn_scorecard"))
	_check("gate: Mom EASY can draw ripped_pogs", easy_draws.has("ripped_pogs"))

	# HARD: the_division is eligible again
	GameSettings.set_difficulty_mode(GameSettings.DifficultyMode.HARD)
	var hard_draws := {}
	for _i in range(200):
		hard_draws[MomLogicHandler._get_random_non_active_debuff({}, [])] = true
	_check("gate: Mom HARD can draw the_division", hard_draws.has("the_division"))

	GameSettings.set_difficulty_mode(GameSettings.DifficultyMode.EASY)
