extends Resource
class_name RoundDifficultyConfig

## RoundDifficultyConfig
##
## Configures difficulty parameters for a single round within a channel.
## Controls challenge selection, debuff limits, goof-off threshold overrides,
## and bonus multipliers for end-of-round rewards.

## The round number this config applies to (1-6)
@export var round_number: int = 1

## Maximum number of debuffs that can be applied this round
## 0 = no debuffs, -1 = no limit
@export var max_debuffs: int = 0

## Maximum difficulty rating of debuffs that can be selected
## Higher values allow more punishing debuffs
@export var debuff_difficulty_cap: int = 1

## Optional override for goof-off meter threshold this round
## -1 = use channel default with round scaling
@export var goof_off_threshold_override: int = -1

## Optional target score override for this round
## 0 = use Challenge resource target_score (default)
## > 0 = use this value as the base target (before channel scaling)
@export var target_score_override: int = 0

## Legacy compatibility field retained for existing channel resources.
## Round-owned Groundings were removed, so runtime ignores this value.
@export_range(0.0, 1.0) var grounding_chance: float = 0.0

## Boss round flag (final round of a zone). Boss rounds draw exactly one
## debuff of boss_debuff_level instead of the regular pool draw.
@export var is_boss_round: bool = false

## Exact difficulty level for the boss debuff draw when is_boss_round.
@export_range(1, 5) var boss_debuff_level: int = 5

## Optional reward money override for this round
## 0 = use ChallengeData.reward_money as fallback
## > 0 = use this value as the challenge reward for the round
@export var reward_money_override: int = 0

## Multipliers for end-of-round bonus calculations
## Keys: "empty_category", "points_above", "chore_completion"
## Default 1.0 = no change, higher values = more rewarding
@export var bonus_multipliers: Dictionary = {
	"empty_category": 1.0,
	"points_above": 1.0,
	"chore_completion": 1.0
}


## get_bonus_multiplier(bonus_type: String) -> float
##
## Returns the multiplier for a specific bonus type.
## Falls back to 1.0 if the bonus type isn't defined.
## @param bonus_type: One of "empty_category", "points_above", "chore_completion"
## @return: The multiplier value (default 1.0)
func get_bonus_multiplier(bonus_type: String) -> float:
	return bonus_multipliers.get(bonus_type, 1.0)


## can_apply_debuff(current_count: int, debuff_difficulty: int) -> bool
##
## Checks if another debuff can be applied based on count and difficulty limits.
## @param current_count: Number of debuffs already applied this round
## @param debuff_difficulty: Difficulty rating of the proposed debuff
## @return: True if the debuff can be applied
func can_apply_debuff(current_count: int, debuff_difficulty: int) -> bool:
	# Check count limit (-1 means no limit)
	if max_debuffs >= 0 and current_count >= max_debuffs:
		return false
	
	# Check difficulty cap
	if debuff_difficulty > debuff_difficulty_cap:
		return false
	
	return true


## get_summary() -> String
##
## Returns a human-readable summary of this round's configuration.
## Useful for debugging and the channel editor tool.
func get_summary() -> String:
	var summary = "Round %d: Max Debuffs: %s, Debuff Cap: %d" % [
		round_number,
		str(max_debuffs) if max_debuffs >= 0 else "unlimited",
		debuff_difficulty_cap
	]

	if is_boss_round:
		summary += ", BOSS (debuff level %d)" % boss_debuff_level

	if goof_off_threshold_override >= 0:
		summary += ", Goof-off: %d" % goof_off_threshold_override

	if reward_money_override > 0:
		summary += ", Reward: $%d" % reward_money_override

	return summary
