extends Consumable
class_name UpperSectionBoostConsumable

## UpperSectionBoostConsumable
##
## Upgrades all 6 upper section categories by one level each.
## Categories: ones, twos, threes, fours, fives, sixes
## Uses batch update to minimize UI refreshes.

const UPPER_CATEGORIES := ["ones", "twos", "threes", "fours", "fives", "sixes"]

func _ready() -> void:
	add_to_group("consumables")
	print("[UpperSectionBoostConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[UpperSectionBoostConsumable] Invalid target passed to apply()")
		return
	
	var scorecard = game_controller.scorecard
	if not scorecard:
		push_error("[UpperSectionBoostConsumable] No scorecard found")
		return
	
	print("[UpperSectionBoostConsumable] Upgrading all upper section categories...")
	
	# Batch upgrade all upper section categories
	var upgraded_count := 0
	for category in UPPER_CATEGORIES:
		scorecard.upgrade_category(Scorecard.Section.UPPER, category)
		upgraded_count += 1
	
	print("[UpperSectionBoostConsumable] Upgraded %d upper section categories" % upgraded_count)
