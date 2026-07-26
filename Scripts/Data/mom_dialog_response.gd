extends Resource
class_name MomDialogResponse

## MomDialogResponse Resource
##
## One player-selectable response button in a Mom dialog.
## Holds 2+ weighted outcomes; MomLogicHandler draws one when the
## response is picked, so the same answer can resolve differently
## (e.g. sassing usually backfires, but rarely Mom storms off).

## Button label shown to the player (e.g. "All good, Mom!").
@export var button_text: String = ""

## Tone of the response. Used by the bot policy and for flavor.
@export_enum("polite", "neutral", "sassy") var tone: String = "neutral"

## Weighted possible outcomes. One is drawn at random when picked.
@export var outcomes: Array[MomDialogOutcome] = []


## get_total_weight() -> float
##
## Sums all outcome weights. Used for weighted random selection.
func get_total_weight() -> float:
	var total := 0.0
	for outcome in outcomes:
		if outcome:
			total += outcome.weight
	return total


## validate() -> bool
##
## Checks the response for data errors. Logs errors but does not throw.
##
## Returns: bool - true if the response is well-formed
func validate() -> bool:
	var all_valid := true

	if button_text.is_empty():
		push_error("[MomDialogResponse] button_text is empty")
		all_valid = false

	if outcomes.is_empty():
		push_error("[MomDialogResponse:'%s'] outcomes is empty" % button_text)
		all_valid = false

	for outcome in outcomes:
		if outcome == null:
			push_error("[MomDialogResponse:'%s'] null outcome in outcomes" % button_text)
			all_valid = false
		elif not outcome.validate():
			all_valid = false

	if get_total_weight() <= 0.0:
		push_error("[MomDialogResponse:'%s'] total outcome weight is <= 0" % button_text)
		all_valid = false

	return all_valid
