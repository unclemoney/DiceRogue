extends Debuff
class_name MixedBagDebuff

## Mixed Bag Debuff
##
## Replaces some dice in the player's hand with smaller dice types,
## creating an uneven mixed pool (e.g., 3×d6 + 2×d4).
##
## Intensity scales the number of dice replaced:
##   1.0 → 1 die replaced with d4
##   2.0 → 2 dice replaced with d4
##   3.0+ → 3 dice replaced with d4
##
## The debuff stores original DiceData for proper cleanup on removal.

var original_dice_data: Array = []  # Array of DiceData for cleanup
var d4_data: DiceData = preload("res://Scripts/Dice/d4_dice.tres")


func _ready() -> void:
	add_to_group("debuffs")


## apply(_target)
##
## Replaces the last N dice in the hand with d4s.
## N is determined by intensity (clamped to hand size - 1 to keep at least 1 original).
func apply(_target) -> void:
	self.target = _target
	var dice_hand = target as DiceHand
	if not dice_hand:
		push_error("[MixedBagDebuff] Target is not a DiceHand")
		return
	
	# Store originals for removal
	original_dice_data.clear()
	for die in dice_hand.dice_list:
		original_dice_data.append(die.dice_data)
	
	# Calculate how many dice to replace based on intensity
	var count_to_replace = mini(int(intensity), dice_hand.dice_list.size() - 1)
	if count_to_replace < 1:
		count_to_replace = 1
	
	# Replace the last N dice with d4s
	var start_index = dice_hand.dice_list.size() - count_to_replace
	for i in range(start_index, dice_hand.dice_list.size()):
		var die = dice_hand.dice_list[i]
		die.dice_data = d4_data
		die.value = 1
		die.update_visual()
		print("[MixedBagDebuff] Replaced die %d with d4" % (i + 1))
	
	is_active = true
	print("[MixedBagDebuff] Applied: replaced %d dice with d4s (intensity: %.1f)" % [count_to_replace, intensity])


## remove()
##
## Restores all dice to their original DiceData.
func remove() -> void:
	var dice_hand = target as DiceHand
	if dice_hand and original_dice_data.size() > 0:
		var restore_count = mini(original_dice_data.size(), dice_hand.dice_list.size())
		for i in range(restore_count):
			dice_hand.dice_list[i].dice_data = original_dice_data[i]
			dice_hand.dice_list[i].value = 1
			dice_hand.dice_list[i].update_visual()
		print("[MixedBagDebuff] Restored %d dice to original types" % restore_count)
	original_dice_data.clear()
	is_active = false
