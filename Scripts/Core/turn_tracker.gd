extends Node
class_name TurnTracker

signal turn_updated(turn: int)
signal rolls_updated(rolls_left: int)
signal rolls_exhausted
signal turn_started
signal game_over
signal max_rolls_changed(new_max: int)
signal temporary_effect_expired(effect_type: String)
signal dice_bonus_changed(new_bonus: int)
signal score_streak_changed(multiplier: float, turns_remaining: int)
signal dice_stack_expired(stack_id: int, dice_removed: int)

var current_turn := 1
var rolls_left := 3
@export var MAX_ROLLS := 3
@export var max_turns: int = 13
var is_active := false

# Stacking dice bonus tracking (for multiple Dice Surge consumables)
# Each stack is a Dictionary: { "id": int, "dice": int, "turns_remaining": int }
var dice_bonus_stacks: Array[Dictionary] = []
var _next_stack_id: int = 0

# Legacy property for backwards compatibility - returns total bonus from all stacks
var temporary_dice_bonus: int:
	get:
		var total = 0
		for stack in dice_bonus_stacks:
			total += stack.dice
		return total

# Score streak tracking (for Score Streak consumable)
var score_streak_active: bool = false
var score_streak_turns_remaining: int = 0
var score_streak_multiplier: float = 1.0
var score_streak_current_turn: int = 0  # Tracks which turn of the streak we're on (0, 1, 2)

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
## Also decrements temporary effect counters and expires them when complete.
func start_new_turn():
	# Are we already at the limit?
	if current_turn >= max_turns:
		emit_signal("game_over")
		return
	current_turn += 1
	rolls_left = MAX_ROLLS
	is_active = true  # Turn is now active
	
	# Decrement all dice bonus stacks and remove expired ones
	var expired_stacks: Array[Dictionary] = []
	for stack in dice_bonus_stacks:
		stack.turns_remaining -= 1
		print("[TurnTracker] Dice stack #%d: %d dice, %d turns remaining" % [stack.id, stack.dice, stack.turns_remaining])
		if stack.turns_remaining <= 0:
			expired_stacks.append(stack)
	
	# Remove expired stacks and emit signals
	for stack in expired_stacks:
		dice_bonus_stacks.erase(stack)
		print("[TurnTracker] Dice stack #%d expired (was +%d dice)" % [stack.id, stack.dice])
		emit_signal("dice_stack_expired", stack.id, stack.dice)
	
	# If any stacks expired, emit the general dice_bonus_changed signal
	if expired_stacks.size() > 0:
		var new_total = temporary_dice_bonus
		print("[TurnTracker] Total dice bonus now: +%d" % new_total)
		emit_signal("dice_bonus_changed", new_total)
		# Also emit legacy signal if all bonuses are gone
		if new_total == 0:
			emit_signal("temporary_effect_expired", "dice_bonus")
	
	# Progress score streak if active
	if score_streak_active:
		score_streak_turns_remaining -= 1
		score_streak_current_turn += 1
		# Update multiplier based on streak turn (1.5 -> 1.75 -> 2.0)
		match score_streak_current_turn:
			1:
				score_streak_multiplier = 1.5
			2:
				score_streak_multiplier = 1.75
			3:
				score_streak_multiplier = 2.0
		print("[TurnTracker] Score streak turn %d, multiplier: %.2fx, turns remaining: %d" % [score_streak_current_turn, score_streak_multiplier, score_streak_turns_remaining])
		emit_signal("score_streak_changed", score_streak_multiplier, score_streak_turns_remaining)
		
		if score_streak_turns_remaining <= 0:
			_end_score_streak()
	
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
	# Reset temporary effects
	dice_bonus_stacks.clear()
	_next_stack_id = 0
	score_streak_active = false
	score_streak_turns_remaining = 0
	score_streak_multiplier = 1.0
	score_streak_current_turn = 0
	emit_signal("turn_updated", current_turn)
	emit_signal("rolls_updated", rolls_left)
	emit_signal("turn_started")


