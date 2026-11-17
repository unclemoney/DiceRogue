extends PowerUp
class_name SweetSixteenPowerUp

## SweetSixteenPowerUp
##
## An uncommon PowerUp that pays out at the end of each round.
## When the round ends (all 13 scorecard categories filled), grants $0.05 for
## every category whose final stored score is 16 or higher.
## If all 13 categories score 16+, also grants a stacking $2.56 bonus
## (total $3.21 for a perfect round).
##
## Connects to Scorecard's game_completed signal for the round-end payout.

var scorecard_ref: Node = null
var game_controller_ref = null

var total_earned: float = 0.0

const MONEY_PER_QUALIFYING_CATEGORY: float = 0.05
const PERFECT_ROUND_BONUS: float = 2.56
const QUALIFYING_SCORE: int = 16
const TOTAL_CATEGORIES: int = 13

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")
	print("[SweetSixteenPowerUp] Added to 'power_ups' group")

func apply(target) -> void:
	print("=== Applying SweetSixteenPowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[SweetSixteenPowerUp] Target is not a Scorecard")
		return
	
	scorecard_ref = scorecard
	
	# Find GameController for the award_score_time_power_up_money grant path
	game_controller_ref = scorecard.get_tree().get_first_node_in_group("game_controller")
	if not game_controller_ref:
		push_error("[SweetSixteenPowerUp] Could not find GameController")
		return
	
	# Connect to game_completed for the end-of-round payout
	if scorecard_ref.has_signal("game_completed"):
		if not scorecard_ref.is_connected("game_completed", _on_round_end_payout):
			scorecard_ref.game_completed.connect(_on_round_end_payout)
			print("[SweetSixteenPowerUp] Connected to game_completed signal")
	else:
		push_error("[SweetSixteenPowerUp] Scorecard has no game_completed signal")
		return
	
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	
	print("[SweetSixteenPowerUp] Applied successfully - will grant $%.2f per category scoring %d+ at round end, +$%.2f for all %d" % [MONEY_PER_QUALIFYING_CATEGORY, QUALIFYING_SCORE, PERFECT_ROUND_BONUS, TOTAL_CATEGORIES])

func _on_round_end_payout(_final_score: int) -> void:
	# TurnTracker can force-emit game_completed at max turns with categories
	# still unfilled; only pay out on a genuinely completed scorecard.
	if not scorecard_ref or not scorecard_ref.is_game_complete():
		print("[SweetSixteenPowerUp] game_completed received but scorecard not complete - skipping payout")
		return
	
	# Count categories whose final stored score qualifies
	var qualifying: int = 0
	for score in scorecard_ref.upper_scores.values():
		if score != null and score >= QUALIFYING_SCORE:
			qualifying += 1
	for score in scorecard_ref.lower_scores.values():
		if score != null and score >= QUALIFYING_SCORE:
			qualifying += 1
	
	# First grant: $0.05 per qualifying category
	if qualifying > 0:
		var category_payout: float = qualifying * MONEY_PER_QUALIFYING_CATEGORY
		var awarded: float = _grant(category_payout, "sweet_sixteen")
		total_earned += awarded
		print("[SweetSixteenPowerUp] Round end: %d categories scored %d+. Granted $%.2f (total earned: $%.2f)" % [qualifying, QUALIFYING_SCORE, awarded, total_earned])
	else:
		print("[SweetSixteenPowerUp] Round end: no categories scored %d+ - no payout" % QUALIFYING_SCORE)
	
	# Then, if ALL categories qualify, the stacking perfect-round bonus
	if qualifying == TOTAL_CATEGORIES:
		var bonus_awarded: float = _grant(PERFECT_ROUND_BONUS, "sweet_sixteen_perfect_round")
		total_earned += bonus_awarded
		print("[SweetSixteenPowerUp] PERFECT ROUND! All %d categories scored %d+. Granted $%.2f bonus! (total earned: $%.2f)" % [TOTAL_CATEGORIES, QUALIFYING_SCORE, bonus_awarded, total_earned])
	
	emit_signal("description_updated", id, get_current_description())
	
	if is_inside_tree():
		_update_power_up_icons()

func _grant(amount: float, tag: String) -> float:
	if game_controller_ref and is_instance_valid(game_controller_ref) and game_controller_ref.has_method("award_score_time_power_up_money"):
		return game_controller_ref.award_score_time_power_up_money(amount, tag)
	PlayerEconomy.add_money(amount)
	return amount

func remove(_target) -> void:
	print("=== Removing SweetSixteenPowerUp ===")
	
	if scorecard_ref:
		if scorecard_ref.is_connected("game_completed", _on_round_end_payout):
			scorecard_ref.game_completed.disconnect(_on_round_end_payout)
			print("[SweetSixteenPowerUp] Disconnected from game_completed signal")
	
	scorecard_ref = null
	game_controller_ref = null

func get_current_description() -> String:
	var base_desc = "End of round: $%.2f per category scoring %d+. All %d: +$%.2f." % [MONEY_PER_QUALIFYING_CATEGORY, QUALIFYING_SCORE, TOTAL_CATEGORIES, PERFECT_ROUND_BONUS]
	
	if total_earned > 0:
		base_desc += "\nTotal earned: $%.2f" % total_earned
	
	return base_desc

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("sweet_sixteen")
		if icon:
			icon.update_hover_description()
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

func _on_tree_exiting() -> void:
	if scorecard_ref:
		if scorecard_ref.is_connected("game_completed", _on_round_end_payout):
			scorecard_ref.game_completed.disconnect(_on_round_end_payout)
	
	print("[SweetSixteenPowerUp] Cleanup: Disconnected signals")
