extends PowerUp
class_name WildDotsPowerUp

## WildDotsPowerUp
##
## Each locked die showing a 6 increases the chance of rolling a 6 on remaining dice for the rest of the turn.
## As dice are locked, the odds of rolling a 6 on the remaining dice are increased by +1/6 per locked six (max 100%).
##
## This PowerUp connects to the dice_hand's signals to monitor locked dice and alters the roll odds dynamically.

var dice_hand_ref: DiceHand = null
var sixes_locked: int = 0

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	var dice_hand = target as DiceHand
	if not dice_hand:
		push_error("[WildDotsPowerUp] Target is not a DiceHand")
		return
	
	dice_hand_ref = dice_hand
	
	# Connect to dice_locked and roll_started signals
	if not dice_hand.is_connected("die_locked", _on_die_locked):
		dice_hand.die_locked.connect(_on_die_locked)
	if not dice_hand.is_connected("roll_started", _on_roll_started):
		dice_hand.roll_started.connect(_on_roll_started)
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

	# Patch dice roll odds
	# Initialize current count
	_update_locked_sixes()

func remove(target) -> void:
	var dice_hand: DiceHand = null
	if target is DiceHand:
		dice_hand = target
	elif target == self:
		dice_hand = dice_hand_ref
	if dice_hand:
		if dice_hand.is_connected("die_locked", _on_die_locked):
			dice_hand.die_locked.disconnect(_on_die_locked)
		if dice_hand.is_connected("roll_started", _on_roll_started):
			dice_hand.roll_started.disconnect(_on_roll_started)
		dice_hand_ref = null

func _on_die_locked(_die) -> void:
	# Update count of locked sixes
	_update_locked_sixes()
	emit_signal("description_updated", id, get_current_description())
	_update_power_up_icons()

func _on_roll_started() -> void:
	# Reset count at start of each roll
	sixes_locked = 0
	_update_locked_sixes()
	emit_signal("description_updated", id, get_current_description())
	_update_power_up_icons()

	# Before the dice are rolled, set per-die bias meta on unlocked dice
	if dice_hand_ref:
		# Calculate bias per unlocked die: increase by +1/6 per locked six, capped at 1.0
		var bias = min(1.0, float(sixes_locked) / 6.0)
		var unlocked = dice_hand_ref.get_unlocked_dice()
		for die in unlocked:
			die.set_meta("wild_dots_bias", bias)

func _update_locked_sixes() -> void:
	if not dice_hand_ref:
		return
	sixes_locked = 0
	for die in dice_hand_ref.dice_list:
		if die.is_locked and die.value == 6:
			sixes_locked += 1

# No monkey-patching required; Dice.roll() reads per-die meta 'wild_dots_bias'

func get_current_description() -> String:
	return "Each locked die showing a 6 increases the chance of rolling a 6 on remaining dice for the rest of the turn. Locked sixes: %d" % sixes_locked

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("wild_dots")
		if icon:
			icon.update_hover_description()

func _on_tree_exiting() -> void:
	dice_hand_ref = null
