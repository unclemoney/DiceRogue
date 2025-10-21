extends Node
class_name Scorecard

enum Section { UPPER, LOWER }

const UPPER_BONUS_THRESHOLD := 63
const UPPER_BONUS_AMOUNT := 35

signal upper_bonus_achieved(bonus: int)
signal upper_section_completed
signal lower_section_completed
signal score_auto_assigned(section: Section, category: String, score: int, breakdown_info: Dictionary)
signal score_assigned(section: Section, category: String, score: int)  # New signal for all score assignments
signal yahtzee_bonus_achieved(points: int)
signal score_changed(total_score: int)  # Add this signal
signal game_completed(final_score: int) # Add this signal

var upper_bonus := 0  # Add this to track the bonus
var upper_bonus_awarded := false  # Track if bonus has been awarded
var yahtzee_bonuses := 0  # Track number of bonus yahtzees
var yahtzee_bonus_points := 0  # Track total bonus points

# Debug counter for calculate_score calls
var calculate_score_call_count := 0

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
	
	# Apply legacy score modifiers if any exist (for backward compatibility)
	var final_score = score
	for modifier in score_modifiers:
		if modifier.has_method("modify_score"):
			var result = modifier.modify_score(section, category, final_score)
			if result != null:
				final_score = result
				print("[Scorecard] Score modified by legacy modifier", modifier.name, "to:", final_score)
	
	# Note: Modern multipliers and additives are already applied in calculate_score_internal()
	# set_score() just stores the final calculated score - no further modifications needed
	
	print("[Scorecard] Storing final score:", final_score, "for category:", category)
	
	match section:
		Section.UPPER:
			if upper_scores.has(category):
				var old_value = upper_scores[category]
				upper_scores[category] = final_score
				print("[Scorecard] Updated upper score:", category, "from", old_value, "to", final_score)
			else:
				push_error("[Scorecard] Invalid upper category: " + category)
				return
		Section.LOWER:
			if lower_scores.has(category):
				var old_value = lower_scores[category]
				lower_scores[category] = final_score
				print("[Scorecard] Updated lower score:", category, "from", old_value, "to", final_score)
			else:
				push_error("[Scorecard] Invalid lower category: " + category)
				return
	
	var new_total = get_total_score()
	print("[Scorecard] New total score:", new_total)
	
	# Emit the score_assigned signal for tracking purposes
	emit_signal("score_assigned", section, category, final_score)
	
	# Track statistics with RollStats singleton
	_track_combination_stats(category, final_score)
	
	# Check for upper bonus after updating scores
	check_upper_bonus()
	
	# Check for bonus yahtzee if this was a yahtzee category
	if category == "yahtzee" and final_score == 50:
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
	print("\n=== SCORECARD CATEGORY SELECTED ===")
	print("[Scorecard] *** DIRECT SCORECARD CALL *** on_category_selected")
	print("[Scorecard] Section:", section, "Category:", category)
	
	var values = DiceResults.values
	print("[Scorecard] Dice values:", values)
	
	# Note: about_to_score signal should have been emitted by ScoreCardUI already
	# Do NOT emit it again here to avoid double signal processing
	
	var score = calculate_score_internal(category, values, true)  # Apply money effects when actually scoring
	set_score(section, category, score)

