extends Consumable
class_name EvenOddFullHouseUpgradeConsumable

const TARGET_SECTION = Scorecard.Section.LOWER
const TARGET_CATEGORY = "large_straight"

func _ready() -> void:
	add_to_group("consumables")
	print("[EvenOddFullHouseUpgradeConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[EvenOddFullHouseUpgradeConsumable] Invalid target")
		return
	
	var scorecard = game_controller.scorecard
	if not scorecard:
		push_error("[EvenOddFullHouseUpgradeConsumable] No scorecard found")
		return
	
	scorecard.upgrade_category(TARGET_SECTION, TARGET_CATEGORY)
	print("[EvenOddFullHouseUpgradeConsumable] Upgraded %s to level %d" % [TARGET_CATEGORY, scorecard.get_category_level(TARGET_SECTION, TARGET_CATEGORY)])
