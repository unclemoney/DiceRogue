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

func set_score(section: Section, category: String, value: int) -> void:
	match section:
		Section.UPPER:
			if upper_scores.has(category):
				upper_scores[category] = value
				check_upper_bonus()
		Section.LOWER:
			if lower_scores.has(category):
				lower_scores[category] = value
				check_lower_section()

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
	# Reset evaluation counter
	ScoreEvaluatorSingleton.reset_evaluation_count()
	
	var best_score := -1
	var best_section
	var best_category := ""
	
	# Get all possible scores at once to include bonus Yahtzee
	var all_scores = ScoreEvaluatorSingleton.evaluate_with_wildcards(values)
	
	# Check upper section
	for category in upper_scores.keys():
		if upper_scores[category] == null:
			var score = all_scores.get(category, 0)
			if score > best_score:
				best_score = score
				best_section = Section.UPPER
				best_category = category
	
	# Check lower section
	for category in lower_scores.keys():
		if lower_scores[category] == null:
			var score = all_scores.get(category, 0)
			if score > best_score:
				best_score = score
				best_section = Section.LOWER
				best_category = category
	
	if best_category != "":
		var is_new_yahtzee = (best_category == "yahtzee" and best_score == 50)
		set_score(best_section, best_category, best_score)
		# This will trigger the bonus Yahtzee check if applicable
		check_bonus_yahtzee(values, is_new_yahtzee)
		emit_signal("score_auto_assigned", best_section, best_category, best_score)
	else:
		print("No valid scoring categories found!")

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
		print("→ This is the first Yahtzee being scored, skipping bonus check")
		return

	if lower_scores["yahtzee"] != 50:
		print("→ No previous Yahtzee scored as 50, cannot award bonus")
		return
		
	# Use ScoreEvaluator to check for Yahtzee with wildcards
	if ScoreEvaluatorSingleton.is_yahtzee(values):
		yahtzee_bonuses += 1
		yahtzee_bonus_points += 100
		emit_signal("yahtzee_bonus_achieved", 100)
	else:
		print("✗ Not a Yahtzee - no bonus awarded")
