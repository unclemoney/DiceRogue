extends Control
class_name ScoreCardUI

var scorecard: Scorecard
var category_buttons := {}
var category_labels := {}
var turn_scored := false
var reroll_active := false
var upper_section_buttons := {}
var lower_section_buttons := {}
var section_buttons := {} # Add this line to declare the section_buttons dictionary

signal hand_scored
signal score_rerolled(section: Scorecard.Section, category: String, score: int)
signal score_doubled(section: Scorecard.Section, category: String, new_score: int)

@onready var best_hand_label: RichTextLabel = $BestHandScore
@onready var upper_total_label: Label = $HBoxContainer/UpperVBoxContainer/UpperGridContainer/UpperSubTotal/UppersubButton
@onready var upper_bonus_label: Label = $HBoxContainer/UpperVBoxContainer/UpperGridContainer/UpperBonus/UpperBonusLabel
@onready var upper_final_total_label: Label = $HBoxContainer/UpperVBoxContainer/UpperGridContainer/UpperTotal/UpperTotalLabel
@onready var lower_total_label: Label = $HBoxContainer/LowerVBoxContainer/LowerGridContainer/LowerTotal/LowerTotalLabel
@onready var total_score_label: RichTextLabel = $RichTextTotalScore
@onready var yahtzee_bonus_label: Label = $HBoxContainer/LowerVBoxContainer/LowerGridContainer/YahtzeeBonus/YahtzeeBonusLabel

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

func _ready():
	# Add to existing _ready function
	best_hand_label = get_node_or_null("BestHandScore")
	if not best_hand_label:
		push_error("BestHandScore RichTextLabel not found!")
		
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
	
	# Remove or comment out from _ready():
	# if scorecard:
	#     DiceResults.set_scorecard(scorecard)
	# else:
	#     push_error("[ScoreCardUI] No scorecard reference to set in DiceResults")

func bind_scorecard(sc: Scorecard):
	scorecard = sc
	update_all()
	connect_buttons()
	# Connect to bonus signals
	scorecard.upper_bonus_achieved.connect(_on_upper_bonus_achieved)
	scorecard.upper_section_completed.connect(_on_upper_section_completed)
	scorecard.lower_section_completed.connect(_on_lower_section_completed)
	scorecard.yahtzee_bonus_achieved.connect(_on_yahtzee_bonus_achieved)
	
	# Set scorecard in DiceResults
	DiceResults.set_scorecard(scorecard)

func update_all():
	for category in scorecard.upper_scores.keys():
		var label_path = "HBoxContainer/UpperVBoxContainer/UpperGridContainer/" + category.capitalize() + "Container/" + category.capitalize() + "Label"
		var label = get_node_or_null(label_path)
		if label:
			var value = scorecard.upper_scores[category]
			label.text = str(value if value != null else "-")

	for category in scorecard.lower_scores.keys():
		var node_name = LOWER_CATEGORY_NODE_NAMES.get(category, category.capitalize())
		var label_path = "HBoxContainer/LowerVBoxContainer/LowerGridContainer/" + node_name + "/" + node_name + "Label"
		var label = get_node_or_null(label_path)
		if label:
			var value = scorecard.lower_scores[category]
			label.text = str(value if value != null else "-")

	# Update upper section totals with debug prints
	var upper_subtotal = scorecard.get_upper_section_total()
	
	if upper_total_label:
		upper_total_label.text = str(upper_subtotal)
	else:
		push_error("upper_total_label not found!")
		
	# Show progress towards bonus
	if upper_bonus_label:
		if scorecard.is_upper_section_complete():
			if upper_subtotal >= Scorecard.UPPER_BONUS_THRESHOLD:
				upper_bonus_label.text = str(Scorecard.UPPER_BONUS_AMOUNT)
			else:
				upper_bonus_label.text = "0"
		else:
			var remaining = Scorecard.UPPER_BONUS_THRESHOLD - upper_subtotal
			upper_bonus_label.text = "Need " + str(remaining)
	else:
		push_error("upper_bonus_label not found!")
	
	# Update final upper total (subtotal + bonus)
	if upper_final_total_label:
		var final_total = scorecard.get_upper_section_final_total()
		upper_final_total_label.text = str(final_total)
	else:
		push_error("upper_final_total_label not found!")

	# Update lower section total - Add Yahtzee bonus points
	var lower_total = scorecard.get_lower_section_total()
	lower_total += scorecard.yahtzee_bonus_points  # Add Yahtzee bonus to lower total
	
	if lower_total_label:
		lower_total_label.text = str(lower_total)
	else:
		push_error("lower_total_label not found!")
	
	# Update total score with dynamic effect
	if total_score_label:
		var upper_total = scorecard.get_upper_section_final_total()
		var total_score = upper_total + lower_total  # lower_total already includes Yahtzee bonus
		
		# Remap the score (0-500) to frequency range (1-10)
		var freq = remap(total_score, 0, 500, 1.0, 10.0)
		
		# Format with BBCode, including dynamic frequency and bonus info
		var text = "[center][tornado freq=%0.1f sat=0.8 val=1.9]Total Score: %d" % [freq, total_score]
		
		# Add bonus info if there are any Yahtzee bonuses
		#if scorecard.yahtzee_bonuses > 0:
		#	text += "\n(includes %d Yahtzee bonus%s)" % [
		#		scorecard.yahtzee_bonus_points,
		#		"es" if scorecard.yahtzee_bonuses > 1 else ""
		#	]
		
		text += "[/tornado][/center]"
		total_score_label.text = text
		
		# Adjust font size based on score
		var base_size = 32
		var size_scale = remap(total_score, 0, 500, 1.0, 1.5)
		total_score_label.add_theme_font_size_override("normal_font_size", base_size * size_scale)

	# Update Yahtzee bonus display
	if yahtzee_bonus_label:
		if scorecard.yahtzee_bonuses > 0:
			yahtzee_bonus_label.text = str(scorecard.yahtzee_bonus_points)
		else:
			yahtzee_bonus_label.text = "-"

