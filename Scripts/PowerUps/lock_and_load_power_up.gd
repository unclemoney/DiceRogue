extends PowerUp
class_name LockAndLoadPowerUp

## LockAndLoadPowerUp
##
## Grants $3 for each die locked during a turn.
## Money is added to the round-end PowerUp bonus based on locks performed.
## Encourages strategic locking behavior.
## Common rarity, $75 price.

# Reference to dice hand and turn tracker
var dice_hand_ref: DiceHand = null
var turn_tracker_ref: TurnTracker = null

# Track locks this turn and queue them for round-end payout
var locks_this_turn: int = 0
var total_money_granted: int = 0
var pending_round_end_bonus: int = 0

const MONEY_PER_LOCK: int = 3

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying LockAndLoadPowerUp ===")
	var dice_hand = target as DiceHand
	if not dice_hand:
		push_error("[LockAndLoadPowerUp] Target is not a DiceHand")
		return
	
	# Store reference to the dice hand
	dice_hand_ref = dice_hand
	
	# Get turn tracker from tree
	var tree = dice_hand.get_tree()
	if tree:
		turn_tracker_ref = tree.get_first_node_in_group("turn_tracker")
	
	# Connect to die_locked signal to track locks
	if not dice_hand.is_connected("die_locked", _on_die_locked):
		dice_hand.die_locked.connect(_on_die_locked)
		print("[LockAndLoadPowerUp] Connected to die_locked signal")
	
	# Connect to turn_started so completed turns roll into the round-end bonus bucket
	if turn_tracker_ref:
		if not turn_tracker_ref.is_connected("turn_started", _on_turn_started):
			turn_tracker_ref.turn_started.connect(_on_turn_started)
			print("[LockAndLoadPowerUp] Connected to turn_started signal")
	
	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func _on_die_locked(_die: Dice) -> void:
	locks_this_turn += 1
	print("[LockAndLoadPowerUp] Die locked - total this turn: %d" % locks_this_turn)
	
	# Update description to show current progress
	emit_signal("description_updated", id, get_current_description())
	
	if is_inside_tree():
		_update_power_up_icons()

func _on_turn_started() -> void:
	# Move the completed turn's locks into the round-end payout bucket.
	if locks_this_turn > 0:
		var money_to_grant = locks_this_turn * MONEY_PER_LOCK
		pending_round_end_bonus += money_to_grant
		print("[LockAndLoadPowerUp] Turn ended - queued $%d for round-end payout (%d locks, $%d pending)" % [money_to_grant, locks_this_turn, pending_round_end_bonus])
	
	# Reset tracking for the new turn
	locks_this_turn = 0
	
	# Update description
	emit_signal("description_updated", id, get_current_description())
	
	if is_inside_tree():
		_update_power_up_icons()

func get_current_description() -> String:
	var lines: Array[String] = ["+$%d for each die locked (added to round-end PowerUp bonus)" % MONEY_PER_LOCK]
	var current_turn_bonus = locks_this_turn * MONEY_PER_LOCK
	var total_pending = pending_round_end_bonus + current_turn_bonus

	if locks_this_turn > 0:
		lines.append("Locks this turn: %d ($%d queued)" % [locks_this_turn, current_turn_bonus])

	if total_pending > 0:
		lines.append("Pending this round: $%d" % total_pending)

	if total_money_granted > 0:
		lines.append("Total earned: $%d" % total_money_granted)

	return "\n".join(lines)


func get_pending_round_end_bonus() -> int:
	return pending_round_end_bonus + (locks_this_turn * MONEY_PER_LOCK)


func consume_pending_round_end_bonus() -> int:
	var granted_amount = get_pending_round_end_bonus()
	if granted_amount <= 0:
		return 0

	pending_round_end_bonus = 0
	locks_this_turn = 0
	total_money_granted += granted_amount
	print("[LockAndLoadPowerUp] Consumed pending round-end bonus: $%d (total earned: $%d)" % [granted_amount, total_money_granted])
	emit_signal("description_updated", id, get_current_description())
	if is_inside_tree():
		_update_power_up_icons()
	return granted_amount

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("lock_and_load")
		if icon:
			icon.update_hover_description()
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

func remove(target) -> void:
	print("=== Removing LockAndLoadPowerUp ===")
	
	var dice_hand: DiceHand = null
	if target is DiceHand:
		dice_hand = target
	elif target == self:
		dice_hand = dice_hand_ref
	
	if dice_hand:
		if dice_hand.is_connected("die_locked", _on_die_locked):
			dice_hand.die_locked.disconnect(_on_die_locked)
			print("[LockAndLoadPowerUp] Disconnected from die_locked signal")
	
	if turn_tracker_ref:
		if turn_tracker_ref.is_connected("turn_started", _on_turn_started):
			turn_tracker_ref.turn_started.disconnect(_on_turn_started)
			print("[LockAndLoadPowerUp] Disconnected from turn_started signal")
	
	dice_hand_ref = null
	turn_tracker_ref = null

func _on_tree_exiting() -> void:
	if dice_hand_ref:
		if dice_hand_ref.is_connected("die_locked", _on_die_locked):
			dice_hand_ref.die_locked.disconnect(_on_die_locked)
	
	if turn_tracker_ref:
		if turn_tracker_ref.is_connected("turn_started", _on_turn_started):
			turn_tracker_ref.turn_started.disconnect(_on_turn_started)