func auto_score_best(values: Array[int]) -> void:
	print("\n=== Auto-Scoring Best Hand ===")
	# Reset evaluation counter at the start of each auto-scoring cycle
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
		
		# Calculate color effects NOW before dice state changes
		var dice_hand = get_tree().get_first_node_in_group("dice_hand")
		var color_effects = {}
		if dice_hand and dice_hand.has_method("get_color_effects"):
			color_effects = dice_hand.get_color_effects()
		
		# Emit about_to_score signal for PowerUps BEFORE calculating final score
		var game_controller = get_tree().get_first_node_in_group("game_controller")
		if game_controller and game_controller.score_card_ui:
			print("[Scorecard] Emitting about_to_score signal for autoscoring:", best_category)
			game_controller.score_card_ui.about_to_score.emit(best_section, best_category, values)
		
		# IMMEDIATELY update scorecard to prevent display issues
		# Calculate final score with money effects and multipliers using preserved dice state
		var final_score_with_money = _calculate_score_with_preserved_effects(best_category, values, true, color_effects)
		print("[Scorecard] Final score with money effects and multipliers:", final_score_with_money)
		
		# CAPTURE BREAKDOWN INFO NOW while PowerUps are still active
		var scoring_breakdown = calculate_score_with_breakdown(best_category, values, false)
		var captured_breakdown_info = scoring_breakdown.get("breakdown_info", {})
		
		# Set score immediately so other systems see the category as filled
		set_score(best_section, best_category, final_score_with_money)
		
		# Defer only the bonus checks and signal emission to avoid timing issues
		call_deferred("_complete_auto_scoring_finalization", best_section, best_category, final_score_with_money, values, best_score == 50, captured_breakdown_info)
	else:
		print("[Scorecard] No valid scoring categories found!")

## _complete_auto_scoring_finalization(section, category, final_score, values, was_yahtzee_50, breakdown_info)
##
## Deferred finalization of auto-scoring: handles bonus checks and signal emission.
## The actual score setting now happens immediately in auto_score_best() to prevent display timing issues.
func _complete_auto_scoring_finalization(section: Section, category: String, final_score: int, values: Array[int], was_yahtzee_50: bool, breakdown_info: Dictionary = {}) -> void:
	print("[Scorecard] Finalizing auto-scoring for:", category, "with final score:", final_score)
	
	# Handle bonus Yahtzee check if applicable
	if category == "yahtzee" and was_yahtzee_50:
		check_bonus_yahtzee(values, true)
	
	print("[Scorecard] Auto-scoring breakdown - PowerUps:", breakdown_info.get("active_powerups", []))
	print("[Scorecard] Auto-scoring breakdown - Consumables:", breakdown_info.get("active_consumables", []))
	
	# Emit signal to notify other systems with the captured breakdown info
	emit_signal("score_auto_assigned", section, category, final_score, breakdown_info)

# DEPRECATED: Old method kept for reference but should not be called
func _complete_auto_scoring(_section: Section, category: String, _original_score: int, _values: Array[int], _preserved_color_effects: Dictionary = {}) -> void:
	push_warning("[Scorecard] _complete_auto_scoring is deprecated - auto-scoring now happens immediately in auto_score_best()")
	print("[Scorecard] WARNING: Deprecated _complete_auto_scoring called for:", category)

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
	
	# Reset debug counter
	calculate_score_call_count = 0
	
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
	return calculate_score_internal(category, dice_values, false)

## Internal calculate score with option to apply money effects
## @param category: String scoring category
## @param dice_values: Array dice values to score
## @param apply_money_effects: bool whether to actually add money to economy
## @return int calculated score
func calculate_score_internal(category: String, dice_values: Array, apply_money_effects: bool = false) -> int:
	var breakdown = calculate_score_with_breakdown(category, dice_values, apply_money_effects)
	return breakdown.final_score

