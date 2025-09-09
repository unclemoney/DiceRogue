extends Challenge
class_name Pts200DisabledTwoDebuff

var _scorecard: Scorecard = null
var _game_controller: GameController = null
var _debuff_id: String = "disabled_twos"
var _target_score: int = 200

func _ready() -> void:
	add_to_group("challenges")
	print("[Pts200DisabledTwoDebuff:] Ready")

func apply(target) -> void:
	_game_controller = target as GameController
	if _game_controller:
		print("[Pts200DisabledTwoDebuff:] Applied to game controller")
		
		# Get scorecard reference
		_scorecard = _game_controller.scorecard
		if not _scorecard:
			push_error("[Pts200DisabledTwoDebuff:] Failed to get scorecard reference")
			return
			
		# Connect to score change signals with proper debugging
		if _scorecard.has_signal("score_changed"):
			print("[Pts200DisabledTwoDebuff:] Found score_changed signal")
			if not _scorecard.is_connected("score_changed", _on_score_changed):
				_scorecard.score_changed.connect(_on_score_changed)
				print("[Pts200DisabledTwoDebuff:] Connected to score_changed signal")
			else:
				print("[Pts200DisabledTwoDebuff:] Already connected to score_changed signal")
		else:
			push_error("[Pts200DisabledTwoDebuff:] Scorecard does not have signal score_changed")
		
		# Connect to game completion signal
		if _scorecard.has_signal("game_completed"):
			print("[Pts200DisabledTwoDebuff:] Found game_completed signal")
			if not _scorecard.is_connected("game_completed", _on_game_completed):
				_scorecard.game_completed.connect(_on_game_completed)
				print("[Pts200DisabledTwoDebuff:] Connected to game_completed signal")
			else:
				print("[Pts200DisabledTwoDebuff:] Already connected to game_completed signal")
		else:
			push_error("[Pts200DisabledTwoDebuff:] Scorecard does not have signal game_completed")
		
		# Apply the lock_dice debuff
		_game_controller.enable_debuff(_debuff_id)
		print("[Pts200DisabledTwoDebuff:] Lock dice debuff enabled")
		
		# Update initial progress
		_update_progress()
	else:
		push_error("[Pts200DisabledTwoDebuff:] Invalid target - expected GameController")

func remove() -> void:
	if _game_controller:
		# Remove the lock_dice debuff
		_game_controller.disable_debuff(_debuff_id)
		print("[Pts200DisabledTwoDebuff:] Lock dice debuff disabled")
		
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
	print("[Pts200DisabledTwoDebuff:] Progress updated:", progress)

func _on_score_changed(total_score: int) -> void:
	print("[Pts200DisabledTwoDebuff:] Score changed event received! New total:", total_score)
	_update_progress()
	
	# Check if we've met the target
	if total_score >= _target_score:
		print("[Pts200DisabledTwoDebuff:] Target score reached! Challenge completed.")
		emit_signal("challenge_completed")
		end()

func _on_game_completed() -> void:
	# Game is over - check if we succeeded
	if _scorecard and _scorecard.get_total_score() >= _target_score:
		print("[Pts200DisabledTwoDebuff:] Game completed with target score reached!")
		emit_signal("challenge_completed")
	else:
		print("[Pts200DisabledTwoDebuff:] Game completed but target score not reached.")
		emit_signal("challenge_failed")
	end()
