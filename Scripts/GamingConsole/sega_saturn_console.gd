extends GamingConsole
class_name SegaSaturnConsole

## SegaSaturnConsole — Double Action
##
## Once per round, activation arms the next committed score this round.
## That next score doubles score-related PowerUp additives, multipliers,
## and score-time money payouts.

var game_controller_ref = null


func apply(target) -> void:
	super.apply(target)
	game_controller_ref = target
	if not game_controller_ref:
		push_error("[SegaSaturnConsole] Target is not a GameController")
		return
	if not game_controller_ref.has_method("arm_sega_saturn_next_score"):
		push_error("[SegaSaturnConsole] Target is missing Sega Saturn score hooks")
		return
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	print("[SegaSaturnConsole] Applied — Double Action ready")


func remove(_target_node) -> void:
	if game_controller_ref and game_controller_ref.has_method("clear_sega_saturn_score_state"):
		game_controller_ref.clear_sega_saturn_score_state()
	game_controller_ref = null
	super.remove(_target_node)


func can_activate() -> bool:
	if not is_active:
		return false
	if not game_controller_ref:
		return false
	if uses_remaining <= 0:
		return false
	if game_controller_ref.has_method("is_sega_saturn_score_armed") and game_controller_ref.is_sega_saturn_score_armed():
		return false
	if game_controller_ref.has_method("is_sega_saturn_score_active") and game_controller_ref.is_sega_saturn_score_active():
		return false
	return not game_controller_ref.active_power_ups.is_empty()


func activate() -> void:
	if not can_activate():
		return
	if not game_controller_ref.arm_sega_saturn_next_score():
		return
	uses_remaining -= 1
	emit_signal("uses_changed", uses_remaining)
	emit_signal("description_updated", get_power_description())
	print("[SegaSaturnConsole] Armed for next committed score this round")


func reset_for_new_round() -> void:
	super.reset_for_new_round()
	if game_controller_ref and game_controller_ref.has_method("clear_sega_saturn_score_state"):
		game_controller_ref.clear_sega_saturn_score_state()
	emit_signal("description_updated", get_power_description())


func is_passive() -> bool:
	return false


func get_power_description() -> String:
	var held_count := 0
	if game_controller_ref:
		held_count = game_controller_ref.active_power_ups.size()
		if game_controller_ref.has_method("is_sega_saturn_score_armed") and game_controller_ref.is_sega_saturn_score_armed():
			return "Double Action: Next score doubles score-related PowerUps this round."
	if held_count <= 0:
		return "Double Action: Hold at least one PowerUp to arm the next score. [%d use/round]" % uses_per_round
	return "Double Action: Arm the next score to double score-related PowerUps. [%d held, %d use/round]" % [held_count, uses_per_round]


func _on_tree_exiting() -> void:
	if game_controller_ref and game_controller_ref.has_method("clear_sega_saturn_score_state"):
		game_controller_ref.clear_sega_saturn_score_state()
	game_controller_ref = null
