extends Node

## GameSaveManager
##
## Autoload singleton responsible for mid-run save/load. Writes the settled
## snapshot to disk on every settled event, buffers pending loads in memory,
## and handles all file I/O for run saves.
##
## Save path: user://profile_{slot}_run.save
## Format: JSON with run_save_version = 2
## Writes are atomic (tmp + rename). Corrupt or newer-version saves are
## quarantined to a timestamped .bak instead of deleted.

const RUN_SAVE_VERSION: int = 2

var _pending_load_data: Dictionary = {}

func _ready() -> void:
	print("[GameSaveManager] Initialized")


## get_save_path(slot) -> String
##
## Returns the file path for the given profile slot's run save.
func get_save_path(slot: int) -> String:
	return "user://profile_%d_run.save" % slot


## has_save_for_profile(slot) -> bool
##
## Returns true if a run save exists for the specified profile slot.
func has_save_for_profile(slot: int) -> bool:
	var path = get_save_path(slot)
	return FileAccess.file_exists(path)


## save_snapshot(data)
##
## Atomically writes the provided snapshot dictionary to disk for the current
## profile slot (read from GameSettings): writes a .tmp file first, then
## renames it over the live save. Aborts with push_error if the profile slot
## cannot be determined.
##
## Parameters:
##   data: Dictionary - the full game state snapshot to persist
func save_snapshot(data: Dictionary) -> void:
	var slot = _get_current_profile_slot()
	if slot < 0:
		push_error("[GameSaveManager] Save aborted: no valid profile slot")
		return
	var path = get_save_path(slot)
	var tmp_path = path + ".tmp"

	var save_dict = {
		"meta": {
			"run_save_version": RUN_SAVE_VERSION,
			"profile_slot": slot,
			"timestamp": Time.get_datetime_string_from_system(),
			"godot_version": Engine.get_version_info().get("string", "unknown")
		},
		"state": data
	}

	var file = FileAccess.open(tmp_path, FileAccess.WRITE)
	if not file:
		push_error("[GameSaveManager] Failed to open temp file for writing: " + tmp_path)
		return
	file.store_string(JSON.stringify(save_dict, "\t"))
	file.close()

	var err = DirAccess.rename_absolute(tmp_path, path)
	if err != OK:
		push_error("[GameSaveManager] Failed to rename temp save over target (%d): %s" % [err, path])
		DirAccess.remove_absolute(tmp_path)
		return
	print("[GameSaveManager] Run saved to:", path)


## load_save_for_profile(slot) -> bool
##
## Reads the run save for the specified profile slot into _pending_load_data.
## Returns true on success, false if the file is missing or corrupt.
## Corrupt or newer-version files are quarantined to a timestamped .bak,
## never deleted. Saves older than RUN_SAVE_VERSION load with defaults for
## missing keys.
##
## Parameters:
##   slot: int - profile slot to load
## Returns: bool - true if load succeeded
func load_save_for_profile(slot: int) -> bool:
	var path = get_save_path(slot)

	if not FileAccess.file_exists(path):
		print("[GameSaveManager] No save found at:", path)
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[GameSaveManager] Failed to open file for reading: " + path)
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("[GameSaveManager] JSON parse error: " + json.get_error_message())
		_quarantine_save(slot, path)
		return false

	var save_dict = json.get_data()
	if not save_dict is Dictionary:
		push_error("[GameSaveManager] Save file root is not a Dictionary")
		_quarantine_save(slot, path)
		return false

	var meta = save_dict.get("meta", {})
	var version = int(meta.get("run_save_version", 0))

	if version > RUN_SAVE_VERSION:
		push_error("[GameSaveManager] Save version %d is newer than supported %d" % [version, RUN_SAVE_VERSION])
		_quarantine_save(slot, path)
		return false

	_pending_load_data = save_dict.get("state", {})
	print("[GameSaveManager] Save loaded for profile slot:", slot)
	return true


## has_pending_load() -> bool
##
## Returns true if a save has been loaded and is waiting to be consumed.
func has_pending_load() -> bool:
	return not _pending_load_data.is_empty()


## consume_pending_load() -> Dictionary
##
## Returns and clears the pending load data. Should be called once by
## GameController when starting the game scene.
##
## Returns: Dictionary - the loaded game state, or empty if none
func consume_pending_load() -> Dictionary:
	var data = _pending_load_data.duplicate(true)
	_pending_load_data.clear()
	return data


## delete_save_for_profile(slot)
##
## Deletes the run save file for the specified profile slot if it exists.
func delete_save_for_profile(slot: int) -> void:
	if slot < 0:
		push_error("[GameSaveManager] Delete aborted: no valid profile slot")
		return
	var path = get_save_path(slot)
	if FileAccess.file_exists(path):
		var err = DirAccess.remove_absolute(path)
		if err == OK:
			print("[GameSaveManager] Deleted save:", path)
		else:
			push_error("[GameSaveManager] Failed to delete save: " + path)


## delete_current_save()
##
## Deletes the run save for the currently active profile slot.
func delete_current_save() -> void:
	delete_save_for_profile(_get_current_profile_slot())


## quarantine_current_save()
##
## Quarantines the active profile slot's run save to a timestamped .bak.
## F12 debug hook for the corrupt-save path; safe no-op when no save exists.
func quarantine_current_save() -> void:
	var slot = _get_current_profile_slot()
	if slot < 0:
		return
	var path = get_save_path(slot)
	if FileAccess.file_exists(path):
		_quarantine_save(slot, path)
	else:
		print("[GameSaveManager] No save to quarantine for slot:", slot)


## capture_settled_snapshot() -> Dictionary
##
## Captures the current settled game state by delegating to GameController.
## Returns an empty dictionary if GameController is not available.
func capture_settled_snapshot() -> Dictionary:
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.has_method("get_save_state"):
		return game_controller.get_save_state()
	push_warning("[GameSaveManager] No GameController available to capture snapshot")
	return {}


## update_settled_snapshot()
##
## Captures the current settled state and writes it to disk as the run save.
## Called automatically after dice settle, turns start, scoring completes,
## grants, debuffs, etc., so the save preserves the run at every roll.
func update_settled_snapshot() -> void:
	var snapshot = capture_settled_snapshot()
	if not snapshot.is_empty():
		save_snapshot(snapshot)


## _quarantine_save(slot, path)
##
## Renames a corrupt or unsupported save file to a timestamped .bak so the
## player never loses data to a bad write. Failure to rename is logged only.
func _quarantine_save(slot: int, path: String) -> void:
	var bak_path = "%s.%d.bak" % [path, int(Time.get_unix_time_from_system())]
	var err = DirAccess.rename_absolute(path, bak_path)
	if err == OK:
		print("[GameSaveManager] Quarantined save to:", bak_path)
	else:
		push_error("[GameSaveManager] Failed to quarantine save (%d): %s" % [err, path])


## _get_current_profile_slot() -> int
##
## Reads the active profile slot from GameSettings. Returns -1 (after a
## push_error) when GameSettings or the slot accessor is unavailable;
## callers must abort rather than write to a guessed slot.
func _get_current_profile_slot() -> int:
	if not is_instance_valid(GameSettings):
		push_error("[GameSaveManager] GameSettings autoload unavailable; cannot resolve profile slot")
		return -1
	if GameSettings.has_method("get_active_profile_slot"):
		return int(GameSettings.get_active_profile_slot())
	if "active_profile_slot" in GameSettings:
		return int(GameSettings.active_profile_slot)
	push_error("[GameSaveManager] GameSettings exposes no active profile slot")
	return -1
