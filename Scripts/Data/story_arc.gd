extends Resource
class_name MomStoryArc

## MomStoryArc Resource
##
## A small 3-beat ongoing story told across Mom's check-ins
## (setup -> escalation -> payoff). CastManager evaluates arcs at
## check-in time: the highest-priority arc whose next beat's conditions
## all pass takes the check-in slot. Completion rewards ride on the
## final beat (see MomStoryBeat).
##
## Files live in Resources/Data/Mom/Cast/ and are auto-validated by
## Tests/mom_data_validation_test.gd.

## Unique identifier (e.g. "patterson_file", "golden_child").
@export var id: String = ""

## CastCharacter.id of the character this arc belongs to.
@export var character_id: String = ""

## Display name (designer-facing).
@export var display_name: String = ""

## Higher priority wins when several arcs have a due beat.
@export var priority: int = 0

## Beats in delivery order. beat_index should match array position.
@export var beats: Array[MomStoryBeat] = []


## validate() -> bool
##
## Checks the arc for data errors. Logs errors but does not throw.
func validate() -> bool:
	var all_valid := true

	if id.is_empty():
		push_error("[MomStoryArc] id is empty")
		all_valid = false

	if character_id.is_empty():
		push_error("[MomStoryArc:'%s'] character_id is empty" % id)
		all_valid = false

	if beats.is_empty():
		push_error("[MomStoryArc:'%s'] has no beats" % id)
		all_valid = false

	for i in range(beats.size()):
		var beat := beats[i]
		if beat == null:
			push_error("[MomStoryArc:'%s'] null beat at %d" % [id, i])
			all_valid = false
			continue
		if not beat.validate():
			all_valid = false
		if beat.beat_index != i:
			push_error("[MomStoryArc:'%s'] beat %d has beat_index %d (must match order)" % [
				id, i, beat.beat_index])
			all_valid = false

	return all_valid
