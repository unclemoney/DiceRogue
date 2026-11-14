extends Control

## empty_shelves_test.gd
##
## Exercises the real Empty Shelves consumable through manual scoring,
## auto-scoring, and GameController lifecycle boundaries.
## Run headless with `-- --auto-test` to quit with a test result code.

const UNRELATED_SOURCE := "empty_shelves_test_unrelated"

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var multiplier_label: Label = $VBoxContainer/MultiplierLabel
@onready var scores_label: Label = $VBoxContainer/ScoresLabel
@onready var apply_button: Button = $VBoxContainer/ApplyButton
@onready var assign_score_button: Button = $VBoxContainer/AssignScoreButton
@onready var check_button: Button = $VBoxContainer/CheckMultiplierButton
@onready var run_tests_button: Button = $VBoxContainer/RunTestsButton
@onready var log_label: RichTextLabel = $VBoxContainer/LogLabel

var game_controller: BareGameController
var scorecard: Scorecard
var powerup_ui: BarePowerUpUI
var empty_shelves: EmptyShelvesConsumable
var scores_assigned: int = 0
var _fail_count: int = 0
var _test_completed: bool = false
var _auto_cleanup_before_round: bool = false


class BareGameController extends GameController:
	func _ready() -> void:
		pass

	func _setup_round_target(_round_number: int) -> void:
		pass


class BarePowerUpUI extends PowerUpUI:
	func _ready() -> void:
		pass


func _ready() -> void:
	apply_button.pressed.connect(_on_apply_pressed)
	assign_score_button.pressed.connect(_on_assign_score_pressed)
	check_button.pressed.connect(_on_check_multiplier_pressed)
	run_tests_button.pressed.connect(_on_run_tests_pressed)
	_setup_real_consumable()
	_update_multiplier_display()
	call_deferred("_run_tests_and_report")


func _setup_real_consumable() -> void:
	ScoreModifierManager.reset()
	game_controller = BareGameController.new()
	add_child(game_controller)
	scorecard = Scorecard.new()
	add_child(scorecard)
	powerup_ui = BarePowerUpUI.new()
	add_child(powerup_ui)
	powerup_ui.max_power_ups = 5
	empty_shelves = EmptyShelvesConsumable.new()
	add_child(empty_shelves)
	game_controller.scorecard = scorecard
	game_controller.powerup_ui = powerup_ui


func _run_tests_and_report() -> void:
	run_tests_button.disabled = true
	await _run_regression_tests()
	_test_completed = true
	run_tests_button.disabled = false
	_update_multiplier_display()
	if _fail_count == 0:
		status_label.text = "Status: PASS - manual controls are ready"
	else:
		status_label.text = "Status: FAIL - %d check(s) failed" % _fail_count
	if "--auto-test" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		_quit_with_result.call_deferred()


func _quit_with_result() -> void:
	get_tree().quit(0 if _fail_count == 0 else 1)


func _run_regression_tests() -> void:
	_log("\n=== RUNNING REAL EMPTY SHELVES REGRESSION TESTS ===")
	_test_no_empty_slots()
	_test_manual_score_cleanup()
	await _test_auto_score_cleanup()
	_test_post_score_fail_safe()
	_test_round_boundaries()
	await _test_exit_tree_cleanup()
	ScoreModifierManager.reset()
	scorecard.reset_scores()
	_log("=== TESTS COMPLETE: %s ===" % ("PASS" if _fail_count == 0 else "FAIL"))


func _test_no_empty_slots() -> void:
	_log("\n--- No empty slots ---")
	powerup_ui._power_up_data.clear()
	for index in range(powerup_ui.max_power_ups):
		powerup_ui._power_up_data["test_powerup_%d" % index] = null
	empty_shelves.apply(game_controller)
	_assert(not ScoreModifierManager.has_multiplier(EmptyShelvesConsumable.MULTIPLIER_ID),
		"No multiplier is registered without empty PowerUp slots")
	powerup_ui._power_up_data.clear()


func _test_manual_score_cleanup() -> void:
	_log("\n--- Immediate manual score cleanup ---")
	empty_shelves.apply(game_controller)
	_assert(ScoreModifierManager.get_multiplier(EmptyShelvesConsumable.MULTIPLIER_ID) == 5.0,
		"Five empty slots register a 5x multiplier")
	var modified_score: int = scorecard.calculate_score("ones", [1, 1, 2, 3, 4])
	_assert(modified_score == 10, "The real scoring calculation receives the 5x multiplier")
	scorecard.set_score(Scorecard.Section.UPPER, "ones", modified_score)
	_assert(not ScoreModifierManager.has_multiplier(EmptyShelvesConsumable.MULTIPLIER_ID),
		"score_assigned removes the multiplier immediately")
	_assert(not scorecard.is_connected("score_assigned", empty_shelves._on_score_assigned),
		"Manual cleanup disconnects the score callback")
	var second_score: int = scorecard.calculate_score("twos", [2, 2, 1, 3, 4])
	_assert(second_score == 4, "The second score is unaffected")
	scorecard.set_score(Scorecard.Section.UPPER, "twos", second_score)
	_assert(not ScoreModifierManager.has_multiplier(EmptyShelvesConsumable.MULTIPLIER_ID),
		"The multiplier stays removed after a second score")
	scorecard.reset_scores()


