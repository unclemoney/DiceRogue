extends PowerUp
class_name FailedMoneyPowerUp

## FailedMoneyPowerUp
##
## Grants $25 for each failed hand (0 score category) at the end of each round.
## Example: 4 failed hands = $100 at round end.
## Common rarity, PG rating.

# Reference to round manager
var round_manager_ref: Node = null
var total_money_granted: int = 0

const MONEY_PER_FAILED_HAND: int = 25

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying FailedMoneyPowerUp ===")
	
	# Get round manager from the tree
	var tree = null
	if target is Node:
		tree = target.get_tree()
	elif is_inside_tree():
		tree = get_tree()
	
	if not tree:
		push_error("[FailedMoneyPowerUp] Cannot access scene tree")
		return
	
	# Try to find RoundManager - first by group, then by class
	round_manager_ref = tree.get_first_node_in_group("round_manager")
	if not round_manager_ref:
		# Fallback: search all nodes for RoundManager class
		var nodes = tree.root.find_children("*", "RoundManager", true, false)
		if nodes.size() > 0:
			round_manager_ref = nodes[0]
			print("[FailedMoneyPowerUp] Found RoundManager by class search")
	
	if not round_manager_ref:
		push_error("[FailedMoneyPowerUp] RoundManager not found")
		return
	
	# Connect to round_completed signal (note: signal passes round_number: int)
	if not round_manager_ref.is_connected("round_completed", _on_round_completed):
		round_manager_ref.round_completed.connect(_on_round_completed)
		print("[FailedMoneyPowerUp] Connected to round_completed signal")
	
	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func _on_round_completed(_round_number: int) -> void:
	# Skip round 0 which is an initialization signal, not actual gameplay
	if _round_number < 1:
		return
	
	# Get failed hands count from Statistics
	var failed_count = Statistics.failed_hands
	var money_to_grant = failed_count * MONEY_PER_FAILED_HAND
	
	if money_to_grant > 0:
		PlayerEconomy.add_money(money_to_grant)
		total_money_granted += money_to_grant
		print("[FailedMoneyPowerUp] Granted $%d for %d failed hands" % [money_to_grant, failed_count])
		
		# Update description
		emit_signal("description_updated", id, get_current_description())
		
		if is_inside_tree():
			_update_power_up_icons()
	else:
		print("[FailedMoneyPowerUp] No failed hands to reward")

func get_current_description() -> String:
	var current_failed = Statistics.failed_hands
	var base_desc = "+$%d for each failed hand (at round end)" % MONEY_PER_FAILED_HAND
	
	var progress_desc = "\nFailed hands: %d" % current_failed
	if total_money_granted > 0:
		progress_desc += " | Total earned: $%d" % total_money_granted
	
	return base_desc + progress_desc

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("failed_money")
		if icon:
			icon.update_hover_description()
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

func remove(target) -> void:
	print("=== Removing FailedMoneyPowerUp ===")
	
	var round_mgr: Node = null
	if target and target.is_in_group("round_manager"):
		round_mgr = target
	elif round_manager_ref:
		round_mgr = round_manager_ref
	
	if round_mgr:
		if round_mgr.is_connected("round_completed", _on_round_completed):
			round_mgr.round_completed.disconnect(_on_round_completed)
			print("[FailedMoneyPowerUp] Disconnected from round_completed signal")
	
	round_manager_ref = null

func _on_tree_exiting() -> void:
	if round_manager_ref:
		if round_manager_ref.is_connected("round_completed", _on_round_completed):
			round_manager_ref.round_completed.disconnect(_on_round_completed)
