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
	var scorecard = target as Scorecard
	if scorecard:
		# Store a reference to the scorecard
		scorecard_ref = scorecard
		print("[FoursomePowerUp] Target scorecard:", scorecard)
		
		# Make sure the scorecard and this object stay connected
		if not is_connected("tree_exiting", _on_tree_exiting):
			connect("tree_exiting", _on_tree_exiting)
		
		# Create a multiplier function that checks for Fours
		var multiplier_func = Callable(self, "_foursome_multiplier_func")
		print("[FoursomePowerUp] Created multiplier function. Valid:", multiplier_func.is_valid())
		print("[FoursomePowerUp] Function target:", multiplier_func.get_object())
		
		# Set the multiplier function on the scorecard
		scorecard.set_score_multiplier(multiplier_func)
		print("[FoursomePowerUp] Score multiplier function set")
		
		# Verify the scorecard has the function
		scorecard.debug_multiplier_function()
	else:
		push_error("[FoursomePowerUp] Target is not a Scorecard")

# This function will be called by the scorecard when calculating scores
func _foursome_multiplier_func(category: String, base_score: int, dice_values: Array) -> int:
	# Safety check for empty arrays
	if dice_values.size() == 0:
		print("[FoursomePowerUp] Empty dice values array, returning base score:", base_score)
		return base_score
	
	# Check if any of the dice show a 4
	var has_four = false
	for value in dice_values:
		if value == 4:
			has_four = true
			break

	var final_score: int
	match category:
		"fours":
			final_score = base_score * 4
			print("[FoursomePowerUp] Fours category - multiplying by 4:", final_score)
		"three_of_a_kind", "four_of_a_kind", "full_house", "small_straight", "large_straight", "chance":
			final_score = base_score * 4
			print("[FoursomePowerUp] Lower section category - multiplying by 4:", final_score)
		"yahtzee":
			if dice_values.count(4) >= 5:
				final_score = base_score * 4
				print("[FoursomePowerUp] Yahtzee of fours - multiplying by 4:", final_score)
			else:
				final_score = base_score
				print("[FoursomePowerUp] Non-four yahtzee - keeping base score")
		_:
			final_score = base_score
			print("[FoursomePowerUp] Unhandled category - keeping base score")

	# Apply 4x multiplier only if a Four is present
	if has_four:
		var multiplied_score = base_score * 4
		print("[FoursomePowerUp] Four found! Applying 4x multiplier to", base_score, "=", multiplied_score)
		#return multiplied_score
		return final_score
	else:
		print("[FoursomePowerUp] No Four found, keeping original score:", base_score)
		return base_score
	return base_score  # Fallback, should not reach here

# This function will be called when the node is about to be destroyed
func _on_tree_exiting() -> void:
	print("[FoursomePowerUp] Node is being destroyed, cleaning up")
	if scorecard_ref:
		# Make sure we reset the multiplier
		scorecard_ref.set_score_multiplier(1.0)

func remove(target) -> void:
	print("=== Removing FoursomePowerUp ===")
	print("[FoursomePowerUp] DEBUG - Remove called from:", get_stack())
	
	# Handle both direct target and stored reference
	var scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		# If GameController is calling remove(self), use our stored reference
		scorecard = scorecard_ref
		print("[FoursomePowerUp] Using stored scorecard reference")
	
	if scorecard:
		# Reset multiplier when removed (1.0 means no multiplier)
		scorecard.set_score_multiplier(1.0)
		print("[FoursomePowerUp] Score multiplier reset")
	else:
		push_error("[FoursomePowerUp] Target is not a Scorecard and no scorecard reference stored")
	
	# Clear our reference
	scorecard_ref = null

# Add this function to periodically check and fix the connection
func _process(_delta) -> void:
	# Only run this check occasionally to avoid performance impact
	if Engine.get_process_frames() % 60 == 0 and scorecard_ref:
		# Check if our multiplier function is still valid
		if not scorecard_ref._score_multiplier_func.is_valid() or \
		   scorecard_ref._score_multiplier_func.get_object() != self:
			print("[FoursomePowerUp] Detected lost multiplier function, reconnecting...")
			# Reconnect the multiplier function
			var multiplier_func = Callable(self, "_foursome_multiplier_func")
			scorecard_ref.set_score_multiplier(multiplier_func)
			print("[FoursomePowerUp] Reconnected multiplier function")
