extends Node
class_name TutorialPaintedReproTest

var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[TutorialPaintedReproTest] PASS: " + label)
	else:
		_failures += 1
		push_error("[TutorialPaintedReproTest] FAIL: " + label)


func _run() -> void:
	var old_session: bool = TutorialManager.is_tutorial_session_active
	var old_active: bool = TutorialManager.is_active
	var old_progress: bool = TutorialManager.tutorial_in_progress_flag
	TutorialManager.is_tutorial_session_active = true
	TutorialManager.is_active = true
	TutorialManager.tutorial_in_progress_flag = true

	var game = load("res://Tests/DebuffTest.tscn").instantiate()
	add_child(game)
	for i in range(8):
		await get_tree().process_frame

	var controller = get_tree().get_first_node_in_group("game_controller")
	_check(is_instance_valid(controller), "full game controller available")
	if not is_instance_valid(controller):
		_finish(game, old_session, old_active, old_progress)
		return

	var gameplay := Node.new()
	gameplay.set_script(load("res://Scripts/Game/tutorial_gameplay.gd"))
	TutorialManager.add_child(gameplay)
	TutorialManager._gameplay = gameplay
	TutorialManager.current_step = TutorialManager.all_steps.get("mods_tab")
	TutorialManager.current_step_id = "mods_tab"
	gameplay.begin_session()
	await get_tree().process_frame

	var shop_item := _find_painted_shop_item(controller.shop_ui)
	_check(is_instance_valid(shop_item), "tutorial painted shop item exists")
	if is_instance_valid(shop_item):
		controller.shop_ui._on_item_purchase_requested(shop_item, "painted_die", "mod")
		for i in range(90):
			await get_tree().process_frame

	_check(controller.dice_hand.dice_list.size() == 5, "tutorial dice spawn after a pre-spawn painted purchase")
	var visible_count := 0
	var mod_count := 0
	for die in controller.dice_hand.dice_list:
		if is_instance_valid(die) and die.visible:
			visible_count += 1
		if is_instance_valid(die) and die.has_mod("painted_die"):
			mod_count += 1
	_check(visible_count == 0, "unrolled dice stay hidden after tutorial purchase")
	_check(mod_count == 1, "one painted mod remains attached after step advance")

	TutorialManager.current_step = TutorialManager.all_steps.get("start_first_round")
	TutorialManager.current_step_id = "start_first_round"
	var roll_ui = get_tree().get_first_node_in_group("roll_button_ui")
	roll_ui.roll_button.disabled = false
	roll_ui._roll_in_progress = false
	roll_ui._activate_round_start(1)
	for i in range(120):
		await get_tree().process_frame
	for die in controller.dice_hand.dice_list:
		print("[TutorialPaintedReproTest] post-roll ", die.name, " scale=", die.scale, " state=", die.get_state_name())
		_check(die.visible, "die becomes visible after tutorial roll: " + String(die.name))
		_check(die.scale.x > 0.5 and die.scale.y > 0.5, "die scale survives tutorial roll: " + String(die.name))

	for die in controller.dice_hand.dice_list:
		if die.has_mod("painted_die"):
			die.animate_exit(die.position + Vector2(100, 100))
			die.set_state(Dice.DiceState.ROLLABLE)
			die.roll()
			for i in range(60):
				await get_tree().process_frame
			_check(die.scale.x > 0.5 and die.scale.y > 0.5, "roll cancels stale exit scale animation")
			controller._on_mod_sold("painted_die", die)
			break
	_check(is_instance_valid(find_child("ModSaleBurst", true, false)), "gameplay mod sale emits fanfare burst")

	var no_carryovers: Array[String] = []
	controller._proceed_to_next_channel_with_carryovers(no_carryovers)
	roll_ui.roll_button.disabled = false
	roll_ui._roll_in_progress = false
	roll_ui._activate_round_start(1)
	for i in range(3):
		await get_tree().process_frame
	_check(controller.channel_manager.current_channel == 2, "zone 2 transition starts")
	_check(not controller.dice_hand.dice_list.is_empty(), "zone 2 dice hand spawned")
	for die in controller.dice_hand.dice_list:
		_check(not die.visible, "zone 2 unrolled die stays hidden: " + String(die.name))
	for i in range(120):
		await get_tree().process_frame
	for die in controller.dice_hand.dice_list:
		_check(die.visible, "zone 2 die appears after auto-roll: " + String(die.name))

	_finish(game, old_session, old_active, old_progress)


func _find_painted_shop_item(node: Node) -> ShopItem:
	if node is ShopItem and node.item_id == "painted_die":
		return node
	for child in node.get_children():
		var result := _find_painted_shop_item(child)
		if result:
			return result
	return null


func _finish(game: Node, old_session: bool, old_active: bool, old_progress: bool) -> void:
	if is_instance_valid(TutorialManager._gameplay):
		TutorialManager._gameplay.queue_free()
	TutorialManager._gameplay = null
	game.queue_free()
	TutorialManager.is_tutorial_session_active = old_session
	TutorialManager.is_active = old_active
	TutorialManager.tutorial_in_progress_flag = old_progress
	await get_tree().process_frame
	print("[TutorialPaintedReproTest] failures=%d" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
