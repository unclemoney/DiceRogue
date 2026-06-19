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
var _trigger_feedback_pending: bool = false

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
	_trigger_feedback_pending = false

func _on_about_to_score(section: Scorecard.Section, category: String, _dice_values: Array[int]) -> void:
	print("[HighlightedScorePowerUp] About to score:", category, "in section:", section)
	print("[HighlightedScorePowerUp] Currently highlighted:", highlighted_category, "in section:", highlighted_section)
	
	# Check if this is the highlighted category
	if section == highlighted_section and category == highlighted_category:
		print("[HighlightedScorePowerUp] Scoring highlighted category! Applying 1.5x multiplier")
		_trigger_feedback_pending = true
		
		# Register the multiplier for this scoring
		var modifier_manager = _get_modifier_manager()
		if modifier_manager:
			modifier_manager.register_multiplier(modifier_source_name, highlight_multiplier)
			print("[HighlightedScorePowerUp] Registered multiplier:", highlight_multiplier)
		else:
			push_error("[HighlightedScorePowerUp] Could not find ScoreModifierManager")

func _on_score_assigned(section: Scorecard.Section, category: String, score: int) -> void:
	print("[HighlightedScorePowerUp] Score assigned:", category, "=", score)
	var scored_highlighted_category = _trigger_feedback_pending and section == highlighted_section and category == highlighted_category
	_trigger_feedback_pending = false
	
	# Clear the multiplier after scoring (only applied to one score)
	var modifier_manager = _get_modifier_manager()
	if modifier_manager and modifier_manager.has_multiplier(modifier_source_name):
		modifier_manager.unregister_multiplier(modifier_source_name)
		print("[HighlightedScorePowerUp] Cleared multiplier after scoring")

	if scored_highlighted_category and scorecard_ui_ref:
		scorecard_ui_ref.play_power_up_highlight_trigger(section, category)
		if is_inside_tree() and get_tree():
			get_tree().create_timer(0.42).timeout.connect(_advance_highlight_after_score)
		else:
			_advance_highlight_after_score()
		return
	
	# Always clear current highlight and choose a new one after ANY score is assigned
	print("[HighlightedScorePowerUp] Any category was scored, selecting new highlight")
	_advance_highlight_after_score()

func _clear_all_highlights() -> void:
	if not scorecard_ui_ref:
		return
	scorecard_ui_ref.clear_power_up_highlight()

func _highlight_random_category() -> void:
	if not scorecard_ref or not scorecard_ui_ref:
		print("[HighlightedScorePowerUp] Missing references, cannot highlight")
		return
	
	# Guard: clear any stale highlights from all buttons before selecting a new one
	_clear_all_highlights()
	
	# Get all unscored categories
	var available_categories = _get_unscored_categories()
	
	if available_categories.is_empty():
		print("[HighlightedScorePowerUp] No unscored categories available for highlighting")
		highlighted_category = ""
		highlighted_section = Scorecard.Section.UPPER
		_update_description()
		return
	
	# Choose a random category
	var random_choice = available_categories[GameRNG.random_index(available_categories)]
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
	if scorecard_ui_ref.set_power_up_highlight(highlighted_section, highlighted_category):
		print("[HighlightedScorePowerUp] Applied shader highlight to", highlighted_category, "button")
	else:
		push_error("[HighlightedScorePowerUp] Could not find button for category:", highlighted_category)

func _clear_highlight() -> void:
	if scorecard_ui_ref:
		scorecard_ui_ref.clear_power_up_highlight()
		print("[HighlightedScorePowerUp] Cleared highlight from", highlighted_category, "button")


func _advance_highlight_after_score() -> void:
	print("[HighlightedScorePowerUp] Any category was scored, selecting new highlight")
	_clear_highlight()
	call_deferred("_highlight_random_category")

func _get_modifier_manager():
	# ScoreModifierManager is a registered autoload — use direct reference
	return ScoreModifierManager

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
