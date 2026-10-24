extends Node

const ChoreTasksLibraryScript = preload("res://Scripts/Managers/chore_tasks_library.gd")

var _manager: Node
var _game: Node
var _shop: Node
var _chores: Node
var _connected := false
var _tab_targets: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if not _manager or not _manager.is_active or not _manager.current_step:
		return
	var target_id: String = _manager.current_step.semantic_target
	if target_id == "" or not _manager._tutorial_highlight:
		return
	var target := resolve_target(target_id)
	if target and target != _manager._tutorial_highlight.target_node:
		_manager._tutorial_highlight.show_highlight(target, _manager.current_step.show_click_indicator, _manager.current_step.highlight_size, _manager.current_step.highlight_offset, _manager.current_step.show_backdrop, _manager.current_step.indicator_offset)


func begin_session() -> void:
	_game = get_tree().get_first_node_in_group("game_controller")
	if not _game:
		return
	_manager = get_node_or_null("/root/TutorialManager")
	_shop = _game.shop_ui
	_shop.tutorial_stock_override = true
	_chores = _game.chores_manager
	_connect_events()
	_prepare_stock()
	_prepare_initial_chore()
	if PlayerEconomy:
		PlayerEconomy.add_money(500)


func _connect_events() -> void:
	if _connected:
		return
	_connected = true
	if _shop:
		_shop.item_purchased.connect(_on_item_purchased)
		_shop.shop_button_opened.connect(func(): _complete("click_shop"))
		_shop.shop_close_finished.connect(func(): _complete("close_shop"))
		_shop.tab_container.tab_changed.connect(_on_shop_tab_changed)
	if _chores:
		_chores.task_selected.connect(_on_task_selected)
		_chores.task_completed.connect(_on_task_completed)
		_chores.request_chore_selection.connect(_on_chore_selection_requested)
	if _game.scorecard:
		_game.scorecard.score_assigned.connect(_on_score_assigned)
	_game.consumable_used.connect(_on_consumable_used)
	_game.mom_visit_finished.connect(_on_mom_visit_finished)
	if _game.round_manager:
		_game.round_manager.round_started.connect(func(_round = null): _complete("click_next_round"))


func _on_chore_selection_requested() -> void:
	if not _manager or _manager.current_step_id not in ["start_first_round", "chore_select"]:
		return
	_prepare_initial_chore()
	if _game._chore_selection_popup:
		_game._chore_selection_popup.show_popup(_chores)


func _prepare_stock() -> void:
	if not _shop:
		return
	_shop._set_tab_item_pool("power_up", [_game.pu_manager.get_def("step_by_step")])
	_shop._set_tab_item_pool("consumable", [_game.consumable_manager.get_def("quick_cash")])
	_shop._set_tab_item_pool("mod", [_game.mod_manager.get_def("painted_die")])
	_shop._set_tab_item_pool("colored_dice", [DiceColorManager.get_colored_dice_data("green_dice")])
	for item_type in ["power_up", "consumable", "mod", "colored_dice"]:
		_shop._render_current_page(item_type)


func _prepare_initial_chore() -> void:
	if not _chores:
		return
	_chores._pending_easy_task = ChoreTasksLibraryScript.get_task_by_id("use_consumable", 6)
	_chores._pending_hard_task = ChoreTasksLibraryScript.get_task_by_id("score_ones", 6)


func prepare_step(step) -> void:
	if not _game:
		return
	match step.id:
		"shop_overview":
			_game.game_button_ui._set_button_disabled(_game.game_button_ui.shop_button, false)
		"checkin_roll":
			_chores.adjust_mood(1 - _chores.mom_mood)
			_chores._checkin_done_this_round = false
			_chores._checkin_roll_target = _chores._rolls_this_round + 1
			_game.cast_manager.debug_forced_claim = {"tree_id": "checkin_cool_mom", "context": {}}
		"punishment_roll":
			_chores.adjust_mood(8 - _chores.mom_mood)
			_chores.grudge = 0
			_chores.defer_streak = 0
			_chores.low_mood_visits_this_run = 0
			_chores.set_progress(_chores.get_scaled_max_progress() - 1)
			_chores._checkin_done_this_round = true
		"mom_punishment_response":
			_set_punishment_choices()


