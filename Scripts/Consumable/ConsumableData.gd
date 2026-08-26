extends Resource
class_name ConsumableData

@export var id: String
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var scene: PackedScene
@export var price: int = 100
## Dice side count required for this consumable to appear in the shop
## (0 = any dice set). Used for d4-only consumables like Evens/Odds upgrades.
@export var required_dice_sides: int = 0
## Dice side counts on which this consumable must NOT appear in the shop
## (e.g. Fives/Sixes/Large Straight upgrades are excluded on d4 runs, where
## those scorecard categories are re-purposed).
@export var excluded_dice_sides: Array[int] = []

## is_available_for_dice_sides(sides: int) -> bool
##
## Returns true if this consumable may appear in the shop for a run using
## dice with the given side count. A required_dice_sides of 0 means any set;
## excluded_dice_sides lists sets that must not offer it.
func is_available_for_dice_sides(sides: int) -> bool:
	if required_dice_sides != 0 and required_dice_sides != sides:
		return false
	return not excluded_dice_sides.has(sides)