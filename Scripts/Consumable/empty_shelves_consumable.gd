extends Consumable
class_name EmptyShelvesConsumable

## EmptyShelvesConsumable
## 
## When used, counts the number of empty powerup slots and applies a score multiplier
## equal to that number for the next score. Can only be used when dice are rolled
## and ready to be scored.

signal empty_shelves_applied(multiplier: int)

const MULTIPLIER_ID := "empty_shelves_multiplier"

var _scorecard_ref: Scorecard = null

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
	var score_modifier_manager = ScoreModifierManager
	if not score_modifier_manager:
		# Fallback to group search
		score_modifier_manager = get_tree().get_first_node_in_group("score_modifier_manager")
		if not score_modifier_manager:
			push_error("[EmptyShelvesConsumable] ScoreModifierManager not found")
			return
	
	_disarm()
	score_modifier_manager.register_multiplier(MULTIPLIER_ID, empty_slots)
	
	print("[EmptyShelvesConsumable] Applied %dx multiplier for next score (%d empty slots)" % [empty_slots, empty_slots])
	
	# Both manual and automatic scoring emit this before round completion.
	if game_controller.scorecard:
		_scorecard_ref = game_controller.scorecard
		if not _scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			_scorecard_ref.score_assigned.connect(_on_score_assigned)
	
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

## _on_score_assigned(_section: int, _category: String, _score: int)
##
## Removes the one-time multiplier immediately after any score is assigned.
func _on_score_assigned(_section: int, _category: String, _score: int) -> void:
	print("[EmptyShelvesConsumable] Score assigned - removing one-time multiplier")
	_disarm()


func _disarm() -> void:
	var score_modifier_manager = ScoreModifierManager
	if not score_modifier_manager:
		score_modifier_manager = get_tree().get_first_node_in_group("score_modifier_manager")
	
	if score_modifier_manager and score_modifier_manager.has_multiplier(MULTIPLIER_ID):
		score_modifier_manager.unregister_multiplier(MULTIPLIER_ID)
	
	if is_instance_valid(_scorecard_ref):
		if _scorecard_ref.is_connected("score_assigned", _on_score_assigned):
			_scorecard_ref.score_assigned.disconnect(_on_score_assigned)
	_scorecard_ref = null


func _exit_tree() -> void:
	_disarm()

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
