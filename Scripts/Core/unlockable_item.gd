extends Resource
class_name UnlockableItem

## UnlockableItem Resource
##
## Represents an item (PowerUp, Consumable, or Colored Dice) that can be unlocked
## through gameplay progression. Contains the item information and unlock requirements.

enum ItemType {
	POWER_UP,
	CONSUMABLE,
	MOD,
	COLORED_DICE_FEATURE
}

@export var id: String = ""
@export var item_type: ItemType = ItemType.POWER_UP
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var unlock_condition: Resource  # UnlockCondition resource
@export var is_unlocked: bool = false
@export var unlock_timestamp: int = 0  # Unix timestamp when unlocked
@export var difficulty_rating: int = 1  # 1-10 scale: 1-3 common, 4-6 uncommon, 7-9 rare, 10 legendary

## Check if this item should be unlocked based on game statistics
## @param game_stats: Dictionary containing current game statistics
## @param progress_data: Dictionary containing cumulative progress data
## @return bool: True if item should be unlocked
func check_unlock(game_stats: Dictionary, progress_data: Dictionary) -> bool:
	if is_unlocked:
		return false
		
	if not unlock_condition or not unlock_condition.has_method("is_satisfied"):
		push_error("[UnlockableItem] No unlock condition set for item: %s" % id)
		return false
		
	return unlock_condition.is_satisfied(game_stats, progress_data)

## Unlock this item and set the timestamp
func unlock_item() -> void:
	if is_unlocked:
		print("[UnlockableItem] Item %s is already unlocked" % id)
		return
		
	is_unlocked = true
	unlock_timestamp = int(Time.get_unix_time_from_system())
	print("[UnlockableItem] Unlocked item: %s" % display_name)

## Get formatted unlock requirement description
## @return String: Human-readable unlock requirement
func get_unlock_description() -> String:
	if not unlock_condition or not unlock_condition.has_method("get_formatted_description"):
		return "No unlock condition set"
	return unlock_condition.get_formatted_description()

## Get item type as string
## @return String: Item type name
func get_type_string() -> String:
	match item_type:
		ItemType.POWER_UP:
			return "PowerUp"
		ItemType.CONSUMABLE:
			return "Consumable"
		ItemType.MOD:
			return "Mod"
		ItemType.COLORED_DICE_FEATURE:
			return "Colored Dice"
		_:
			return "Unknown"