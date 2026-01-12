extends Control
class_name TutorialTest
## TutorialTest.gd
##
## Test scene for verifying tutorial system functionality.
## This scene provides mock game elements for isolated tutorial testing.

# --- Mock UI Elements ---
var mock_dice_tray: Control
var mock_score_card: Control
var mock_roll_button: Button
var mock_shop_button: Button
var mock_next_turn_button: Button
var mock_next_round_button: Button

# --- Test Output ---
var output_text: RichTextLabel
var status_label: Label

# --- Test State ---
var test_log: Array[String] = []


func _ready() -> void:
	name = "TutorialTest"
	# Ensure test UI works when game is paused during tutorial
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_ui()
	_connect_tutorial_signals()
	_log("Tutorial Test Scene Ready")
	_log("Press buttons below to test tutorial functionality")
	_update_status()


func _setup_ui() -> void:
	# Main container
	var main_split = HSplitContainer.new()
	main_split.anchor_right = 1.0
	main_split.anchor_bottom = 1.0
	add_child(main_split)
	
	# Left side - Mock game elements
	var mock_panel = PanelContainer.new()
	mock_panel.custom_minimum_size = Vector2(400, 0)
	main_split.add_child(mock_panel)
	
	var mock_vbox = VBoxContainer.new()
	mock_vbox.add_theme_constant_override("separation", 10)
	mock_panel.add_child(mock_vbox)
	
	# Title
	var mock_title = Label.new()
	mock_title.text = "Mock Game Elements"
	mock_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mock_title.add_theme_font_size_override("font_size", 20)
	mock_vbox.add_child(mock_title)
	
	# Mock dice tray (highlightable)
	mock_dice_tray = PanelContainer.new()
	mock_dice_tray.name = "DiceTray"
	mock_dice_tray.custom_minimum_size = Vector2(380, 100)
	mock_dice_tray.add_to_group("dice_tray")
	var dice_label = Label.new()
	dice_label.text = "Mock Dice Tray\n(Add to highlight)"
	dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mock_dice_tray.add_child(dice_label)
	mock_vbox.add_child(mock_dice_tray)
	
	# Mock score card (highlightable)
	mock_score_card = PanelContainer.new()
	mock_score_card.name = "ScoreCard"
	mock_score_card.custom_minimum_size = Vector2(380, 150)
	mock_score_card.add_to_group("score_card")
	var score_label = Label.new()
	score_label.text = "Mock Score Card\n(Add to highlight)"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mock_score_card.add_child(score_label)
	mock_vbox.add_child(mock_score_card)
	
	# Mock buttons
	var button_grid = GridContainer.new()
	button_grid.columns = 2
	button_grid.add_theme_constant_override("h_separation", 10)
	button_grid.add_theme_constant_override("v_separation", 10)
	mock_vbox.add_child(button_grid)
	
	mock_roll_button = Button.new()
	mock_roll_button.name = "RollButton"
	mock_roll_button.text = "Roll Dice"
	mock_roll_button.custom_minimum_size = Vector2(180, 40)
	mock_roll_button.pressed.connect(_on_mock_roll_pressed)
	button_grid.add_child(mock_roll_button)
	
	mock_shop_button = Button.new()
	mock_shop_button.name = "ShopButton"
	mock_shop_button.text = "Open Shop"
	mock_shop_button.custom_minimum_size = Vector2(180, 40)
	mock_shop_button.pressed.connect(_on_mock_shop_pressed)
	button_grid.add_child(mock_shop_button)
	
	mock_next_turn_button = Button.new()
	mock_next_turn_button.name = "NextTurnButton"
	mock_next_turn_button.text = "Next Turn"
	mock_next_turn_button.custom_minimum_size = Vector2(180, 40)
	mock_next_turn_button.pressed.connect(_on_mock_next_turn_pressed)
	button_grid.add_child(mock_next_turn_button)
	
	mock_next_round_button = Button.new()
	mock_next_round_button.name = "NextRoundButton"
	mock_next_round_button.text = "Next Round"
	mock_next_round_button.custom_minimum_size = Vector2(180, 40)
	mock_next_round_button.pressed.connect(_on_mock_next_round_pressed)
	button_grid.add_child(mock_next_round_button)
	
	# Right side - Test controls and output
	var test_panel = PanelContainer.new()
	main_split.add_child(test_panel)
	
	var test_vbox = VBoxContainer.new()
	test_vbox.add_theme_constant_override("separation", 10)
	test_panel.add_child(test_vbox)
	
	# Status label
	status_label = Label.new()
	status_label.text = "Status: Checking..."
	status_label.add_theme_font_size_override("font_size", 16)
	test_vbox.add_child(status_label)
	
	# Test buttons
	var test_title = Label.new()
	test_title.text = "Test Controls"
	test_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	test_title.add_theme_font_size_override("font_size", 18)
	test_vbox.add_child(test_title)
	
	var test_grid = GridContainer.new()
	test_grid.columns = 2
	test_grid.add_theme_constant_override("h_separation", 10)
	test_grid.add_theme_constant_override("v_separation", 5)
	test_vbox.add_child(test_grid)
	
	_add_test_button(test_grid, "Start Tutorial", _test_start_tutorial)
	_add_test_button(test_grid, "Skip Tutorial", _test_skip_tutorial)
	_add_test_button(test_grid, "Complete Step", _test_complete_step)
	_add_test_button(test_grid, "Advance Part", _test_advance_part)
	_add_test_button(test_grid, "Show State", _test_show_state)
	_add_test_button(test_grid, "List Steps", _test_list_steps)
	_add_test_button(test_grid, "Reset Progress", _test_reset_progress)
	_add_test_button(test_grid, "Clear Log", _clear_log)
	
	# Jump to step dropdown
	var jump_hbox = HBoxContainer.new()
	test_vbox.add_child(jump_hbox)
	
	var jump_label = Label.new()
	jump_label.text = "Jump to: "
	jump_hbox.add_child(jump_label)
	
	var step_option = OptionButton.new()
	step_option.name = "StepDropdown"
	step_option.custom_minimum_size = Vector2(200, 0)
	jump_hbox.add_child(step_option)
	_populate_step_dropdown(step_option)
	step_option.item_selected.connect(_on_step_selected)
	
	# Output area
	var output_label = Label.new()
	output_label.text = "Output Log"
	output_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	test_vbox.add_child(output_label)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	test_vbox.add_child(scroll)
	
	output_text = RichTextLabel.new()
	output_text.bbcode_enabled = true
	output_text.scroll_following = true
	output_text.custom_minimum_size = Vector2(380, 0)
	output_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(output_text)


