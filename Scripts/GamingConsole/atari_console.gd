extends GamingConsole
class_name AtariConsole

## AtariConsole — Save State
##
## Saves the current dice values when activated the first time,
## then restores them when activated the second time.
## Uses per round: 1 full save/load cycle.

enum SaveMode { SAVE, LOAD }

var current_mode: SaveMode = SaveMode.SAVE
var saved_values: Array[int] = []
var saved_lock_states: Array[bool] = []
var dice_hand_ref: DiceHand = null


func apply(target) -> void:
	super.apply(target)
	dice_hand_ref = target as DiceHand
	if not dice_hand_ref:
		push_error("[AtariConsole] Target is not a DiceHand")
		return
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	print("[AtariConsole] Applied — Save State ready")


func remove(_target_node) -> void:
	_clear_saved_state()
	dice_hand_ref = null
	super.remove(_target_node)


func can_activate() -> bool:
	if not is_active:
		return false
	if not dice_hand_ref:
		return false
	if current_mode == SaveMode.SAVE:
		var dice_list = dice_hand_ref.get_all_dice()
		if dice_list.is_empty():
			return false
		var has_rolled = false
		for die in dice_list:
			if die.get_state() == Dice.DiceState.ROLLED or die.get_state() == Dice.DiceState.LOCKED:
				has_rolled = true
				break
		return has_rolled
	else:
		return saved_values.size() > 0 and uses_remaining > 0


func activate() -> void:
	if not can_activate():
		return

	if current_mode == SaveMode.SAVE:
		_save_dice_state()
		current_mode = SaveMode.LOAD
		emit_signal("description_updated", get_power_description())
		emit_signal("activated")
	else:
		_load_dice_state()
		current_mode = SaveMode.SAVE
		uses_remaining -= 1
		emit_signal("uses_changed", uses_remaining)
		emit_signal("description_updated", get_power_description())
		emit_signal("activated")


func _save_dice_state() -> void:
	saved_values.clear()
	saved_lock_states.clear()
	var dice_list = dice_hand_ref.get_all_dice()
	for die in dice_list:
		saved_values.append(die.value)
		saved_lock_states.append(die.is_locked)
	print("[AtariConsole] Saved dice state: %s" % str(saved_values))


func _load_dice_state() -> void:
	if saved_values.is_empty():
		return
	var dice_list = dice_hand_ref.get_all_dice()
	var count = mini(dice_list.size(), saved_values.size())
	for i in range(count):
		dice_list[i].value = saved_values[i]
		dice_list[i].update_visual()
		if saved_lock_states[i]:
			if dice_list[i].get_state() != Dice.DiceState.LOCKED:
				dice_list[i].set_state(Dice.DiceState.LOCKED)
		else:
			if dice_list[i].get_state() == Dice.DiceState.LOCKED:
				dice_list[i].set_state(Dice.DiceState.ROLLED)
	# Sync DiceResults cache so scoring sees the updated values
	if dice_hand_ref:
		DiceResults.update_from_dice(dice_hand_ref.get_all_dice())
	print("[AtariConsole] Loaded dice state: %s" % str(saved_values))
	_clear_saved_state()


func _clear_saved_state() -> void:
	saved_values.clear()
	saved_lock_states.clear()
	current_mode = SaveMode.SAVE


func reset_for_new_round() -> void:
	super.reset_for_new_round()
	_clear_saved_state()
	emit_signal("description_updated", get_power_description())


func is_passive() -> bool:
	return false


func get_power_description() -> String:
	if current_mode == SaveMode.SAVE:
		return "Save State: Save your current dice, then load them later. [%d use/round]" % uses_per_round
	else:
		return "Save State: Dice saved! Activate again to LOAD. Values: %s" % str(saved_values)


func _on_tree_exiting() -> void:
	_clear_saved_state()
	dice_hand_ref = null
