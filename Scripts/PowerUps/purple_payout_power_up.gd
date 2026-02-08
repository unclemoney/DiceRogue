extends PowerUp
class_name PurplePayoutPowerUp

## PurplePayoutPowerUp
##
## Common PowerUp that grants $3 for each purple die rolled when scoring.
## Encourages players to invest in purple dice for passive income.
## Price: $50, Rarity: Common

const MONEY_PER_PURPLE_DIE: int = 3

var scorecard_ref: Scorecard = null
var score_card_ui_ref = null
var total_purple_money_earned: int = 0

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying PurplePayoutPowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[PurplePayoutPowerUp] Target is not a Scorecard")
		return
	
	scorecard_ref = scorecard
	
	# Get score_card_ui from GameController for about_to_score signal
	var game_controller = scorecard.get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.score_card_ui:
		score_card_ui_ref = game_controller.score_card_ui
		if not score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.connect(_on_about_to_score)
	else:
		push_error("[PurplePayoutPowerUp] Could not find ScoreCardUI via GameController")
	
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func remove(_target) -> void:
	print("=== Removing PurplePayoutPowerUp ===")
	if score_card_ui_ref and score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
		score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
	score_card_ui_ref = null
	scorecard_ref = null

func _on_about_to_score(_section: Scorecard.Section, _category: String, _dice_values: Array[int]) -> void:
	# Count purple dice in the current hand
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if not game_controller or not game_controller.dice_hand:
		return
	
	var purple_count: int = 0
	for die in game_controller.dice_hand.get_all_dice():
		if die.get_color() == DiceColor.Type.PURPLE:
			purple_count += 1
	
	if purple_count > 0:
		var money_earned = purple_count * MONEY_PER_PURPLE_DIE
		PlayerEconomy.add_money(money_earned)
		total_purple_money_earned += money_earned
		print("[PurplePayoutPowerUp] Earned $%d from %d purple dice" % [money_earned, purple_count])
		emit_signal("description_updated", id, get_current_description())
		_update_power_up_icons()

func get_current_description() -> String:
	return "Each purple die grants $%d when scoring.\nTotal earned: $%d" % [MONEY_PER_PURPLE_DIE, total_purple_money_earned]

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("purple_payout")
		if icon:
			icon.update_hover_description()

func _on_tree_exiting() -> void:
	if score_card_ui_ref and score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
		score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
