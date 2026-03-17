extends Consumable
class_name HalfPriceConsumable

func _ready() -> void:
	add_to_group("consumables")
	print("[HalfPriceConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[HalfPriceConsumable] Invalid target passed to apply()")
		return
	
	# Stack half price - each stack halves PowerUp prices multiplicatively
	game_controller.half_price_stacks += 1
	print("[HalfPriceConsumable] Half Price applied. Stacks: %d, Multiplier: %.2f" % [game_controller.half_price_stacks, game_controller.get_half_price_multiplier()])
