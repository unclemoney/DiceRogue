extends Control
class_name ConsumableUsageWindowTest

## consumable_usage_window_test.gd
##
## Verifies the ConsumableData.UsageWindow -> GameController.GamePhase mapping
## used by the data-driven consumable usability check:
## 1. ANY_TIME is usable in every phase.
## 2. BEFORE_ROLL_INITIATED is usable only in IDLE.
## 3. DURING_ACTIVE_ROUND is usable only in ROUND_ACTIVE.
## 4. AFTER_SCORING is usable only in AFTER_SCORE.
## 5. Defaults keep un-migrated resources usable (ANY_TIME, empty sets).
## 6. Migrated anchor .tres files carry their intended windows/conditions.
##
## Run headless with `-- --auto-test` to run the suite and quit with an
## exit code (0 = pass, 1 = fail).

var _fail_count := 0
var _test_completed := false


class BareConsumableUI extends ConsumableUI:
	func _ready() -> void:
		pass


class BareShopItem extends ShopItem:
	func _ready() -> void:
		pass


class BareGameController extends GameController:
	var refresh_count: int = 0

	func _ready() -> void:
		pass

	func _refresh_shop_prices() -> void:
		refresh_count += 1

func _ready() -> void:
	print("=== Consumable Usage Window Test ===")
	_run_tests()
	_test_completed = true
	if "--auto-test" in OS.get_cmdline_user_args():
		_quit_with_result()
	elif DisplayServer.get_name() == "headless":
		_quit_with_result()

func _run_tests() -> void:
	var phases := {
		"IDLE": GameController.GamePhase.IDLE,
		"ROUND_ACTIVE": GameController.GamePhase.ROUND_ACTIVE,
		"AFTER_SCORE": GameController.GamePhase.AFTER_SCORE,
	}

	print("--- Window x Phase matrix ---")
	var expectations := {
		ConsumableData.UsageWindow.ANY_TIME: {"IDLE": true, "ROUND_ACTIVE": true, "AFTER_SCORE": true},
		ConsumableData.UsageWindow.BEFORE_ROLL_INITIATED: {"IDLE": true, "ROUND_ACTIVE": false, "AFTER_SCORE": false},
		ConsumableData.UsageWindow.DURING_ACTIVE_ROUND: {"IDLE": false, "ROUND_ACTIVE": true, "AFTER_SCORE": false},
		ConsumableData.UsageWindow.AFTER_SCORING: {"IDLE": false, "ROUND_ACTIVE": false, "AFTER_SCORE": true},
	}
	for window in expectations.keys():
		var data := ConsumableData.new()
		data.usage_window = window
		var window_name: String = ConsumableData.UsageWindow.keys()[window]
		for phase_name in phases.keys():
			var expected: bool = expectations[window][phase_name]
			_assert_equals(data.is_usable_in_phase(phases[phase_name]), expected,
				"%s in %s" % [window_name, phase_name])

	print("--- Defaults keep un-migrated resources usable ---")
	var fresh := ConsumableData.new()
	_assert_equals(fresh.usage_window, ConsumableData.UsageWindow.ANY_TIME, "default usage_window is ANY_TIME")
	_assert(fresh.allowed_dice_sets.is_empty(), "default allowed_dice_sets is empty")
	_assert(fresh.is_available_for_dice_sides(4), "fresh data available for d4")
	_assert(fresh.is_available_for_dice_sides(6), "fresh data available for d6")
	_assert(fresh.is_usable_in_phase(GameController.GamePhase.IDLE), "fresh data usable in IDLE")

	print("--- Migrated anchor resources ---")
	var go_broke := preload("res://Scripts/Consumable/GoBrokeOrGoHomeConsumable.tres") as ConsumableData
	_assert_equals(go_broke.usage_window, ConsumableData.UsageWindow.BEFORE_ROLL_INITIATED,
		"go_broke_or_go_home is BEFORE_ROLL_INITIATED")
	_assert(go_broke.usage_conditions.has(&"open_lower_category"),
		"go_broke_or_go_home keeps open_lower_category condition")
	var visit_shop := preload("res://Scripts/Consumable/VisitTheShopConsumable.tres") as ConsumableData
	_assert_equals(visit_shop.usage_window, ConsumableData.UsageWindow.AFTER_SCORING,
		"visit_the_shop is AFTER_SCORING")
	var mulligan := preload("res://Scripts/Consumable/MulliganConsumable.tres") as ConsumableData
	_assert_equals(mulligan.usage_window, ConsumableData.UsageWindow.DURING_ACTIVE_ROUND,
		"mulligan is DURING_ACTIVE_ROUND")
	_assert(mulligan.usage_conditions.has(&"dice_rolled") and mulligan.usage_conditions.has(&"has_placed_score"),
		"mulligan keeps dice_rolled + has_placed_score conditions")
	_test_live_usability_gates()
	_test_go_broke_raw_scoring()
	_test_challenge_icon_assets()

	var result_text := "PASS"
	if _fail_count > 0:
		result_text = "FAIL"
	print("=== Usage Window Test Complete: %s ===" % result_text)

