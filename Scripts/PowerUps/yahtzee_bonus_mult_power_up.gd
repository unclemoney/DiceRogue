extends PowerUp
class_name YahtzeeBonusMultPowerUp

# Reference to the scorecard to maintain state and listen for signals
var scorecard_ref: Scorecard = null
var bonus_count: int = 0
var base_multiplier: float = 1.0

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")
	print("[YahtzeeBonusMultPowerUp] Added to 'power_ups' group")
	
	# Guard against missing ScoreModifierManager
	if not _is_score_modifier_manager_available():
		push_error("[YahtzeeBonusMultPowerUp] ScoreModifierManager not available")
		return
	
	# Get the correct ScoreModifierManager reference
	var manager = _get_score_modifier_manager()
	
	# Connect to ScoreModifierManager signals to update UI when total multiplier changes
	if manager and not manager.is_connected("multiplier_changed", _on_multiplier_manager_changed):
		manager.multiplier_changed.connect(_on_multiplier_manager_changed)
		print("[YahtzeeBonusMultPowerUp] Connected to ScoreModifierManager signals")

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
	print("=== Applying YahtzeeBonusMultPowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[YahtzeeBonusMultPowerUp] Target is not a Scorecard")
		return
	
	# Store a reference to the scorecard
	scorecard_ref = scorecard
	print("[YahtzeeBonusMultPowerUp] Target scorecard:", scorecard)
	
	# Check if we already have yahtzee bonuses
	if scorecard.yahtzee_bonuses > 0:
		bonus_count = scorecard.yahtzee_bonuses
		print("[YahtzeeBonusMultPowerUp] Found existing yahtzee bonuses:", bonus_count, ", setting multiplier to:", get_current_multiplier())
	
	# Connect to the yahtzee_bonus_achieved signal
	if not scorecard.is_connected("yahtzee_bonus_achieved", _on_yahtzee_bonus_achieved):
		scorecard.yahtzee_bonus_achieved.connect(_on_yahtzee_bonus_achieved)
		print("[YahtzeeBonusMultPowerUp] Connected to yahtzee_bonus_achieved signal")
	
	# Make sure we clean up when the node is destroyed
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	
	# Register with ScoreModifierManager instead of setting scorecard directly
	_update_multiplier_manager()
	print("[YahtzeeBonusMultPowerUp] Initial multiplier registered:", get_current_multiplier())

func _on_yahtzee_bonus_achieved(_bonus_points: int) -> void:
	print("\n=== Yahtzee Bonus Achieved! ===")
	bonus_count += 1
	print("[YahtzeeBonusMultPowerUp] Bonus count increased to:", bonus_count)
	print("[YahtzeeBonusMultPowerUp] New multiplier:", get_current_multiplier())
	emit_signal("description_updated", id, get_current_description())
	
	# Update the ScoreModifierManager with new multiplier
	_update_multiplier_manager()
	
	# Only update icons if we're still in the tree
	if is_inside_tree():
		_update_power_up_icons()
	
	print("[YahtzeeBonusMultPowerUp] ALL SCORES NOW MULTIPLIED BY:", get_current_multiplier())

func get_current_multiplier() -> float:
	return base_multiplier + bonus_count

func _update_multiplier_manager() -> void:
	if not _is_score_modifier_manager_available():
		print("[YahtzeeBonusMultPowerUp] ScoreModifierManager not available, skipping update")
		return
	
	var multiplier = get_current_multiplier()
	var manager = _get_score_modifier_manager()
	
	if manager:
		manager.register_multiplier("yahtzee_bonus_mult", multiplier)
		print("[YahtzeeBonusMultPowerUp] ScoreModifierManager updated with multiplier:", multiplier)
	else:
		push_error("[YahtzeeBonusMultPowerUp] Could not access ScoreModifierManager")

func _on_multiplier_manager_changed(total_multiplier: float) -> void:
	print("[YahtzeeBonusMultPowerUp] ScoreModifierManager total changed to:", total_multiplier)
	emit_signal("description_updated", id, get_current_description())
	
	# Only update icons if we're still in the tree
	if is_inside_tree():
		_update_power_up_icons()

func _on_tree_exiting() -> void:
	print("[YahtzeeBonusMultPowerUp] Node is being destroyed, cleaning up")
	if scorecard_ref:
		if scorecard_ref.is_connected("yahtzee_bonus_achieved", _on_yahtzee_bonus_achieved):
			scorecard_ref.yahtzee_bonus_achieved.disconnect(_on_yahtzee_bonus_achieved)
	
	# Unregister from ScoreModifierManager
	if _is_score_modifier_manager_available():
		var manager = _get_score_modifier_manager()
		if manager:
			manager.unregister_multiplier("yahtzee_bonus_mult")
			print("[YahtzeeBonusMultPowerUp] Multiplier unregistered from ScoreModifierManager")

func remove(target) -> void:
	print("=== Removing YahtzeeBonusMultPowerUp ===")
	
	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		scorecard = scorecard_ref
		print("[YahtzeeBonusMultPowerUp] Using stored scorecard reference")
	
	if scorecard:
		if scorecard.is_connected("yahtzee_bonus_achieved", _on_yahtzee_bonus_achieved):
			scorecard.yahtzee_bonus_achieved.disconnect(_on_yahtzee_bonus_achieved)
	
	# Unregister from ScoreModifierManager
	if _is_score_modifier_manager_available():
		var manager = _get_score_modifier_manager()
		if manager:
			manager.unregister_multiplier("yahtzee_bonus_mult")
			print("[YahtzeeBonusMultPowerUp] Multiplier unregistered from ScoreModifierManager")
	
	scorecard_ref = null

func get_current_description() -> String:
	var base_desc = "🎲 mult by 1x for each Yahtzee Bonus"
	
	if not scorecard_ref:
		return base_desc
	
	if not _is_score_modifier_manager_available():
		return base_desc
	
	var current_mult = get_current_multiplier()
	var manager = _get_score_modifier_manager()
	var total_mult = 1.0
	if manager:
		total_mult = manager.get_total_multiplier()
	
	var desc = "\nCurrent : %dx" % [current_mult]
	
	return base_desc + desc

func _update_power_up_icons() -> void:
	# Guard against calling when not in tree or tree is null
	if not is_inside_tree() or not get_tree():
		print("[YahtzeeBonusMultPowerUp] Node not in tree or tree is null, skipping icon update")
		return
	
	# Find the PowerUpUI in the scene
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		# Get the icon for this power-up
		var icon = power_up_ui.get_power_up_icon("yahtzee_bonus_mult")
		if icon:
			# Update its description
			icon.update_hover_description()
			
			print("[YahtzeeBonusMultPowerUp] Updated icon description")
	else:
		print("[YahtzeeBonusMultPowerUp] PowerUpUI not found in scene")