extends Debuff
class_name PogsConfiscatedDebuff

## PogsConfiscatedDebuff (Grounding)
##
## On apply, randomly revokes POGs (power-ups) from the player's collection.
## The confiscation count scales with the player's REP tier:
## tiers 0-1 -> 1 POG, tiers 2-3 -> 2 POGs, tier 4 -> 3 POGs.
## No-op when the player holds no POGs.


## get_confiscation_count() -> int
##
## Returns how many POGs to confiscate for the current REP tier.
func get_confiscation_count() -> int:
	var tier: int = ProgressManager.get_rep_tier()
	if tier >= 4:
		return 3
	if tier >= 2:
		return 2
	return 1


func apply(new_target) -> void:
	print("[PogsConfiscatedDebuff] Applied - confiscating POGs")
	self.target = new_target
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if not game_controller:
		push_error("[PogsConfiscatedDebuff] GameController not found")
		return

	var held: Array = game_controller.active_power_ups.keys()
	if held.is_empty():
		print("[PogsConfiscatedDebuff] Player holds no POGs - no-op")
		return

	var count: int = mini(get_confiscation_count(), held.size())
	held.shuffle()
	for i in range(count):
		print("[PogsConfiscatedDebuff] Confiscating:", held[i])
		game_controller.revoke_power_up(held[i])

	request_visual_pulse(1.08, 0.58)
	var notification_system = get_tree().get_first_node_in_group("notification_system")
	if notification_system:
		notification_system.show_notification("%d POG(s) Confiscated!" % count)


func remove() -> void:
	# One-shot effect; confiscated POGs are not returned.
	pass
