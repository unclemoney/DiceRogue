extends Node

const MONEY_WELL_SPENT_SCENE := preload("res://Scenes/PowerUp/MoneyWellSpentPowerUp.tscn")
const HOT_STREAK_SCENE := preload("res://Scenes/PowerUp/HotStreakPowerUp.tscn")
const SCORECARD_SCENE := preload("res://Scenes/ScoreCard/score_card.tscn")
const GAME_CONTROLLER_SCRIPT := preload("res://Scripts/Core/game_controller.gd")

var _failures: Array[String] = []


func _ready() -> void:
	print("=== Replica PowerUp Test ===")
	ScoreModifierManager.reset()
	await get_tree().process_frame
	_test_money_well_spent_replica_stack()
	_test_modifier_source_sync_for_replica()
	_test_scorecard_replica_categorization()
	ScoreModifierManager.reset()
	if _failures.is_empty():
		print("=== Replica PowerUp Test Passed ===")
		await get_tree().create_timer(0.1).timeout
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("=== Replica PowerUp Test Failed ===")
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(1)


func _test_money_well_spent_replica_stack() -> void:
	print("--- MoneyWellSpent original + replica ---")
	var controller = GAME_CONTROLLER_SCRIPT.new()
	var original = MONEY_WELL_SPENT_SCENE.instantiate()
	var replica = MONEY_WELL_SPENT_SCENE.instantiate()
	add_child(original)
	add_child(replica)
	controller._configure_power_up_runtime_identity(original, "money_well_spent")
	controller._configure_power_up_runtime_identity(replica, "money_well_spent_replica_test")
	var previous_money_spent = Statistics.total_money_spent
	Statistics.total_money_spent = 100
	original.apply(null)
	replica.apply(null)
	var additive_sources = ScoreModifierManager.get_active_additive_sources()
	_assert_true(additive_sources.has("money_well_spent"), "Original MoneyWellSpent source missing after apply")
	_assert_true(additive_sources.has("money_well_spent_replica_test"), "Replica MoneyWellSpent source missing after apply")
	_assert_equal(4, ScoreModifierManager.get_total_additive(), "MoneyWellSpent original + replica should stack additive bonuses")
	replica.remove(null)
	_assert_equal(2, ScoreModifierManager.get_total_additive(), "Removing replica should preserve original MoneyWellSpent additive")
	original.remove(null)
	_assert_equal(0, ScoreModifierManager.get_total_additive(), "Removing original should clear MoneyWellSpent additive")
	Statistics.total_money_spent = previous_money_spent
	original.queue_free()
	replica.queue_free()
	ScoreModifierManager.reset()


func _test_modifier_source_sync_for_replica() -> void:
	print("--- modifier_source_name replica sync ---")
	var controller = GAME_CONTROLLER_SCRIPT.new()
	var hot_streak = HOT_STREAK_SCENE.instantiate()
	add_child(hot_streak)
	controller._configure_power_up_runtime_identity(hot_streak, "hot_streak_replica_test")
	_assert_equal("hot_streak_replica_test", hot_streak.modifier_source_name, "Replica runtime identity should update modifier_source_name for variable-based PowerUps")
	hot_streak.queue_free()


func _test_scorecard_replica_categorization() -> void:
	print("--- scorecard replica categorization ---")
	var scorecard = SCORECARD_SCENE.instantiate()
	add_child(scorecard)
	_assert_equal("powerup", scorecard._categorize_modifier_source("money_well_spent_replica_test"), "Scorecard should classify replica additive sources as powerups")
	_assert_equal("powerup", scorecard._categorize_modifier_source("hot_streak_replica_test"), "Scorecard should classify modifier_source_name replica ids as powerups")
	scorecard.queue_free()


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)


func _assert_equal(expected, actual, message: String) -> void:
	if expected == actual:
		print("PASS: %s" % message)
		return
	_failures.append("%s | expected=%s actual=%s" % [message, str(expected), str(actual)])