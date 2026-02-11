extends Consumable
class_name LuckyUpgradeConsumable

## LuckyUpgradeConsumable
##
## Randomly selects an unscored scorecard category and upgrades it by 1 level.
## Cannot upgrade categories that have already been scored.
## If all categories are scored, the consumable has no effect.
## Price: $25

func _ready() -> void:
	add_to_group("consumables")
	print("[LuckyUpgradeConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[LuckyUpgradeConsumable] Invalid target passed to apply()")
		return

	var scorecard = game_controller.scorecard
	if not scorecard:
		push_error("[LuckyUpgradeConsumable] No scorecard found")
		return

	# Collect all unscored categories from both sections
	var available_categories: Array[Dictionary] = []

	for category in scorecard.upper_scores.keys():
		if scorecard.upper_scores[category] == null:
			available_categories.append({
				"section": Scorecard.Section.UPPER,
				"category": category
			})

	for category in scorecard.lower_scores.keys():
		if scorecard.lower_scores[category] == null:
			available_categories.append({
				"section": Scorecard.Section.LOWER,
				"category": category
			})

	if available_categories.is_empty():
		print("[LuckyUpgradeConsumable] No unscored categories available to upgrade")
		return

	# Randomly select one category
	var selected = available_categories[randi() % available_categories.size()]
	var section: Scorecard.Section = selected["section"]
	var category: String = selected["category"]

	# Upgrade the selected category
	scorecard.upgrade_category(section, category)
	var new_level = scorecard.get_category_level(section, category)
	print("[LuckyUpgradeConsumable] Upgraded '%s' to level %d!" % [category, new_level])
