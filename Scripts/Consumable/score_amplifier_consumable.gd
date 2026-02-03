extends Consumable
class_name ScoreAmplifierConsumable

## ScoreAmplifierConsumable
##
## Doubles all additive bonuses from ScoreModifierManager for the next score.
## Registers a temporary 2x multiplier that is removed after scoring.

const AMPLIFIER_MULTIPLIER := 2.0

var _game_controller_ref: GameController = null
var _scorecard_ref: Scorecard = null

func _ready() -> void:
	add_to_group("consumables")
	print("[ScoreAmplifierConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[ScoreAmplifierConsumable] Invalid target passed to apply()")
		return
	
	_game_controller_ref = game_controller
	
	var scorecard = game_controller.scorecard
	if not scorecard:
		push_error("[ScoreAmplifierConsumable] No scorecard found")
		return
	
	_scorecard_ref = scorecard
	
	# Register the amplifier multiplier
	var score_modifier_manager = get_node_or_null("/root/ScoreModifierManager")
	if not score_modifier_manager:
		push_error("[ScoreAmplifierConsumable] ScoreModifierManager not found")
		return
	
	if score_modifier_manager.has_method("register_multiplier"):
		score_modifier_manager.register_multiplier("score_amplifier", AMPLIFIER_MULTIPLIER)
		print("[ScoreAmplifierConsumable] Registered %.1fx amplifier multiplier" % AMPLIFIER_MULTIPLIER)
	
	# Connect to score_assigned signal to remove multiplier after next score
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
		print("[ScoreAmplifierConsumable] Connected to score_assigned signal")

func _on_score_assigned(_section: Scorecard.Section, _category: String, _score: int) -> void:
	# Unregister the amplifier after scoring
	var score_modifier_manager = get_node_or_null("/root/ScoreModifierManager")
	if score_modifier_manager and score_modifier_manager.has_method("unregister_multiplier"):
		score_modifier_manager.unregister_multiplier("score_amplifier")
		print("[ScoreAmplifierConsumable] Removed amplifier multiplier after scoring")
	
	# Disconnect from signal
	if _scorecard_ref and _scorecard_ref.is_connected("score_assigned", _on_score_assigned):
		_scorecard_ref.score_assigned.disconnect(_on_score_assigned)
		print("[ScoreAmplifierConsumable] Disconnected from score_assigned signal")
