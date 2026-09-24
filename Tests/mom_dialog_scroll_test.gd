extends Node

## mom_dialog_scroll_test.gd
##
## Layer 6 of the Mom suite: dialog popup response coverage, extending the
## pattern of Tests/mom_dialog_ui_test.gd. The popup has NO scroll container
## (response_row is a VBoxContainer capped at MomCharacter.MAX_RESPONSES), so
## the "scroll the full list" requirement is implemented as: press every built
## button index and verify geometry containment inside the fixed panel.
##
## Run headless:
##   godot --headless --path . Tests/MomDialogScrollTest.tscn -- --quit-after
## Exit code 0 = all checks passed, 1 = at least one failure.

signal finished(failures: int)

const Harness = preload("res://Tests/mom_test_harness.gd")

var _reporter := Harness.Reporter.new()


func _ready() -> void:
	if get_tree().current_scene == self:
		var failures := await run_tests()
		if OS.get_cmdline_user_args().has("--quit-after"):
			get_tree().quit(failures)


func run_tests() -> int:
	print("[MomTests] --- Layer: dialog popup response coverage ---")
	_reporter = Harness.Reporter.new()

	var scene: PackedScene = load("res://Scenes/UI/mom_dialog_popup.tscn")
	_reporter.check("mom_dialog_popup.tscn loads", scene != null)
	if scene == null:
		finished.emit(_reporter.failures)
		return _reporter.failures
	var dialog = scene.instantiate()
	add_child(dialog)

	var scan := Harness.scan_dialog_nodes()
	var nodes: Dictionary = scan["nodes"]
	_reporter.check("dialog nodes scanned (%d)" % nodes.size(), nodes.size() > 0)

	var picked: Array = []
	dialog.response_selected.connect(func(index): picked.append(index))

	var response_nodes := 0
	var terminal_nodes := 0
	for node_id in nodes:
		var node: MomDialogNode = nodes[node_id]
		if node.is_terminal():
			terminal_nodes += 1
			_check_terminal_node(dialog, node)
		else:
			response_nodes += 1
			await _check_response_node(dialog, node, picked)

	_reporter.check("nodes with responses exercised (%d)" % response_nodes, response_nodes > 0)
	_reporter.check("terminal nodes exercised (%d)" % terminal_nodes, terminal_nodes > 0)

	# show_outcome_reply: OK button, no response row.
	dialog.show_outcome_reply("A parting reply.", "upset")
	_reporter.check("show_outcome_reply: response row hidden", not dialog.response_row.visible)
	_reporter.check("show_outcome_reply: close button visible", dialog.close_button.visible)

	remove_child(dialog)
	dialog.queue_free()

	if _reporter.failures == 0:
		print("[MomTests] PASS - dialog popup coverage (%d checks)" % _reporter.checks)
	else:
		print("[MomTests] FAIL - dialog popup coverage: %d/%d check(s) failed" % [_reporter.failures, _reporter.checks])
	finished.emit(_reporter.failures)
	return _reporter.failures


func _check_response_node(dialog, node: MomDialogNode, picked: Array) -> void:
	dialog.show_node(node)
	var expected_buttons: int = mini(node.responses.size(), MomCharacter.MAX_RESPONSES)
	_reporter.check("%s: response buttons built (%d of %d, cap %d)" % [node.id, dialog.response_buttons.size(), node.responses.size(), MomCharacter.MAX_RESPONSES],
		dialog.response_buttons.size() == expected_buttons)
	_reporter.check("%s: response row visible" % node.id, dialog.response_row.visible)
	_reporter.check("%s: close button hidden on response beat" % node.id, not dialog.close_button.visible)

	var geometry_ok := true
	var flags_ok := true
	for button in dialog.response_buttons:
		if button.custom_minimum_size.x < 400.0:
			flags_ok = false
		if button.size_flags_horizontal != Control.SIZE_EXPAND_FILL:
			flags_ok = false
	_reporter.check("%s: buttons >= 400px min and SIZE_EXPAND_FILL" % node.id, flags_ok)

	# Let layout settle, then verify containment inside the fixed panel.
	await dialog.get_tree().process_frame
	await dialog.get_tree().process_frame
	var panel_rect: Rect2 = dialog.dialog_panel.get_global_rect().grow(2.0)
	var overflow_detail := ""
	for i in range(dialog.response_buttons.size()):
		var button = dialog.response_buttons[i]
		if not panel_rect.encloses(button.get_global_rect()):
			geometry_ok = false
			overflow_detail += " button%d rect=%s" % [i, button.get_global_rect()]
	_reporter.check("%s: buttons contained in panel (panel rect=%s)%s" % [node.id, panel_rect, overflow_detail], geometry_ok)
	_reporter.check("%s: panel is PANEL_SIZE to the pixel (size=%s vs %s)" % [node.id, dialog.dialog_panel.size, MomCharacter.PANEL_SIZE],
		dialog.dialog_panel.size.round() == MomCharacter.PANEL_SIZE)

	# Press every built index; response_selected must fire with that index.
	var press_ok := true
	for index in range(dialog.response_buttons.size()):
		picked.clear()
		dialog.press_response(index)
		if picked != [index]:
			press_ok = false
			_reporter.check("%s: press_response(%d) emits response_selected(%d)" % [node.id, index, index], false)
	_reporter.check("%s: every built index routes through response_selected" % node.id, press_ok)
	# Out-of-range presses emit nothing.
	picked.clear()
	dialog.press_response(-1)
	dialog.press_response(dialog.response_buttons.size())
	_reporter.check("%s: out-of-range presses emit nothing" % node.id, picked.is_empty())


func _check_terminal_node(dialog, node: MomDialogNode) -> void:
	dialog.show_node(node)
	_reporter.check("%s: terminal beat hides response row" % node.id, not dialog.response_row.visible)
	_reporter.check("%s: terminal beat shows close button" % node.id, dialog.close_button.visible)
