extends Debuff
class_name DisabledModsDebuff

## DisabledModsDebuff
##
## Disables all dice mods while active.
## Calls disable_all_mods() on all existing dice and any newly spawned dice.
## Re-enables mods on all affected dice when removed.

var dice_hand: Node
var affected_dice: Array = []

## apply(_target)
##
## Disables mods on all existing dice and connects to dice_spawned signal.
func apply(_target) -> void:
	print("[DisabledModsDebuff] Applied - Disabling all dice mods")
	self.target = _target
	
	# Target should be DiceHand
	dice_hand = _target
	if not dice_hand:
		dice_hand = get_tree().get_first_node_in_group("dice_hand")
	
	if not dice_hand:
		push_error("[DisabledModsDebuff] Failed to find DiceHand")
		return
	
	# Disable mods on all existing dice
	if dice_hand.has_method("get_dice_list"):
		for die in dice_hand.get_dice_list():
			if die and die.has_method("disable_all_mods"):
				die.disable_all_mods()
				affected_dice.append(die)
				print("[DisabledModsDebuff] Disabled mods on existing die")
	elif "dice_list" in dice_hand:
		for die in dice_hand.dice_list:
			if die and die.has_method("disable_all_mods"):
				die.disable_all_mods()
				affected_dice.append(die)
				print("[DisabledModsDebuff] Disabled mods on existing die")
	
	# Connect to dice_spawned signal to disable mods on new dice
	if dice_hand.has_signal("dice_spawned"):
		if not dice_hand.is_connected("dice_spawned", _on_dice_spawned):
			dice_hand.dice_spawned.connect(_on_dice_spawned)
			print("[DisabledModsDebuff] Connected to dice_spawned signal")

## remove()
##
## Re-enables mods on all affected dice and disconnects from signals.
func remove() -> void:
	print("[DisabledModsDebuff] Removed - Re-enabling all dice mods")
	
	# Re-enable mods on all affected dice
	for die in affected_dice:
		if is_instance_valid(die) and die.has_method("enable_all_mods"):
			die.enable_all_mods()
			print("[DisabledModsDebuff] Re-enabled mods on die")
	
	affected_dice.clear()
	
	# Disconnect from dice_spawned signal
	if dice_hand and dice_hand.has_signal("dice_spawned"):
		if dice_hand.is_connected("dice_spawned", _on_dice_spawned):
			dice_hand.dice_spawned.disconnect(_on_dice_spawned)
			print("[DisabledModsDebuff] Disconnected from dice_spawned")

## _on_dice_spawned()
##
## Called when dice are spawned. Disables mods on all newly spawned dice.
func _on_dice_spawned() -> void:
	# Get all dice and disable mods on any not already affected
	if dice_hand and "dice_list" in dice_hand:
		for die in dice_hand.dice_list:
			if die and die.has_method("disable_all_mods"):
				if not affected_dice.has(die):
					die.disable_all_mods()
					affected_dice.append(die)
					print("[DisabledModsDebuff] Disabled mods on newly spawned die")
