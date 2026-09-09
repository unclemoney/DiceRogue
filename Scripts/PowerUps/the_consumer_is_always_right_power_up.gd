extends PowerUp
class_name TheConsumerIsAlwaysRightPowerUp

# This PowerUp provides a 0.25 multiplier for each consumable used in the game session
# It queries the Statistics singleton for consumables_used and maintains the multiplier
# The multiplier is unregistered when the PowerUp is removed or exits the tree

var base_multiplier: float = 1.0
var multiplier_per_consumable: float = 0.25
var statistics_ref = null

## Enable verbose debug logging only in debug builds
var _debug_enabled: bool = OS.is_debug_build()

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")
	if _debug_enabled:
		print("[TheConsumerIsAlwaysRightPowerUp] Added to 'power_ups' group")

	# Get reference to Statistics manager
	statistics_ref = Statistics
	if not statistics_ref:
		push_error("[TheConsumerIsAlwaysRightPowerUp] Statistics manager not found")
		return

	# Guard against missing ScoreModifierManager
	if not _is_score_modifier_manager_available():
		push_error("[TheConsumerIsAlwaysRightPowerUp] ScoreModifierManager not available")
		return

	# Get the correct ScoreModifierManager reference
	var manager = _get_score_modifier_manager()

	# Connect to ScoreModifierManager signals to update UI when total multiplier changes
	if manager and not manager.is_connected("multiplier_changed", _on_multiplier_manager_changed):
		manager.multiplier_changed.connect(_on_multiplier_manager_changed)
		if _debug_enabled:
			print("[TheConsumerIsAlwaysRightPowerUp] Connected to ScoreModifierManager signals")

func _is_score_modifier_manager_available() -> bool:
	# ScoreModifierManager is a registered autoload — always accessible
	return ScoreModifierManager != null

func _get_score_modifier_manager():
	# ScoreModifierManager is a registered autoload — use direct reference
	return ScoreModifierManager

func apply(_target) -> void:
	if _debug_enabled:
		print("=== Applying TheConsumerIsAlwaysRightPowerUp ===")

	# This PowerUp doesn't need a specific target - it modifies all scores based on statistics
	# But we still validate that we have access to the Statistics manager
	if not statistics_ref:
		push_error("[TheConsumerIsAlwaysRightPowerUp] Statistics manager not available")
		return

	if _debug_enabled:
		print("[TheConsumerIsAlwaysRightPowerUp] Current consumables used:", statistics_ref.consumables_used)
		print("[TheConsumerIsAlwaysRightPowerUp] Current multiplier:", get_current_multiplier())

	# Connect to GameController's consumable_used signal to track when consumables are used
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if _debug_enabled:
		print("[TheConsumerIsAlwaysRightPowerUp] Found game_controller:", game_controller != null)
	if game_controller:
		var already_connected = game_controller.is_connected("consumable_used", _on_consumable_used)
		if _debug_enabled:
			print("[TheConsumerIsAlwaysRightPowerUp] GameController has consumable_used signal:", game_controller.has_signal("consumable_used"))
			print("[TheConsumerIsAlwaysRightPowerUp] Already connected:", already_connected)
		if not already_connected:
			var result = game_controller.consumable_used.connect(_on_consumable_used)
			if _debug_enabled:
				print("[TheConsumerIsAlwaysRightPowerUp] Connection result:", result)
				print("[TheConsumerIsAlwaysRightPowerUp] *** Connected to GameController consumable_used signal ***")
		else:
			if _debug_enabled:
				print("[TheConsumerIsAlwaysRightPowerUp] *** Already connected to consumable_used signal ***")

	# Make sure we clean up when the node is destroyed
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

	# Register with ScoreModifierManager
	_update_multiplier_manager()
	if _debug_enabled:
		print("[TheConsumerIsAlwaysRightPowerUp] Initial multiplier registered:", get_current_multiplier())

func remove(_target) -> void:
	if _debug_enabled:
		print("=== Removing TheConsumerIsAlwaysRightPowerUp ===")

	# Disconnect from GameController signals
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.is_connected("consumable_used", _on_consumable_used):
		game_controller.consumable_used.disconnect(_on_consumable_used)

	# Unregister our multiplier from ScoreModifierManager (idempotent)
	if _is_score_modifier_manager_available():
		var manager = _get_score_modifier_manager()
		if manager:
			manager.unregister_multiplier("the_consumer_is_always_right")
	if _debug_enabled:
		print("[TheConsumerIsAlwaysRightPowerUp] PowerUp removed and multiplier unregistered")

func get_current_multiplier() -> float:
	# Use statistics_ref if available (for testing), otherwise use singleton
	var stats = statistics_ref if statistics_ref else Statistics
	var consumables_used = stats.consumables_used
	var calculated_multiplier = base_multiplier + (consumables_used * multiplier_per_consumable)
	if _debug_enabled:
		print("[TheConsumerIsAlwaysRightPowerUp] DETAILED DEBUG:")
		print("  base_multiplier: %.2f" % base_multiplier)
		print("  consumables_used: %d" % consumables_used)
		print("  multiplier_per_consumable: %.2f" % multiplier_per_consumable)
		print("  calculated_multiplier: %.2f" % calculated_multiplier)
	return calculated_multiplier

