extends GamingConsole
class_name SegaConsole

## SegaConsole — Combo System
##
## PASSIVE: Maintains a running combo counter. Each time a category is scored
## with a value > 0, the combo increments. Scoring 0 resets the combo.
## Grants combo_count × 3 as an additive score bonus.

var scorecard_ref: Scorecard = null
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
	if not scorecard_ref.is_connected("score_auto_assigned", _on_score_auto_assigned):
		scorecard_ref.score_auto_assigned.connect(_on_score_auto_assigned)

	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	print("[SegaConsole] Applied — Combo System ready")


func remove(_target_node) -> void:
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
		if scorecard_ref.is_connected("score_auto_assigned", _on_score_auto_assigned):
			scorecard_ref.score_auto_assigned.disconnect(_on_score_auto_assigned)
	if ScoreModifierManager.has_additive(modifier_source_name):
		ScoreModifierManager.unregister_additive(modifier_source_name)
	scorecard_ref = null
	super.remove(_target_node)


func _on_score_assigned(_section: Scorecard.Section, _category: String, score: int) -> void:
	_process_score(score)


func _on_score_auto_assigned(_section: Scorecard.Section, _category: String, score: int, _breakdown_info: Dictionary = {}) -> void:
	_process_score(score)


func _process_score(score: int) -> void:
	if score > 0:
		combo_count += 1
		print("[SegaConsole] Combo! Count: %d (+%d bonus)" % [combo_count, combo_count * bonus_per_combo])
	else:
		combo_count = 0
		print("[SegaConsole] Combo broken! Reset to 0")

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
	if ScoreModifierManager and ScoreModifierManager.has_additive(modifier_source_name):
		ScoreModifierManager.unregister_additive(modifier_source_name)
	scorecard_ref = null
