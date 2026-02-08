extends PowerUp
class_name DebuffDestroyerPowerUp

## DebuffDestroyerPowerUp
##
## Epic PowerUp that removes one random active debuff on purchase
## and at the beginning of each round while owned.
## Price: $400, Rarity: Epic

var game_controller_ref: GameController = null
var round_manager_ref = null
var debuffs_destroyed: int = 0

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(_target) -> void:
	print("=== Applying DebuffDestroyerPowerUp ===")
	
	game_controller_ref = get_tree().get_first_node_in_group("game_controller") as GameController
	if not game_controller_ref:
		push_error("[DebuffDestroyerPowerUp] GameController not found")
		return
	
	# Connect to round_started for ongoing debuff removal
	round_manager_ref = game_controller_ref.round_manager
	if round_manager_ref and not round_manager_ref.is_connected("round_started", _on_round_started):
		round_manager_ref.round_started.connect(_on_round_started)
		print("[DebuffDestroyerPowerUp] Connected to round_started signal")
	
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	
	# Immediately remove a random debuff on purchase
	_remove_random_debuff()

func remove(_target) -> void:
	print("=== Removing DebuffDestroyerPowerUp ===")
	if round_manager_ref and round_manager_ref.is_connected("round_started", _on_round_started):
		round_manager_ref.round_started.disconnect(_on_round_started)
	round_manager_ref = null
	game_controller_ref = null

## _on_round_started(_round_number)
##
## At round start, attempt to remove a random debuff if any are active.
func _on_round_started(_round_number: int) -> void:
	_remove_random_debuff()

## _remove_random_debuff()
##
## Picks a random active debuff and calls disable_debuff on the GameController.
## Logs the result and updates the description.
func _remove_random_debuff() -> void:
	if not game_controller_ref:
		return
	
	# Get active debuffs
	var active_ids: Array = game_controller_ref.active_debuffs.keys()
	if active_ids.is_empty():
		print("[DebuffDestroyerPowerUp] No active debuffs to remove")
		return
	
	# Pick a random debuff to remove
	var random_index = randi() % active_ids.size()
	var debuff_to_remove = active_ids[random_index]
	
	print("[DebuffDestroyerPowerUp] Removing random debuff: %s" % debuff_to_remove)
	game_controller_ref.disable_debuff(debuff_to_remove)
	debuffs_destroyed += 1
	print("[DebuffDestroyerPowerUp] Debuff '%s' destroyed! Total destroyed: %d" % [debuff_to_remove, debuffs_destroyed])
	
	emit_signal("description_updated", id, get_current_description())
	_update_power_up_icons()

func get_current_description() -> String:
	var debuff_count = 0
	if game_controller_ref:
		debuff_count = game_controller_ref.active_debuffs.size()
	return "Removes 1 random debuff on purchase & each round start.\nActive debuffs: %d | Total destroyed: %d" % [debuff_count, debuffs_destroyed]

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("debuff_destroyer")
		if icon:
			icon.update_hover_description()

func _on_tree_exiting() -> void:
	if round_manager_ref and round_manager_ref.is_connected("round_started", _on_round_started):
		round_manager_ref.round_started.disconnect(_on_round_started)
