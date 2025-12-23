extends Challenge
class_name CostlyRollChallenge

var _scorecard: Scorecard = null
var _game_controller: GameController = null
var _debuff_id: String = "costly_roll"
#var _target_score: int = 400

func _ready() -> void:
	add_to_group("challenges")
	print("[CostlyRollChallenge] Ready")

func apply(target) -> void:
	_game_controller = target as GameController
	if _game_controller:
		print("[CostlyRollChallenge] Applied to game controller")
		
		# Get scorecard reference
		_scorecard = _game_controller.scorecard
		if not _scorecard:
			push_error("[CostlyRollChallenge] Failed to get scorecard reference")
			return
			
		# Connect to score change signals
		if not _scorecard.is_connected("score_changed", _on_score_changed):
			_scorecard.score_changed.connect(_on_score_changed)
			print("[CostlyRollChallenge] Connected to score_changed signal")
		
		# Apply the costly_roll debuff
		_game_controller.enable_debuff(_debuff_id)
		print("[CostlyRollChallenge] Costly roll debuff enabled")
		
		# Update initial progress
		_update_progress()
	else:
		push_error("[CostlyRollChallenge] Invalid target - expected GameController")

func remove() -> void:
	if _game_controller:
		# Remove the costly_roll debuff
		_game_controller.disable_debuff(_debuff_id)
		print("[CostlyRollChallenge] Costly roll debuff disabled")
		
		# Disconnect signals
		if _scorecard:
			if _scorecard.is_connected("score_changed", _on_score_changed):
				_scorecard.disconnect("score_changed", _on_score_changed)

func get_progress() -> float:
	if not _scorecard:
		return 0.0
		
	var current_score = _scorecard.get_total_score()
	return float(current_score) / float(_target_score)

func _update_progress() -> void:
	var progress = get_progress()
	update_progress(progress)
	print("[CostlyRollChallenge] Progress updated:", progress)

func _on_score_changed(total_score: int) -> void:
	print("[CostlyRollChallenge] Score changed event received! New total:", total_score)
	_update_progress()
	
	# Check if we've met the target
	if total_score >= _target_score:
		print("[CostlyRollChallenge] Target score reached! Challenge completed.")
		emit_signal("challenge_completed")
		end()

func set_target_score_from_resource(resource: ChallengeData, _round_number: int) -> void:
	if resource:
		_target_score = resource.target_score
		print("[CostlyRollChallenge] Target score set from resource:", _target_score)
