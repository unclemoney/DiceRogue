extends Consumable
class_name AntidoteConsumable

## AntidoteConsumable
##
## Cleanses the highest-intensity active debuff via
## GameController.disable_debuff(id). No-ops with a message when no debuffs
## are active. Usability gate lives in ConsumableUI/CorkboardUI
## `_can_use_consumable`, keyed on "antidote".
##
## Mom-granted buffs (rebellion, teacher_pet) ride the debuff pipeline but are
## rewards, so Antidote never targets them.


func _ready() -> void:
	add_to_group("consumables")


## apply(target)
##
## Finds the highest-intensity active debuff and disables it.
## @param target: GameController (duck-typed: needs active_debuffs and
##   disable_debuff(id))
func apply(target) -> void:
	var game_controller = target
	if not game_controller or not ("active_debuffs" in game_controller):
		push_error("[AntidoteConsumable] Invalid target passed to apply()")
		return
	if not game_controller.has_method("disable_debuff"):
		push_error("[AntidoteConsumable] Target has no disable_debuff method")
		return

	var best_id := ""
	var best_intensity := 0.0
	for debuff_id in game_controller.active_debuffs.keys():
		if debuff_id in DebuffManager.GRANTED_ONLY_IDS:
			continue
		var debuff = game_controller.active_debuffs[debuff_id]
		if not is_instance_valid(debuff) or not debuff.is_active:
			continue
		if best_id == "" or debuff.intensity > best_intensity:
			best_id = debuff_id
			best_intensity = debuff.intensity

	if best_id == "":
		print("[AntidoteConsumable] No active debuffs to cleanse - Antidote fizzles")
		return

	print("[AntidoteConsumable] Cleansing '%s' (intensity %.2f)" % [best_id, best_intensity])
	game_controller.disable_debuff(best_id)
