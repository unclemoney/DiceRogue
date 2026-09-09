extends Consumable
class_name ImmunityConsumable

## ImmunityConsumable
##
## Grants immunity for the next round: no automatic debuffs are assigned.
## Sets the `immunity_next_round` flag on DebuffManager; the flag is consumed
## at round-start debuff assignment (see GameController._apply_automatic_debuffs
## wiring hook).


func _ready() -> void:
	add_to_group("consumables")


## apply(target)
##
## Sets the next-round immunity flag on the DebuffManager.
## @param target: GameController (duck-typed: needs a debuff_manager property)
func apply(target) -> void:
	var game_controller = target
	if not game_controller:
		push_error("[ImmunityConsumable] Invalid target passed to apply()")
		return

	var debuff_manager = game_controller.get("debuff_manager")
	if not debuff_manager or not debuff_manager.has_method("grant_immunity_next_round"):
		push_error("[ImmunityConsumable] No DebuffManager with immunity support found")
		return

	debuff_manager.grant_immunity_next_round()
	print("[ImmunityConsumable] Immunity granted - no debuffs next round")
