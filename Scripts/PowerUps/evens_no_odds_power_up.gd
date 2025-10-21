extends PowerUp
class_name EvensNoOddsPowerUp

# Reference to the scorecard to listen for score assignments
var scorecard_ref: Scorecard = null
var additive_total: int = 0

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")
	print("[EvensNoOddsPowerUp] Added to 'power_ups' group")
	
	# Guard against missing ScoreModifierManager
	if not _is_score_modifier_manager_available():
		push_error("[EvensNoOddsPowerUp] ScoreModifierManager not available")
		return
	
	# Get the correct ScoreModifierManager reference
	var manager = _get_score_modifier_manager()
	
	# Connect to ScoreModifierManager signals to update UI when total additive changes
	if manager and not manager.is_connected("additive_changed", _on_additive_manager_changed):
		manager.additive_changed.connect(_on_additive_manager_changed)
		print("[EvensNoOddsPowerUp] Connected to ScoreModifierManager signals")

func _is_score_modifier_manager_available() -> bool:
	# Try both group search methods for compatibility
	var manager = get_tree().get_first_node_in_group("score_modifier_manager")
	if manager:
		return true
	
	# Try old group name for backward compatibility
	var old_group_node = get_tree().get_first_node_in_group("multiplier_manager")
	if old_group_node:
		return true
	
	return false

func _get_score_modifier_manager():
	# First try the current group name
	var manager = get_tree().get_first_node_in_group("score_modifier_manager")
	if manager:
		return manager
	
	# Fallback to old group name
	var old_group_node = get_tree().get_first_node_in_group("multiplier_manager")
	if old_group_node:
		return old_group_node
	
	return null

func apply(target) -> void:
	print("=== Applying EvensNoOddsPowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[EvensNoOddsPowerUp] Target is not a Scorecard")
		return
	
	# Store a reference to the scorecard
	scorecard_ref = scorecard
	print("[EvensNoOddsPowerUp] Target scorecard:", scorecard)
	
	# Connect to score assignment signals
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
		print("[EvensNoOddsPowerUp] Connected to score_assigned signal")
	
	if not scorecard.is_connected("score_auto_assigned", _on_score_assigned):
		scorecard.score_auto_assigned.connect(_on_score_assigned)
		print("[EvensNoOddsPowerUp] Connected to score_auto_assigned signal")
	
	# Connect to tree_exiting to clean up when removed
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	
	# Register initial additive with ScoreModifierManager (starts at 0)
	_update_additive_manager()
	print("[EvensNoOddsPowerUp] Initial additive registered:", additive_total)

func _on_score_assigned(section: Scorecard.Section, category: String, score: int, _breakdown_info: Dictionary = {}) -> void:
	print("\n=== Score Assigned ===")
	print("[EvensNoOddsPowerUp] Section:", section, " Category:", category, " Score:", score)
	
	var dice_values = DiceResults.values
	if dice_values.is_empty():
		print("[EvensNoOddsPowerUp] No dice values available")
		return
	
	print("[EvensNoOddsPowerUp] All dice values:", dice_values)
	
	# Get only the dice values that actually contribute to this category's score
	var contributing_dice = _get_contributing_dice_values(section, category, dice_values)
	print("[EvensNoOddsPowerUp] Contributing dice for", category, ":", contributing_dice)
	
	if contributing_dice.is_empty():
		print("[EvensNoOddsPowerUp] No contributing dice for this category")
		return
	
	# Count even and odd dice only among those that contributed to the score
	var even_count = 0
	var odd_count = 0
	
	for value in contributing_dice:
		if value % 2 == 0:
			even_count += 1
		else:
			odd_count += 1
	
	print("[EvensNoOddsPowerUp] Contributing even dice:", even_count, " odd dice:", odd_count)
	
	# Calculate the modifier (+1 for each contributing even, -1 for each contributing odd)
	var modifier = even_count - odd_count
	additive_total += modifier
	
	print("[EvensNoOddsPowerUp] Modifier for this score:", modifier)
	print("[EvensNoOddsPowerUp] New running additive total:", additive_total)
	
	# Update the description and UI
	emit_signal("description_updated", id, get_current_description())
	
	# Update the ScoreModifierManager with new additive
	_update_additive_manager()
	
	# Only update icons if we're still in the tree
	if is_inside_tree():
		_update_power_up_icons()
	
	print("[EvensNoOddsPowerUp] All scores now have", additive_total, "added before multipliers")