func _on_upper_bonus_achieved(bonus: int) -> void:
	# Animate the bonus achievement and update totals
	if upper_bonus_label:
		var tween = create_tween()
		tween.tween_property(upper_bonus_label, "modulate", Color.YELLOW, 0.3)
		tween.tween_property(upper_bonus_label, "modulate", Color.WHITE, 0.3)
		
		# Update the final total label with animation
		if upper_final_total_label:
			var final_total = scorecard.get_upper_section_final_total()
			tween.tween_property(upper_final_total_label, "modulate", Color.YELLOW, 0.3)
			upper_final_total_label.text = str(final_total)
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
	print("[ScoreCardUI] Category selected:", category)
	print("[ScoreCardUI] Double mode active:", is_double_mode)
	
	# Check if we're in double mode
	if is_double_mode:
		_handle_double_score(section, category)
		return
	
	# Check if this category already has a score
	var existing_score = null
	match section:
		Scorecard.Section.UPPER:
			existing_score = scorecard.upper_scores.get(category)
		Scorecard.Section.LOWER:
			existing_score = scorecard.lower_scores.get(category)
			
	if existing_score != null and not reroll_active:
		show_invalid_score_feedback(category)
		return
		
	if reroll_active:
		handle_score_reroll(section, category)
		return
		
	if turn_scored:
		return

	var values = DiceResults.values
	print("\n=== Processing Score Selection ===")
	print("[ScoreCardUI] Category:", category)
	print("[ScoreCardUI] Dice values:", values)
	
	# Get the score through scorecard's evaluate_category to apply multipliers
	var score = scorecard.evaluate_category(category, values)
	print("[ScoreCardUI] Final calculated score:", score)
	
	if score == null:
		print("[ScoreCardUI] Invalid score calculation")
		show_invalid_score_feedback(category)
		return

	# Check for Yahtzee bonus
	scorecard.check_bonus_yahtzee(values)
	
	# Set the selected category's score
	print("[ScoreCardUI] Setting score for", category, "to:", score)
	scorecard.set_score(section, category, score)
	update_all()
	turn_scored = true
	disable_all_score_buttons()
	emit_signal("hand_scored")

func disable_all_score_buttons():
	for button in upper_section_buttons.values():
		button.disabled = true
	for button in lower_section_buttons.values():
		button.disabled = true

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

	var best_score := -1
	var best_section
	var best_category := ""
	
	# Check upper section
	for category in scorecard.upper_scores.keys():
		if scorecard.upper_scores[category] == null:
			var score = scorecard.evaluate_category(category, dice_values)
			if score > best_score:
				best_score = score
				best_section = Scorecard.Section.UPPER
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
				best_section = Scorecard.Section.LOWER
				best_category = category
	
	# ...rest of existing display code...

	if best_category != "":
		var display_category = best_category.capitalize().replace("_", " ")
		
		# Add special formatting for exceptional scores
		var base_text = "Best: %s (%d)" % [display_category, best_score]
		var format_text = ""
		
		if best_category == "yahtzee" and best_score >= 50:
			format_text = "[center][rainbow freq=1.2 sat=0.8 val=2.0]%s[/rainbow][/center]" % base_text
		elif best_score > 30:  # For high-scoring hands
			format_text = "[center][tornado freq=2.5 sat=0.9 val=2.0]%s[/tornado][/center]" % base_text
		else:
			format_text = "[center][tornado freq=1.9 sat=0.8 val=1.9]%s[/tornado][/center]" % base_text
			
		best_hand_label.add_theme_font_size_override("normal_font_size", 32)
		best_hand_label.text = format_text
		animate_best_hand_label()

				# Scale shake intensity with score value
		var screen_shake = get_tree().root.find_child("ScreenShake", true, false)
		var shake_intensity = remap(best_score, 0, 100, 0.1, 1.0)
		print("Shake intensity:", shake_intensity, " for score:", best_score)
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
	emit_signal("hand_scored")
	emit_signal("score_rerolled", section, category, score)

func _on_yahtzee_bonus_achieved(points: int) -> void:
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

func _on_score_button_pressed(section: Scorecard.Section, category: String) -> void:
	if is_double_mode:
		_handle_double_score(section, category)
		return
		
	# Existing score button handling...
	
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
