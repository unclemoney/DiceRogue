extends Node

var _failures := 0
var _game: Node
var _profile_path := ""
var _run_path := ""
var _profile_bytes := PackedByteArray()
var _run_bytes := PackedByteArray()
var _had_profile := false
var _had_run := false


func _ready() -> void:
	var slot: int = GameSettings.active_profile_slot
	_profile_path = "user://profile_%d.save" % slot
	_run_path = GameSaveManager.get_save_path(slot)
	_had_profile = FileAccess.file_exists(_profile_path)
	_had_run = FileAccess.file_exists(_run_path)
	if _had_profile:
		_profile_bytes = FileAccess.get_file_as_bytes(_profile_path)
	if _had_run:
		_run_bytes = FileAccess.get_file_as_bytes(_run_path)
	TutorialManager.reset_tutorial()
	call_deferred("_run")
	call_deferred("_watchdog")


func _watchdog() -> void:
	await get_tree().create_timer(60.0).timeout
	push_error("[TutorialFlowTest] FAIL: watchdog expired at " + TutorialManager.current_step_id)
	_restore(_profile_path, _had_profile, _profile_bytes)
	_restore(_run_path, _had_run, _run_bytes)
	get_tree().quit(2)


func _run() -> void:
	await get_tree().create_timer(1.4).timeout
	_game = get_tree().get_first_node_in_group("game_controller")
	_check("Tutorial starts", TutorialManager.is_active and _game != null)
	if not _game:
		_finish()
		return
	await _next_to("shop_overview")
	_check("Shop button enabled for kiosk lesson", not _game.game_button_ui.shop_button.disabled)
	_game.game_button_ui._on_shop_button_pressed()
	await get_tree().create_timer(0.8).timeout
	_check("Shop opens on POG purchase", TutorialManager.current_step_id == "buy_pog")
	await _buy("step_by_step", "powerups_intro", 0)
	await _next_to("coupons_tab")
	await _tab_to(1, "consumables_intro")
	await _buy("quick_cash", "mods_tab", 1)
	await _tab_to(2, "challenges_intro")
	await _buy("painted_die", "colors_tab", 2)
	await _tab_to(3, "debuffs_intro")
	await _buy("green_dice", "chores_intro", 3)
	_game.shop_ui._on_close_button_pressed()
	await get_tree().create_timer(0.8).timeout
	_check("Shop close reaches next round lesson", TutorialManager.current_step_id == "start_first_round")
	_game.game_button_ui._on_next_round_button_pressed()
	await get_tree().create_timer(0.6).timeout
	_check("Round panel opens", _game._new_round_panel != null)
	if not _game._new_round_panel:
		_finish()
		return
	_game._new_round_panel._on_lets_play_pressed()
	await _wait_for_step("chore_select")
	await get_tree().create_timer(0.9).timeout
	_check("Chore fixture is Use Item", _game.chores_manager.get_pending_tasks().easy.id == "use_consumable")
	if not _game._chore_selection_popup:
		_finish()
		return
	_game._chore_selection_popup._on_task_selected(false)
	await get_tree().create_timer(0.7).timeout
	_check("Chore selection advances", TutorialManager.current_step_id == "chores_mood")
	_game.consumable_ui._on_spine_clicked("quick_cash")
	await get_tree().create_timer(0.7).timeout
	_game.consumable_ui._on_consumable_used("quick_cash")
	await get_tree().create_timer(0.8).timeout
	_check("Real Coupon use advances", TutorialManager.current_step_id == "synergy_intro")
	_check("Coupon completes Use Item chore", _game.chores_manager.tasks_completed >= 1)
	if _game._chore_selection_popup:
		_game._chore_selection_popup._on_task_selected(false)
	await get_tree().create_timer(0.7).timeout
	_check("Replacement chore advances", TutorialManager.current_step_id == "chore_results")
	await _next_to("roll_button")
	await _roll_to("lock_dice")
	_game.dice_hand.dice_list[0].toggle_lock()
	await get_tree().create_timer(0.4).timeout
	_check("Real lock advances", TutorialManager.current_step_id == "roll_again")
	await _roll_to("synergy_rainbow")
	await _roll_to("scorecard_intro")
	await _next_to("score_action")
	_game.score_card_ui._on_row_pressed("ones")
	await get_tree().create_timer(0.7).timeout
	_check("Real scoring advances", TutorialManager.current_step_id == "next_turn_button")
	_game.game_button_ui._on_next_turn_button_pressed()
	await get_tree().create_timer(0.7).timeout
	_check("Next turn reaches Goof-Off Meter lesson", TutorialManager.current_step_id == "goof_off_meter")
	await _next_to("punishment_roll")
	await _roll_to("mom_punishment_response")
	await get_tree().create_timer(0.6).timeout
	_game._mom_dialog._on_response_pressed(1)
	await get_tree().create_timer(0.8).timeout
	if _game._mom_dialog.visible:
		_game._mom_dialog._on_close_pressed()
	await _wait_for_step("punishment_results")
	_check("Punishment was meter visit", TutorialManager.last_mom_summary.get("is_meter_visit", false))
	await _next_to("checkin_roll")
	await _roll_to("mom_checkin_response")
	await get_tree().create_timer(0.6).timeout
	_check("Check-in creates Mom dialog", _game._mom_dialog != null and _game._mom_dialog.visible)
	_game._mom_dialog._on_response_pressed(0)
	await get_tree().create_timer(0.8).timeout
	if _game._mom_dialog.visible:
		_game._mom_dialog._on_close_pressed()
	await _wait_for_step("mom_buff_results")
	await _next_to("next_round_button")
	await _next_to("tutorial_complete")
	TutorialManager._tutorial_dialog._on_next_pressed()
	TutorialManager._on_dialog_next()
	reparent(get_tree().root)
	await get_tree().create_timer(2.0).timeout
	_check("Finish reaches Main Menu", get_tree().current_scene.name == "MainMenu")
	_check("Finish marks tutorial complete", TutorialManager.tutorial_completed_flag and not TutorialManager.is_tutorial_session_active)
	_check("Finish leaves no tutorial save", _had_run or not FileAccess.file_exists(_run_path))
	if _had_run:
		_check("Finish preserves existing save", FileAccess.get_file_as_bytes(_run_path) == _run_bytes)
	_finish()


