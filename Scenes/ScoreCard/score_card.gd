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
	print("Setting score:", category, "→", value)
	match section:
		Section.UPPER:
			if upper_scores.has(category):
				upper_scores[category] = value
				check_upper_bonus()
		Section.LOWER:
			if lower_scores.has(category):
				lower_scores[category] = value
				check_lower_section()

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
	var best_score := -1
	var best_section
	var best_category := ""

	# scan upper section
	for category in upper_scores.keys():
		if upper_scores[category] == null:
			#print("Using evaluator:", ScoreEvaluatorSingleton)  
			#print("Script path:", ScoreEvaluatorSingleton.get_script().resource_path)  
			var s: int = ScoreEvaluatorSingleton.calculate_score_for_category(category, values)  
			#print("  -> s =", s, " type:", typeof(s))  
			if s > best_score:
				best_score = s
				best_section = Section.UPPER
				best_category = category

	# scan lower section
	for category in lower_scores.keys():
		if lower_scores[category] == null:
			#print("Using evaluator:", ScoreEvaluatorSingleton)  
			#print("Script path:", ScoreEvaluatorSingleton.get_script().resource_path)  
			var s: int = ScoreEvaluatorSingleton.calculate_score_for_category(category, values)  
			#print("  -> s =", s, " type:", typeof(s))  
			if s > best_score:
				best_score = s
				best_section = Section.LOWER
				best_category = category

	if best_category != "":
		set_score(best_section, best_category, best_score)
		emit_signal("score_auto_assigned", best_section, best_category, best_score)

func get_upper_section_final_total() -> int:
	var subtotal = get_upper_section_total()
	if is_upper_section_complete() and subtotal >= UPPER_BONUS_THRESHOLD:
		return subtotal + UPPER_BONUS_AMOUNT
	return subtotal

func is_upper_section_complete() -> bool:
	for score in upper_scores.values():
		if score == null:
			print("Upper section incomplete.")
			return false
	print("Upper section is complete.")
	return true

func is_lower_section_complete() -> bool:
	for score in lower_scores.values():
		if score == null:
			print("Lower section incomplete")
			return false
	print("Lower section is complete")
	return true

func check_lower_section() -> void:
	if is_lower_section_complete():
		print("Lower section completed, emitting signal")
		emit_signal("lower_section_completed")

func check_upper_bonus() -> void:
	print("Checking upper bonus...")
	if not is_upper_section_complete():
		print("Upper section not complete yet")
		return
	
	print("Upper section complete, calculating total")    
	var total = get_upper_section_total()
	print("Upper total:", total, " (need ", UPPER_BONUS_THRESHOLD, " for bonus)")
	
	if total >= UPPER_BONUS_THRESHOLD:
		print("Bonus achieved! Emitting signal...")
		upper_bonus = UPPER_BONUS_AMOUNT  # Store the bonus
		emit_signal("upper_bonus_achieved", UPPER_BONUS_AMOUNT)
	else:
		upper_bonus = 0
		print("No bonus yet")
	
	emit_signal("upper_section_completed")

func check_bonus_yahtzee(values: Array[int]) -> void:
	# Only check if we already have a yahtzee scored
	if lower_scores["yahtzee"] != null and lower_scores["yahtzee"] > 0:
		# Check if current roll is a yahtzee
		var counts = {}
		for v in values:
			counts[v] = counts.get(v, 0) + 1
		
		for count in counts.values():
			if count >= 5:
				yahtzee_bonuses += 1
				yahtzee_bonus_points += 100
				print("Bonus Yahtzee achieved! Total bonuses:", yahtzee_bonuses)
				emit_signal("yahtzee_bonus_achieved", 100)
				return