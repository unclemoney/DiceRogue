extends Consumable
class_name SixesUpgradeConsumable

const TARGET_SECTION = Scorecard.Section.UPPER
const TARGET_CATEGORY = "sixes"

func _ready() -> void:
	add_to_group("consumables")
	print("[SixesUpgradeConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[SixesUpgradeConsumable] Invalid target")
		return
	
	var scorecard = game_controller.scorecard
	if not scorecard:
		push_error("[SixesUpgradeConsumable] No scorecard found")
		return
	
	scorecard.upgrade_category(TARGET_SECTION, TARGET_CATEGORY)
	print("[SixesUpgradeConsumable] Upgraded %s to level %d" % [TARGET_CATEGORY, scorecard.get_category_level(TARGET_SECTION, TARGET_CATEGORY)])