# Add this new helper function to determine which dice contribute to each category
func _get_contributing_dice_values(section: Scorecard.Section, category: String, dice_values: Array[int]) -> Array[int]:
	var contributing: Array[int] = []
	
	match section:
		Scorecard.Section.UPPER:
			# For upper section, only dice matching the category number contribute
			var target_number = _get_upper_section_number(category)
			if target_number > 0:
				for value in dice_values:
					if value == target_number:
						contributing.append(value)
		
		Scorecard.Section.LOWER:
			# For lower section, different categories have different contributing dice
			match category:
				"three_of_a_kind", "four_of_a_kind":
					# Only the dice that form the "of a kind" contribute
					var required_count = 3 if category == "three_of_a_kind" else 4
					var matching_value = _get_n_of_a_kind_value(dice_values, required_count)
					if matching_value > 0:
						# All dice contribute to of-a-kind scoring (sum of all dice)
						contributing.assign(dice_values)
				
				"full_house", "small_straight", "large_straight", "yahtzee":
					# All dice contribute to pattern-based categories
					if _category_matches_pattern(category, dice_values):
						contributing.assign(dice_values)
				
				"chance":
					# All dice always contribute to chance
					contributing.assign(dice_values)
	
	return contributing

# Helper function to get the target number for upper section categories
func _get_upper_section_number(category: String) -> int:
	match category:
		"ones": return 1
		"twos": return 2
		"threes": return 3
		"fours": return 4
		"fives": return 5
		"sixes": return 6
		_: return 0

# Helper function to find the value that appears n or more times
func _get_n_of_a_kind_value(values: Array[int], n: int) -> int:
	var counts = {}
	for v in values:
		counts[v] = counts.get(v, 0) + 1
	
	for value in counts:
		if counts[value] >= n:
			return value
	return 0

# Helper function to check if dice match the pattern for the category
func _category_matches_pattern(category: String, dice_values: Array[int]) -> bool:
	match category:
		"full_house":
			return ScoreEvaluatorSingleton.is_full_house(dice_values)
		"small_straight":
			return ScoreEvaluatorSingleton.is_small_straight(dice_values)
		"large_straight":
			return ScoreEvaluatorSingleton.is_straight(dice_values)
		"yahtzee":
			return ScoreEvaluatorSingleton.is_yahtzee(dice_values)
		_:
			return false

func get_current_additive() -> int:
	return additive_total

func _update_additive_manager() -> void:
	if not _is_score_modifier_manager_available():
		print("[EvensNoOddsPowerUp] ScoreModifierManager not available, skipping update")
		return
	
	var additive = get_current_additive()
	var manager = _get_score_modifier_manager()
	
	if manager:
		manager.register_additive("evens_no_odds", additive)
		print("[EvensNoOddsPowerUp] ScoreModifierManager updated with additive:", additive)
	else:
		push_error("[EvensNoOddsPowerUp] Could not access ScoreModifierManager")

func _on_additive_manager_changed(total_additive: int) -> void:
	print("[EvensNoOddsPowerUp] ScoreModifierManager total additive changed to:", total_additive)

func _update_power_up_icons() -> void:
	# Update PowerUp icon descriptions to show current additive
	emit_signal("description_updated", id, get_current_description())

func _on_tree_exiting() -> void:
	print("[EvensNoOddsPowerUp] Node is being destroyed, cleaning up")
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
		if scorecard_ref.is_connected("score_auto_assigned", _on_score_assigned):
			scorecard_ref.score_auto_assigned.disconnect(_on_score_assigned)
	
	# Unregister from ScoreModifierManager
	if _is_score_modifier_manager_available():
		var manager = _get_score_modifier_manager()
		if manager:
			manager.unregister_additive("evens_no_odds")
			print("[EvensNoOddsPowerUp] Additive unregistered from ScoreModifierManager")

func remove(target) -> void:
	print("=== Removing EvensNoOddsPowerUp ===")
	
	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		scorecard = scorecard_ref
		print("[EvensNoOddsPowerUp] Using stored scorecard reference")
	
	if scorecard:
		if scorecard.is_connected("score_assigned", _on_score_assigned):
			scorecard.score_assigned.disconnect(_on_score_assigned)
		if scorecard.is_connected("score_auto_assigned", _on_score_assigned):
			scorecard.score_auto_assigned.disconnect(_on_score_assigned)
	
	# Unregister from ScoreModifierManager
	if _is_score_modifier_manager_available():
		var manager = _get_score_modifier_manager()
		if manager:
			manager.unregister_additive("evens_no_odds")
			print("[EvensNoOddsPowerUp] Additive unregistered from ScoreModifierManager")
	
	scorecard_ref = null

func get_current_description() -> String:
	var base_desc = "Even dice add +1, odd dice add -1 to all scores"
	
	if not scorecard_ref:
		return base_desc
	
	if not _is_score_modifier_manager_available():
		return base_desc
	
	var current_add = get_current_additive()
	var manager = _get_score_modifier_manager()
	var total_add = 0
	if manager:
		total_add = manager.get_total_additive()
	
	var modifier_text = ""
	if current_add > 0:
		modifier_text = " (+%d total)" % current_add
	elif current_add < 0:
		modifier_text = " (%d total)" % current_add
	else:
		modifier_text = " (0 total)"
	
	return base_desc + modifier_text
