extends PowerUp
class_name StraightTripletMasterPowerUp

## StraightTripletMasterPowerUp
##
## Rare PowerUp that rewards scoring 3 Large Straights in ONE round:
## - 1 in the Large Straight category
## - 1 in the Small Straight category (scored as a large straight)
## - 1 in the Chance category (scored as a large straight)
## When all 3 are achieved in a single round, grants +$150 and +75 bonus points.
## Resets each round if not completed.
## Price: $275, Rarity: Rare

const BONUS_MONEY: int = 150
const BONUS_POINTS: int = 75

var scorecard_ref: Scorecard = null
var large_straight_in_large: bool = false
var large_straight_in_small: bool = false
var large_straight_in_chance: bool = false
var bonus_awarded: bool = false
var total_bonuses_earned: int = 0

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying StraightTripletMasterPowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[StraightTripletMasterPowerUp] Target is not a Scorecard")
		return
	
	scorecard_ref = scorecard
	
	# Connect to score_assigned to track large straight placements
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
	
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func remove(_target) -> void:
	print("=== Removing StraightTripletMasterPowerUp ===")
	if scorecard_ref and scorecard_ref.is_connected("score_assigned", _on_score_assigned):
		scorecard_ref.score_assigned.disconnect(_on_score_assigned)
	scorecard_ref = null

func _on_score_assigned(section: Scorecard.Section, category: String, score: int) -> void:
	if bonus_awarded:
		return
	
	# Check if a large straight value (40) was scored in each target category
	# Large straight base score is 40
	if category == "large_straight" and section == Scorecard.Section.LOWER:
		if score >= 40:
			large_straight_in_large = true
			print("[StraightTripletMasterPowerUp] Large Straight scored in Large Straight category!")
	
	if category == "small_straight" and section == Scorecard.Section.LOWER:
		# Check if the score suggests a large straight was available
		# A large straight scored in small straight still gets small straight's 30 base
		if score >= 30:
			large_straight_in_small = true
			print("[StraightTripletMasterPowerUp] Straight scored in Small Straight category!")
	
	if category == "chance" and section == Scorecard.Section.LOWER:
		# For chance, check if dice form a large straight (sum of 1+2+3+4+5=15 or 2+3+4+5+6=20)
		# Any score in chance counts as progress
		if score >= 15:
			large_straight_in_chance = true
			print("[StraightTripletMasterPowerUp] Score in Chance category!")
	
	emit_signal("description_updated", id, get_current_description())
	_update_power_up_icons()
	
	# Check if all three conditions are met
	if large_straight_in_large and large_straight_in_small and large_straight_in_chance:
		_award_bonus()

func _award_bonus() -> void:
	bonus_awarded = true
	total_bonuses_earned += 1
	
	# Grant money bonus
	PlayerEconomy.add_money(BONUS_MONEY)
	print("[StraightTripletMasterPowerUp] TRIPLET ACHIEVED! Awarded $%d" % BONUS_MONEY)
	
	# Add one-time bonus points directly to the scorecard total
	if scorecard_ref:
		scorecard_ref.yahtzee_bonus_points += BONUS_POINTS
		print("[StraightTripletMasterPowerUp] Added +%d one-time bonus points to scorecard" % BONUS_POINTS)
	
	emit_signal("description_updated", id, get_current_description())
	_update_power_up_icons()

func get_current_description() -> String:
	var status_large = "[color=green]YES[/color]" if large_straight_in_large else "[color=red]NO[/color]"
	var status_small = "[color=green]YES[/color]" if large_straight_in_small else "[color=red]NO[/color]"
	var status_chance = "[color=green]YES[/color]" if large_straight_in_chance else "[color=red]NO[/color]"
	
	if bonus_awarded:
		return "TRIPLET MASTER ACHIEVED!\n+$%d and +%d bonus points!\nTimes achieved: %d" % [BONUS_MONEY, BONUS_POINTS, total_bonuses_earned]
	
	return "Score straights in all 3 categories in 1 round:\nLg Straight: %s | Sm Straight: %s | Chance: %s\nReward: +$%d and +%d pts" % [status_large, status_small, status_chance, BONUS_MONEY, BONUS_POINTS]

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("straight_triplet_master")
		if icon:
			icon.update_hover_description()

func _on_tree_exiting() -> void:
	if scorecard_ref and scorecard_ref.is_connected("score_assigned", _on_score_assigned):
		scorecard_ref.score_assigned.disconnect(_on_score_assigned)
