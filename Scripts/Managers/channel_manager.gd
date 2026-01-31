extends Node
class_name ChannelManager

## ChannelManager
##
## Manages the difficulty channel system (1-20) using resource-based configuration.
## Each channel has a ChannelDifficultyData resource defining multipliers for:
## - Goal score targets
## - Shop prices and reroll costs
## - Goof-off meter fill rate
## - Debuff intensity
## - Yahtzee bonus rewards
## - Per-round challenge tier ranges and debuff limits

signal channel_changed(new_channel: int)
signal channel_selected(channel: int)
signal difficulty_multiplier_changed(multiplier: float)
signal channel_locked(channel: int, required_completions: int)

const MIN_CHANNEL: int = 1
const MAX_CHANNEL: int = 20

## Preloaded channel difficulty resources
var channel_configs: Array[ChannelDifficultyData] = []

var current_channel: int = 1


func _ready() -> void:
	_load_channel_configs()
	print("[ChannelManager] Initialized at Channel", current_channel, "with", channel_configs.size(), "configs loaded")


## _load_channel_configs()
##
## Loads all channel difficulty resources from Resources/Data/Channels/
func _load_channel_configs() -> void:
	channel_configs.clear()
	
	for i in range(1, MAX_CHANNEL + 1):
		var path = "res://Resources/Data/Channels/channel_%02d.tres" % i
		var config = load(path) as ChannelDifficultyData
		if config:
			channel_configs.append(config)
			print("[ChannelManager] Loaded config for Channel", i)
		else:
			push_error("[ChannelManager] Failed to load channel config:", path)
			# Create a fallback config
			var fallback = ChannelDifficultyData.new()
			fallback.channel_number = i
			fallback.display_name = "Channel %02d" % i
			fallback.goal_score_multiplier = 1.0 + (i - 1) * 0.5
			channel_configs.append(fallback)


## get_channel_config(channel: int) -> ChannelDifficultyData
##
## Returns the difficulty configuration for a specific channel.
## @param channel: Channel number (1-20), defaults to current if -1
## @return: ChannelDifficultyData resource or null
func get_channel_config(channel: int = -1) -> ChannelDifficultyData:
	if channel < 0:
		channel = current_channel
	
	var index = clampi(channel, MIN_CHANNEL, MAX_CHANNEL) - 1
	if index >= 0 and index < channel_configs.size():
		return channel_configs[index]
	
	return null


## get_round_config(channel: int, round_number: int) -> RoundDifficultyConfig
##
## Returns the round-specific difficulty configuration.
## @param channel: Channel number (1-20), defaults to current if -1
## @param round_number: Round number (1-6)
## @return: RoundDifficultyConfig resource or null
func get_round_config(channel: int = -1, round_number: int = 1) -> RoundDifficultyConfig:
	var config = get_channel_config(channel)
	if config:
		return config.get_round_config(round_number)
	return null


## get_difficulty_multiplier(channel: int) -> float
##
## Returns the goal score multiplier for a given channel from the resource.
## @param channel: Channel number (defaults to current_channel if -1)
## @return: The goal_score_multiplier from the channel config
func get_difficulty_multiplier(channel: int = -1) -> float:
	var config = get_channel_config(channel)
	if config:
		return config.goal_score_multiplier
	
	# Fallback if no config loaded
	return 1.0


## get_scaled_target_score(base_score: int, channel: int) -> int
##
## Returns the target score scaled by the channel's goal_score_multiplier.
## @param base_score: The original target score from ChallengeData
## @param channel: The channel number (defaults to current_channel if -1)
## @return: The scaled target score (rounded to nearest integer)
func get_scaled_target_score(base_score: int, channel: int = -1) -> int:
	var multiplier = get_difficulty_multiplier(channel)
	var scaled = int(round(base_score * multiplier))
	return scaled


## get_shop_price_multiplier(channel: int) -> float
##
## Returns the shop price multiplier for PowerUps/Consumables/Mods.
func get_shop_price_multiplier(channel: int = -1) -> float:
	var config = get_channel_config(channel)
	if config:
		return config.shop_price_multiplier
	return 1.0


## get_colored_dice_cost_multiplier(channel: int) -> float
##
## Returns the colored dice base cost multiplier.
func get_colored_dice_cost_multiplier(channel: int = -1) -> float:
	var config = get_channel_config(channel)
	if config:
		return config.colored_dice_cost_multiplier
	return 1.0