func _add_test_button(parent: Control, text: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 35)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _populate_step_dropdown(dropdown: OptionButton) -> void:
	dropdown.clear()
	dropdown.add_item("-- Select Step --", 0)
	
	var tutorial_mgr = get_node_or_null("/root/TutorialManager")
	if not tutorial_mgr:
		return
	
	var step_ids = tutorial_mgr.get_all_step_ids()
	for i in range(step_ids.size()):
		var step_id = step_ids[i]
		var step = tutorial_mgr.get_step(step_id)
		var label = "%s - %s" % [step_id, step.title if step else "???"]
		dropdown.add_item(label, i + 1)


func _connect_tutorial_signals() -> void:
	var tutorial_mgr = get_node_or_null("/root/TutorialManager")
	if not tutorial_mgr:
		_log("[color=red]ERROR: TutorialManager not available![/color]")
		return
	
	tutorial_mgr.tutorial_started.connect(_on_tutorial_started)
	tutorial_mgr.tutorial_step_started.connect(_on_tutorial_step_started)
	tutorial_mgr.tutorial_part_advanced.connect(_on_tutorial_part_advanced)
	tutorial_mgr.tutorial_step_completed.connect(_on_tutorial_step_completed)
	tutorial_mgr.tutorial_completed.connect(_on_tutorial_completed)
	tutorial_mgr.tutorial_skipped.connect(_on_tutorial_skipped)
	_log("[color=green]Connected to TutorialManager signals[/color]")


