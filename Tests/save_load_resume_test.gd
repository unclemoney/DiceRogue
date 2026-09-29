extends Node

## save_load_resume_test.gd
##
## Regression test for the load-resets-to-round-1 bug. Exercises the REAL
## load path end-to-end: a fabricated mid-round-3 v2 state is written through
## GameSaveManager.save_snapshot(), read back with load_save_for_profile()
## (covering the JSON float round-trip), then the real game scene
## (Tests/DebuffTest.tscn) is instantiated so GameController._ready consumes
## the pending load via call_deferred -> load_game_state ->
## _restore_session_ui_state().
##
## Asserts the restored round survives, the roll button is re-enabled
## (first_roll_done restored), and the VCR round label shows round 3.
##
## The real active profile slot's run save is backed up in memory before the
## test and restored in teardown, so a real save is never destroyed.
##
## NOTE on quitting: the instanced DebuffTest child would quit the whole tree
## after 3s if it sees "--quit-after" in the user args (debuff_test.gd), so
## this test quits itself unconditionally once assertions finish. Run:
##   godot --headless --path . Tests/SaveLoadResumeTest.tscn
## Exit code 0 = all checks passed, 1 = at least one failure.

const GAME_SCENE: PackedScene = preload("res://Tests/DebuffTest.tscn")

var _failures: int = 0
var _slot: int = -1
var _save_path: String = ""
var _had_save: bool = false
var _backup: PackedByteArray = PackedByteArray()
var _money_start: int = 0
var _piggy_start: int = 0
var _game_scene: Node = null


func _ready() -> void:
	print("[SaveLoadResumeTest] Starting")
	_check("GameSaveManager autoload available", GameSaveManager != null)
	_check("GameSettings autoload available", GameSettings != null)
	if GameSaveManager == null or GameSettings == null:
		_finish()
		return

	_slot = int(GameSettings.active_profile_slot)
	_save_path = GameSaveManager.get_save_path(_slot)
	_backup_save()
	_money_start = PlayerEconomy.money
	_piggy_start = PlayerEconomy.piggy_bank_savings

	await _test_mid_round_resume()

	await _teardown()
	_finish()


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[SaveLoadResumeTest] OK: " + label)
	else:
		push_error("[SaveLoadResumeTest] FAILED: " + label)
		_failures += 1


