extends Consumable
class_name OneExtraDiceConsumable

## OneExtraDiceConsumable
##
## When used, adds +1 extra dice to the dice hand for the next turn only.
## The extra dice is automatically removed when any score is assigned (auto or manual).
## Similar to ExtraDicePowerUp but temporary and only lasts for 1 turn.

signal extra_dice_added
signal extra_dice_removed

var is_active: bool = false
var game_controller_ref: GameController = null
var dice_hand_ref: DiceHand = null
var scorecard_ref: Scorecard = null

func _ready() -> void:
	add_to_group("consumables")
	print("[OneExtraDiceConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[OneExtraDiceConsumable] Invalid target passed to apply()")
		return
	
	if is_active:
		print("[OneExtraDiceConsumable] Already active - ignoring duplicate application")
		return
	
	# Store references
	game_controller_ref = game_controller
	dice_hand_ref = game_controller.dice_hand
	scorecard_ref = game_controller.scorecard
	
	if not dice_hand_ref:
		push_error("[OneExtraDiceConsumable] No dice hand found")
		return
	
	if not scorecard_ref:
		push_error("[OneExtraDiceConsumable] No scorecard found")
		return
	
	# Apply the extra dice effect (increase dice count from 5 to 6)
	var original_count = dice_hand_ref.dice_count
	dice_hand_ref.dice_count = original_count + 1
	print("[OneExtraDiceConsumable] Increased dice count from %d to %d" % [original_count, dice_hand_ref.dice_count])
	
	# Connect to scoring signals to remove the extra dice after scoring
	if not scorecard_ref.is_connected("score_assigned", _on_score_assigned):
		scorecard_ref.score_assigned.connect(_on_score_assigned)
		print("[OneExtraDiceConsumable] Connected to score_assigned signal")
	
	if not scorecard_ref.is_connected("score_auto_assigned", _on_score_auto_assigned):
		scorecard_ref.score_auto_assigned.connect(_on_score_auto_assigned)
		print("[OneExtraDiceConsumable] Connected to score_auto_assigned signal")
	
	is_active = true
	emit_signal("extra_dice_added")
	
	print("[OneExtraDiceConsumable] Applied successfully - extra dice will be removed after next score")

## _on_score_assigned(_section, _category, _score)
##
## Called when a manual score is assigned. Removes the extra dice effect.
func _on_score_assigned(_section: int, _category: String, _score: int) -> void:
	print("[OneExtraDiceConsumable] Manual score assigned - removing extra dice effect")
	_remove_extra_dice()

## _on_score_auto_assigned(_section, _category, _score, _breakdown_info)
##
## Called when an auto score is assigned. Removes the extra dice effect.
func _on_score_auto_assigned(_section: int, _category: String, _score: int, _breakdown_info: Dictionary = {}) -> void:
	print("[OneExtraDiceConsumable] Auto score assigned - removing extra dice effect")
	_remove_extra_dice()

## _remove_extra_dice()
##
## Removes the extra dice effect and cleans up signal connections.
func _remove_extra_dice() -> void:
	if not is_active:
		print("[OneExtraDiceConsumable] Not active - nothing to remove")
		return
	
	if dice_hand_ref:
		# Remove the extra dice (decrease dice count from 6 to 5)
		var current_count = dice_hand_ref.dice_count
		dice_hand_ref.dice_count = current_count - 1
		print("[OneExtraDiceConsumable] Reduced dice count from %d to %d" % [current_count, dice_hand_ref.dice_count])
	
	# Disconnect from signals
	if scorecard_ref:
		if scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			scorecard_ref.score_assigned.disconnect(_on_score_assigned)
			print("[OneExtraDiceConsumable] Disconnected from score_assigned signal")
		
		if scorecard_ref.is_connected("score_auto_assigned", _on_score_auto_assigned):
			scorecard_ref.score_auto_assigned.disconnect(_on_score_auto_assigned)
			print("[OneExtraDiceConsumable] Disconnected from score_auto_assigned signal")
	
	is_active = false
	emit_signal("extra_dice_removed")
	
	# Clear references
	game_controller_ref = null
	dice_hand_ref = null
	scorecard_ref = null
	
	print("[OneExtraDiceConsumable] Extra dice effect removed and cleaned up")