func _log(message: String) -> void:
	var timestamp = Time.get_time_string_from_system()
	var full_message = "[%s] %s" % [timestamp, message]
	test_log.append(full_message)
	
	if output_text:
		output_text.append_text(full_message + "\n")
	
	print("[TutorialTest] %s" % message)


func _clear_log() -> void:
	test_log.clear()
	if output_text:
		output_text.clear()
	_log("Log cleared")


func _update_status() -> void:
	if not status_label:
		return
	
	var status_parts: Array[String] = []
	var tutorial_mgr = get_node_or_null("/root/TutorialManager")
	var progress_mgr = get_node_or_null("/root/ProgressManager")
	
	# TutorialManager status
	if tutorial_mgr:
		status_parts.append("[color=green]TutorialManager: OK[/color]")
		if tutorial_mgr.is_tutorial_active():
			status_parts.append("[color=yellow]Active: %s[/color]" % tutorial_mgr.current_step_id)
		else:
			status_parts.append("Inactive")
	else:
		status_parts.append("[color=red]TutorialManager: MISSING[/color]")
	
	# ProgressManager status
	if progress_mgr:
		var completed = "Yes" if progress_mgr.tutorial_completed else "No"
		status_parts.append("Completed: %s" % completed)
	
	status_label.text = " | ".join(status_parts)


# --- Mock Button Handlers ---

func _on_mock_roll_pressed() -> void:
	_log("Mock: Roll button pressed")
	var tutorial_mgr = get_node_or_null("/root/TutorialManager")
	if tutorial_mgr and tutorial_mgr.is_tutorial_active():
		if tutorial_mgr.is_action_allowed("roll_dice"):
			tutorial_mgr.action_completed("roll_dice")
			_log("  -> Action 'roll_dice' completed")
		else:
			_log("  -> Action 'roll_dice' not allowed at this step")
	_update_status()


func _on_mock_shop_pressed() -> void:
	_log("Mock: Shop button pressed")
	var tutorial_mgr = get_node_or_null("/root/TutorialManager")
	if tutorial_mgr and tutorial_mgr.is_tutorial_active():
		if tutorial_mgr.is_action_allowed("open_shop"):
			tutorial_mgr.action_completed("open_shop")
			_log("  -> Action 'open_shop' completed")
		else:
			_log("  -> Action 'open_shop' not allowed at this step")
	_update_status()


func _on_mock_next_turn_pressed() -> void:
	_log("Mock: Next turn button pressed")
	var tutorial_mgr = get_node_or_null("/root/TutorialManager")
	if tutorial_mgr and tutorial_mgr.is_tutorial_active():
		if tutorial_mgr.is_action_allowed("next_turn"):
			tutorial_mgr.action_completed("next_turn")
			_log("  -> Action 'next_turn' completed")
		else:
			_log("  -> Action 'next_turn' not allowed at this step")
	_update_status()


func _on_mock_next_round_pressed() -> void:
	_log("Mock: Next round button pressed")
	var tutorial_mgr = get_node_or_null("/root/TutorialManager")
	if tutorial_mgr and tutorial_mgr.is_tutorial_active():
		if tutorial_mgr.is_action_allowed("next_round"):
			tutorial_mgr.action_completed("next_round")
			_log("  -> Action 'next_round' completed")
		else:
			_log("  -> Action 'next_round' not allowed at this step")
	_update_status()


# --- Test Control Handlers ---

func _test_start_tutorial() -> void:
	_log("TEST: Starting tutorial...")
	var tutorial_mgr = get_node_or_null("/root/TutorialManager")
	if tutorial_mgr:
		tutorial_mgr.start_tutorial()
	_update_status()


func _test_skip_tutorial() -> void:
	_log("TEST: Skipping tutorial...")
	var tutorial_mgr = get_node_or_null("/root/TutorialManager")
	if tutorial_mgr:
		tutorial_mgr.skip_tutorial()
	_update_status()


func _test_complete_step() -> void:
	_log("TEST: Completing current step...")
	var tutorial_mgr = get_node_or_null("/root/TutorialManager")
	if tutorial_mgr and tutorial_mgr.is_tutorial_active():
		tutorial_mgr.complete_step()
	else:
		_log("  -> No active tutorial")
	_update_status()


