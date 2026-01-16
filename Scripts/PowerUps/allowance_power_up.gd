extends PowerUp
class_name AllowancePowerUp

## AllowancePowerUp
##
## A common PowerUp that grants $100 when a challenge/round completes.
## Connects to the ChallengeManager's challenge_completed signal.

# Reference to challenge manager
var challenge_manager_ref: Node = null

# Track total money earned
var total_earned: int = 0

# Money granted per challenge completion
const MONEY_AMOUNT: int = 100

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")
	print("[AllowancePowerUp] Added to 'power_ups' group")

func _on_challenge_completed(_challenge_id: String) -> void:
	# Grant money when challenge/round completes
	PlayerEconomy.add_money(MONEY_AMOUNT)
	total_earned += MONEY_AMOUNT
	
	print("[AllowancePowerUp] Challenge completed! Granted $%d (total earned: $%d)" % [MONEY_AMOUNT, total_earned])
	
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
	
	print("[AllowancePowerUp] Applied successfully - will grant $%d when challenge completes" % MONEY_AMOUNT)

func remove(_target) -> void:
	print("=== Removing AllowancePowerUp ===")
	
	if challenge_manager_ref:
		if challenge_manager_ref.is_connected("challenge_completed", _on_challenge_completed):
			challenge_manager_ref.challenge_completed.disconnect(_on_challenge_completed)
			print("[AllowancePowerUp] Disconnected from challenge_completed signal")
	
	challenge_manager_ref = null

func get_current_description() -> String:
	if total_earned > 0:
		return "Grants $%d when challenge completes\nTotal earned: $%d" % [MONEY_AMOUNT, total_earned]
	else:
		return "Grants $%d when challenge completes" % MONEY_AMOUNT

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
