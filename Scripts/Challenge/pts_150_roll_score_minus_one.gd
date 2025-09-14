extends Challenge
class_name Pts150RollScoreMinusOne

var _scorecard: Scorecard = null
var _game_controller: GameController = null
var _debuff_id: String = "roll_score_minus_one"
var _target_score: int = 150

func _ready() -> void:
	add_to_group("challenges")
	print("[Pts150RollScoreMinusOne] Ready")

func apply(target) -> void:
	_game_controller = target as GameController
	if _game_controller:
		print("[Pts150RollScoreMinusOne] Applied to game controller")
		
		# Get scorecard reference
		_scorecard = _game_controller.scorecard
		if not _scorecard:
			push_error("[Pts150RollScoreMinusOne] Failed to get scorecard reference")
			return
			
		# Connect to score change signals with proper debugging
		if _scorecard.has_signal("score_changed"):
			print("[Pts150RollScoreMinusOne] Found score_changed signal")
			if not _scorecard.is_connected("score_changed", _on_score_changed):
				_scorecard.score_changed.connect(_on_score_changed)
				print("[Pts150RollScoreMinusOne] Connected to score_changed signal")
			else:
				print("[Pts150RollScoreMinusOne] Already connected to score_changed signal")
		else:
			push_error("[Pts150RollScoreMinusOne] Scorecard does not have signal score_changed")
		
		# Connect to game completion signal
		if _scorecard.has_signal("game_completed"):
			print("[Pts150RollScoreMinusOne] Found game_completed signal")
			if not _scorecard.is_connected("game_completed", _on_game_completed):
				_scorecard.game_completed.connect(_on_game_completed)
				print("[Pts150RollScoreMinusOne] Connected to game_completed signal")
			else:
				print("[Pts150RollScoreMinusOne] Already connected to game_completed signal")
		else:
			push_error("[Pts150RollScoreMinusOne] Scorecard does not have signal game_completed")
		
		# Apply the lock_dice debuff
		_game_controller.apply_debuff(_debuff_id)
		print("[Pts150RollScoreMinusOne] Lock dice debuff enabled")
		
		# Update initial progress
		_update_progress()
	else:
		push_error("[Pts150RollScoreMinusOne] Invalid target - expected GameController")

func remove() -> void:
	if _game_controller:
		# Remove the lock_dice debuff
		if _game_controller.is_debuff_active(_debuff_id):
			_game_controller.disable_debuff(_debuff_id)
			print("[Pts150RollScoreMinusOne] Roll score minus one debuff disabled")
		
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
	print("[Pts150RollScoreMinusOne] Progress updated:", progress)

func _on_score_changed(total_score: int) -> void:
	print("[Pts150RollScoreMinusOne] Score changed event received! New total:", total_score)
	_update_progress()
	
	# Check if we've met the target
	if total_score >= _target_score:
		print("[Pts150RollScoreMinusOne] Target score reached! Challenge completed.")
		emit_signal("challenge_completed")
		end()

func _on_game_completed() -> void:
	# Game is over - check if we succeeded
	if _scorecard and _scorecard.get_total_score() >= _target_score:
		print("[Pts150RollScoreMinusOne] Game completed with target score reached!")
		emit_signal("challenge_completed")
	else:
		print("[Pts150RollScoreMinusOne] Game completed but target score not reached.")
		emit_signal("challenge_failed")
	end()
