extends Control
class_name ScoreCardUI

var scorecard: Scorecard
var category_buttons := {}
var category_labels := {}
var category_level_labels := {}  # Level labels for score card upgrades
var turn_scored := false
var reroll_active := false
var any_score_active := false
var upper_section_buttons := {}
var lower_section_buttons := {}
var section_buttons := {} # Add this line to declare the section_buttons dictionary

signal hand_scored
signal score_rerolled(section: Scorecard.Section, category: String, score: int)
signal score_doubled(section: Scorecard.Section, category: String, new_score: int)
signal about_to_score(section: Scorecard.Section, category: String, dice_values: Array[int])
signal manual_score

@onready var best_hand_label: RichTextLabel = $BestHandPanel/MarginContainer/VBoxContainer/BestHandScore
@onready var upper_total_label: Label = $HBoxContainer/UpperVBoxContainer/UpperGridContainer/UpperSubTotal/UppersubButton
@onready var upper_bonus_label: Label = $HBoxContainer/UpperVBoxContainer/UpperGridContainer/UpperBonus/UpperBonusLabel
@onready var upper_final_total_label: Label = $HBoxContainer/UpperVBoxContainer/UpperGridContainer/UpperTotal/UpperTotalLabel
@onready var lower_total_label: Label = $HBoxContainer/LowerVBoxContainer/LowerGridContainer/LowerTotal/LowerTotalLabel
@onready var total_score_label: RichTextLabel = $TotalScorePanel/MarginContainer/RichTextTotalScore
@onready var yahtzee_bonus_label: Label = $HBoxContainer/LowerVBoxContainer/LowerGridContainer/YahtzeeBonus/YahtzeeBonusLabel
@onready var extra_info_label: RichTextLabel = get_node_or_null("LogbookPanel/MarginContainer/ExtraInfo")

# Score breakdown panel labels
@onready var additive_score_label: Label = $BestHandPanel/MarginContainer/VBoxContainer/ScoreBreakdownContainer/AdditiveContainer/AdditiveScoreLabel
@onready var multiplier_score_label: Label = $BestHandPanel/MarginContainer/VBoxContainer/ScoreBreakdownContainer/MultiplierContainer/MultiplierScoreLabel
@onready var total_score_panel: PanelContainer = $TotalScorePanel
@onready var best_hand_panel: PanelContainer = $BestHandPanel

const LOWER_CATEGORY_NODE_NAMES := {
	"three_of_a_kind": "Threeofakind",
	"four_of_a_kind": "Fourofakind",
	"full_house": "Fullhouse",
	"small_straight": "Smallstraight",
	"large_straight": "Largestraight",
	"yahtzee": "Yahtzee",
	"chance": "Chance"
}

var is_double_mode := false
var go_broke_mode := false
var current_best_hand_category := ""
var current_best_hand_section
var current_base_additive_score := 0


## _ready()
##
## Initialize ScoreCard UI: apply theme, locate labels/buttons and prepare category mappings.
func _ready():
	# Add to scorecard_ui group for PowerUps to find
	add_to_group("scorecard_ui")
	
	# Load and apply custom theme
	_apply_custom_theme()

	# Add to existing _ready function
	best_hand_label = get_node_or_null("BestHandPanel/MarginContainer/VBoxContainer/BestHandScore")
	if not best_hand_label:
		push_error("BestHandScore RichTextLabel not found!")

	# Ensure ExtraInfo label is properly configured
	extra_info_label = get_node_or_null("LogbookPanel/MarginContainer/ExtraInfo")
	if extra_info_label and extra_info_label is RichTextLabel:
		extra_info_label.bbcode_enabled = true
		print("[ScoreCardUI] ExtraInfo RichTextLabel found and BBCode enabled")
	else:
		print("[ScoreCardUI] Warning: ExtraInfo RichTextLabel not found or not properly configured")
	
	# Initialize score breakdown labels
	_reset_score_breakdown_labels()
	
	# Apply custom theme to score breakdown labels
	_apply_score_breakdown_theme()

	for key in LOWER_CATEGORY_NODE_NAMES.keys():
		var node_name = LOWER_CATEGORY_NODE_NAMES[key]
		var button_path = "HBoxContainer/LowerVBoxContainer/LowerGridContainer/%s/%sButton" % [node_name, node_name]
		var label_path = "HBoxContainer/LowerVBoxContainer/LowerGridContainer/%s/%sLabel" % [node_name, node_name]

		var button = get_node_or_null(button_path)
		var label = get_node_or_null(label_path)

		if button:
			category_buttons[key] = button
		else:
			print("❌ Button not found for:", key, "→", button_path)

		if label:
			category_labels[key] = label
		else:
			print("❌ Label not found for:", key, "→", label_path)

	


func _exit_tree() -> void:
	# Clean up stored tween to prevent warnings
	if _extra_info_tween and _extra_info_tween.is_valid():
		_extra_info_tween.kill()
		_extra_info_tween = null


## _apply_custom_theme()
##
## Loads and applies a custom UI theme for the scorecard if present.
func _apply_custom_theme():
	# Load the custom scorecard theme
	var custom_theme = load("res://Resources/UI/scorecard_theme.tres") as Theme
	if custom_theme:
		theme = custom_theme
		print("[ScoreCardUI] Custom theme applied successfully")
	else:
		push_error("[ScoreCardUI] Failed to load custom theme from res://Resources/UI/scorecard_theme.tres")


## bind_scorecard(sc)
##
## Attaches a `Scorecard` model to the UI, refreshes displays and connects relevant signals.
func bind_scorecard(sc: Scorecard):
	scorecard = sc
	update_all()
	connect_buttons()
	# Connect to bonus signals
	scorecard.upper_bonus_achieved.connect(_on_upper_bonus_achieved)
	scorecard.upper_section_completed.connect(_on_upper_section_completed)
	scorecard.lower_section_completed.connect(_on_lower_section_completed)
	scorecard.yahtzee_bonus_achieved.connect(_on_yahtzee_bonus_achieved)
	
	# Connect to score assignment signals for autoscoring
	scorecard.score_assigned.connect(_on_score_assigned_from_scorecard)
	scorecard.score_auto_assigned.connect(_on_score_auto_assigned)
	scorecard.score_changed.connect(_on_score_changed_from_scorecard)
	
	# Connect to category upgrade signal for level label updates
	scorecard.category_upgraded.connect(_on_category_upgraded)
	
	# Create level labels for all categories
	_create_level_labels()

	# Set scorecard in DiceResults
	DiceResults.set_scorecard(scorecard)


