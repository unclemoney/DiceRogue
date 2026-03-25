extends GamingConsole
class_name NesConsole

## NesConsole — Power Glove
##
## After activating, the player clicks a die, then a +1/-1 popup appears.
## Selecting +1 or -1 adjusts that die's face value (clamped 1-6).
## Uses per round: 1.

signal awaiting_die_click
signal die_adjustment_complete

var dice_hand_ref: DiceHand = null
var _waiting_for_die: bool = false
var _selected_die: Dice = null


func apply(target) -> void:
	super.apply(target)
	dice_hand_ref = target as DiceHand
	if not dice_hand_ref:
		push_error("[NesConsole] Target is not a DiceHand")
		return
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	print("[NesConsole] Applied — Power Glove ready")


func remove(_target_node) -> void:
	_cancel_die_selection()
	dice_hand_ref = null
	super.remove(_target_node)


func can_activate() -> bool:
	if not is_active:
		return false
	if not dice_hand_ref:
		return false
	if _waiting_for_die:
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
	_waiting_for_die = true
	_connect_die_clicks()
	emit_signal("awaiting_die_click")
	emit_signal("description_updated", get_power_description())
	print("[NesConsole] Waiting for die selection...")


## adjust_die(amount)
##
## Called by the UI popup when the player picks +1 or -1.
func adjust_die(amount: int) -> void:
	if not _selected_die:
		return
	var new_value = clampi(_selected_die.value + amount, 1, _selected_die.dice_data.sides)
	_selected_die.value = new_value
	_selected_die.update_visual()
	# Sync DiceResults cache so scoring sees the updated value
	if dice_hand_ref:
		DiceResults.update_from_dice(dice_hand_ref.get_all_dice())
	print("[NesConsole] Adjusted die to %d" % new_value)

	_disconnect_die_clicks()
	_selected_die = null
	_waiting_for_die = false
	uses_remaining -= 1
	emit_signal("uses_changed", uses_remaining)
	emit_signal("die_adjustment_complete")
	emit_signal("description_updated", get_power_description())
	emit_signal("activated")


## adjust_specific_die(die, amount)
##
## Adjusts a specific die by the given amount without requiring die selection.
## Used by the per-die +/- buttons spawned by the UI.
func adjust_specific_die(die: Dice, amount: int) -> void:
	if not die:
		return
	var new_value = clampi(die.value + amount, 1, die.dice_data.sides)
	die.value = new_value
	die.update_visual()
	# Sync DiceResults cache so scoring sees the updated value
	if dice_hand_ref:
		DiceResults.update_from_dice(dice_hand_ref.get_all_dice())
	print("[NesConsole] Adjusted specific die to %d" % new_value)

	_disconnect_die_clicks()
	_selected_die = null
	_waiting_for_die = false
	uses_remaining -= 1
	emit_signal("uses_changed", uses_remaining)
	emit_signal("die_adjustment_complete")
	emit_signal("description_updated", get_power_description())
	emit_signal("activated")


func cancel_activation() -> void:
	_cancel_die_selection()
	emit_signal("description_updated", get_power_description())


func is_waiting_for_die() -> bool:
	return _waiting_for_die


func get_selected_die() -> Dice:
	return _selected_die


func _connect_die_clicks() -> void:
	if not dice_hand_ref:
		return
	for die in dice_hand_ref.get_all_dice():
		if die.get_state() == Dice.DiceState.ROLLED or die.get_state() == Dice.DiceState.LOCKED:
			if not die.is_connected("clicked", _on_die_clicked.bind(die)):
				die.connect("clicked", _on_die_clicked.bind(die))


func _disconnect_die_clicks() -> void:
	if not dice_hand_ref:
		return
	for die in dice_hand_ref.get_all_dice():
		if die.is_connected("clicked", _on_die_clicked.bind(die)):
			die.disconnect("clicked", _on_die_clicked.bind(die))


func _on_die_clicked(die: Dice) -> void:
	if not _waiting_for_die:
		return
	_selected_die = die
	_waiting_for_die = false
	print("[NesConsole] Die selected with value: %d" % die.value)


func _cancel_die_selection() -> void:
	_disconnect_die_clicks()
	_selected_die = null
	_waiting_for_die = false


func reset_for_new_round() -> void:
	super.reset_for_new_round()
	_cancel_die_selection()
	emit_signal("description_updated", get_power_description())


func is_passive() -> bool:
	return false


func get_power_description() -> String:
	if _waiting_for_die:
		return "Power Glove: Click a die to adjust it by +1 or -1."
	return "Power Glove: Adjust any die by +1 or -1. [%d use/round]" % uses_per_round


func _on_tree_exiting() -> void:
	_cancel_die_selection()
	dice_hand_ref = null
