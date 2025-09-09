extends Debuff
class_name DisabledTwosDebuff

func _ready() -> void:
	add_to_group("debuffs")
	print("[DisabledTwosDebuff] Ready")

func apply(target) -> void:
	print("[DisabledTwosDebuff] Applying to target:", target.name if target else "null")
	var dice_hand = target as DiceHand
	if dice_hand:
		is_active = true
		print("[DisabledTwosDebuff] Disabling twos in scoring")
		# Connect to roll_complete to check for twos
		if not dice_hand.is_connected("roll_complete", _on_roll_complete):
			dice_hand.roll_complete.connect(_on_roll_complete)
		_on_roll_complete()  # Apply immediately if there are dice
	else:
		push_error("[DisabledTwosDebuff] Invalid target passed to apply()")

func _on_roll_complete() -> void:
	var dice_hand = target as DiceHand
	if not dice_hand or not is_active:
		return
		
	print("[DisabledTwosDebuff] Checking for twos in roll")
	for die in dice_hand.dice_list:
		# Apply visual effect to twos
		if die.value == 2:
			print("[DisabledTwosDebuff] Found a two - applying visual effect")
			_apply_disabled_visual(die)
		else:
			_remove_disabled_visual(die)

func _apply_disabled_visual(die: Dice) -> void:
	if die:
		# Instead of directly setting a shader parameter, use the existing dice API
		if die.dice_material:
			die.dice_material.set_shader_parameter("disabled", true)
		else:
			print("[DisabledTwosDebuff] Dice shader material missing")

func _remove_disabled_visual(die: Dice) -> void:
	if die:
		if die.dice_material:
			die.dice_material.set_shader_parameter("disabled", false)

func remove() -> void:
	print("[DisabledTwosDebuff] Removing effect")
	var dice_hand = target as DiceHand
	if dice_hand:
		is_active = false
		if dice_hand.is_connected("roll_complete", _on_roll_complete):
			dice_hand.roll_complete.disconnect(_on_roll_complete)
			
		# Remove visual effect from all dice
		for die in dice_hand.dice_list:
			_remove_disabled_visual(die)
			
		print("[DisabledTwosDebuff] Removed disabled twos effect")
