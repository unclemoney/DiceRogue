extends Debuff
class_name LockDiceDebuff

#var is_active := false Moved to parent class

func _ready() -> void:
	add_to_group("debuffs")
	print("[LockDiceDebuff] Ready")

func apply(_target) -> void:
	self.target = _target
	print("[LockDiceDebuff] Applying to target:", _target.name if _target else "null")
	var dice_hand = _target as DiceHand
	if dice_hand:
		is_active = true
		print("[LockDiceDebuff] Disabling dice locking (dice remain scoreable)")
		dice_hand.disable_locking_only()
	else:
		push_error("[LockDiceDebuff] Invalid target passed to apply()")

func _on_dice_added(node: Node) -> void:
	if node is Dice:
		print("[LockDiceDebuff] New die added - applying lock disable")
		node.set_debuff_locking_disabled(true)
		node.set_lock_shader_enabled(false)

func remove() -> void:
	print("[LockDiceDebuff] Removing effect")
	var dice_hand = target as DiceHand
	if dice_hand:
		is_active = false
		print("[LockDiceDebuff] Restoring dice locking ability")
		dice_hand.restore_locking()
