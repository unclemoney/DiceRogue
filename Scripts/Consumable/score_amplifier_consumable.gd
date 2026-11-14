extends Consumable
class_name ScoreAmplifierConsumable

## ScoreAmplifierConsumable
##
## Doubles all additive bonuses from ScoreModifierManager for the next score.
## Does not multiply the base score or other score multipliers.

const AMPLIFIER_MULTIPLIER := 2.0
const MODIFIER_SOURCE := "score_amplifier"

var _game_controller_ref: GameController = null
var _scorecard_ref: Scorecard = null

func _ready() -> void:
	add_to_group("consumables")
	print("[ScoreAmplifierConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[ScoreAmplifierConsumable] Invalid target passed to apply()")
		apply_succeeded = false
		return
	
	_game_controller_ref = game_controller
	
	var scorecard = game_controller.scorecard
	if not scorecard:
		push_error("[ScoreAmplifierConsumable] No scorecard found")
		apply_succeeded = false
		return
	
	_scorecard_ref = scorecard
	
	var score_modifier_manager = get_node_or_null("/root/ScoreModifierManager")
	if not score_modifier_manager:
		push_error("[ScoreAmplifierConsumable] ScoreModifierManager not found")
		apply_succeeded = false
		return
	if score_modifier_manager.get_total_additive() == 0:
		print("[ScoreAmplifierConsumable] No additive bonuses to amplify")
		apply_succeeded = false
		return
	
	score_modifier_manager.register_additive_multiplier(MODIFIER_SOURCE, AMPLIFIER_MULTIPLIER)
	print("[ScoreAmplifierConsumable] Registered %.1fx additive amplifier" % AMPLIFIER_MULTIPLIER)
	
	# Connect to score_assigned signal to remove multiplier after next score
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
		print("[ScoreAmplifierConsumable] Connected to score_assigned signal")

func _on_score_assigned(_section: Scorecard.Section, _category: String, _score: int) -> void:
	_disarm()


func _disarm() -> void:
	var score_modifier_manager = get_node_or_null("/root/ScoreModifierManager")
	if score_modifier_manager and score_modifier_manager.has_additive_multiplier(MODIFIER_SOURCE):
		score_modifier_manager.unregister_additive_multiplier(MODIFIER_SOURCE)
		print("[ScoreAmplifierConsumable] Removed additive amplifier after scoring")
	
	if is_instance_valid(_scorecard_ref):
		if _scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			_scorecard_ref.score_assigned.disconnect(_on_score_assigned)
	_scorecard_ref = null


func _exit_tree() -> void:
	_disarm()