func _finish() -> void:
	if _failures == 0:
		print("[SaveLoadResumeTest] PASS - all checks passed")
	else:
		print("[SaveLoadResumeTest] FAIL - %d check(s) failed" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _backup_save() -> void:
	_had_save = FileAccess.file_exists(_save_path)
	if _had_save:
		var file = FileAccess.open(_save_path, FileAccess.READ)
		if file:
			_backup = file.get_buffer(file.get_length())
			file.close()


func _teardown() -> void:
	if is_instance_valid(_game_scene):
		_game_scene.queue_free()
		_game_scene = null
		await get_tree().process_frame

	# Restore the player's real run save (or remove the test's file)
	if _had_save:
		var file = FileAccess.open(_save_path, FileAccess.WRITE)
		if file:
			file.store_buffer(_backup)
			file.close()
	elif FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(_save_path)

	if GameSaveManager.has_pending_load():
		GameSaveManager.consume_pending_load()

	# Undo the melting_dice additive the load registered on the autoload
	if ScoreModifierManager and ScoreModifierManager.has_additive("melting_dice"):
		ScoreModifierManager.unregister_additive("melting_dice")

	PlayerEconomy.money = _money_start
	PlayerEconomy.piggy_bank_savings = _piggy_start


## _fabricate_mid_round_3_state() -> Dictionary
##
## Builds a realistic v2 state dictionary for a save taken on turn 3 of round
## 3 (0-based current_round 2), with rounds 1-2 completed. Numbers are written
## as ints here but come back as floats through the JSON round-trip, which is
## exactly what the int coercion in the load_state functions must handle.
func _fabricate_mid_round_3_state() -> Dictionary:
	var rounds_data: Array = []
	for i in range(6):
		rounds_data.append({
			"round_number": i + 1,
			"target_score": 300 + i * 100,
			"dice_type": "d6",
			"completed": i < 2,
			"failed": false
		})

	var dice: Array = []
	var values: Array = [1, 2, 3, 4, 5]
	for i in range(5):
		dice.append({
			"value": values[i],
			"color": 0,
			"is_locked": i == 2,
			"state": 2 if i == 2 else 1,  # DiceState.LOCKED / DiceState.ROLLED
			"mods": []
		})

	return {
		"round_manager": {
			"current_round": 2,
			"is_challenge_completed": false,
			"game_started": true,
			"max_rounds": 6,
			"rounds_data": rounds_data
		},
		"turn_tracker": {
			"current_turn": 3,
			"rolls_left": 2,
			"MAX_ROLLS": 3,
			"is_active": true,
			"dice_bonus_stacks": [],
			"_next_stack_id": 0,
			"score_streak_active": false,
			"score_streak_turns_remaining": 0,
			"score_streak_multiplier": 1.0,
			"score_streak_current_turn": 0
		},
		"player_economy": {
			"money": 250,
			"piggy_bank_savings": 0
		},
		"scorecard": {
			"upper_scores": {"ones": null, "twos": null, "threes": null, "fours": null, "fives": null, "sixes": null},
			"lower_scores": {"three_of_a_kind": null, "four_of_a_kind": null, "full_house": null, "small_straight": null, "large_straight": null, "yahtzee": null, "chance": null},
			"upper_levels": {"ones": 1, "twos": 1, "threes": 1, "fours": 1, "fives": 1, "sixes": 1},
			"lower_levels": {"three_of_a_kind": 1, "four_of_a_kind": 1, "full_house": 1, "small_straight": 1, "large_straight": 1, "yahtzee": 1, "chance": 1},
			"upper_bonus": 0,
			"upper_bonus_awarded": false,
			"yahtzee_bonuses": 0,
			"yahtzee_bonus_points": 0,
			"yahtzee_scored": false,
			"current_round_number": 3,
			"current_dice_sides": 6,
			"sixth_slot_target": 6,
			"sixth_slot_multiplier": 1,
			"allow_gap_straights": false,
			"allow_four_kind_yahtzee": false,
			"allow_two_pair_full_house": false,
			"last_base_score": 0
		},
		"dice_hand": {
			"dice_count": 5,
			"current_dice_type": "d6",
			"current_roll_number": 1,
			"dice": dice
		},
		"game_controller": {
			"active_power_up_ids": ["melting_dice"],
			"power_up_states": {"melting_dice": {"current_additive": 24.0}}
		}
	}


func _test_mid_round_resume() -> void:
	# Write through the real pipeline (covers the JSON float round-trip)
	GameSaveManager.save_snapshot(_fabricate_mid_round_3_state())
	_check("run save written", FileAccess.file_exists(_save_path))
	_check("save buffered as pending load", GameSaveManager.load_save_for_profile(_slot))
	if not GameSaveManager.has_pending_load():
		_check("pending load available for the game scene", false)
		return

	# Instantiate the real game scene; GameController._ready consumes the
	# pending load via call_deferred("load_game_state", ...)
	_game_scene = GAME_SCENE.instantiate()
	add_child(_game_scene)
	# Let the deferred load + restore settle
	for i in range(6):
		await get_tree().process_frame

	var game_controller = get_tree().get_first_node_in_group("game_controller")
	_check("game controller registered from instanced scene", game_controller != null)
	if game_controller == null:
		return

	var round_manager = game_controller.get("round_manager")
	_check("round manager present", round_manager != null)
	if round_manager:
		_check("current_round is int 2 (round 3, 0-based)", typeof(round_manager.current_round) == TYPE_INT and round_manager.current_round == 2)
		_check("get_current_round_number() == 3", round_manager.get_current_round_number() == 3)
		if round_manager.rounds_data.size() == 6:
			var round_1: Dictionary = round_manager.rounds_data[0]
			var round_2: Dictionary = round_manager.rounds_data[1]
			_check("round 1 completed survived as bool true", typeof(round_1.get("completed")) == TYPE_BOOL and round_1.get("completed") == true)
			_check("round 2 completed survived as bool true", typeof(round_2.get("completed")) == TYPE_BOOL and round_2.get("completed") == true)
		else:
			_check("rounds_data restored with 6 entries", false)

	_check("money is int 250 after load", typeof(PlayerEconomy.money) == TYPE_INT and PlayerEconomy.money == 250)

	var turn_tracker = game_controller.get("turn_tracker")
	_check("turn tracker present", turn_tracker != null)
	if turn_tracker:
		_check("current_turn is int 3", typeof(turn_tracker.current_turn) == TYPE_INT and turn_tracker.current_turn == 3)
		_check("rolls_left is int 2", typeof(turn_tracker.rolls_left) == TYPE_INT and turn_tracker.rolls_left == 2)
		_check("turn tracker is_active", turn_tracker.is_active == true)

	# Session-scoped UI state restored by _restore_session_ui_state()
	var roll_ui = get_tree().get_first_node_in_group("roll_button_ui")
	_check("roll button UI present", roll_ui != null)
	if roll_ui:
		_check("first_roll_done restored to true", roll_ui.get("first_roll_done") == true)
		var roll_button = roll_ui.get("roll_button")
		_check("roll button enabled after resume", roll_button != null and roll_button.disabled == false)

	var vcr_tracker = get_tree().get_first_node_in_group("turn_tracker_ui")
	_check("VCR turn tracker UI present", vcr_tracker != null)
	if vcr_tracker:
		var round_label = vcr_tracker.get("round_label")
		_check("VCR round label shows round 3", round_label != null and round_label.text.contains("3"))

	var dice_hand = game_controller.get("dice_hand")
	_check("dice hand present", dice_hand != null)
	if dice_hand:
		_check("5 dice restored", dice_hand.dice_list.size() == 5)
		if dice_hand.dice_list.size() == 5:
			var expected_values: Array = [1, 2, 3, 4, 5]
			var values_ok := true
			for i in range(5):
				if dice_hand.dice_list[i].value != expected_values[i]:
					values_ok = false
			_check("saved dice values restored", values_ok)
			_check("locked die restored locked", dice_hand.dice_list[2].is_locked == true)
			_check("unlocked dice restored unlocked", dice_hand.dice_list[0].is_locked == false and dice_hand.dice_list[4].is_locked == false)

	# Scorecard reveal on resume: the round intro hides ScoreCardUI and reveals
	# it via animate_entrance(); _restore_session_ui_state() re-runs that reveal
	# on the load path. animate_entrance sets visible/modulate synchronously.
	var score_card_ui = game_controller.get("score_card_ui")
	_check("scorecard UI present", score_card_ui != null)
	if score_card_ui:
		_check("scorecard UI visible after resume", score_card_ui.visible == true)
		_check("scorecard UI faded in after resume", score_card_ui.modulate.a > 0.0)

	# Power-up running state: the melt counter (current_additive) must survive
	# the load instead of resetting to the full +80 default.
	_check("melting_dice re-granted", game_controller.active_power_ups.has("melting_dice"))
	if game_controller.active_power_ups.has("melting_dice"):
		var melting_dice = game_controller.active_power_ups["melting_dice"]
		_check("melting_dice current_additive is int 24", typeof(melting_dice.current_additive) == TYPE_INT and melting_dice.current_additive == 24)
		_check("melting_dice additive registered at 24",
			ScoreModifierManager.has_additive("melting_dice") and ScoreModifierManager.get_additive("melting_dice") == 24)
