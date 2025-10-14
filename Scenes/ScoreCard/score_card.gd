extends Node
class_name Scorecard

enum Section { UPPER, LOWER }

const UPPER_BONUS_THRESHOLD := 63
const UPPER_BONUS_AMOUNT := 35

signal upper_bonus_achieved(bonus: int)
signal upper_section_completed
signal lower_section_completed
signal score_auto_assigned(section: Section, category: String, score: int)
signal score_assigned(section: Section, category: String, score: int)  # New signal for all score assignments
signal yahtzee_bonus_achieved(points: int)
signal score_changed(total_score: int)  # Add this signal
signal game_completed(final_score: int) # Add this signal

var upper_bonus := 0  # Add this to track the bonus
var upper_bonus_awarded := false  # Track if bonus has been awarded
var yahtzee_bonuses := 0  # Track number of bonus yahtzees
var yahtzee_bonus_points := 0  # Track total bonus points

var upper_scores := {
	"ones": null,
	"twos": null,
	"threes": null,
	"fours": null,
	"fives": null,
	"sixes": null
}

var lower_scores := {
	"three_of_a_kind": null,
	"four_of_a_kind": null,
	"full_house": null,
	"small_straight": null,
	"large_straight": null,
	"yahtzee": null,
	"chance": null
}

var _score_multiplier_func: Callable  # DEPRECATED: Use ScoreModifierManager instead
var score_modifiers: Array = [] # Array to hold score modifier objects
var score_multiplier: float = 1.0  # DEPRECATED: Use ScoreModifierManager instead

func _ready() -> void:
	add_to_group("scorecard")
	print("[Scorecard] Ready - Added to 'scorecard' group")


func register_score_modifier(modifier: Object) -> void:
	if not score_modifiers.has(modifier):
		score_modifiers.append(modifier)
		print("[Scorecard] Registered score modifier:", modifier.name)

func unregister_score_modifier(modifier: Object) -> void:
	if score_modifiers.has(modifier):
		score_modifiers.erase(modifier)
		print("[Scorecard] Unregistered score modifier:", modifier.name)

func set_score(section: int, category: String, score: int) -> void:
	print("\n=== Setting Score ===")
	print("[Scorecard] Setting", category, "to", score)
	print("[Scorecard] Current total before change:", get_total_score())
	
	# Apply score modifiers from old system first
	var modified_score = score
	for modifier in score_modifiers:
		if modifier.has_method("modify_score"):
			var result = modifier.modify_score(section, category, modified_score)
			if result != null:
				modified_score = result
				print("[Scorecard] Score modified by", modifier.name, "to:", modified_score)
	
	# Now apply ScoreModifierManager additives and multipliers
	var modifier_manager = null
	if Engine.has_singleton("ScoreModifierManager"):
		modifier_manager = ScoreModifierManager
	elif get_tree():
		modifier_manager = get_tree().get_first_node_in_group("score_modifier_manager")
		if not modifier_manager:
			modifier_manager = get_tree().get_first_node_in_group("multiplier_manager")
	
	if modifier_manager:
		var total_additive = 0
		var total_multiplier = 1.0
		
		if modifier_manager.has_method("get_total_additive"):
			total_additive = modifier_manager.get_total_additive()
		total_multiplier = modifier_manager.get_total_multiplier()
		
		# Apply additive bonuses first, then multipliers
		var score_with_additive = modified_score + total_additive
		var final_modified_score = int(ceil(score_with_additive * total_multiplier))
		
		print("[Scorecard] Base score:", modified_score)
		print("[Scorecard] Total additive bonus:", total_additive)
		print("[Scorecard] Score after additive:", score_with_additive)
		print("[Scorecard] Total multiplier:", total_multiplier)
		print("[Scorecard] Score before rounding:", int(score_with_additive * total_multiplier))
		print("[Scorecard] Final modified score (rounded up):", final_modified_score)
		
		modified_score = final_modified_score
	else:
		print("[Scorecard] Warning: No ScoreModifierManager found, using base score")
	
	if modified_score != score:
		print("[Scorecard] Final modified score:", modified_score, "(was", score, ")")
	
	match section:
		Section.UPPER:
			if upper_scores.has(category):
				var old_value = upper_scores[category]
				upper_scores[category] = modified_score
				print("[Scorecard] Updated upper score:", category, "from", old_value, "to", modified_score)
			else:
				push_error("[Scorecard] Invalid upper category: " + category)
				return
		Section.LOWER:
			if lower_scores.has(category):
				var old_value = lower_scores[category]
				lower_scores[category] = modified_score
				print("[Scorecard] Updated lower score:", category, "from", old_value, "to", modified_score)
			else:
				push_error("[Scorecard] Invalid lower category: " + category)
				return
	
	var new_total = get_total_score()
	print("[Scorecard] New total score:", new_total)
	
	# Emit the score_assigned signal for tracking purposes
	emit_signal("score_assigned", section, category, modified_score)
	
	# Track statistics with RollStats singleton
	_track_combination_stats(category, modified_score)
	
	# Check for upper bonus after updating scores
	check_upper_bonus()
	
	# Check for bonus yahtzee if this was a yahtzee category
	if category == "yahtzee" and modified_score == 50:
		# This is the initial yahtzee, bonus yahtzees will be handled separately
		print("[Scorecard] Initial Yahtzee scored!")
		RollStats.track_yahtzee_rolled()
	
	# Always emit score_changed signal
	emit_signal("score_changed", new_total)
	
	print("[Scorecard] Score setting complete")
	print("===============================")

