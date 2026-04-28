extends PowerUp
class_name PlusADollarPowerUp

## PlusADollarPowerUp
##
## A common PowerUp that grants $1 after each dice roll.
## Connects to the DiceHand's roll_complete signal.

var dice_hand_ref: Node = null
var total_earned: int = 0
const MONEY_PER_ROLL: int = 1

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")
	print("[PlusADollarPowerUp] Added to 'power_ups' group")

func apply(target) -> void:
	print("=== Applying PlusADollarPowerUp ===")
	if not target:
		push_error("[PlusADollarPowerUp] Target is null")
		return
	
	dice_hand_ref = target
	
	if dice_hand_ref.has_signal("roll_complete"):
		if not dice_hand_ref.is_connected("roll_complete", _on_roll_complete):
			dice_hand_ref.roll_complete.connect(_on_roll_complete)
			print("[PlusADollarPowerUp] Connected to roll_complete signal")
	
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	
	print("[PlusADollarPowerUp] Applied successfully - will grant $%d per roll" % MONEY_PER_ROLL)

func _on_roll_complete() -> void:
	PlayerEconomy.add_money(MONEY_PER_ROLL)
	total_earned += MONEY_PER_ROLL
	print("[PlusADollarPowerUp] Roll complete! Granted $%d (total earned: $%d)" % [MONEY_PER_ROLL, total_earned])
	
	emit_signal("description_updated", id, get_current_description())
	
	if is_inside_tree():
		_update_power_up_icons()

func remove(_target) -> void:
	print("=== Removing PlusADollarPowerUp ===")
	if dice_hand_ref:
		if dice_hand_ref.has_signal("roll_complete"):
			if dice_hand_ref.is_connected("roll_complete", _on_roll_complete):
				dice_hand_ref.roll_complete.disconnect(_on_roll_complete)
				print("[PlusADollarPowerUp] Disconnected from roll_complete signal")
	
	dice_hand_ref = null

func get_current_description() -> String:
	if total_earned > 0:
		return "Grants $%d per roll\nTotal earned: $%d" % [MONEY_PER_ROLL, total_earned]
	else:
		return "Grants $%d per roll" % MONEY_PER_ROLL

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("plus_a_dollar")
		if icon:
			icon.update_hover_description()
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

func _on_tree_exiting() -> void:
	if dice_hand_ref:
		if dice_hand_ref.has_signal("roll_complete"):
			if dice_hand_ref.is_connected("roll_complete", _on_roll_complete):
				dice_hand_ref.roll_complete.disconnect(_on_roll_complete)
		print("[PlusADollarPowerUp] Cleanup: Disconnected signals")
