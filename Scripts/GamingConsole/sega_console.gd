extends GamingConsole
class_name SegaConsole

## SegaConsole — Combo System
##
## PASSIVE: Maintains a running combo counter. Each time a category is scored
## with a value > 0, the combo increments. Scoring 0 resets the combo.
## Grants combo_count × 3 as an additive score bonus.
##
## Hooks into about_to_score (from ScoreCardUI) to pre-emptively remove the
## additive BEFORE score calculation when the base score would be 0. This
## prevents zero-base-score categories from being inflated by the combo bonus.

var scorecard_ref: Scorecard = null
var _score_card_ui_ref = null
var combo_count: int = 0
var bonus_per_combo: int = 3
var modifier_source_name: String = "combo_system"


func apply(target) -> void:
	super.apply(target)
	scorecard_ref = target as Scorecard
	if not scorecard_ref:
		push_error("[SegaConsole] Target is not a Scorecard")
		return

	if not scorecard_ref.is_connected("score_assigned", _on_score_assigned):
		scorecard_ref.score_assigned.connect(_on_score_assigned)

	# Connect to about_to_score on ScoreCardUI to pre-emptively handle zero scores
	_score_card_ui_ref = get_tree().get_first_node_in_group("scorecard_ui")
	if _score_card_ui_ref and _score_card_ui_ref.has_signal("about_to_score"):
		if not _score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			_score_card_ui_ref.about_to_score.connect(_on_about_to_score)

	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	print("[SegaConsole] Applied — Combo System ready")


func remove(_target_node) -> void:
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
	if _score_card_ui_ref and _score_card_ui_ref.has_signal("about_to_score"):
		if _score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			_score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
	if ScoreModifierManager.has_additive(modifier_source_name):
		ScoreModifierManager.unregister_additive(modifier_source_name)
	scorecard_ref = null
	_score_card_ui_ref = null
	super.remove(_target_node)


## _on_about_to_score()
##
## Pre-scoring hook: fires BEFORE score calculation. If the base score for
## the category is 0, immediately unregister the combo additive and reset
## the combo so the zero score isn't inflated by the bonus.
func _on_about_to_score(_section, category: String, dice_values) -> void:
	if not scorecard_ref:
		return
	var base = scorecard_ref._calculate_base_score(category, dice_values)
	if base == 0:
		# Pre-emptively remove additive so the zero score stays zero
		if ScoreModifierManager.has_additive(modifier_source_name):
			ScoreModifierManager.unregister_additive(modifier_source_name)
			print("[SegaConsole] Pre-emptive combo reset — base score is 0 for %s" % category)
		combo_count = 0


func _on_score_assigned(_section: Scorecard.Section, _category: String, score: int) -> void:
	_process_score(score)


func _process_score(_score: int) -> void:
	# Use the base score (before modifiers) to determine combo breaks
	var base = 0
	if scorecard_ref:
		base = scorecard_ref.last_base_score
	if base > 0:
		combo_count += 1
		print("[SegaConsole] Combo! Count: %d (+%d bonus) [base_score: %d]" % [combo_count, combo_count * bonus_per_combo, base])
	else:
		# Combo was already reset in _on_about_to_score, just ensure state is clean
		combo_count = 0
		print("[SegaConsole] Combo broken! Base score was 0, reset to 0")

	var total_bonus = combo_count * bonus_per_combo
	if total_bonus > 0:
		ScoreModifierManager.register_additive(modifier_source_name, total_bonus)
	else:
		if ScoreModifierManager.has_additive(modifier_source_name):
			ScoreModifierManager.unregister_additive(modifier_source_name)

	emit_signal("activated")
	emit_signal("description_updated", get_power_description())


func reset_for_new_round() -> void:
	# Combo persists across rounds within the same channel
	uses_remaining = uses_per_round
	emit_signal("uses_changed", uses_remaining)


func is_passive() -> bool:
	return true


func can_activate() -> bool:
	return false


func activate() -> void:
	pass


func get_power_description() -> String:
	var total_bonus = combo_count * bonus_per_combo
	return "Combo System: +%d per consecutive non-zero score. [Combo: %d, Bonus: +%d]" % [bonus_per_combo, combo_count, total_bonus]


func _on_tree_exiting() -> void:
	if _score_card_ui_ref and is_instance_valid(_score_card_ui_ref):
		if _score_card_ui_ref.has_signal("about_to_score"):
			if _score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
				_score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
	if ScoreModifierManager and ScoreModifierManager.has_additive(modifier_source_name):
		ScoreModifierManager.unregister_additive(modifier_source_name)
	scorecard_ref = null
	_score_card_ui_ref = null