func has_any_scores() -> bool:
	# Check upper section
	for score in upper_scores.values():
		if score != null:
			print("[Scorecard] Found scored category in upper section")
			return true
			
	# Check lower section
	for score in lower_scores.values():
		if score != null:
			print("[Scorecard] Found scored category in lower section")
			return true
			
	return false

func get_total_score() -> int:
	var total := get_upper_section_final_total() + get_lower_section_total()
	return total + yahtzee_bonus_points

func get_upper_section_total() -> int:
	var total := 0
	for score in upper_scores.values():
		if score != null:
			total += score
	return total

func get_lower_section_total() -> int:
	var total := 0
	for score in lower_scores.values():
		if score != null:
			total += score
	return total

func on_category_selected(section: Section, category: String):
	var values = DiceResults.values
	var score = ScoreEvaluatorSingleton.calculate_score_for_category(category, values)
	set_score(section, category, score)

func auto_score_best(values: Array[int]) -> void:
	print("\n=== Auto-Scoring Best Hand ===")
	# Reset evaluation counter
	ScoreEvaluatorSingleton.reset_evaluation_count()
	
	var best_score := -1
	var best_section
	var best_category := ""
	
	# Check upper section first
	for category in upper_scores.keys():
		if upper_scores[category] == null:
			# Pass the actual dice values to evaluate_category
			var score = evaluate_category(category, values)
			print("[Scorecard] Evaluating upper category:", category, "score:", score)
			if score > best_score:
				best_score = score
				best_section = Section.UPPER
				best_category = category
	
	# Check lower section next
	for category in lower_scores.keys():
		if lower_scores[category] == null:
			# Pass the actual dice values to evaluate_category
			var score = evaluate_category(category, values)
			print("[Scorecard] Evaluating lower category:", category, "score:", score)
			if score > best_score:
				best_score = score
				best_section = Section.LOWER
				best_category = category
	
	if best_category != "":
		print("[Scorecard] Auto-scoring category:", best_category, "with score:", best_score)
		var is_new_yahtzee = (best_category == "yahtzee" and best_score == 50)
		set_score(best_section, best_category, best_score)
		# This will trigger the bonus Yahtzee check if applicable
		check_bonus_yahtzee(values, is_new_yahtzee)
		emit_signal("score_auto_assigned", best_section, best_category, best_score)
	else:
		print("[Scorecard] No valid scoring categories found!")

func get_upper_section_final_total() -> int:
	var subtotal = get_upper_section_total()
	if is_upper_section_complete() and subtotal >= UPPER_BONUS_THRESHOLD:
		return subtotal + UPPER_BONUS_AMOUNT
	return subtotal

func is_upper_section_complete() -> bool:
	for score in upper_scores.values():
		if score == null:
			return false
	return true

func is_lower_section_complete() -> bool:
	for score in lower_scores.values():
		if score == null:
			return false
	return true

func check_lower_section() -> void:
	if is_lower_section_complete():
		emit_signal("lower_section_completed")

