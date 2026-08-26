extends Debuff
class_name WindowShoppingDebuff

## WindowShoppingDebuff
##
## While active, all kiosk/shop item prices are marked up.
## The effect is read by ShopItem.refresh_price() via
## GameController.get_window_shopping_multiplier(), which checks
## window_shopping_stacks. This debuff only maintains the stack count
## and asks the shop to refresh so open shops show marked-up prices.


func apply(new_target) -> void:
	print("[WindowShoppingDebuff] Applied - shop prices marked up")
	self.target = new_target
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if not game_controller:
		push_error("[WindowShoppingDebuff] GameController not found")
		return
	game_controller.window_shopping_stacks += 1
	print("[WindowShoppingDebuff] window_shopping_stacks:", game_controller.window_shopping_stacks)
	_refresh_shop_prices()


func remove() -> void:
	print("[WindowShoppingDebuff] Removed - shop prices restored")
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller:
		game_controller.window_shopping_stacks = maxi(0, game_controller.window_shopping_stacks - 1)
		_refresh_shop_prices()


## _refresh_shop_prices()
##
## Best-effort refresh of an already-open shop so the markup shows
## immediately. Prices are recalculated on shop setup regardless.
func _refresh_shop_prices() -> void:
	var shop_ui = get_tree().get_root().find_child("ShopUI", true, false)
	if shop_ui and shop_ui.has_method("refresh_all_prices"):
		shop_ui.refresh_all_prices()
