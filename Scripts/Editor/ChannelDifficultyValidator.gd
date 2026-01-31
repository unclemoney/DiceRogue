@tool
extends EditorScript

## ChannelDifficultyValidator
##
## Editor tool for validating and analyzing channel difficulty configurations.
## Run from Editor > Run Script to validate all channel configs.
##
## Features:
## - Validates all channel .tres files for completeness
## - Checks for progression issues (non-increasing difficulty)
## - Generates summary report of difficulty curves
## - Simulates unlock progression

const CHANNELS_PATH := "res://Resources/Data/Channels/"
const CHANNEL_COUNT := 20


func _run() -> void:
	print("\n")
	print("=" .repeat(60))
	print("  CHANNEL DIFFICULTY VALIDATOR")
	print("=" .repeat(60))
	print("")
	
	var results := {
		"valid_count": 0,
		"error_count": 0,
		"warning_count": 0,
		"errors": [],
		"warnings": [],
		"channel_data": []
	}
	
	# Load and validate each channel
	for i in range(1, CHANNEL_COUNT + 1):
		var channel_path = CHANNELS_PATH + "channel_%02d.tres" % i
		_validate_channel(i, channel_path, results)
	
	# Print summary
	_print_summary(results)
	
	# Print progression analysis
	_analyze_progression(results)
	
	# Print unlock simulation
	_simulate_unlock_progression(results)
	
	print("\n")
	print("=" .repeat(60))
	print("  VALIDATION COMPLETE")
	print("=" .repeat(60))


func _validate_channel(channel_num: int, path: String, results: Dictionary) -> void:
	var config = load(path)
	
	if config == null:
		results.error_count += 1
		results.errors.append("Channel %d: Failed to load from %s" % [channel_num, path])
		return
	
	# Basic validation
	var errors := []
	var warnings := []
	
	# Check required fields
	if config.channel_number != channel_num:
		errors.append("channel_number mismatch (expected %d, got %d)" % [channel_num, config.channel_number])
	
	if config.display_name.is_empty():
		errors.append("display_name is empty")
	
	if config.round_configs.size() != 6:
		errors.append("round_configs should have 6 entries (has %d)" % config.round_configs.size())
	
	# Check multipliers are reasonable
	if config.goal_score_multiplier < 0.5 or config.goal_score_multiplier > 20.0:
		warnings.append("goal_score_multiplier %.2f is outside typical range [0.5, 20.0]" % config.goal_score_multiplier)
	
	if config.shop_price_multiplier < 0.5 or config.shop_price_multiplier > 10.0:
		warnings.append("shop_price_multiplier %.2f is outside typical range [0.5, 10.0]" % config.shop_price_multiplier)
	
	if config.debuff_intensity_multiplier < 1.0 or config.debuff_intensity_multiplier > 5.0:
		warnings.append("debuff_intensity_multiplier %.2f is outside typical range [1.0, 5.0]" % config.debuff_intensity_multiplier)
	
	# Validate round configs
	for i in range(config.round_configs.size()):
		var round_config = config.round_configs[i]
		if round_config == null:
			errors.append("round_configs[%d] is null" % i)
			continue
		
		var range_check = round_config.challenge_difficulty_range
		if range_check.x > range_check.y:
			errors.append("round_configs[%d] has invalid difficulty range (min > max)" % i)
		if range_check.x < 0 or range_check.y > 5:
			warnings.append("round_configs[%d] difficulty range %s is outside [0, 5]" % [i, range_check])
	
	# Check unlock requirement progression
	if channel_num > 1 and config.unlock_requirement <= 0:
		warnings.append("unlock_requirement is 0 - channel is always unlocked")
	
	# Run validate() method if available
	if config.has_method("validate"):
		var validation_result = config.validate()
		if not validation_result.valid:
			for err in validation_result.errors:
				errors.append("validate(): " + err)
	
	# Store results
	if errors.size() > 0:
		results.error_count += 1
		for err in errors:
			results.errors.append("Channel %d: %s" % [channel_num, err])
	
	if warnings.size() > 0:
		results.warning_count += warnings.size()
		for warn in warnings:
			results.warnings.append("Channel %d: %s" % [channel_num, warn])
	
	if errors.size() == 0:
		results.valid_count += 1
	
	# Store channel data for analysis
	results.channel_data.append({
		"channel": channel_num,
		"name": config.display_name,
		"goal_mult": config.goal_score_multiplier,
		"shop_mult": config.shop_price_multiplier,
		"goof_mult": config.goof_off_multiplier,
		"yahtzee_mult": config.yahtzee_bonus_multiplier,
		"debuff_mult": config.debuff_intensity_multiplier,
		"unlock_req": config.unlock_requirement
	})


func _print_summary(results: Dictionary) -> void:
	print("\n--- VALIDATION SUMMARY ---")
	print("Valid channels: %d / %d" % [results.valid_count, CHANNEL_COUNT])
	print("Errors: %d" % results.error_count)
	print("Warnings: %d" % results.warning_count)
	
	if results.errors.size() > 0:
		print("\nERRORS:")
		for err in results.errors:
			print("  ❌ " + err)
	
	if results.warnings.size() > 0:
		print("\nWARNINGS:")
		for warn in results.warnings:
			print("  ⚠️ " + warn)


func _analyze_progression(results: Dictionary) -> void:
	print("\n--- DIFFICULTY PROGRESSION ---")
	print("%-8s %-15s %8s %8s %8s %8s %8s %8s" % ["Channel", "Name", "Goal", "Shop", "Goof", "Yahtzee", "Debuff", "Unlock"])
	print("-".repeat(80))
	
	var prev_goal = 0.0
	var prev_debuff = 0.0
	
	for data in results.channel_data:
		var goal_indicator = ""
		var debuff_indicator = ""
		
		# Check for non-monotonic progression
		if data.goal_mult < prev_goal:
			goal_indicator = " ↓"
		if data.debuff_mult < prev_debuff:
			debuff_indicator = " ↓"
		
		print("%-8d %-15s %7.2fx%s %7.2fx %7.2fx %7.2fx %7.2fx%s %8d" % [
			data.channel,
			data.name.left(15),
			data.goal_mult,
			goal_indicator,
			data.shop_mult,
			data.goof_mult,
			data.yahtzee_mult,
			data.debuff_mult,
			debuff_indicator,
			data.unlock_req
		])
		
		prev_goal = data.goal_mult
		prev_debuff = data.debuff_mult


func _simulate_unlock_progression(results: Dictionary) -> void:
	print("\n--- UNLOCK PROGRESSION SIMULATION ---")
	print("Starting with 0 completed channels...\n")
	
	var completed_count := 0
	var unlocked_channels := [1]  # Channel 1 always unlocked
	var order := []
	
	# Simulate completing channels in order
	for i in range(CHANNEL_COUNT):
		# Find next channel to complete (lowest unlocked that's not completed)
		var next_channel := -1
		for ch in unlocked_channels:
			if not ch in order:
				next_channel = ch
				break
		
		if next_channel == -1:
			print("No more channels to complete!")
			break
		
		order.append(next_channel)
		completed_count += 1
		
		# Check what new channels are unlocked
		var newly_unlocked := []
		for data in results.channel_data:
			var ch = data.channel
			if ch in unlocked_channels:
				continue
			if completed_count >= data.unlock_req:
				unlocked_channels.append(ch)
				newly_unlocked.append(ch)
		
		if newly_unlocked.size() > 0:
			print("After completing Channel %d (%d total): Unlocked %s" % [
				next_channel,
				completed_count,
				str(newly_unlocked)
			])
	
	print("\nUnlock order: %s" % str(order))
