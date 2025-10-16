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
	
	# Get the scorecard to monitor scoring events
	var game_controller = get_tree().get_first_node_in_group("game_controllers")
	if not game_controller:
		push_error("[GreenMonsterPU] Could not find GameController")
		return

	scorecard_ref = game_controller.scorecard
	if not scorecard_ref:
		push_error("[GreenMonsterPU] Could not find Scorecard")
		return

	# Connect to the scorecard's score_assigned signal to intercept scoring
	if not scorecard_ref.is_connected("score_assigned", _on_score_assigned):
		scorecard_ref.score_assigned.connect(_on_score_assigned)
		print("[GreenMonsterPU] Connected to score_assigned signal")

	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func remove(_target) -> void:
	print("=== Removing GreenMonsterPU ===")
	
	if scorecard_ref:
		# Disconnect signals
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
			print("[GreenMonsterPU] Disconnected from score_assigned signal")

	scorecard_ref = null

func _on_score_assigned(category: String, dice_array: Array, base_score: int, final_score: int) -> void:
	print("[GreenMonsterPU] Score assigned to %s: %d -> %d" % [category, base_score, final_score])

	var green_dice_this_round = _count_green_dice_from_array(dice_array)

	if green_dice_this_round > 0:
		total_green_dice_scored += green_dice_this_round

		print("[GreenMonsterPU] Green dice this round: %d, Total green dice: %d" % [green_dice_this_round, total_green_dice_scored])

		# Calculate green money from the dice array
		var green_money = _calculate_green_money_from_array(dice_array)

		if green_money > 0:
			# Calculate and apply multiplier to green money
			var current_multiplier = 1.0 + (total_green_dice_scored * multiplier_per_green_dice)
			var original_money = green_money
			var multiplied_money = int(round(green_money * current_multiplier))
			var bonus_money = multiplied_money - original_money

			print("[GreenMonsterPU] Multiplier: %.2fx, Original: $%d, Multiplied: $%d, Bonus: $%d" % [current_multiplier, original_money, multiplied_money, bonus_money])

			# Add the bonus money to player economy
			if bonus_money > 0:
				PlayerEconomy.add_money(bonus_money)
				print("[GreenMonsterPU] Added bonus money: $%d" % bonus_money)

			# Update description
			emit_signal("description_updated", id, get_current_description())
			_update_power_up_icons()

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

func _on_tree_exiting() -> void:
	# Cleanup when PowerUp is destroyed
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
