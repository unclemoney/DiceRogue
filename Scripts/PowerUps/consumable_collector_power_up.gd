extends PowerUp
class_name ConsumableCollectorPowerUp

## ConsumableCollectorPowerUp
##
## Rare PowerUp that grants a stacking x0.1 score multiplier
## for every consumable used during the game. Tracks total consumables
## used and registers a persistent multiplier with ScoreModifierManager.
## Price: $275, Rarity: Rare, Rating: PG-13
##
## Integration: Uses ScoreModifierManager for multiplier (logbook visible).
## Connects to game_controller.consumable_used signal.
## Note: consumable_used emits (id: String, consumable: Consumable).

var game_controller_ref = null
var consumables_used_count: int = 0
var current_multiplier: float = 1.0

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying ConsumableCollectorPowerUp ===")
	var card = target as Scorecard
	if not card:
		push_error("[ConsumableCollectorPowerUp] Target is not a Scorecard")
		return
	
	consumables_used_count = 0
	current_multiplier = 1.0
	
	game_controller_ref = get_tree().get_first_node_in_group("game_controller")
	if game_controller_ref:
		if game_controller_ref.has_signal("consumable_used"):
			if not game_controller_ref.is_connected("consumable_used", _on_consumable_used):
				game_controller_ref.consumable_used.connect(_on_consumable_used)
				print("[ConsumableCollectorPowerUp] Connected to consumable_used signal")
	
	# Register initial multiplier (1.0 = no effect until consumables are used)
	ScoreModifierManager.register_multiplier("consumable_collector", current_multiplier)
	print("[ConsumableCollectorPowerUp] Registered initial multiplier x%.1f" % current_multiplier)
	
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func _on_consumable_used(_consumable_id: String, _consumable) -> void:
	## _on_consumable_used()
	##
	## Called every time a consumable is used. Increments the counter
	## and immediately updates the persistent multiplier in ScoreModifierManager.
	## Signal signature: consumable_used(id: String, consumable: Consumable)
	consumables_used_count += 1
	current_multiplier = 1.0 + (consumables_used_count * 0.1)
	print("[ConsumableCollectorPowerUp] Consumable used! Count: %d, Multiplier: x%.1f" % [consumables_used_count, current_multiplier])
	
	# Update the persistent multiplier
	ScoreModifierManager.register_multiplier("consumable_collector", current_multiplier)
	print("[ConsumableCollectorPowerUp] Updated multiplier to x%.1f" % current_multiplier)
	
	emit_signal("description_updated", id, get_current_description())
	_update_power_up_icons()

func get_current_description() -> String:
	return "x%.1f score multiplier\n(%d consumables used, +0.1x each)" % [current_multiplier, consumables_used_count]

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("consumable_collector")
		if icon:
			icon.update_hover_description()

func remove(_target) -> void:
	print("=== Removing ConsumableCollectorPowerUp ===")
	# Unregister multiplier from ScoreModifierManager
	ScoreModifierManager.unregister_multiplier("consumable_collector")
	
	if game_controller_ref:
		if game_controller_ref.has_signal("consumable_used"):
			if game_controller_ref.is_connected("consumable_used", _on_consumable_used):
				game_controller_ref.consumable_used.disconnect(_on_consumable_used)
	
	game_controller_ref = null

func _on_tree_exiting() -> void:
	ScoreModifierManager.unregister_multiplier("consumable_collector")
	
	if game_controller_ref:
		if game_controller_ref.has_signal("consumable_used"):
			if game_controller_ref.is_connected("consumable_used", _on_consumable_used):
				game_controller_ref.consumable_used.disconnect(_on_consumable_used)
