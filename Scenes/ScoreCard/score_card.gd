extends Node
class_name Scorecard

enum Section { UPPER, LOWER }

const UPPER_BONUS_THRESHOLD := 63
const UPPER_BONUS_AMOUNT := 35

signal upper_bonus_achieved(bonus: int)
signal upper_section_completed
signal lower_section_completed
signal score_auto_assigned(section: Section, category: String, score: int)
signal yahtzee_bonus_achieved(points: int)
signal score_changed(total_score: int)  # Add this signal
signal game_completed(final_score: int) # Add this signal

var upper_bonus := 0  # Add this to track the bonus
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

var _score_multiplier_func: Callable  # Add this near other vars
var score_modifiers: Array = [] # Array to hold score modifier objects
var score_multiplier: float = 1.0

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
	
	# Apply score modifiers
	var modified_score = score
	for modifier in score_modifiers:
		if modifier.has_method("modify_score"):
			var result = modifier.modify_score(section, category, modified_score)
			if result != null:
				modified_score = result
				print("[Scorecard] Score modified by", modifier.name, "to:", modified_score)
	
	if modified_score != score:
		score = modified_score
		print("[Scorecard] Final modified score:", score)
	
	match section:
		Section.UPPER:
			if upper_scores.has(category):
				var old_value = upper_scores[category]
				upper_scores[category] = score
				print("[Scorecard] Updated upper score:", category, "from", old_value, "to", score)
				check_upper_bonus()
		Section.LOWER:
			if lower_scores.has(category):
				var old_value = lower_scores[category]
				lower_scores[category] = score
				print("[Scorecard] Updated lower score:", category, "from", old_value, "to", score)
				check_lower_section()
				
	var new_total = get_total_score()
	print("[Scorecard] New total after change:", new_total)
	
	# Emit signal for score changes
	print("[Scorecard] Emitting score_changed signal with total:", new_total)
	emit_signal("score_changed", new_total)
	
	# Check if game is complete
	if is_upper_section_complete() and is_lower_section_complete():
		print("[Scorecard] Game is complete, emitting game_completed signal")
		emit_signal("game_completed", new_total)

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
	
	if total >= UPPER_BONUS_THRESHOLD:
		upper_bonus = UPPER_BONUS_AMOUNT  # Store the bonus
		emit_signal("upper_bonus_achieved", UPPER_BONUS_AMOUNT)
	else:
		upper_bonus = 0
	
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
	else:
		print("✗ Not a Yahtzee - no bonus awarded")

# Fix the set_score_multiplier function - make sure it properly registers the Callable
func set_score_multiplier(multiplier_value) -> void:
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

func clear_score_multiplier() -> void:
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
	
	# Preserve the multiplier function during resets
	# Store the current multiplier state
	var had_multiplier_func = _score_multiplier_func.is_valid()
	var temp_multiplier_func = _score_multiplier_func
	var temp_multiplier_value = score_multiplier
	
	# Now we can safely clear it
	clear_score_multiplier()
	
	# And restore it if it was valid
	if had_multiplier_func:
		_score_multiplier_func = temp_multiplier_func
		print("[Scorecard] Preserved multiplier function during reset")
	elif temp_multiplier_value != 1.0:
		score_multiplier = temp_multiplier_value
		print("[Scorecard] Preserved direct multiplier value during reset")
	
	print("[Scorecard] All scores reset")
	
	# Emit signal with 0 score since we've reset everything
	emit_signal("score_changed", 0)

func calculate_score(category: String, dice_values: Array) -> int:
	print("[Scorecard] Calculating score for", category, "with dice:", dice_values)
	print("[Scorecard] Current multiplier:", score_multiplier)
	
	var base_score = _calculate_base_score(category, dice_values)
	var final_score = int(base_score * score_multiplier)
	
	print("[Scorecard] Base score before multiplier:", base_score)
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
	
	# Debug the multiplier function state
	print("[Scorecard] _score_multiplier_func set?", _score_multiplier_func != null)
	print("[Scorecard] _score_multiplier_func valid?", _score_multiplier_func.is_valid())
	if _score_multiplier_func.is_valid():
		print("[Scorecard] _score_multiplier_func target:", _score_multiplier_func.get_object())
		print("[Scorecard] _score_multiplier_func method:", _score_multiplier_func.get_method())
	
	# Reset evaluation counter
	ScoreEvaluatorSingleton.reset_evaluation_count()
	var scores = ScoreEvaluatorSingleton.evaluate_with_wildcards(values)
	var score = scores.get(category, 0)
	print("[Scorecard] Base score before multiplier:", score)
	
	# Try to recover the multiplier function if it's broken but we have a FoursomePowerUp active
	var has_valid_multiplier = false
	
	if _score_multiplier_func.is_valid():
		var multiplier_target = _score_multiplier_func.get_object()
		has_valid_multiplier = multiplier_target != null
		print("[Scorecard] Multiplier function validity:", has_valid_multiplier)
	else:
		# Try to find FoursomePowerUp nodes that might need to reconnect
		var foursome_nodes = get_tree().get_nodes_in_group("power_ups")
		for node in foursome_nodes:
			if node is FoursomePowerUp and node.scorecard_ref == self:
				print("[Scorecard] Found FoursomePowerUp, reconnecting multiplier function")
				var multiplier_func = Callable(node, "_foursome_multiplier_func")
				_score_multiplier_func = multiplier_func
				has_valid_multiplier = true
				break
	
	# Apply multiplier if one is set
	if has_valid_multiplier:
		print("[Scorecard] Calling multiplier function...")
		# We've confirmed the function is valid, so call it
		var multiplied_score = _score_multiplier_func.call(category, score, values)
		print("[Scorecard] Score after multiplier function:", multiplied_score)
		return multiplied_score
	# Or if we have a direct multiplier value
	elif score_multiplier != 1.0:
		print("[Scorecard] Applying direct multiplier:", score_multiplier)
		return int(score * score_multiplier)
	else:
		print("[Scorecard] No multiplier applied")
		return score

# Add this debug function near the evaluate_category function
func debug_multiplier_function() -> void:
	print("\n=== Testing Scorecard Multiplier Function ===")
	print("[Scorecard] Has multiplier function:", _score_multiplier_func.is_valid())
	if _score_multiplier_func.is_valid():
		print("[Scorecard] Multiplier function object:", _score_multiplier_func.get_object())
		print("[Scorecard] Multiplier function method:", _score_multiplier_func.get_method())
		
		# Try a test call
		var test_result = _score_multiplier_func.call("test_category", 10, [4, 3, 2, 1])
		print("[Scorecard] Test call result:", test_result)
	else:
		print("[Scorecard] No valid multiplier function set")
