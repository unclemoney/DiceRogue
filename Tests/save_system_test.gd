extends Node

## save_system_test.gd
##
## Exercises the save-system overhaul (run_save_version 2):
##   1. Atomic write: save_snapshot leaves no .tmp and writes version 2.
##   2. Corrupt quarantine: garbage bytes -> load fails, timestamped .bak appears.
##   3. v1 compatibility: a version 1 save loads with per-key defaults.
##   4. Int fidelity: float JSON numbers coerce into typed int vars on load.
##   5. Newer version: a version 99 save is refused and quarantined.
##
## The real active profile slot's run save is backed up in memory before the
## tests and restored in teardown, so a real save is never destroyed.
##
## Run headless:
##   godot --headless --path . Tests/SaveSystemTest.tscn -- --quit-after
## Exit code 0 = all checks passed, 1 = at least one failure.

var _failures: int = 0
var _slot: int = -1
var _save_path: String = ""
var _had_save: bool = false
var _backup: PackedByteArray = PackedByteArray()
var _money_start: int = 0
var _piggy_start: int = 0
var _test_nodes: Array[Node] = []


func _ready() -> void:
	print("[SaveSystemTest] Starting")
	_check("GameSaveManager autoload available", GameSaveManager != null)
	_check("GameSettings autoload available", GameSettings != null)
	_check("PlayerEconomy autoload available", PlayerEconomy != null)
	if GameSaveManager == null or GameSettings == null:
		_finish()
		return

	_slot = int(GameSettings.active_profile_slot)
	_save_path = GameSaveManager.get_save_path(_slot)
	_backup_save()
	_money_start = PlayerEconomy.money
	_piggy_start = PlayerEconomy.piggy_bank_savings

	_test_atomic_write()
	_test_corrupt_quarantine()
	_test_v1_compatibility()
	_test_int_fidelity()
	_test_newer_version_quarantine()

	_teardown()
	_finish()


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[SaveSystemTest] OK: " + label)
	else:
		push_error("[SaveSystemTest] FAILED: " + label)
		_failures += 1


func _finish() -> void:
	if _failures == 0:
		print("[SaveSystemTest] PASS - all checks passed")
	else:
		print("[SaveSystemTest] FAIL - %d check(s) failed" % _failures)

	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(0 if _failures == 0 else 1)


func _backup_save() -> void:
	_had_save = FileAccess.file_exists(_save_path)
	if _had_save:
		var file = FileAccess.open(_save_path, FileAccess.READ)
		if file:
			_backup = file.get_buffer(file.get_length())
			file.close()


func _teardown() -> void:
	# Restore the player's real run save (or remove the test's file)
	if _had_save:
		var file = FileAccess.open(_save_path, FileAccess.WRITE)
		if file:
			file.store_buffer(_backup)
			file.close()
	elif FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(_save_path)

	# Clear any pending load buffered by the load tests
	if GameSaveManager.has_pending_load():
		GameSaveManager.consume_pending_load()

	# Restore economy state mutated by the fidelity test
	PlayerEconomy.money = _money_start
	PlayerEconomy.piggy_bank_savings = _piggy_start

	for node in _test_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_test_nodes.clear()


## _list_quarantine_baks() -> Array[String]
##
## Returns every quarantined .bak file for the active slot's run save.
func _list_quarantine_baks() -> Array[String]:
	var baks: Array[String] = []
	var prefix = "profile_%d_run.save." % _slot
	var dir = DirAccess.open("user://")
	if dir:
		for file_name in dir.get_files():
			if file_name.begins_with(prefix) and file_name.ends_with(".bak"):
				baks.append(file_name)
	return baks


## _remove_quarantine_baks(baks: Array[String])
##
## Deletes the given .bak files from user:// (test cleanup).
func _remove_quarantine_baks(baks: Array) -> void:
	for file_name in baks:
		DirAccess.remove_absolute("user://" + file_name)


func _write_save_file(contents: String) -> void:
	var file = FileAccess.open(_save_path, FileAccess.WRITE)
	if file:
		file.store_string(contents)
		file.close()


