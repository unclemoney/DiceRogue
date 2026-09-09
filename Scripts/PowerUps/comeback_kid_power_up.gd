extends PowerUp
class_name ComebackKidPowerUp

## ComebackKidPowerUp
##
## Rare build-around PowerUp: every score gets +5 per category currently
## sitting at a scored 0 (null/unscored does not count). Registers a
## temporary additive on ScoreModifierManager during the about_to_score
## window and unregisters after score_assigned (LowerTen lifecycle).
## apply() target is the Scorecard, matching LowerTenPowerUp.

const BONUS_PER_ZERO: int = 5

# ScoreModifierManager source name
var modifier_source_name: String = "comeback_kid"

# Reference to target scorecard
var scorecard_ref: Scorecard = null
var score_card_ui_ref: Node = null

var _debug_enabled: bool = OS.is_debug_build()

signal description_updated(power_up_id: String, new_description: String)


func _ready() -> void:
	add_to_group("power_ups")
	if _debug_enabled:
		print("[ComebackKidPowerUp] Added to 'power_ups' group")


## count_zero_scores(upper_scores, lower_scores) -> int
##
## Counts categories scored exactly 0 across both sections. Null (unscored)
## entries do not count.
static func count_zero_scores(upper_scores: Dictionary, lower_scores: Dictionary) -> int:
	var count := 0
	for score in upper_scores.values():
		if score != null and int(score) == 0:
			count += 1
	for score in lower_scores.values():
		if score != null and int(score) == 0:
			count += 1
	return count


func _register_additive(amount: int) -> void:
	if ScoreModifierManager == null:
		return
	ScoreModifierManager.register_additive(modifier_source_name, amount)
	if _debug_enabled:
		print("[ComebackKidPowerUp] Registered additive: +%d" % amount)


func _unregister_additive() -> void:
	if ScoreModifierManager == null:
		return
	if ScoreModifierManager.has_additive(modifier_source_name):
		ScoreModifierManager.unregister_additive(modifier_source_name)
		if _debug_enabled:
			print("[ComebackKidPowerUp] Unregistered additive")


func _on_about_to_score(_section: Scorecard.Section, _category: String, _dice_values: Array[int]) -> void:
	if not scorecard_ref:
		return
	var zero_count := count_zero_scores(scorecard_ref.upper_scores, scorecard_ref.lower_scores)
	if zero_count > 0:
		_register_additive(zero_count * BONUS_PER_ZERO)
	else:
		_unregister_additive()


func _on_score_assigned(_section: Scorecard.Section, _category: String, _score: int) -> void:
	# Clean up additive after any scoring to reset state
	_unregister_additive()
	emit_signal("description_updated", id, get_current_description())


func apply(target) -> void:
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[ComebackKidPowerUp] Target is not a Scorecard")
		return

	scorecard_ref = scorecard

	# Connect to about_to_score signal to register the additive before
	# score calculation, via GameController's score_card_ui (LowerTen pattern)
	var game_controller = scorecard.get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.score_card_ui:
		score_card_ui_ref = game_controller.score_card_ui
		if not score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.connect(_on_about_to_score)
			if _debug_enabled:
				print("[ComebackKidPowerUp] Connected to about_to_score signal")
	else:
		push_error("[ComebackKidPowerUp] Could not find ScoreCardUI via GameController")

	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)

	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

	if _debug_enabled:
		print("[ComebackKidPowerUp] Applied successfully - +%d per 0-scored category" % BONUS_PER_ZERO)


func remove(target) -> void:
	_unregister_additive()

	if score_card_ui_ref and score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
		score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)

	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		scorecard = scorecard_ref

	if scorecard:
		if scorecard.is_connected("score_assigned", _on_score_assigned):
			scorecard.score_assigned.disconnect(_on_score_assigned)

	scorecard_ref = null
	score_card_ui_ref = null


func get_current_description() -> String:
	var zero_count := 0
	if scorecard_ref:
		zero_count = count_zero_scores(scorecard_ref.upper_scores, scorecard_ref.lower_scores)
	return "+%d for each 0-scored category (currently +%d)" % [BONUS_PER_ZERO, zero_count * BONUS_PER_ZERO]


func _on_tree_exiting() -> void:
	_unregister_additive()

	if score_card_ui_ref and score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
		score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)

	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