func check_upper_bonus() -> void:
	if not is_upper_section_complete():
		return
	
	var total = get_upper_section_total()
	
	if total >= UPPER_BONUS_THRESHOLD and not upper_bonus_awarded:
		upper_bonus = UPPER_BONUS_AMOUNT  # Store the bonus
		upper_bonus_awarded = true  # Mark as awarded
		emit_signal("upper_bonus_achieved", UPPER_BONUS_AMOUNT)
		RollStats.track_upper_bonus()
	elif total < UPPER_BONUS_THRESHOLD:
		upper_bonus = 0
		upper_bonus_awarded = false  # Reset if somehow total drops below threshold
	
	emit_signal("upper_section_completed")

func check_bonus_yahtzee(values: Array[int], is_new_yahtzee: bool = false) -> void:
	# Only check if we already have a yahtzee scored as 50
	if is_new_yahtzee:
		return
	if lower_scores["yahtzee"] != 50:
		return
		
	# Use ScoreEvaluator to check for Yahtzee with wildcards
	if ScoreEvaluatorSingleton.is_yahtzee(values):
		yahtzee_bonuses += 1
		yahtzee_bonus_points += 100
		emit_signal("yahtzee_bonus_achieved", 100)
		emit_signal("score_changed", get_total_score())  # Add this line
		RollStats.track_yahtzee_bonus()
	else:
		print("✗ Not a Yahtzee - no bonus awarded")

# DEPRECATED: Use ScoreModifierManager.register_multiplier() instead
# Fix the set_score_multiplier function - make sure it properly registers the Callable
func set_score_multiplier(multiplier_value) -> void:
	push_warning("[Scorecard] set_score_multiplier is DEPRECATED. Use ScoreModifierManager.register_multiplier() instead.")
	print("[Scorecard] Setting score multiplier with type:", typeof(multiplier_value))
	
	if multiplier_value is float or multiplier_value is int:
		print("[Scorecard] Setting score multiplier to:", multiplier_value)
		score_multiplier = float(multiplier_value)
		# Clear any callable multiplier when using a direct value
		_score_multiplier_func = Callable()
		print("[Scorecard] Direct multiplier set, cleared any multiplier function")
	elif multiplier_value is Callable:
		print("[Scorecard] Setting score multiplier function:", multiplier_value)
		_score_multiplier_func = multiplier_value
		# Print debug info to verify it's valid
		print("[Scorecard] Function is valid:", _score_multiplier_func.is_valid())
		print("[Scorecard] Function target:", _score_multiplier_func.get_object())
		# Reset the direct multiplier when using a function
		score_multiplier = 1.0
		print("[Scorecard] Multiplier function set, reset direct multiplier to 1.0")
	else:
		push_error("[Scorecard] Invalid multiplier type: " + str(typeof(multiplier_value)))

# DEPRECATED: Use ScoreModifierManager instead
func clear_score_multiplier() -> void:
	push_warning("[Scorecard] clear_score_multiplier is DEPRECATED. Use ScoreModifierManager.unregister_multiplier() instead.")
	_score_multiplier_func = Callable()

func is_game_complete() -> bool:
	return is_upper_section_complete() and is_lower_section_complete()


func reset_scores() -> void:
	print("[Scorecard] Resetting all scores")
	
	# Reset upper section scores
	for category in upper_scores.keys():
		upper_scores[category] = null
	
	# Reset lower section scores
	for category in lower_scores.keys():
		lower_scores[category] = null
	
	# Reset bonus tracking
	upper_bonus = 0
	yahtzee_bonuses = 0
	yahtzee_bonus_points = 0
	
	# Note: Multipliers are now handled by ScoreModifierManager
	# PowerUps should manage their own multiplier lifecycle
	print("[Scorecard] All scores reset - multipliers handled by ScoreModifierManager")
	
	print("[Scorecard] All scores reset")
	
	# Emit signal with 0 score since we've reset everything
	emit_signal("score_changed", 0)

