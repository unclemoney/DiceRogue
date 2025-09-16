extends PowerUp
class_name UpperBonusMultPowerUp

# Reference to the scorecard to maintain state and listen for signals
var scorecard_ref = null
var bonus_count: int = 0
var base_multiplier: float = 1.0

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")
	print("[UpperBonusMultPowerUp] Added to 'power_ups' group")

func apply(target) -> void:
	print("=== Applying UpperBonusMultPowerUp ===")
	var scorecard = target as Scorecard
	if scorecard:
		# Store a reference to the scorecard
		scorecard_ref = scorecard
		print("[UpperBonusMultPowerUp] Target scorecard:", scorecard)
		
		# Check if we already have an upper bonus
		if scorecard.upper_bonus > 0:
			bonus_count += 1
			print("[UpperBonusMultPowerUp] Found existing upper bonus, setting multiplier to:", get_current_multiplier())
		
		# Connect to the upper_bonus_achieved signal
		if not scorecard.is_connected("upper_bonus_achieved", _on_upper_bonus_achieved):
			scorecard.upper_bonus_achieved.connect(_on_upper_bonus_achieved)
			print("[UpperBonusMultPowerUp] Connected to upper_bonus_achieved signal")
		
		# Make sure we clean up when the node is destroyed
		if not is_connected("tree_exiting", _on_tree_exiting):
			connect("tree_exiting", _on_tree_exiting)
		
		# Set the initial multiplier
		_update_scorecard_multiplier()
		print("[UpperBonusMultPowerUp] Initial multiplier set to:", get_current_multiplier())
	else:
		push_error("[UpperBonusMultPowerUp] Target is not a Scorecard")

# Signal handler for when upper bonus is achieved
func _on_upper_bonus_achieved(_bonus_amount: int) -> void:
	print("\n=== Upper Bonus Achieved! ===")
	bonus_count += 1
	print("[UpperBonusMultPowerUp] Bonus count increased to:", bonus_count)
	print("[UpperBonusMultPowerUp] New multiplier:", get_current_multiplier())
	emit_signal("description_updated", id, get_current_description())
	# Update the scorecard multiplier
	_update_scorecard_multiplier()
	
	# Update any power-up icons showing this power-up
	_update_power_up_icons()
	
	# Optional: Visual feedback
	print("[UpperBonusMultPowerUp] ALL SCORES NOW MULTIPLIED BY:", get_current_multiplier())

# Returns the current multiplier value based on bonus count
func get_current_multiplier() -> float:
	return base_multiplier + bonus_count

# Updates the scorecard's multiplier value
func _update_scorecard_multiplier() -> void:
	if scorecard_ref:
		var multiplier = get_current_multiplier()
		scorecard_ref.set_score_multiplier(multiplier)
		print("[UpperBonusMultPowerUp] Scorecard multiplier updated to:", multiplier)
	else:
		push_error("[UpperBonusMultPowerUp] Cannot update multiplier - no scorecard reference")

# Cleanup when node is about to be destroyed
func _on_tree_exiting() -> void:
	print("[UpperBonusMultPowerUp] Node is being destroyed, cleaning up")
	if scorecard_ref:
		# Disconnect from signals
		if scorecard_ref.is_connected("upper_bonus_achieved", _on_upper_bonus_achieved):
			scorecard_ref.upper_bonus_achieved.disconnect(_on_upper_bonus_achieved)
		
		# Reset the multiplier
		scorecard_ref.set_score_multiplier(1.0)
		print("[UpperBonusMultPowerUp] Score multiplier reset to default")

func remove(target) -> void:
	print("=== Removing UpperBonusMultPowerUp ===")
	
	# Handle both direct target and stored reference
	var scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		scorecard = scorecard_ref
		print("[UpperBonusMultPowerUp] Using stored scorecard reference")
	
	if scorecard:
		# Disconnect from signals
		if scorecard.is_connected("upper_bonus_achieved", _on_upper_bonus_achieved):
			scorecard.upper_bonus_achieved.disconnect(_on_upper_bonus_achieved)
		
		# Reset the multiplier
		scorecard.set_score_multiplier(1.0)
		print("[UpperBonusMultPowerUp] Score multiplier reset")
	else:
		push_error("[UpperBonusMultPowerUp] Target is not a Scorecard and no scorecard reference stored")
	
	# Clear our reference
	scorecard_ref = null

func get_current_description() -> String:
	var base_desc = "Increases score multiplier by 1x for each Upper Section Bonus achieved"
	
	# If not yet applied to a scorecard, just return the base description
	if not scorecard_ref:
		return base_desc
	
	# Otherwise, show the current multiplier
	var current_mult = get_current_multiplier()
	return "Current multiplier: %dx\n%s" % [current_mult, base_desc]
	
# New method to find and update icons
func _update_power_up_icons() -> void:
	# Find the PowerUpUI in the scene
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		# Get the icon for this power-up
		var icon = power_up_ui.get_power_up_icon("upper_bonus_mult")
		if icon:
			# Update its description
			icon.update_hover_description()
			
			# If it's currently being hovered, make the label visible
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true
				
			print("[UpperBonusMultPowerUp] Updated icon description")
