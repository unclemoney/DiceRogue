extends PowerUp
class_name SnakeEyesPowerUp

## SnakeEyesPowerUp
##
## Each die showing 1 grants +0.2x multiplier. If ALL dice show 1 (true snake eyes),
## grants a flat 3.0x multiplier instead. High risk, high reward.
## Legendary rarity, $600 price.

# References
var scorecard_ref: Scorecard = null
var score_card_ui_ref = null

# ScoreModifierManager source name
var modifier_source_name: String = "snake_eyes"

# Track for description
var last_ones_count: int = 0
var last_was_all_ones: bool = false
var times_triggered: int = 0
var mult_per_one: float = 0.2
var all_ones_mult: float = 3.0

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying SnakeEyesPowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[SnakeEyesPowerUp] Target is not a Scorecard")
		return
	
	scorecard_ref = scorecard
	
	# Get score_card_ui from tree
	var tree = scorecard.get_tree()
	if tree:
		var game_controller = tree.get_first_node_in_group("game_controller")
		if game_controller and game_controller.score_card_ui:
			score_card_ui_ref = game_controller.score_card_ui
	
	# Connect to about_to_score to register multiplier based on 1s
	if score_card_ui_ref:
		if not score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.connect(_on_about_to_score)
			print("[SnakeEyesPowerUp] Connected to about_to_score signal")
	
	# Connect to score_assigned to clean up multiplier
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
		print("[SnakeEyesPowerUp] Connected to score_assigned signal")
	
	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func _on_about_to_score(_section: Scorecard.Section, _category: String, _dice_values: Array[int]) -> void:
	# Get the current dice values
	var dice_values = DiceResults.values
	if dice_values.is_empty():
		return
	
	# Count 1s
	var ones_count: int = 0
	for value in dice_values:
		if value == 1:
			ones_count += 1
	
	last_ones_count = ones_count
	
	if ones_count == 0:
		last_was_all_ones = false
		print("[SnakeEyesPowerUp] No 1s — no bonus")
		return
	
	# Check if ALL dice are 1s
	var all_ones = (ones_count == dice_values.size())
	last_was_all_ones = all_ones
	
	var total_mult: float = 1.0
	if all_ones:
		total_mult = all_ones_mult
		print("[SnakeEyesPowerUp] ALL ONES! Registered %.1fx multiplier" % total_mult)
	else:
		total_mult = 1.0 + (ones_count * mult_per_one)
		print("[SnakeEyesPowerUp] %d ones — registered %.2fx multiplier" % [ones_count, total_mult])
	
	ScoreModifierManager.register_multiplier(modifier_source_name, total_mult)

func _on_score_assigned(_section: Scorecard.Section, _category: String, _score: int) -> void:
	# Track triggers
	if ScoreModifierManager.has_multiplier(modifier_source_name):
		times_triggered += 1
	
	# Clean up multiplier after scoring
	if ScoreModifierManager.has_multiplier(modifier_source_name):
		ScoreModifierManager.unregister_multiplier(modifier_source_name)
		print("[SnakeEyesPowerUp] Cleaned up multiplier after scoring")
	
	# Update description
	emit_signal("description_updated", id, get_current_description())
	
	if is_inside_tree():
		_update_power_up_icons()

func get_current_description() -> String:
	var base_desc = "Each 1 = +0.2x mult. All 1s = 3.0x!"
	if times_triggered > 0:
		base_desc += "\nTriggered: %d time(s)" % times_triggered
		if last_was_all_ones:
			base_desc += " (last: ALL ONES!)"
		elif last_ones_count > 0:
			base_desc += " (last: %d ones)" % last_ones_count
	return base_desc

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("snake_eyes")
		if icon:
			icon.update_hover_description()
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

func remove(target) -> void:
	print("=== Removing SnakeEyesPowerUp ===")
	
	# Unregister from ScoreModifierManager
	if ScoreModifierManager.has_multiplier(modifier_source_name):
		ScoreModifierManager.unregister_multiplier(modifier_source_name)
	
	if score_card_ui_ref:
		if score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
			print("[SnakeEyesPowerUp] Disconnected from about_to_score signal")
	
	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		scorecard = scorecard_ref
	
	if scorecard:
		if scorecard.is_connected("score_assigned", _on_score_assigned):
			scorecard.score_assigned.disconnect(_on_score_assigned)
			print("[SnakeEyesPowerUp] Disconnected from score_assigned signal")
	
	scorecard_ref = null
	score_card_ui_ref = null

func _on_tree_exiting() -> void:
	if ScoreModifierManager.has_multiplier(modifier_source_name):
		ScoreModifierManager.unregister_multiplier(modifier_source_name)
	
	if score_card_ui_ref:
		if score_card_ui_ref.is_connected("about_to_score", _on_about_to_score):
			score_card_ui_ref.about_to_score.disconnect(_on_about_to_score)
	
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
