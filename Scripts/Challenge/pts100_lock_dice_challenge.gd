extends Challenge
class_name Pts100LockDiceChallenge

var _scorecard: Scorecard = null
var _game_controller: GameController = null
var _debuff_id: String = "lock_dice"
#var _target_score: int = 100

func _ready() -> void:
	add_to_group("challenges")
	print("[Pts100LockDiceChallenge] Ready")

func apply(target) -> void:
	_game_controller = target as GameController
	if _game_controller:
		print("[Pts100LockDiceChallenge] Applied to game controller")
		
		# Get scorecard reference
		_scorecard = _game_controller.scorecard
		if not _scorecard:
			push_error("[Pts100LockDiceChallenge] Failed to get scorecard reference")
			return
			
		# Connect to score change signals with proper debugging
		if _scorecard.has_signal("score_changed"):
			print("[Pts100LockDiceChallenge] Found score_changed signal")
			if not _scorecard.is_connected("score_changed", _on_score_changed):
				_scorecard.score_changed.connect(_on_score_changed)
				print("[Pts100LockDiceChallenge] Connected to score_changed signal")
			else:
				print("[Pts100LockDiceChallenge] Already connected to score_changed signal")
		else:
			push_error("[Pts100LockDiceChallenge] Scorecard does not have signal score_changed")
		
		# Connect to game completion signal
		if _scorecard.has_signal("game_completed"):
			print("[Pts100LockDiceChallenge] Found game_completed signal")
			if not _scorecard.is_connected("game_completed", _on_game_completed):
				_scorecard.game_completed.connect(_on_game_completed)
				print("[Pts100LockDiceChallenge] Connected to game_completed signal")
			else:
				print("[Pts100LockDiceChallenge] Already connected to game_completed signal")
		else:
			push_error("[Pts100LockDiceChallenge] Scorecard does not have signal game_completed")
		
		# Apply the lock_dice debuff
		_game_controller.enable_debuff(_debuff_id)
		print("[Pts100LockDiceChallenge] Lock dice debuff enabled")
		
		# Update initial progress
		_update_progress()
	else:
		push_error("[Pts100LockDiceChallenge] Invalid target - expected GameController")

func remove() -> void:
	if _game_controller:
		# Remove the lock_dice debuff
		_game_controller.disable_debuff(_debuff_id)
		print("[Pts100LockDiceChallenge] Lock dice debuff disabled")
		
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
	print("[Pts100LockDiceChallenge] Progress updated:", progress)

func _on_score_changed(total_score: int) -> void:
	print("[Pts100LockDiceChallenge] Score changed event received! New total:", total_score)
	_update_progress()
	
	# Check if we've met the target
	if total_score >= _target_score:
		print("[Pts100LockDiceChallenge] Target score reached! Challenge completed.")
		emit_signal("challenge_completed")
		end()

func _on_game_completed() -> void:
	# Game is over - check if we succeeded
	if _scorecard and _scorecard.get_total_score() >= _target_score:
		print("[Pts100LockDiceChallenge] Game completed with target score reached!")
		emit_signal("challenge_completed")
	else:
		print("[Pts100LockDiceChallenge] Game completed but target score not reached.")
		emit_signal("challenge_failed")
	end()

func set_target_score_from_resource(resource: ChallengeData, _round_number: int) -> void:
	if resource:
		_target_score = resource.target_score
		print("[Pts100LockDiceChallenge] Target score set from resource:", _target_score)
