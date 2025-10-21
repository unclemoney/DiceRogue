extends Consumable
class_name EmptyShelvesConsumable

## EmptyShelvesConsumable
## 
## When used, counts the number of empty powerup slots and applies a score multiplier
## equal to that number for the next score. Can only be used when dice are rolled
## and ready to be scored.

signal empty_shelves_applied(multiplier: int)

func _ready() -> void:
	add_to_group("consumables")
	print("[EmptyShelvesConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[EmptyShelvesConsumable] Invalid target passed to apply()")
		return
	
	# Count empty powerup slots
	var empty_slots = _count_empty_powerup_slots(game_controller)
	
	if empty_slots <= 0:
		print("[EmptyShelvesConsumable] No empty powerup slots - no multiplier applied")
		return
	
	# Get ScoreModifierManager to register a one-time multiplier
	var score_modifier_manager = get_node("/root/ScoreModifierManager")
	if not score_modifier_manager:
		# Fallback to group search
		score_modifier_manager = get_tree().get_first_node_in_group("score_modifier_manager")
		if not score_modifier_manager:
			push_error("[EmptyShelvesConsumable] ScoreModifierManager not found")
			return
	
	# Register the multiplier for this turn
	var multiplier_id = "empty_shelves_multiplier"
	score_modifier_manager.register_multiplier(multiplier_id, empty_slots)
	
	print("[EmptyShelvesConsumable] Applied %dx multiplier for next score (%d empty slots)" % [empty_slots, empty_slots])
	
	# Connect to the scorecard to remove the multiplier after first score
	if game_controller.scorecard:
		if not game_controller.scorecard.is_connected("score_auto_assigned", _on_score_assigned):
			game_controller.scorecard.score_auto_assigned.connect(_on_score_assigned)
	
	# Emit signal for feedback
	emit_signal("empty_shelves_applied", empty_slots)
	
	# Add logbook entry for tracking
	if has_node("/root/Statistics"):
		var stats = get_node("/root/Statistics")
		if stats.has_method("add_consumable_event"):
			stats.add_consumable_event("empty_shelves", {
				"empty_slots": empty_slots,
				"multiplier": empty_slots,
				"description": "Empty Shelves: %dx multiplier from %d empty slots" % [empty_slots, empty_slots]
			})

## _on_score_assigned(_section: int, _category: String, _score: int, _breakdown_info: Dictionary = {})
##
## Callback triggered when a score is assigned. Removes the one-time multiplier
## after it has been applied to ensure it only affects one score.
func _on_score_assigned(_section: int, _category: String, _score: int, _breakdown_info: Dictionary = {}) -> void:
	print("[EmptyShelvesConsumable] Score assigned - removing one-time multiplier")
	
	# Get ScoreModifierManager and remove our multiplier
	var score_modifier_manager = get_node("/root/ScoreModifierManager")
	if not score_modifier_manager:
		score_modifier_manager = get_tree().get_first_node_in_group("score_modifier_manager")
	
	if score_modifier_manager:
		var multiplier_id = "empty_shelves_multiplier"
		if score_modifier_manager.has_method("has_multiplier") and score_modifier_manager.has_multiplier(multiplier_id):
			score_modifier_manager.unregister_multiplier(multiplier_id)
			print("[EmptyShelvesConsumable] One-time multiplier removed")
		else:
			print("[EmptyShelvesConsumable] Multiplier already removed or not found")
	
	# Disconnect from further score events since this is a one-time effect
	var scorecard = get_tree().get_first_node_in_group("scorecard")
	if scorecard and scorecard.is_connected("score_auto_assigned", _on_score_assigned):
		scorecard.score_auto_assigned.disconnect(_on_score_assigned)
		print("[EmptyShelvesConsumable] Disconnected from scorecard signals")

## _count_empty_powerup_slots(game_controller: GameController) -> int
##
## Counts the number of empty powerup slots available.
func _count_empty_powerup_slots(game_controller: GameController) -> int:
	var powerup_ui = game_controller.powerup_ui
	if not powerup_ui:
		push_error("[EmptyShelvesConsumable] No PowerUpUI found")
		return 0
	
	var current_powerups = powerup_ui._power_up_data.size()
	var max_powerups = powerup_ui.max_power_ups
	var empty_slots = max_powerups - current_powerups
	
	print("[EmptyShelvesConsumable] PowerUp slots: %d/%d (empty: %d)" % [current_powerups, max_powerups, empty_slots])
	
	return max(0, empty_slots)  # Ensure we never return negative
