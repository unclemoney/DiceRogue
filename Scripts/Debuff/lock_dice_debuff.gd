extends Debuff
class_name LockDiceDebuff

var is_active := false

func _ready() -> void:
	add_to_group("debuffs")
	print("[LockDiceDebuff] Ready")

func apply(target) -> void:
	print("[LockDiceDebuff] Applying to target:", target.name if target else "null")
	var dice_hand = target as DiceHand
	if dice_hand:
		is_active = true
		var dice_count = dice_hand.get_child_count()
		print("[LockDiceDebuff] Found", dice_count, "dice in hand")
		
		if dice_count == 0:
			print("[LockDiceDebuff] No dice to disable - will need to apply after roll")
			return
			
		for die in dice_hand.get_children():
			if die is Dice:
				print("[LockDiceDebuff] - Disabling die:", die.name)
				die.unlock()  # Force unlock any locked dice
				die.set_dice_input_enabled(false)
				die.set_lock_shader_enabled(false)
				
		# Connect to dice_hand signals to catch new dice
		if not dice_hand.is_connected("child_entered_tree", _on_dice_added):
			dice_hand.child_entered_tree.connect(_on_dice_added)

func _on_dice_added(node: Node) -> void:
	if node is Dice:
		print("[LockDiceDebuff] New die added - applying lock disable")
		node.unlock()
		node.set_dice_input_enabled(false)
		node.set_lock_shader_enabled(false)

func remove() -> void:
	print("[LockDiceDebuff] Removing effect")
	var dice_hand = target as DiceHand
	if dice_hand:
		is_active = false
		print("[LockDiceDebuff] Re-enabling dice locking")
		
		# Disconnect from dice_hand signals
		if dice_hand.is_connected("child_entered_tree", _on_dice_added):
			dice_hand.child_entered_tree.disconnect(_on_dice_added)
			
		for die in dice_hand.get_children():
			if die is Dice:
				print("[LockDiceDebuff] - Re-enabling die:", die.name)
				die.set_dice_input_enabled(true)
				die.set_lock_shader_enabled(true)