extends GamingConsole
class_name SegaSaturnConsole

## SegaSaturnConsole — Cartridge Tilt
##
## After activating, a popup appears with "+1 ALL" and "-1 ALL" buttons.
## Selecting one shifts ALL unlocked dice by that amount (clamped 1-6).
## Uses per round: 1.

signal awaiting_tilt_choice
signal tilt_complete

var dice_hand_ref: DiceHand = null
var _waiting_for_choice: bool = false


func apply(target) -> void:
	super.apply(target)
	dice_hand_ref = target as DiceHand
	if not dice_hand_ref:
		push_error("[SegaSaturnConsole] Target is not a DiceHand")
		return
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	print("[SegaSaturnConsole] Applied — Cartridge Tilt ready")


func remove(_target_node) -> void:
	_waiting_for_choice = false
	dice_hand_ref = null
	super.remove(_target_node)


func can_activate() -> bool:
	if not is_active:
		return false
	if not dice_hand_ref:
		return false
	if _waiting_for_choice:
		return false
	if uses_remaining <= 0:
		return false
	var dice_list = dice_hand_ref.get_all_dice()
	for die in dice_list:
		if die.get_state() == Dice.DiceState.ROLLED or die.get_state() == Dice.DiceState.LOCKED:
			return true
	return false


func activate() -> void:
	if not can_activate():
		return
	_waiting_for_choice = true
	emit_signal("awaiting_tilt_choice")
	emit_signal("description_updated", get_power_description())
	print("[SegaSaturnConsole] Waiting for +1/-1 choice...")


## apply_tilt(amount)
##
## Called by the UI when the player selects +1 or -1.
## Shifts all unlocked (ROLLED or LOCKED) dice by amount, clamped to valid range.
func apply_tilt(amount: int) -> void:
	if not _waiting_for_choice:
		return
	if not dice_hand_ref:
		return

	var dice_list = dice_hand_ref.get_all_dice()
	var adjusted_count = 0
	for die in dice_list:
		if die.get_state() == Dice.DiceState.ROLLED or die.get_state() == Dice.DiceState.LOCKED:
			var new_value = clampi(die.value + amount, 1, die.dice_data.sides)
			die.value = new_value
			die.update_visual()
			adjusted_count += 1

	var direction = "+1" if amount > 0 else "-1"
	print("[SegaSaturnConsole] Cartridge Tilt %s applied to %d dice" % [direction, adjusted_count])

	_waiting_for_choice = false
	uses_remaining -= 1
	emit_signal("uses_changed", uses_remaining)
	emit_signal("tilt_complete")
	emit_signal("description_updated", get_power_description())
	emit_signal("activated")


func cancel_activation() -> void:
	_waiting_for_choice = false
	emit_signal("description_updated", get_power_description())


func is_waiting_for_choice() -> bool:
	return _waiting_for_choice


func reset_for_new_round() -> void:
	super.reset_for_new_round()
	_waiting_for_choice = false
	emit_signal("description_updated", get_power_description())


func is_passive() -> bool:
	return false


func get_power_description() -> String:
	if _waiting_for_choice:
		return "Cartridge Tilt: Choose +1 ALL or -1 ALL to shift all dice!"
	return "Cartridge Tilt: Shift all unlocked dice by +1 or -1. [%d use/round]" % uses_per_round


func _on_tree_exiting() -> void:
	_waiting_for_choice = false
	dice_hand_ref = null
