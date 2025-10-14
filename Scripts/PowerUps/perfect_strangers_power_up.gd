extends PowerUp
class_name PerfectStrangersPowerUp

# Reference to the scorecard to listen for score assignments
var scorecard_ref: Scorecard = null
var multiplier_activated: bool = false
var current_multiplier: float = 0.0

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")
	print("[PerfectStrangersPowerUp] Added to 'power_ups' group")

func apply(target) -> void:
	print("=== Applying PerfectStrangersPowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[PerfectStrangersPowerUp] Target is not a Scorecard")
		return
	
	# Store a reference to the scorecard
	scorecard_ref = scorecard
	print("[PerfectStrangersPowerUp] Target scorecard:", scorecard)
	
	# Connect to score assignment signals
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
		print("[PerfectStrangersPowerUp] Connected to score_assigned signal")
	
	if not scorecard.is_connected("score_auto_assigned", _on_score_assigned):
		scorecard.score_auto_assigned.connect(_on_score_assigned)
		print("[PerfectStrangersPowerUp] Connected to score_auto_assigned signal")
	
	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func remove(target) -> void:
	print("=== Removing PerfectStrangersPowerUp ===")
	
	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		scorecard = scorecard_ref
	
	if scorecard:
		# Disconnect signals
		if scorecard.is_connected("score_assigned", _on_score_assigned):
			scorecard.score_assigned.disconnect(_on_score_assigned)
		if scorecard.is_connected("score_auto_assigned", _on_score_assigned):
			scorecard.score_auto_assigned.disconnect(_on_score_assigned)
		print("[PerfectStrangersPowerUp] Disconnected from scorecard signals")
	
	# Remove multiplier if it was activated
	if multiplier_activated:
		_remove_multiplier()
	
	scorecard_ref = null

func _on_score_assigned(section: Scorecard.Section, category: String, score: int) -> void:
	print("\n=== PERFECT STRANGERS DEBUG ===")
	print("[PerfectStrangersPowerUp] Section:", section, " Category:", category, " Score:", score)
	
	# If multiplier is already activated, just log the current state
	if multiplier_activated:
		var manager = _get_score_modifier_manager()
		if manager:
			print("[PerfectStrangersPowerUp] ✓ MULTIPLIER ALREADY ACTIVE! Current total multiplier:", manager.get_total_multiplier())
		else:
			print("[PerfectStrangersPowerUp] ✗ MULTIPLIER ACTIVE BUT NO MANAGER FOUND!")
		return
	
	# Check if dice show 1,2,3,4,5 (Perfect Strangers condition)
	print("[PerfectStrangersPowerUp] Checking for Perfect Strangers condition...")
	
	# Get current dice values from the game controller
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if not game_controller:
		print("[PerfectStrangersPowerUp] ✗ CANNOT FIND GAMECONTROLLER")
		return
	
	var dice_hand = game_controller.dice_hand
	if not dice_hand:
		print("[PerfectStrangersPowerUp] ✗ CANNOT FIND DICEHAND")
		return
	
	var dice_values = dice_hand.get_current_dice_values()
	print("[PerfectStrangersPowerUp] Current dice values:", dice_values)
	
	# Check if all dice values are different and we have 5+ dice
	if dice_values.size() >= 5 and _are_all_dice_different(dice_values):
		print("[PerfectStrangersPowerUp] ✓ PERFECT STRANGERS CONDITION MET!")
		print("[PerfectStrangersPowerUp] ✓ All dice are different - activating 1.5x multiplier!")
		_activate_multiplier()
		emit_signal("description_updated", id, get_current_description())
	else:
		print("[PerfectStrangersPowerUp] ✗ Perfect Strangers condition NOT met")
		print("[PerfectStrangersPowerUp]   - Dice count:", dice_values.size(), " (need 5+)")
		print("[PerfectStrangersPowerUp]   - All different:", _are_all_dice_different(dice_values))
		
		# Debug individual dice values
		var unique_values = {}
		var duplicates = []
		for value in dice_values:
			if value in unique_values:
				duplicates.append(value)
			unique_values[value] = true
		
		if duplicates.size() > 0:
			print("[PerfectStrangersPowerUp]   - Duplicate values found:", duplicates)
		else:
			print("[PerfectStrangersPowerUp]   - No duplicates found - this should have worked!")

