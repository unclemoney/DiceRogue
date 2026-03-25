extends GamingConsole
class_name PlaystationConsole

## PlaystationConsole — Continue?
##
## PASSIVE: Auto-triggers when a challenge fails. Grants 3 bonus rolls
## so the player gets another chance to complete the round.
## Uses per round: 1 (one continue per round).

signal continue_triggered

var round_manager_ref = null
var turn_tracker_ref = null
var scorecard_ref = null
var bonus_rolls: int = 3
var _continued_this_round: bool = false


func apply(target) -> void:
	super.apply(target)
	# Target is the GameController — we need RoundManager, TurnTracker, and Scorecard
	var game_controller = target
	if game_controller.has_method("get") or true:
		round_manager_ref = game_controller.get("round_manager")
		turn_tracker_ref = game_controller.get("turn_tracker")
		scorecard_ref = game_controller.get("scorecard")

	if round_manager_ref and round_manager_ref.has_signal("round_failed"):
		if not round_manager_ref.is_connected("round_failed", _on_round_failed):
			round_manager_ref.round_failed.connect(_on_round_failed)

	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	print("[PlaystationConsole] Applied — Continue? ready")


func remove(_target_node) -> void:
	if round_manager_ref and round_manager_ref.has_signal("round_failed"):
		if round_manager_ref.is_connected("round_failed", _on_round_failed):
			round_manager_ref.round_failed.disconnect(_on_round_failed)
	round_manager_ref = null
	turn_tracker_ref = null
	scorecard_ref = null
	super.remove(_target_node)


func _on_round_failed(_round_number: int) -> void:
	if _continued_this_round:
		print("[PlaystationConsole] Already used Continue? this round")
		return
	if uses_remaining <= 0:
		print("[PlaystationConsole] No uses remaining")
		return
	_trigger_continue()


func _trigger_continue() -> void:
	_continued_this_round = true
	uses_remaining -= 1
	emit_signal("uses_changed", uses_remaining)

	if turn_tracker_ref:
		turn_tracker_ref.rolls_left += bonus_rolls
		turn_tracker_ref.emit_signal("rolls_updated", turn_tracker_ref.rolls_left)
		print("[PlaystationConsole] CONTINUE? Granted %d bonus rolls!" % bonus_rolls)

	# If the scorecard is completely full, enable score reroll so the player
	# can pick an existing category to re-score with the bonus rolls
	if scorecard_ref and _is_scorecard_full():
		var score_card_ui = get_tree().get_first_node_in_group("scorecard_ui")
		if score_card_ui and score_card_ui.has_method("activate_score_reroll"):
			score_card_ui.activate_score_reroll()
			print("[PlaystationConsole] Scorecard full — activated score reroll mode")

	emit_signal("continue_triggered")
	emit_signal("activated")
	emit_signal("description_updated", get_power_description())


func reset_for_new_round() -> void:
	super.reset_for_new_round()
	_continued_this_round = false
	emit_signal("description_updated", get_power_description())


func is_passive() -> bool:
	return true


func can_activate() -> bool:
	return false


func activate() -> void:
	pass


func get_power_description() -> String:
	if _continued_this_round:
		return "Continue?: USED this round. Granted +%d rolls on challenge failure." % bonus_rolls
	return "Continue?: Auto-grants +%d rolls when a challenge fails. [%d use/round]" % [bonus_rolls, uses_remaining]


func _is_scorecard_full() -> bool:
	if not scorecard_ref:
		return false
	for score in scorecard_ref.upper_scores.values():
		if score == null:
			return false
	for score in scorecard_ref.lower_scores.values():
		if score == null:
			return false
	return true


func _on_tree_exiting() -> void:
	if round_manager_ref and round_manager_ref.is_connected("round_failed", _on_round_failed):
		round_manager_ref.round_failed.disconnect(_on_round_failed)
	round_manager_ref = null
	turn_tracker_ref = null
	scorecard_ref = null
