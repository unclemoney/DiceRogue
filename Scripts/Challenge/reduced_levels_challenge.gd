extends Challenge
class_name ReducedLevelsChallenge

var _scorecard: Scorecard = null
var _game_controller: GameController = null
var _debuff_id: String = "reduced_levels"

func _ready() -> void:
	add_to_group("challenges")
	print("[ReducedLevelsChallenge] Ready")

## apply(_target)
##
## Sets up the challenge requirements: 250 point target and reduced_levels debuff.
## Connects to scorecard signals to track progress.
func apply(_target) -> void:
	_game_controller = _target as GameController
	if _game_controller:
		print("[ReducedLevelsChallenge] Applied to game controller")
		
		# Get scorecard reference
		_scorecard = _game_controller.scorecard
		if not _scorecard:
			push_error("[ReducedLevelsChallenge] Failed to get scorecard reference")
			return
			
		# Connect to score change signals
		if _scorecard.has_signal("score_changed"):
			print("[ReducedLevelsChallenge] Found score_changed signal")
			if not _scorecard.is_connected("score_changed", _on_score_changed):
				_scorecard.score_changed.connect(_on_score_changed)
				print("[ReducedLevelsChallenge] Connected to score_changed signal")
			else:
				print("[ReducedLevelsChallenge] Already connected to score_changed signal")
		else:
			push_error("[ReducedLevelsChallenge] Scorecard does not have signal score_changed")
		
		# Connect to game completion signal
		if _scorecard.has_signal("game_completed"):
			print("[ReducedLevelsChallenge] Found game_completed signal")
			if not _scorecard.is_connected("game_completed", _on_game_completed):
				_scorecard.game_completed.connect(_on_game_completed)
				print("[ReducedLevelsChallenge] Connected to game_completed signal")
			else:
				print("[ReducedLevelsChallenge] Already connected to game_completed signal")
		else:
			push_error("[ReducedLevelsChallenge] Scorecard does not have signal game_completed")
		
		# Apply the reduced_levels debuff
		_game_controller.apply_debuff(_debuff_id)
		print("[ReducedLevelsChallenge] Reduced levels debuff enabled")
		
		# Update initial progress
		_update_progress()
	else:
		push_error("[ReducedLevelsChallenge] Invalid target - expected GameController")

## remove()
##
## Cleans up the challenge by removing the debuff and disconnecting signals.
func remove() -> void:
	if _game_controller:
		# Remove the reduced_levels debuff
		if _game_controller.is_debuff_active(_debuff_id):
			_game_controller.disable_debuff(_debuff_id)
			print("[ReducedLevelsChallenge] Reduced levels debuff disabled")
		
		# Disconnect signals
		if _scorecard:
			if _scorecard.is_connected("score_changed", _on_score_changed):
				_scorecard.disconnect("score_changed", _on_score_changed)
			if _scorecard.is_connected("game_completed", _on_game_completed):
				_scorecard.disconnect("game_completed", _on_game_completed)

## get_progress()
##
## Returns the current progress as a float between 0.0 and 1.0.
func get_progress() -> float:
	if not _scorecard:
		return 0.0
		
	var current_score = _scorecard.get_total_score()
	return float(current_score) / float(_target_score)

## _update_progress()
##
## Updates and emits the current progress.
func _update_progress() -> void:
	var progress = get_progress()
	update_progress(progress)
	print("[ReducedLevelsChallenge] Progress updated:", progress)

## _on_score_changed(total_score)
##
## Handles score change events to track progress and check for completion.
func _on_score_changed(total_score: int) -> void:
	print("[ReducedLevelsChallenge] Score changed event received! New total:", total_score)
	_update_progress()
	
	# Check if we've met the target
	if total_score >= _target_score:
		print("[ReducedLevelsChallenge] Target score reached! Challenge completed.")
		emit_signal("challenge_completed")
		end()

## _on_game_completed()
##
## Handles game completion to determine if the challenge was successful.
func _on_game_completed() -> void:
	if _scorecard and _scorecard.get_total_score() >= _target_score:
		print("[ReducedLevelsChallenge] Game completed with target score reached!")
		emit_signal("challenge_completed")
	else:
		print("[ReducedLevelsChallenge] Game completed but target score not reached.")
		emit_signal("challenge_failed")
	end()
