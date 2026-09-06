extends Control

## _chore_fanout_shot.gd
##
## Visual check for the redesigned chore status fan-out panel. Instances the
## REAL Scenes/UI/GameUI.tscn, wires a real ChoresManager, adds a Rebellion
## buff chip, sets an angry mood (7/10) with some progress and one completed
## chore, then opens the fan-out and screenshots it.
##
## Needs a real rendering driver — run WITHOUT --headless:
##   godot --path . --resolution 1280x720 Tests/_chore_fanout_shot.tscn -- --quit-after
## Exit code 0 = all checks passed, 1 = at least one failure.

const GAME_UI_SCENE: PackedScene = preload("res://Scenes/UI/GameUI.tscn")
const ChoresManagerScript = preload("res://Scripts/Managers/ChoresManager.gd")
const REBELLION_DATA: DebuffData = preload("res://Scripts/Debuff/RebellionBuff.tres")

const SHOT_DIR := "res://Tests/_layout_shots"
const SHOT_PATH := SHOT_DIR + "/chore_fanout.png"

var _failures: int = 0


func _ready() -> void:
	print("[ChoreFanoutShot] Starting")
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var game_ui = GAME_UI_SCENE.instantiate()
	add_child(game_ui)

	var chores_manager = ChoresManagerScript.new()
	chores_manager.name = "ChoresManager"
	add_child(chores_manager)

	game_ui.chore_ui.set_chores_manager(chores_manager)

	# Let deferred init (manager wiring, fan-out reparenting) and layout settle.
	for i in range(12):
		await get_tree().process_frame

	# Screenshot the compact shell with the buff slot EMPTY (dashed border,
	# faint glyph) before adding a chip.
	await RenderingServer.frame_post_draw
	var compact_image := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	compact_image.save_png(SHOT_DIR + "/chore_compact_empty.png")

	game_ui.chore_ui.add_buff_icon(REBELLION_DATA)
	await get_tree().process_frame

	# Angry mood so the frame/label tint band is visible; partial progress and
	# one completed chore so the fan-out sections are populated.
	chores_manager.mom_mood = 7
	chores_manager.mom_mood_changed.emit(7)
	chores_manager.current_progress = 42
	chores_manager.progress_changed.emit(42)
	if chores_manager.current_task:
		chores_manager.completed_chores.append(chores_manager.current_task)
		chores_manager.task_completed.emit(chores_manager.current_task)

	# Open the fan-out and let its drop-in animation finish.
	game_ui.chore_ui._toggle_fan_state()
	for i in range(40):
		await get_tree().process_frame

	_check("fan-out visible", game_ui.chore_ui.details_panel.visible)
	_check("background dimmed", game_ui.chore_ui._background.visible)
	_check("title stated once", game_ui.chore_ui._title_label.text != "")
	_check("numeral has no percentage", "%" not in game_ui.chore_ui._progress_numeral.text)
	var panel_size: Vector2 = game_ui.chore_ui.details_panel.size
	_check("panel is DETAILS_PANEL_SIZE", panel_size == game_ui.chore_ui.DETAILS_PANEL_SIZE)

	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	var err := image.save_png(SHOT_PATH)
	if err == OK:
		print("[ChoreFanoutShot] Screenshot saved: " + SHOT_PATH)
	else:
		push_error("[ChoreFanoutShot] Screenshot save failed: %d" % err)
		_failures += 1

	if _failures == 0:
		print("[ChoreFanoutShot] PASS - all checks passed")
	else:
		print("[ChoreFanoutShot] FAIL - %d check(s) failed" % _failures)

	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(0 if _failures == 0 else 1)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[ChoreFanoutShot] OK: " + label)
	else:
		push_error("[ChoreFanoutShot] FAILED: " + label)
		_failures += 1
