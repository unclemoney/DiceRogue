extends Node

## mom_dialog_ui_test.gd
##
## Verifies the MomDialogPopup response-button layout:
## response buttons stack vertically in a wide column so full-sentence
## response texts fit.
##
## Scene-based test (autoloads must be compiled first).
## Run headless:
##   godot --headless --path . Tests/MomDialogUITest.tscn -- --quit-after
## Exit code 0 = all checks passed, 1 = at least one failure.

const Handler := preload("res://Scripts/Core/mom_logic_handler.gd")

var _failures: int = 0


func _ready() -> void:
	print("[MomDialogUITest] Starting")
	var scene: PackedScene = load("res://Scenes/UI/mom_dialog_popup.tscn")
	var dialog = scene.instantiate()
	add_child(dialog)

	var node := Handler.get_dialog_node("checkin_neutral")
	dialog.show_node(node)

	_check("response row is a VBoxContainer", dialog.response_row is VBoxContainer)
	_check("response row visible with responses", dialog.response_row.visible)
	_check("3 response buttons built", dialog.response_buttons.size() == 3)
	if dialog.response_buttons.size() > 0:
		var button = dialog.response_buttons[0]
		_check("buttons are wide (>= 400px min)", button.custom_minimum_size.x >= 400.0)
		_check("buttons expand horizontally", button.size_flags_horizontal == Control.SIZE_EXPAND_FILL)
	_check("close button hidden on response beat", not dialog.close_button.visible)

	# Terminal node: OK button shown, response row hidden
	dialog.show_node(Handler.get_dialog_node("sass_storm_off"))
	_check("response row hidden on terminal beat", not dialog.response_row.visible)
	_check("close button visible on terminal beat", dialog.close_button.visible)

	# press_response routes through response_selected
	var picked: Array = [-1]
	dialog.response_selected.connect(func(index): picked[0] = index)
	dialog.show_node(node)
	dialog.press_response(1)
	_check("press_response emits response_selected", picked[0] == 1)

	if _failures == 0:
		print("[MomDialogUITest] PASS - all checks passed")
	else:
		print("[MomDialogUITest] FAIL - %d check(s) failed" % _failures)

	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(0 if _failures == 0 else 1)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[MomDialogUITest] OK: " + label)
	else:
		push_error("[MomDialogUITest] FAILED: " + label)
		_failures += 1
