extends Consumable
class_name YahtzeeUpgradeConsumable

const TARGET_SECTION = Scorecard.Section.LOWER
const TARGET_CATEGORY = "yahtzee"

func _ready() -> void:
	add_to_group("consumables")
	print("[YahtzeeUpgradeConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[YahtzeeUpgradeConsumable] Invalid target")
		return
	
	var scorecard = game_controller.scorecard
	if not scorecard:
		push_error("[YahtzeeUpgradeConsumable] No scorecard found")
		return
	
	scorecard.upgrade_category(TARGET_SECTION, TARGET_CATEGORY)
	print("[YahtzeeUpgradeConsumable] Upgraded %s to level %d" % [TARGET_CATEGORY, scorecard.get_category_level(TARGET_SECTION, TARGET_CATEGORY)])