func get_current_description() -> String:
	# Use statistics_ref if available (for testing), otherwise use singleton
	var stats = statistics_ref if statistics_ref else Statistics
	var consumables_used = stats.consumables_used
	var current_mult = get_current_multiplier()

	if consumables_used == 0:
		return "Score multiplier: x%.2f (+%.2f per consumable used)" % [current_mult, multiplier_per_consumable]
	else:
		return "Score multiplier: x%.2f (%d consumables used)" % [current_mult, consumables_used]

func _on_consumable_used(_consumable_id: String, _consumable) -> void:
	# Update the multiplier when a consumable is used
	if _debug_enabled:
		print("=== POWERUP SIGNAL RECEIVED ===")
		print("[TheConsumerIsAlwaysRightPowerUp] *** CONSUMABLE SIGNAL RECEIVED ***")
		print("[TheConsumerIsAlwaysRightPowerUp] Consumable ID:", _consumable_id)
		print("[TheConsumerIsAlwaysRightPowerUp] statistics_ref is null: ", statistics_ref == null)
		if statistics_ref:
			print("[TheConsumerIsAlwaysRightPowerUp] Current consumables_used: ", statistics_ref.consumables_used)
		# Also check the Statistics singleton directly
		print("[TheConsumerIsAlwaysRightPowerUp] Statistics singleton consumables_used: ", Statistics.consumables_used)
		print("=== POWERUP SIGNAL DEBUG END ===")

	# Wait a frame to ensure statistics are updated, then recalculate
	await get_tree().process_frame
	if _debug_enabled:
		if statistics_ref:
			print("[TheConsumerIsAlwaysRightPowerUp] After frame delay - consumables_used: ", statistics_ref.consumables_used)
		print("[TheConsumerIsAlwaysRightPowerUp] After frame delay - Statistics singleton: ", Statistics.consumables_used)

	# Update the ScoreModifierManager with the new multiplier
	_update_multiplier_manager()

	# Update the description
	emit_signal("description_updated", id, get_current_description())

	# Only update icons if we're still in the tree
	if is_inside_tree():
		_update_power_up_icons()

func _update_multiplier_manager() -> void:
	if not _is_score_modifier_manager_available():
		if _debug_enabled:
			print("[TheConsumerIsAlwaysRightPowerUp] ScoreModifierManager not available, skipping update")
		return

	var multiplier = get_current_multiplier()
	var manager = _get_score_modifier_manager()

	if _debug_enabled:
		print("[TheConsumerIsAlwaysRightPowerUp] _update_multiplier_manager called with multiplier:", multiplier)

	if manager:
		# Unregister old multiplier first, then register new one
		manager.unregister_multiplier("the_consumer_is_always_right")
		manager.register_multiplier("the_consumer_is_always_right", multiplier)
		if _debug_enabled:
			print("[TheConsumerIsAlwaysRightPowerUp] ScoreModifierManager updated with multiplier:", multiplier)

			# Verify the registration immediately
			var verified_total = manager.get_total_multiplier()
			print("[TheConsumerIsAlwaysRightPowerUp] Verified total multiplier after registration:", verified_total)

			if manager.has_method("get_active_sources"):
				var sources = manager.get_active_sources()
				print("[TheConsumerIsAlwaysRightPowerUp] Active sources after registration:", sources)
	else:
		push_error("[TheConsumerIsAlwaysRightPowerUp] Could not access ScoreModifierManager")

func _on_multiplier_manager_changed(total_multiplier: float) -> void:
	if _debug_enabled:
		print("[TheConsumerIsAlwaysRightPowerUp] ScoreModifierManager total changed to:", total_multiplier)
	emit_signal("description_updated", id, get_current_description())

	# Only update icons if we're still in the tree
	if is_inside_tree():
		_update_power_up_icons()

func _update_power_up_icons() -> void:
	# Update UI icons when description changes
	if not is_inside_tree() or not get_tree():
		return

	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("the_consumer_is_always_right")
		if icon:
			icon.update_hover_description()

func _on_tree_exiting() -> void:
	if _debug_enabled:
		print("[TheConsumerIsAlwaysRightPowerUp] Node is being destroyed, cleaning up")

	# Disconnect from GameController signals
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.is_connected("consumable_used", _on_consumable_used):
		game_controller.consumable_used.disconnect(_on_consumable_used)

	# Unregister our multiplier from ScoreModifierManager (idempotent)
	if _is_score_modifier_manager_available():
		var manager = _get_score_modifier_manager()
		if manager:
			manager.unregister_multiplier("the_consumer_is_always_right")
