extends Consumable
class_name ScoreStreakConsumable

## ScoreStreakConsumable
##
## Activates a score streak for the next 3 turns.
## Turn 1: 1.5x multiplier
## Turn 2: 1.75x multiplier  
## Turn 3: 2.0x multiplier
## Streak breaks if player scratches (scores 0).

const STREAK_TURNS := 3
const INITIAL_MULTIPLIER := 1.5

func _ready() -> void:
	add_to_group("consumables")
	print("[ScoreStreakConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[ScoreStreakConsumable] Invalid target passed to apply()")
		return
	
	var turn_tracker = game_controller.turn_tracker
	if not turn_tracker:
		push_error("[ScoreStreakConsumable] No TurnTracker found")
		return
	
	# Start the score streak
	turn_tracker.start_score_streak(STREAK_TURNS)
	
	# Register the initial multiplier with ScoreModifierManager
	# The multiplier starts at 1.5x on the current turn (immediate effect)
	var score_modifier_manager = get_node_or_null("/root/ScoreModifierManager")
	if score_modifier_manager and score_modifier_manager.has_method("register_multiplier"):
		score_modifier_manager.register_multiplier("score_streak", INITIAL_MULTIPLIER)
		print("[ScoreStreakConsumable] Registered streak multiplier: %.2fx" % INITIAL_MULTIPLIER)
	
	print("[ScoreStreakConsumable] Score streak activated for %d turns" % STREAK_TURNS)
