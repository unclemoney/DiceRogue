extends Resource
class_name ColoredDiceData

## ColoredDiceData Resource
##
## Represents a purchasable colored dice type in the shop.
## Each colored dice type has specific properties and effects.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var price: int = 50
@export var color_type: DiceColor.Type = DiceColor.Type.NONE
@export var icon: Texture2D
@export var effect_description: String = ""
@export var rarity_description: String = ""

## Get formatted price string for display
## @return String formatted price with $ symbol
func get_formatted_price() -> String:
	return "$%d" % price

## Get color name for display
## @return String name of the dice color
func get_color_name() -> String:
	return DiceColor.get_color_name(color_type)

## Get full description including effects and rarity
## @return String complete description for tooltip
func get_full_description() -> String:
	var desc_parts = [description]
	
	if effect_description != "":
		desc_parts.append("Effect: " + effect_description)
	
	if rarity_description != "":
		desc_parts.append("Rarity: " + rarity_description)
	
	return "\n\n".join(desc_parts)

## Check if this colored dice type is valid
## @return bool true if color type is not NONE
func is_valid() -> bool:
	return color_type != DiceColor.Type.NONE and id != ""