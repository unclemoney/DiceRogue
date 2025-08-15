extends Node
class_name TurnTracker

signal turn_updated(turn: int)
signal rolls_updated(rolls_left: int)
signal rolls_exhausted
signal turn_started

var current_turn := 1
var rolls_left := 3
const MAX_ROLLS := 3

func start_new_turn():
	current_turn += 1
	rolls_left = MAX_ROLLS
	emit_signal("turn_updated", current_turn)
	emit_signal("rolls_updated", rolls_left)
	emit_signal("turn_started")

func use_roll():
	if rolls_left > 0:
		rolls_left -= 1
		emit_signal("rolls_updated", rolls_left)
		if rolls_left == 0:
			emit_signal("rolls_exhausted")

func reset_game():
	current_turn = 1
	rolls_left = MAX_ROLLS
	emit_signal("turn_updated", current_turn)
	emit_signal("rolls_updated", rolls_left)