func _set_punishment_choices() -> void:
	if not _game._mom_dialog:
		return
	for index in range(_game._mom_dialog.response_buttons.size()):
		_game._mom_dialog.response_buttons[index].disabled = index != 1


func can_go_back() -> bool:
	return _chores == null or not _chores.is_mom_active


func is_action_allowed(action: String) -> bool:
	if not _manager or not _manager.current_step:
		return true
	if _manager.completed_step_ids.has(_manager.current_step_id):
		return true
	if action in ["click_continue", "menu", "open_chore_details"]:
		return true
	if action == "click_roll" and _manager.current_step_id in ["start_first_round", "chore_select"]:
		return true
	return _manager.current_step.required_action == action


func resolve_target(target_id: String) -> CanvasItem:
	if not _game:
		return null
	if target_id.begins_with("shop_item:"):
		return _find_shop_item(target_id.trim_prefix("shop_item:"))
	if target_id == "shop:close":
		return _shop.close_button if _shop else null
	if target_id.begins_with("shop_tab:"):
		var tab_name := target_id.trim_prefix("shop_tab:")
		var tab_indices := {"pogs": 0, "coupons": 1, "mods": 2, "colors": 3}
		if tab_indices.has(tab_name):
			return _resolve_shop_tab(tab_indices[tab_name])
	if target_id == "chore_option:easy":
		if _game._chore_selection_popup:
			return _game._chore_selection_popup.find_child("EasyCard", true, false)
	if target_id.begins_with("mom_response:"):
		if _game._mom_dialog:
			var index := target_id.trim_prefix("mom_response:").to_int()
			var buttons: Array = _game._mom_dialog.response_buttons
			if index >= 0 and index < buttons.size():
				return buttons[index]
	if target_id.begins_with("coupon:"):
		var coupon_id := target_id.trim_prefix("coupon:")
		var icon = _game.consumable_ui.get_fanned_icon(coupon_id)
		if icon:
			return icon.use_button
		return _game.consumable_ui.get_consumable_spine(coupon_id)
	return null


func _resolve_shop_tab(tab_index: int) -> Control:
	if not _tab_targets.has(tab_index) or not is_instance_valid(_tab_targets[tab_index]):
		var target := Control.new()
		target.name = "TutorialTabTarget%d" % tab_index
		target.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shop.add_child(target)
		_tab_targets[tab_index] = target
	var tab_bar: TabBar = _shop.tab_container.get_tab_bar()
	var tab_rect := tab_bar.get_tab_rect(tab_index)
	var target: Control = _tab_targets[tab_index]
	target.global_position = tab_bar.global_position + tab_rect.position
	target.size = tab_rect.size
	return target


func _find_shop_item(item_id: String) -> CanvasItem:
	if not _shop:
		return null
	return _find_item_recursive(_shop, item_id)


func _find_item_recursive(node: Node, item_id: String) -> CanvasItem:
	if node is ShopItem and node.item_id == item_id:
		return node.buy_button
	for child in node.get_children():
		var result := _find_item_recursive(child, item_id)
		if result:
			return result
	return null


func _complete(action: String, payload: Dictionary = {}) -> void:
	if _manager:
		_manager.action_completed(action, payload)


func _on_shop_tab_changed(tab_index: int) -> void:
	_complete("shop_tab_changed", {"tab_index": tab_index})


func _on_item_purchased(item_id: String, item_type: String) -> void:
	_complete("purchase_item", {"item_id": item_id, "item_type": item_type})


func _on_task_selected(task) -> void:
	if not task:
		return
	_complete("select_chore", {"chore_id": task.id})


func _on_task_completed(task) -> void:
	if task:
		_complete("complete_chore", {"chore_id": task.id})


func _on_score_assigned(_category, _score, _level = null) -> void:
	_complete("click_scorecard")


func _on_consumable_used(consumable_id: String, _consumable) -> void:
	_complete("use_consumable", {"item_id": consumable_id})


func _on_mom_visit_finished(summary: Dictionary) -> void:
	if _manager:
		_manager.last_mom_summary = summary.duplicate(true)
	if _game._mom_dialog:
		for button in _game._mom_dialog.response_buttons:
			button.disabled = false
	_complete("mom_response", {"is_meter_visit": summary.get("is_meter_visit", false)})
