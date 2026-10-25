extends Node

var _failures := 0

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	var game = load("res://Tests/DebuffTest.tscn").instantiate()
	get_tree().root.add_child(game)
	for i in range(5):
		await get_tree().process_frame
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if not is_instance_valid(game_controller):
		_check(false, "GameController available")
		get_tree().quit(1)
		return
	var dice_hand = game_controller.dice_hand
	dice_hand.dice_count = 5
	dice_hand.update_dice_count()
	await get_tree().process_frame
	if dice_hand.dice_list.is_empty():
		_check(false, "Dice available")
		get_tree().quit(1)
		return

	var die = dice_hand.dice_list[0]
	var definition = game_controller.mod_manager.get_def("only_ones")
	die.add_mod(definition)
	await get_tree().process_frame
	var tooltip_found := false
	for icon in die.mod_container.get_children():
		if icon is ModIcon and icon.data.id == "only_ones":
			tooltip_found = true
			_check(icon._tooltip._body_label.text == definition.description, "Tooltip body uses the mod description")
			_check(icon._tooltip._body_label.visible, "Tooltip description is visible")
	_check(tooltip_found, "Only 1s mod icon created")

	game_controller.scorecard.reset_scores()
	game_controller._current_round_target = 100
	game_controller._game_ended = false
	game_controller.round_manager.is_challenge_completed = false
	var only_mod = die.get_mod("only_ones")
	only_mod.trigger_probability = 0.01
	var panel = DebugPanel.instance
	_check(is_instance_valid(panel), "DebugPanel available")
	if is_instance_valid(panel):
		panel._debug_trigger_only_ones()
		_check(game_controller.scorecard.get_total_score() == 100, "Debug button fills the target gap")
		_check(game_controller.round_manager.is_challenge_completed, "Debug button uses normal round completion")
		_check(only_mod.trigger_probability == 0.01, "Debug button preserves the 0.01 probability")

	game.queue_free()
	await get_tree().process_frame
	print("Mod tooltip/debug verification failures: ", _failures)
	if _failures == 0:
		get_tree().quit(0)
	else:
		get_tree().quit(1)
