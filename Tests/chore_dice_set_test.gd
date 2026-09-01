extends Control
class_name ChoreDiceSetTest

## chore_dice_set_test.gd
##
## Verifies chores adapt to the active dice set:
## 1. d4: no chores requiring face values 5/6 are offered; "Score Fives" /
##    "Score Sixes" / Large Straight chores read Evens / Odds /
##    Even Odd Full House, and still complete on the re-purposed keys.
## 2. d20: the value-6 chores target the max face (Yahtzee of Twenties,
##    Score Twenties, etc.).
## 3. d6: library is unchanged.
## 4. ChoresManager generation resolves the dice set from RoundManager and
##    readapt_to_dice_set() clears chores that become impossible.
##
## Run headless with `-- --auto-test` to run the suite and quit with an
## exit code (0 = pass, 1 = fail).

const D4_DROPPED_IDS := [
	"yahtzee_fives", "yahtzee_sixes",
	"full_house_fives", "full_house_sixes",
	"three_kind_fives", "three_kind_sixes",
	"four_kind_fives", "four_kind_sixes",
]

## Minimal RoundManager stand-in: ChoresManager reads run_dice_type off the
## first node in the "round_manager" group.
class StubRoundManager extends Node:
	var run_dice_type: String = "d6"

var _stub_round_manager: StubRoundManager
var _fail_count := 0
var _test_completed := false

func _ready() -> void:
	print("=== Chore Dice Set Test ===")
	_stub_round_manager = StubRoundManager.new()
	_stub_round_manager.name = "StubRoundManager"
	add_child(_stub_round_manager)
	_stub_round_manager.add_to_group("round_manager")
	await get_tree().process_frame
	_run_tests()
	_test_completed = true
	if "--auto-test" in OS.get_cmdline_user_args():
		_quit_with_result()
	elif DisplayServer.get_name() == "headless":
		_quit_with_result()

func _run_tests() -> void:
	_test_d6_unchanged()
	_test_d4_adaptation()
	_test_d20_adaptation()
	_test_chores_manager_generation()

	var result_text := "PASS"
	if _fail_count > 0:
		result_text = "FAIL"
	print("=== Chore Dice Set Test Complete: %s ===" % result_text)

func _test_d6_unchanged() -> void:
	print("--- d6 library unchanged ---")
	var tasks := ChoreTasksLibrary.get_all_tasks(6)
	for id in D4_DROPPED_IDS:
		_assert(ChoreTasksLibrary.get_task_by_id(id, 6) != null, "d6 keeps %s" % id)
	var score_sixes = ChoreTasksLibrary.get_task_by_id("score_sixes", 6)
	_assert_equals(score_sixes.display_name, "Score Sixes", "d6 score_sixes display name")
	_assert_equals(tasks.size(), ChoreTasksLibrary.get_all_tasks().size(), "d6 explicit equals default")

func _test_d4_adaptation() -> void:
	print("--- d4 adaptation ---")
	var tasks := ChoreTasksLibrary.get_all_tasks(4)
	_assert(not tasks.is_empty(), "d4 pool is not empty")
	for task in tasks:
		if task.task_type == ChoreTasksLibrary.TASK_SCORE_SPECIFIC and task.target_value > 0:
			_assert(task.target_value <= 4, "d4 task %s targets value <= 4 (got %d)" % [task.id, task.target_value])
	for id in D4_DROPPED_IDS:
		_assert(ChoreTasksLibrary.get_task_by_id(id, 4) == null, "d4 drops %s" % id)

	var score_fives = ChoreTasksLibrary.get_task_by_id("score_fives", 4)
	_assert_equals(score_fives.display_name, "Score Evens", "d4 score_fives renamed to Score Evens")
	_assert_equals(score_fives.target_category, "fives", "d4 score_fives keeps 'fives' key")
	var score_sixes = ChoreTasksLibrary.get_task_by_id("score_sixes", 4)
	_assert_equals(score_sixes.display_name, "Score Odds", "d4 score_sixes renamed to Score Odds")
	var score_ls = ChoreTasksLibrary.get_task_by_id("score_large_straight", 4)
	_assert_equals(score_ls.display_name, "Even Odd Full House", "d4 large straight chore renamed")

	# Renamed chores still complete on the re-purposed scorecard keys
	var evens_context := {"category": "fives", "dice_values": [2, 4, 2, 1, 3], "score": 8}
	_assert(score_fives.check_completion(evens_context), "d4 Score Evens completes on 'fives' category")
	var odds_context := {"category": "sixes", "dice_values": [1, 3, 2, 1, 3], "score": 8}
	_assert(score_sixes.check_completion(odds_context), "d4 Score Odds completes on 'sixes' category")
	var eo_context := {"category": "large_straight", "dice_values": [2, 2, 3, 3, 3], "score": 40}
	_assert(score_ls.check_completion(eo_context), "d4 EO Full House completes on 'large_straight' category")

	_assert(not ChoreTasksLibrary.get_easy_tasks(4).is_empty(), "d4 easy pool not empty")
	_assert(not ChoreTasksLibrary.get_hard_tasks(4).is_empty(), "d4 hard pool not empty")

