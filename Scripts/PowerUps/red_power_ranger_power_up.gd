extends PowerUp
class_name RedPowerRangerPowerUp

## RedPowerRangerPowerUp
##
## Increases the additive score for each red dice scored.
## Example: First hand with 1 red five scores +5 additive.
## After several hands, total additive becomes cumulative for all future scores.
## Additive is applied when scoring manually or through Next Turn.

# Reference to the scorecard to listen for score assignments
var scorecard_ref: Scorecard = null
var total_red_dice_scored: int = 0
var current_additive: int = 0

# Signal for dynamic description updates
signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[RedPowerRangerPowerUp] Target is not a Scorecard")
		return
	
	# Store a reference to the scorecard
	scorecard_ref = scorecard
	
	# Connect to score assignment signal to track red dice
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
	
	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func _on_score_assigned(_section: int, _category: String, _score: int) -> void:
	# Get current dice from DiceResults to count red dice
	var red_dice_count = _count_red_dice_in_current_hand()
	
	if red_dice_count > 0:
		# Each red die adds its value to the total additive
		var red_dice_value_sum = _get_red_dice_value_sum()
		total_red_dice_scored += red_dice_count
		current_additive += red_dice_value_sum
		
		print("[RedPowerRangerPowerUp] Scored %d red dice with total value %d. New additive: +%d" % [red_dice_count, red_dice_value_sum, current_additive])
		
		# Update ScoreModifierManager with our new additive
		ScoreModifierManager.register_additive("red_power_ranger", current_additive)
		
		# Update the description to show current progress
		emit_signal("description_updated", id, get_current_description())
		
		# Update any power-up icons if we're still in the tree
		if is_inside_tree():
			_update_power_up_icons()
		
		# Update the notification UI
		_update_notification_ui()

func _count_red_dice_in_current_hand() -> int:
	var red_count = 0
	if DiceResults and DiceResults.dice_refs:
		for dice in DiceResults.dice_refs:
			if dice is Dice and dice.get_color() == DiceColor.Type.RED:
				red_count += 1
	return red_count

func _get_red_dice_value_sum() -> int:
	var value_sum = 0
	if DiceResults and DiceResults.dice_refs:
		for dice in DiceResults.dice_refs:
			if dice is Dice and dice.get_color() == DiceColor.Type.RED:
				value_sum += dice.value
	return value_sum

func get_current_description() -> String:
	var base_desc = "Gain +additive score for each red dice scored"
	
	if total_red_dice_scored > 0:
		var progress_desc = "\nRed dice scored: %d\nCurrent additive: +%d" % [total_red_dice_scored, current_additive]
		return base_desc + progress_desc
	
	return base_desc

func _update_power_up_icons() -> void:
	# Guard against calling when not in tree or tree is null
	if not is_inside_tree() or not get_tree():
		return
	
	# Find the PowerUpUI in the scene
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		# Get the icon for this power-up
		var icon = power_up_ui.get_power_up_icon("red_power_ranger")
		if icon:
			# Update its description
			icon.update_hover_description()
			
			# If it's currently being hovered, make the label visible
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

func _update_notification_ui() -> void:
	# Update the turn tracker UI to show current additive
	if not is_inside_tree() or not get_tree():
		return
	
	var turn_tracker_ui = get_tree().get_first_node_in_group("turn_tracker_ui")
	if turn_tracker_ui and turn_tracker_ui.has_method("update_additive_display"):
		turn_tracker_ui.update_additive_display(current_additive)
	else:
		# Create a simple notification label if no existing UI
		var game_ui = get_tree().get_first_node_in_group("game_ui")
		if game_ui:
			_create_additive_notification(game_ui)

func _create_additive_notification(parent_node: Node) -> void:
	# Find or create a notification label for the additive score
	var additive_label = parent_node.get_node_or_null("RedRangerAdditiveLabel")
	if not additive_label:
		additive_label = Label.new()
		additive_label.name = "RedRangerAdditiveLabel"
		additive_label.add_theme_color_override("font_color", Color.RED)
		additive_label.position = Vector2(10, 60)  # Position near other UI elements
		parent_node.add_child(additive_label)
	
	if current_additive > 0:
		additive_label.text = "Red Ranger: +%d" % current_additive
		additive_label.visible = true
	else:
		additive_label.visible = false

func _on_tree_exiting() -> void:
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)

func remove(target) -> void:
	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		scorecard = scorecard_ref
	
	if scorecard:
		if scorecard.is_connected("score_assigned", _on_score_assigned):
			scorecard.score_assigned.disconnect(_on_score_assigned)
	
	# Remove from ScoreModifierManager
	ScoreModifierManager.unregister_additive("red_power_ranger")
	
	# Clean up notification UI
	if is_inside_tree() and get_tree():
		var game_ui = get_tree().get_first_node_in_group("game_ui")
		if game_ui:
			var additive_label = game_ui.get_node_or_null("RedRangerAdditiveLabel")
			if additive_label:
				additive_label.queue_free()
	
	scorecard_ref = null
