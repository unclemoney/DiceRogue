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

func start_new_turn():
	# Are we already at the limit?
	if current_turn >= max_turns:
		emit_signal("game_over")
		return
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

func add_rolls(amount: int) -> void:
	MAX_ROLLS += amount
	print("🎲 MAX_ROLLS increased to", MAX_ROLLS)

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