func _next_to(step_id: String) -> void:
	var guard := 0
	while TutorialManager.current_step_id != step_id and guard < 20:
		guard += 1
		var step = TutorialManager.current_step
		if not step or step.required_action != "click_continue":
			_check("Explanation path reaches " + step_id, false)
			return
		TutorialManager._tutorial_dialog._on_next_pressed()
		TutorialManager._on_dialog_next()
		await get_tree().create_timer(0.32).timeout
	_check("Explanation path reaches " + step_id, TutorialManager.current_step_id == step_id)


func _wait_for_step(step_id: String) -> void:
	for index in range(120):
		if TutorialManager.current_step_id == step_id:
			_check("Reached " + step_id, true)
			return
		await get_tree().create_timer(0.1).timeout
	_check("Reached " + step_id, false)


func _roll_to(step_id: String) -> void:
	var roll_ui = get_tree().get_first_node_in_group("roll_button_ui")
	for index in range(50):
		if not roll_ui._roll_in_progress and roll_ui._button_action_cooldown <= 0.0:
			break
		await get_tree().create_timer(0.1).timeout
	roll_ui._on_roll_button_pressed()
	await _wait_for_step(step_id)


func _tab_to(tab_index: int, next_id: String) -> void:
	var tab_name := "coupons" if tab_index == 1 else "mods" if tab_index == 2 else "colors"
	var target = TutorialManager._gameplay.resolve_target("shop_tab:" + tab_name)
	_check("Semantic tab target exists: " + tab_name, target != null and target.size.x > 0.0)
	_game.shop_ui.tab_container.current_tab = tab_index
	await get_tree().create_timer(0.4).timeout
	_check("Tab selection advances: " + tab_name, TutorialManager.current_step_id == next_id)


func _buy(item_id: String, next_id: String, tab: int) -> void:
	_game.shop_ui.tab_container.current_tab = tab
	var item = TutorialManager._gameplay._find_shop_item(item_id)
	_check("Fixture shop item exists: " + item_id, item != null)
	if not item:
		return
	var shop_item: Node = item
	while shop_item and not shop_item is ShopItem:
		shop_item = shop_item.get_parent()
	_check("Buy button belongs to ShopItem", shop_item != null)
	if shop_item:
		shop_item._on_buy_button_pressed()
	await get_tree().create_timer(0.65).timeout
	_check("Purchase advances: " + item_id, TutorialManager.current_step_id == next_id)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[TutorialFlowTest] PASS: " + label)
	else:
		_failures += 1
		push_error("[TutorialFlowTest] FAIL: " + label)


func _finish() -> void:
	_restore(_profile_path, _had_profile, _profile_bytes)
	_restore(_run_path, _had_run, _run_bytes)
	print("[TutorialFlowTest] %s" % ("PASS" if _failures == 0 else "FAIL: %d" % _failures))
	if OS.get_cmdline_user_args().has("--tutorial-test"):
		get_tree().quit(0 if _failures == 0 else 1)


func _restore(path: String, existed: bool, bytes: PackedByteArray) -> void:
	if existed:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_buffer(bytes)
			file.close()
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
