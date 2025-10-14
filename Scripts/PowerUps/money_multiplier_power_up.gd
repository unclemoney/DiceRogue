extends PowerUp
class_name MoneyMultiplierPowerUp

## MoneyMultiplierPowerUp
##
## Increases a money multiplier by 0.1 for each yahtzee rolled, then multiplies
## the player's current money by that multiplier.
## Example: Starting at $500 with 1.0 multiplier, after 1 yahtzee:
## - Multiplier becomes 1.1
## - Money becomes $500 * 1.1 = $550

# PowerUp-specific variables
var money_multiplier: float = 1.0
var yahtzees_tracked: int = 0
var multiplier_increment: float = 0.1

# Reference to scorecard for yahtzee tracking
var scorecard_ref: Scorecard = null

# Signal for dynamic description updates
signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")
	print("[MoneyMultiplierPowerUp] Added to 'power_ups' group")

func apply(target) -> void:
	print("=== Applying MoneyMultiplierPowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[MoneyMultiplierPowerUp] Target is not a Scorecard")
		return
	
	# Store reference
	scorecard_ref = scorecard
	
	# Connect to yahtzee-related signals
	if not scorecard.is_connected("yahtzee_bonus_achieved", _on_yahtzee_bonus_achieved):
		scorecard.yahtzee_bonus_achieved.connect(_on_yahtzee_bonus_achieved)
		print("[MoneyMultiplierPowerUp] Connected to yahtzee_bonus_achieved signal")
	
	# Connect to RollStats for tracking all yahtzees (including first one)
	if not RollStats.is_connected("yahtzee_rolled", _on_yahtzee_rolled):
		RollStats.yahtzee_rolled.connect(_on_yahtzee_rolled)
		print("[MoneyMultiplierPowerUp] Connected to RollStats yahtzee_rolled signal")
	
	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func remove(target) -> void:
	print("=== Removing MoneyMultiplierPowerUp ===")
	
	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		scorecard = scorecard_ref
	
	if scorecard:
		# Disconnect signals
		if scorecard.is_connected("yahtzee_bonus_achieved", _on_yahtzee_bonus_achieved):
			scorecard.yahtzee_bonus_achieved.disconnect(_on_yahtzee_bonus_achieved)
	
	# Disconnect RollStats signals
	if RollStats.is_connected("yahtzee_rolled", _on_yahtzee_rolled):
		RollStats.yahtzee_rolled.disconnect(_on_yahtzee_rolled)
	
	scorecard_ref = null

func _on_yahtzee_rolled() -> void:
	print("[MoneyMultiplierPowerUp] Yahtzee rolled detected!")
	_process_yahtzee_multiplier()

func _on_yahtzee_bonus_achieved(_bonus_points: int) -> void:
	print("[MoneyMultiplierPowerUp] Yahtzee bonus achieved!")
	_process_yahtzee_multiplier()

func _process_yahtzee_multiplier() -> void:
	yahtzees_tracked += 1
	
	# Calculate new multiplier
	var old_multiplier = money_multiplier
	money_multiplier += multiplier_increment
	
	# Get current money
	var current_money = PlayerEconomy.get_money()
	
	# Calculate the additional money from the multiplier increase
	var multiplier_increase = money_multiplier - old_multiplier
	var additional_money = int(current_money * multiplier_increase)
	
	print("[MoneyMultiplierPowerUp] Yahtzee #%d detected!" % yahtzees_tracked)
	print("[MoneyMultiplierPowerUp] Multiplier: %.1f -> %.1f" % [old_multiplier, money_multiplier])
	print("[MoneyMultiplierPowerUp] Current money: $%d" % current_money)
	print("[MoneyMultiplierPowerUp] Additional money from multiplier: $%d" % additional_money)
	
	# Add the additional money
	if additional_money > 0:
		PlayerEconomy.add_money(additional_money)
		print("[MoneyMultiplierPowerUp] Added $%d to player economy" % additional_money)
	
	# Update the description to show current progress
	emit_signal("description_updated", id, get_current_description())
	
	# Update any power-up icons if we're still in the tree
	if is_inside_tree():
		_update_power_up_icons()

func get_current_description() -> String:
	var base_desc = "+0.1x money multiplier per Yahtzee"
	
	if yahtzees_tracked > 0:
		var progress_desc = "\nYahtzees: %d (%.1fx multiplier)" % [yahtzees_tracked, money_multiplier]
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
		var icon = power_up_ui.get_power_up_icon("money_multiplier")
		if icon:
			# Update its description
			icon.update_hover_description()
			
			# If it's currently being hovered, make the label visible
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

func _on_tree_exiting() -> void:
	# Cleanup when PowerUp is destroyed
	if scorecard_ref:
		if scorecard_ref.is_connected("yahtzee_bonus_achieved", _on_yahtzee_bonus_achieved):
			scorecard_ref.yahtzee_bonus_achieved.disconnect(_on_yahtzee_bonus_achieved)
	
	if RollStats.is_connected("yahtzee_rolled", _on_yahtzee_rolled):
		RollStats.yahtzee_rolled.disconnect(_on_yahtzee_rolled)