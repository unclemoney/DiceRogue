extends PowerUp
class_name AllowancePowerUp

## AllowancePowerUp
##
## A common PowerUp that adds $100 to the round-end PowerUp bonus payout
## when a challenge is completed.
## Connects to the ChallengeManager's challenge_completed signal.

# Reference to challenge manager
var challenge_manager_ref: Node = null

# Track total money earned
var total_earned: int = 0
var pending_round_end_bonus: int = 0

# Money granted per challenge completion
const MONEY_AMOUNT: int = 100

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")
	print("[AllowancePowerUp] Added to 'power_ups' group")

func _on_challenge_completed(_challenge_id: String) -> void:
	# Queue the reward for the end-of-round stats payout instead of granting it immediately.
	pending_round_end_bonus += MONEY_AMOUNT
	
	print("[AllowancePowerUp] Challenge completed! Queued $%d for round-end payout (pending: $%d)" % [MONEY_AMOUNT, pending_round_end_bonus])
	
	# Update description
	emit_signal("description_updated", id, get_current_description())
	
	# Update UI icons
	if is_inside_tree():
		_update_power_up_icons()

func apply(target) -> void:
	print("=== Applying AllowancePowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[AllowancePowerUp] Target is not a Scorecard")
		return
	
	# Find ChallengeManager via GameController
	var game_controller = scorecard.get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.challenge_manager:
		challenge_manager_ref = game_controller.challenge_manager
		if not challenge_manager_ref.is_connected("challenge_completed", _on_challenge_completed):
			challenge_manager_ref.challenge_completed.connect(_on_challenge_completed)
			print("[AllowancePowerUp] Connected to challenge_completed signal")
	else:
		push_error("[AllowancePowerUp] Could not find ChallengeManager via GameController")
		return
	
	# Connect to tree_exiting for cleanup
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	
	print("[AllowancePowerUp] Applied successfully - will add $%d to the round-end PowerUp bonus when a challenge completes" % MONEY_AMOUNT)

func remove(_target) -> void:
	print("=== Removing AllowancePowerUp ===")
	
	if challenge_manager_ref:
		if challenge_manager_ref.is_connected("challenge_completed", _on_challenge_completed):
			challenge_manager_ref.challenge_completed.disconnect(_on_challenge_completed)
			print("[AllowancePowerUp] Disconnected from challenge_completed signal")
	
	challenge_manager_ref = null

func get_current_description() -> String:
	var lines: Array[String] = ["Adds $%d to round-end PowerUp bonuses when a challenge completes" % MONEY_AMOUNT]
	if pending_round_end_bonus > 0:
		lines.append("Pending this round: $%d" % pending_round_end_bonus)
	if total_earned > 0:
		lines.append("Total earned: $%d" % total_earned)
	return "\n".join(lines)


func get_pending_round_end_bonus() -> int:
	return pending_round_end_bonus


func consume_pending_round_end_bonus() -> int:
	if pending_round_end_bonus <= 0:
		return 0

	var granted_amount = pending_round_end_bonus
	pending_round_end_bonus = 0
	total_earned += granted_amount
	print("[AllowancePowerUp] Consumed pending round-end bonus: $%d (total earned: $%d)" % [granted_amount, total_earned])
	emit_signal("description_updated", id, get_current_description())
	if is_inside_tree():
		_update_power_up_icons()
	return granted_amount

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("allowance")
		if icon:
			icon.update_hover_description()
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

func _on_tree_exiting() -> void:
	# Cleanup when PowerUp is destroyed
	if challenge_manager_ref:
		if challenge_manager_ref.is_connected("challenge_completed", _on_challenge_completed):
			challenge_manager_ref.challenge_completed.disconnect(_on_challenge_completed)
		print("[AllowancePowerUp] Cleanup: Disconnected signals")
