extends Consumable
class_name DiceSurgeConsumable

## DiceSurgeConsumable
##
## Grants +2 extra dice for the next 3 turns.
## Works by setting temporary dice bonus in TurnTracker which DiceHand listens to.
## If no dice are rolled yet, triggers a proper roll via the game button.
## Otherwise, spawns and rolls only the new dice.

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
	
	# Check if dice have been rolled yet (dice_list is empty means no roll happened)
	var dice_exist = dice_hand.dice_list.size() > 0
	
	if not dice_exist:
		# No dice rolled yet - trigger a proper roll through the game button
		print("[DiceSurgeConsumable] No dice exist yet - triggering proper roll")
		# Update dice count first so spawn creates the right number
		var new_count = turn_tracker.get_total_dice_count()
		dice_hand.dice_count = new_count
		
		# Find the game button UI and trigger roll
		var game_button_ui = game_controller.get_node_or_null("GameButtonUI")
		if not game_button_ui:
			game_button_ui = game_controller.get_tree().get_first_node_in_group("game_button_ui")
		if game_button_ui and game_button_ui.has_method("trigger_roll"):
			game_button_ui.trigger_roll()
		else:
			# Fallback: manually spawn and roll
			print("[DiceSurgeConsumable] Fallback: manually spawning and rolling dice")
			await dice_hand.spawn_dice()
			await dice_hand.get_tree().create_timer(0.3).timeout
			dice_hand.roll_all()
	else:
		# Dice exist - add new dice and roll only them
		var old_dice_count = dice_hand.dice_list.size()
		var new_count = turn_tracker.get_total_dice_count()
		dice_hand.dice_count = new_count
		dice_hand.update_dice_count()
		
		print("[DiceSurgeConsumable] Granted +%d dice for %d turns (total dice: %d)" % [dice_to_add, BONUS_TURNS, new_count])
		
		# Roll only the newly added dice after a short delay to let them spawn
		# Verify dice were actually added before attempting to roll
		await dice_hand.get_tree().create_timer(0.5).timeout
		if dice_hand.dice_list.size() > old_dice_count:
			_roll_new_dice(dice_hand, old_dice_count)

## Rolls only the newly added dice (those after the old count)
func _roll_new_dice(dice_hand: DiceHand, start_index: int) -> void:
	var current_size = dice_hand.dice_list.size()
	# Validate bounds to prevent out-of-range errors
	if start_index >= current_size:
		print("[DiceSurgeConsumable] No new dice to roll (start_index %d >= size %d)" % [start_index, current_size])
		return
	
	print("[DiceSurgeConsumable] Rolling %d new dice (indices %d to %d)" % [current_size - start_index, start_index, current_size - 1])
	for i in range(start_index, current_size):
		if i < dice_hand.dice_list.size():  # Double-check bounds
			var die = dice_hand.dice_list[i]
			if die is Dice:
				die.roll()
				await dice_hand.get_tree().create_timer(0.1).timeout
	print("[DiceSurgeConsumable] New dice rolled")
