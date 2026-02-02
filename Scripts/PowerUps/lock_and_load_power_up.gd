extends PowerUp
class_name LockAndLoadPowerUp

## LockAndLoadPowerUp
##
## Grants $3 for each die locked during a turn.
## Money is awarded at the end of each turn based on locks performed.
## Encourages strategic locking behavior.
## Common rarity, $75 price.

# Reference to dice hand and turn tracker
var dice_hand_ref: DiceHand = null
var turn_tracker_ref: TurnTracker = null

# Track locks this turn
var locks_this_turn: int = 0
var total_money_granted: int = 0

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
	
	# Connect to turn_started to pay out and reset tracking
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
	# Pay out for previous turn's locks before resetting
	if locks_this_turn > 0:
		var money_to_grant = locks_this_turn * MONEY_PER_LOCK
		PlayerEconomy.add_money(money_to_grant)
		total_money_granted += money_to_grant
		print("[LockAndLoadPowerUp] Turn ended - granted $%d for %d locks" % [money_to_grant, locks_this_turn])
	
	# Reset tracking for the new turn
	locks_this_turn = 0
	
	# Update description
	emit_signal("description_updated", id, get_current_description())
	
	if is_inside_tree():
		_update_power_up_icons()

func get_current_description() -> String:
	var base_desc = "+$%d for each die locked" % MONEY_PER_LOCK
	
	if locks_this_turn > 0:
		var pending = locks_this_turn * MONEY_PER_LOCK
		base_desc += "\nLocks this turn: %d ($%d pending)" % [locks_this_turn, pending]
	
	if total_money_granted > 0:
		base_desc += "\nTotal earned: $%d" % total_money_granted
	
	return base_desc

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
