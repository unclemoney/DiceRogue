extends Consumable
class_name BonusCollectorConsumable

## BonusCollectorConsumable
##
## Grants $35 instantly if the upper section total is >= 63 (bonus threshold).
## If not eligible, shows feedback message but does nothing.

const BONUS_AMOUNT := 35
const UPPER_BONUS_THRESHOLD := 63

func _ready() -> void:
	add_to_group("consumables")
	print("[BonusCollectorConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[BonusCollectorConsumable] Invalid target passed to apply()")
		return
	
	var scorecard = game_controller.scorecard
	if not scorecard:
		push_error("[BonusCollectorConsumable] No scorecard found")
		return
	
	# Get the upper section total
	var upper_total: int = scorecard.get_upper_section_total()
	
	print("[BonusCollectorConsumable] Upper section total: %d (threshold: %d)" % [upper_total, UPPER_BONUS_THRESHOLD])
	
	if upper_total >= UPPER_BONUS_THRESHOLD:
		# Eligible - grant the bonus
		var player_economy = get_node_or_null("/root/PlayerEconomy")
		if player_economy:
			player_economy.add_money(BONUS_AMOUNT)
			print("[BonusCollectorConsumable] Granted $%d bonus!" % BONUS_AMOUNT)
		else:
			push_error("[BonusCollectorConsumable] PlayerEconomy autoload not found")
	else:
		# Not eligible - show feedback
		print("[BonusCollectorConsumable] Upper section not eligible (current: %d/%d)" % [upper_total, UPPER_BONUS_THRESHOLD])
		# The consumable is still consumed but has no effect
