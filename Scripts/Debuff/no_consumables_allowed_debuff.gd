extends Debuff
class_name NoConsumablesAllowedDebuff

## NoConsumablesAllowedDebuff
##
## Prevents the player from using any consumables during gameplay.
## The player can still sell consumables for money, but the USE button
## is disabled on all consumable icons. Works by setting a "consumables_blocked"
## meta flag on the CorkboardUI node, which _can_use_consumable checks.

var corkboard_ui: Node

## apply(_target)
##
## Sets the "consumables_blocked" meta flag on the CorkboardUI node,
## which causes _can_use_consumable to always return false.
## Also immediately updates usability on any currently fanned icons.
func apply(_target) -> void:
	print("[NoConsumablesAllowed] Applied - All consumable usage blocked")
	self.target = _target

	corkboard_ui = get_tree().get_first_node_in_group("corkboard_ui")
	if not corkboard_ui:
		push_error("[NoConsumablesAllowed] Could not find CorkboardUI")
		return

	# Set the blocking flag
	corkboard_ui.set_meta("consumables_blocked", true)
	print("[NoConsumablesAllowed] Set consumables_blocked meta flag")

	# Immediately update usability if icons are fanned out
	if corkboard_ui.has_method("update_consumable_usability"):
		corkboard_ui.update_consumable_usability()

## remove()
##
## Clears the "consumables_blocked" meta flag and refreshes
## the consumable usability state.
func remove() -> void:
	print("[NoConsumablesAllowed] Removed - Consumable usage restored")

	if corkboard_ui and is_instance_valid(corkboard_ui):
		corkboard_ui.set_meta("consumables_blocked", false)
		print("[NoConsumablesAllowed] Cleared consumables_blocked meta flag")

		# Refresh usability to re-enable buttons
		if corkboard_ui.has_method("update_consumable_usability"):
			corkboard_ui.update_consumable_usability()