func calculate_score(category: String, dice_values: Array) -> int:
	print("[Scorecard] Calculating score for", category, "with dice:", dice_values)
	
	var base_score = _calculate_base_score(category, dice_values)
	
	# Get modifiers from ScoreModifierManager (fallback for compatibility)
	var modifier_manager = null
	if Engine.has_singleton("ScoreModifierManager"):
		modifier_manager = ScoreModifierManager
	elif get_tree():
		modifier_manager = get_tree().get_first_node_in_group("score_modifier_manager")
		# Fallback to old group name
		if not modifier_manager:
			modifier_manager = get_tree().get_first_node_in_group("multiplier_manager")
	
	var total_additive = 0
	var total_multiplier = 1.0
	
	if modifier_manager:
		if modifier_manager.has_method("get_total_additive"):
			total_additive = modifier_manager.get_total_additive()
		total_multiplier = modifier_manager.get_total_multiplier()
	else:
		# Fallback warning if no manager found
		push_warning("[Scorecard] No ScoreModifierManager found")
	
	# Apply additive bonuses first, then multipliers
	var score_with_additive = base_score + total_additive
	var final_score = int(score_with_additive * total_multiplier)
	
	print("[Scorecard] Base score:", base_score)
	print("[Scorecard] Total additive bonus:", total_additive)
	print("[Scorecard] Score after additive:", score_with_additive)
	print("[Scorecard] Total multiplier:", total_multiplier)
	print("[Scorecard] Final score after multiplier:", final_score)
	
	return final_score

# Helper function to calculate the base score
func _calculate_base_score(category: String, dice_values: Array) -> int:
	# Use the ScoreEvaluator to calculate the base score
	return ScoreEvaluatorSingleton.calculate_score_for_category(category, dice_values)

func evaluate_category(category: String, values: Array[int]) -> int:
	print("\n=== Scorecard Category Evaluation ===")
	print("[Scorecard] Evaluating category:", category)
	print("[Scorecard] Values array size:", values.size())
	print("[Scorecard] Values:", values)
	
	# Additional safety check
	if values.size() == 0:
		print("[Scorecard] Warning: Empty values array!")
		return 0
	
	# Reset evaluation counter
	ScoreEvaluatorSingleton.reset_evaluation_count()
	var scores = ScoreEvaluatorSingleton.evaluate_with_wildcards(values)
	var score = scores.get(category, 0)
	print("[Scorecard] Base score before multiplier:", score)
	
	# Get total multiplier from ScoreModifierManager
	var total_multiplier = ScoreModifierManager.get_total_multiplier()
	print("[Scorecard] Total multiplier from ScoreModifierManager:", total_multiplier)
	
	# Handle conditional multipliers like FoursomePowerUp
	if ScoreModifierManager.has_multiplier("foursome"):
		# Check if current dice have a 4, and update FoursomePowerUp accordingly
		var foursome_nodes = get_tree().get_nodes_in_group("power_ups")
		for node in foursome_nodes:
			if node is FoursomePowerUp:
				node.update_multiplier_for_dice(values)
				break
		# Recalculate total multiplier after potential update
		total_multiplier = ScoreModifierManager.get_total_multiplier()
		print("[Scorecard] Updated total multiplier after foursome check:", total_multiplier)
	
	# Apply the final multiplier
	var final_score = int(score * total_multiplier)
	print("[Scorecard] Final score after multiplier:", final_score)
	
	return final_score

# DEPRECATED: Debug function for old multiplier system
func debug_multiplier_function() -> void:
	push_warning("[Scorecard] debug_multiplier_function is DEPRECATED. Use ScoreModifierManager.debug_print_state() instead.")
	print("\n=== Testing OLD Scorecard Multiplier Function (DEPRECATED) ===")
	print("[Scorecard] Has multiplier function:", _score_multiplier_func.is_valid())
	if _score_multiplier_func.is_valid():
		print("[Scorecard] Multiplier function object:", _score_multiplier_func.get_object())
		print("[Scorecard] Multiplier function method:", _score_multiplier_func.get_method())
		
		# Try a test call
		var test_result = _score_multiplier_func.call("test_category", 10, [4, 3, 2, 1])
		print("[Scorecard] Test call result:", test_result)
	else:
		print("[Scorecard] No valid multiplier function set")

## Track combination statistics based on category and score
func _track_combination_stats(category: String, score: int) -> void:
	# Only track if a valid score was achieved (> 0)
	if score <= 0:
		return
	
	match category:
		"three_of_a_kind":
			RollStats.track_three_of_a_kind()
		"four_of_a_kind":
			RollStats.track_four_of_a_kind()
		"full_house":
			if score == 25:  # Standard full house score
				RollStats.track_full_house()
		"small_straight":
			if score == 30:  # Standard small straight score
				RollStats.track_small_straight()
		"large_straight":
			if score == 40:  # Standard large straight score
				RollStats.track_large_straight()
		# Note: Yahtzee tracking is handled separately in set_score function
	
	# Show the new system
	print("\n=== NEW ScoreModifierManager State ===")
	ScoreModifierManager.debug_print_state()
