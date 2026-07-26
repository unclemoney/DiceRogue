extends Resource
class_name MomDialogNode

## MomDialogNode Resource
##
## One beat of a Mom conversation: her line, her expression, and the
## player's response options. Nodes chain via MomDialogOutcome.followup_node_id.
## A node with no responses is terminal — the dialog shows the OK button
## (the pre-rework behavior, also used by the tutorial).

## Unique identifier for this node (e.g. "checkin_neutral", "sass_storm_off").
## Referenced by MomLogicHandler's tree table and follow-up ids.
@export var id: String = ""

## Mom's dialog line. Supports BBCode formatting.
@export_multiline var mom_text: String = ""

## Mom's expression for this beat. Maps to the 3 existing sprites.
@export_enum("happy", "neutral", "upset") var expression: String = "neutral"

## Speaker label shown in the dialog title. Default "Mom"; cast story
## beats use variants like "Mom (on the phone with Dad)" - Mom still
## delivers every line, the cast never speaks directly.
@export var speaker_name: String = "Mom"

## Tint applied to the portrait for this beat (dark silhouette for
## phone beats, etc.). White = no tint.
@export var speaker_tint: Color = Color.WHITE

## Player response options (2-3 recommended). Empty = terminal node.
@export var responses: Array[MomDialogResponse] = []


## is_terminal() -> bool
##
## Returns: bool - true if this node ends the conversation (OK button)
func is_terminal() -> bool:
	return responses.is_empty()


## validate(known_node_ids) -> bool
##
## Checks the node for data errors. Logs errors but does not throw.
## When known_node_ids is provided, every followup_node_id referenced
## by outcomes must exist in it.
##
## Parameters:
##   known_node_ids: Array[String] - ids of all nodes in the tree (optional)
##
## Returns: bool - true if the node is well-formed
func validate(known_node_ids: Array[String] = []) -> bool:
	var all_valid := true

	if id.is_empty():
		push_error("[MomDialogNode] id is empty")
		all_valid = false

	if mom_text.is_empty():
		push_error("[MomDialogNode:'%s'] mom_text is empty" % id)
		all_valid = false

	for response in responses:
		if response == null:
			push_error("[MomDialogNode:'%s'] null response in responses" % id)
			all_valid = false
			continue
		if not response.validate():
			all_valid = false
		if known_node_ids.is_empty():
			continue
		for outcome in response.outcomes:
			if outcome == null:
				continue
			if outcome.has_followup() and outcome.followup_node_id not in known_node_ids:
				push_error("[MomDialogNode:'%s'] followup_node_id '%s' not found in tree" % [
					id, outcome.followup_node_id])
				all_valid = false

	return all_valid
