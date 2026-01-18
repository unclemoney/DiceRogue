extends Challenge
class_name ToughAdditionChallenge

## ToughAdditionChallenge
##
## A difficulty 3 challenge that applies the half_additive debuff.
## Players must reach 350 points while all additive bonuses are halved.
## Reward: $200 on completion.

var _scorecard: Scorecard = null
var _game_controller: GameController = null
var _debuff_id: String = "half_additive"

func _ready() -> void:
	add_to_group("challenges")
	print("[ToughAdditionChallenge] Ready")

## apply(_target)
##
## Sets up the challenge requirements: 350 point target and half_additive debuff.
## Connects to scorecard signals to track progress.
func apply(_target) -> void:
	_game_controller = _target as GameController
	if _game_controller:
		print("[ToughAdditionChallenge] Applied to game controller")
		
		# Get scorecard reference
		_scorecard = _game_controller.scorecard
		if not _scorecard:
			push_error("[ToughAdditionChallenge] Failed to get scorecard reference")
			return
			
		# Connect to score change signals with proper debugging
		if _scorecard.has_signal("score_changed"):
			print("[ToughAdditionChallenge] Found score_changed signal")
			if not _scorecard.is_connected("score_changed", _on_score_changed):
				_scorecard.score_changed.connect(_on_score_changed)
				print("[ToughAdditionChallenge] Connected to score_changed signal")
			else:
				print("[ToughAdditionChallenge] Already connected to score_changed signal")
		else:
			push_error("[ToughAdditionChallenge] Scorecard does not have signal score_changed")
		
		# Connect to game completion signal
		if _scorecard.has_signal("game_completed"):
			print("[ToughAdditionChallenge] Found game_completed signal")
			if not _scorecard.is_connected("game_completed", _on_game_completed):
				_scorecard.game_completed.connect(_on_game_completed)
				print("[ToughAdditionChallenge] Connected to game_completed signal")
			else:
				print("[ToughAdditionChallenge] Already connected to game_completed signal")
		else:
			push_error("[ToughAdditionChallenge] Scorecard does not have signal game_completed")
		
		# Apply the half_additive debuff
		_game_controller.apply_debuff(_debuff_id)
		print("[ToughAdditionChallenge] Half additive debuff enabled")
		
		# Update initial progress
		_update_progress()
	else:
		push_error("[ToughAdditionChallenge] Invalid target - expected GameController")

## remove()
##
## Cleans up the challenge by removing the debuff and disconnecting signals.
func remove() -> void:
	if _game_controller:
		# Remove the half_additive debuff
		if _game_controller.is_debuff_active(_debuff_id):
			_game_controller.disable_debuff(_debuff_id)
			print("[ToughAdditionChallenge] Half additive debuff disabled")
		
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
	print("[ToughAdditionChallenge] Progress updated:", progress)

## _on_score_changed(total_score)
##
## Handles score change events to track progress and check for completion.
func _on_score_changed(total_score: int) -> void:
	print("[ToughAdditionChallenge] Score changed event received! New total:", total_score)
	_update_progress()
	
	# Check if we've met the target
	if total_score >= _target_score:
		print("[ToughAdditionChallenge] Target score reached! Challenge completed.")
		emit_signal("challenge_completed")
		end()

## _on_game_completed()
##
## Handles game completion to determine if the challenge was successful.
func _on_game_completed() -> void:
	# Game is over - check if we succeeded
	if _scorecard and _scorecard.get_total_score() >= _target_score:
		print("[ToughAdditionChallenge] Game completed with target score reached!")
		emit_signal("challenge_completed")
	else:
		print("[ToughAdditionChallenge] Game completed but target score not reached.")
		emit_signal("challenge_failed")
	end()

## set_target_score_from_resource(resource, _round_number)
##
## CRITICAL: Sets the target score from the ChallengeData resource.
## This method MUST be implemented or the challenge will have a target score of 0.
func set_target_score_from_resource(resource: ChallengeData, _round_number: int) -> void:
	if resource:
		_target_score = resource.target_score
		print("[ToughAdditionChallenge] Target score set from resource:", _target_score)
