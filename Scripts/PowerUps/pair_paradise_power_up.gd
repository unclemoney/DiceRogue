extends PowerUp
class_name PairParadisePowerUp

## PairParadisePowerUp
##
## Adds additive bonus based on pair patterns in scored dice:
## - +3 for a pair or three-of-a-kind
## - +6 for two pair or four-of-a-kind
## - +9 for full house or five-of-a-kind (Yahtzee)
## Analyzes dice value frequencies to detect patterns.
## Common rarity, $75 price.

# References
var scorecard_ref: Scorecard = null
var score_card_ui_ref = null

# ScoreModifierManager source name
var modifier_source_name: String = "pair_paradise"

# Track for description
var last_bonus: int = 0
var total_bonus_applied: int = 0
var times_triggered: int = 0

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying PairParadisePowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[PairParadisePowerUp] Target is not a Scorecard")
		return
	
	# Store reference to the scorecard
	scorecard_ref = scorecard
	
	# Get score_card_ui via GameController for reliability
	var tree = scorecard.get_tree()
	if tree:
		var game_controller = tree.get_first_node_in_group("game_controller")
		if game_controller and game_controller.score_card_ui:
			score_card_ui_ref = game_controller.score_card_ui
	
	# Connect to about_to_score to analyze dice and register additive
	if score_card_ui_ref:
		if not score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.connect(_on_about_to_score)
			print("[PairParadisePowerUp] Connected to about_to_score signal")
	
	# Connect to score_assigned to clean up additive
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
		print("[PairParadisePowerUp] Connected to score_assigned signal")
	
	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func _analyze_pair_patterns(dice_values: Array[int]) -> int:
	## Analyzes dice values and returns bonus amount based on pair patterns.
	## Returns:
	##   0 - No pairs
	##   3 - Pair or three-of-a-kind
	##   6 - Two pair or four-of-a-kind
	##   9 - Full house or five-of-a-kind
	
	if dice_values.is_empty():
		return 0
	
	# Count frequency of each value
	var frequency: Dictionary = {}
	for value in dice_values:
		if frequency.has(value):
			frequency[value] += 1
		else:
			frequency[value] = 1
	
	# Get sorted frequencies (highest first)
	var freq_values: Array = frequency.values()
	freq_values.sort()
	freq_values.reverse()
	
	# Analyze patterns based on frequencies
	# freq_values[0] is the highest frequency
	
	if freq_values.size() == 0:
		return 0
	
	var highest_freq = freq_values[0]
	var second_freq = freq_values[1] if freq_values.size() > 1 else 0
	
	# Five-of-a-kind (Yahtzee) - all 5 dice same
	if highest_freq >= 5:
		return 9
	
	# Full house (3 + 2) or four-of-a-kind
	if highest_freq == 4:
		return 6  # Four-of-a-kind
	
	if highest_freq == 3:
		if second_freq >= 2:
			return 9  # Full house (3 + 2)
		else:
			return 3  # Three-of-a-kind only
	
	# Two pair (2 + 2)
	if highest_freq == 2 and second_freq == 2:
		return 6  # Two pair
	
	# Single pair
	if highest_freq == 2:
		return 3  # One pair
	
	# No pairs
	return 0

func _on_about_to_score(_section: Scorecard.Section, _category: String, dice_values: Array[int]) -> void:
	# Analyze the dice values for pair patterns
	var bonus = _analyze_pair_patterns(dice_values)
	last_bonus = bonus
	
	if bonus > 0:
		# Register the additive
		ScoreModifierManager.register_additive(modifier_source_name, bonus)
		print("[PairParadisePowerUp] Registered additive +%d for pair pattern" % bonus)
	else:
		# Ensure no additive is registered for no-pair hands
		if ScoreModifierManager.has_additive(modifier_source_name):
			ScoreModifierManager.unregister_additive(modifier_source_name)

func _on_score_assigned(_section: Scorecard.Section, _category: String, _score: int) -> void:
	# Track bonus for description
	if last_bonus > 0:
		total_bonus_applied += last_bonus
		times_triggered += 1
	
	# Clean up additive after scoring
	if ScoreModifierManager.has_additive(modifier_source_name):
		ScoreModifierManager.unregister_additive(modifier_source_name)
		print("[PairParadisePowerUp] Cleaned up additive after scoring")
	
	# Update description
	emit_signal("description_updated", id, get_current_description())
	
	if is_inside_tree():
		_update_power_up_icons()

func get_current_description() -> String:
	var base_desc = "Pair bonuses: +3 (pair/3oak), +6 (2pair/4oak), +9 (FH/Yahtzee)"
	
	if total_bonus_applied > 0:
		base_desc += "\nTotal bonus: +%d (%d times)" % [total_bonus_applied, times_triggered]
	
	return base_desc

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("pair_paradise")
		if icon:
			icon.update_hover_description()
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

func remove(target) -> void:
	print("=== Removing PairParadisePowerUp ===")
	
	# Unregister from ScoreModifierManager
	if ScoreModifierManager.has_additive(modifier_source_name):
		ScoreModifierManager.unregister_additive(modifier_source_name)
	
	if score_card_ui_ref:
		if score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
			print("[PairParadisePowerUp] Disconnected from about_to_score signal")
	
	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		scorecard = scorecard_ref
	
	if scorecard:
		if scorecard.is_connected("score_assigned", _on_score_assigned):
			scorecard.score_assigned.disconnect(_on_score_assigned)
			print("[PairParadisePowerUp] Disconnected from score_assigned signal")
	
	scorecard_ref = null
	score_card_ui_ref = null

func _on_tree_exiting() -> void:
	# Cleanup when PowerUp is destroyed
	if ScoreModifierManager.has_additive(modifier_source_name):
		ScoreModifierManager.unregister_additive(modifier_source_name)
	
	if score_card_ui_ref:
		if score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
	
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
