extends Resource
class_name ChannelDifficultyData

## ChannelDifficultyData
##
## Defines all difficulty parameters for a single channel (1-20).
## Contains multipliers for economy, scoring, debuffs, and per-round configurations.
## Used by ChannelManager to control game difficulty instead of hardcoded formulas.

## The channel number this config applies to (1-20)
@export var channel_number: int = 1

## Display name for UI (e.g., "Channel 01", "The Gauntlet")
@export var display_name: String = ""

## Optional description of this channel's theme or difficulty
@export var description: String = ""

## ============== UNLOCK SYSTEM ==============

## Number of total channel completions required to unlock this channel
## 0 = unlocked by default (channel 1), higher values gate later channels
@export var unlock_requirement: int = 0

## ============== ROUND CONFIGURATIONS ==============

## Per-round difficulty settings (should have 6 elements for rounds 1-6)
@export var round_configs: Array[RoundDifficultyConfig] = []

## ============== SCORE & GOAL MULTIPLIERS ==============

## Multiplier applied to challenge target scores
## 1.0 = base target, 2.0 = double target, etc.
@export var goal_score_multiplier: float = 1.0

## Multiplier applied to yahtzee bonus points ($100 base)
## Higher channels reward skilled play more
@export var yahtzee_bonus_multiplier: float = 1.0

## ============== ECONOMY MULTIPLIERS ==============

## Multiplier for shop item prices (PowerUps, Consumables, Mods)
## 1.0 = base price, 2.0 = double price
@export var shop_price_multiplier: float = 1.0

## Multiplier for colored dice base costs
## Applied before exponential scaling from purchases
@export var colored_dice_cost_multiplier: float = 1.0

## Multiplier for shop reroll base cost ($25 base)
@export var reroll_base_cost_multiplier: float = 1.0

## ============== GOOF-OFF METER ==============

## Multiplier for goof-off meter fill rate
## Lower values = meter fills slower (easier), Higher = fills faster (harder)
## 1.0 = 100 rolls to fill, 0.5 = 200 rolls, 2.0 = 50 rolls
@export var goof_off_multiplier: float = 1.0

## ============== DEBUFF SYSTEM ==============

## Intensity multiplier for debuff effects
## 1.0 = normal effects, 2.0 = double intensity (e.g., costly_roll costs 2x)
@export var debuff_intensity_multiplier: float = 1.0

## ============== SPECIAL OVERRIDES ==============

## Force specific challenge IDs for certain rounds (optional)
## If specified, these challenge IDs are used instead of random selection
## Array of challenge_id strings, indexed by round (0-5)
@export var force_specific_challenges: Array[String] = []

## Shop item IDs to exclude from appearing in this channel
## Useful for restricting powerful items in early channels
@export var disabled_shop_items: Array[String] = []

## Arbitrary key-value config for special channel rules
## Examples: {"no_colored_dice": true, "double_yahtzee_scoring": true}
@export var special_rules: Dictionary = {}


## ============== METHODS ==============

## get_round_config(round_number: int) -> RoundDifficultyConfig
##
## Returns the difficulty config for a specific round.
## @param round_number: 1-based round number (1-6)
## @return: RoundDifficultyConfig or null if not found
func get_round_config(round_number: int) -> RoundDifficultyConfig:
	var index = round_number - 1
	if index >= 0 and index < round_configs.size():
		return round_configs[index]
	return null


## get_challenge_difficulty_range(round_number: int) -> Vector2i
##
## Returns the allowed challenge difficulty tier range for a round.
## @param round_number: 1-based round number
## @return: Vector2i with x=min_tier, y=max_tier
func get_challenge_difficulty_range(round_number: int) -> Vector2i:
	var config = get_round_config(round_number)
	if config:
		return config.challenge_difficulty_range
	# Default fallback: tier equals round number - 1
	return Vector2i(round_number - 1, round_number - 1)


## get_max_debuffs(round_number: int) -> int
##
## Returns the maximum debuff count for a round.
## @param round_number: 1-based round number
## @return: Max debuffs (-1 = unlimited)
func get_max_debuffs(round_number: int) -> int:
	var config = get_round_config(round_number)
	if config:
		return config.max_debuffs
	return 0  # Default: no debuffs


## get_debuff_difficulty_cap(round_number: int) -> int
##
## Returns the debuff difficulty cap for a round.
## @param round_number: 1-based round number
## @return: Maximum allowed debuff difficulty
func get_debuff_difficulty_cap(round_number: int) -> int:
	var config = get_round_config(round_number)
	if config:
		return config.debuff_difficulty_cap
	return 1  # Default: only easy debuffs


## get_bonus_multiplier(round_number: int, bonus_type: String) -> float
##
## Returns the bonus multiplier for a specific round and bonus type.
## @param round_number: 1-based round number
## @param bonus_type: "empty_category", "points_above", or "chore_completion"
## @return: Multiplier value (default 1.0)
func get_bonus_multiplier(round_number: int, bonus_type: String) -> float:
	var config = get_round_config(round_number)
	if config:
		return config.get_bonus_multiplier(bonus_type)
	return 1.0


