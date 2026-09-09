extends PowerUp
class_name ExtremeCouponingPowerUp

## ExtremeCouponingPowerUp
## +5 additive score per consumable granted this run (any source:
## yellow dice, purchases, bonuses). Stacks for the whole run.
## WIRING: GameController.grant_consumable() must either emit a
## `consumable_granted(id)` signal or call `on_consumable_granted(id)`
## on this PowerUp for the bonus to grow. apply() auto-connects to the
## signal when it exists.

# Additive granted per consumable
var bonus_per_consumable: int = 5

# Consumables granted this run
var consumables_granted: int = 0

# ScoreModifierManager source name (replica-aware)
var modifier_source_name: String = "extreme_couponing"

# Reference to GameController for signal cleanup
var game_controller_ref: Node = null

## Enable verbose debug logging (auto-enabled in debug builds)
var _debug_enabled: bool = OS.is_debug_build()

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")
	modifier_source_name = get_runtime_modifier_source_name("extreme_couponing")
	if _debug_enabled:
		print("[ExtremeCouponingPowerUp] Added to 'power_ups' group")

func apply(_target) -> void:
	if _debug_enabled:
		print("=== Applying ExtremeCouponingPowerUp ===")

	# Find GameController to listen for consumable grants
	game_controller_ref = get_tree().get_first_node_in_group("game_controller")
	if not game_controller_ref:
		push_warning("[ExtremeCouponingPowerUp] No GameController found - grants must be reported via on_consumable_granted()")
	else:
		# Connect to consumable_granted signal if GameController provides it
		if game_controller_ref.has_signal("consumable_granted"):
			if not game_controller_ref.is_connected("consumable_granted", _on_consumable_granted_signal):
				game_controller_ref.consumable_granted.connect(_on_consumable_granted_signal)
				if _debug_enabled:
					print("[ExtremeCouponingPowerUp] Connected to consumable_granted signal")
		else:
			push_warning("[ExtremeCouponingPowerUp] GameController has no consumable_granted signal - grants must be reported via on_consumable_granted()")

	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

## on_consumable_granted(consumable_id)
##
## Public hook: call this (or emit GameController.consumable_granted)
## whenever a consumable is granted to the player this run.
func on_consumable_granted(consumable_id: String) -> void:
	consumables_granted += 1
	var total_bonus = consumables_granted * bonus_per_consumable
	ScoreModifierManager.register_additive(modifier_source_name, total_bonus)
	if _debug_enabled:
		print("[ExtremeCouponingPowerUp] Consumable '%s' granted - total: %d, additive: +%d" % [consumable_id, consumables_granted, total_bonus])

	emit_signal("description_updated", id, get_current_description())
	_update_power_up_icons()

func remove(_target) -> void:
	if _debug_enabled:
		print("=== Removing ExtremeCouponingPowerUp ===")

	# Unregister additive from ScoreModifierManager
	if ScoreModifierManager.has_additive(modifier_source_name):
		ScoreModifierManager.unregister_additive(modifier_source_name)
		if _debug_enabled:
			print("[ExtremeCouponingPowerUp] Unregistered additive from ScoreModifierManager")

	_disconnect_game_controller()

func _on_tree_exiting() -> void:
	# Cleanup when PowerUp is destroyed
	if ScoreModifierManager.has_additive(modifier_source_name):
		ScoreModifierManager.unregister_additive(modifier_source_name)
		if _debug_enabled:
			print("[ExtremeCouponingPowerUp] Cleaned up additive on tree exit")

	_disconnect_game_controller()

func _disconnect_game_controller() -> void:
	if game_controller_ref:
		if game_controller_ref.has_signal("consumable_granted"):
			if game_controller_ref.is_connected("consumable_granted", _on_consumable_granted_signal):
				game_controller_ref.consumable_granted.disconnect(_on_consumable_granted_signal)
	game_controller_ref = null

func _on_consumable_granted_signal(consumable_id: String) -> void:
	on_consumable_granted(consumable_id)

func get_current_description() -> String:
	var base_desc = "+%d score per consumable granted this run" % bonus_per_consumable

	if consumables_granted > 0:
		var total_bonus = consumables_granted * bonus_per_consumable
		var progress_desc = "\nConsumables granted: %d (+%d bonus)" % [consumables_granted, total_bonus]
		return base_desc + progress_desc

	return base_desc

func _update_power_up_icons() -> void:
	# Update UI icons if description changes
	if not is_inside_tree() or not get_tree():
		return

	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon(get_runtime_power_up_id("extreme_couponing"))
		if icon:
			icon.update_hover_description()

			# If it's currently being hovered, make the label visible
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true
