extends Control

## chore_ui_layout_test.gd
##
## Visual + rect regression test for the Chore UI overflowing its
## ChoreMeterContainer panel in the left column.
##
## Instances the REAL Scenes/UI/GameUI.tscn (layout built by game_ui.gd),
## wires a real ChoresManager so the ChoreUI populates, and adds a Rebellion
## buff chip so the BuffIconRow slot is filled. After layout settles it:
##   1. Prints global_rect diagnostics for the whole chore subtree.
##   2. Saves a screenshot to Tests/_layout_shots/chore_ui_layout.png.
##   3. Asserts the ChoreUI/CompactShell stay inside ChoreMeterContainer and
##      that its right edge matches the DebuffContainer right edge.
##
## Needs a real rendering driver — run WITHOUT --headless:
##   godot --path . Tests/ChoreUILayoutTest.tscn -- --quit-after
## Exit code 0 = all checks passed, 1 = at least one failure.

const GAME_UI_SCENE: PackedScene = preload("res://Scenes/UI/GameUI.tscn")
const ChoresManagerScript = preload("res://Scripts/Managers/ChoresManager.gd")
const REBELLION_DATA: DebuffData = preload("res://Scripts/Debuff/RebellionBuff.tres")

const SHOT_DIR := "res://Tests/_layout_shots"
const SHOT_PATH := SHOT_DIR + "/chore_ui_layout.png"
const EPSILON: float = 1.0

var _failures: int = 0


func _ready() -> void:
	print("[ChoreUILayoutTest] Starting")
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var game_ui = GAME_UI_SCENE.instantiate()
	add_child(game_ui)

	var chores_manager = ChoresManagerScript.new()
	chores_manager.name = "ChoresManager"
	add_child(chores_manager)

	game_ui.chore_ui.set_chores_manager(chores_manager)
	game_ui.chore_ui.add_buff_icon(REBELLION_DATA)

	# Let deferred init (manager wiring, fan-out reparenting) and layout settle.
	for i in range(12):
		await get_tree().process_frame

	_print_diagnostics(game_ui)
	_run_assertions(game_ui)
	await _save_screenshot()

	if _failures == 0:
		print("[ChoreUILayoutTest] PASS - all checks passed")
	else:
		print("[ChoreUILayoutTest] FAIL - %d check(s) failed" % _failures)

	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(0 if _failures == 0 else 1)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[ChoreUILayoutTest] OK: " + label)
	else:
		push_error("[ChoreUILayoutTest] FAILED: " + label)
		_failures += 1


func _rect_str(control: Control) -> String:
	var r := control.get_global_rect()
	return "%s pos=%s size=%s right=%.1f bottom=%.1f" % [
		control.name, r.position, r.size, r.end.x, r.end.y]


func _print_diagnostics(game_ui) -> void:
	var chore_ui = game_ui.chore_ui
	var shell_row: Control = chore_ui.find_child("ShellRow", true, false)
	var meter_column: Control = chore_ui.find_child("MeterColumn", true, false)
	var nodes: Array[Control] = [
		game_ui.chore_meter_container,
		game_ui.debuff_container,
		chore_ui,
		chore_ui._compact_shell,
		shell_row,
		meter_column,
		chore_ui.buff_icon_row,
		chore_ui.progress_bar,
	]
	print("[ChoreUILayoutTest] --- global rects ---")
	for node in nodes:
		print("[ChoreUILayoutTest] " + _rect_str(node))


func _run_assertions(game_ui) -> void:
	var container: Control = game_ui.chore_meter_container
	var debuff: Control = game_ui.debuff_container
	var chore_ui = game_ui.chore_ui
	var shell: Control = chore_ui._compact_shell
	var c_right := container.get_global_rect().end.x
	var c_bottom := container.get_global_rect().end.y

	_check("ChoreUI width non-negative", chore_ui.size.x >= 0.0 and chore_ui.size.y >= 0.0)
	_check("ChoreUI right edge inside ChoreMeterContainer",
		chore_ui.get_global_rect().end.x <= c_right + EPSILON)
	_check("CompactShell right edge inside ChoreMeterContainer",
		shell.get_global_rect().end.x <= c_right + EPSILON)
	_check("ChoreUI bottom edge inside ChoreMeterContainer",
		chore_ui.get_global_rect().end.y <= c_bottom + EPSILON)
	_check("CompactShell bottom edge inside ChoreMeterContainer",
		shell.get_global_rect().end.y <= c_bottom + EPSILON)
	_check("ChoreMeterContainer right edge matches DebuffContainer",
		absf(c_right - debuff.get_global_rect().end.x) <= EPSILON)
	_check("BuffIconRow right edge inside ChoreMeterContainer",
		chore_ui.buff_icon_row.get_global_rect().end.x <= c_right + EPSILON)


func _save_screenshot() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	var err := image.save_png(SHOT_PATH)
	if err == OK:
		print("[ChoreUILayoutTest] Screenshot saved: " + SHOT_PATH)
	else:
		push_error("[ChoreUILayoutTest] Screenshot save failed: %d" % err)
		_failures += 1
