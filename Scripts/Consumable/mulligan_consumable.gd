extends Consumable
class_name MulliganConsumable

## MulliganConsumable
##
## "Mulligan" coupon: rerolls the player's WORST placed score.
## Scans the scorecard for the lowest non-null score (a scored 0 counts and
## is always the worst), then drives the existing ScoreCardUI score-reroll
## pipeline at that category automatically — no row click required.
## Yahtzee bonus points live outside the category dicts, so a Yahtzee-bonus-
## affected score still rerolls its base category.
## Usable only with at least one placed score and dice currently rolled
## (gated in ConsumableUI._can_use_consumable).

signal mulligan_activated(category: String)
signal mulligan_denied(reason: String)

var has_been_used: bool = false
var _debug_enabled: bool = OS.is_debug_build()


func _ready() -> void:
	add_to_group("consumables")
	if _debug_enabled:
		print("[MulliganConsumable] Ready")


## apply(target)
##
## Entry point called by GameController with the GameController as target.
## Refuses (mulligan_denied) when nothing is scored, no dice are rolled, or
## the ScoreCardUI reroll pipeline is unavailable.
func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[MulliganConsumable] Invalid target passed to apply()")
		return

	if has_been_used:
		if _debug_enabled:
			print("[MulliganConsumable] Already used")
		emit_signal("mulligan_denied", "already_used")
		return

	var scorecard: Scorecard = game_controller.scorecard
	if not scorecard:
		push_error("[MulliganConsumable] No scorecard found in game controller")
		emit_signal("mulligan_denied", "no_scorecard")
		return

	var worst := find_worst_placed_score(scorecard.upper_scores, scorecard.lower_scores)
	if worst.is_empty():
		if _debug_enabled:
			print("[MulliganConsumable] Denied - no placed scores")
		emit_signal("mulligan_denied", "no_scores")
		return

	# The reroll re-evaluates the current hand, so dice must be rolled
	if DiceResults.values.is_empty():
		if _debug_enabled:
			print("[MulliganConsumable] Denied - no dice rolled")
		emit_signal("mulligan_denied", "no_dice")
		return

	var score_card_ui = game_controller.score_card_ui
	if not score_card_ui or not score_card_ui.has_method("activate_score_reroll_for"):
		push_error("[MulliganConsumable] ScoreCardUI missing activate_score_reroll_for()")
		emit_signal("mulligan_denied", "no_ui")
		return

	var category: String = worst["category"]
	if _debug_enabled:
		print("[MulliganConsumable] Rerolling worst score: %s (was %d)" % [category, worst["score"]])
	var started: bool = score_card_ui.activate_score_reroll_for(category)
	if started:
		has_been_used = true
		emit_signal("mulligan_activated", category)
	else:
		emit_signal("mulligan_denied", "reroll_failed")


## find_worst_placed_score(upper_scores, lower_scores) -> Dictionary
##
## Returns the lowest-scoring placed category across both sections.
## A scored 0 counts (it is always the worst); null means unscored and is
## skipped. Returns {} when nothing is placed, otherwise
## {"section": Scorecard.Section, "category": String, "score": int}.
## Ties resolve to the first category found (upper section first, then dict order).
static func find_worst_placed_score(upper_scores: Dictionary, lower_scores: Dictionary) -> Dictionary:
	var found := false
	var worst_section: int = Scorecard.Section.UPPER
	var worst_category := ""
	var worst_score := 0

	for category in upper_scores.keys():
		var score = upper_scores[category]
		if score == null:
			continue
		if not found or int(score) < worst_score:
			found = true
			worst_section = Scorecard.Section.UPPER
			worst_category = category
			worst_score = int(score)

	for category in lower_scores.keys():
		var score = lower_scores[category]
		if score == null:
			continue
		if not found or int(score) < worst_score:
			found = true
			worst_section = Scorecard.Section.LOWER
			worst_category = category
			worst_score = int(score)

	if not found:
		return {}
	return {"section": worst_section, "category": worst_category, "score": worst_score}
