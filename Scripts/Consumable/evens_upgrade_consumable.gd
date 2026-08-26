extends Consumable
class_name EvensUpgradeConsumable

const TARGET_SECTION = Scorecard.Section.UPPER
const TARGET_CATEGORY = "fives"

func _ready() -> void:
	add_to_group("consumables")
	print("[EvensUpgradeConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[EvensUpgradeConsumable] Invalid target")
		return
	
	var scorecard = game_controller.scorecard
	if not scorecard:
		push_error("[EvensUpgradeConsumable] No scorecard found")
		return
	
	scorecard.upgrade_category(TARGET_SECTION, TARGET_CATEGORY)
	print("[EvensUpgradeConsumable] Upgraded %s to level %d" % [TARGET_CATEGORY, scorecard.get_category_level(TARGET_SECTION, TARGET_CATEGORY)])