func _test_atomic_write() -> void:
	GameSaveManager.save_snapshot({"marker": "save_system_test"})
	_check("run save exists after save_snapshot", FileAccess.file_exists(_save_path))
	_check("no .tmp file remains after save_snapshot", not FileAccess.file_exists(_save_path + ".tmp"))

	var file = FileAccess.open(_save_path, FileAccess.READ)
	if file == null:
		_check("run save opens for reading", false)
		return
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	_check("run save parses as JSON", err == OK)
	if err != OK:
		return
	var data = json.get_data()
	_check("run save root is a Dictionary", data is Dictionary)
	if data is Dictionary:
		var meta = data.get("meta", {})
		_check("meta.run_save_version == 2", int(meta.get("run_save_version", 0)) == 2)
		_check("meta.profile_slot matches active slot", int(meta.get("profile_slot", -1)) == _slot)
		var state = data.get("state", {})
		_check("state round-trips the snapshot", state.get("marker", "") == "save_system_test")


func _test_corrupt_quarantine() -> void:
	_write_save_file("this is not json {{{")
	var baks_before = _list_quarantine_baks()
	var loaded = GameSaveManager.load_save_for_profile(_slot)
	_check("corrupt save: load returns false", not loaded)
	_check("corrupt save: original file removed", not FileAccess.file_exists(_save_path))
	var baks_after = _list_quarantine_baks()
	var new_baks: Array[String] = []
	for bak in baks_after:
		if bak not in baks_before:
			new_baks.append(bak)
	_check("corrupt save: timestamped .bak created", new_baks.size() >= 1)
	_remove_quarantine_baks(new_baks)


func _test_v1_compatibility() -> void:
	var v1_save = {
		"meta": {
			"run_save_version": 1,
			"profile_slot": _slot,
			"timestamp": "2025-01-01T00:00:00"
		},
		"state": {
			"player_economy": {"money": 250.0, "piggy_bank_savings": 75.0}
		}
	}
	_write_save_file(JSON.stringify(v1_save))
	var loaded = GameSaveManager.load_save_for_profile(_slot)
	_check("v1 save: load returns true", loaded)
	_check("v1 save: pending load buffered", GameSaveManager.has_pending_load())
	var state = GameSaveManager.consume_pending_load()
	_check("v1 save: consume returns the state dict", not state.is_empty())
	var economy = state.get("player_economy", {})
	_check("v1 save: money survives the round-trip", float(economy.get("money", 0.0)) == 250.0)


