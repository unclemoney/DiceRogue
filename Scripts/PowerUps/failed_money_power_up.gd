extends PowerUp
class_name FailedMoneyPowerUp

## FailedMoneyPowerUp
##
## Grants $50 for each failed hand (0 score category) at the end of each round.
## Example: 4 failed hands = $200 at round end.
## Common rarity, PG rating.

# Reference to round manager
var round_manager_ref: Node = null
var total_money_granted: int = 0
var _last_consumed_round_number: int = 0

const MONEY_PER_FAILED_HAND: int = 50

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
	
	print("[FailedMoneyPowerUp] Ready to contribute to the round-end PowerUp bonus payout")

func get_current_description() -> String:
	var current_failed = Statistics.failed_hands_this_round
	var base_desc = "+$%d for each failed hand (at round end)" % MONEY_PER_FAILED_HAND
	
	var progress_desc = "\nFailed hands this round: %d" % current_failed
	if total_money_granted > 0:
		progress_desc += " | Total earned: $%d" % total_money_granted
	
	return base_desc + progress_desc


func get_pending_round_end_bonus() -> int:
	var round_number = _get_current_round_number()
	if round_number < 1 or round_number == _last_consumed_round_number:
		return 0
	return Statistics.failed_hands_this_round * MONEY_PER_FAILED_HAND


func consume_pending_round_end_bonus() -> int:
	var money_to_grant = get_pending_round_end_bonus()
	if money_to_grant <= 0:
		return 0

	_last_consumed_round_number = _get_current_round_number()
	total_money_granted += money_to_grant
	print("[FailedMoneyPowerUp] Consumed $%d for %d failed hands this round" % [money_to_grant, Statistics.failed_hands_this_round])
	emit_signal("description_updated", id, get_current_description())
	if is_inside_tree():
		_update_power_up_icons()
	return money_to_grant


func _get_current_round_number() -> int:
	if round_manager_ref and round_manager_ref.has_method("get_current_round_number"):
		return int(round_manager_ref.get_current_round_number())
	return -1

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

func remove(_target) -> void:
	print("=== Removing FailedMoneyPowerUp ===")
	
	round_manager_ref = null

func _on_tree_exiting() -> void:
	round_manager_ref = null
