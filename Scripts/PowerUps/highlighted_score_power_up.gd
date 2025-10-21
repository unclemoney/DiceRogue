extends PowerUp
class_name HighlightedScorePowerUp

## HighlightedScorePowerUp
##
## Highlights one random unscored category on the scorecard. When the highlighted
## category is scored, it receives a 1.5x multiplier. The highlight changes to
## a new random unscored category after each score.

# References to game components
var scorecard_ref: Scorecard = null
var scorecard_ui_ref: ScoreCardUI = null

# Currently highlighted category
var highlighted_section: Scorecard.Section = Scorecard.Section.UPPER
var highlighted_category: String = ""
var highlighted_button: Button = null

# Multiplier configuration
var highlight_multiplier: float = 1.5
var modifier_source_name: String = "highlighted_score_powerup"

# Signal for dynamic description updates
signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")
	print("[HighlightedScorePowerUp] Added to 'power_ups' group")

func apply(target) -> void:
	print("=== Applying HighlightedScorePowerUp ===")
	var scorecard = target as Scorecard
	if not scorecard:
		push_error("[HighlightedScorePowerUp] Target is not a Scorecard")
		return
	
	# Store reference
	scorecard_ref = scorecard
	
	# Find the ScoreCardUI
	scorecard_ui_ref = get_tree().get_first_node_in_group("scorecard_ui")
	if not scorecard_ui_ref:
		push_error("[HighlightedScorePowerUp] Could not find ScoreCardUI")
		return
	
	# Connect to scorecard signals
	if not scorecard.is_connected("score_assigned", _on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
		print("[HighlightedScorePowerUp] Connected to score_assigned signal")
	
	# Connect to scorecard UI about_to_score signal to detect scoring attempts
	if not scorecard_ui_ref.is_connected("about_to_score", _on_about_to_score):
		scorecard_ui_ref.about_to_score.connect(_on_about_to_score)
		print("[HighlightedScorePowerUp] Connected to about_to_score signal")
	
	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	
	# Highlight the first random category
	_highlight_random_category()

func remove(target) -> void:
	print("=== Removing HighlightedScorePowerUp ===")
	
	# Clear any active highlight
	_clear_highlight()
	
	# Unregister multiplier if active
	var modifier_manager = _get_modifier_manager()
	if modifier_manager and modifier_manager.has_multiplier(modifier_source_name):
		modifier_manager.unregister_multiplier(modifier_source_name)
	
	var scorecard: Scorecard = null
	if target is Scorecard:
		scorecard = target
	elif target == self:
		scorecard = scorecard_ref
	
	if scorecard:
		# Disconnect signals
		if scorecard.is_connected("score_assigned", _on_score_assigned):
			scorecard.score_assigned.disconnect(_on_score_assigned)
	
	if scorecard_ui_ref:
		if scorecard_ui_ref.is_connected("about_to_score", _on_about_to_score):
			scorecard_ui_ref.about_to_score.disconnect(_on_about_to_score)
	
	scorecard_ref = null
	scorecard_ui_ref = null
	highlighted_button = null

func _on_about_to_score(section: Scorecard.Section, category: String, _dice_values: Array[int]) -> void:
	print("[HighlightedScorePowerUp] About to score:", category, "in section:", section)
	print("[HighlightedScorePowerUp] Currently highlighted:", highlighted_category, "in section:", highlighted_section)
	
	# Check if this is the highlighted category
	if section == highlighted_section and category == highlighted_category:
		print("[HighlightedScorePowerUp] Scoring highlighted category! Applying 1.5x multiplier")
		
		# Register the multiplier for this scoring
		var modifier_manager = _get_modifier_manager()
		if modifier_manager:
			modifier_manager.register_multiplier(modifier_source_name, highlight_multiplier)
			print("[HighlightedScorePowerUp] Registered multiplier:", highlight_multiplier)
		else:
			push_error("[HighlightedScorePowerUp] Could not find ScoreModifierManager")

func _on_score_assigned(_section: Scorecard.Section, category: String, score: int) -> void:
	print("[HighlightedScorePowerUp] Score assigned:", category, "=", score)
	
	# Clear the multiplier after scoring (only applied to one score)
	var modifier_manager = _get_modifier_manager()
	if modifier_manager and modifier_manager.has_multiplier(modifier_source_name):
		modifier_manager.unregister_multiplier(modifier_source_name)
		print("[HighlightedScorePowerUp] Cleared multiplier after scoring")
	
	# Always clear current highlight and choose a new one after ANY score is assigned
	print("[HighlightedScorePowerUp] Any category was scored, selecting new highlight")
	_clear_highlight()
	
	# Delay highlighting to allow UI to update
	call_deferred("_highlight_random_category")

func _highlight_random_category() -> void:
	if not scorecard_ref or not scorecard_ui_ref:
		print("[HighlightedScorePowerUp] Missing references, cannot highlight")
		return
	
	# Get all unscored categories
	var available_categories = _get_unscored_categories()
	
	if available_categories.is_empty():
		print("[HighlightedScorePowerUp] No unscored categories available for highlighting")
		highlighted_category = ""
		highlighted_section = Scorecard.Section.UPPER
		_update_description()
		return
	
	# Choose a random category
	var random_choice = available_categories[randi() % available_categories.size()]
	highlighted_section = random_choice.section
	highlighted_category = random_choice.category
	
	print("[HighlightedScorePowerUp] Highlighting:", highlighted_category, "in section:", highlighted_section)
	
	# Apply visual highlight to the button
	_apply_visual_highlight()
	
	# Update description
	_update_description()

func _get_unscored_categories() -> Array:
	var unscored = []
	
	if not scorecard_ref:
		return unscored
	
	# Check upper section
	for category in scorecard_ref.upper_scores.keys():
		if scorecard_ref.upper_scores[category] == null:
			unscored.append({
				"section": Scorecard.Section.UPPER,
				"category": category
			})
	
	# Check lower section
	for category in scorecard_ref.lower_scores.keys():
		if scorecard_ref.lower_scores[category] == null:
			unscored.append({
				"section": Scorecard.Section.LOWER, 
				"category": category
			})
	
	return unscored

func _apply_visual_highlight() -> void:
	if not scorecard_ui_ref or highlighted_category == "":
		return
	
	# Get the button for the highlighted category
	var button: Button = null
	
	if highlighted_section == Scorecard.Section.UPPER:
		button = scorecard_ui_ref.upper_section_buttons.get(highlighted_category)
	else:
		button = scorecard_ui_ref.lower_section_buttons.get(highlighted_category)
	
	if button:
		highlighted_button = button
		
		# Apply highlight styling - golden glow effect
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(1.0, 0.8, 0.0, 0.3)  # Golden with transparency
		style_box.border_width_left = 3
		style_box.border_width_right = 3
		style_box.border_width_top = 3
		style_box.border_width_bottom = 3
		style_box.border_color = Color(1.0, 0.8, 0.0, 0.8)  # Golden border
		style_box.corner_radius_top_left = 8
		style_box.corner_radius_top_right = 8
		style_box.corner_radius_bottom_left = 8
		style_box.corner_radius_bottom_right = 8
		
		# Apply the highlight style
		button.add_theme_stylebox_override("normal", style_box)
		button.add_theme_stylebox_override("hover", style_box)
		button.add_theme_stylebox_override("pressed", style_box)
		
		print("[HighlightedScorePowerUp] Applied golden highlight to", highlighted_category, "button")
	else:
		push_error("[HighlightedScorePowerUp] Could not find button for category:", highlighted_category)

func _clear_highlight() -> void:
	if highlighted_button:
		# Remove theme overrides to restore original styling
		highlighted_button.remove_theme_stylebox_override("normal")
		highlighted_button.remove_theme_stylebox_override("hover") 
		highlighted_button.remove_theme_stylebox_override("pressed")
		
		print("[HighlightedScorePowerUp] Cleared highlight from", highlighted_category, "button")
		highlighted_button = null

func _get_modifier_manager():
	# Try singleton first
	if Engine.has_singleton("ScoreModifierManager"):
		return ScoreModifierManager
	
	# Fallback to finding in tree
	if get_tree():
		return get_tree().get_first_node_in_group("score_modifier_manager")
	
	return null

func get_current_description() -> String:
	var base_desc = "Highlights a random unscored category for 1.5x score"
	
	if highlighted_category != "":
		var category_display = _format_category_display_name(highlighted_category)
		var section_display = "Upper" if highlighted_section == Scorecard.Section.UPPER else "Lower"
		var highlight_desc = "\nCurrently highlighted: %s (%s)" % [category_display, section_display]
		return base_desc + highlight_desc
	else:
		return base_desc + "\nNo categories available to highlight"

func _format_category_display_name(category: String) -> String:
	match category.to_lower():
		"ones": return "Ones"
		"twos": return "Twos" 
		"threes": return "Threes"
		"fours": return "Fours"
		"fives": return "Fives"
		"sixes": return "Sixes"
		"three_of_a_kind": return "Three of a Kind"
		"four_of_a_kind": return "Four of a Kind"
		"full_house": return "Full House"
		"small_straight": return "Small Straight"
		"large_straight": return "Large Straight"
		"yahtzee": return "Yahtzee"
		"chance": return "Chance"
		_: return category.capitalize()

func _update_description() -> void:
	# Update the description to show current progress
	emit_signal("description_updated", id, get_current_description())
	
	# Update any power-up icons if we're still in the tree
	if is_inside_tree():
		_update_power_up_icons()

func _update_power_up_icons() -> void:
	# Guard against calling when not in tree or tree is null
	if not is_inside_tree() or not get_tree():
		return
	
	# Find the PowerUpUI in the scene
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		# Get the icon for this power-up
		var icon = power_up_ui.get_power_up_icon("highlighted_score")
		if icon:
			# Update its description
			icon.update_hover_description()

func _on_tree_exiting() -> void:
	# Clear highlight before cleanup
	_clear_highlight()
	
	# Clear multiplier
	var modifier_manager = _get_modifier_manager()
	if modifier_manager and modifier_manager.has_multiplier(modifier_source_name):
		modifier_manager.unregister_multiplier(modifier_source_name)
	
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
	
	if scorecard_ui_ref:
		if scorecard_ui_ref.is_connected("about_to_score", _on_about_to_score):
			scorecard_ui_ref.about_to_score.disconnect(_on_about_to_score)