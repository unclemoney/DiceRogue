extends PowerUp
class_name Chance520PowerUp

# Reference to the scorecard to listen for score assignments
var scorecard_ref: Scorecard = null
var bonus_count: int = 0

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")
	print("[Chance520PowerUp] Added to 'power_ups' group")
	
	# Guard against missing ScoreModifierManager
	if not _is_score_modifier_manager_available():
		push_error("[Chance520PowerUp] ScoreModifierManager not available")
		return
	
	# Get the correct ScoreModifierManager reference
	var manager = _get_score_modifier_manager()
	
	# Connect to ScoreModifierManager signals to update UI when total additive changes
	if manager and not manager.is_connected("additive_changed", _on_additive_manager_changed):
		manager.additive_changed.connect(_on_additive_manager_changed)
		print("[Chance520PowerUp] Connected to ScoreModifierManager signals")

func _is_score_modifier_manager_available() -> bool:
	# Check if ScoreModifierManager exists as an autoload singleton
	if Engine.has_singleton("ScoreModifierManager"):
		return true
	
	# Fallback: check if it exists in the scene tree as a group member
	if get_tree():
		var group_node = get_tree().get_first_node_in_group("score_modifier_manager")
		if group_node:
			return true
		# Also check old group name for backward compatibility
		var old_group_node = get_tree().get_first_node_in_group("multiplier_manager")
		if old_group_node:
			return true
	
	return false

func _get_score_modifier_manager():
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

func apply(target) -> void:
	print("=== Applying Chance520PowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[Chance520PowerUp] Target is not a Scorecard")
		return
	
	# Store a reference to the scorecard
	scorecard_ref = scorecard
	print("[Chance520PowerUp] Target scorecard:", scorecard)
	
	# Connect to score assignment signals
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
		print("[Chance520PowerUp] Connected to score_assigned signal")
	
	if not scorecard.is_connected("score_auto_assigned", _on_score_assigned):
		scorecard.score_auto_assigned.connect(_on_score_assigned)
		print("[Chance520PowerUp] Connected to score_auto_assigned signal")
	
	# Also connect to a more general score_changed signal if available
	# We need to manually track when chance scores are set
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	
	# Register initial additive with ScoreModifierManager (starts at 0)
	_update_additive_manager()
	print("[Chance520PowerUp] Initial additive registered:", get_current_additive())

func _on_score_assigned(section: Scorecard.Section, category: String, score: int, _breakdown_info: Dictionary = {}) -> void:
	print("\n=== Score Assigned ===")
	print("[Chance520PowerUp] Section:", section, " Category:", category, " Score:", score)
	
	# Check if this is a Chance category score of 20 or above
	if category == "chance" and score >= 20:
		print("[Chance520PowerUp] Chance scored with 20+! Increasing bonus.")
		bonus_count += 1
		print("[Chance520PowerUp] Bonus count increased to:", bonus_count)
		print("[Chance520PowerUp] New additive bonus:", get_current_additive())
		emit_signal("description_updated", id, get_current_description())
		
		# Update the ScoreModifierManager with new additive
		_update_additive_manager()
		
		# Only update icons if we're still in the tree
		if is_inside_tree():
			_update_power_up_icons()
		
		print("[Chance520PowerUp] All scores now have +", get_current_additive(), " added before multipliers")

func get_current_additive() -> int:
	return bonus_count * 5

func _update_additive_manager() -> void:
	if not _is_score_modifier_manager_available():
		print("[Chance520PowerUp] ScoreModifierManager not available, skipping update")
		return
	
	var additive = get_current_additive()
	var manager = _get_score_modifier_manager()
	
	if manager:
		manager.register_additive("chance520", additive)
		print("[Chance520PowerUp] ScoreModifierManager updated with additive:", additive)
	else:
		push_error("[Chance520PowerUp] Could not access ScoreModifierManager")

func _on_additive_manager_changed(total_additive: int) -> void:
	print("[Chance520PowerUp] ScoreModifierManager total additive changed to:", total_additive)
	emit_signal("description_updated", id, get_current_description())
	
	# Only update icons if we're still in the tree
	if is_inside_tree():
		_update_power_up_icons()

func _on_tree_exiting() -> void:
	print("[Chance520PowerUp] Node is being destroyed, cleaning up")
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
		if scorecard_ref.is_connected("score_auto_assigned", _on_score_assigned):
			scorecard_ref.score_auto_assigned.disconnect(_on_score_assigned)
	
	# Unregister from ScoreModifierManager
	if _is_score_modifier_manager_available():
		var manager = _get_score_modifier_manager()
		if manager:
			manager.unregister_additive("chance520")
			print("[Chance520PowerUp] Additive unregistered from ScoreModifierManager")

func remove(target) -> void:
	print("=== Removing Chance520PowerUp ===")
	
	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		scorecard = scorecard_ref
		print("[Chance520PowerUp] Using stored scorecard reference")
	
	if scorecard:
		if scorecard.is_connected("score_assigned", _on_score_assigned):
			scorecard.score_assigned.disconnect(_on_score_assigned)
		if scorecard.is_connected("score_auto_assigned", _on_score_assigned):
			scorecard.score_auto_assigned.disconnect(_on_score_assigned)
	
	# Unregister from ScoreModifierManager
	if _is_score_modifier_manager_available():
		var manager = _get_score_modifier_manager()
		if manager:
			manager.unregister_additive("chance520")
			print("[Chance520PowerUp] Additive unregistered from ScoreModifierManager")
	
	scorecard_ref = null

func get_current_description() -> String:
	var base_desc = "+5 to all scores for each Chance ≥20"
	
	if not scorecard_ref:
		return base_desc
	
	if not _is_score_modifier_manager_available():
		return base_desc
	
	var current_add = get_current_additive()
	var manager = _get_score_modifier_manager()
	var total_add = 0
	if manager:
		total_add = manager.get_total_additive()
	
	var desc = "\nCurrent: +%d" % [current_add]
	
	return base_desc + desc

func _update_power_up_icons() -> void:
	# Guard against calling when not in tree or tree is null
	if not is_inside_tree() or not get_tree():
		print("[Chance520PowerUp] Node not in tree or tree is null, skipping icon update")
		return
	
	# Find the PowerUpUI in the scene
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		# Get the icon for this power-up
		var icon = power_up_ui.get_power_up_icon("chance520")
		if icon:
			# Update its description
			icon.update_hover_description()
			
			# If it's currently being hovered, make the label visible
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true
				
			print("[Chance520PowerUp] Updated icon description")
	else:
		print("[Chance520PowerUp] PowerUpUI not found in scene")