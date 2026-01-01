extends Resource
class_name UnlockCondition

## UnlockCondition Resource
##
## Defines the requirements for unlocking PowerUps, Consumables, or Colored Dice features.
## Each condition has a type and parameters that determine when it should be triggered.

enum ConditionType {
	SCORE_POINTS,           # Score X points in a single category
	ROLL_YAHTZEE,          # Roll a yahtzee (5 of a kind) in a single game
	COMPLETE_GAME,         # Complete a full game
	SCORE_CATEGORY,        # Score in a specific category (e.g., "full_house")
	ROLL_STRAIGHT,         # Roll a large or small straight
	USE_CONSUMABLES,       # Use X number of consumables in a single game
	EARN_MONEY,            # Earn X dollars in a single game
	COLORED_DICE_BONUS,    # Trigger 5+ same color bonus
	SCORE_UPPER_BONUS,     # Achieve upper section bonus (63+ points)
	WIN_GAMES,             # Win X number of games
	CUMULATIVE_SCORE,      # Achieve total score across all games
	DICE_COMBINATIONS,     # Roll specific dice combinations
	CUMULATIVE_YAHTZEES,   # Roll X yahtzees across all games (cumulative)
	COMPLETE_CHANNEL,      # Complete channel X (reach highest_channel_completed >= target)
	REACH_CHANNEL          # Alias for COMPLETE_CHANNEL - reach a specific channel
}

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var condition_type: ConditionType = ConditionType.SCORE_POINTS
@export var target_value: int = 0
@export var additional_params: Dictionary = {}

## Check if this condition is satisfied by the given game statistics
## @param game_stats: Dictionary containing game statistics
## @param progress_data: Dictionary containing cumulative progress data
## @return bool: True if condition is satisfied
func is_satisfied(game_stats: Dictionary, progress_data: Dictionary) -> bool:
	match condition_type:
		ConditionType.SCORE_POINTS:
			var max_category_score = game_stats.get("max_category_score", 0)
			return max_category_score >= target_value
			
		ConditionType.ROLL_YAHTZEE:
			var yahtzees_rolled = game_stats.get("yahtzees_rolled", 0)
			return yahtzees_rolled >= target_value
			
		ConditionType.COMPLETE_GAME:
			var games_completed = progress_data.get("games_completed", 0)
			return games_completed >= target_value
			
		ConditionType.SCORE_CATEGORY:
			var target_category = additional_params.get("category", "")
			var categories_scored = game_stats.get("categories_scored", [])
			return target_category in categories_scored
			
		ConditionType.ROLL_STRAIGHT:
			var straights_rolled = game_stats.get("straights_rolled", 0)
			return straights_rolled >= target_value
			
		ConditionType.USE_CONSUMABLES:
			var consumables_used = game_stats.get("consumables_used", 0)
			return consumables_used >= target_value
			
		ConditionType.EARN_MONEY:
			var money_earned = game_stats.get("money_earned", 0)
			return money_earned >= target_value
			
		ConditionType.COLORED_DICE_BONUS:
			var color_bonuses = game_stats.get("same_color_bonuses", 0)
			return color_bonuses >= target_value
			
		ConditionType.SCORE_UPPER_BONUS:
			var upper_bonus_achieved = game_stats.get("upper_bonus_achieved", false)
			return upper_bonus_achieved
			
		ConditionType.WIN_GAMES:
			var games_won = progress_data.get("games_won", 0)
			return games_won >= target_value
			
		ConditionType.CUMULATIVE_SCORE:
			var total_score = progress_data.get("total_score", 0)
			return total_score >= target_value
			
		ConditionType.DICE_COMBINATIONS:
			var combination_type = additional_params.get("combination", "")
			var combinations = game_stats.get("combinations_rolled", {})
			return combinations.get(combination_type, 0) >= target_value
			
		ConditionType.CUMULATIVE_YAHTZEES:
			var total_yahtzees = progress_data.get("total_yahtzees", 0)
			return total_yahtzees >= target_value
			
		ConditionType.COMPLETE_CHANNEL:
			var highest_channel = progress_data.get("highest_channel_completed", 0)
			return highest_channel >= target_value
			
		ConditionType.REACH_CHANNEL:
			var highest_channel_reached = progress_data.get("highest_channel_completed", 0)
			return highest_channel_reached >= target_value
			
		_:
			push_error("[UnlockCondition] Unknown condition type: %s" % condition_type)
			return false

## Get a formatted description of this condition's requirements
## @return String: Human-readable description
func get_formatted_description() -> String:
	match condition_type:
		ConditionType.SCORE_POINTS:
			return "Score %d points in a single category" % target_value
		ConditionType.ROLL_YAHTZEE:
			if target_value == 1:
				return "Roll a Yahtzee"
			else:
				return "Roll %d Yahtzees" % target_value
		ConditionType.COMPLETE_GAME:
			if target_value == 1:
				return "Complete a game"
			else:
				return "Complete %d games" % target_value
		ConditionType.SCORE_CATEGORY:
			var category = additional_params.get("category", "unknown")
			return "Score in %s category" % category.replace("_", " ").capitalize()
		ConditionType.ROLL_STRAIGHT:
			if target_value == 1:
				return "Roll a straight"
			else:
				return "Roll %d straights" % target_value
		ConditionType.USE_CONSUMABLES:
			if target_value == 1:
				return "Use a consumable"
			else:
				return "Use %d consumables in one game" % target_value
		ConditionType.EARN_MONEY:
			return "Earn $%d in a single game" % target_value
		ConditionType.COLORED_DICE_BONUS:
			if target_value == 1:
				return "Trigger a 5+ same color bonus"
			else:
				return "Trigger %d same color bonuses" % target_value
		ConditionType.SCORE_UPPER_BONUS:
			return "Achieve upper section bonus (63+ points)"
		ConditionType.WIN_GAMES:
			if target_value == 1:
				return "Win a game"
			else:
				return "Win %d games" % target_value
		ConditionType.CUMULATIVE_SCORE:
			return "Score %d total points across all games" % target_value
		ConditionType.DICE_COMBINATIONS:
			var combination = additional_params.get("combination", "unknown")
			return "Roll %s" % combination.replace("_", " ").capitalize()
		ConditionType.CUMULATIVE_YAHTZEES:
			if target_value == 1:
				return "Roll a Yahtzee (total across all games)"
			else:
				return "Roll %d Yahtzees (total across all games)" % target_value
		ConditionType.COMPLETE_CHANNEL:
			return "Complete Channel %d" % target_value
		ConditionType.REACH_CHANNEL:
			return "Reach Channel %d" % target_value
		_:
			return description if description else "Unknown condition"