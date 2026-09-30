extends Node

class StubGC extends Node:
	var channel_manager = null

func _ready() -> void:
	# Wait one frame so add_child to the root is allowed (root is busy during _ready)
	await get_tree().process_frame
	var cm := ChannelManager.new()
	var ok := true

	# Default state
	ok = _check("default difficulty is MEDIUM", cm.selected_difficulty == ChannelManager.Difficulty.MEDIUM) and ok
	ok = _check("default reward mult 1.0", cm.get_run_reward_multiplier() == 1.0) and ok
	ok = _check("default challenge mult 1.0", cm.get_run_challenge_multiplier() == 1.0) and ok
	ok = _check("default debuff modifier 0", cm.get_run_debuff_count_modifier() == 0) and ok
	ok = _check("default chore threshold 100", cm.get_chore_meter_threshold() == 100) and ok
	ok = _check("default carryover adjustment 0", cm.get_carryover_count_adjustment() == 0) and ok
	ok = _check("default debuff gate 4", cm.get_run_debuff_difficulty_gate() == 4) and ok

	# Easy
	cm.set_selected_difficulty(ChannelManager.Difficulty.EASY)
	ok = _check("easy reward mult 1.25", cm.get_run_reward_multiplier() == 1.25) and ok
	ok = _check("easy challenge mult 0.8", cm.get_run_challenge_multiplier() == 0.80) and ok
	ok = _check("easy debuff modifier -1", cm.get_run_debuff_count_modifier() == -1) and ok
	ok = _check("easy debuff gate 3", cm.get_run_debuff_difficulty_gate() == 3) and ok
	ok = _check("easy gate clamps cap, never raises", mini(2, cm.get_run_debuff_difficulty_gate()) == 2) and ok
	ok = _check("easy chore threshold 125", cm.get_chore_meter_threshold() == 125) and ok
	ok = _check("easy carryover adjustment +2", cm.get_carryover_count_adjustment() == 2) and ok
	ok = _check("easy display name", cm.get_difficulty_display_name() == "Easy") and ok

	# Hard
	cm.set_selected_difficulty(ChannelManager.Difficulty.HARD)
	ok = _check("hard reward mult 0.75", cm.get_run_reward_multiplier() == 0.75) and ok
	ok = _check("hard challenge mult 1.25", cm.get_run_challenge_multiplier() == 1.25) and ok
	ok = _check("hard debuff modifier +1", cm.get_run_debuff_count_modifier() == 1) and ok
	ok = _check("hard debuff gate 5", cm.get_run_debuff_difficulty_gate() == 5) and ok
	ok = _check("hard gate does not raise configured cap", mini(4, cm.get_run_debuff_difficulty_gate()) == 4) and ok
	ok = _check("hard chore threshold 75", cm.get_chore_meter_threshold() == 75) and ok
	ok = _check("hard carryover adjustment clamps to 0", maxi(0, 3 + cm.get_carryover_count_adjustment()) == 0) and ok

	# Save/load round-trip
	var state: Dictionary = cm.get_state()
	var cm2 := ChannelManager.new()
	cm2.load_state(state)
	ok = _check("load_state restores HARD", cm2.selected_difficulty == ChannelManager.Difficulty.HARD) and ok

	# Old save without the key defaults to MEDIUM
	var cm3 := ChannelManager.new()
	cm3.load_state({"current_channel": 2})
	ok = _check("old save defaults to MEDIUM", cm3.selected_difficulty == ChannelManager.Difficulty.MEDIUM) and ok

	# JSON-style float round-trip does not crash the enum
	var cm4 := ChannelManager.new()
	cm4.load_state({"selected_difficulty": 2.0})
	ok = _check("float save value coerces to HARD", cm4.selected_difficulty == ChannelManager.Difficulty.HARD) and ok

	# ChoresManager threshold lookup through the game_controller group
	var stub_gc := StubGC.new()
	stub_gc.channel_manager = cm3  # cm3 is at MEDIUM (threshold 100)
	stub_gc.add_to_group("game_controller")
	get_tree().root.add_child(stub_gc)
	var chores := ChoresManager.new()
	get_tree().root.add_child(chores)
	ok = _check("chores threshold via group (Medium=100)", chores.get_scaled_max_progress() == 100) and ok
	cm3.set_selected_difficulty(ChannelManager.Difficulty.HARD)
	ok = _check("chores threshold via group (Hard=75)", chores.get_scaled_max_progress() == 75) and ok
	stub_gc.channel_manager = null
	ok = _check("chores threshold falls back to 100", chores.get_scaled_max_progress() == 100) and ok
	chores.queue_free()
	stub_gc.queue_free()

	# Reset restores MEDIUM
	cm.set_selected_difficulty(ChannelManager.Difficulty.HARD)
	cm.reset()
	ok = _check("reset restores MEDIUM", cm.selected_difficulty == ChannelManager.Difficulty.MEDIUM) and ok

	cm.free()
	cm2.free()
	cm3.free()
	cm4.free()

	var result_text := "ALL PASS"
	var exit_code := 0
	if not ok:
		result_text = "FAILURES"
		exit_code = 1
	print("RESULT: %s" % result_text)
	get_tree().quit(exit_code)


func _check(label: String, condition: bool) -> bool:
	var status := "PASS"
	if not condition:
		status = "FAIL"
	print("%s: %s" % [status, label])
	return condition
