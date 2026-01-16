extends PowerUp
class_name MoneyBagsPowerUp

## MoneyBagsPowerUp
##
## Uses the player's current money to calculate a score multiplier.
## Multiplier = (current_money / 100) + 1.0
## Example: $550 = 1.55x multiplier, Full House (25) becomes 39 points.
## Epic rarity, R rating.

# References
var scorecard_ref: Scorecard = null
var score_card_ui_ref: Node = null
var current_multiplier: float = 1.0

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying MoneyBagsPowerUp ===")
	
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[MoneyBagsPowerUp] Target is not a Scorecard")
		return
	
	scorecard_ref = scorecard
	
	# Get score_card_ui from GameController (most reliable method)
	var game_controller = scorecard.get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.score_card_ui:
		score_card_ui_ref = game_controller.score_card_ui
		
		# Connect to about_to_score signal
		if not score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.connect(_on_about_to_score)
			print("[MoneyBagsPowerUp] Connected to about_to_score signal")
	else:
		push_error("[MoneyBagsPowerUp] Could not find ScoreCardUI via GameController")
		return
	
	# Connect to score_assigned for cleanup after each score
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
		print("[MoneyBagsPowerUp] Connected to score_assigned signal")
	
	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	
	# Update description with current multiplier
	_update_multiplier_display()

func _on_about_to_score(_section: Scorecard.Section, _category: String, _dice_values: Array[int]) -> void:
	# Calculate multiplier based on current money
	var current_money = PlayerEconomy.get_money()
	current_multiplier = (float(current_money) / 100.0) + 1.0
	
	# Register the multiplier
	ScoreModifierManager.register_multiplier("money_bags", current_multiplier)
	print("[MoneyBagsPowerUp] Registered multiplier: %.2fx (based on $%d)" % [current_multiplier, current_money])

func _on_score_assigned(_section: Scorecard.Section, _category: String, _score: int) -> void:
	# Unregister the multiplier after scoring completes
	if ScoreModifierManager.has_multiplier("money_bags"):
		ScoreModifierManager.unregister_multiplier("money_bags")
		print("[MoneyBagsPowerUp] Unregistered multiplier after scoring")
	
	# Update description
	_update_multiplier_display()

func _update_multiplier_display() -> void:
	var current_money = PlayerEconomy.get_money()
	current_multiplier = (float(current_money) / 100.0) + 1.0
	
	emit_signal("description_updated", id, get_current_description())
	
	if is_inside_tree():
		_update_power_up_icons()

func get_current_description() -> String:
	var current_money = PlayerEconomy.get_money()
	var mult = (float(current_money) / 100.0) + 1.0
	
	var base_desc = "Score multiplier = ($Money / 100) + 1"
	var progress_desc = "\nCurrent: $%d → %.2fx multiplier" % [current_money, mult]
	
	return base_desc + progress_desc

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("money_bags")
		if icon:
			icon.update_hover_description()
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

func remove(target) -> void:
	print("=== Removing MoneyBagsPowerUp ===")
	
	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif scorecard_ref:
		scorecard = scorecard_ref
	
	if scorecard:
		if scorecard.is_connected("score_assigned", _on_score_assigned):
			scorecard.score_assigned.disconnect(_on_score_assigned)
	
	if score_card_ui_ref:
		if score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
	
	# Unregister multiplier if still active
	if ScoreModifierManager.has_multiplier("money_bags"):
		ScoreModifierManager.unregister_multiplier("money_bags")
	
	scorecard_ref = null
	score_card_ui_ref = null

func _on_tree_exiting() -> void:
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
	
	if score_card_ui_ref:
		if score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
	
	if ScoreModifierManager.has_multiplier("money_bags"):
		ScoreModifierManager.unregister_multiplier("money_bags")
