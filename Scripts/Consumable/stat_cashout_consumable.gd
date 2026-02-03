extends Consumable
class_name StatCashoutConsumable

## StatCashoutConsumable
##
## Grants money based on historical stats:
## - $10 per Yahtzee scored
## - $5 per Full House scored
## Reads from Statistics singleton (statistics_manager.gd).

const YAHTZEE_PAYOUT := 10
const FULL_HOUSE_PAYOUT := 5

func _ready() -> void:
	add_to_group("consumables")
	print("[StatCashoutConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[StatCashoutConsumable] Invalid target passed to apply()")
		return
	
	# Get Statistics singleton
	var statistics = get_node_or_null("/root/Statistics")
	if not statistics:
		push_error("[StatCashoutConsumable] Statistics autoload not found")
		return
	
	# Get PlayerEconomy for money
	var player_economy = get_node_or_null("/root/PlayerEconomy")
	if not player_economy:
		push_error("[StatCashoutConsumable] PlayerEconomy autoload not found")
		return
	
	# Calculate payout from stats
	var yahtzee_count: int = statistics.yahtzee_count
	var full_house_count: int = statistics.full_house_scored
	
	var yahtzee_payout := yahtzee_count * YAHTZEE_PAYOUT
	var full_house_payout := full_house_count * FULL_HOUSE_PAYOUT
	var total_payout := yahtzee_payout + full_house_payout
	
	print("[StatCashoutConsumable] Stats: %d yahtzees ($%d), %d full houses ($%d)" % [yahtzee_count, yahtzee_payout, full_house_count, full_house_payout])
	
	if total_payout > 0:
		player_economy.add_money(total_payout)
		print("[StatCashoutConsumable] Granted $%d total" % total_payout)
	else:
		print("[StatCashoutConsumable] No qualifying stats, granted $0")
