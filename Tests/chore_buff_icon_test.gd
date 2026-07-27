extends Node

## chore_buff_icon_test.gd
##
## Verifies the ChoreUI buff icon API (home of the Rebellion buff):
##   1. add_buff_icon() shows a compact chip in BuffIconRow and a fan-out
##      chip + label in BuffDetailRow.
##   2. Duplicate adds reuse the existing chip.
##   3. remove_buff_icon() / clear_buff_icons() hide and reset the rows.
##
## Scene-based test (autoloads must be compiled first).
## Run headless:
##   godot --headless --path . Tests/ChoreBuffIconTest.tscn -- --quit-after
## Exit code 0 = all checks passed, 1 = at least one failure.

const CHORE_UI_SCENE: PackedScene = preload("res://Scenes/UI/chore_ui.tscn")
const REBELLION_DATA: DebuffData = preload("res://Scripts/Debuff/RebellionBuff.tres")

var _failures: int = 0


func _ready() -> void:
	print("[ChoreBuffIconTest] Starting")
	var ui = CHORE_UI_SCENE.instantiate()
	add_child(ui)

	_test_add_buff_icon(ui)
	_test_duplicate_add(ui)
	_test_remove_buff_icon(ui)
	_test_clear_buff_icons(ui)

	ui.queue_free()

	if _failures == 0:
		print("[ChoreBuffIconTest] PASS - all checks passed")
	else:
		print("[ChoreBuffIconTest] FAIL - %d check(s) failed" % _failures)

	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(0 if _failures == 0 else 1)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[ChoreBuffIconTest] OK: " + label)
	else:
		push_error("[ChoreBuffIconTest] FAILED: " + label)
		_failures += 1


func _test_add_buff_icon(ui) -> void:
	_check("buff rows start hidden", not ui.buff_icon_row.visible and not ui.buff_detail_row.visible)
	var icon = ui.add_buff_icon(REBELLION_DATA)
	_check("add_buff_icon() returns a chip", icon != null)
	_check("chip registered by id", ui._buff_icons.has("rebellion"))
	_check("compact row shown", ui.buff_icon_row.visible)
	_check("fan-out row shown", ui.buff_detail_row.visible)
	_check("fan-out chip built", ui._buff_detail_icons.has("rebellion"))
	_check("fan-out label shows name and stacks",
		ui._buff_detail_labels.has("rebellion") and ui._buff_detail_labels["rebellion"].text == "Rebellion  x1")


func _test_duplicate_add(ui) -> void:
	var first = ui._buff_icons["rebellion"]
	var again = ui.add_buff_icon(REBELLION_DATA)
	_check("duplicate add returns the same chip", again == first)
	_check("duplicate add keeps one chip", ui._buff_icons.size() == 1)


func _test_remove_buff_icon(ui) -> void:
	ui.remove_buff_icon("nonexistent_buff")
	_check("removing an unknown id is a no-op", ui._buff_icons.size() == 1)
	ui.remove_buff_icon("rebellion")
	_check("remove_buff_icon() unregisters the chip", not ui._buff_icons.has("rebellion"))
	_check("compact row hides when empty", not ui.buff_icon_row.visible)
	_check("fan-out row hides when empty", not ui.buff_detail_row.visible)
	_check("fan-out entries cleared", ui._buff_detail_icons.is_empty() and ui._buff_detail_labels.is_empty())


func _test_clear_buff_icons(ui) -> void:
	ui.add_buff_icon(REBELLION_DATA)
	_check("chip re-added for clear test", ui._buff_icons.size() == 1)
	ui.clear_buff_icons()
	_check("clear_buff_icons() empties the registry", ui._buff_icons.is_empty())
	_check("compact row hidden after clear", not ui.buff_icon_row.visible)
	_check("fan-out row hidden after clear", not ui.buff_detail_row.visible)
