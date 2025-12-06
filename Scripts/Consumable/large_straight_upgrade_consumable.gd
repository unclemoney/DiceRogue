extends Consumable
class_name LargeStraightUpgradeConsumable

const TARGET_SECTION = Scorecard.Section.LOWER
const TARGET_CATEGORY = "large_straight"

func _ready() -> void:
	add_to_group("consumables")
	print("[LargeStraightUpgradeConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[LargeStraightUpgradeConsumable] Invalid target")
		return
	
	var scorecard = game_controller.scorecard
	if not scorecard:
		push_error("[LargeStraightUpgradeConsumable] No scorecard found")
		return
	
	scorecard.upgrade_category(TARGET_SECTION, TARGET_CATEGORY)
	print("[LargeStraightUpgradeConsumable] Upgraded %s to level %d" % [TARGET_CATEGORY, scorecard.get_category_level(TARGET_SECTION, TARGET_CATEGORY)])
