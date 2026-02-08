extends PowerUp
class_name DebuffDestroyerPowerUp

## DebuffDestroyerPowerUp
##
## Epic PowerUp that removes one random active debuff when SOLD.
## This is a strategic tool - buy it and sell it to cleanse a debuff.
## The sell action triggers the debuff removal immediately.
## Price: $400, Rarity: Epic

var game_controller_ref = null

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(_target) -> void:
	print("=== Applying DebuffDestroyerPowerUp ===")
	
	game_controller_ref = get_tree().get_first_node_in_group("game_controller")
	if not game_controller_ref:
		push_error("[DebuffDestroyerPowerUp] GameController not found")
		return
	
	# Connect to the power_up_sold signal to trigger debuff removal on sell
	var powerup_ui = get_tree().get_first_node_in_group("power_up_ui")
	if powerup_ui and not powerup_ui.is_connected("power_up_sold", _on_any_power_up_sold):
		powerup_ui.power_up_sold.connect(_on_any_power_up_sold)
		print("[DebuffDestroyerPowerUp] Connected to power_up_sold signal")
	
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func remove(_target) -> void:
	print("=== Removing DebuffDestroyerPowerUp ===")
	var powerup_ui = null
	if is_inside_tree() and get_tree():
		powerup_ui = get_tree().get_first_node_in_group("power_up_ui")
	if powerup_ui and powerup_ui.is_connected("power_up_sold", _on_any_power_up_sold):
		powerup_ui.power_up_sold.disconnect(_on_any_power_up_sold)
	game_controller_ref = null

func _on_any_power_up_sold(power_up_id: String) -> void:
	# Only trigger on OUR sell event
	if power_up_id != "debuff_destroyer":
		return
	
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
	print("[DebuffDestroyerPowerUp] Debuff '%s' destroyed!" % debuff_to_remove)

func get_current_description() -> String:
	var debuff_count = 0
	if game_controller_ref:
		debuff_count = game_controller_ref.active_debuffs.size()
	return "SELL this PowerUp to remove 1 random debuff!\nActive debuffs: %d" % debuff_count

func _on_tree_exiting() -> void:
	var powerup_ui = null
	if is_inside_tree() and get_tree():
		powerup_ui = get_tree().get_first_node_in_group("power_up_ui")
	if powerup_ui and powerup_ui.is_connected("power_up_sold", _on_any_power_up_sold):
		powerup_ui.power_up_sold.disconnect(_on_any_power_up_sold)