## update_all()
##
## Refreshes the UI labels and totals from the bound `scorecard` model.
func update_all():
	for category in scorecard.upper_scores.keys():
		var label_path = "HBoxContainer/UpperVBoxContainer/UpperGridContainer/" + category.capitalize() + "Container/" + category.capitalize() + "Label"
		var label = get_node_or_null(label_path)
		if label:
			var value = scorecard.upper_scores[category]
			label.text = str(int(value)) if value != null else "-"

	for category in scorecard.lower_scores.keys():
		var node_name = LOWER_CATEGORY_NODE_NAMES.get(category, category.capitalize())
		var label_path = "HBoxContainer/LowerVBoxContainer/LowerGridContainer/" + node_name + "/" + node_name + "Label"
		var label = get_node_or_null(label_path)
		if label:
			var value = scorecard.lower_scores[category]
			label.text = str(int(value)) if value != null else "-"

	# Update upper section totals with debug prints
	var upper_subtotal = scorecard.get_upper_section_total()
	
	if upper_total_label:
		upper_total_label.text = str(int(upper_subtotal))
	else:
		push_error("upper_total_label not found!")
		
	# Show progress towards bonus
	if upper_bonus_label:
		if scorecard.is_upper_section_complete():
			if upper_subtotal >= Scorecard.UPPER_BONUS_THRESHOLD:
				upper_bonus_label.text = str(int(Scorecard.UPPER_BONUS_AMOUNT))
			else:
				upper_bonus_label.text = "0"
		else:
			var remaining = Scorecard.UPPER_BONUS_THRESHOLD - upper_subtotal
			upper_bonus_label.text = str(int(remaining)) #need remaining points, remove this later
	else:
		push_error("upper_bonus_label not found!")
	
	# Update final upper total (subtotal + bonus)
	if upper_final_total_label:
		var final_total = scorecard.get_upper_section_final_total()
		upper_final_total_label.text = str(int(final_total))
	else:
		push_error("upper_final_total_label not found!")

	# Update lower section total - Add Yahtzee bonus points
	var lower_total = scorecard.get_lower_section_total()
	lower_total += scorecard.yahtzee_bonus_points  # Add Yahtzee bonus to lower total
	
	if lower_total_label:
		lower_total_label.text = str(int(lower_total))
	else:
		push_error("lower_total_label not found!")
	
	# Update total score with dynamic effect (tornado disabled)
	if total_score_label:
		var upper_total = scorecard.get_upper_section_final_total()
		var total_score = upper_total + lower_total  # lower_total already includes Yahtzee bonus
		
		# Format with BBCode - tornado disabled for now
		var text = "[center]Total Score:\n%d[/center]" % total_score
		total_score_label.text = text
		
		# Adjust font size based on score
		var base_size = 24
		var size_scale = remap(total_score, 0, 500, 1.0, 1.3)
		total_score_label.add_theme_font_size_override("normal_font_size", int(base_size * size_scale))

	# Update Yahtzee bonus display
	if yahtzee_bonus_label:
		if scorecard.yahtzee_bonuses > 0:
			yahtzee_bonus_label.text = str(int(scorecard.yahtzee_bonus_points))
		else:
			yahtzee_bonus_label.text = "-"


## _create_level_labels()
##
## References level indicator labels from the scene for all scoring categories.
## Labels show "Lv.1" by default and update to "Lv.X" when upgraded.
func _create_level_labels() -> void:
	print("[ScoreCardUI] Referencing category level labels from scene")
	
	# Load VCR font for level labels
	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
	
	# Reference labels for upper section categories
	var upper_categories = ["ones", "twos", "threes", "fours", "fives", "sixes"]
	for category in upper_categories:
		var category_name = category.capitalize()
		var label_path = "HBoxContainer/UpperVBoxContainer/UpperGridContainer/" + category_name + "Container/" + category_name + "LevelLabel"
		var level_label = get_node_or_null(label_path)
		
		if level_label:
			# Apply styling
			if vcr_font:
				level_label.add_theme_font_override("font", vcr_font)
			level_label.add_theme_color_override("font_color", Color(1, 0.84, 0, 1))  # Gold color
			level_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			level_label.add_theme_constant_override("outline_size", 1)
			
			category_level_labels[category] = level_label
			print("[ScoreCardUI] Found level label for upper:", category)
		else:
			print("[ScoreCardUI] Warning: Level label not found for upper category:", category)
	
	# Reference labels for lower section categories (including chance)
	var lower_categories_to_upgrade = ["three_of_a_kind", "four_of_a_kind", "full_house", "small_straight", "large_straight", "yahtzee", "chance"]
	for category in lower_categories_to_upgrade:
		var node_name = LOWER_CATEGORY_NODE_NAMES.get(category, category.capitalize())
		var label_path = "HBoxContainer/LowerVBoxContainer/LowerGridContainer/" + node_name + "/" + node_name + "LevelLabel"
		var level_label = get_node_or_null(label_path)
		
		if level_label:
			# Apply styling
			if vcr_font:
				level_label.add_theme_font_override("font", vcr_font)
			level_label.add_theme_color_override("font_color", Color(1, 0.84, 0, 1))  # Gold color
			level_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			level_label.add_theme_constant_override("outline_size", 1)
			
			category_level_labels[category] = level_label
			print("[ScoreCardUI] Found level label for lower:", category)
		else:
			print("[ScoreCardUI] Warning: Level label not found for lower category:", category)
	
	print("[ScoreCardUI] Referenced", category_level_labels.size(), "level labels total")