func _are_all_dice_different(dice_values: Array) -> bool:
	## _are_all_dice_different(dice_values)
	##
	## Checks if all dice in the array have different values (no duplicates).
	## Returns true if all values are unique, false otherwise.
	var unique_values = {}
	for value in dice_values:
		if value in unique_values:
			return false
		unique_values[value] = true
	return true

func _activate_multiplier() -> void:
	## _activate_multiplier()
	##
	## Activates a 1.5x multiplier by registering it with the ScoreModifierManager.
	print("\n=== ACTIVATING PERFECT STRANGERS MULTIPLIER ===")
	var manager = _get_score_modifier_manager()
	if manager:
		current_multiplier = 1.5
		print("[PerfectStrangersPowerUp] ✓ Found ScoreModifierManager")
		print("[PerfectStrangersPowerUp] BEFORE REGISTRATION - Current total multiplier:", manager.get_total_multiplier())
		print("[PerfectStrangersPowerUp] BEFORE REGISTRATION - Active multipliers:", manager._active_multipliers)
		
		manager.register_multiplier("perfect_strangers", current_multiplier)
		multiplier_activated = true
		
		print("[PerfectStrangersPowerUp] ✓ REGISTERED 1.5x MULTIPLIER")
		print("[PerfectStrangersPowerUp] AFTER REGISTRATION - Current total multiplier:", manager.get_total_multiplier())
		print("[PerfectStrangersPowerUp] AFTER REGISTRATION - Active multipliers:", manager._active_multipliers)
		print("[PerfectStrangersPowerUp] ✓ ALL FUTURE SCORES SHOULD NOW BE MULTIPLIED BY:", manager.get_total_multiplier())
	else:
		print("[PerfectStrangersPowerUp] ✗ CANNOT FIND ScoreModifierManager - MULTIPLIER NOT ACTIVATED!")
		push_error("[PerfectStrangersPowerUp] Cannot find ScoreModifierManager")

func _remove_multiplier() -> void:
	## _remove_multiplier()
	##
	## Removes the multiplier from the ScoreModifierManager when PowerUp is removed.
	var manager = _get_score_modifier_manager()
	if manager:
		manager.unregister_multiplier("perfect_strangers")
		multiplier_activated = false
		current_multiplier = 0.0
		print("[PerfectStrangersPowerUp] Unregistered multiplier from ScoreModifierManager")

func _get_score_modifier_manager():
	## _get_score_modifier_manager()
	##
	## Gets a reference to the ScoreModifierManager singleton or group node.
	## Returns null if not found.
	# Check if ScoreModifierManager exists as an autoload singleton
	if Engine.has_singleton("ScoreModifierManager"):
		return ScoreModifierManager
	
	# Fallback: check new group name first
	if get_tree():
		var group_node = get_tree().get_first_node_in_group("score_modifier_manager")
		if group_node:
			return group_node
		# Then check old group name for backward compatibility
		var old_group_node = get_tree().get_first_node_in_group("multiplier_manager")
		if old_group_node:
			return old_group_node
	
	return null

func get_current_description() -> String:
	## get_current_description()
	##
	## Returns the current description of the PowerUp, updating based on activation state.
	if multiplier_activated:
		return "Perfect Strangers ACTIVE! All future scores are multiplied by 1.5x"
	else:
		return "When all 5+ dice show different values, gain 1.5x score multiplier for all future scores"

func _on_tree_exiting() -> void:
	## _on_tree_exiting()
	##
	## Cleanup when PowerUp is destroyed - removes multiplier and disconnects signals.
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
		if scorecard_ref.is_connected("score_auto_assigned", _on_score_assigned):
			scorecard_ref.score_auto_assigned.disconnect(_on_score_assigned)
	
	if multiplier_activated:
		_remove_multiplier()