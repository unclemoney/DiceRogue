extends Node
class_name Scorecard

enum Section { UPPER, LOWER }

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