## Calculate score with detailed breakdown information
## @param category: String scoring category 
## @param dice_values: Array dice values to score
## @param apply_money_effects: bool whether to actually add money to economy
## @return Dictionary with detailed breakdown {final_score, base_score, breakdown_info}
func calculate_score_with_breakdown(category: String, dice_values: Array, apply_money_effects: bool = false) -> Dictionary:
	calculate_score_call_count += 1
	
	var base_score = _calculate_base_score(category, dice_values)
	
	# Get dice hand to calculate color effects
	var dice_hand = get_tree().get_first_node_in_group("dice_hand")
	var color_effects = {}
	if dice_hand and dice_hand.has_method("get_color_effects"):
		color_effects = dice_hand.get_color_effects()
	
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
	var active_powerup_sources: Array[String] = []
	var active_consumable_sources: Array[String] = []
	
	if modifier_manager:
		if modifier_manager.has_method("get_total_additive"):
			total_additive = modifier_manager.get_total_additive()
		total_multiplier = modifier_manager.get_total_multiplier()
		
		# Get detailed source information for breakdown
		var all_modifier_sources = {}
		
		# Get multiplier sources and their values
		if modifier_manager.has_method("get_active_sources"):
			var multiplier_sources = modifier_manager.get_active_sources()
			for source in multiplier_sources:
				var multiplier_value = modifier_manager.get_multiplier(source) if modifier_manager.has_method("get_multiplier") else 1.0
				var source_category = _categorize_modifier_source(source)
				all_modifier_sources[source] = {
					"type": "multiplier",
					"value": multiplier_value,
					"category": source_category
				}
				
				# Add to appropriate category lists
				if all_modifier_sources[source].category == "powerup":
					active_powerup_sources.append(source)
				elif all_modifier_sources[source].category == "consumable":
					active_consumable_sources.append(source)
		
		# Get additive sources and their values
		if modifier_manager.has_method("get_active_additive_sources"):
			var additive_sources = modifier_manager.get_active_additive_sources()
			for source in additive_sources:
				var additive_value = modifier_manager.get_additive(source) if modifier_manager.has_method("get_additive") else 0
				
				# If source already exists (has both additive and multiplier), combine info
				if source in all_modifier_sources:
					all_modifier_sources[source]["additive_value"] = additive_value
				else:
					all_modifier_sources[source] = {
						"type": "additive",
						"value": additive_value,
						"category": _categorize_modifier_source(source)
					}
				
				# Add to appropriate category lists if not already there
				var source_category = all_modifier_sources[source].category
				if source_category == "powerup" and source not in active_powerup_sources:
					active_powerup_sources.append(source)
				elif source_category == "consumable" and source not in active_consumable_sources:
					active_consumable_sources.append(source)
	else:
		# Fallback warning if no manager found
		push_warning("[Scorecard] No ScoreModifierManager found")
	
	# Add dice color effects
	var dice_color_additive = color_effects.get("red_additive", 0)
	var dice_color_multiplier = color_effects.get("purple_multiplier", 1.0)
	var dice_color_money = color_effects.get("green_money", 0)
	
	# Apply calculation order: base + additives (regular + red dice) * multipliers (regular + purple dice)
	var total_additive_bonus = total_additive + dice_color_additive
	var total_multiplier_bonus = total_multiplier * dice_color_multiplier
	var score_with_additive = base_score + total_additive_bonus
	var final_score = int(score_with_additive * total_multiplier_bonus)
	
	# Create detailed breakdown information
	var breakdown_info = {
		"base_score": base_score,
		"regular_additive": total_additive,
		"dice_color_additive": dice_color_additive,
		"total_additive": total_additive_bonus,
		"regular_multiplier": total_multiplier,
		"dice_color_multiplier": dice_color_multiplier,
		"total_multiplier": total_multiplier_bonus,
		"score_after_additives": score_with_additive,
		"final_score": final_score,
		"category_display": _format_category_display_name(category),
		"active_powerups": active_powerup_sources.duplicate(),
		"active_consumables": active_consumable_sources.duplicate(),
		"dice_color_money": dice_color_money,
		"has_modifiers": (total_additive_bonus > 0 or total_multiplier_bonus != 1.0 or dice_color_money > 0)
	}
	

	
	# Only print detailed calculation if there are modifiers applied
	if apply_money_effects and breakdown_info.has_modifiers:
		print("[Scorecard] Scoring calculation for", category, ": Base:", base_score, "→ Final:", final_score)
		if total_additive_bonus > 0:
			print("  Additives: +", total_additive_bonus, " (Regular:", total_additive, " + Red:", dice_color_additive, ")")
		if total_multiplier_bonus != 1.0:
			print("  Multipliers: x", total_multiplier_bonus, " (Regular:", total_multiplier, " × Purple:", dice_color_multiplier, ")")
	
	# Apply money bonus from green dice ONLY if requested
	if apply_money_effects and dice_color_money > 0:
		PlayerEconomy.add_money(dice_color_money)
		print("[Scorecard] Applied green money bonus: +$", dice_color_money)
	
	return {
		"final_score": final_score,
		"base_score": base_score,
		"breakdown_info": breakdown_info
	}

