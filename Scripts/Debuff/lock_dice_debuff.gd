extends Debuff
class_name LockDiceDebuff

#var is_active := false Moved to parent class

func _ready() -> void:
	add_to_group("debuffs")
	print("[LockDiceDebuff] Ready")

func apply(target) -> void:
	print("[LockDiceDebuff] Applying to target:", target.name if target else "null")
	var dice_hand = target as DiceHand
	if dice_hand:
		is_active = true
		print("[LockDiceDebuff] Disabling dice locking")
		dice_hand.disable_all_dice()
	else:
		push_error("[LockDiceDebuff] Invalid target passed to apply()")

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
		dice_hand.enable_all_dice()
