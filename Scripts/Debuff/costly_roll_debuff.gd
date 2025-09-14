extends Debuff
class_name CostlyRollDebuff

@export var roll_cost: int = 10

var game_controller: GameController

func apply(target) -> void:
	print("[CostlyRollDebuff] Applied - Roll cost:", roll_cost)
	
	# Store the target
	self.target = target
	_find_game_controller()
	
	# If we found the controller, connect to the signal
	if game_controller:
		if not game_controller.is_connected("dice_rolled", _on_dice_rolled):
			game_controller.connect("dice_rolled", _on_dice_rolled)
		print("[CostlyRollDebuff] Connected to dice_rolled signal")
	else:
		push_error("[CostlyRollDebuff] Failed to find GameController")

func remove() -> void:
	print("[CostlyRollDebuff] Removed")
	
	# Disconnect from signals when removed
	if game_controller and game_controller.is_connected("dice_rolled", _on_dice_rolled):
		game_controller.disconnect("dice_rolled", _on_dice_rolled)
		print("[CostlyRollDebuff] Disconnected from dice_rolled signal")

func _find_game_controller() -> void:
	# Try to find GameController in various ways
	if target and target is GameController:
		game_controller = target
	else:
		game_controller = get_tree().get_first_node_in_group("game_controller")
		if not game_controller:
			game_controller = get_tree().get_root().find_child("GameController", true, false)
	
	if game_controller:
		print("[CostlyRollDebuff] Found GameController:", game_controller)
	else:
		push_error("[CostlyRollDebuff] Could not find GameController")

func _on_dice_rolled(_dice_values: Array) -> void:
	print("[CostlyRollDebuff] Dice rolled, charging", roll_cost, "money")
	
	# Display a notification about the cost
	var notification = get_tree().get_first_node_in_group("notification_system")
	if notification:
		notification.show_notification("-$%d Roll Fee" % roll_cost)
	
	# Apply the cost
	PlayerEconomy.remove_money(roll_cost)