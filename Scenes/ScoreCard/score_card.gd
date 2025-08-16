extends Node
class_name Scorecard

enum Section { UPPER, LOWER }

signal score_auto_assigned(section: Section, category: String, score: int)

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
		Section.LOWER:
			if lower_scores.has(category):
				lower_scores[category] = value

func get_total_score() -> int:
	var total := 0
	for score in upper_scores.values():
		if score != null:
			total += score
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
			print("Using evaluator:", ScoreEvaluatorSingleton)  
			print("Script path:", ScoreEvaluatorSingleton.get_script().resource_path)  
			var s: int = ScoreEvaluatorSingleton.calculate_score_for_category(category, values)  
			print("  -> s =", s, " type:", typeof(s))  
			if s > best_score:
				best_score = s
				best_section = Section.UPPER
				best_category = category

	# scan lower section
	for category in lower_scores.keys():
		if lower_scores[category] == null:
			print("Using evaluator:", ScoreEvaluatorSingleton)  
			print("Script path:", ScoreEvaluatorSingleton.get_script().resource_path)  
			var s: int = ScoreEvaluatorSingleton.calculate_score_for_category(category, values)  
			print("  -> s =", s, " type:", typeof(s))  
			if s > best_score:
				best_score = s
				best_section = Section.LOWER
				best_category = category

	if best_category != "":
		set_score(best_section, best_category, best_score)
		emit_signal("score_auto_assigned", best_section, best_category, best_score)
