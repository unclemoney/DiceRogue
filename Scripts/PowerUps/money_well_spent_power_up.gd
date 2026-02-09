extends PowerUp
class_name MoneyWellSpentPowerUp

## MoneyWellSpentPowerUp
##
## Grants +1 additive to all scores for every $25 spent.
## Example: $175 spent = +7 to all scores.

# Reference to Statistics manager for tracking money spent
var statistics_ref = null
var last_money_spent: int = 0

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")
	print("[MoneyWellSpentPowerUp] Added to 'power_ups' group")
	
	# Guard against missing ScoreModifierManager
	if not _is_score_modifier_manager_available():
		push_error("[MoneyWellSpentPowerUp] ScoreModifierManager not available")
		return
	
	# Get the correct ScoreModifierManager reference
	var manager = _get_score_modifier_manager()
	
	# Connect to ScoreModifierManager signals to update UI when total additive changes
	if manager and not manager.is_connected("additive_changed", _on_additive_manager_changed):
		manager.additive_changed.connect(_on_additive_manager_changed)
		print("[MoneyWellSpentPowerUp] Connected to ScoreModifierManager signals")

func _is_score_modifier_manager_available() -> bool:
	# ScoreModifierManager is a registered autoload — always accessible
	return ScoreModifierManager != null

func _get_score_modifier_manager():
	# ScoreModifierManager is a registered autoload — use direct reference
	return ScoreModifierManager

func apply(_target) -> void:
	print("=== Applying MoneyWellSpentPowerUp ===")
	
	# Get reference to Statistics manager
	statistics_ref = Statistics
	if not statistics_ref:
		push_error("[MoneyWellSpentPowerUp] Statistics manager not found")
		return
	
	print("[MoneyWellSpentPowerUp] Statistics manager found:", statistics_ref)
	
	# Initialize with current money spent value
	last_money_spent = statistics_ref.total_money_spent
	print("[MoneyWellSpentPowerUp] Initial money spent:", last_money_spent)
	
	# Connect to cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	
	# Register initial additive with ScoreModifierManager
	_update_additive_manager()
	print("[MoneyWellSpentPowerUp] Initial additive registered:", get_current_additive())
	
	# Start checking for money spent updates
	_start_money_tracking()

func _start_money_tracking() -> void:
	# We'll use a timer to periodically check if total_money_spent has changed
	# This is more reliable than trying to connect to individual purchase events
	var timer = Timer.new()
	timer.wait_time = 0.5  # Check every 500ms
	timer.timeout.connect(_check_money_spent)
	timer.autostart = true
	add_child(timer)
	print("[MoneyWellSpentPowerUp] Started money tracking timer")

func _check_money_spent() -> void:
	if not statistics_ref:
		return
	
	var current_money_spent = statistics_ref.total_money_spent
	if current_money_spent != last_money_spent:
		print("[MoneyWellSpentPowerUp] Money spent changed from %d to %d" % [last_money_spent, current_money_spent])
		last_money_spent = current_money_spent
		
		# Update additive
		_update_additive_manager()
		
		# Update UI
		emit_signal("description_updated", id, get_current_description())
		
		# Only update icons if we're still in the tree
		if is_inside_tree():
			_update_power_up_icons()

func get_current_additive() -> int:
	if not statistics_ref:
		return 0
	
	return statistics_ref.total_money_spent / 50

func _update_additive_manager() -> void:
	if not _is_score_modifier_manager_available():
		print("[MoneyWellSpentPowerUp] ScoreModifierManager not available, skipping update")
		return
	
	var additive = get_current_additive()
	var manager = _get_score_modifier_manager()
	
	if manager:
		manager.register_additive("money_well_spent", additive)
		print("[MoneyWellSpentPowerUp] ScoreModifierManager updated with additive:", additive)
	else:
		push_error("[MoneyWellSpentPowerUp] Could not access ScoreModifierManager")

func _on_additive_manager_changed(total_additive: int) -> void:
	print("[MoneyWellSpentPowerUp] ScoreModifierManager total additive changed to:", total_additive)
	emit_signal("description_updated", id, get_current_description())
	
	# Only update icons if we're still in the tree
	if is_inside_tree():
		_update_power_up_icons()

func _on_tree_exiting() -> void:
	print("[MoneyWellSpentPowerUp] Node is being destroyed, cleaning up")
	
	# Unregister from ScoreModifierManager
	if _is_score_modifier_manager_available():
		var manager = _get_score_modifier_manager()
		if manager:
			manager.unregister_additive("money_well_spent")
			print("[MoneyWellSpentPowerUp] Additive unregistered from ScoreModifierManager")

func remove(_target) -> void:
	print("=== Removing MoneyWellSpentPowerUp ===")
	
	# Unregister from ScoreModifierManager
	if _is_score_modifier_manager_available():
		var manager = _get_score_modifier_manager()
		if manager:
			manager.unregister_additive("money_well_spent")
			print("[MoneyWellSpentPowerUp] Additive unregistered from ScoreModifierManager")
	
	statistics_ref = null

func get_current_description() -> String:
	var base_desc = "+1 to all scores per $50 spent"
	
	if not statistics_ref:
		return base_desc
	
	var current_money_spent = statistics_ref.total_money_spent
	var current_add = get_current_additive()
	
	var desc = "\nSpent: $%d | Bonus: +%d" % [current_money_spent, current_add]
	
	return base_desc + desc

func _update_power_up_icons() -> void:
	# Guard against calling when not in tree or tree is null
	if not is_inside_tree() or not get_tree():
		print("[MoneyWellSpentPowerUp] Node not in tree or tree is null, skipping icon update")
		return
	
	# Find the PowerUpUI in the scene
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		# Get the icon for this power-up
		var icon = power_up_ui.get_power_up_icon("money_well_spent")
		if icon:
			# Update its description
			icon.update_hover_description()
			
			# If it's currently being hovered, make the label visible
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true
				
			print("[MoneyWellSpentPowerUp] Updated icon description")
	else:
		print("[MoneyWellSpentPowerUp] PowerUpUI not found in scene")