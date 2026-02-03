extends Consumable
class_name DiceSurgeConsumable

## DiceSurgeConsumable
##
## Grants +2 extra dice for the next 3 turns.
## Works by setting temporary dice bonus in TurnTracker which DiceHand listens to.
## The new dice are immediately spawned and rolled upon use.

const BONUS_DICE := 2
const BONUS_TURNS := 3
const MAX_DICE := 16

func _ready() -> void:
	add_to_group("consumables")
	print("[DiceSurgeConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[DiceSurgeConsumable] Invalid target passed to apply()")
		return
	
	var turn_tracker = game_controller.turn_tracker
	if not turn_tracker:
		push_error("[DiceSurgeConsumable] No TurnTracker found")
		return
	
	var dice_hand = game_controller.dice_hand
	if not dice_hand:
		push_error("[DiceSurgeConsumable] No DiceHand found")
		return
	
	# Check current dice count and calculate how many we can actually add
	var current_count = dice_hand.dice_count
	var space_available = MAX_DICE - current_count
	var dice_to_add = mini(BONUS_DICE, space_available)
	
	if dice_to_add <= 0:
		print("[DiceSurgeConsumable] Already at max dice (%d), cannot add more" % MAX_DICE)
		return
	
	# Set temporary dice bonus in TurnTracker
	turn_tracker.set_temporary_dice_bonus(dice_to_add, BONUS_TURNS)
	
	# Update DiceHand's dice_count property and spawn new dice
	var new_count = turn_tracker.get_total_dice_count()
	var old_dice_count = dice_hand.dice_list.size()
	dice_hand.dice_count = new_count
	dice_hand.update_dice_count()
	
	print("[DiceSurgeConsumable] Granted +%d dice for %d turns (total dice: %d)" % [dice_to_add, BONUS_TURNS, new_count])
	
	# Roll only the newly added dice after a short delay to let them spawn
	if dice_hand.dice_list.size() > old_dice_count:
		await dice_hand.get_tree().create_timer(0.5).timeout
		_roll_new_dice(dice_hand, old_dice_count)

## Rolls only the newly added dice (those after the old count)
func _roll_new_dice(dice_hand: DiceHand, start_index: int) -> void:
	print("[DiceSurgeConsumable] Rolling %d new dice" % (dice_hand.dice_list.size() - start_index))
	for i in range(start_index, dice_hand.dice_list.size()):
		var die = dice_hand.dice_list[i]
		if die is Dice:
			die.roll()
			await dice_hand.get_tree().create_timer(0.1).timeout
	print("[DiceSurgeConsumable] New dice rolled")
