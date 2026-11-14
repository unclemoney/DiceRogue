extends Consumable
class_name LossLeaderConsumable

func _ready() -> void:
	add_to_group("consumables")
	print("[LossLeaderConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[LossLeaderConsumable] Invalid target passed to apply()")
		apply_succeeded = false
		return
	
	# Stack loss leader - each stack grants one free consumable purchase
	game_controller.loss_leader_stacks += 1
	game_controller._refresh_shop_prices()
	print("[LossLeaderConsumable] Loss Leader applied. Free consumable purchases: %d" % game_controller.loss_leader_stacks)