## get_reroll_cost_multiplier(channel: int) -> float
##
## Returns the shop reroll cost multiplier.
func get_reroll_cost_multiplier(channel: int = -1) -> float:
	var config = get_channel_config(channel)
	if config:
		return config.reroll_base_cost_multiplier
	return 1.0


## get_goof_off_multiplier(channel: int) -> float
##
## Returns the goof-off meter fill rate multiplier.
## Higher = fills faster (harder).
func get_goof_off_multiplier(channel: int = -1) -> float:
	var config = get_channel_config(channel)
	if config:
		return config.goof_off_multiplier
	return 1.0


## get_yahtzee_bonus_multiplier(channel: int) -> float
##
## Returns the yahtzee bonus point multiplier.
func get_yahtzee_bonus_multiplier(channel: int = -1) -> float:
	var config = get_channel_config(channel)
	if config:
		return config.yahtzee_bonus_multiplier
	return 1.0


## get_debuff_intensity_multiplier(channel: int) -> float
##
## Returns the debuff intensity multiplier.
## Higher = stronger debuff effects.
func get_debuff_intensity_multiplier(channel: int = -1) -> float:
	var config = get_channel_config(channel)
	if config:
		return config.debuff_intensity_multiplier
	return 1.0


## get_bonus_multiplier(channel: int, round_number: int, bonus_type: String) -> float
##
## Returns the bonus multiplier for end-of-round rewards.
## @param bonus_type: "empty_category", "points_above", or "chore_completion"
func get_bonus_multiplier(channel: int = -1, round_number: int = 1, bonus_type: String = "empty_category") -> float:
	var config = get_channel_config(channel)
	if config:
		return config.get_bonus_multiplier(round_number, bonus_type)
	return 1.0


## is_shop_item_disabled(item_id: String, channel: int) -> bool
##
## Checks if an item should be hidden from the shop for this channel.
func is_shop_item_disabled(item_id: String, channel: int = -1) -> bool:
	var config = get_channel_config(channel)
	if config:
		return config.is_shop_item_disabled(item_id)
	return false


## get_challenge_difficulty_range(channel: int, round_number: int) -> Vector2i
##
## Returns the allowed challenge difficulty tier range for a round.
func get_challenge_difficulty_range(channel: int = -1, round_number: int = 1) -> Vector2i:
	var config = get_channel_config(channel)
	if config:
		return config.get_challenge_difficulty_range(round_number)
	return Vector2i(0, 5)  # Fallback: allow all tiers


## get_max_debuffs(channel: int, round_number: int) -> int
##
## Returns the maximum debuff count for a round.
func get_max_debuffs(channel: int = -1, round_number: int = 1) -> int:
	var config = get_channel_config(channel)
	if config:
		return config.get_max_debuffs(round_number)
	return 0


## get_debuff_difficulty_cap(channel: int, round_number: int) -> int
##
## Returns the max debuff difficulty allowed for a round.
func get_debuff_difficulty_cap(channel: int = -1, round_number: int = 1) -> int:
	var config = get_channel_config(channel)
	if config:
		return config.get_debuff_difficulty_cap(round_number)
	return 1


## get_forced_challenge(channel: int, round_number: int) -> String
##
## Returns a forced challenge ID if one is configured for the round.
func get_forced_challenge(channel: int = -1, round_number: int = 1) -> String:
	var config = get_channel_config(channel)
	if config:
		return config.get_forced_challenge(round_number)
	return ""


## is_channel_unlocked(channel: int) -> bool
##
## Checks if a channel is unlocked based on player's total completions.
## @param channel: Channel to check (1-20)
## @return: True if the player has enough completions to access this channel
func is_channel_unlocked(channel: int) -> bool:
	var config = get_channel_config(channel)
	if not config:
		return false
	
	# Channel 1 is always unlocked
	if channel <= 1:
		return true
	
	# Get total completions from PlayerProgress (via ProgressManager autoload)
	var progress_manager = get_node_or_null("/root/ProgressManager")
	if progress_manager and progress_manager.has_method("get_total_channel_completions"):
		var completions = progress_manager.get_total_channel_completions()
		return completions >= config.unlock_requirement
	
	# Fallback: check if unlock_requirement is 0
	return config.unlock_requirement <= 0


