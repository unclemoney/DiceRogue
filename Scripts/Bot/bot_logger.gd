extends RefCounted
class_name BotLogger

## BotLogger
##
## Captures errors, crashes, edge cases, and info messages during bot runs.
## Writes a JSON log file after all runs complete.

enum Level { INFO, WARNING, EDGE_CASE, ERROR, CRASH }

const LOG_DIR := "user://bot_reports/"

var entries: Array[Dictionary] = []
var _current_run_id: int = -1
var _current_channel: int = -1
var _current_round: int = -1
var _current_turn: int = -1
var verbose: bool = true


## set_context(run_id, channel, round_num, turn)
##
## Updates the current context so every subsequent log entry
## is tagged with the right run/round/turn.
func set_context(run_id: int, channel: int, round_num: int = -1, turn: int = -1) -> void:
	_current_run_id = run_id
	_current_channel = channel
	_current_round = round_num
	_current_turn = turn


## log_info(message)
func log_info(message: String) -> void:
	if verbose:
		_add(Level.INFO, message)


## log_warning(message)
func log_warning(message: String) -> void:
	_add(Level.WARNING, message)


## log_edge_case(message)
func log_edge_case(message: String) -> void:
	_add(Level.EDGE_CASE, message)


## log_error(message)
func log_error(message: String) -> void:
	_add(Level.ERROR, message)
	push_error("[BotLogger] " + message)


## log_crash(message)
func log_crash(message: String) -> void:
	_add(Level.CRASH, message)
	push_error("[BotLogger][CRASH] " + message)


## get_error_count() -> int
func get_error_count() -> int:
	var count := 0
	for entry in entries:
		if entry.level >= Level.ERROR:
			count += 1
	return count


## get_edge_case_count() -> int
func get_edge_case_count() -> int:
	var count := 0
	for entry in entries:
		if entry.level == Level.EDGE_CASE:
			count += 1
	return count


## save_log() -> String
##
## Writes all entries to a timestamped JSON file.
## Returns the file path written.
func save_log() -> String:
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var path = LOG_DIR + "bot_log_" + timestamp + ".json"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("[BotLogger] Could not open log file: " + path)
		return ""
	var serialized: Array = []
	for entry in entries:
		var e = entry.duplicate()
		e["level_name"] = Level.keys()[e.level]
		serialized.append(e)
	file.store_string(JSON.stringify(serialized, "\t"))
	file.close()
	print("[BotLogger] Log saved to: " + path)
	return path


## clear()
func clear() -> void:
	entries.clear()


## _add(level, message)
func _add(level: int, message: String) -> void:
	var entry := {
		"run_id": _current_run_id,
		"channel": _current_channel,
		"round": _current_round,
		"turn": _current_turn,
		"level": level,
		"message": message,
		"timestamp": Time.get_datetime_string_from_system()
	}
	entries.append(entry)
	if verbose:
		var prefix = Level.keys()[level]
		print("[Bot][%s] R%d Ch%d Rd%d T%d: %s" % [prefix, _current_run_id, _current_channel, _current_round, _current_turn, message])