## add_dice_bonus_stack(bonus, turns) -> int
##
## Adds a new dice bonus stack that lasts for a number of turns.
## Returns the stack ID for tracking.
## @param bonus: Number of extra dice to grant
## @param turns: Number of turns the bonus lasts
## @return: Stack ID for this bonus
func add_dice_bonus_stack(bonus: int, turns: int) -> int:
	var stack_id = _next_stack_id
	_next_stack_id += 1
	var stack = {
		"id": stack_id,
		"dice": bonus,
		"turns_remaining": turns
	}
	dice_bonus_stacks.append(stack)
	var total_bonus = temporary_dice_bonus
	print("[TurnTracker] Added dice bonus stack #%d: +%d dice for %d turns (total bonus: +%d)" % [stack_id, bonus, turns, total_bonus])
	emit_signal("dice_bonus_changed", total_bonus)
	return stack_id


## set_temporary_dice_bonus(bonus, turns)
##
## Legacy method - adds a dice bonus stack (for backwards compatibility).
## @param bonus: Number of extra dice to grant
## @param turns: Number of turns the bonus lasts
func set_temporary_dice_bonus(bonus: int, turns: int) -> void:
	add_dice_bonus_stack(bonus, turns)


## get_total_dice_count() -> int
##
## Returns the total dice count including any temporary bonus.
## Base is 5, plus any temporary bonus.
func get_total_dice_count() -> int:
	return 5 + temporary_dice_bonus


## start_score_streak(turns)
##
## Activates score streak mode with multipliers increasing each turn.
## Multipliers: Turn 1 = 1.5x, Turn 2 = 1.75x, Turn 3 = 2.0x
## @param turns: Number of turns the streak lasts (typically 3)
func start_score_streak(turns: int) -> void:
	score_streak_active = true
	score_streak_turns_remaining = turns
	score_streak_current_turn = 1  # Start at turn 1 (immediate effect)
	score_streak_multiplier = 1.5  # Initial multiplier is 1.5x
	print("[TurnTracker] Started score streak for %d turns (initial multiplier: 1.5x)" % turns)
	emit_signal("score_streak_changed", score_streak_multiplier, score_streak_turns_remaining)


## break_score_streak()
##
## Ends the score streak early (called when player scratches with 0 score).
func break_score_streak() -> void:
	if score_streak_active:
		print("[TurnTracker] Score streak broken!")
		_end_score_streak()


## _end_score_streak()
##
## Internal method to clean up score streak state.
func _end_score_streak() -> void:
	score_streak_active = false
	score_streak_turns_remaining = 0
	score_streak_multiplier = 1.0
	score_streak_current_turn = 0
	print("[TurnTracker] Score streak ended")
	emit_signal("temporary_effect_expired", "score_streak")
	emit_signal("score_streak_changed", 1.0, 0)


## get_state() -> Dictionary
##
## Returns the current state for saving/persistence.
func get_state() -> Dictionary:
	return {
		"current_turn": current_turn,
		"rolls_left": rolls_left,
		"MAX_ROLLS": MAX_ROLLS,
		"is_active": is_active,
		"dice_bonus_stacks": dice_bonus_stacks.duplicate(true),
		"_next_stack_id": _next_stack_id,
		"score_streak_active": score_streak_active,
		"score_streak_turns_remaining": score_streak_turns_remaining,
		"score_streak_multiplier": score_streak_multiplier,
		"score_streak_current_turn": score_streak_current_turn
	}


## load_state(state: Dictionary)
##
## Loads state from a saved dictionary.
func load_state(state: Dictionary) -> void:
	current_turn = state.get("current_turn", 1)
	rolls_left = state.get("rolls_left", MAX_ROLLS)
	MAX_ROLLS = state.get("MAX_ROLLS", 3)
	is_active = state.get("is_active", false)
	# Load stacks array
	dice_bonus_stacks.clear()
	var saved_stacks = state.get("dice_bonus_stacks", [])
	for stack in saved_stacks:
		dice_bonus_stacks.append(stack.duplicate())
	_next_stack_id = state.get("_next_stack_id", 0)
	score_streak_active = state.get("score_streak_active", false)
	score_streak_turns_remaining = state.get("score_streak_turns_remaining", 0)
	score_streak_multiplier = state.get("score_streak_multiplier", 1.0)
	score_streak_current_turn = state.get("score_streak_current_turn", 0)
	print("[TurnTracker] State loaded")
