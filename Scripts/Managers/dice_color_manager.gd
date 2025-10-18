extends Node

## DiceColorManager - Autoload for managing dice color system
## Handles global color settings, effect calculations, and integration with scoring

# Import DiceColor class to avoid shadowing warning
const DiceColorClass = preload("res://Scripts/Core/dice_color.gd")

signal colors_enabled_changed(enabled: bool)
signal color_effects_calculated(green_money: int, red_additive: int, purple_multiplier: float, same_color_bonus: bool)

var colors_enabled: bool = true

func _ready() -> void:
	add_to_group("dice_color_manager")
	print("[DiceColorManager] Initialized and added to dice_color_manager group")

## Calculate dice color effects for scoring
## @param dice_array: Array[Dice] dice to analyze for color effects
## @return Dictionary with money, additive, multiplier, and bonus information
func calculate_color_effects(dice_array: Array) -> Dictionary:
	if not colors_enabled:
		return _get_empty_effects()
	
	var green_count := 0
	var red_count := 0
	var purple_count := 0
	var green_money := 0
	var red_additive := 0
	var purple_multiplier := 1.0
	
	# Count colored dice and calculate base effects
	for i in range(dice_array.size()):
		var dice = dice_array[i]
		if not dice is Dice:
			continue
		
		var dice_color = dice.get_color()
		var dice_value = dice.value
		
		match dice_color:
			DiceColorClass.Type.GREEN:
				green_count += 1
				green_money += dice_value
			DiceColorClass.Type.RED:
				red_count += 1
				red_additive += dice_value
			DiceColorClass.Type.PURPLE:
				purple_count += 1
				purple_multiplier *= dice_value # CHANGED FROM *= to +=
			DiceColorClass.Type.NONE:
				pass  # No effect
	
	# Check for same color bonus (5+ of any color gets 2x)
	var same_color_bonus := false
	if green_count >= 5 or red_count >= 5 or purple_count >= 5:
		same_color_bonus = true
		
		# Only apply bonus to the colors that actually exist
		if green_count >= 5:
			green_money *= 2
		if red_count >= 5:
			red_additive *= 2
		if purple_count >= 5:
			purple_multiplier *= 2
	
	var effects = {
		"green_money": green_money,
		"red_additive": red_additive,
		"purple_multiplier": purple_multiplier,
		"same_color_bonus": same_color_bonus,
		"green_count": green_count,
		"red_count": red_count, 
		"purple_count": purple_count
	}
	
	# Only print summary if there are actual effects
	if green_count > 0 or red_count > 0 or purple_count > 0:
		print("[DiceColorManager] Effects: Green(", green_count, "):$", green_money, " Red(", red_count, "):+", red_additive, " Purple(", purple_count, "):x", purple_multiplier)
		if same_color_bonus:
			print("[DiceColorManager] Same color bonus applied!")
	
	emit_signal("color_effects_calculated", green_money, red_additive, purple_multiplier, same_color_bonus)
	return effects

## Enable or disable the dice color system globally
## @param enabled: bool whether to enable dice colors
func set_colors_enabled(enabled: bool) -> void:
	if colors_enabled != enabled:
		colors_enabled = enabled
		emit_signal("colors_enabled_changed", enabled)
		print("[DiceColorManager] Dice colors ", "enabled" if enabled else "disabled")

## Get whether colors are currently enabled
## @return bool true if colors are enabled
func are_colors_enabled() -> bool:
	return colors_enabled

## Get empty effects structure for when colors are disabled
## @return Dictionary with zero values for all effects
func _get_empty_effects() -> Dictionary:
	return {
		"green_money": 0,
		"red_additive": 0,
		"purple_multiplier": 1.0,
		"same_color_bonus": false,
		"green_count": 0,
		"red_count": 0,
		"purple_count": 0
	}

## Apply dice color effects to score calculation
## @param base_score: int base score before color effects
## @param dice_array: Array[Dice] dice that were scored
## @return Dictionary with final_score and money_bonus
func apply_color_effects_to_score(base_score: int, dice_array: Array) -> Dictionary:
	var effects = calculate_color_effects(dice_array)
	
	# Calculate final score: (base + red_additive) * purple_multiplier
	var final_score = (base_score + effects.red_additive) * effects.purple_multiplier
	
	return {
		"final_score": int(final_score),
		"money_bonus": effects.green_money,
		"effects": effects
	}

## Debug function to force all dice to specific color
## @param dice_array: Array[Dice] dice to color
## @param color_type: DiceColorClass.Type color to apply
func debug_force_all_colors(dice_array: Array, color_type: DiceColorClass.Type) -> void:
	for dice in dice_array:
		if dice is Dice:
			dice.force_color(color_type)
	print("[DiceColorManager] DEBUG: Set all dice to ", DiceColorClass.get_color_name(color_type))

## Debug function to clear all dice colors
## @param dice_array: Array[Dice] dice to clear
func debug_clear_all_colors(dice_array: Array) -> void:
	for dice in dice_array:
		if dice is Dice:
			dice.clear_color()
	print("[DiceColorManager] DEBUG: Cleared all dice colors")

## Get current dice color effects description similar to RandomizerPowerUp
## @param dice_array: Array[Dice] dice to analyze for description
## @return String description of current color effects
func get_current_effects_description(dice_array: Array) -> String:
	if not colors_enabled:
		return "Dice Colors: Disabled"
	
	var effects = calculate_color_effects(dice_array)
	var descriptions := []
	
	# Add green money effect
	if effects.green_money > 0:
		descriptions.append("Green Dice Money: +$%d" % effects.green_money)
	
	# Add red additive effect  
	if effects.red_additive > 0:
		descriptions.append("Red Dice Bonus: +%d" % effects.red_additive)
	elif effects.red_additive < 0:
		descriptions.append("Red Dice Penalty: %d" % effects.red_additive)
	
	# Add purple multiplier effect
	if effects.purple_multiplier > 1.0:
		descriptions.append("Purple Dice Multiplier: ×%.1f" % effects.purple_multiplier)
	elif effects.purple_multiplier < 1.0 and effects.purple_multiplier > 0.0:
		descriptions.append("Purple Dice Multiplier: ×%.1f" % effects.purple_multiplier)
	elif effects.purple_multiplier <= 0.0:
		descriptions.append("Purple Dice Multiplier: ×%.1f" % effects.purple_multiplier)
	
	# Add same color bonus info
	if effects.same_color_bonus:
		descriptions.append("Same Color Bonus: 2x (5+ dice)")
	
	# Return combined description
	if descriptions.size() == 0:
		return "Dice Colors: No Effects"
	else:
		return "Color Effects: " + " | ".join(descriptions)