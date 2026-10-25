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
	if dice_hand.dice_list.size() < 5:
		_check(false, "Five real dice available")
		get_tree().quit(1)
		return

	ScoreModifierManager.reset()
	var safety_die = dice_hand.dice_list[0]
	var ordinary_die = dice_hand.dice_list[1]
	safety_die.add_mod(game_controller.mod_manager.get_def("safety_twos"))
	for die in dice_hand.dice_list:
		die.value = 1
	safety_die.value = 2
	ordinary_die.value = 2
	dice_hand.dice_list[4].value = 5
	game_controller.apply_debuff("disabled_twos")
	var disabled_twos = game_controller.active_debuffs.get("disabled_twos")
	_check(is_instance_valid(disabled_twos), "disabled_twos active")
	if is_instance_valid(disabled_twos):
		disabled_twos._on_roll_complete()
		_check(not safety_die.is_debuff_disabled_face_enabled(), "Safety 2's die is exempt")
		_check(ordinary_die.is_debuff_disabled_face_enabled(), "Ordinary two remains disabled")
		dice_hand._update_results()
		var values: Array[int] = []
		values.assign(DiceResults.values)
		_check(game_controller.scorecard.evaluate_category("twos", values) == 2, "Only Safety 2's contributes to Twos")
		_check(game_controller.scorecard.evaluate_category("chance", values) == 9, "Safety 2's contributes normally to Chance")
	game_controller.disable_debuff("disabled_twos", true)
	game.queue_free()
	await get_tree().process_frame
	print("Safety 2's verification failures: ", _failures)
	if _failures == 0:
		get_tree().quit(0)
	else:
		get_tree().quit(1)
