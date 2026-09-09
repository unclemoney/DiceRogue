extends PowerUp
class_name MoneyWellSpentPowerUp

## MoneyWellSpentPowerUp
##
## Grants +1 additive to all scores for every $50 spent.
## Example: $350 spent = +7 to all scores.

# Reference to Statistics manager for tracking money spent
var statistics_ref = null
var tracked_money_spent: int = 0
var MONEY_SPENT_THRESHOLD: int = 50

## Enable verbose debug logging only in debug builds
var _debug_enabled: bool = OS.is_debug_build()

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")
	if _debug_enabled:
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
		if _debug_enabled:
			print("[MoneyWellSpentPowerUp] Connected to ScoreModifierManager signals")

func _is_score_modifier_manager_available() -> bool:
	# ScoreModifierManager is a registered autoload — always accessible
	return ScoreModifierManager != null

func _get_score_modifier_manager():
	# ScoreModifierManager is a registered autoload — use direct reference
	return ScoreModifierManager


func _get_additive_source_name() -> String:
	return get_runtime_modifier_source_name("money_well_spent")

func apply(_target) -> void:
	if _debug_enabled:
		print("=== Applying MoneyWellSpentPowerUp ===")

	# Get reference to Statistics manager
	statistics_ref = Statistics
	if not statistics_ref:
		push_error("[MoneyWellSpentPowerUp] Statistics manager not found")
		return

	# Initialize with current money spent value
	tracked_money_spent = statistics_ref.total_money_spent
	if _debug_enabled:
		print("[MoneyWellSpentPowerUp] Initial money spent:", tracked_money_spent)

	# Connect to cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

	# Register initial additive with ScoreModifierManager
	_update_additive_manager()
	if _debug_enabled:
		print("[MoneyWellSpentPowerUp] Initial additive registered:", get_current_additive())

	# Start tracking money spent via the PlayerEconomy signal
	_start_money_tracking()

func _start_money_tracking() -> void:
	# Connect to PlayerEconomy's money_changed signal; spending shows up as a negative change
	if not PlayerEconomy.money_changed.is_connected(_on_money_changed):
		PlayerEconomy.money_changed.connect(_on_money_changed)
		if _debug_enabled:
			print("[MoneyWellSpentPowerUp] Connected to PlayerEconomy money_changed signal")

func _stop_money_tracking() -> void:
	if PlayerEconomy.money_changed.is_connected(_on_money_changed):
		PlayerEconomy.money_changed.disconnect(_on_money_changed)
		if _debug_enabled:
			print("[MoneyWellSpentPowerUp] Disconnected from PlayerEconomy money_changed signal")

func _on_money_changed(_new_amount: int, change: int) -> void:
	# Only spending (negative change) counts toward the threshold
	if change >= 0:
		return

	tracked_money_spent += -change
	if _debug_enabled:
		print("[MoneyWellSpentPowerUp] Money spent changed, total spent now:", tracked_money_spent)

	# Update additive (grants +1 per MONEY_SPENT_THRESHOLD crossed)
	_update_additive_manager()

	# Update UI
	emit_signal("description_updated", id, get_current_description())

	# Only update icons if we're still in the tree
	if is_inside_tree():
		_update_power_up_icons()

func get_current_additive() -> int:
	return tracked_money_spent / MONEY_SPENT_THRESHOLD

func _update_additive_manager() -> void:
	if not _is_score_modifier_manager_available():
		if _debug_enabled:
			print("[MoneyWellSpentPowerUp] ScoreModifierManager not available, skipping update")
		return

	var additive = get_current_additive()
	var manager = _get_score_modifier_manager()

	if manager:
		manager.register_additive(_get_additive_source_name(), additive)
		if _debug_enabled:
			print("[MoneyWellSpentPowerUp] ScoreModifierManager updated with additive:", additive)
	else:
		push_error("[MoneyWellSpentPowerUp] Could not access ScoreModifierManager")

func _on_additive_manager_changed(total_additive: int) -> void:
	if _debug_enabled:
		print("[MoneyWellSpentPowerUp] ScoreModifierManager total additive changed to:", total_additive)
	emit_signal("description_updated", id, get_current_description())

	# Only update icons if we're still in the tree
	if is_inside_tree():
		_update_power_up_icons()

func _on_tree_exiting() -> void:
	if _debug_enabled:
		print("[MoneyWellSpentPowerUp] Node is being destroyed, cleaning up")

	_stop_money_tracking()

	# Unregister from ScoreModifierManager
	if _is_score_modifier_manager_available():
		var manager = _get_score_modifier_manager()
		if manager:
			manager.unregister_additive(_get_additive_source_name())
			if _debug_enabled:
				print("[MoneyWellSpentPowerUp] Additive unregistered from ScoreModifierManager")

func remove(_target) -> void:
	if _debug_enabled:
		print("=== Removing MoneyWellSpentPowerUp ===")

	_stop_money_tracking()

	# Unregister from ScoreModifierManager
	if _is_score_modifier_manager_available():
		var manager = _get_score_modifier_manager()
		if manager:
			manager.unregister_additive(_get_additive_source_name())
			if _debug_enabled:
				print("[MoneyWellSpentPowerUp] Additive unregistered from ScoreModifierManager")

	statistics_ref = null

func get_current_description() -> String:
	var base_desc = "+1 to all scores per $50 spent"

	if not statistics_ref:
		return base_desc

	var current_add = get_current_additive()

	var desc = "\nSpent: $%d | Bonus: +%d" % [tracked_money_spent, current_add]

	return base_desc + desc

func _update_power_up_icons() -> void:
	# Guard against calling when not in tree or tree is null
	if not is_inside_tree() or not get_tree():
		if _debug_enabled:
			print("[MoneyWellSpentPowerUp] Node not in tree or tree is null, skipping icon update")
		return

	# Find the PowerUpUI in the scene
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		# Get the icon for this power-up
		var icon = power_up_ui.get_power_up_icon(get_runtime_power_up_id("money_well_spent"))
		if icon:
			# Update its description
			icon.update_hover_description()

			# If it's currently being hovered, make the label visible
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

			if _debug_enabled:
				print("[MoneyWellSpentPowerUp] Updated icon description")
	else:
		if _debug_enabled:
			print("[MoneyWellSpentPowerUp] PowerUpUI not found in scene")
