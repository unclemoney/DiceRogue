extends Node
class_name ChannelManager

## ChannelManager
##
## Manages the difficulty channel system (1-99).
## Higher channels increase the target score for challenges using quadratic growth.
## Channel 1 = 1.0x multiplier, Channel 99 = 100x multiplier.
## Formula: 1.0 + pow((channel - 1) / 98.0, 2) * 99.0

signal channel_changed(new_channel: int)
signal channel_selected(channel: int)
signal difficulty_multiplier_changed(multiplier: float)

const MIN_CHANNEL: int = 1
const MAX_CHANNEL: int = 99

var current_channel: int = 1


func _ready() -> void:
	print("[ChannelManager] Initialized at Channel", current_channel)


## get_difficulty_multiplier(channel: int) -> float
##
## Returns the difficulty multiplier for a given channel using quadratic growth.
## Channel 1 = 1.0x (no change)
## Channel 2 ≈ 1.01x (very slight increase)
## Channel 50 ≈ 25x
## Channel 99 = 100x
func get_difficulty_multiplier(channel: int = -1) -> float:
	if channel < 0:
		channel = current_channel
	
	# Clamp channel to valid range
	channel = clampi(channel, MIN_CHANNEL, MAX_CHANNEL)
	
	# Quadratic formula: 1.0 + pow((channel - 1) / 98.0, 2) * 99.0
	var normalized = float(channel - 1) / 98.0
	var multiplier = 1.0 + pow(normalized, 2) * 99.0
	
	return multiplier


## get_scaled_target_score(base_score: int, channel: int) -> int
##
## Returns the target score scaled by the channel's difficulty multiplier.
## @param base_score: The original target score from ChallengeData
## @param channel: The channel number (defaults to current_channel if -1)
## @return: The scaled target score (rounded to nearest integer)
func get_scaled_target_score(base_score: int, channel: int = -1) -> int:
	var multiplier = get_difficulty_multiplier(channel)
	var scaled = int(round(base_score * multiplier))
	return scaled


## set_channel(channel: int) -> void
##
## Sets the current channel, clamped to valid range.
## Emits channel_changed signal.
func set_channel(channel: int) -> void:
	var old_channel = current_channel
	current_channel = clampi(channel, MIN_CHANNEL, MAX_CHANNEL)
	
	if current_channel != old_channel:
		print("[ChannelManager] Channel changed from", old_channel, "to", current_channel)
		print("[ChannelManager] Difficulty multiplier:", get_difficulty_multiplier())
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


## advance_to_next_channel() -> void
##
## Called when player wins all rounds. Advances to the next channel.
## Returns false if already at max channel.
func advance_to_next_channel() -> bool:
	if current_channel >= MAX_CHANNEL:
		print("[ChannelManager] Already at max channel", MAX_CHANNEL)
		return false
	
	increment_channel()
	print("[ChannelManager] Advanced to Channel", current_channel)
	return true


## select_channel() -> void
##
## Called when player confirms their channel selection at game start.
## Emits channel_selected signal to trigger game start.
func select_channel() -> void:
	print("[ChannelManager] Channel", current_channel, "selected!")
	print("[ChannelManager] Difficulty multiplier:", "%.2f" % get_difficulty_multiplier(), "x")
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
## Returns a zero-padded channel number string for display (e.g., "01", "42", "99")
func get_channel_display_text() -> String:
	return "%02d" % current_channel


## get_difficulty_description() -> String
##
## Returns a human-readable description of the current difficulty.
func get_difficulty_description() -> String:
	var mult = get_difficulty_multiplier()
	if mult < 1.1:
		return "Easy"
	elif mult < 2.0:
		return "Normal"
	elif mult < 5.0:
		return "Hard"
	elif mult < 15.0:
		return "Very Hard"
	elif mult < 40.0:
		return "Extreme"
	else:
		return "Impossible"
