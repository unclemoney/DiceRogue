extends Debuff
class_name CouponsRevokedDebuff

## CouponsRevokedDebuff (Grounding)
##
## On apply, every coupon (consumable) the player currently holds is removed.
## One-shot effect at round start; coupons bought during the round are kept.


func apply(new_target) -> void:
	print("[CouponsRevokedDebuff] Applied - revoking held coupons")
	self.target = new_target
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if not game_controller:
		push_error("[CouponsRevokedDebuff] GameController not found")
		return
	game_controller._clear_all_consumables()
	request_visual_pulse(1.08, 0.58)
	var notification_system = get_tree().get_first_node_in_group("notification_system")
	if notification_system:
		notification_system.show_notification("Coupons Revoked!")


func remove() -> void:
	# One-shot effect; nothing to restore.
	pass
