extends Control
class_name TutorialTest

var _failures := 0
var _manager: Node
var _old_completed := false
var _old_in_progress := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_manager = get_node_or_null("/root/TutorialManager")
	_check("TutorialManager exists", _manager != null)
	if not _manager:
		_finish()
		return
	_old_completed = ProgressManager.tutorial_completed
	_old_in_progress = ProgressManager.tutorial_in_progress
	_check("All resources form one chain", _manager.step_order.size() == _manager.all_steps.size())
	_check("Expanded guided sequence", _manager.step_order.size() >= 39)
	_check("Chain reaches final step", _manager.step_order.back() == "tutorial_complete")
	_manager.start_tutorial()
	await get_tree().create_timer(0.1).timeout
	_check("Starts at intro", _manager.current_step_id == "intro")
	if OS.get_cmdline_user_args().has("--screenshot"):
		_manager._tutorial_dialog._on_next_pressed()
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_png("res://Tests/_layout_shots/tutorial_dialog.png")
	_check("Back disabled at intro", not _manager.can_go_back())
	var target := Control.new()
	target.custom_minimum_size = Vector2(80, 40)
	target.size = Vector2(80, 40)
	add_child(target)
	_manager._tutorial_highlight.show_highlight(target, true, Vector2.ZERO, Vector2.ZERO, false)
	var indicator_home: Vector2 = _manager._tutorial_highlight.click_indicator.position
	_manager._tutorial_highlight.show_highlight(target, true, Vector2.ZERO, Vector2.ZERO, false, Vector2(12, 34))
	_check("Indicator offset is independent", _manager._tutorial_highlight.click_indicator.position == indicator_home + Vector2(12, 34))
	target.queue_free()
	_manager.previous_step()
	_check("Back at intro is a no-op", _manager.current_step_id == "intro")
	_manager._tutorial_dialog._on_next_pressed()
	_check("First Next reveals text", _manager._tutorial_dialog._typing_complete)
	_manager._on_dialog_next()
	await get_tree().create_timer(0.35).timeout
	_check("Second Next advances", _manager.current_step_id == "yahtzee_basics_1")
	_manager.jump_to_step("buy_pog")
	await get_tree().create_timer(0.6).timeout
	_check("Action step disables Next", _manager._tutorial_dialog.next_button.disabled)
	_manager.action_completed("purchase_item", {"item_id": "wrong", "item_type": "power_up"})
	_check("Wrong purchase payload rejected", _manager.current_step_id == "buy_pog")
	_manager.action_completed("purchase_item", {"item_id": "step_by_step", "item_type": "power_up"})
	_manager.action_completed("purchase_item", {"item_id": "step_by_step", "item_type": "power_up"})
	await get_tree().create_timer(0.4).timeout
	_check("Committed purchase advances once", _manager.current_step_id == "powerups_intro")
	_check("Explanation step enables Next", not _manager._tutorial_dialog.next_button.disabled)
	var grant_count: int = _manager.granted_step_ids.size()
	_manager.previous_step()
	await get_tree().create_timer(0.35).timeout
	_check("Back revisits completed action", _manager.current_step_id == "buy_pog")
	_check("Completed action enables Next on revisit", not _manager._tutorial_dialog.next_button.disabled)
	_manager._on_dialog_next()
	await get_tree().create_timer(0.35).timeout
	_check("Completed action can be advanced", _manager.current_step_id == "powerups_intro")
	_check("Revisit does not repeat setup", _manager.granted_step_ids.size() == grant_count)
	_manager.jump_to_step("checkin_roll")
	_manager.reset_tutorial()
	await get_tree().create_timer(0.6).timeout
	_check("Reset clears current step", _manager.current_step == null)
	_check("Reset stops session", not _manager.is_tutorial_session_active)
	_check("Reset clears pause", not get_tree().paused)
	ProgressManager.tutorial_completed = _old_completed
	ProgressManager.tutorial_in_progress = _old_in_progress
	ProgressManager.save_current_profile()
	_finish()


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[TutorialTest] PASS: " + label)
	else:
		_failures += 1
		push_error("[TutorialTest] FAIL: " + label)


func _finish() -> void:
	print("[TutorialTest] %s" % ("PASS" if _failures == 0 else "FAIL: %d" % _failures))
	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(0 if _failures == 0 else 1)
