extends PowerUp
class_name StepByStepPowerUp

## StepByStepPowerUp
##
## A common PowerUp that adds +6 additive bonus to every upper section score only.
## This bonus is applied through the Scorecard's score_modifiers system and only affects
## upper section categories (ones, twos, threes, fours, fives, sixes).
## Lower section scores (Full House, etc.) are not affected.

# PowerUp configuration
const ADDITIVE_BONUS: int = 6

# Reference to target scorecard
var scorecard_ref: Scorecard = null

# Track upper section scores that have received the bonus
var upper_scores_applied: int = 0

signal description_updated(power_up_id: String, new_description: String)

# Score modifier interface
var modifier_name: String = "StepByStepPowerUp"

func _ready() -> void:
	add_to_group("power_ups")
	print("[StepByStepPowerUp] Added to 'power_ups' group")

func apply(target) -> void:
	print("=== Applying StepByStepPowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[StepByStepPowerUp] Target is not a Scorecard")
		return
	
	# Store reference to the scorecard
	scorecard_ref = scorecard
	
	# Register this PowerUp as a score modifier
	scorecard.register_score_modifier(self)
	print("[StepByStepPowerUp] Registered as score modifier")
	
	# Connect to score assignment signals for tracking purposes
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
		print("[StepByStepPowerUp] Connected to score_assigned signal for tracking")
	
	# Connect to tree_exiting for cleanup
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	
	print("[StepByStepPowerUp] Applied successfully - will add +%d to upper section scores only" % ADDITIVE_BONUS)

func remove(target) -> void:
	print("=== Removing StepByStepPowerUp ===")
	
	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		scorecard = scorecard_ref
	
	if scorecard:
		# Unregister as score modifier
		scorecard.unregister_score_modifier(self)
		print("[StepByStepPowerUp] Unregistered as score modifier")
		
		# Disconnect signals
		if scorecard.is_connected("score_assigned", _on_score_assigned):
			scorecard.score_assigned.disconnect(_on_score_assigned)
	
	scorecard_ref = null
	upper_scores_applied = 0

## modify_score(section, category, score)
##
## Score modifier interface method. Called by Scorecard for each score assignment.
## Returns modified score if this modifier applies, or null if it doesn't.
func modify_score(section: int, category: String, score: int):
	if section == Scorecard.Section.UPPER:
		var modified_score = score + ADDITIVE_BONUS
		print("[StepByStepPowerUp] Modifying upper section score for %s: %d -> %d" % [category, score, modified_score])
		return modified_score
	else:
		# Don't modify lower section scores
		return null

func _on_score_assigned(section: Scorecard.Section, category: String, _score: int) -> void:
	# Track upper section score applications for description updates
	if section == Scorecard.Section.UPPER:
		upper_scores_applied += 1
		emit_signal("description_updated", id, get_current_description())
		print("[StepByStepPowerUp] Upper section score tracked: %s (total applied: %d)" % [category, upper_scores_applied])

func get_current_description() -> String:
	if upper_scores_applied > 0:
		return "Upper section scores get +%d (%d applied)" % [ADDITIVE_BONUS, upper_scores_applied]
	else:
		return "Upper section scores get +%d" % ADDITIVE_BONUS

func _on_tree_exiting() -> void:
	# Cleanup when PowerUp is destroyed
	if scorecard_ref:
		scorecard_ref.unregister_score_modifier(self)
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
		print("[StepByStepPowerUp] Cleanup: Unregistered score modifier")