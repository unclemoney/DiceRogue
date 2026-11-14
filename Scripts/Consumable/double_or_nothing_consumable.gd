extends Consumable
class_name DoubleOrNothingConsumable

## DoubleOrNothingConsumable
##
## This consumable MUST be used at the beginning of a turn (after Next Turn, before first Roll).
## If a Yahtzee is rolled during that turn, the Yahtzee score is multiplied by 2.
## If no Yahtzee is rolled, the next score placed is 0.

# Signals for consumable events
signal double_or_nothing_applied
signal yahtzee_doubled(original_score: int, doubled_score: int)
signal score_zeroed(category: String)

var is_active: bool = false
var turn_activated: int = -1
var game_controller_ref: GameController = null
var scorecard_ref: Scorecard = null
var yahtzee_found: bool = false
var has_zeroed_score: bool = false

func _ready() -> void:
	add_to_group("consumables")
	print("[DoubleOrNothingConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[DoubleOrNothingConsumable] Invalid target passed to apply()")
		apply_succeeded = false
		return
	
	# Store references
	game_controller_ref = game_controller
	scorecard_ref = game_controller.scorecard
	if not scorecard_ref:
		push_error("[DoubleOrNothingConsumable] No scorecard found in game controller")
		apply_succeeded = false
		return
	
	# Get current turn number
	var turn_tracker = game_controller.turn_tracker
	if not turn_tracker:
		push_error("[DoubleOrNothingConsumable] No turn tracker found")
		apply_succeeded = false
		return
	
	# Store the turn we're activated on
	turn_activated = turn_tracker.current_turn
	is_active = true
	yahtzee_found = false
	has_zeroed_score = false
	
	print("[DoubleOrNothingConsumable] Applied for turn ", turn_activated)
	
	# Register a zero multiplier by default - this ensures all scores will be 0
	# We'll remove this multiplier only if a yahtzee is scored
	ScoreModifierManager.register_multiplier("double_or_nothing_zero", 0.0)
	print("[DoubleOrNothingConsumable] Registered zero multiplier - all scores will be 0 unless yahtzee")
	
	# Connect to yahtzee_rolled signal from RollStats to detect yahtzee before scoring
	if RollStats and not RollStats.is_connected("yahtzee_rolled", _on_yahtzee_rolled):
		RollStats.yahtzee_rolled.connect(_on_yahtzee_rolled)
		print("[DoubleOrNothingConsumable] Connected to yahtzee_rolled signal")
	
	# Connect to score_assigned signal to monitor scoring
	if not scorecard_ref.is_connected("score_assigned", _on_score_assigned):
		scorecard_ref.score_assigned.connect(_on_score_assigned)
		print("[DoubleOrNothingConsumable] Connected to score_assigned signal")
	
	# Connect to turn_started signal to detect if we're no longer on the active turn
	if not turn_tracker.is_connected("turn_started", _on_turn_started):
		turn_tracker.turn_started.connect(_on_turn_started)
		print("[DoubleOrNothingConsumable] Connected to turn_started signal")
	
	emit_signal("double_or_nothing_applied")

func _on_yahtzee_rolled() -> void:
	if not is_active:
		return
	
	print("[DoubleOrNothingConsumable] Yahtzee rolled! Removing zero multiplier and applying 2x multiplier")
	yahtzee_found = true
	
	# Remove the zero multiplier
	if ScoreModifierManager.has_multiplier("double_or_nothing_zero"):
		ScoreModifierManager.unregister_multiplier("double_or_nothing_zero")
	
	# Register the 2x multiplier for yahtzee scoring
	ScoreModifierManager.register_multiplier("double_or_nothing_yahtzee", 2.0)

func _on_score_assigned(_section: int, category: String, score: int) -> void:
	if not is_active:
		return
	
	print("[DoubleOrNothingConsumable] Score changed: ", category, " = ", score)
	
	# Check if this is a yahtzee being scored
	if category == "yahtzee" and yahtzee_found:
		print("[DoubleOrNothingConsumable] Yahtzee scored with our multiplier! Final score: ", score)
		emit_signal("yahtzee_doubled", 50, score)
		
		# Clean up yahtzee multiplier
		if ScoreModifierManager.has_multiplier("double_or_nothing_yahtzee"):
			ScoreModifierManager.unregister_multiplier("double_or_nothing_yahtzee")
		
		# Deactivate after successful yahtzee
		_deactivate()
	
	# For any score (yahtzee or non-yahtzee), we've used the consumable
	elif not yahtzee_found:
		# No yahtzee was rolled, so this score would be 0 due to our zero multiplier
		print("[DoubleOrNothingConsumable] No yahtzee rolled, score is 0 for ", category)
		has_zeroed_score = true
		emit_signal("score_zeroed", category)
		
		# Deactivate after scoring (whether 0 or not)
		_deactivate()
	else:
		print("[DoubleOrNothingConsumable] Yahtzee rolled but not scored - deactivating")
		_deactivate()

func _on_turn_started() -> void:
	if not is_active:
		return
	
	# If a new turn has started and we haven't found a yahtzee, 
	# we should deactivate (though normally a score would have been placed)
	var turn_tracker = game_controller_ref.turn_tracker if game_controller_ref else null
	if turn_tracker and turn_tracker.current_turn != turn_activated:
		print("[DoubleOrNothingConsumable] Turn changed, deactivating")
		_deactivate()

func _deactivate() -> void:
	if not is_active:
		return
		
	print("[DoubleOrNothingConsumable] Deactivating")
	is_active = false
	
	# Disconnect from signals
	if scorecard_ref and scorecard_ref.is_connected("score_assigned", _on_score_assigned):
		scorecard_ref.score_assigned.disconnect(_on_score_assigned)
	
	if game_controller_ref and game_controller_ref.turn_tracker:
		var turn_tracker = game_controller_ref.turn_tracker
		if turn_tracker.is_connected("turn_started", _on_turn_started):
			turn_tracker.turn_started.disconnect(_on_turn_started)
	
	# Clean up any remaining multipliers
	if ScoreModifierManager.has_multiplier("double_or_nothing_yahtzee"):
		ScoreModifierManager.unregister_multiplier("double_or_nothing_yahtzee")
	if ScoreModifierManager.has_multiplier("double_or_nothing_zero"):
		ScoreModifierManager.unregister_multiplier("double_or_nothing_zero")
	
	# Disconnect from RollStats if connected
	if RollStats and RollStats.is_connected("yahtzee_rolled", _on_yahtzee_rolled):
		RollStats.yahtzee_rolled.disconnect(_on_yahtzee_rolled)


func _exit_tree() -> void:
	_deactivate()