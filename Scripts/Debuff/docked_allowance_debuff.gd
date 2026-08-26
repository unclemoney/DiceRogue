extends Debuff
class_name DockedAllowanceDebuff

## DockedAllowanceDebuff (Grounding)
##
## While active, the end-of-round award is withheld entirely: no challenge
## reward, chore reward, bonuses, or power-up round-end payouts.
## The effect is a flag on GameController read by _on_stats_panel_continue().


func apply(new_target) -> void:
	print("[DockedAllowanceDebuff] Applied - end of round award docked")
	self.target = new_target
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if not game_controller:
		push_error("[DockedAllowanceDebuff] GameController not found")
		return
	game_controller.docked_allowance_active = true


func remove() -> void:
	print("[DockedAllowanceDebuff] Removed - allowance restored")
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller:
		game_controller.docked_allowance_active = false
