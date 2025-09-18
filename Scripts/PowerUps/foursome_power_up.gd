extends PowerUp
class_name FoursomePowerUp

# Add a reference to the scorecard to maintain state
var scorecard_ref = null

func _ready() -> void:
	# Make sure this is in a group so we can find it later if needed
	add_to_group("power_ups")
	print("[FoursomePowerUp] Added to 'power_ups' group")

func apply(target) -> void:
	print("=== Applying FoursomePowerUp ===")
	print("[FoursomePowerUp] DEBUG: Need to connect to dice roll events")
	print("[FoursomePowerUp] DEBUG: update_multiplier_for_dice method exists but not called")
	var scorecard = target as Scorecard
	if scorecard:
		# Store a reference to the scorecard
		scorecard_ref = scorecard
		print("[FoursomePowerUp] Target scorecard:", scorecard)
		
		# Make sure the scorecard and this object stay connected
		if not is_connected("tree_exiting", _on_tree_exiting):
			connect("tree_exiting", _on_tree_exiting)
		
		# Register with ScoreModifierManager - we'll conditionally apply the multiplier based on dice
		# For now, register with 1.0 as default, we'll update it when dice contain a 4
		ScoreModifierManager.register_multiplier("foursome", 1.0)
		print("[FoursomePowerUp] Registered with ScoreModifierManager")
	else:
		push_error("[FoursomePowerUp] Target is not a Scorecard")

# This function evaluates if the current dice warrant a 4x multiplier
func should_apply_multiplier(dice_values: Array) -> bool:
	# Check if any of the dice show a 4
	for value in dice_values:
		if value == 4:
			return true
	return false

# Update the multiplier based on current dice state
func update_multiplier_for_dice(dice_values: Array) -> void:
	var multiplier = 4.0 if should_apply_multiplier(dice_values) else 1.0
	ScoreModifierManager.register_multiplier("foursome", multiplier)
	print("[FoursomePowerUp] Updated multiplier to:", multiplier, "based on dice:", dice_values)

# This function will be called when the node is about to be destroyed
func _on_tree_exiting() -> void:
	print("[FoursomePowerUp] Node is being destroyed, cleaning up")
	# Unregister from ScoreModifierManager
	ScoreModifierManager.unregister_multiplier("foursome")

func remove(target) -> void:
	print("=== Removing FoursomePowerUp ===")
	print("[FoursomePowerUp] DEBUG - Remove called from:", get_stack())
	
	# Unregister from ScoreModifierManager regardless of target type
	ScoreModifierManager.unregister_multiplier("foursome")
	print("[FoursomePowerUp] Multiplier unregistered from ScoreModifierManager")
	
	# Clear our reference
	scorecard_ref = null
