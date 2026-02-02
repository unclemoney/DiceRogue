extends Resource
class_name RoundDifficultyConfig

## RoundDifficultyConfig
##
## Configures difficulty parameters for a single round within a channel.
## Controls challenge selection, debuff limits, goof-off threshold overrides,
## and bonus multipliers for end-of-round rewards.

## The round number this config applies to (1-6)
@export var round_number: int = 1

## Challenge difficulty tier range for random selection
## x = minimum tier, y = maximum tier (inclusive, 0-5)
@export var challenge_difficulty_range: Vector2i = Vector2i(0, 0)

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


## is_challenge_tier_valid(tier: int) -> bool
##
## Checks if a challenge tier falls within the allowed range for this round.
## @param tier: The challenge difficulty tier (0-5)
## @return: True if the tier is within range
func is_challenge_tier_valid(tier: int) -> bool:
	return tier >= challenge_difficulty_range.x and tier <= challenge_difficulty_range.y


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
	var summary = "Round %d: Tiers %d-%d, Max Debuffs: %s, Debuff Cap: %d" % [
		round_number,
		challenge_difficulty_range.x,
		challenge_difficulty_range.y,
		str(max_debuffs) if max_debuffs >= 0 else "unlimited",
		debuff_difficulty_cap
	]
	
	if goof_off_threshold_override >= 0:
		summary += ", Goof-off: %d" % goof_off_threshold_override
	
	return summary