func _test_int_fidelity() -> void:
	# Every number below is a float, exactly as JSON.parse() produces.

	PlayerEconomy.load_state({"money": 250.0, "piggy_bank_savings": 75.0})
	_check("economy money is int 250", typeof(PlayerEconomy.money) == TYPE_INT and PlayerEconomy.money == 250)
	_check("economy piggy bank is int 75", typeof(PlayerEconomy.piggy_bank_savings) == TYPE_INT and PlayerEconomy.piggy_bank_savings == 75)

	var turn_tracker := TurnTracker.new()
	add_child(turn_tracker)
	_test_nodes.append(turn_tracker)
	turn_tracker.load_state({
		"current_turn": 2.0,
		"rolls_left": 1.0,
		"MAX_ROLLS": 3.0,
		"is_active": true,
		"dice_bonus_stacks": [{"id": 4.0, "dice": 2.0, "turns_remaining": 3.0}],
		"_next_stack_id": 5.0,
		"score_streak_active": false,
		"score_streak_turns_remaining": 2.0,
		"score_streak_multiplier": 1.5,
		"score_streak_current_turn": 1.0
	})
	_check("turn_tracker current_turn is int 2", typeof(turn_tracker.current_turn) == TYPE_INT and turn_tracker.current_turn == 2)
	_check("turn_tracker rolls_left is int 1", typeof(turn_tracker.rolls_left) == TYPE_INT and turn_tracker.rolls_left == 1)
	_check("turn_tracker MAX_ROLLS is int 3", typeof(turn_tracker.MAX_ROLLS) == TYPE_INT and turn_tracker.MAX_ROLLS == 3)
	_check("turn_tracker _next_stack_id is int 5", typeof(turn_tracker._next_stack_id) == TYPE_INT and turn_tracker._next_stack_id == 5)
	_check("turn_tracker streak turns is int 2", typeof(turn_tracker.score_streak_turns_remaining) == TYPE_INT and turn_tracker.score_streak_turns_remaining == 2)
	_check("turn_tracker streak current turn is int 1", typeof(turn_tracker.score_streak_current_turn) == TYPE_INT and turn_tracker.score_streak_current_turn == 1)
	_check("turn_tracker streak multiplier stays float 1.5", is_equal_approx(turn_tracker.score_streak_multiplier, 1.5))
	if turn_tracker.dice_bonus_stacks.size() == 1:
		var stack: Dictionary = turn_tracker.dice_bonus_stacks[0]
		_check("bonus stack id is int 4", typeof(stack.get("id")) == TYPE_INT and stack.get("id") == 4)
		_check("bonus stack dice is int 2", typeof(stack.get("dice")) == TYPE_INT and stack.get("dice") == 2)
		_check("bonus stack turns_remaining is int 3", typeof(stack.get("turns_remaining")) == TYPE_INT and stack.get("turns_remaining") == 3)
	else:
		_check("bonus stack restored", false)

	var round_manager := RoundManager.new()
	add_child(round_manager)
	_test_nodes.append(round_manager)
	round_manager.load_state({
		"current_round": 2.0,
		"is_challenge_completed": false,
		"game_started": true,
		"max_rounds": 6.0,
		"rounds_data": [{"round_number": 3.0, "target_score": 500.0, "dice_type": "d6"}]
	})
	_check("round_manager current_round is int 2", typeof(round_manager.current_round) == TYPE_INT and round_manager.current_round == 2)
	_check("round_manager max_rounds is int 6", typeof(round_manager.max_rounds) == TYPE_INT and round_manager.max_rounds == 6)
	_check("round_manager game_started restored", round_manager.game_started == true)
	if round_manager.rounds_data.size() == 1:
		var round_data: Dictionary = round_manager.rounds_data[0]
		_check("rounds_data round_number is int 3", typeof(round_data.get("round_number")) == TYPE_INT and round_data.get("round_number") == 3)
		_check("rounds_data target_score is int 500", typeof(round_data.get("target_score")) == TYPE_INT and round_data.get("target_score") == 500)
	else:
		_check("rounds_data restored", false)

	var scorecard := Scorecard.new()
	add_child(scorecard)
	_test_nodes.append(scorecard)
	scorecard.load_state({
		"upper_scores": {"ones": 3.0, "twos": null, "threes": 9.0, "fours": null, "fives": null, "sixes": null},
		"lower_scores": {"three_of_a_kind": null, "four_of_a_kind": null, "full_house": null, "small_straight": null, "large_straight": null, "yahtzee": null, "chance": 20.0},
		"upper_levels": {"ones": 2.0, "twos": 1.0, "threes": 1.0, "fours": 1.0, "fives": 1.0, "sixes": 1.0},
		"lower_levels": {"three_of_a_kind": 1.0, "four_of_a_kind": 1.0, "full_house": 1.0, "small_straight": 1.0, "large_straight": 1.0, "yahtzee": 1.0, "chance": 1.0},
		"upper_bonus": 35.0,
		"yahtzee_bonuses": 1.0,
		"yahtzee_bonus_points": 100.0,
		"current_round_number": 2.0,
		"current_dice_sides": 6.0,
		"sixth_slot_target": 6.0,
		"sixth_slot_multiplier": 1.0,
		"last_base_score": 12.0
	})
	_check("scorecard ones score is int 3", typeof(scorecard.upper_scores["ones"]) == TYPE_INT and scorecard.upper_scores["ones"] == 3)
	_check("scorecard twos stays null (unscored)", scorecard.upper_scores["twos"] == null)
	_check("scorecard chance score is int 20", typeof(scorecard.lower_scores["chance"]) == TYPE_INT and scorecard.lower_scores["chance"] == 20)
	_check("scorecard ones level is int 2", typeof(scorecard.upper_levels["ones"]) == TYPE_INT and scorecard.upper_levels["ones"] == 2)
	_check("scorecard upper_bonus is int 35", typeof(scorecard.upper_bonus) == TYPE_INT and scorecard.upper_bonus == 35)
	_check("scorecard current_round_number is int 2", typeof(scorecard.current_round_number) == TYPE_INT and scorecard.current_round_number == 2)
	_check("scorecard current_dice_sides is int 6", typeof(scorecard.current_dice_sides) == TYPE_INT and scorecard.current_dice_sides == 6)
	_check("scorecard last_base_score is int 12", typeof(scorecard.last_base_score) == TYPE_INT and scorecard.last_base_score == 12)

	var chores_manager := ChoresManager.new()
	add_child(chores_manager)
	_test_nodes.append(chores_manager)
	chores_manager.load_state({
		"current_progress": 40.0,
		"chores_completed_this_round": 2.0,
		"chore_rewards_this_round": 15.0,
		"tasks_completed": 7.0,
		"is_mom_active": false,
		"_task_history": [],
		"pending_chore_selection": false,
		"current_task_id": "",
		"_pending_easy_task_id": "",
		"_pending_hard_task_id": "",
		"current_round_number": 3.0,
		"mom_mood": 5.0,
		"grudge": 1.0,
		"defer_streak": 2.0,
		"low_mood_visits_this_run": 1.0,
		"_rolls_this_round": 4.0,
		"_checkin_roll_target": 3.0,
		"_checkin_done_this_round": true,
		"completed_chores_ids": []
	})
	_check("chores current_progress is int 40", typeof(chores_manager.current_progress) == TYPE_INT and chores_manager.current_progress == 40)
	_check("chores tasks_completed is int 7", typeof(chores_manager.tasks_completed) == TYPE_INT and chores_manager.tasks_completed == 7)
	_check("chores mom_mood is int 5", typeof(chores_manager.mom_mood) == TYPE_INT and chores_manager.mom_mood == 5)
	_check("chores grudge is int 1", typeof(chores_manager.grudge) == TYPE_INT and chores_manager.grudge == 1)
	_check("chores defer_streak is int 2", typeof(chores_manager.defer_streak) == TYPE_INT and chores_manager.defer_streak == 2)
	_check("chores _checkin_roll_target is int 3", typeof(chores_manager._checkin_roll_target) == TYPE_INT and chores_manager._checkin_roll_target == 3)

	var cast_manager := CastManager.new()
	add_child(cast_manager)
	_test_nodes.append(cast_manager)
	cast_manager.load_state({
		"visited_zones": ["food_court"],
		"visited_zone_channels": {"food_court": 2.0},
		"arc_progress": {"patterson_arc": 1.0},
		"completed_arcs": [],
		"flags": {},
		"patterson_pending": [{"zone": "food_court", "is_true": true, "recorded_channel": 2.0, "min_delay_zones": 2.0}],
		"patterson_sightings_this_run": 1.0,
		"last_sighting_channel": 2.0,
		"sightings_in_current_zone": 1.0,
		"dad_call_used": false,
		"dad_cover_used": false,
		"dad_cover_pending": false,
		"max_grudge_seen": 0.0
	})
	_check("cast visited channel is int 2", typeof(cast_manager.visited_zone_channels.get("food_court")) == TYPE_INT and cast_manager.visited_zone_channels.get("food_court") == 2)
	_check("cast arc beat index is int 1", typeof(cast_manager.arc_progress.get("patterson_arc")) == TYPE_INT and cast_manager.arc_progress.get("patterson_arc") == 1)
	if cast_manager.patterson_pending.size() == 1:
		var report: Dictionary = cast_manager.patterson_pending[0]
		_check("cast recorded_channel is int 2", typeof(report.get("recorded_channel")) == TYPE_INT and report.get("recorded_channel") == 2)
		_check("cast min_delay_zones is int 2", typeof(report.get("min_delay_zones")) == TYPE_INT and report.get("min_delay_zones") == 2)
	else:
		_check("cast patterson_pending restored", false)
	_check("cast sightings scalar is int 1", typeof(cast_manager.patterson_sightings_this_run) == TYPE_INT and cast_manager.patterson_sightings_this_run == 1)


func _test_newer_version_quarantine() -> void:
	var v99_save = {
		"meta": {
			"run_save_version": 99,
			"profile_slot": _slot,
			"timestamp": "2025-01-01T00:00:00"
		},
		"state": {}
	}
	_write_save_file(JSON.stringify(v99_save))
	var baks_before = _list_quarantine_baks()
	var loaded = GameSaveManager.load_save_for_profile(_slot)
	_check("v99 save: load returns false", not loaded)
	_check("v99 save: original file removed", not FileAccess.file_exists(_save_path))
	var baks_after = _list_quarantine_baks()
	var new_baks: Array[String] = []
	for bak in baks_after:
		if bak not in baks_before:
			new_baks.append(bak)
	_check("v99 save: timestamped .bak created", new_baks.size() >= 1)
	_remove_quarantine_baks(new_baks)
