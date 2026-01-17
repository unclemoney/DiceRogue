extends Debuff
class_name ReducedLevelsDebuff

## ReducedLevelsDebuff
##
## Reduces the scorecard category level by 1 BEFORE each scoring action.
## Example: If Full House is at level 4, when scoring it decrements to level 3, then scores.
## This is a permanent effect - levels are NOT restored when the debuff is removed.

var scorecard: Node
var score_card_ui: Node
var game_controller: Node

## apply(_target)
##
## Connects to about_to_score signal to decrement level before each score.
func apply(_target) -> void:
	print("[ReducedLevelsDebuff] Applied - Will reduce category level by 1 before each score")
	self.target = _target
	
	# Find Scorecard
	scorecard = get_tree().get_first_node_in_group("scorecard")
	if not scorecard:
		push_error("[ReducedLevelsDebuff] Failed to find Scorecard")
		return
	
	# Find GameController to access ScoreCardUI
	game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.score_card_ui:
		score_card_ui = game_controller.score_card_ui
		if score_card_ui.has_signal("about_to_score"):
			if not score_card_ui.is_connected("about_to_score", _on_about_to_score):
				score_card_ui.about_to_score.connect(_on_about_to_score)
				print("[ReducedLevelsDebuff] Connected to about_to_score signal")
	else:
		push_error("[ReducedLevelsDebuff] Failed to find ScoreCardUI")

## remove()
##
## Disconnects from signals - levels remain reduced (permanent).
func remove() -> void:
	print("[ReducedLevelsDebuff] Removed - Levels remain at current values (permanent)")
	
	if score_card_ui and score_card_ui.has_signal("about_to_score"):
		if score_card_ui.is_connected("about_to_score", _on_about_to_score):
			score_card_ui.about_to_score.disconnect(_on_about_to_score)
			print("[ReducedLevelsDebuff] Disconnected from about_to_score")

## _on_about_to_score(section, category, _dice_values)
##
## Called just before a category is scored.
## Reduces the category level by 1 (minimum 1) before scoring happens.
func _on_about_to_score(section, category: String, _dice_values) -> void:
	if not scorecard:
		return
	
	var current_level: int = 1
	var new_level: int = 1
	var levels_dict: Dictionary
	
	# Get the appropriate levels dictionary based on section
	match section:
		scorecard.Section.UPPER:
			if "upper_levels" in scorecard and scorecard.upper_levels.has(category):
				levels_dict = scorecard.upper_levels
				current_level = levels_dict[category]
		scorecard.Section.LOWER:
			if "lower_levels" in scorecard and scorecard.lower_levels.has(category):
				levels_dict = scorecard.lower_levels
				current_level = levels_dict[category]
	
	# Reduce level by 1, minimum 1
	new_level = maxi(current_level - 1, 1)
	
	if new_level != current_level:
		levels_dict[category] = new_level
		print("[ReducedLevelsDebuff] Reduced %s from level %d to %d before scoring" % [category, current_level, new_level])
		
		# Emit signal for UI update
		if scorecard.has_signal("category_upgraded"):
			scorecard.emit_signal("category_upgraded", section, category, new_level)
	else:
		print("[ReducedLevelsDebuff] %s already at minimum level 1" % category)

