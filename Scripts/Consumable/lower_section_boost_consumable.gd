extends Consumable
class_name LowerSectionBoostConsumable

## LowerSectionBoostConsumable
##
## Upgrades all 7 lower section categories by one level each.
## Categories: three_of_a_kind, four_of_a_kind, full_house, small_straight, large_straight, yahtzee, chance
## Uses batch update to minimize UI refreshes.

const LOWER_CATEGORIES := ["three_of_a_kind", "four_of_a_kind", "full_house", "small_straight", "large_straight", "yahtzee", "chance"]

func _ready() -> void:
	add_to_group("consumables")
	print("[LowerSectionBoostConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[LowerSectionBoostConsumable] Invalid target passed to apply()")
		return
	
	var scorecard = game_controller.scorecard
	if not scorecard:
		push_error("[LowerSectionBoostConsumable] No scorecard found")
		return
	
	print("[LowerSectionBoostConsumable] Upgrading all lower section categories...")
	
	# Batch upgrade all lower section categories
	var upgraded_count := 0
	for category in LOWER_CATEGORIES:
		scorecard.upgrade_category(Scorecard.Section.LOWER, category)
		upgraded_count += 1
	
	print("[LowerSectionBoostConsumable] Upgraded %d lower section categories" % upgraded_count)
