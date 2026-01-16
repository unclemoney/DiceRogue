extends PowerUp
class_name TangoAndCashPowerUp

## TangoAndCashPowerUp
##
## Grants $10 for every odd die scored during each round.
## Money is awarded at the end of each round.
## Uncommon rarity, PG-13 rating.

# Reference to round manager
var round_manager_ref: Node = null
var total_money_granted: int = 0

const MONEY_PER_ODD_DIE: int = 10

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying TangoAndCashPowerUp ===")
	
	# Get round manager from the tree
	var tree = null
	if target is Node:
		tree = target.get_tree()
	elif is_inside_tree():
		tree = get_tree()
	
	if not tree:
		push_error("[TangoAndCashPowerUp] Cannot access scene tree")
		return
	
	# Try to find RoundManager - first by group, then by class
	round_manager_ref = tree.get_first_node_in_group("round_manager")
	if not round_manager_ref:
		# Fallback: search all nodes for RoundManager class
		var nodes = tree.root.find_children("*", "RoundManager", true, false)
		if nodes.size() > 0:
			round_manager_ref = nodes[0]
			print("[TangoAndCashPowerUp] Found RoundManager by class search")
	
	if not round_manager_ref:
		push_error("[TangoAndCashPowerUp] RoundManager not found")
		return
	
	# Connect to round_completed signal (note: signal passes round_number: int)
	if not round_manager_ref.is_connected("round_completed", _on_round_completed):
		round_manager_ref.round_completed.connect(_on_round_completed)
		print("[TangoAndCashPowerUp] Connected to round_completed signal")
	
	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func _on_round_completed(_round_number: int) -> void:
	# Skip round 0 which is an initialization signal, not actual gameplay
	if _round_number < 1:
		return
	
	# Get odd dice count from Statistics
	var odd_count = Statistics.odd_dice_scored_this_round
	var money_to_grant = odd_count * MONEY_PER_ODD_DIE
	
	if money_to_grant > 0:
		PlayerEconomy.add_money(money_to_grant)
		total_money_granted += money_to_grant
		print("[TangoAndCashPowerUp] Granted $%d for %d odd dice scored this round" % [money_to_grant, odd_count])
		
		# Update description
		emit_signal("description_updated", id, get_current_description())
		
		if is_inside_tree():
			_update_power_up_icons()
	else:
		print("[TangoAndCashPowerUp] No odd dice scored this round")

func get_current_description() -> String:
	var base_desc = "+$%d for every odd die scored (at round end)" % MONEY_PER_ODD_DIE
	
	if total_money_granted > 0:
		var progress_desc = "\nTotal earned: $%d" % total_money_granted
		return base_desc + progress_desc
	
	return base_desc

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("tango_and_cash")
		if icon:
			icon.update_hover_description()
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

func remove(target) -> void:
	print("=== Removing TangoAndCashPowerUp ===")
	
	var round_mgr: Node = null
	if target and target.is_in_group("round_manager"):
		round_mgr = target
	elif round_manager_ref:
		round_mgr = round_manager_ref
	
	if round_mgr:
		if round_mgr.is_connected("round_completed", _on_round_completed):
			round_mgr.round_completed.disconnect(_on_round_completed)
			print("[TangoAndCashPowerUp] Disconnected from round_completed signal")
	
	round_manager_ref = null

func _on_tree_exiting() -> void:
	if round_manager_ref:
		if round_manager_ref.is_connected("round_completed", _on_round_completed):
			round_manager_ref.round_completed.disconnect(_on_round_completed)
