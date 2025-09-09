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
			return true
			
	# Check lower section
	for score in lower_scores.values():
		if score != null:
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
			# Use evaluate_category instead of direct ScoreEvaluator call
			var score = evaluate_category(category, values)
			print("[Scorecard] Evaluating upper category:", category, "score:", score)
			if score > best_score:
				best_score = score
				best_section = Section.UPPER
				best_category = category
	
	# Check lower section next
	for category in lower_scores.keys():
		if lower_scores[category] == null:
			# Use evaluate_category instead of direct ScoreEvaluator call
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

func evaluate_category(category: String, values: Array[int]) -> int:
	print("\n=== Scorecard Category Evaluation ===")
	print("[Scorecard] Evaluating category:", category)
	print("[Scorecard] Values:", values)
	
	# Reset evaluation counter
	ScoreEvaluatorSingleton.reset_evaluation_count()
	var scores = ScoreEvaluatorSingleton.evaluate_with_wildcards(values)
	var score = scores.get(category, 0)
	print("[Scorecard] Base score before multiplier:", score)
	
	# Apply multiplier if one is set
	if _score_multiplier_func.is_valid():
		print("[Scorecard] Multiplier function is valid, applying...")
		var multiplied_score = _score_multiplier_func.call(category, score, values)
		print("[Scorecard] Score after multiplier:", multiplied_score)
		return multiplied_score
	else:
		print("[Scorecard] No multiplier function set")
		return score

func set_score_multiplier(multiplier_func: Callable) -> void:
	_score_multiplier_func = multiplier_func

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
	
	# Clear any multiplier function
	clear_score_multiplier()
	
	print("[Scorecard] All scores reset")
	
	# Emit signal with 0 score since we've reset everything
	emit_signal("score_changed", 0)