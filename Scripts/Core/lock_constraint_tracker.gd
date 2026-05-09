extends RefCounted
class_name LockConstraintTracker

## LockConstraintTracker
##
## Tracks score and dice-lock counts over a fixed turn window for chore/unlock validation.
## Records the maximum number of dice locked at any roll press within each turn,
## plus the score achieved when that turn is scored.
##
## Uses a FIXED window semantics: the window covers exactly the turns from
## _start_turn to _start_turn + _turn_window - 1. Any turns outside this range
## are ignored for satisfaction and expiration checks.

var _start_turn: int = 0
var _turn_window: int = 3
var _max_locked_dice: int = 0
var _min_score: int = 0

## Each entry: { "turn": int, "score": int, "max_locked": int }
var _turn_records: Array[Dictionary] = []

var _current_turn: int = -1
var _current_turn_max_locked: int = 0
var _current_turn_score: int = 0
var _current_turn_score_recorded: bool = false

## setup()
##
## Initializes the tracker with constraint parameters.
## Parameters:
##   start_turn: The turn number when tracking begins.
##   turn_window: Number of turns the window spans.
##   min_score: Minimum cumulative score required across the window.
##   max_locked_dice: Maximum allowed dice locked at any roll press within the window.
func setup(start_turn: int, turn_window: int, min_score: int, max_locked_dice: int) -> void:
	_start_turn = start_turn
	_turn_window = turn_window
	_min_score = min_score
	_max_locked_dice = max_locked_dice
	_turn_records.clear()
	_current_turn = -1
	_current_turn_max_locked = 0
	_current_turn_score = 0
	_current_turn_score_recorded = false

## record_roll()
##
## Called when the player presses the roll button. Records the number of dice
## locked at that moment for the current turn.
## Parameters:
##   turn: The current turn number.
##   locked_count: Number of dice in LOCKED state when roll was pressed.
func record_roll(turn: int, locked_count: int) -> void:
	if turn != _current_turn:
		_finalize_turn()
		_current_turn = turn
		_current_turn_max_locked = locked_count
		_current_turn_score = 0
		_current_turn_score_recorded = false
	else:
		_current_turn_max_locked = maxi(_current_turn_max_locked, locked_count)

## record_turn_score()
##
## Called when the turn ends and a score is assigned. Finalizes the current turn.
## Parameters:
##   turn: The turn number.
##   score: The score achieved this turn.
func record_turn_score(turn: int, score: int) -> void:
	if turn != _current_turn:
		_finalize_turn()
		_current_turn = turn
		_current_turn_max_locked = 0
	_current_turn_score = score
	_current_turn_score_recorded = true
	_finalize_turn()

## _finalize_turn()
##
## Commits the in-progress turn data to the record list.
func _finalize_turn() -> void:
	if _current_turn < 0:
		return
	
	var existing_idx := -1
	for i in range(_turn_records.size()):
		if _turn_records[i].get("turn", -1) == _current_turn:
			existing_idx = i
			break
	
	if existing_idx >= 0:
		_turn_records[existing_idx]["score"] = _current_turn_score
		_turn_records[existing_idx]["max_locked"] = _current_turn_max_locked
	else:
		_turn_records.append({
			"turn": _current_turn,
			"score": _current_turn_score,
			"max_locked": _current_turn_max_locked
		})
	
	_current_turn = -1

## _get_window_records()
##
## Returns only the records whose turn numbers fall within the fixed window
## [_start_turn, _start_turn + _turn_window).
func _get_window_records() -> Array[Dictionary]:
	var window: Array[Dictionary] = []
	for record in _turn_records:
		var turn = record.get("turn", 0)
		if turn >= _start_turn and turn < _start_turn + _turn_window:
			window.append(record)
	return window

## is_satisfied()
##
## Returns true if the fixed window [_start_turn, _start_turn + _turn_window)
## has enough recorded turns, meets the score threshold, and respects the lock limit.
func is_satisfied() -> bool:
	var window = _get_window_records()
	if window.size() < _turn_window:
		return false
	
	var total_score := 0
	for record in window:
		total_score += record.get("score", 0)
		if record.get("max_locked", 0) > _max_locked_dice:
			return false
	
	return total_score >= _min_score

## is_violated()
##
## Returns true if any recorded turn in the fixed window has already exceeded
## the max locked dice limit. Useful for UI feedback.
func is_violated() -> bool:
	var window = _get_window_records()
	for record in window:
		if record.get("max_locked", 0) > _max_locked_dice:
			return true
	return false

## is_expired()
##
## Returns true if the fixed window is fully recorded (we have _turn_window turns
## within the window range) and it is still not satisfied.
## Parameters:
##   current_turn: The current turn number (used only as a hint; the primary check
##                 is whether the window is fully populated).
func is_expired(_current_turn: int) -> bool:
	var window = _get_window_records()
	return window.size() >= _turn_window and not is_satisfied()

## get_progress_summary()
##
## Returns a human-readable progress string for UI display.
func get_progress_summary() -> String:
	var window = _get_window_records()
	if window.is_empty():
		return "Score: 0/%d | Locks: 0/%d (Turns: 0/%d)" % [_min_score, _max_locked_dice, _turn_window]
	
	var total_score := 0
	var max_locked_in_window := 0
	for record in window:
		total_score += record.get("score", 0)
		max_locked_in_window = maxi(max_locked_in_window, record.get("max_locked", 0))
	
	return "Score: %d/%d | Locks: %d/%d (Turns: %d/%d)" % [total_score, _min_score, max_locked_in_window, _max_locked_dice, window.size(), _turn_window]

## get_window_progress()
##
## Returns a dictionary with raw progress values for custom UI.
func get_window_progress() -> Dictionary:
	var window = _get_window_records()
	if window.is_empty():
		return {"total_score": 0, "min_score": _min_score, "max_locked": 0, "max_allowed": _max_locked_dice, "turns_recorded": 0, "turn_window": _turn_window}
	
	var total_score := 0
	var max_locked_in_window := 0
	for record in window:
		total_score += record.get("score", 0)
		max_locked_in_window = maxi(max_locked_in_window, record.get("max_locked", 0))
	
	return {
		"total_score": total_score,
		"min_score": _min_score,
		"max_locked": max_locked_in_window,
		"max_allowed": _max_locked_dice,
		"turns_recorded": window.size(),
		"turn_window": _turn_window
	}

## reset()
##
## Clears all tracked data but preserves constraint parameters.
func reset() -> void:
	_turn_records.clear()
	_current_turn = -1
	_current_turn_max_locked = 0
	_current_turn_score = 0
	_current_turn_score_recorded = false
