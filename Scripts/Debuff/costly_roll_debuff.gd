extends Debuff
class_name CostlyRollDebuff

## CostlyRollDebuff
##
## Charges the player money each time they roll the dice.
## Intensity scaling: roll_cost is multiplied by intensity.
## At intensity 1.0: $10 per roll. At intensity 2.0: $20 per roll.

@export var base_roll_cost: int = 10  ## Base cost before intensity scaling

var dice_hand: DiceHand
var _effective_roll_cost: int = 10  ## Actual cost after intensity scaling


func apply(target) -> void:
	# Calculate effective cost based on intensity
	_effective_roll_cost = int(round(base_roll_cost * intensity))
	print("[CostlyRollDebuff] Applied - Base cost:", base_roll_cost, "Intensity:", intensity, "Effective cost:", _effective_roll_cost)
	
	# Store the target
	self.target = target
	_find_dice_hand()
	
	# If we found the dice_hand, connect to roll_complete signal
	if dice_hand:
		if not dice_hand.is_connected("roll_complete", _on_roll_complete):
			dice_hand.connect("roll_complete", _on_roll_complete)
		print("[CostlyRollDebuff] Connected to dice_hand.roll_complete signal")
	else:
		push_error("[CostlyRollDebuff] Failed to find DiceHand")

func remove() -> void:
	print("[CostlyRollDebuff] Removed")
	
	# Disconnect from signals when removed
	if dice_hand and dice_hand.is_connected("roll_complete", _on_roll_complete):
		dice_hand.disconnect("roll_complete", _on_roll_complete)
		print("[CostlyRollDebuff] Disconnected from roll_complete signal")

func _find_dice_hand() -> void:
	# Try to find DiceHand in various ways
	dice_hand = get_tree().get_first_node_in_group("dice_hand")
	if not dice_hand:
		var game_controller = get_tree().get_first_node_in_group("game_controller")
		if game_controller and game_controller.has_node("DiceHand"):
			dice_hand = game_controller.get_node("DiceHand")
	if not dice_hand:
		dice_hand = get_tree().get_root().find_child("DiceHand", true, false)
	
	if dice_hand:
		print("[CostlyRollDebuff] Found DiceHand:", dice_hand)
	else:
		push_error("[CostlyRollDebuff] Could not find DiceHand")

func _on_roll_complete() -> void:
	print("[CostlyRollDebuff] Roll complete, charging", _effective_roll_cost, "money")
	
	# Display a notification about the cost
	var notification = get_tree().get_first_node_in_group("notification_system")
	if notification:
		notification.show_notification("-$%d Roll Fee" % _effective_roll_cost)
	
	# Apply the cost
	PlayerEconomy.remove_money(_effective_roll_cost, "debuff")