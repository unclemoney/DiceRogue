extends Debuff
class_name AllPowerUpsSoldDebuff

## AllPowerUpsSoldDebuff
##
## Immediately sells all of the player's active power-ups, giving them
## money for each (half price refund). This is a one-time destructive
## effect — once applied, the power-ups are permanently gone.
## The remove() method is a no-op since the effect cannot be undone.

var game_controller: Node
var total_refund: int = 0
var powerups_sold: int = 0

## apply(_target)
##
## Iterates through all active power-ups, calculates a half-price refund
## for each, deactivates and revokes them, removes them from the UI, and
## awards the total refund to the player.
func apply(_target) -> void:
	print("[AllPowerUpsSold] Applied - Liquidating all powerups")
	self.target = _target
	game_controller = _target

	if not game_controller:
		push_error("[AllPowerUpsSold] No GameController target")
		return

	# Snapshot the current power-up IDs (avoid modifying dict during iteration)
	var active_ids: Array = game_controller.active_power_ups.keys().duplicate()

	if active_ids.is_empty():
		print("[AllPowerUpsSold] No powerups to sell")
		return

	total_refund = 0
	powerups_sold = 0

	for power_up_id in active_ids:
		var pu = game_controller.active_power_ups.get(power_up_id)
		if not pu or not is_instance_valid(pu):
			continue

		# Calculate refund (half price)
		var def = game_controller.pu_manager.get_def(power_up_id)
		var refund: int = 0
		if def:
			refund = int(def.price / 2.0)
			total_refund += refund

		# Deactivate, revoke, and remove from UI
		game_controller._deactivate_power_up(power_up_id)
		game_controller.revoke_power_up(power_up_id)
		if game_controller.powerup_ui:
			game_controller.powerup_ui.remove_power_up(power_up_id)

		powerups_sold += 1
		print("[AllPowerUpsSold] Sold '%s' for %d coins" % [power_up_id, refund])

	# Award the total refund
	if total_refund > 0:
		PlayerEconomy.add_money(total_refund)

	print("[AllPowerUpsSold] Sold %d powerups for %d total coins" % [powerups_sold, total_refund])

## remove()
##
## No-op. The effect is permanent — sold power-ups cannot be restored.
func remove() -> void:
	print("[AllPowerUpsSold] Removed (effect was permanent, %d powerups were sold for %d coins)" % [powerups_sold, total_refund])
