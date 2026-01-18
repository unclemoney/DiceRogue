extends Challenge
class_name DisabledModsChallenge

var _scorecard: Scorecard = null
var _game_controller: GameController = null
var _debuff_id: String = "disabled_mods"

func _ready() -> void:
	add_to_group("challenges")
	print("[DisabledModsChallenge] Ready")

## apply(_target)
##
## Sets up the challenge requirements: 220 point target and disabled_mods debuff.
## Connects to scorecard signals to track progress.
func apply(_target) -> void:
	_game_controller = _target as GameController
	if _game_controller:
		print("[DisabledModsChallenge] Applied to game controller")
		
		# Get scorecard reference
		_scorecard = _game_controller.scorecard
		if not _scorecard:
			push_error("[DisabledModsChallenge] Failed to get scorecard reference")
			return
			
		# Connect to score change signals
		if _scorecard.has_signal("score_changed"):
			print("[DisabledModsChallenge] Found score_changed signal")
			if not _scorecard.is_connected("score_changed", _on_score_changed):
				_scorecard.score_changed.connect(_on_score_changed)
				print("[DisabledModsChallenge] Connected to score_changed signal")
			else:
				print("[DisabledModsChallenge] Already connected to score_changed signal")
		else:
			push_error("[DisabledModsChallenge] Scorecard does not have signal score_changed")
		
		# Connect to game completion signal
		if _scorecard.has_signal("game_completed"):
			print("[DisabledModsChallenge] Found game_completed signal")
			if not _scorecard.is_connected("game_completed", _on_game_completed):
				_scorecard.game_completed.connect(_on_game_completed)
				print("[DisabledModsChallenge] Connected to game_completed signal")
			else:
				print("[DisabledModsChallenge] Already connected to game_completed signal")
		else:
			push_error("[DisabledModsChallenge] Scorecard does not have signal game_completed")
		
		# Apply the disabled_mods debuff
		_game_controller.apply_debuff(_debuff_id)
		print("[DisabledModsChallenge] Disabled mods debuff enabled")
		
		# Update initial progress
		_update_progress()
	else:
		push_error("[DisabledModsChallenge] Invalid target - expected GameController")

## remove()
##
## Cleans up the challenge by removing the debuff and disconnecting signals.
func remove() -> void:
	if _game_controller:
		# Remove the disabled_mods debuff
		if _game_controller.is_debuff_active(_debuff_id):
			_game_controller.disable_debuff(_debuff_id)
			print("[DisabledModsChallenge] Disabled mods debuff disabled")
		
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
	print("[DisabledModsChallenge] Progress updated:", progress)

## _on_score_changed(total_score)
##
## Handles score change events to track progress and check for completion.
func _on_score_changed(total_score: int) -> void:
	print("[DisabledModsChallenge] Score changed event received! New total:", total_score)
	_update_progress()
	
	# Check if we've met the target
	if total_score >= _target_score:
		print("[DisabledModsChallenge] Target score reached! Challenge completed.")
		emit_signal("challenge_completed")
		end()

## _on_game_completed()
##
## Handles game completion to determine if the challenge was successful.
func _on_game_completed() -> void:
	if _scorecard and _scorecard.get_total_score() >= _target_score:
		print("[DisabledModsChallenge] Game completed with target score reached!")
		emit_signal("challenge_completed")
	else:
		print("[DisabledModsChallenge] Game completed but target score not reached.")
		emit_signal("challenge_failed")
	end()
