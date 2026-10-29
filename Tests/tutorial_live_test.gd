extends Node

var _failures := 0
var _profile_path := ""
var _run_path := ""
var _profile_bytes := PackedByteArray()
var _run_bytes := PackedByteArray()
var _had_profile := false
var _had_run := false
var _fixture_save_created := false


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
	else:
		_fixture_save_created = true
		_run_bytes = PackedByteArray([1, 2, 3, 4, 5])
		var file := FileAccess.open(_run_path, FileAccess.WRITE)
		file.store_buffer(_run_bytes)
		file.close()
		_had_run = true
	TutorialManager.reset_tutorial()
	call_deferred("_run")


func _run() -> void:
	await get_tree().create_timer(1.5).timeout
	_check("Live tutorial auto-starts", TutorialManager.is_active)
	_check("Live tutorial initializes gameplay director", TutorialManager._gameplay != null and TutorialManager._gameplay._game != null)
	var root_node: Node = TutorialManager._get_game_root()
	for step_id in TutorialManager.step_order:
		var step = TutorialManager.get_step(step_id)
		if step.highlight_node_path != "":
			_check("Path resolves: " + step_id, root_node.get_node_or_null(step.highlight_node_path) != null)
	_check("Animated portrait is installed", TutorialManager._tutorial_dialog.portrait is MomPortraitAnimator)
	_check("Back, Exit, Next exist", TutorialManager._tutorial_dialog.back_button != null and TutorialManager._tutorial_dialog.exit_button != null and TutorialManager._tutorial_dialog.next_button != null)
	reparent(get_tree().root)
	TutorialManager.exit_tutorial()
	await get_tree().create_timer(2.0).timeout
	_check("Exit reaches Main Menu", get_tree().current_scene.name == "MainMenu")
	_check("Exit clears tutorial activity", not TutorialManager.is_active and not TutorialManager.is_tutorial_session_active)
	_check("Exit leaves tutorial incomplete", not TutorialManager.tutorial_completed_flag and TutorialManager.tutorial_in_progress_flag)
	_check("Exit disables tutorial auto-start", not TutorialManager.should_auto_start())
	_check("Exit does not create a run save", _had_run or not FileAccess.file_exists(_run_path))
	if _had_run:
		_check("Existing run save survives", FileAccess.get_file_as_bytes(_run_path) == _run_bytes)
	_restore_files()
	print("[TutorialLiveTest] %s" % ("PASS" if _failures == 0 else "FAIL: %d" % _failures))
	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(0 if _failures == 0 else 1)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[TutorialLiveTest] PASS: " + label)
	else:
		_failures += 1
		push_error("[TutorialLiveTest] FAIL: " + label)


func _restore_files() -> void:
	_restore(_profile_path, _had_profile, _profile_bytes)
	_restore(_run_path, _had_run and not _fixture_save_created, _run_bytes)


func _restore(path: String, existed: bool, bytes: PackedByteArray) -> void:
	if existed:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_buffer(bytes)
			file.close()
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
