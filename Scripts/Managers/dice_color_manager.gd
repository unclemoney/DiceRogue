extends Node

## DiceColorManager - Autoload for managing dice color system
## Handles global color settings, effect calculations, and integration with scoring

# Import DiceColor class to avoid shadowing warning
const DiceColorClass = preload("res://Scripts/Core/dice_color.gd")
const ColoredDiceDataClass = preload("res://Scripts/Core/colored_dice_data.gd")

signal colors_enabled_changed(enabled: bool)
signal color_effects_calculated(green_money: int, red_additive: int, purple_multiplier: float, same_color_bonus: bool)

var colors_enabled: bool = true

# Purchased colored dice tracking (only for current game session)
var purchased_colors: Dictionary = {}  # DiceColor.Type -> bool
var colored_dice_data: Dictionary = {}  # color_id -> ColoredDiceData

# Color probability modifiers (multipliers applied to base chance denominators)
var color_chance_modifiers: Dictionary = {}  # DiceColor.Type -> float

func _ready() -> void:
	add_to_group("dice_color_manager")
	_load_colored_dice_data()
	_reset_purchased_colors()
	print("[DiceColorManager] Initialized and added to dice_color_manager group")

## Calculate dice color effects for scoring
## @param dice_array: Array[Dice] dice to analyze for color effects
## @param used_dice_array: Array[Dice] dice that are actually used in the scoring category (optional)
## @return Dictionary with money, additive, multiplier, and bonus information
func calculate_color_effects(dice_array: Array, used_dice_array: Array = []) -> Dictionary:
	if not colors_enabled:
		return _get_empty_effects()
	
	var green_count := 0
	var red_count := 0
	var purple_count := 0
	var blue_count := 0
	var green_money := 0
	var red_additive := 0
	var purple_multiplier := 1.0
	var blue_score_multiplier := 1.0
	
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
			DiceColorClass.Type.BLUE:
				blue_count += 1
				# Blue dice effect depends on whether it's used in scoring
				var is_used = used_dice_array.size() == 0 or i in used_dice_array
				if is_used:
					# Used: multiply score
					blue_score_multiplier *= dice_value
				else:
					# Not used: divide score (implemented as fractional multiplier)
					if dice_value > 0:
						blue_score_multiplier *= (1.0 / dice_value)
			DiceColorClass.Type.NONE:
				pass  # No effect
	
	# Check for same color bonus (5+ of any color gets 2x)
	var same_color_bonus := false
	if green_count >= 5 or red_count >= 5 or purple_count >= 5 or blue_count >= 5:
		same_color_bonus = true
		
		# Only apply bonus to the colors that actually exist
		if green_count >= 5:
			green_money *= 2
		if red_count >= 5:
			red_additive *= 2
		if purple_count >= 5:
			purple_multiplier *= 2
		if blue_count >= 5:
			blue_score_multiplier *= 2
	
	var effects = {
		"green_money": green_money,
		"red_additive": red_additive,
		"purple_multiplier": purple_multiplier,
		"blue_score_multiplier": blue_score_multiplier,
		"same_color_bonus": same_color_bonus,
		"green_count": green_count,
		"red_count": red_count, 
		"purple_count": purple_count,
		"blue_count": blue_count
	}
	
	# Only print summary if there are actual effects
	if green_count > 0 or red_count > 0 or purple_count > 0 or blue_count > 0:
		print("[DiceColorManager] Effects: Green(", green_count, "):$", green_money, " Red(", red_count, "):+", red_additive, " Purple(", purple_count, "):x", purple_multiplier, " Blue(", blue_count, "):x", blue_score_multiplier)
		if same_color_bonus:
			print("[DiceColorManager] Same color bonus applied!")
	
	# Register effects with ScoreModifierManager for proper tracking
	_register_color_effects_with_manager(effects)
	
	emit_signal("color_effects_calculated", green_money, red_additive, purple_multiplier, same_color_bonus)
	return effects

