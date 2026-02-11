extends PowerUp
class_name ExtraRainbowPowerUp

## ExtraRainbowPowerUp
##
## Rare PowerUp that grants +10 additive score for each colored die scored.
## Colored dice include: Green, Red, Purple, Blue, Yellow (any non-NONE color).
## Example: 2 green dice scored = +20 additive, 5 colored dice scored = +50 additive.
## Uses ScoreModifierManager for logbook visibility.
## Price: $300, Rarity: Rare, Rating: PG-13

const BONUS_PER_COLOR: int = 10

var scorecard_ref: Scorecard = null
var score_card_ui_ref = null
var total_bonus_awarded: int = 0

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying ExtraRainbowPowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[ExtraRainbowPowerUp] Target is not a Scorecard")
		return

	scorecard_ref = scorecard

	# Get score_card_ui from GameController
	var game_controller = scorecard.get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.score_card_ui:
		score_card_ui_ref = game_controller.score_card_ui
		if not score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.connect(_on_about_to_score)
	else:
		push_error("[ExtraRainbowPowerUp] Could not find ScoreCardUI via GameController")

	# Connect to score_assigned for cleanup after scoring
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)

	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func remove(_target) -> void:
	print("=== Removing ExtraRainbowPowerUp ===")
	if score_card_ui_ref and score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
		score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
	if scorecard_ref and scorecard_ref.is_connected("score_assigned", _on_score_assigned):
		scorecard_ref.score_assigned.disconnect(_on_score_assigned)
	if ScoreModifierManager.has_additive("extra_rainbow"):
		ScoreModifierManager.unregister_additive("extra_rainbow")
	score_card_ui_ref = null
	scorecard_ref = null

func _on_about_to_score(_section: Scorecard.Section, _category: String, _dice_values: Array[int]) -> void:
	## _on_about_to_score()
	##
	## Counts colored dice in the current hand and registers an additive bonus.
	## Each colored die (non-NONE) adds +10 to the score.
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if not game_controller or not game_controller.dice_hand:
		return

	var colored_count: int = 0
	for die in game_controller.dice_hand.get_all_dice():
		var die_color = die.get_color()
		if die_color != DiceColor.Type.NONE:
			colored_count += 1

	if colored_count > 0:
		var bonus = colored_count * BONUS_PER_COLOR
		ScoreModifierManager.register_additive("extra_rainbow", bonus)
		total_bonus_awarded += bonus
		print("[ExtraRainbowPowerUp] %d colored dice detected - +%d additive bonus!" % [colored_count, bonus])
	else:
		# No colored dice, ensure no additive registered
		if ScoreModifierManager.has_additive("extra_rainbow"):
			ScoreModifierManager.unregister_additive("extra_rainbow")

func _on_score_assigned(_section: Scorecard.Section, _category: String, _score: int) -> void:
	## _on_score_assigned()
	##
	## Clean up additive modifier after scoring completes.
	if ScoreModifierManager.has_additive("extra_rainbow"):
		ScoreModifierManager.unregister_additive("extra_rainbow")
	emit_signal("description_updated", id, get_current_description())
	_update_power_up_icons()

func get_current_description() -> String:
	return "+%d per colored die scored\nTotal bonus awarded: +%d" % [BONUS_PER_COLOR, total_bonus_awarded]

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("extra_rainbow")
		if icon:
			icon.update_hover_description()

func _on_tree_exiting() -> void:
	if score_card_ui_ref and score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
		score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
	if scorecard_ref and scorecard_ref.is_connected("score_assigned", _on_score_assigned):
		scorecard_ref.score_assigned.disconnect(_on_score_assigned)
	if ScoreModifierManager.has_additive("extra_rainbow"):
		ScoreModifierManager.unregister_additive("extra_rainbow")
