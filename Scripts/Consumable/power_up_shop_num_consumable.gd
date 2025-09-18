extends Consumable
class_name PowerUpShopNumConsumable

signal shop_size_increased(additional_items: int)

func _ready() -> void:
	add_to_group("consumables")
	print("[PowerUpShopNumConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[PowerUpShopNumConsumable] Invalid target passed to apply()")
		return
		
	var shop_ui = game_controller.shop_ui
	if not shop_ui:
		push_error("[PowerUpShopNumConsumable] No ShopUI found")
		return
		
	# Increase the number of power-ups displayed in shop by 1
	shop_ui.increase_power_up_items(1)
	print("[PowerUpShopNumConsumable] Increased shop power-up items by 1")
	
	# Emit signal for feedback
	emit_signal("shop_size_increased", 1)