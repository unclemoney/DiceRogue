extends Consumable
class_name BonusSprintConsumable

## BonusSprintConsumable
##
## For the rest of this round, upper section scores count DOUBLE toward the
## upper bonus threshold (63 on d6). Actual scored values are unchanged -
## only progress toward the bonus is boosted.
## The effect lives on the Scorecard (upper_bonus_progress_multiplier) and is
## reset to 1.0 by Scorecard.reset_scores_preserve_levels() at the round
## transition (called by RoundManager.start_round()).

const PROGRESS_MULTIPLIER: float = 2.0

var _debug_enabled: bool = OS.is_debug_build()

func _ready() -> void:
	add_to_group("consumables")
	if _debug_enabled:
		print("[BonusSprintConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[BonusSprintConsumable] Invalid target passed to apply()")
		return
	
	var scorecard = game_controller.scorecard
	if not scorecard:
		push_error("[BonusSprintConsumable] No scorecard found")
		return
	
	scorecard.upper_bonus_progress_multiplier = PROGRESS_MULTIPLIER
	if _debug_enabled:
		print("[BonusSprintConsumable] Upper bonus progress multiplier set to x%.1f for this round" % PROGRESS_MULTIPLIER)