## Format category name for display in breakdown
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

## _categorize_modifier_source()
##
## Categorize a modifier source name as powerup, consumable, or other
func _categorize_modifier_source(source_name: String) -> String:
	var lower_name = source_name.to_lower()
	
	if lower_name.contains("powerup") or lower_name.contains("power_up"):
		return "powerup"
	elif lower_name.contains("consumable"):
		return "consumable"
	elif lower_name.contains("mod"):
		return "mod"
	else:
		# Check for known PowerUp source names that don't contain "powerup"
		if lower_name in ["pin_head", "hot_streak", "lucky_seven", "double_down"]:
			return "powerup"
		# Check for known Consumable source names that don't contain "consumable"
		elif lower_name in ["score_reroll", "any_score", "duplicate"]:
			return "consumable"
		else:
			return "other"

## _calculate_score_with_preserved_effects()
##
## Calculate score using preserved color effects instead of current dice state
## This prevents autoscoring bugs when dice roll between signal and deferred call
func _calculate_score_with_preserved_effects(category: String, dice_values: Array, apply_money_effects: bool, preserved_color_effects: Dictionary) -> int:
	var base_score = _calculate_base_score(category, dice_values)
	
	# Use preserved color effects instead of querying current dice state
	var color_effects = preserved_color_effects
	
	# Get modifiers from ScoreModifierManager
	var modifier_manager = null
	if Engine.has_singleton("ScoreModifierManager"):
		modifier_manager = ScoreModifierManager
	elif get_tree():
		modifier_manager = get_tree().get_first_node_in_group("score_modifier_manager")
		if not modifier_manager:
			modifier_manager = get_tree().get_first_node_in_group("multiplier_manager")
	
	var total_additive = 0
	var total_multiplier = 1.0
	
	if modifier_manager:
		if modifier_manager.has_method("get_total_additive"):
			total_additive = modifier_manager.get_total_additive()
		total_multiplier = modifier_manager.get_total_multiplier()
	else:
		push_warning("[Scorecard] No ScoreModifierManager found")
	
	# Add dice color effects (preserved from when autoscoring was triggered)
	var dice_color_additive = color_effects.get("red_additive", 0)
	var dice_color_multiplier = color_effects.get("purple_multiplier", 1.0)
	var dice_color_money = color_effects.get("green_money", 0)
	
	# Apply calculation order: base + additives * multipliers
	var total_additive_bonus = total_additive + dice_color_additive
	var total_multiplier_bonus = total_multiplier * dice_color_multiplier
	var score_with_additive = base_score + total_additive_bonus
	var final_score = int(score_with_additive * total_multiplier_bonus)
	
	# Print debug info for autoscoring
	print("[Scorecard] Preserved effects calculation:")
	print("  Base score: ", base_score)
	print("  Regular additive: ", total_additive)
	print("  Dice color additive: ", dice_color_additive, " (preserved)")
	print("  Regular multiplier: ", total_multiplier)
	print("  Dice color multiplier: ", dice_color_multiplier, " (preserved)")
	print("  Final score: ", final_score)
	
	# Apply money bonus from green dice (preserved)
	if apply_money_effects and dice_color_money > 0:
		PlayerEconomy.add_money(dice_color_money)
		print("[Scorecard] Applied preserved green money bonus: +$", dice_color_money)
	
	return final_score

# Helper function to calculate the base score
func _calculate_base_score(category: String, dice_values: Array) -> int:
	# Use the ScoreEvaluator to calculate the base score
	return ScoreEvaluatorSingleton.calculate_score_for_category(category, dice_values)

func evaluate_category(category: String, values: Array[int]) -> int:
	# Additional safety check
	if values.size() == 0:
		print("[Scorecard] Warning: Empty values array!")
		return 0
	
	# Use our color-aware calculate_score method but DON'T apply money effects during evaluation (for previews)
	return calculate_score_internal(category, values, false)

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

## Reset the calculate_score call counter for debugging
func reset_call_counter():
	calculate_score_call_count = 0
	print("[Scorecard] Reset call counter to 0")
