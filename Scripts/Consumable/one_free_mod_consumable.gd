extends Consumable
class_name OneFreeModConsumable

## OneFreeModConsumable
##
## Grants the player one random dice mod for free.
## Can only be used if the player has an available dice slot for a mod
## (current mod count < expected dice count).

func _ready() -> void:
	add_to_group("consumables")
	print("[OneFreeModConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[OneFreeModConsumable] Invalid target passed to apply()")
		return
	
	# Verify mod manager exists
	if not game_controller.mod_manager:
		push_error("[OneFreeModConsumable] ModManager not found")
		return
	
	# Double-check mod limit (should be validated by _can_use_consumable, but be safe)
	var current_mod_count = game_controller._get_total_active_mod_count()
	var expected_dice_count = game_controller._get_expected_dice_count()
	
	if current_mod_count >= expected_dice_count:
		push_error("[OneFreeModConsumable] Cannot grant mod - mod limit reached (%d/%d)" % [current_mod_count, expected_dice_count])
		return
	
	# Get random mod ID and grant it
	var random_mod_id = game_controller.mod_manager.get_random_mod_id()
	if not random_mod_id:
		push_error("[OneFreeModConsumable] No mods available to grant")
		return
	
	game_controller.grant_mod(random_mod_id)
	print("[OneFreeModConsumable] Granted free mod: %s (mods: %d/%d)" % [random_mod_id, current_mod_count + 1, expected_dice_count])
