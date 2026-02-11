extends RefCounted
class_name DiceColor

## Dice color system enumeration and utility functions
## This class defines the different colors dice can have and their properties

enum Type {
	NONE,
	GREEN,
	RED,
	PURPLE,
	BLUE,
	YELLOW
}

## Color chance probabilities (1 in X chance)
const COLOR_CHANCES = {
	Type.GREEN: 25,   # 1 in 25 chance
	Type.RED: 50,     # 1 in 50 chance  
	Type.PURPLE: 88,  # 1 in 88 chance
	Type.BLUE: 100,   # 1 in 100 chance (very rare)
	Type.YELLOW: 60   # 1 in 60 chance (grants consumable when scored)
}

## Color names for display
const COLOR_NAMES = {
	Type.NONE: "None",
	Type.GREEN: "Green",
	Type.RED: "Red", 
	Type.PURPLE: "Purple",
	Type.BLUE: "Blue",
	Type.YELLOW: "Yellow"
}

## Get readable name for a color type
## @param color_type: DiceColor.Type to get name for
## @return String name of the color
static func get_color_name(color_type: Type) -> String:
	return COLOR_NAMES.get(color_type, "Unknown")

## Get the chance denominator for a color (1 in X)
## @param color_type: DiceColor.Type to get chance for
## @return int chance denominator, or 0 if color doesn't have random assignment
static func get_color_chance(color_type: Type) -> int:
	return COLOR_CHANCES.get(color_type, 0)

## Check if a color type is valid (not NONE)
## @param color_type: DiceColor.Type to validate
## @return bool true if color is valid and not NONE
static func is_colored(color_type: Type) -> bool:
	return color_type != Type.NONE

## Get all available color types (excluding NONE)
## @return Array[Type] of all available colors
static func get_all_colors() -> Array[Type]:
	return [Type.GREEN, Type.RED, Type.PURPLE, Type.BLUE, Type.YELLOW]

## Convert color type to Color for UI display
## @param color_type: DiceColor.Type to convert
## @return Color for UI representation
static func get_display_color(color_type: Type) -> Color:
	match color_type:
		Type.GREEN:
			return Color.GREEN
		Type.RED:
			return Color.RED
		Type.PURPLE:
			return Color.PURPLE
		Type.BLUE:
			return Color.BLUE
		Type.YELLOW:
			return Color.YELLOW
		_:
			return Color.WHITE