## Register dice color effects with ScoreModifierManager for proper tracking
## @param effects: Dictionary with calculated color effects
func _register_color_effects_with_manager(effects: Dictionary) -> void:
	if not ScoreModifierManager:
		return
	
	# Clear any existing dice color effects
	_unregister_color_effects_from_manager()
	
	# Register red dice additive effects
	var red_additive = effects.get("red_additive", 0)
	if red_additive > 0:
		ScoreModifierManager.register_additive("red_dice", red_additive)
		print("[DiceColorManager] Registered red dice additive: +", red_additive)
	
	# Register purple dice multiplier effects
	var purple_multiplier = effects.get("purple_multiplier", 1.0)
	if purple_multiplier != 1.0:
		ScoreModifierManager.register_multiplier("purple_dice", purple_multiplier)
		print("[DiceColorManager] Registered purple dice multiplier: ×", purple_multiplier)
	
	# Register blue dice multiplier effects
	var blue_multiplier = effects.get("blue_score_multiplier", 1.0)
	if blue_multiplier != 1.0:
		ScoreModifierManager.register_multiplier("blue_dice", blue_multiplier)
		print("[DiceColorManager] Registered blue dice multiplier: ×", blue_multiplier)

## Unregister all dice color effects from ScoreModifierManager
func _unregister_color_effects_from_manager() -> void:
	if not ScoreModifierManager:
		return
	
	# Unregister all dice color effects
	ScoreModifierManager.unregister_additive("red_dice")
	ScoreModifierManager.unregister_multiplier("purple_dice")
	ScoreModifierManager.unregister_multiplier("blue_dice")

## Clear all dice color effects from ScoreModifierManager (called when round ends)
func clear_color_effects() -> void:
	_unregister_color_effects_from_manager()
	print("[DiceColorManager] Cleared all dice color effects from ScoreModifierManager")

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
		"blue_score_multiplier": 1.0,
		"same_color_bonus": false,
		"green_count": 0,
		"red_count": 0,
		"purple_count": 0,
		"blue_count": 0
	}

