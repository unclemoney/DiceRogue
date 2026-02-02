extends Challenge
class_name TripleThreatChallenge

## TripleThreatChallenge
##
## A difficulty 4 challenge combining three moderate debuffs:
## - lock_dice: Cannot lock dice between rolls
## - disabled_twos: Twos on dice don't count for scoring
## - faster_chores: Chore meter increases 3x faster
## Tests player's ability to multitask under compound restrictions.

var _scorecard: Scorecard = null
var _game_controller: GameController = null
var _debuff_ids: Array[String] = ["lock_dice", "disabled_twos", "faster_chores"]

func _ready() -> void:
	add_to_group("challenges")
	print("[TripleThreatChallenge] Ready")

## apply(_target)
##
## Sets up the challenge by applying all three debuffs simultaneously.
## Connects to scorecard signals to track progress.
func apply(_target) -> void:
	_game_controller = _target as GameController
	if _game_controller:
		print("[TripleThreatChallenge] Applied to game controller")
		
		# Get scorecard reference
		_scorecard = _game_controller.scorecard
		if not _scorecard:
			push_error("[TripleThreatChallenge] Failed to get scorecard reference")
			return
		
		# Connect to score change signals
		if _scorecard.has_signal("score_changed"):
			if not _scorecard.is_connected("score_changed", _on_score_changed):
				_scorecard.score_changed.connect(_on_score_changed)
				print("[TripleThreatChallenge] Connected to score_changed signal")
		else:
			push_error("[TripleThreatChallenge] Scorecard does not have signal score_changed")
		
		# Connect to game completion signal
		if _scorecard.has_signal("game_completed"):
			if not _scorecard.is_connected("game_completed", _on_game_completed):
				_scorecard.game_completed.connect(_on_game_completed)
				print("[TripleThreatChallenge] Connected to game_completed signal")
		else:
			push_error("[TripleThreatChallenge] Scorecard does not have signal game_completed")
		
		# Apply all three debuffs
		for debuff_id in _debuff_ids:
			_game_controller.apply_debuff(debuff_id)
			print("[TripleThreatChallenge] Applied debuff: %s" % debuff_id)
		
		print("[TripleThreatChallenge] All three debuffs active - good luck!")
		
		# Update initial progress
		_update_progress()
	else:
		push_error("[TripleThreatChallenge] Invalid target - expected GameController")

## remove()
##
## Cleans up the challenge by removing all debuffs and disconnecting signals.
func remove() -> void:
	if _game_controller:
		# Remove all debuffs
		for debuff_id in _debuff_ids:
			if _game_controller.is_debuff_active(debuff_id):
				_game_controller.disable_debuff(debuff_id)
				print("[TripleThreatChallenge] Disabled debuff: %s" % debuff_id)
		
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
	print("[TripleThreatChallenge] Progress updated: %.2f" % progress)

## _on_score_changed(total_score)
##
## Handles score change events to track progress and check for completion.
func _on_score_changed(total_score: int) -> void:
	print("[TripleThreatChallenge] Score changed! New total: %d" % total_score)
	_update_progress()
	
	# Check if we've met the target
	if total_score >= _target_score:
		print("[TripleThreatChallenge] Target score reached! Challenge completed.")
		emit_signal("challenge_completed")
		end()

## _on_game_completed()
##
## Handles game completion to determine if the challenge was successful.
func _on_game_completed() -> void:
	if _scorecard and _scorecard.get_total_score() >= _target_score:
		print("[TripleThreatChallenge] Game completed with target score reached!")
		emit_signal("challenge_completed")
	else:
		print("[TripleThreatChallenge] Game completed but target score not reached.")
		emit_signal("challenge_failed")
	end()

## set_target_score_from_resource(resource, _round_number)
##
## Sets the target score from the ChallengeData resource.
func set_target_score_from_resource(resource: ChallengeData, _round_number: int) -> void:
	if resource:
		_target_score = resource.target_score
		print("[TripleThreatChallenge] Target score set from resource: %d" % _target_score)
