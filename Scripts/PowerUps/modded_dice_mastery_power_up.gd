extends PowerUp
class_name ModdedDiceMasteryPowerUp

## ModdedDiceMasteryPowerUp
##
## Rare PowerUp that grants +10 additive bonus when dice with mods are used in scoring.
## Synergizes with the mod system - the more modded dice you have, the more valuable
## this becomes. Registers conditionally only when modded dice are present.
## Price: $300, Rarity: Rare

const BONUS_PER_MODDED_DIE: int = 10

var scorecard_ref: Scorecard = null
var score_card_ui_ref = null
var total_bonus_applied: int = 0

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying ModdedDiceMasteryPowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[ModdedDiceMasteryPowerUp] Target is not a Scorecard")
		return
	
	scorecard_ref = scorecard
	
	# Get score_card_ui from GameController
	var game_controller = scorecard.get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.score_card_ui:
		score_card_ui_ref = game_controller.score_card_ui
		if not score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.connect(_on_about_to_score)
	else:
		push_error("[ModdedDiceMasteryPowerUp] Could not find ScoreCardUI via GameController")
	
	# Connect to score_assigned for cleanup
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
	
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func remove(_target) -> void:
	print("=== Removing ModdedDiceMasteryPowerUp ===")
	if score_card_ui_ref and score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
		score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
	if scorecard_ref and scorecard_ref.is_connected("score_assigned", _on_score_assigned):
		scorecard_ref.score_assigned.disconnect(_on_score_assigned)
	if ScoreModifierManager.has_additive("modded_dice_mastery"):
		ScoreModifierManager.unregister_additive("modded_dice_mastery")
	score_card_ui_ref = null
	scorecard_ref = null

func _on_about_to_score(_section: Scorecard.Section, _category: String, _dice_values: Array[int]) -> void:
	# Count modded dice and register additive bonus
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if not game_controller or not game_controller.dice_hand:
		return
	
	var modded_count: int = 0
	for die in game_controller.dice_hand.get_all_dice():
		if die.active_mods.size() > 0:
			modded_count += 1
	
	if modded_count > 0:
		var bonus = modded_count * BONUS_PER_MODDED_DIE
		ScoreModifierManager.register_additive("modded_dice_mastery", bonus)
		total_bonus_applied += bonus
		print("[ModdedDiceMasteryPowerUp] Registered +%d additive (%d modded dice)" % [bonus, modded_count])
	else:
		# No modded dice, ensure no bonus applied
		if ScoreModifierManager.has_additive("modded_dice_mastery"):
			ScoreModifierManager.unregister_additive("modded_dice_mastery")

func _on_score_assigned(_section: Scorecard.Section, _category: String, _score: int) -> void:
	# Clean up after scoring completes
	if ScoreModifierManager.has_additive("modded_dice_mastery"):
		ScoreModifierManager.unregister_additive("modded_dice_mastery")
	emit_signal("description_updated", id, get_current_description())
	_update_power_up_icons()

func get_current_description() -> String:
	return "+%d points per modded die when scoring.\nTotal bonus applied: +%d" % [BONUS_PER_MODDED_DIE, total_bonus_applied]

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("modded_dice_mastery")
		if icon:
			icon.update_hover_description()

func _on_tree_exiting() -> void:
	if score_card_ui_ref and score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
		score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
	if scorecard_ref and scorecard_ref.is_connected("score_assigned", _on_score_assigned):
		scorecard_ref.score_assigned.disconnect(_on_score_assigned)
	if ScoreModifierManager.has_additive("modded_dice_mastery"):
		ScoreModifierManager.unregister_additive("modded_dice_mastery")
