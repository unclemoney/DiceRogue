extends Resource
class_name MomStoryBeat

## MomStoryBeat Resource
##
## One beat of a MomStoryArc: a dialog tree plus the conditions under
## which it interrupts a normal check-in, and the rewards paid when its
## session completes. Beats are delivered in order (beat_index 0 = setup,
## 1 = escalation, 2 = payoff); CastManager tracks each arc's next beat.

## Position within the arc (0 = setup, 1 = escalation, 2 = payoff).
@export var beat_index: int = 0

## Root MomDialogNode id of this beat's tree (must exist in
## Resources/Data/Mom/Dialog/).
@export var dialog_node_id: String = ""

## Earliest channel (mall zone) at which this beat may fire.
@export var min_channel: int = 1

## Grudge window: the beat only fires while grudge is in
## [min_grudge, max_grudge].
@export var min_grudge: int = 0
@export var max_grudge: int = 3

## Minimum Rebellion Rep required.
@export var min_rep: int = 0

## Story flag that must already be set (e.g. "patterson_intro_done").
## Empty = no requirement.
@export var requires_flag: String = ""

## If true, the beat only fires when the player completed at least one
## chore this round (the "homework done" angle).
@export var requires_chores_done: bool = false

## Story flag set when this beat's session completes. Empty = none.
@export var sets_flag: String = ""

## Completion rewards (applied by CastManager when the session ends).
## reward_mood is a raw ChoresManager.adjust_mood delta: positive makes
## Mom ANGRIER - use negative values for happy endings.
@export var reward_money: int = 0
@export var reward_mood: int = 0
@export var reward_rep: int = 0


## validate() -> bool
##
## Checks the beat for data errors. Logs errors but does not throw.
## Cross-checks (dialog node exists, flag is set by some beat) happen
## in the validation test where the whole data set is visible.
func validate() -> bool:
	var all_valid := true

	if dialog_node_id.is_empty():
		push_error("[MomStoryBeat] dialog_node_id is empty")
		all_valid = false

	if min_grudge > max_grudge:
		push_error("[MomStoryBeat:'%s'] min_grudge > max_grudge" % dialog_node_id)
		all_valid = false

	return all_valid
