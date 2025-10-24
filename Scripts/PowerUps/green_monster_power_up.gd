extends PowerUp
class_name GreenMonsterPU

## GreenMonsterPU
##
## For every green dice scored in the game, adds a +0.05 multiplier to green money.
## Example: 5 green dice scored = 1.25x multiplier
## Green dice value of 4 would normally give +$4, with this PowerUp gives +$5 (rounded)

# Reference to scorecard to listen for scoring events
var scorecard_ref: Node = null
var total_green_dice_scored: int = 0
var multiplier_per_green_dice: float = 0.05

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")
	print("[GreenMonsterPU] Added to 'power_ups' group")

func apply(_target) -> void:
	print("=== Applying GreenMonsterPU ===")
	
	# Get the scorecard UI to monitor scoring events
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if not game_controller:
		push_error("[GreenMonsterPU] Could not find GameController")
		return

	# Connect to score_card_ui's about_to_score signal to register multiplier BEFORE scoring
	var score_card_ui = game_controller.score_card_ui
	if not score_card_ui:
		push_error("[GreenMonsterPU] Could not find ScoreCardUI")
		return

	# Connect to the about_to_score signal to register multiplier before calculation
	if not score_card_ui.is_connected("about_to_score", _on_about_to_score):
		score_card_ui.about_to_score.connect(_on_about_to_score)
		print("[GreenMonsterPU] Connected to about_to_score signal")

	# Also connect to score_assigned to track green dice after scoring
	scorecard_ref = game_controller.scorecard
	if not scorecard_ref:
		push_error("[GreenMonsterPU] Could not find Scorecard")
		return

	# Connect to the scorecard's score_assigned signal to track green dice
	if not scorecard_ref.is_connected("score_assigned", _on_score_assigned):
		scorecard_ref.score_assigned.connect(_on_score_assigned)
		print("[GreenMonsterPU] Connected to score_assigned signal for tracking")

	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

	# Register initial multiplier (1.0) to ensure we appear in logbook from start
	ScoreModifierManager.register_multiplier("green_monster", 1.0)
	print("[GreenMonsterPU] Registered initial 1.0x multiplier")

func remove(_target) -> void:
	print("=== Removing GreenMonsterPU ===")
	
	# Unregister multiplier from ScoreModifierManager
	if ScoreModifierManager.has_multiplier("green_monster"):
		ScoreModifierManager.unregister_multiplier("green_monster")
		print("[GreenMonsterPU] Unregistered multiplier from ScoreModifierManager")
	
	if scorecard_ref:
		# Disconnect signals
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
			print("[GreenMonsterPU] Disconnected from score_assigned signal")

	scorecard_ref = null

func _on_tree_exiting() -> void:
	# Cleanup when PowerUp is destroyed
	if ScoreModifierManager.has_multiplier("green_monster"):
		ScoreModifierManager.unregister_multiplier("green_monster")
		print("[GreenMonsterPU] Cleaned up multiplier on tree exit")
	
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
			print("[GreenMonsterPU] Disconnected signals on tree exit")

## _on_about_to_score()
##
## Pre-scoring phase: Register multiplier based on accumulated green dice
func _on_about_to_score(_section: Scorecard.Section, category: String, _dice_values: Array[int]) -> void:
	print("[GreenMonsterPU] About to score %s - checking for green dice multiplier" % category)
	
	# Always register current multiplier (even if 1.0) to ensure we appear in logbook
	var current_multiplier = 1.0 + (total_green_dice_scored * multiplier_per_green_dice)
	print("[GreenMonsterPU] Registering money multiplier: %.2f (based on %d green dice)" % [current_multiplier, total_green_dice_scored])
	ScoreModifierManager.register_multiplier("green_monster", current_multiplier)

func _on_score_assigned(_section: int, category: String, score: int) -> void:
	print("[GreenMonsterPU] Score assigned to %s: %d - tracking green dice" % [category, score])

	# Only track green dice here - multiplier was already applied during scoring
	if not DiceResults or not DiceResults.dice_refs:
		print("[GreenMonsterPU] No dice data available for tracking")
		return
	
	var dice_array = DiceResults.dice_refs
	var green_dice_this_round = _count_green_dice_from_array(dice_array)

	if green_dice_this_round > 0:
		total_green_dice_scored += green_dice_this_round
		print("[GreenMonsterPU] Green dice this round: %d, Total green dice: %d" % [green_dice_this_round, total_green_dice_scored])
		
		# Update persistent multiplier to reflect new total
		var new_multiplier = 1.0 + (total_green_dice_scored * multiplier_per_green_dice)
		ScoreModifierManager.register_multiplier("green_monster", new_multiplier)
		print("[GreenMonsterPU] Updated persistent multiplier to: %.2f" % new_multiplier)
		
		# Update description for next round
		emit_signal("description_updated", id, get_current_description())
		_update_power_up_icons()

	# Note: We keep the multiplier registered for future scoring events

func _count_green_dice_from_array(dice_array: Array) -> int:
	var green_count = 0
	const DiceColorClass = preload("res://Scripts/Core/dice_color.gd")

	for dice in dice_array:
		if dice and dice.has_method("get_color"):
			var dice_color = dice.get_color()
			if dice_color == DiceColorClass.Type.GREEN:
				green_count += 1

	return green_count

func _calculate_green_money_from_array(dice_array: Array) -> int:
	var green_money = 0
	const DiceColorClass = preload("res://Scripts/Core/dice_color.gd")

	for dice in dice_array:
		if dice and dice.has_method("get_color") and dice.has_method("get_value"):
			var dice_color = dice.get_color()
			if dice_color == DiceColorClass.Type.GREEN:
				green_money += dice.value

	return green_money

func get_current_description() -> String:
	var base_desc = "+0.05x green money multiplier per green dice scored"

	if total_green_dice_scored > 0:
		var current_multiplier = 1.0 + (total_green_dice_scored * multiplier_per_green_dice)
		var progress_desc = "\nGreen dice scored: %d (%.2fx multiplier)" % [total_green_dice_scored, current_multiplier]
		return base_desc + progress_desc

	return base_desc

func _update_power_up_icons() -> void:
	# Update UI icons if description changes
	if not is_inside_tree() or not get_tree():
		return

	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("green_monster")
		if icon:
			icon.update_hover_description()
			
			# If it's currently being hovered, make the label visible
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true
