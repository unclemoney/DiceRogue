extends Challenge
class_name Pts100NoDebuffChallenge

var _scorecard: Scorecard = null
var _game_controller: GameController = null
var _debuff_id: String = ""
#: int = 100

func _ready() -> void:
	add_to_group("challenges")
	print("[Pts100NoDebuffChallenge] Ready - ID:", get_instance_id())

func apply(target) -> void:
	print("[Pts100NoDebuffChallenge] Applying to target:", target)
	_game_controller = target as GameController
	if _game_controller:
		print("[Pts100NoDebuffChallenge] Applied to game controller")
		
		# Get scorecard reference
		_scorecard = _game_controller.scorecard
		if not _scorecard:
			push_error("[Pts100NoDebuffChallenge] Failed to get scorecard reference")
			return
			
		print("[Pts100NoDebuffChallenge] Got scorecard reference:", _scorecard)
		
		# Connect to score change signals with proper debugging
		if _scorecard.has_signal("score_changed"):
			print("[Pts100NoDebuffChallenge] Found score_changed signal")
			if not _scorecard.is_connected("score_changed", _on_score_changed):
				_scorecard.score_changed.connect(_on_score_changed)
				print("[Pts100NoDebuffChallenge] Connected to score_changed signal")
			else:
				print("[Pts100NoDebuffChallenge] Already connected to score_changed signal")
		else:
			push_error("[Pts100NoDebuffChallenge] Scorecard does not have signal score_changed")

		# Connect to game completion signal
		if _scorecard.has_signal("game_completed"):
			print("[Pts100NoDebuffChallenge] Found game_completed signal")
			if not _scorecard.is_connected("game_completed", _on_game_completed):
				_scorecard.game_completed.connect(_on_game_completed)
				print("[Pts100NoDebuffChallenge] Connected to game_completed signal")
			else:
				print("[Pts100NoDebuffChallenge] Already connected to game_completed signal")
		else:
			push_error("[Pts100NoDebuffChallenge] Scorecard does not have signal game_completed")

		# No debuff applied in this challenge
		# Update initial progress
		_update_progress()
	else:
		push_error("[Pts100NoDebuffChallenge] Invalid target - expected GameController")

func remove() -> void:
	print("[Pts100NoDebuffChallenge] Removing challenge")
	if _game_controller:
		# Disconnect signals
		if _scorecard:
			if _scorecard.is_connected("score_changed", _on_score_changed):
				_scorecard.disconnect("score_changed", _on_score_changed)
			if _scorecard.is_connected("game_completed", _on_game_completed):
				_scorecard.disconnect("game_completed", _on_game_completed)

func get_progress() -> float:
	if not _scorecard:
		return 0.0
		
	var current_score = _scorecard.get_total_score()
	return float(current_score) / float(_target_score)

func _update_progress() -> void:
	var progress = get_progress()
	update_progress(progress)
	print("[Pts100NoDebuffChallenge] Progress updated:", progress)

func _on_score_changed(total_score: int) -> void:
	print("[Pts100NoDebuffChallenge] Score changed event received! New total:", total_score)
	_update_progress()
	
	# Check if we've met the target
	if total_score >= _target_score:
		print("[Pts100NoDebuffChallenge] Target score reached! Challenge completed.")
		emit_signal("challenge_completed")
		end()

func _on_game_completed(final_score := 0) -> void:
	# Game is over - check if we succeeded
	if _scorecard and _scorecard.get_total_score() >= _target_score:
		print("[Pts100NoDebuffChallenge] Game completed with target score reached!")
		emit_signal("challenge_completed")
	else:
		print("[Pts100NoDebuffChallenge] Game completed but target score not reached.")
		emit_signal("challenge_failed")
	end()

func set_target_score_from_resource(resource: ChallengeData, round_number: int) -> void:
	if resource:
		_target_score = resource.target_score * round_number 
		print("[Pts100NoDebuffChallenge] Target score set from resource:", _target_score)