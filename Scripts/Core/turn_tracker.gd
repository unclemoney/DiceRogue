extends Node
class_name TurnTracker

signal turn_updated(turn: int)
signal rolls_updated(rolls_left: int)
signal rolls_exhausted
signal turn_started
signal game_over
signal max_rolls_changed(new_max: int)

var current_turn := 1
var rolls_left := 3
@export var MAX_ROLLS := 3
@export var max_turns: int = 13
var is_active := false

## _ready()
## Initialize turn tracker state before the first round.
## - Sets current_turn to 0 and rolls_left to 0.
## - Does not emit signals (game not started yet).
func _ready() -> void:
	# Initialize with 0 rolls and turn 0 at game start (pre-first round)
	current_turn = 0
	rolls_left = 0
	is_active = false
	# No need to emit signals here as the game hasn't truly started yet

## start_new_turn()
##
## Starts the next turn if max turns not reached.
## Emits: turn_updated, rolls_updated, turn_started
func start_new_turn():
	# Are we already at the limit?
	if current_turn >= max_turns:
		emit_signal("game_over")
		return
	current_turn += 1
	rolls_left = MAX_ROLLS
	is_active = true  # Turn is now active
	emit_signal("turn_updated", current_turn)
	emit_signal("rolls_updated", rolls_left)
	emit_signal("turn_started")

## use_roll()
##
## Consumes one roll from rolls_left and emits rolls_updated.
## Emits rolls_exhausted when rolls reach zero.
func use_roll():
	if rolls_left > 0:
		rolls_left -= 1
		emit_signal("rolls_updated", rolls_left)
		if rolls_left == 0:
			#is_active = false  # Turn is no longer active when rolls are exhausted
			emit_signal("rolls_exhausted")

## reset_game()
##
## Resets tracker to initial running state (turn 1, full rolls).
func reset_game():
	current_turn = 1
	rolls_left = MAX_ROLLS
	emit_signal("turn_updated", current_turn)
	emit_signal("rolls_updated", rolls_left)

## add_rolls(amount)
##
## Increases the maximum number of rolls allowed per turn.
func add_rolls(amount: int) -> void:
	MAX_ROLLS += amount
	print("🎲 MAX_ROLLS increased to", MAX_ROLLS)
	# Notify listeners that the maximum rolls-per-turn value changed
	emit_signal("max_rolls_changed", MAX_ROLLS)

## _on_turn_completed()
##
## Called when a turn completes. Checks for max_turns and emits game_over if reached.
func _on_turn_completed() -> void:
	print("[TurnTracker] Turn completed")

	if current_turn >= max_turns:
		print("[TurnTracker] Max turns reached, game over!")

		# If we have a scorecard reference, check for game completion
		var scorecard = get_tree().get_first_node_in_group("scorecard")
		if scorecard and scorecard is Scorecard:
			print("[TurnTracker] Scorecard found, checking game completion")
			if not scorecard.is_game_complete():
				print("[TurnTracker] Game not yet marked as complete, emitting game_completed")
				scorecard.emit_signal("game_completed", scorecard.get_total_score())

		emit_signal("game_over")

## reset()
##
## Resets the tracker and emits update signals and turn_started.
func reset() -> void:
	print("[TurnTracker] Resetting turn tracker")
	current_turn = 1
	rolls_left = MAX_ROLLS
	emit_signal("turn_updated", current_turn)
	emit_signal("rolls_updated", rolls_left)
	emit_signal("turn_started")
