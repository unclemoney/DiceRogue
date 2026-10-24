extends Node

var _failures := 0


func _ready() -> void:
	var slot: int = GameSettings.active_profile_slot
	var path: String = GameSaveManager.get_save_path(slot)
	var existed := FileAccess.file_exists(path)
	var original := FileAccess.get_file_as_bytes(path) if existed else PackedByteArray()
	TutorialManager.is_tutorial_session_active = true
	GameSaveManager.save_snapshot({"tutorial_test": true})
	_check("No tutorial save is created", existed or not FileAccess.file_exists(path))
	if existed:
		_check("Existing save is unchanged", FileAccess.get_file_as_bytes(path) == original)
	TutorialManager.is_tutorial_session_active = false
	if existed:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(original)
		file.close()
	print("[TutorialSaveTest] %s" % ("PASS" if _failures == 0 else "FAIL: %d" % _failures))
	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(0 if _failures == 0 else 1)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[TutorialSaveTest] PASS: " + label)
	else:
		_failures += 1
		push_error("[TutorialSaveTest] FAIL: " + label)