func _test_live_usability_gates() -> void:
	var game_controller := BareGameController.new()
	add_child(game_controller)
	game_controller.add_to_group("game_controller")
	var round_manager := RoundManager.new()
	game_controller.add_child(round_manager)
	game_controller.round_manager = round_manager
	round_manager.game_started = true
	var turn_tracker := TurnTracker.new()
	game_controller.add_child(turn_tracker)
	game_controller.turn_tracker = turn_tracker
	turn_tracker.is_active = false
	var consumable_ui := BareConsumableUI.new()
	add_child(consumable_ui)

	var expansion := ConsumableData.new()
	expansion.id = "power_up_shop_num"
	expansion.usage_window = ConsumableData.UsageWindow.ANY_TIME
	_assert(consumable_ui._can_use_consumable(expansion), "Shop Expansion works between rounds")
	game_controller._game_ended = true
	_assert(not consumable_ui._can_use_consumable(expansion), "Shop Expansion is blocked after game over")
	game_controller._game_ended = false

	var surge := ConsumableData.new()
	surge.id = "dice_surge"
	surge.usage_window = ConsumableData.UsageWindow.ANY_TIME
	_assert(not consumable_ui._can_use_consumable(surge), "Dice Surge is blocked between rounds")
	turn_tracker.is_active = true
	game_controller.current_phase = GameController.GamePhase.IDLE
	_assert(consumable_ui._can_use_consumable(surge), "Dice Surge works before first roll")
	game_controller.current_phase = GameController.GamePhase.ROUND_ACTIVE
	_assert(consumable_ui._can_use_consumable(surge), "Dice Surge works after first roll")

	var loss_leader := LossLeaderConsumable.new()
	add_child(loss_leader)
	var stacks_before: int = game_controller.loss_leader_stacks
	loss_leader.apply(game_controller)
	_assert(game_controller.loss_leader_stacks == stacks_before + 1, "Loss Leader adds one free purchase")
	_assert(game_controller.refresh_count == 1, "Loss Leader refreshes open-shop prices immediately")
	var shop_item := BareShopItem.new()
	add_child(shop_item)
	_assert(shop_item._apply_consumable_discounts(75, "consumable") == 0, "Loss Leader makes the next consumable free immediately")
	game_controller.loss_leader_stacks = 0
	_assert(shop_item._apply_consumable_discounts(75, "consumable") == 75, "Consumable price recovers after Loss Leader is consumed")
	shop_item.free()

	consumable_ui.free()
	loss_leader.free()
	game_controller.free()


func _test_go_broke_raw_scoring() -> void:
	var scorecard := load("res://Scenes/ScoreCard/score_card.tscn").instantiate() as Scorecard
	add_child(scorecard)
	var scorecard_ui := load("res://Scenes/UI/Scorecard/scorecard.tscn").instantiate() as ScoreCardUI
	add_child(scorecard_ui)
	scorecard_ui.bind_scorecard(scorecard)
	scorecard.lower_levels["small_straight"] = 5
	ScoreModifierManager.register_additive("go_broke_test_add", 50)
	ScoreModifierManager.register_multiplier("go_broke_test_mult", 3.0)
	var dice_values: Array[int] = [1, 2, 3, 4, 6]
	DiceResults.set_values(dice_values)

	scorecard_ui.handle_go_broke_score(Scorecard.Section.LOWER, "small_straight")
	_assert(scorecard.lower_scores["small_straight"] == 30, "Go Broke ignores levels, additives, and multipliers")
	scorecard_ui.handle_go_broke_score(Scorecard.Section.LOWER, "full_house")
	_assert(scorecard.lower_scores["full_house"] == 0, "Go Broke keeps raw zero despite nonzero modifiers")

	ScoreModifierManager.unregister_additive("go_broke_test_add")
	ScoreModifierManager.unregister_multiplier("go_broke_test_mult")
	DiceResults.reset()
	scorecard_ui.free()
	scorecard.free()


func _test_challenge_icon_assets() -> void:
	var icon := ChallengeIcon.new()
	add_child(icon)
	var data := ChallengeData.new()
	data.icon = load("res://Resources/Art/Powerups/cassette_tape.png")
	icon.set_data(data)
	_assert(icon._chip_tex.texture == data.icon, "challenge icon uses assigned resource art")
	var replacement := ChallengeData.new()
	replacement.icon = load("res://Resources/Art/Powerups/chore_chart.png")
	icon.set_data(replacement)
	_assert(icon._chip_tex.texture == replacement.icon, "challenge icon refreshes art on data change")
	replacement.icon = null
	icon.set_data(replacement)
	_assert(icon._chip_tex.texture != null, "challenge icon keeps fallback art when icon is missing")
	icon.free()


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("✓ %s" % message)
	else:
		_fail_count += 1
		push_error("[ConsumableUsageWindowTest] FAIL: %s" % message)
		print("✗ %s" % message)

func _assert_equals(actual, expected, message: String) -> void:
	_assert(actual == expected, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])

func _quit_with_result() -> void:
	if _fail_count > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)

func _input(event: InputEvent) -> void:
	if _test_completed and event.is_action_pressed("ui_accept"):
		_quit_with_result()
