extends Consumable
class_name ThreesUpgradeConsumable

const TARGET_SECTION = Scorecard.Section.UPPER
const TARGET_CATEGORY = "threes"

func _ready() -> void:
	add_to_group("consumables")
	print("[ThreesUpgradeConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[ThreesUpgradeConsumable] Invalid target")
		return
	
	var scorecard = game_controller.scorecard
	if not scorecard:
		push_error("[ThreesUpgradeConsumable] No scorecard found")
		return
	
	scorecard.upgrade_category(TARGET_SECTION, TARGET_CATEGORY)
	print("[ThreesUpgradeConsumable] Upgraded %s to level %d" % [TARGET_CATEGORY, scorecard.get_category_level(TARGET_SECTION, TARGET_CATEGORY)])
