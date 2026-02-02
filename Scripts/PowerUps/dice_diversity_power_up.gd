extends PowerUp
class_name DiceDiversityPowerUp

## DiceDiversityPowerUp
##
## Grants $5 for each unique dice value scored during a turn.
## Money is awarded at the end of each turn based on unique values (1-6) used.
## Encourages varied dice combinations rather than all-same patterns.
## Common rarity, $50 price.

# Reference to scorecard and turn tracker
var scorecard_ref: Scorecard = null
var turn_tracker_ref: TurnTracker = null

# Track unique dice values scored this turn
var unique_values_this_turn: Dictionary = {}  # value -> true
var total_money_granted: int = 0

const MONEY_PER_UNIQUE: int = 5

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying DiceDiversityPowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[DiceDiversityPowerUp] Target is not a Scorecard")
		return
	
	# Store reference to the scorecard
	scorecard_ref = scorecard
	
	# Get turn tracker from tree
	var tree = scorecard.get_tree()
	if tree:
		turn_tracker_ref = tree.get_first_node_in_group("turn_tracker")
	
	# Connect to score_assigned to track unique dice values
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
		print("[DiceDiversityPowerUp] Connected to score_assigned signal")
	
	# Connect to turn_started to reset tracking and pay out
	if turn_tracker_ref:
		if not turn_tracker_ref.is_connected("turn_started", _on_turn_started):
			turn_tracker_ref.turn_started.connect(_on_turn_started)
			print("[DiceDiversityPowerUp] Connected to turn_started signal")
	
	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func _on_score_assigned(_section: Scorecard.Section, _category: String, _score: int) -> void:
	# Get the dice values that were just scored
	var dice_values = DiceResults.get_values()
	
	# Track unique values
	for value in dice_values:
		unique_values_this_turn[value] = true
	
	# Award money immediately for this scoring
	var unique_count = unique_values_this_turn.size()
	var money_to_grant = unique_count * MONEY_PER_UNIQUE
	
	if money_to_grant > 0:
		PlayerEconomy.add_money(money_to_grant)
		total_money_granted += money_to_grant
		print("[DiceDiversityPowerUp] Granted $%d for %d unique dice values" % [money_to_grant, unique_count])
		
		# Update description
		emit_signal("description_updated", id, get_current_description())
		
		if is_inside_tree():
			_update_power_up_icons()

func _on_turn_started() -> void:
	# Reset tracking for the new turn
	unique_values_this_turn.clear()
	print("[DiceDiversityPowerUp] Reset unique values tracking for new turn")

func get_current_description() -> String:
	var base_desc = "+$%d for each unique dice value scored" % MONEY_PER_UNIQUE
	
	var current_unique = unique_values_this_turn.size()
	if current_unique > 0:
		var values_str = ", ".join(unique_values_this_turn.keys().map(func(v): return str(v)))
		base_desc += "\nThis turn: %d unique (%s)" % [current_unique, values_str]
	
	if total_money_granted > 0:
		base_desc += "\nTotal earned: $%d" % total_money_granted
	
	return base_desc

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("dice_diversity")
		if icon:
			icon.update_hover_description()
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

func remove(target) -> void:
	print("=== Removing DiceDiversityPowerUp ===")
	
	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		scorecard = scorecard_ref
	
	if scorecard:
		if scorecard.is_connected("score_assigned", _on_score_assigned):
			scorecard.score_assigned.disconnect(_on_score_assigned)
			print("[DiceDiversityPowerUp] Disconnected from score_assigned signal")
	
	if turn_tracker_ref:
		if turn_tracker_ref.is_connected("turn_started", _on_turn_started):
			turn_tracker_ref.turn_started.disconnect(_on_turn_started)
			print("[DiceDiversityPowerUp] Disconnected from turn_started signal")
	
	scorecard_ref = null
	turn_tracker_ref = null

func _on_tree_exiting() -> void:
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
	
	if turn_tracker_ref:
		if turn_tracker_ref.is_connected("turn_started", _on_turn_started):
			turn_tracker_ref.turn_started.disconnect(_on_turn_started)