func _test_advance_part() -> void:
	_log("TEST: Advancing part...")
	var tutorial_mgr = get_node_or_null("/root/TutorialManager")
	if tutorial_mgr and tutorial_mgr.is_tutorial_active():
		tutorial_mgr.advance_part()
	else:
		_log("  -> No active tutorial")
	_update_status()


func _test_show_state() -> void:
	_log("=== Tutorial State ===")
	var tutorial_mgr = get_node_or_null("/root/TutorialManager")
	var progress_mgr = get_node_or_null("/root/ProgressManager")
	if tutorial_mgr:
		_log("  Active: %s" % tutorial_mgr.is_tutorial_active())
		_log("  Current Step: %s" % tutorial_mgr.current_step_id)
		_log("  Current Part: %d" % tutorial_mgr.current_part)
		var step = tutorial_mgr.get_current_step()
		if step:
			_log("  Step Title: %s" % step.title)
			_log("  Required Action: %s" % step.required_action)
			_log("  Total Parts: %d" % step.total_parts)
	
	if progress_mgr:
		_log("  Completed (saved): %s" % progress_mgr.tutorial_completed)
		_log("  In Progress (saved): %s" % progress_mgr.tutorial_in_progress)
	_update_status()


func _test_list_steps() -> void:
	_log("=== All Tutorial Steps ===")
	var tutorial_mgr = get_node_or_null("/root/TutorialManager")
	if tutorial_mgr:
		var step_ids = tutorial_mgr.get_all_step_ids()
		_log("Total: %d steps" % step_ids.size())
		for step_id in step_ids:
			var step = tutorial_mgr.get_step(step_id)
			if step:
				var marker = " [CURRENT]" if tutorial_mgr.current_step_id == step_id else ""
				_log("  %s: %s (parts: %d)%s" % [step_id, step.title, step.total_parts, marker])


func _test_reset_progress() -> void:
	_log("TEST: Resetting tutorial progress...")
	var tutorial_mgr = get_node_or_null("/root/TutorialManager")
	var progress_mgr = get_node_or_null("/root/ProgressManager")
	if tutorial_mgr and tutorial_mgr.is_tutorial_active():
		tutorial_mgr.skip_tutorial()
	
	if progress_mgr:
		progress_mgr.tutorial_completed = false
		progress_mgr.tutorial_in_progress = false
		progress_mgr.save_current_profile()
		_log("  -> Progress reset, will auto-start on next game")
	_update_status()


func _on_step_selected(index: int) -> void:
	if index <= 0:
		return
	
	var tutorial_mgr = get_node_or_null("/root/TutorialManager")
	if not tutorial_mgr:
		return
	
	var step_ids = tutorial_mgr.get_all_step_ids()
	if index - 1 < step_ids.size():
		var step_id = step_ids[index - 1]
		_log("TEST: Jumping to step: %s" % step_id)
		tutorial_mgr.progress_to_step(step_id)
	_update_status()


# --- Tutorial Signal Handlers ---

func _on_tutorial_started() -> void:
	_log("[color=cyan]SIGNAL: tutorial_started[/color]")
	_update_status()


func _on_tutorial_step_started(step) -> void:
	_log("[color=cyan]SIGNAL: tutorial_step_started[/color]")
	_log("  Step: %s - %s" % [step.id, step.title])
	_update_status()


func _on_tutorial_part_advanced(step, part: int) -> void:
	_log("[color=cyan]SIGNAL: tutorial_part_advanced[/color]")
	_log("  Step: %s, Part: %d/%d" % [step.id, part, step.total_parts])
	_update_status()


func _on_tutorial_step_completed(step) -> void:
	_log("[color=cyan]SIGNAL: tutorial_step_completed[/color]")
	var step_id = step.id if step else "unknown"
	_log("  Completed: %s" % step_id)
	_update_status()


func _on_tutorial_completed() -> void:
	_log("[color=green]SIGNAL: tutorial_completed[/color]")
	_log("  Tutorial finished!")
	_update_status()


func _on_tutorial_skipped() -> void:
	_log("[color=orange]SIGNAL: tutorial_skipped[/color]")
	_update_status()
