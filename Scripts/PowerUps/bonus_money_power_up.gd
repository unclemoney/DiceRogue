extends PowerUp
class_name BonusMoneyPowerUp

## BonusMoneyPowerUp
##
## Grants $50 for every bonus achieved in the game:
## - Upper Section Bonus (when upper section total >= 63)
## - Yahtzee Bonus (50-point Yahtzee + 100-point bonus Yahtzees)
##
## This PowerUp connects to scorecard signals to detect when bonuses are achieved
## and automatically adds money to the player's economy.

# Reference to the scorecard to listen for bonus achievements
var scorecard_ref: Scorecard = null
var total_bonuses_earned: int = 0
var money_per_bonus: int = 50

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[BonusMoneyPowerUp] Target is not a Scorecard")
		return
	
	# Store a reference to the scorecard
	scorecard_ref = scorecard
	
	# Connect to bonus achievement signals
	if not scorecard.is_connected("upper_bonus_achieved", _on_upper_bonus_achieved):
		scorecard.upper_bonus_achieved.connect(_on_upper_bonus_achieved)
	
	if not scorecard.is_connected("yahtzee_bonus_achieved", _on_yahtzee_bonus_achieved):
		scorecard.yahtzee_bonus_achieved.connect(_on_yahtzee_bonus_achieved)
	
	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func _on_upper_bonus_achieved(_bonus_points: int) -> void:
	_grant_bonus_money()

func _on_yahtzee_bonus_achieved(_bonus_points: int) -> void:
	_grant_bonus_money()

func _grant_bonus_money() -> void:
	total_bonuses_earned += 1
	
	# Add money to player's economy
	PlayerEconomy.add_money(money_per_bonus)
	
	# Update the description to show current progress
	emit_signal("description_updated", id, get_current_description())
	
	# Update any power-up icons if we're still in the tree
	if is_inside_tree():
		_update_power_up_icons()

func get_current_description() -> String:
	var base_desc = "+$50 for each bonus achieved"
	
	if total_bonuses_earned > 0:
		var total_money = total_bonuses_earned * money_per_bonus
		var progress_desc = "\nBonuses earned: %d ($%d total)" % [total_bonuses_earned, total_money]
		return base_desc + progress_desc
	
	return base_desc

func _update_power_up_icons() -> void:
	# Guard against calling when not in tree or tree is null
	if not is_inside_tree() or not get_tree():
		return
	
	# Find the PowerUpUI in the scene
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		# Get the icon for this power-up
		var icon = power_up_ui.get_power_up_icon("bonus_money")
		if icon:
			# Update its description
			icon.update_hover_description()
			
			# If it's currently being hovered, make the label visible
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

func _on_tree_exiting() -> void:
	if scorecard_ref:
		if scorecard_ref.is_connected("upper_bonus_achieved", _on_upper_bonus_achieved):
			scorecard_ref.upper_bonus_achieved.disconnect(_on_upper_bonus_achieved)
		if scorecard_ref.is_connected("yahtzee_bonus_achieved", _on_yahtzee_bonus_achieved):
			scorecard_ref.yahtzee_bonus_achieved.disconnect(_on_yahtzee_bonus_achieved)

func remove(target) -> void:
	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		scorecard = scorecard_ref
	
	if scorecard:
		if scorecard.is_connected("upper_bonus_achieved", _on_upper_bonus_achieved):
			scorecard.upper_bonus_achieved.disconnect(_on_upper_bonus_achieved)
		if scorecard.is_connected("yahtzee_bonus_achieved", _on_yahtzee_bonus_achieved):
			scorecard.yahtzee_bonus_achieved.disconnect(_on_yahtzee_bonus_achieved)
	
	scorecard_ref = null