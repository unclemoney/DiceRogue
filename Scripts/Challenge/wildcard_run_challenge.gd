extends Challenge
class_name WildcardRunChallenge

## WildcardRunChallenge
##
## A difficulty 3 challenge where normal rules apply until round 3,
## when a random debuff (difficulty 1-2) activates unexpectedly.

var _scorecard: Scorecard = null
var _game_controller: GameController = null
var _round_manager: RoundManager = null
var _debuff_manager: DebuffManager = null
var _applied_debuff_id: String = ""  # Track the randomly applied debuff
var _debuff_applied: bool = false

func _ready() -> void:
	add_to_group("challenges")
	print("[WildcardRunChallenge] Ready")

## apply(_target)
##
## Sets up the challenge with no initial debuffs.
## Connects to round_started signal to apply random debuff at round 3.
func apply(_target) -> void:
	_game_controller = _target as GameController
	if _game_controller:
		print("[WildcardRunChallenge] Applied to game controller")
		
		# Get scorecard reference
		_scorecard = _game_controller.scorecard
		if not _scorecard:
			push_error("[WildcardRunChallenge] Failed to get scorecard reference")
			return
		
		# Get round manager reference for round tracking
		_round_manager = _game_controller.round_manager
		if not _round_manager:
			push_error("[WildcardRunChallenge] Failed to get round_manager reference")
		else:
			# Connect to round_started to detect when round 3 begins
			if not _round_manager.is_connected("round_started", _on_round_started):
				_round_manager.round_started.connect(_on_round_started)
				print("[WildcardRunChallenge] Connected to round_started signal")
		
		# Get debuff manager reference for random debuff selection
		_debuff_manager = _game_controller.debuff_manager
		if not _debuff_manager:
			push_error("[WildcardRunChallenge] Failed to get debuff_manager reference")
		
		# Connect to score change signals
		if _scorecard.has_signal("score_changed"):
			if not _scorecard.is_connected("score_changed", _on_score_changed):
				_scorecard.score_changed.connect(_on_score_changed)
				print("[WildcardRunChallenge] Connected to score_changed signal")
		else:
			push_error("[WildcardRunChallenge] Scorecard does not have signal score_changed")
		
		# Connect to game completion signal
		if _scorecard.has_signal("game_completed"):
			if not _scorecard.is_connected("game_completed", _on_game_completed):
				_scorecard.game_completed.connect(_on_game_completed)
				print("[WildcardRunChallenge] Connected to game_completed signal")
		else:
			push_error("[WildcardRunChallenge] Scorecard does not have signal game_completed")
		
		# No debuffs applied initially - that's the "wildcard" part
		print("[WildcardRunChallenge] Challenge active - random debuff will apply at round 3")
		
		# Update initial progress
		_update_progress()
	else:
		push_error("[WildcardRunChallenge] Invalid target - expected GameController")

## _on_round_started(round_number)
##
## Called when a new round starts. Applies random debuff at round 3.
func _on_round_started(round_number: int) -> void:
	print("[WildcardRunChallenge] Round %d started" % round_number)
	
	# Apply random debuff at round 3 (or later if somehow missed)
	if round_number >= 3 and not _debuff_applied:
		_apply_random_debuff()

## _apply_random_debuff()
##
## Selects and applies a random debuff from difficulty 1-2 pool.
func _apply_random_debuff() -> void:
	if _debuff_applied:
		return
	
	if not _debuff_manager or not _game_controller:
		push_error("[WildcardRunChallenge] Cannot apply random debuff - missing references")
		return
	
	# Get debuffs with difficulty 1-2 only (keep it fair for difficulty 3 challenge)
	var eligible_debuffs = _debuff_manager.get_debuffs_by_difficulty(2)
	
	if eligible_debuffs.is_empty():
		push_error("[WildcardRunChallenge] No eligible debuffs found!")
		return
	
	# Randomly select one
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var index = rng.randi_range(0, eligible_debuffs.size() - 1)
	var selected_debuff = eligible_debuffs[index]
	_applied_debuff_id = selected_debuff.id
	
	# Apply the debuff
	_game_controller.apply_debuff(_applied_debuff_id)
	_debuff_applied = true
	
	print("[WildcardRunChallenge] WILDCARD! Random debuff applied: %s" % _applied_debuff_id)
	print("[WildcardRunChallenge] Debuff description: %s" % selected_debuff.description)

## remove()
##
## Cleans up the challenge by removing the random debuff and disconnecting signals.
func remove() -> void:
	if _game_controller:
		# Remove the randomly applied debuff if any
		if not _applied_debuff_id.is_empty() and _game_controller.is_debuff_active(_applied_debuff_id):
			_game_controller.disable_debuff(_applied_debuff_id)
			print("[WildcardRunChallenge] Disabled random debuff: %s" % _applied_debuff_id)
		
		# Disconnect signals
		if _scorecard:
			if _scorecard.is_connected("score_changed", _on_score_changed):
				_scorecard.disconnect("score_changed", _on_score_changed)
			if _scorecard.is_connected("game_completed", _on_game_completed):
				_scorecard.disconnect("game_completed", _on_game_completed)
		
		if _round_manager:
			if _round_manager.is_connected("round_started", _on_round_started):
				_round_manager.disconnect("round_started", _on_round_started)
	
	# Reset state
	_debuff_applied = false
	_applied_debuff_id = ""

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
	print("[WildcardRunChallenge] Progress updated: %.2f" % progress)

## _on_score_changed(total_score)
##
## Handles score change events to track progress and check for completion.
func _on_score_changed(total_score: int) -> void:
	print("[WildcardRunChallenge] Score changed! New total: %d" % total_score)
	_update_progress()
	
	# Check if we've met the target
	if total_score >= _target_score:
		print("[WildcardRunChallenge] Target score reached! Challenge completed.")
		emit_signal("challenge_completed")
		end()

## _on_game_completed()
##
## Handles game completion to determine if the challenge was successful.
func _on_game_completed() -> void:
	if _scorecard and _scorecard.get_total_score() >= _target_score:
		print("[WildcardRunChallenge] Game completed with target score reached!")
		emit_signal("challenge_completed")
	else:
		print("[WildcardRunChallenge] Game completed but target score not reached.")
		emit_signal("challenge_failed")
	end()

## set_target_score_from_resource(resource, _round_number)
##
## Sets the target score from the ChallengeData resource.
func set_target_score_from_resource(resource: ChallengeData, _round_number: int) -> void:
	if resource:
		_target_score = resource.target_score
		print("[WildcardRunChallenge] Target score set from resource: %d" % _target_score)