func _test_d20_adaptation() -> void:
	print("--- d20 adaptation ---")
	var yahtzee_sixes = ChoreTasksLibrary.get_task_by_id("yahtzee_sixes", 20)
	_assert(yahtzee_sixes != null, "d20 keeps yahtzee_sixes id")
	if yahtzee_sixes:
		_assert_equals(yahtzee_sixes.target_value, 20, "d20 yahtzee_sixes targets 20")
		_assert_equals(yahtzee_sixes.display_name, "Yahtzee of Twenties", "d20 yahtzee_sixes renamed")
	var score_sixes = ChoreTasksLibrary.get_task_by_id("score_sixes", 20)
	_assert_equals(score_sixes.display_name, "Score Twenties", "d20 score_sixes renamed to Score Twenties")
	_assert_equals(score_sixes.target_category, "sixes", "d20 score_sixes keeps 'sixes' key")
	var fh_sixes = ChoreTasksLibrary.get_task_by_id("full_house_sixes", 20)
	_assert_equals(fh_sixes.display_name, "Full House (Twenties)", "d20 full_house_sixes renamed")
	_assert_equals(fh_sixes.target_value, 20, "d20 full_house_sixes targets 20")
	var tk_sixes = ChoreTasksLibrary.get_task_by_id("three_kind_sixes", 20)
	_assert_equals(tk_sixes.display_name, "Triple Twenties", "d20 three_kind_sixes renamed")
	var fk_sixes = ChoreTasksLibrary.get_task_by_id("four_kind_sixes", 20)
	_assert_equals(fk_sixes.display_name, "Quad Twenties", "d20 four_kind_sixes renamed")

	# Remapped chore completes on a yahtzee of 20s
	var yahtzee_context := {"category": "yahtzee", "dice_values": [20, 20, 20, 20, 20], "score": 50}
	_assert(yahtzee_sixes.check_completion(yahtzee_context), "d20 Yahtzee of Twenties completes on five 20s")
	var wrong_context := {"category": "yahtzee", "dice_values": [6, 6, 6, 6, 6], "score": 50}
	_assert(not yahtzee_sixes.check_completion(wrong_context), "d20 Yahtzee of Twenties rejects five 6s")

func _test_chores_manager_generation() -> void:
	print("--- ChoresManager generation ---")
	_stub_round_manager.run_dice_type = "d4"
	var chores_manager = preload("res://Scripts/Managers/ChoresManager.gd").new()
	chores_manager.name = "TestChoresManager"
	add_child(chores_manager)  # _ready() selects a task against d4
	_assert_equals(chores_manager._get_current_dice_sides(), 4, "manager resolves d4 from round manager")
	if chores_manager.current_task:
		var t = chores_manager.current_task
		_assert(t.target_value <= 4 or t.target_value == 0, "generated d4 chore respects set (id=%s value=%d)" % [t.id, t.target_value])
	else:
		_fail("ChoresManager generated no task")

	# Mid-run switch to d20 re-adapts; an impossible chore is cleared
	chores_manager.current_task = ChoreTasksLibrary.get_task_by_id("yahtzee_sixes", 4)
	_assert(chores_manager.current_task == null, "d4 library cannot produce yahtzee_sixes")
	chores_manager.current_task = ChoreTasksLibrary.get_task_by_id("yahtzee_sixes", 6)
	_assert(chores_manager.current_task != null, "seeded d6 yahtzee_sixes chore")
	_stub_round_manager.run_dice_type = "d20"
	chores_manager.readapt_to_dice_set()
	_assert(chores_manager.current_task != null, "yahtzee_sixes survives d20 switch (remapped)")
	if chores_manager.current_task:
		_assert_equals(chores_manager.current_task.target_value, 20, "active chore remapped to 20s on d20")
		_assert_equals(chores_manager.current_task.display_name, "Yahtzee of Twenties", "active chore renamed on d20")
	_stub_round_manager.run_dice_type = "d4"
	chores_manager.readapt_to_dice_set()
	_assert(chores_manager.current_task == null, "impossible chore cleared on d4 switch")
	_stub_round_manager.run_dice_type = "d6"
	chores_manager.queue_free()

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("✓ %s" % message)
	else:
		_fail_count += 1
		push_error("[ChoreDiceSetTest] FAIL: %s" % message)
		print("✗ %s" % message)

func _assert_equals(actual, expected, message: String) -> void:
	_assert(actual == expected, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])

func _fail(message: String) -> void:
	_fail_count += 1
	push_error("[ChoreDiceSetTest] FAIL: %s" % message)
	print("✗ %s" % message)

func _quit_with_result() -> void:
	if _fail_count > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)

func _input(event: InputEvent) -> void:
	if _test_completed and event.is_action_pressed("ui_accept"):
		_quit_with_result()