## is_shop_item_disabled(item_id: String) -> bool
##
## Checks if a shop item is disabled for this channel.
## @param item_id: The item's unique identifier
## @return: True if the item should not appear in shop
func is_shop_item_disabled(item_id: String) -> bool:
	return disabled_shop_items.has(item_id)


## get_forced_challenge(round_number: int) -> String
##
## Returns the forced challenge ID for a round, if any.
## @param round_number: 1-based round number
## @return: Challenge ID or empty string if no override
func get_forced_challenge(round_number: int) -> String:
	var index = round_number - 1
	if index >= 0 and index < force_specific_challenges.size():
		var challenge_id = force_specific_challenges[index]
		if challenge_id and not challenge_id.is_empty():
			return challenge_id
	return ""


## has_special_rule(rule_key: String) -> bool
##
## Checks if a special rule is enabled for this channel.
## @param rule_key: The rule identifier
## @return: True if the rule exists and is truthy
func has_special_rule(rule_key: String) -> bool:
	return special_rules.get(rule_key, false)


## get_special_rule(rule_key: String, default_value: Variant = null) -> Variant
##
## Gets a special rule value with a default fallback.
## @param rule_key: The rule identifier
## @param default_value: Value to return if rule doesn't exist
## @return: The rule value or default
func get_special_rule(rule_key: String, default_value: Variant = null) -> Variant:
	return special_rules.get(rule_key, default_value)


## get_summary() -> String
##
## Returns a human-readable summary of this channel's configuration.
## Useful for debugging and the channel editor tool.
func get_summary() -> String:
	var lines: Array[String] = []
	
	lines.append("=== Channel %d: %s ===" % [channel_number, display_name if display_name else "Unnamed"])
	
	if description:
		lines.append("Description: %s" % description)
	
	lines.append("Unlock Requirement: %d completions" % unlock_requirement)
	lines.append("")
	lines.append("Multipliers:")
	lines.append("  Goal Score: %.2fx" % goal_score_multiplier)
	lines.append("  Yahtzee Bonus: %.2fx" % yahtzee_bonus_multiplier)
	lines.append("  Shop Prices: %.2fx" % shop_price_multiplier)
	lines.append("  Colored Dice: %.2fx" % colored_dice_cost_multiplier)
	lines.append("  Reroll Cost: %.2fx" % reroll_base_cost_multiplier)
	lines.append("  Goof-off Rate: %.2fx" % goof_off_multiplier)
	lines.append("  Debuff Intensity: %.2fx" % debuff_intensity_multiplier)
	lines.append("")
	lines.append("Rounds:")
	
	for i in range(round_configs.size()):
		var round_config = round_configs[i]
		if round_config:
			lines.append("  " + round_config.get_summary())
	
	if force_specific_challenges.size() > 0:
		lines.append("")
		lines.append("Forced Challenges: %s" % str(force_specific_challenges))
	
	if disabled_shop_items.size() > 0:
		lines.append("Disabled Items: %s" % str(disabled_shop_items))
	
	if special_rules.size() > 0:
		lines.append("Special Rules: %s" % str(special_rules))
	
	return "\n".join(lines)


## validate() -> Array[String]
##
## Validates the channel configuration and returns any errors found.
## @return: Array of error messages (empty if valid)
func validate() -> Array[String]:
	var errors: Array[String] = []
	
	if channel_number < 1 or channel_number > 20:
		errors.append("Invalid channel_number: %d (must be 1-20)" % channel_number)
	
	if round_configs.size() != 6:
		errors.append("Expected 6 round configs, found %d" % round_configs.size())
	
	for i in range(round_configs.size()):
		var config = round_configs[i]
		if config == null:
			errors.append("Round config %d is null" % (i + 1))
		elif config.round_number != i + 1:
			errors.append("Round config %d has mismatched round_number: %d" % [i + 1, config.round_number])
	
	if goal_score_multiplier <= 0:
		errors.append("goal_score_multiplier must be positive: %.2f" % goal_score_multiplier)
	
	if shop_price_multiplier <= 0:
		errors.append("shop_price_multiplier must be positive: %.2f" % shop_price_multiplier)
	
	if goof_off_multiplier <= 0:
		errors.append("goof_off_multiplier must be positive: %.2f" % goof_off_multiplier)
	
	if debuff_intensity_multiplier < 1.0:
		errors.append("debuff_intensity_multiplier should be >= 1.0: %.2f" % debuff_intensity_multiplier)
	
	# Check unlock requirement is monotonically increasing (compared to expected)
	# Channel N should require roughly N-1 or similar progression
	if channel_number > 1 and unlock_requirement < 0:
		errors.append("unlock_requirement cannot be negative: %d" % unlock_requirement)
	
	return errors
