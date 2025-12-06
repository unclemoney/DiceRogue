extends Consumable
class_name AllCategoriesUpgradeConsumable

func _ready() -> void:
	add_to_group("consumables")
	print("[AllCategoriesUpgradeConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[AllCategoriesUpgradeConsumable] Invalid target")
		return
	
	var scorecard = game_controller.scorecard
	if not scorecard:
		push_error("[AllCategoriesUpgradeConsumable] No scorecard found")
		return
	
	# Upgrade all upper section categories
	for category in scorecard.upper_scores.keys():
		scorecard.upgrade_category(Scorecard.Section.UPPER, category)
	
	# Upgrade all lower section categories
	for category in scorecard.lower_scores.keys():
		scorecard.upgrade_category(Scorecard.Section.LOWER, category)
	
	print("[AllCategoriesUpgradeConsumable] Upgraded all 13 categories by 1 level")
