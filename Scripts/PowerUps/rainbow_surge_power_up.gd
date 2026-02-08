extends PowerUp
class_name RainbowSurgePowerUp

## RainbowSurgePowerUp
##
## Legendary PowerUp that multiplies final score by 2.0x when 4+ different colored
## dice are present in a roll (Green, Red, Purple, Blue).
## Encourages color diversity in dice collection.
## Price: $650, Rarity: Legendary

const COLOR_THRESHOLD: int = 4  # Need 4 different colors
const SCORE_MULTIPLIER: float = 2.0

var scorecard_ref: Scorecard = null
var score_card_ui_ref = null
var times_triggered: int = 0

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying RainbowSurgePowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[RainbowSurgePowerUp] Target is not a Scorecard")
		return
	
	scorecard_ref = scorecard
	
	# Get score_card_ui from GameController
	var game_controller = scorecard.get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.score_card_ui:
		score_card_ui_ref = game_controller.score_card_ui
		if not score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.connect(_on_about_to_score)
	else:
		push_error("[RainbowSurgePowerUp] Could not find ScoreCardUI via GameController")
	
	# Connect to score_assigned for cleanup
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
	
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func remove(_target) -> void:
	print("=== Removing RainbowSurgePowerUp ===")
	if score_card_ui_ref and score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
		score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
	if scorecard_ref and scorecard_ref.is_connected("score_assigned", _on_score_assigned):
		scorecard_ref.score_assigned.disconnect(_on_score_assigned)
	if ScoreModifierManager.has_multiplier("rainbow_surge"):
		ScoreModifierManager.unregister_multiplier("rainbow_surge")
	score_card_ui_ref = null
	scorecard_ref = null

func _on_about_to_score(_section: Scorecard.Section, _category: String, _dice_values: Array[int]) -> void:
	# Check for 4+ unique dice colors
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if not game_controller or not game_controller.dice_hand:
		return
	
	var colors_present: Dictionary = {}
	for die in game_controller.dice_hand.get_all_dice():
		var die_color = die.get_color()
		if die_color != DiceColor.Type.NONE:
			colors_present[die_color] = true
	
	var unique_colors = colors_present.size()
	
	if unique_colors >= COLOR_THRESHOLD:
		ScoreModifierManager.register_multiplier("rainbow_surge", SCORE_MULTIPLIER)
		times_triggered += 1
		print("[RainbowSurgePowerUp] RAINBOW SURGE! %d unique colors detected - %.1fx multiplier!" % [unique_colors, SCORE_MULTIPLIER])
	else:
		# Not enough colors, ensure no multiplier
		if ScoreModifierManager.has_multiplier("rainbow_surge"):
			ScoreModifierManager.unregister_multiplier("rainbow_surge")

func _on_score_assigned(_section: Scorecard.Section, _category: String, _score: int) -> void:
	# Clean up multiplier after scoring
	if ScoreModifierManager.has_multiplier("rainbow_surge"):
		ScoreModifierManager.unregister_multiplier("rainbow_surge")
	emit_signal("description_updated", id, get_current_description())
	_update_power_up_icons()

func get_current_description() -> String:
	return "%.1fx multiplier when 4+ different dice colors are present!\nTimes triggered: %d" % [SCORE_MULTIPLIER, times_triggered]

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("rainbow_surge")
		if icon:
			icon.update_hover_description()

func _on_tree_exiting() -> void:
	if score_card_ui_ref and score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
		score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
	if scorecard_ref and scorecard_ref.is_connected("score_assigned", _on_score_assigned):
		scorecard_ref.score_assigned.disconnect(_on_score_assigned)
	if ScoreModifierManager.has_multiplier("rainbow_surge"):
		ScoreModifierManager.unregister_multiplier("rainbow_surge")