## Apply dice color effects to score calculation
## @param base_score: int base score before color effects
## @param dice_array: Array[Dice] dice that were scored
## @param used_dice_array: Array[Dice] dice that are actually used in the scoring category (optional)
## @return Dictionary with final_score and money_bonus
func apply_color_effects_to_score(base_score: int, dice_array: Array, used_dice_array: Array = []) -> Dictionary:
	var effects = calculate_color_effects(dice_array, used_dice_array)
	
	# Calculate final score: ((base + red_additive) * purple_multiplier) * blue_score_multiplier
	var intermediate_score = (base_score + effects.red_additive) * effects.purple_multiplier
	var final_score = int(intermediate_score * effects.blue_score_multiplier)
	
	return {
		"final_score": final_score,
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
## @param used_dice_array: Array[Dice] dice that are actually used in the scoring category (optional)
## @return String description of current color effects
func get_current_effects_description(dice_array: Array, used_dice_array: Array = []) -> String:
	if not colors_enabled:
		return "Dice Colors: Disabled"
	
	var effects = calculate_color_effects(dice_array, used_dice_array)
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
	
	# Add blue dice effect
	if effects.blue_score_multiplier != 1.0:
		if effects.blue_score_multiplier > 1.0:
			descriptions.append("Blue Dice Multiplier: ×%.1f" % effects.blue_score_multiplier)
		else:
			descriptions.append("Blue Dice Divisor: ÷%.1f" % (1.0 / effects.blue_score_multiplier))
	
	# Add same color bonus info
	if effects.same_color_bonus:
		descriptions.append("Same Color Bonus: 2x (5+ dice)")
	
	# Return combined description
	if descriptions.size() == 0:
		return "Dice Colors: No Effects"
	else:
		return "Color Effects: " + " | ".join(descriptions)

## Debug function to force all dice to green (for testing money system)
func force_all_green() -> void:
	print("[DiceColorManager] Debug: Forcing all dice to green")
	var dice_hand = get_tree().get_first_node_in_group("dice_hand")
	if dice_hand and dice_hand.has_method("debug_force_all_colors"):
		dice_hand.debug_force_all_colors(DiceColorClass.Type.GREEN)
		print("[DiceColorManager] Successfully forced all dice to green")
	else:
		print("[DiceColorManager] Warning: Could not access dice_hand or debug method")

## Load colored dice data resources
func _load_colored_dice_data() -> void:
	print("[DiceColorManager] Loading colored dice data...")
	
	# Load all colored dice data files
	var data_files = [
		"res://Resources/Data/ColoredDice/GreenDice.tres",
		"res://Resources/Data/ColoredDice/RedDice.tres", 
		"res://Resources/Data/ColoredDice/PurpleDice.tres",
		"res://Resources/Data/ColoredDice/BlueDice.tres"
	]
	
	for file_path in data_files:
		var data = load(file_path)
		if data and data.has_method("is_valid") and data.is_valid():
			colored_dice_data[data.id] = data
			print("[DiceColorManager] Loaded colored dice data: %s" % data.display_name)
		else:
			push_error("[DiceColorManager] Failed to load colored dice data: %s" % file_path)
	
	print("[DiceColorManager] Loaded %d colored dice types" % colored_dice_data.size())

## Reset purchased colors for new game session
func _reset_purchased_colors() -> void:
	purchased_colors.clear()
	for color_type in [DiceColorClass.Type.GREEN, DiceColorClass.Type.RED, DiceColorClass.Type.PURPLE, DiceColorClass.Type.BLUE]:
		purchased_colors[color_type] = false
	print("[DiceColorManager] Reset purchased colors for new game session")

## Purchase a colored dice type for this game session
## @param color_id: String ID of the colored dice to purchase
## @return bool: True if purchase was successful
func purchase_colored_dice(color_id: String) -> bool:
	var data = colored_dice_data.get(color_id)
	if not data:
		push_error("[DiceColorManager] Invalid colored dice ID: %s" % color_id)
		return false
	
	# Check if already purchased
	if is_color_purchased(data.color_type):
		print("[DiceColorManager] %s already purchased" % data.display_name)
		return false
	
	# Mark as purchased for this session
	purchased_colors[data.color_type] = true
	print("[DiceColorManager] Purchased %s for this game session" % data.display_name)
	return true

## Check if a colored dice type has been purchased this session
## @param color_type: DiceColor.Type to check
## @return bool: True if purchased this session
func is_color_purchased(color_type: DiceColorClass.Type) -> bool:
	return purchased_colors.get(color_type, false)

## Get available colored dice data (for shop display)
## @return Array: Array of available colored dice data
func get_available_colored_dice() -> Array:
	var available = []
	for data in colored_dice_data.values():
		if data and data.has_method("is_valid"):
			available.append(data)
	return available

## Get colored dice data by ID
## @param color_id: String ID of the colored dice
## @return Resource: The data resource, or null if not found
func get_colored_dice_data(color_id: String):
	return colored_dice_data.get(color_id)

## Get all purchased colored dice types for this session
## @return Array[DiceColor.Type]: Array of purchased color types
func get_purchased_color_types() -> Array:
	var purchased = []
	for color_type in purchased_colors.keys():
		if purchased_colors[color_type]:
			purchased.append(color_type)
	return purchased

## Clear all purchased colors (call when game ends)
func clear_purchased_colors() -> void:
	_reset_purchased_colors()
	print("[DiceColorManager] Cleared all purchased colors")

## Register a color chance modifier (PowerUp system)
## @param color_type: DiceColor.Type to modify
## @param modifier: float multiplier for the chance denominator (0.5 = half denominator = double chance)
func register_color_chance_modifier(color_type: DiceColorClass.Type, modifier: float) -> void:
	color_chance_modifiers[color_type] = modifier
	print("[DiceColorManager] Registered color chance modifier: %s chance ×%.2f" % [DiceColorClass.get_color_name(color_type), modifier])

## Unregister a color chance modifier
## @param color_type: DiceColor.Type to remove modifier from
func unregister_color_chance_modifier(color_type: DiceColorClass.Type) -> void:
	if color_chance_modifiers.has(color_type):
		color_chance_modifiers.erase(color_type)
		print("[DiceColorManager] Unregistered color chance modifier for: %s" % DiceColorClass.get_color_name(color_type))

## Get modified color chance for a specific color type
## Takes into account PowerUp modifiers that improve probability
## @param color_type: DiceColor.Type to get chance for
## @return int modified chance denominator (1 in X chance)
func get_modified_color_chance(color_type: DiceColorClass.Type) -> int:
	var base_chance = DiceColorClass.get_color_chance(color_type)
	if base_chance <= 0:
		return 0
	
	# Apply modifier if present
	if color_chance_modifiers.has(color_type):
		var modifier = color_chance_modifiers[color_type]
		var modified_chance = int(base_chance * modifier)
		return max(1, modified_chance)  # Ensure at least 1 in 1 chance
	
	return base_chance

## Clear all color chance modifiers (when PowerUps are removed)
func clear_all_color_chance_modifiers() -> void:
	color_chance_modifiers.clear()
	print("[DiceColorManager] Cleared all color chance modifiers")