## _on_category_upgraded(section, category, new_level)
##
## Updates the level label when a category is upgraded.
## Shows "Lv.X" text for all levels (including level 1).
func _on_category_upgraded(_section: Scorecard.Section, category: String, new_level: int) -> void:
	print("[ScoreCardUI] Category upgraded:", category, "to level", new_level)
	
	var level_label = category_level_labels.get(category)
	if level_label:
		level_label.text = "Lv.%d" % new_level
		
		# Add a brief highlight animation when upgraded above level 1
		if new_level > 1:
			var tween = create_tween()
			level_label.modulate = Color(1, 1, 0.5, 1)  # Bright yellow flash
			tween.tween_property(level_label, "modulate", Color(1, 1, 1, 1), 0.4)
			
			# Scale bounce effect
			level_label.scale = Vector2(1.3, 1.3)
			tween.parallel().tween_property(level_label, "scale", Vector2(1, 1), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	else:
		print("[ScoreCardUI] Warning: No level label found for category:", category)


## _on_upper_bonus_achieved(bonus)
##
## UI feedback for when the upper section bonus is achieved. Animates labels and optionally triggers screen shake.
func _on_upper_bonus_achieved(_bonus: int) -> void:
	# Animate the bonus achievement and update totals
	if upper_bonus_label:
		var tween = create_tween()
		tween.tween_property(upper_bonus_label, "modulate", Color.YELLOW, 0.3)
		tween.tween_property(upper_bonus_label, "modulate", Color.WHITE, 0.3)

		# Update the final total label with animation
		if upper_final_total_label:
			var final_total = scorecard.get_upper_section_final_total()
			tween.tween_property(upper_final_total_label, "modulate", Color.YELLOW, 0.3)
			upper_final_total_label.text = str(int(final_total))
			tween.tween_property(upper_final_total_label, "modulate", Color.WHITE, 0.3)

		# Optional: Add screen shake
		var screen_shake = get_tree().root.find_child("ScreenShake", true, false)
		if screen_shake:
			screen_shake.shake(0.4, 0.3)

			# Animate total score
	if total_score_label:
		var tween = create_tween()
		tween.tween_property(total_score_label, "modulate", Color.YELLOW, 0.3)
		tween.tween_property(total_score_label, "modulate", Color.WHITE, 0.3)

func _on_upper_section_completed() -> void:
	# Optional: Visual feedback for section completion
	var upper_section = $HBoxContainer/UpperVBoxContainer
	if upper_section:
		var tween = create_tween()
		tween.tween_property(upper_section, "modulate", Color(1.2, 1.2, 1.2), 0.3)
		tween.tween_property(upper_section, "modulate", Color.WHITE, 0.3)
	update_all()  # Refresh total score

func _on_lower_section_completed() -> void:
	# Visual feedback for section completion
	var lower_section = $HBoxContainer/LowerVBoxContainer
	if lower_section:
		var tween = create_tween()
		tween.tween_property(lower_section, "modulate", Color(1.2, 1.2, 1.2), 0.3)
		tween.tween_property(lower_section, "modulate", Color.WHITE, 0.3)
		
		# Optional: Add screen shake
		var screen_shake = get_tree().root.find_child("ScreenShake", true, false)
		if screen_shake:
			screen_shake.shake(0.3, 0.2)


## connect_buttons()
##
## Wire up UI buttons for each score category so the player can select categories to score.
func connect_buttons():
	# Initialize section_buttons dictionary
	section_buttons = {
		Scorecard.Section.UPPER: {},
		Scorecard.Section.LOWER: {}
	}

	# Upper section
	for category in scorecard.upper_scores.keys():
		var button_path = "HBoxContainer/UpperVBoxContainer/UpperGridContainer/" + category.capitalize() + "Container/" + category.capitalize() + "Button"
		var button = get_node_or_null(button_path)
		if button:
			button.pressed.connect(func(): on_category_selected(Scorecard.Section.UPPER, category))
			upper_section_buttons[category] = button
			section_buttons[Scorecard.Section.UPPER][category] = button

	# Lower section
	for category in scorecard.lower_scores.keys():
		var node_name = LOWER_CATEGORY_NODE_NAMES.get(category, category.capitalize())
		var button_path = "HBoxContainer/LowerVBoxContainer/LowerGridContainer/" + node_name + "/" + node_name + "Button"
		var button = get_node_or_null(button_path)
		if button:
			button.pressed.connect(func(): on_category_selected(Scorecard.Section.LOWER, category))
			lower_section_buttons[category] = button
			section_buttons[Scorecard.Section.LOWER][category] = button
		else:
			print("❌ Lower button not found for:", category, "→", button_path)

func on_category_selected(section: Scorecard.Section, category: String) -> void:
	print("\n=== SCORECARD UI CATEGORY SELECTED ===")
	print("[ScoreCardUI] *** FUNCTION CALLED *** on_category_selected")
	print("[ScoreCardUI] Category selected:", category)
	print("[ScoreCardUI] Section:", section)
	print("[ScoreCardUI] Double mode active:", is_double_mode)
	print("[ScoreCardUI] Any score mode active:", any_score_active)
	print("[ScoreCardUI] Go broke mode active:", go_broke_mode)
	print("[ScoreCardUI] Reroll active:", reroll_active)
	print("[ScoreCardUI] Turn scored:", turn_scored)
	
	# Check if dice are in a valid state for scoring
	var dice_hand = get_node_or_null("../DiceHand") as DiceHand
	if dice_hand and not dice_hand.can_any_dice_score():
		print("[ScoreCardUI] Cannot score - no dice are in ROLLED or LOCKED state")
		show_invalid_score_feedback(category)
		return
	
	# Check if we're in double mode
	if is_double_mode:
		_handle_double_score(section, category)
		return
	
	# Check if we're in go broke mode - only allow lower section
	if go_broke_mode:
		if section != Scorecard.Section.LOWER:
			print("[ScoreCardUI] Go Broke mode: only lower section allowed")
			show_invalid_score_feedback(category)
			return
		# For go broke mode, allow scoring even if already scored (for reroll scenarios)
		# The consumable will handle the logic
		handle_go_broke_score(section, category)
		return
	
	# Check if this category already has a score
	var existing_score = null
	match section:
		Scorecard.Section.UPPER:
			existing_score = scorecard.upper_scores.get(category)
		Scorecard.Section.LOWER:
			existing_score = scorecard.lower_scores.get(category)
			
	if existing_score != null and not reroll_active and not any_score_active:
		show_invalid_score_feedback(category)
		return
		
	if reroll_active:
		handle_score_reroll(section, category)
		return
		
	if any_score_active:
		handle_any_score(section, category)
		return
		
	if turn_scored:
		print("[ScoreCardUI] Turn already scored, cannot score again this turn")
		return

	var values = DiceResults.values
	print("\n=== Processing Score Selection ===")
	print("[ScoreCardUI] Category:", category)
	print("[ScoreCardUI] Dice values:", values)
	
	# Emit signal before scoring to allow PowerUps to prepare
	print("[ScoreCardUI] Emitting about_to_score signal...")
	about_to_score.emit(section, category, values)
	print("[ScoreCardUI] about_to_score signal emitted")
	
	# Use scorecard's on_category_selected to properly apply money effects for actual scoring
	scorecard.on_category_selected(section, category)
	
	# Get the score for display (this is now already set by on_category_selected)
	var score = null
	if section == Scorecard.Section.UPPER:
		score = scorecard.upper_scores[category]
	else:
		score = scorecard.lower_scores[category]
	
	print("[ScoreCardUI] Final score set:", score)
	
	if score == null:
		print("[ScoreCardUI] Invalid score calculation")
		show_invalid_score_feedback(category)
		return

	# Check for Yahtzee bonus
	scorecard.check_bonus_yahtzee(values, category)
	
	# Score is already set by on_category_selected, just update UI
	print("[ScoreCardUI] Score already set by scorecard, updating UI")
	_screen_shaker(score*5, 100)
	update_all()
	turn_scored = true
	disable_all_score_buttons()
	
	# Create logbook entry before emitting hand_scored signal
	create_logbook_entry(section, category, values, score)
	
	# Emit signal for randomizer effect display
	emit_signal("hand_scored")
	
	# Update ExtraInfo with recent logbook entries
	update_extra_info_with_logbook()
	
	# Note: GameController will be notified via scorecard.score_assigned signal connection

func disable_all_score_buttons():
	for button in upper_section_buttons.values():
		button.disabled = true
		button.modulate = Color.WHITE  # Reset any special highlighting
	for button in lower_section_buttons.values():
		button.disabled = true
		button.modulate = Color.WHITE  # Reset any special highlighting

func enable_all_score_buttons():
	for button in upper_section_buttons.values():
		button.disabled = false
	for button in lower_section_buttons.values():
		button.disabled = false

func allow_extra_score():
	turn_scored = false

func show_invalid_score_feedback(category: String):
	# Optional: flash button red
	var button = get_node_or_null("HBoxContainer/.../" + category.capitalize() + "Button")
	if button:
		var tween := get_tree().create_tween()
		tween.tween_property(button, "modulate", Color.RED, 0.2).set_trans(Tween.TRANS_SINE)
		tween.tween_property(button, "modulate", Color.WHITE, 0.2).set_delay(0.2)

func update_best_hand_preview(dice_values: Array) -> void:
	if not best_hand_label:
		return

	# Reset evaluation counter for preview calculations
	ScoreEvaluatorSingleton.reset_evaluation_count()

	var best_score := -1
	var _best_section
	var best_category := ""
	
	# Check upper section
	for category in scorecard.upper_scores.keys():
		if scorecard.upper_scores[category] == null:
			var score = scorecard.evaluate_category(category, dice_values)
			if score > best_score:
				best_score = score
				_best_section = Scorecard.Section.UPPER
				best_category = category
	
	# Define evaluation order for lower section
	var lower_evaluation_order := [
		"yahtzee", "large_straight", "small_straight", 
		"full_house", "four_of_a_kind", "three_of_a_kind", "chance"
	]
	
	# Check lower section in specific order
	for category in lower_evaluation_order:
		if scorecard.lower_scores[category] == null:
			var score = scorecard.evaluate_category(category, dice_values)
			if score > best_score:
				best_score = score
				_best_section = Scorecard.Section.LOWER
				best_category = category

	if best_category != "":
		var display_category = best_category.capitalize().replace("_", " ")
		
		# Simple formatting - show only category name (tornado disabled for now)
		var format_text = "[center][b]Best Hand:[/b]\n%s[/center]" % display_category
		
		best_hand_label.add_theme_font_size_override("normal_font_size", 18)
		best_hand_label.text = format_text
		animate_best_hand_label()
		
		# Calculate RAW base score (without any powerups/modifiers) × category level
		# Use ScoreEvaluatorSingleton directly to get unmodified base score
		var raw_scores = ScoreEvaluatorSingleton.evaluate_normal(dice_values)
		var raw_base_score = raw_scores.get(best_category, 0)
		var category_level = scorecard.get_category_level_by_name(best_category)
		var base_additive = raw_base_score * category_level
		
		# Store current best hand info
		current_best_hand_category = best_category
		current_best_hand_section = _best_section
		current_base_additive_score = base_additive
		
		# Update the additive panel with base score (no animation for preview)
		if additive_score_label:
			additive_score_label.text = "+%d" % base_additive
			additive_score_label.modulate = Color(0.7, 0.7, 0.0) if base_additive > 0 else Color.WHITE
		
		print("[ScoreCardUI] Best hand: %s (Lv.%d) RAW base: %d × %d = +%d base additive (no powerups)" % [best_category, category_level, raw_base_score, category_level, base_additive])

	_screen_shaker(best_score, 50)

		
func _screen_shaker(best_score: int, max_clamp: int) -> void:
	if best_score >= 100:
		best_score = max_clamp
	var screen_shake = get_tree().root.find_child("ScreenShake", true, false)
	var shake_intensity = remap(best_score, 0, max_clamp, 0.1, 1.0)
	print("[Shake intensity]:", shake_intensity, " for score:", best_score)
	if screen_shake:
		screen_shake.shake(shake_intensity, shake_intensity / 2)

func remap(value, from_min, from_max, to_min, to_max):
	var t = inverse_lerp(from_min, from_max, value)
	return lerp(to_min, to_max, t)


func animate_best_hand_label():
	var tween = create_tween()
	
	# Save original position
	var original_position = best_hand_label.position
	
	# Wave animation
	tween.tween_property(best_hand_label, "position:y", 
		original_position.y - 10, 0.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(best_hand_label, "position:y", 
		original_position.y, 0.2).set_trans(Tween.TRANS_SINE)

func activate_score_reroll() -> void:
	print("[ScoreCardUI] DEBUG: activate_score_reroll() called - SPECIAL MODE USAGE TRACKING")
	reroll_active = true
	# Enable only buttons that have scores
	for category in upper_section_buttons.keys():
		var button = upper_section_buttons[category]
		button.disabled = scorecard.upper_scores[category] == null
	for category in lower_section_buttons.keys():
		var button = lower_section_buttons[category]
		button.disabled = scorecard.lower_scores[category] == null
		
func handle_score_reroll(section: Scorecard.Section, category: String) -> void:
	var values = DiceResults.values
	
	# Emit signal before scoring to allow PowerUps to prepare
	print("[ScoreCardUI] Emitting about_to_score signal for reroll...")
	about_to_score.emit(section, category, values)
	print("[ScoreCardUI] about_to_score signal emitted for reroll")
	
	# Use scorecard.evaluate_category instead of direct ScoreEvaluator call
	var score = scorecard.evaluate_category(category, values)
	print("[ScoreCardUI] Reroll score calculated:", score)
	
	# Verify the category has an existing score to reroll
	var has_existing_score = false
	match section:
		Scorecard.Section.UPPER:
			has_existing_score = scorecard.upper_scores[category] != null
		Scorecard.Section.LOWER:
			has_existing_score = scorecard.lower_scores[category] != null
			
	if not has_existing_score:
		print("[ScoreCardUI] No existing score to reroll")
		show_invalid_score_feedback(category)
		return
	
	if score == null:
		print("[ScoreCardUI] Invalid score calculation")
		show_invalid_score_feedback(category)
		return
		
	# Replace the old score with the multiplied value
	print("[ScoreCardUI] Setting rerolled score for", category, "to:", score)
	scorecard.set_score(section, category, score)
	update_all()
	
	# Reset reroll state
	reroll_active = false
	disable_all_score_buttons()
	
	# Create logbook entry for reroll
	create_logbook_entry(section, category, values, score)
	
	emit_signal("hand_scored")
	emit_signal("score_rerolled", section, category, score)
	
	# Update ExtraInfo with recent logbook entries
	update_extra_info_with_logbook()

func _on_yahtzee_bonus_achieved(_points: int) -> void:
	# Extra visual feedback for bonus yahtzee
	if total_score_label:
		# Bigger text animation
		var base_size = total_score_label.get_theme_font_size("normal_font_size")
		var tween = create_tween()
		tween.tween_property(total_score_label, "theme_override_font_sizes/normal_font_size", 
			base_size * 1.5, 0.2)
		tween.tween_property(total_score_label, "theme_override_font_sizes/normal_font_size", 
			base_size, 0.2)
		
		# Optional: Add celebratory particle effect
		var screen_shake = get_tree().root.find_child("ScreenShake", true, false)
		if screen_shake:
			screen_shake.shake(0.8, 0.5)  # Big shake for bonus yahtzee!
		
		# Update with new total including bonus
		update_all()

func activate_score_double() -> void:
	print("[ScoreCardUI] DEBUG: activate_score_double() called - SPECIAL MODE USAGE TRACKING")
	print("[ScoreCardUI] Activating double score mode")
	is_double_mode = true
	
	# Enable only score buttons for categories that already have scores
	for section in [Scorecard.Section.UPPER, Scorecard.Section.LOWER]:
		var buttons = section_buttons[section]
		for category in buttons:
			var score = null
			if section == Scorecard.Section.UPPER:
				score = scorecard.upper_scores[category]
			else:
				score = scorecard.lower_scores[category]
				
			buttons[category].disabled = (score == null)
			
	# Highlight available categories
	for section in [Scorecard.Section.UPPER, Scorecard.Section.LOWER]:
		var buttons = section_buttons[section]
		for category in buttons:
			if not buttons[category].disabled:
				buttons[category].modulate = Color(1.2, 1.2, 0.8)  # Yellow highlight

func _handle_double_score(section: Scorecard.Section, category: String) -> void:
	print("[ScoreCardUI] Handling double score for", category)
	var current_score = null
	if section == Scorecard.Section.UPPER:
		current_score = scorecard.upper_scores[category]
	else:
		current_score = scorecard.lower_scores[category]
		
	if current_score != null:
		var doubled_score = current_score * 2
		print("[ScoreCardUI] Doubling score for", category, "from", current_score, "to", doubled_score)
		
		# Update the score
		scorecard.set_score(section, category, doubled_score)
		
		# Update the UI
		update_all()
		
		# Reset double mode
		is_double_mode = false
		
		# Reset button modulate
		for s in [Scorecard.Section.UPPER, Scorecard.Section.LOWER]:
			var buttons = section_buttons[s]
			for cat in buttons:
				buttons[cat].modulate = Color(1, 1, 1)
		
		# Emit signal
		emit_signal("score_doubled", section, category, doubled_score)
		enable_all_score_buttons()

var _extra_info_tween: Tween = null

func update_extra_info(info_text: String) -> void:
	"""Update the ExtraInfo RichTextLabel with randomizer or other power-up effects"""
	if extra_info_label:
		# Safety check - don't create tweens on invalid nodes
		if not is_inside_tree():
			return
			
		# Reset any existing animations
		if _extra_info_tween:
			_extra_info_tween.kill()
			_extra_info_tween = null
		
		# Set initial state
		extra_info_label.text = "[center]%s[/center]" % info_text
		extra_info_label.modulate = Color(1, 1, 1, 0)
		extra_info_label.scale = Vector2(0.5, 0.5)
		extra_info_label.visible = true
		
		# Create animation sequence
		_extra_info_tween = create_tween()
		
		# Pop-in effect (scale and fade in)
		_extra_info_tween.parallel().tween_property(extra_info_label, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_extra_info_tween.parallel().tween_property(extra_info_label, "scale", Vector2(2.0, 2.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		# Settle to normal size
		_extra_info_tween.tween_property(extra_info_label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		
		# Wait for 5 seconds
		_extra_info_tween.tween_interval(5.0)
		
		# Fade out
		_extra_info_tween.tween_property(extra_info_label, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
		# Hide when done
		_extra_info_tween.tween_callback(func(): extra_info_label.visible = false)
		
		print("[ScoreCardUI] Updated ExtraInfo with animation:", info_text)
	else:
		print("[ScoreCardUI] Warning: ExtraInfo RichTextLabel not found in scene")
		# Try to find it by searching children if it exists but wasn't connected properly
		var extra_info = get_node_or_null("ExtraInfo")
		if not extra_info:
			extra_info = find_child("ExtraInfo", true, false)
		if extra_info and extra_info is RichTextLabel:
			extra_info_label = extra_info
			# Retry the animation with found label
			update_extra_info(info_text)

## update_extra_info_with_logbook()
##
## Update ExtraInfo with recent logbook entries from Statistics Manager
func update_extra_info_with_logbook(entry_count: int = 3) -> void:
	if not Statistics:
		print("[ScoreCardUI] Warning: Statistics Manager not available")
		return
	
	var recent_logs = Statistics.get_formatted_recent_logs(entry_count)
	
	if recent_logs.is_empty():
		recent_logs = "[color=gray][i]No scoring history yet[/i][/color]"
	else:
		# Add formatting for better readability
		var formatted_lines = recent_logs.split("\n")
		var bbcode_lines: Array[String] = []
		
		for i in range(formatted_lines.size()):
			var line = formatted_lines[i]
			if line.strip_edges().is_empty():
				continue
			
			# Add color coding based on recency (most recent = brightest)
			var alpha = 1.0 - (i * 0.2)  # Fade older entries
			alpha = max(alpha, 0.4)  # Don't go too faded
			
			# Color based on score effectiveness with fading
			var base_color = Color.WHITE
			if "→" in line:
				# Try to extract score info for color coding
				if "=" in line:
					var score_part = line.split("=")[-1].strip_edges()
					var score_str = score_part.replace("pts", "").strip_edges()
					var score = score_str.to_int()
					if score >= 20:
						base_color = Color.GREEN
					elif score >= 10:
						base_color = Color.YELLOW
					else:
						base_color = Color.ORANGE
			
			# Apply alpha to the base color
			var faded_color = Color(base_color.r, base_color.g, base_color.b, alpha)
			
			# Convert to hex for BBCode
			var hex_color = "#%02x%02x%02x%02x" % [int(faded_color.r * 255), int(faded_color.g * 255), int(faded_color.b * 255), int(faded_color.a * 255)]
			
			bbcode_lines.append("[color=%s]%s[/color]" % [hex_color, line])
		
		recent_logs = "\n".join(bbcode_lines)
	
	if extra_info_label:
		# Use existing animation system but with different formatting
		_update_extra_info_for_logbook(recent_logs)
	else:
		print("[ScoreCardUI] Warning: ExtraInfo label not found for logbook update")
		# Try to find it again and ensure it's properly configured
		extra_info_label = get_node_or_null("ExtraInfo")
		if not extra_info_label:
			extra_info_label = find_child("ExtraInfo", true, false)
		if extra_info_label and extra_info_label is RichTextLabel:
			# Ensure BBCode is enabled
			extra_info_label.bbcode_enabled = true
			_update_extra_info_for_logbook(recent_logs)
		else:
			print("[ScoreCardUI] Error: ExtraInfo node not found or not a RichTextLabel")

## _update_extra_info_for_logbook()
##
## Internal method to update ExtraInfo without center alignment (for logbook entries)
func _update_extra_info_for_logbook(info_text: String) -> void:
	if extra_info_label:
		# Reset any existing animations
		if _extra_info_tween:
			_extra_info_tween.kill()
			_extra_info_tween = null
		
		# Set text without center alignment for better log readability
		extra_info_label.text = info_text
		extra_info_label.modulate = Color(1, 1, 1, 0)
		extra_info_label.scale = Vector2(0.8, 0.8)  # Slightly smaller for logs
		extra_info_label.visible = true
		
		# Gentler animation for logs
		_extra_info_tween = create_tween()
		
		# Fade in and scale up
		_extra_info_tween.parallel().tween_property(extra_info_label, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_extra_info_tween.parallel().tween_property(extra_info_label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		# Stay visible longer for logs (8 seconds instead of 5)
		_extra_info_tween.tween_interval(8.0)
		
		# Fade out
		_extra_info_tween.tween_property(extra_info_label, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
		# Hide when done
		_extra_info_tween.tween_callback(func(): extra_info_label.visible = false)
		
		print("[ScoreCardUI] Updated ExtraInfo with logbook entries")

## create_logbook_entry()
##
## Create and log a detailed entry for the hand that was just scored
## This function gets the current breakdown info and calls the comprehensive version
func create_logbook_entry(section: Scorecard.Section, category: String, dice_values: Array[int], final_score: int) -> void:
	print("[ScoreCardUI] DEBUG: create_logbook_entry called for", category, "with score", final_score)
	
	# Get current breakdown info from scorecard
	var scoring_breakdown = scorecard.calculate_score_with_breakdown(category, dice_values, false)
	var breakdown_info = scoring_breakdown.get("breakdown_info", {})
	
	# Call the comprehensive version with breakdown info
	_create_logbook_entry_with_breakdown(section, category, dice_values, final_score, breakdown_info)

## _create_logbook_entry_with_breakdown()
##
## Create a logbook entry using pre-calculated breakdown info (for auto-scoring)
## This prevents the timing issue where PowerUps are cleared before logbook entry creation
func _create_logbook_entry_with_breakdown(section: Scorecard.Section, category: String, dice_values: Array[int], final_score: int, breakdown_info: Dictionary) -> void:
	print("[ScoreCardUI] DEBUG: _create_logbook_entry_with_breakdown called for", category, "with score", final_score)
	
	if not Statistics:
		print("[ScoreCardUI] Warning: Statistics Manager not available for logbook")
		return
	
	print("[ScoreCardUI] DEBUG: Statistics manager available, proceeding with logbook entry creation")
	
	# Extract dice information from DiceResults
	var dice_colors: Array[String] = []
	var dice_mods: Array[String] = []
	
	if DiceResults and DiceResults.dice_refs and DiceResults.dice_refs.size() > 0:
		print("[ScoreCardUI] DEBUG: Processing %d dice for logbook (second instance)" % DiceResults.dice_refs.size())
		for i in range(DiceResults.dice_refs.size()):
			var dice = DiceResults.dice_refs[i]
			if dice and dice is Dice:
				# Get color name
				var color_name = DiceColor.get_color_name(dice.color).to_lower()
				print("[ScoreCardUI] DEBUG: Die %d - value: %d, color enum: %s, color_name: %s" % [i, dice.value, dice.color, color_name])
				dice_colors.append(color_name)
				
				# Get active mods (if any)
				var dice_mod_names: Array[String] = []
				if dice.active_mods and dice.active_mods.size() > 0:
					for mod_id in dice.active_mods.keys():
						var mod = dice.active_mods[mod_id]
						if mod and mod.has_method("get_name"):
							dice_mod_names.append(mod.get_name())
						else:
							dice_mod_names.append(mod_id)
				
				if dice_mod_names.size() > 0:
					dice_mods.append(",".join(dice_mod_names))
				else:
					dice_mods.append("")
		print("[ScoreCardUI] DEBUG: Final dice_colors array (second): %s" % [dice_colors])
	else:
		# Fallback - no dice references available
		for i in range(dice_values.size()):
			dice_colors.append("none")
			dice_mods.append("")
	
	# Use the pre-calculated breakdown info instead of recalculating
	var base_score = breakdown_info.get("base_score", final_score)
	
	# Extract active PowerUps and Consumables from the passed breakdown
	var active_powerups = breakdown_info.get("active_powerups", [])
	var active_consumables = breakdown_info.get("active_consumables", [])
	
	print("[ScoreCardUI] DEBUG: Using breakdown PowerUps:", active_powerups)
	print("[ScoreCardUI] DEBUG: Using breakdown Consumables:", active_consumables)
	
	# Create modifier effects array for legacy compatibility
	var modifier_effects: Array[Dictionary] = []
	if breakdown_info.get("has_modifiers", false):
		# Add additive effects
		var total_additive = breakdown_info.get("total_additive", 0)
		if total_additive > 0:
			var regular_additive = breakdown_info.get("regular_additive", 0)
			var red_additive = breakdown_info.get("dice_color_additive", 0)
			
			if regular_additive > 0:
				modifier_effects.append({
					"type": "additive",
					"value": regular_additive,
					"source": "powerups/consumables",
					"description": "+%d from modifiers" % regular_additive,
					"short_description": "+%d" % regular_additive
				})
			
			if red_additive > 0:
				modifier_effects.append({
					"type": "additive", 
					"value": red_additive,
					"source": "red_dice",
					"description": "+%d from red dice" % red_additive,
					"short_description": "red+%d" % red_additive
				})
		
		# Add multiplier effects
		var total_multiplier = breakdown_info.get("total_multiplier", 1.0)
		var blue_multiplier = breakdown_info.get("blue_score_multiplier", 1.0)
		if total_multiplier != 1.0 or blue_multiplier != 1.0:
			var regular_multiplier = breakdown_info.get("regular_multiplier", 1.0)
			var purple_multiplier = breakdown_info.get("dice_color_multiplier", 1.0)
			
			if regular_multiplier != 1.0:
				modifier_effects.append({
					"type": "multiplier",
					"value": regular_multiplier,
					"source": "powerups/consumables", 
					"description": "×%.1f from modifiers" % regular_multiplier,
					"short_description": "×%.1f" % regular_multiplier
				})
			
			if purple_multiplier != 1.0:
				modifier_effects.append({
					"type": "multiplier",
					"value": purple_multiplier,
					"source": "purple_dice",
					"description": "×%.1f from purple dice" % purple_multiplier,
					"short_description": "purple×%.1f" % purple_multiplier
				})
			
			if blue_multiplier != 1.0:
				modifier_effects.append({
					"type": "multiplier",
					"value": blue_multiplier,
					"source": "blue_dice",
					"description": "×%.1f from blue dice" % blue_multiplier,
					"short_description": "blue×%.1f" % blue_multiplier
				})
	
	# Convert section enum to string
	var section_string = "upper" if section == Scorecard.Section.UPPER else "lower"
	
	# Create the enhanced logbook entry with the correct PowerUps/Consumables
	Statistics.log_hand_scored(
		dice_values,
		dice_colors,
		dice_mods,
		category,
		section_string,
		active_consumables,
		active_powerups,
		base_score,
		modifier_effects,
		final_score,
		breakdown_info
	)

## activate_any_score_mode()
##
## Activates the AnyScore consumable mode, allowing scoring in any open category
## regardless of dice requirements
func activate_any_score_mode() -> void:
	print("[ScoreCardUI] DEBUG: activate_any_score_mode() called - SPECIAL MODE USAGE TRACKING")
	any_score_active = true
	print("[ScoreCardUI] AnyScore mode activated")
	
	# Enable only buttons that don't have scores (open categories)
	for category in upper_section_buttons.keys():
		var button = upper_section_buttons[category]
		button.disabled = scorecard.upper_scores[category] != null
		# Highlight available categories with special color for any-score mode
		if not button.disabled:
			button.modulate = Color(0.8, 1.2, 0.8)  # Green highlight for any-score
			
	for category in lower_section_buttons.keys():
		var button = lower_section_buttons[category]
		button.disabled = scorecard.lower_scores[category] != null
		# Highlight available categories with special color for any-score mode
		if not button.disabled:
			button.modulate = Color(0.8, 1.2, 0.8)  # Green highlight for any-score

## deactivate_any_score_mode()
##
## Deactivates the AnyScore mode and clears all highlighting
func deactivate_any_score_mode() -> void:
	any_score_active = false
	print("[ScoreCardUI] AnyScore mode deactivated")
	
	# Clear all special highlighting and disable buttons
	for button in upper_section_buttons.values():
		button.modulate = Color.WHITE
		button.disabled = true
	for button in lower_section_buttons.values():
		button.modulate = Color.WHITE
		button.disabled = true

## set_go_broke_mode(active)
##
## Sets the Go Broke or Go Home mode state
func set_go_broke_mode(active: bool) -> void:
	print("[ScoreCardUI] DEBUG: set_go_broke_mode(%s) called - SPECIAL MODE USAGE TRACKING" % [active])
	go_broke_mode = active
	print("[ScoreCardUI] Go Broke mode set to:", active)

## handle_any_score(section, category)
##
## Handles scoring when AnyScore mode is active - uses the sum of dice values
## instead of category-specific scoring rules
func handle_any_score(section: Scorecard.Section, category: String) -> void:
	var dice_values = DiceResults.values
	print("[ScoreCardUI] AnyScore mode - scoring", category, "with dice:", dice_values)
	
	# Emit signal before scoring to allow PowerUps to prepare
	print("[ScoreCardUI] Emitting about_to_score signal for AnyScore...")
	about_to_score.emit(section, category, dice_values)
	print("[ScoreCardUI] about_to_score signal emitted for AnyScore")
	
	# Verify the category is open (hasn't been scored yet)
	var has_existing_score = false
	match section:
		Scorecard.Section.UPPER:
			has_existing_score = scorecard.upper_scores[category] != null
		Scorecard.Section.LOWER:
			has_existing_score = scorecard.lower_scores[category] != null
			
	if has_existing_score:
		print("[ScoreCardUI] Cannot use AnyScore on already scored category")
		show_invalid_score_feedback(category)
		return
	
	# Calculate the score using the highest-scoring interpretation of current dice
	# This allows the player to score their dice in the most advantageous way
	var score = _calculate_best_score_for_dice(dice_values)
	
	print("[ScoreCardUI] AnyScore calculated best score:", score, "for category:", category)
	
	if score == null or score < 0:
		print("[ScoreCardUI] Invalid AnyScore calculation")
		show_invalid_score_feedback(category)
		return
		
	# Set the selected category's score to the best possible score
	print("[ScoreCardUI] Setting AnyScore for", category, "to:", score)
	scorecard.set_score(section, category, score)
	update_all()
	
	# Reset any score mode and clear highlighting
	deactivate_any_score_mode()
	
	# Create logbook entry for AnyScore usage
	create_logbook_entry(section, category, dice_values, score)
	
	emit_signal("hand_scored")
	
	# Update ExtraInfo with recent logbook entries
	update_extra_info_with_logbook()
	
	print("[ScoreCardUI] AnyScore completed for", category)

## handle_go_broke_score(section, category)
##
## Handles scoring when Go Broke or Go Home mode is active - uses normal scoring rules
## but is restricted to lower section only
func handle_go_broke_score(section: Scorecard.Section, category: String) -> void:
	var dice_values = DiceResults.values
	print("[ScoreCardUI] Go Broke mode - scoring", category, "with dice:", dice_values)
	
	# Emit signal before scoring to allow PowerUps to prepare
	print("[ScoreCardUI] Emitting about_to_score signal for Go Broke...")
	about_to_score.emit(section, category, dice_values)
	print("[ScoreCardUI] about_to_score signal emitted for Go Broke")
	
	# Verify the category is open (hasn't been scored yet)
	var has_existing_score = scorecard.lower_scores[category] != null
	if has_existing_score:
		print("[ScoreCardUI] Cannot use Go Broke on already scored category")
		show_invalid_score_feedback(category)
		return
	
	# Use scorecard's on_category_selected to properly apply normal scoring rules
	scorecard.on_category_selected(section, category)
	
	# Get the score for display (this is now already set by on_category_selected)
	var score = scorecard.lower_scores[category]
	
	print("[ScoreCardUI] Go Broke final score set:", score)
	
	if score == null:
		print("[ScoreCardUI] Invalid Go Broke score calculation")
		show_invalid_score_feedback(category)
		return

	# Check for Yahtzee bonus
	scorecard.check_bonus_yahtzee(dice_values)
	
	# Update UI
	update_all()
	turn_scored = true
	disable_all_score_buttons()
	
	# Create logbook entry for Go Broke usage
	create_logbook_entry(section, category, dice_values, score)
	
	emit_signal("hand_scored")
	
	# Update ExtraInfo with recent logbook entries
	update_extra_info_with_logbook()
	
	print("[ScoreCardUI] Go Broke completed for", category, "with score:", score)

## _calculate_best_score_for_dice(dice_values)
##
## Calculates the highest possible score for the current dice across all categories
func _calculate_best_score_for_dice(dice_values: Array[int]) -> int:
	print("[ScoreCardUI] DEBUG: _calculate_best_score_for_dice() called - SPECIAL MODE USAGE TRACKING")
	var best_score = 0
	
	# Check all possible categories and find the highest score
	var all_categories = []
	all_categories.append_array(scorecard.upper_scores.keys())
	all_categories.append_array(scorecard.lower_scores.keys())
	
	for category in all_categories:
		var category_score = scorecard.evaluate_category(category, dice_values)
		if category_score > best_score:
			best_score = category_score
			
	print("[ScoreCardUI] Best possible score for dice", dice_values, "is:", best_score)
	return best_score

## _on_score_assigned_from_scorecard(section, category, score)
##
## Called when the Scorecard emits score_assigned signal (for autoscoring)
func _on_score_assigned_from_scorecard(section: Scorecard.Section, category: String, score: int) -> void:
	print("[ScoreCardUI] Score assigned from scorecard:", section, category, score)
	manual_score.emit() # Create a new signal to update the game_button_ui so we can disable the dice locking
	# Update UI to reflect the new score
	update_all()
	

	# NOTE: Do NOT emit hand_scored signal here for autoscoring
	# GameButtonUI handles roll button state directly in _on_next_turn_button_pressed()
	# Emitting hand_scored would disable the roll button prematurely

## _on_score_auto_assigned(section, category, score, breakdown_info)
##
## Called when the Scorecard emits score_auto_assigned signal (specifically for autoscoring)
## Creates logbook entries for automatically scored hands
func _on_score_auto_assigned(section: Scorecard.Section, category: String, score: int, breakdown_info: Dictionary) -> void:
	print("[ScoreCardUI] DEBUG: _on_score_auto_assigned called for", category, "with score", score)
	print("[ScoreCardUI] DEBUG: Breakdown PowerUps:", breakdown_info.get("active_powerups", []))
	print("[ScoreCardUI] DEBUG: Breakdown Consumables:", breakdown_info.get("active_consumables", []))
	
	_screen_shaker(score, 100)

	# Get current dice values for the logbook entry
	var dice_values: Array[int] = []
	if DiceResults and DiceResults.values:
		dice_values = DiceResults.values.duplicate()
		print("[ScoreCardUI] DEBUG: Got dice values from DiceResults:", dice_values)
	else:
		print("[ScoreCardUI] DEBUG: No dice values available from DiceResults")
	
	# Create logbook entry for the auto-scored hand using the passed breakdown info
	if dice_values.size() > 0:
		print("[ScoreCardUI] DEBUG: Creating logbook entry for auto-scored hand")
		_create_logbook_entry_with_breakdown(section, category, dice_values, score, breakdown_info)
	else:
		print("[ScoreCardUI] DEBUG: Skipping logbook entry - no dice values")
	
	# Update ExtraInfo with recent logbook entries
	update_extra_info_with_logbook()
	
	# Note: GameController will be notified via scorecard.score_assigned signal connection

## _on_score_changed_from_scorecard(total_score)
##
## Called when the Scorecard emits score_changed signal
func _on_score_changed_from_scorecard(total_score: int) -> void:
	print("[ScoreCardUI] Score changed from scorecard. New total:", total_score)
	# Update UI to reflect the new total
	update_all()


# ============================================================================
# SCORE BREAKDOWN PANEL METHODS
# ============================================================================

## _apply_score_breakdown_theme()
##
## Apply custom theme with UI_BACKGROUND texture to score breakdown labels
func _apply_score_breakdown_theme() -> void:
	var custom_theme = load("res://Resources/UI/score_breakdown_theme.tres") as Theme
	if custom_theme:
		if additive_score_label:
			additive_score_label.theme = custom_theme
			print("[ScoreCardUI] Applied custom theme to additive label")
		if multiplier_score_label:
			multiplier_score_label.theme = custom_theme
			print("[ScoreCardUI] Applied custom theme to multiplier label")
	else:
		push_error("[ScoreCardUI] Failed to load score_breakdown_theme.tres")


## _reset_score_breakdown_labels()
##
## Reset additive and multiplier labels to default values
func _reset_score_breakdown_labels() -> void:
	if additive_score_label:
		additive_score_label.text = "+0"
		additive_score_label.modulate = Color.WHITE
	if multiplier_score_label:
		multiplier_score_label.text = "x1.0"
		multiplier_score_label.modulate = Color.WHITE


## update_additive_score_panel(additive_value, animate)
##
## Update the additive score panel label with optional bounce animation.
## Called by ScoringAnimationController during animation sequence.
func update_additive_score_panel(additive_value: int, animate: bool = true) -> void:
	if not additive_score_label:
		return
	
	print("[ScoreCardUI] Updating additive panel: %d (animate=%s)" % [additive_value, animate])
	additive_score_label.text = "+%d" % additive_value
	
	if animate:
		# Use yellow for positive values, white for zero (always bounce to show calculation step)
		var flash_color = Color.YELLOW if additive_value > 0 else Color.WHITE
		_bounce_label(additive_score_label, flash_color)


## update_multiplier_score_panel(multiplier_value, animate)
##
## Update the multiplier score panel label with optional bounce animation.
## Called by ScoringAnimationController during animation sequence.
func update_multiplier_score_panel(multiplier_value: float, animate: bool = true) -> void:
	if not multiplier_score_label:
		return
	
	print("[ScoreCardUI] Updating multiplier panel: %.1f (animate=%s)" % [multiplier_value, animate])
	multiplier_score_label.text = "x%.1f" % multiplier_value
	
	if animate:
		# Use cyan for values > 1.0, white for 1.0 (always bounce to show multiplication step)
		var flash_color = Color.CYAN if multiplier_value > 1.0 else Color.WHITE
		_bounce_label(multiplier_score_label, flash_color)


## _bounce_label(label, flash_color)
##
## Apply a bouncy animation to a label with color flash
## Always returns label to Vector2(1,1) scale to respect minimum size constraints
func _bounce_label(label: Label, flash_color: Color) -> void:
	if not label:
		return
	
	var tween = create_tween()
	# Always use Vector2(1,1) as base scale to avoid compounding and respect minimum size
	var base_scale = Vector2(1.0, 1.0)
	
	# Flash color
	label.modulate = flash_color
	
	# Scale up then down (bounce effect) - always return to 1,1
	tween.tween_property(label, "scale", base_scale * 1.3, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "scale", base_scale, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	
	# Fade color back to white
	tween.parallel().tween_property(label, "modulate", Color.WHITE, 0.4)


## animate_total_score_bounce(new_score)
##
## Animate the total score label with a bounce effect when score changes.
## Called after all scoring animations complete.
func animate_total_score_bounce(new_score: int) -> void:
	if not total_score_label:
		return
	
	print("[ScoreCardUI] Animating total score bounce for:", new_score)
	
	var tween = create_tween()
	var original_scale = total_score_label.scale
	
	# Flash gold color
	total_score_label.modulate = Color(1.0, 0.84, 0.0)  # Gold
	
	# Scale up and down with bounce
	tween.tween_property(total_score_label, "scale", original_scale * 1.2, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(total_score_label, "scale", original_scale, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	
	# Fade back to white
	tween.parallel().tween_property(total_score_label, "modulate", Color.WHITE, 0.5)


## animate_total_score_panel_bounce()
##
## Animate the entire total score panel with a bounce effect
func animate_total_score_panel_bounce() -> void:
	if not total_score_panel:
		return
	
	var tween = create_tween()
	var original_scale = total_score_panel.scale
	
	# Subtle bounce on the panel
	tween.tween_property(total_score_panel, "scale", original_scale * 1.05, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(total_score_panel, "scale", original_scale, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)


## get_score_panel_position()
##
## Return the global position of the total score panel for floating number placement
func get_score_panel_position() -> Vector2:
	if total_score_panel:
		return total_score_panel.global_position + (total_score_panel.size / 2)
	return Vector2.ZERO


## prepare_for_scoring_animation()
##
## Reset breakdown labels before a scoring animation begins
func prepare_for_scoring_animation() -> void:
	_reset_score_breakdown_labels()
