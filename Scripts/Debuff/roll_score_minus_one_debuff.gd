extends Debuff
class_name RollScoreMinusOneDebuff

## RollScoreMinusOneDebuff ("Rolling Penalty")
##
## Each completed roll adds -1 to the next scored hand. The penalty is a
## negative additive registered with ScoreModifierManager under the source
## name "roll_score_minus_one", so it applies BEFORE multipliers inside the
## authoritative score pipeline and appears in the scoring animation's
## additive stage. Emits penalty_changed whenever the raw count moves.

signal penalty_changed(new_penalty: int)

const MODIFIER_SOURCE_NAME := "roll_score_minus_one"

var turn_tracker: TurnTracker = null
var roll_count: int = 0

func _ready() -> void:
	add_to_group("debuffs")
	print("=== [RollScoreMinusOneDebuff] Ready and initialized ===")


## get_current_penalty() -> int
##
## Returns the raw current penalty (one point per completed roll).
func get_current_penalty() -> int:
	return roll_count


func apply(target) -> void:
	print("[RollScoreMinusOneDebuff] Applying to target:", target.name if target else "null")
	var game_controller = target as GameController
	if game_controller:
		is_active = true

		turn_tracker = game_controller.turn_tracker
		if not turn_tracker:
			push_error("[RollScoreMinusOneDebuff] No turn tracker found in game controller")
			return

		# Get dice hand to track rolls
		var dice_hand = game_controller.dice_hand
		if dice_hand:
			print("[RollScoreMinusOneDebuff] Getting dice_hand roll signals")
			if dice_hand.has_signal("roll_complete"):
				if not dice_hand.is_connected("roll_complete", _on_roll_complete):
					dice_hand.roll_complete.connect(_on_roll_complete)
					print("[RollScoreMinusOneDebuff] Connected to dice_hand roll_complete")
				else:
					print("[RollScoreMinusOneDebuff] Already connected to roll_complete")
			else:
				push_error("[RollScoreMinusOneDebuff] DiceHand missing roll_complete signal")
		else:
			push_error("[RollScoreMinusOneDebuff] No dice_hand found in game controller")

		# Register the negative additive for the current count (save-restore
		# path can arrive with roll_count already above zero)
		if roll_count > 0:
			_register_penalty_additive()

		print("[RollScoreMinusOneDebuff] Roll penalty active - current roll count:", roll_count)
	else:
		push_error("[RollScoreMinusOneDebuff] Invalid target passed to apply() - expected GameController")


func _on_roll_complete() -> void:
	if is_active:
		roll_count += 1
		_register_penalty_additive()
		penalty_changed.emit(roll_count)
		print("[RollScoreMinusOneDebuff] Roll count increased to:", roll_count)


## _register_penalty_additive()
##
## Registers (or updates) the raw roll count as a negative additive with
## ScoreModifierManager. Re-registering the same source name overwrites the
## previous value, so the penalty is never applied twice.
func _register_penalty_additive() -> void:
	ScoreModifierManager.register_additive(MODIFIER_SOURCE_NAME, -roll_count)


func remove() -> void:
	print("[RollScoreMinusOneDebuff] Removing effect")

	# Disconnect from dice hand
	var game_controller = target as GameController
	if game_controller and game_controller.dice_hand:
		var dice_hand = game_controller.dice_hand
		if dice_hand.is_connected("roll_complete", _on_roll_complete):
			dice_hand.roll_complete.disconnect(_on_roll_complete)

	# Remove the negative additive
	if ScoreModifierManager.has_additive(MODIFIER_SOURCE_NAME):
		ScoreModifierManager.unregister_additive(MODIFIER_SOURCE_NAME)

	is_active = false
	roll_count = 0
	print("[RollScoreMinusOneDebuff] Removed roll penalty effect")