## get_unlock_requirement(channel: int) -> int
##
## Returns the number of completions needed to unlock a channel.
func get_unlock_requirement(channel: int) -> int:
	var config = get_channel_config(channel)
	if config:
		return config.unlock_requirement
	return 0


## set_channel(channel: int) -> void
##
## Sets the current channel, clamped to valid range.
## Emits channel_changed signal.
func set_channel(channel: int) -> void:
	var old_channel = current_channel
	current_channel = clampi(channel, MIN_CHANNEL, MAX_CHANNEL)
	
	if current_channel != old_channel:
		var config = get_channel_config(current_channel)
		var display_name = config.display_name if config else "Channel %02d" % current_channel
		print("[ChannelManager] Channel changed from", old_channel, "to", current_channel, "-", display_name)
		print("[ChannelManager] Goal multiplier:", get_difficulty_multiplier())
		emit_signal("channel_changed", current_channel)
		emit_signal("difficulty_multiplier_changed", get_difficulty_multiplier())


## increment_channel() -> void
##
## Increases the channel by 1, capped at MAX_CHANNEL.
func increment_channel() -> void:
	set_channel(current_channel + 1)


## decrement_channel() -> void
##
## Decreases the channel by 1, floored at MIN_CHANNEL.
func decrement_channel() -> void:
	set_channel(current_channel - 1)


## advance_to_next_channel() -> bool
##
## Called when player wins all rounds. Advances to the next channel.
## Returns false if already at max channel or next channel is locked.
func advance_to_next_channel() -> bool:
	if current_channel >= MAX_CHANNEL:
		print("[ChannelManager] Already at max channel", MAX_CHANNEL)
		return false
	
	var next_channel = current_channel + 1
	
	# Check if next channel is unlocked
	if not is_channel_unlocked(next_channel):
		var required = get_unlock_requirement(next_channel)
		print("[ChannelManager] Channel", next_channel, "is locked. Requires", required, "completions.")
		emit_signal("channel_locked", next_channel, required)
		return false
	
	increment_channel()
	print("[ChannelManager] Advanced to Channel", current_channel)
	return true


## select_channel() -> void
##
## Called when player confirms their channel selection at game start.
## Emits channel_selected signal to trigger game start.
func select_channel() -> void:
	var config = get_channel_config(current_channel)
	var display_name = config.display_name if config else "Channel %02d" % current_channel
	print("[ChannelManager] Channel", current_channel, "selected! -", display_name)
	print("[ChannelManager] Goal multiplier:", "%.2f" % get_difficulty_multiplier(), "x")
	emit_signal("channel_selected", current_channel)


## reset() -> void
##
## Resets channel to 1. Called on new game.
func reset() -> void:
	current_channel = 1
	print("[ChannelManager] Reset to Channel 1")
	emit_signal("channel_changed", current_channel)
	emit_signal("difficulty_multiplier_changed", get_difficulty_multiplier())


## get_channel_display_text() -> String
##
## Returns a zero-padded channel number string for display (e.g., "01", "20")
func get_channel_display_text() -> String:
	return "%02d" % current_channel


## get_channel_display_name() -> String
##
## Returns the display name from the channel config.
func get_channel_display_name() -> String:
	var config = get_channel_config(current_channel)
	if config and config.display_name:
		return config.display_name
	return "Channel %02d" % current_channel


## get_difficulty_description() -> String
##
## Returns a human-readable description of the current difficulty.
func get_difficulty_description() -> String:
	var mult = get_difficulty_multiplier()
	if mult < 1.2:
		return "Easy"
	elif mult < 2.0:
		return "Normal"
	elif mult < 3.5:
		return "Hard"
	elif mult < 5.0:
		return "Very Hard"
	elif mult < 7.0:
		return "Extreme"
	else:
		return "Impossible"


## validate_all_configs() -> Array[String]
##
## Validates all loaded channel configurations.
## Returns an array of error messages (empty if all valid).
func validate_all_configs() -> Array[String]:
	var all_errors: Array[String] = []
	
	for config in channel_configs:
		if config:
			var errors = config.validate()
			for error in errors:
				all_errors.append("Channel %d: %s" % [config.channel_number, error])
	
	return all_errors
