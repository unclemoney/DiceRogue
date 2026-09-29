extends Resource
class_name ConsumableData

## When this consumable may be used, evaluated against
## GameController.current_phase (see GameController.GamePhase).
enum UsageWindow { ANY_TIME, BEFORE_ROLL_INITIATED, DURING_ACTIVE_ROUND, AFTER_SCORING }

@export var id: String
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var scene: PackedScene
@export var price: int = 100
## Dice side counts this consumable may appear for in the shop and grant
## pools (e.g. [4] for the d4-only Evens/Odds upgrades, [6] for the d6-only
## Fives/Sixes/Large Straight upgrades). Empty = any dice set.
@export var allowed_dice_sets: Array[int] = []
## When true, allowed_dice_sets becomes an exclusion list instead of a
## whitelist: the consumable is offered on every dice set EXCEPT the listed
## ones ("all except d4" = [4] + exclude; "all except d6" = [6] + exclude).
@export var exclude_listed_dice_sets: bool = false
## When this consumable may be used. ANY_TIME (default) keeps un-migrated
## resources usable whenever a turn is active.
@export var usage_window: UsageWindow = UsageWindow.ANY_TIME
## Named extra conditions, evaluated by ConsumableUI's generic dispatcher
## (_check_usage_conditions). Recognized keys:
## "dice_rolled", "open_category", "open_lower_category", "has_placed_score",
## "last_score_zero", "has_active_debuff", "powerup_slot_free", "has_powerups",
## "mod_slot_free", "rolls_at_turn_start"
@export var usage_conditions: Array[StringName] = []

## is_available_for_dice_sides(sides: int) -> bool
##
## Returns true if this consumable may appear in the shop / grant pools for a
## run using dice with the given side count. An empty allowed_dice_sets means
## any set. Otherwise the default is whitelist (set must be listed); with
## exclude_listed_dice_sets the list is inverted (set must NOT be listed).
func is_available_for_dice_sides(sides: int) -> bool:
	if allowed_dice_sets.is_empty():
		return true
	return allowed_dice_sets.has(sides) != exclude_listed_dice_sets

## is_usable_in_phase(phase: int) -> bool
##
## Maps usage_window onto GameController.GamePhase:
## BEFORE_ROLL_INITIATED -> IDLE, DURING_ACTIVE_ROUND -> ROUND_ACTIVE,
## AFTER_SCORING -> AFTER_SCORE. ANY_TIME is always usable.
func is_usable_in_phase(phase: int) -> bool:
	match usage_window:
		UsageWindow.ANY_TIME:
			return true
		UsageWindow.BEFORE_ROLL_INITIATED:
			return phase == GameController.GamePhase.IDLE
		UsageWindow.DURING_ACTIVE_ROUND:
			return phase == GameController.GamePhase.ROUND_ACTIVE
		UsageWindow.AFTER_SCORING:
			return phase == GameController.GamePhase.AFTER_SCORE
	return true