func _test_auto_score_cleanup() -> void:
	_log("\n--- Auto-score cleanup before round completion ---")
	_auto_cleanup_before_round = false
	empty_shelves.apply(game_controller)
	scorecard.score_changed.connect(_on_auto_round_score_changed)
	scorecard.auto_score_best([1, 1, 1, 2, 3])
	_assert(_auto_cleanup_before_round,
		"The multiplier is gone when score_changed starts round completion")
	_assert(not ScoreModifierManager.has_multiplier(EmptyShelvesConsumable.MULTIPLIER_ID),
		"Auto-score cleanup does not wait for deferred finalization")
	await get_tree().process_frame
	await get_tree().process_frame
	_assert(not ScoreModifierManager.has_multiplier(EmptyShelvesConsumable.MULTIPLIER_ID),
		"Deferred auto-score finalization cannot restore the multiplier")
	scorecard.score_changed.disconnect(_on_auto_round_score_changed)
	scorecard.reset_scores()


func _on_auto_round_score_changed(_total_score: int) -> void:
	_auto_cleanup_before_round = not ScoreModifierManager.has_multiplier(EmptyShelvesConsumable.MULTIPLIER_ID)
	game_controller._on_round_completed(1)


func _test_post_score_fail_safe() -> void:
	_log("\n--- Shared post-score GameController fail-safe ---")
	ScoreModifierManager.register_multiplier(EmptyShelvesConsumable.MULTIPLIER_ID, 5.0)
	ScoreModifierManager.register_multiplier(UNRELATED_SOURCE, 3.0)
	game_controller._handle_post_scoring_effects(Scorecard.Section.UPPER, "ones", 10, {})
	_assert(not ScoreModifierManager.has_multiplier(EmptyShelvesConsumable.MULTIPLIER_ID),
		"The shared post-score path removes Empty Shelves")
	_assert(ScoreModifierManager.has_multiplier(UNRELATED_SOURCE),
		"The post-score fail-safe preserves unrelated modifiers")


func _test_round_boundaries() -> void:
	_log("\n--- Round lifecycle fail-safes ---")
	_assert_round_boundary("completed")
	_assert_round_boundary("failed")
	_assert_round_boundary("started")
	if ScoreModifierManager.has_multiplier(UNRELATED_SOURCE):
		ScoreModifierManager.unregister_multiplier(UNRELATED_SOURCE)


func _assert_round_boundary(boundary: String) -> void:
	empty_shelves.apply(game_controller)
	if not ScoreModifierManager.has_multiplier(UNRELATED_SOURCE):
		ScoreModifierManager.register_multiplier(UNRELATED_SOURCE, 3.0)
	match boundary:
		"completed":
			game_controller._on_round_completed(1)
		"failed":
			game_controller._on_round_failed(1)
		"started":
			game_controller._on_round_started(1)
	_assert(not ScoreModifierManager.has_multiplier(EmptyShelvesConsumable.MULTIPLIER_ID),
		"Round %s removes Empty Shelves" % boundary)
	_assert(ScoreModifierManager.has_multiplier(UNRELATED_SOURCE),
		"Round %s preserves unrelated modifiers" % boundary)


func _test_exit_tree_cleanup() -> void:
	_log("\n--- Freeing an armed consumable ---")
	empty_shelves.apply(game_controller)
	empty_shelves.queue_free()
	await get_tree().process_frame
	_assert(not ScoreModifierManager.has_multiplier(EmptyShelvesConsumable.MULTIPLIER_ID),
		"Freeing an armed Empty Shelves instance removes its multiplier")
	empty_shelves = EmptyShelvesConsumable.new()
	add_child(empty_shelves)


func _on_apply_pressed() -> void:
	if not _test_completed:
		return
	powerup_ui._power_up_data.clear()
	empty_shelves.apply(game_controller)
	_log("Applied the real Empty Shelves consumable")
	_update_multiplier_display()


func _on_assign_score_pressed() -> void:
	if not _test_completed:
		return
	var category := ""
	for candidate in scorecard.upper_scores.keys():
		if scorecard.upper_scores[candidate] == null:
			category = candidate
			break
	if category.is_empty():
		scorecard.reset_scores()
		category = "ones"
	var dice_values: Array = [1, 1, 2, 3, 4]
	var score: int = scorecard.calculate_score(category, dice_values)
	scorecard.set_score(Scorecard.Section.UPPER, category, score)
	scores_assigned += 1
	scores_label.text = "Scores assigned: %d" % scores_assigned
	_log("Assigned a real score to %s: %d" % [category, score])
	_update_multiplier_display()


func _on_check_multiplier_pressed() -> void:
	_update_multiplier_display()
	_log("Active multiplier sources: %s" % str(ScoreModifierManager.get_active_sources()))


func _on_run_tests_pressed() -> void:
	if not _test_completed:
		return
	_fail_count = 0
	scores_assigned = 0
	scores_label.text = "Scores assigned: 0"
	await _run_tests_and_report()


func _update_multiplier_display() -> void:
	if ScoreModifierManager.has_multiplier(EmptyShelvesConsumable.MULTIPLIER_ID):
		var value: float = ScoreModifierManager.get_multiplier(EmptyShelvesConsumable.MULTIPLIER_ID)
		multiplier_label.text = "Multiplier registered: YES (value: %.1f)" % value
		multiplier_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		multiplier_label.text = "Multiplier registered: NO"
		multiplier_label.add_theme_color_override("font_color", Color.GRAY)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_log("PASS: %s" % message)
	else:
		_fail_count += 1
		_log("[color=red]FAIL: %s[/color]" % message)
		push_error("[EmptyShelvesTest] %s" % message)


func _log(message: String) -> void:
	log_label.append_text("\n" + message)
	print("[EmptyShelvesTest] " + message.replace("[color=red]", "").replace("[/color]", ""))
