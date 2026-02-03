extends Consumable
class_name VisitTheShopConsumable

## VisitTheShopConsumable
##
## Allows the player to visit the shop once during active play.
## Opens shop without triggering end of round.

func _ready() -> void:
	add_to_group("consumables")
	print("[VisitTheShopConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[VisitTheShopConsumable] Invalid target passed to apply()")
		return
	
	print("[VisitTheShopConsumable] Opening shop mid-round")
	
	# Fold back the CorkboardUI fan first (primary UI)
	if game_controller.corkboard_ui and game_controller.corkboard_ui.has_method("fold_back"):
		game_controller.corkboard_ui.fold_back()
		print("[VisitTheShopConsumable] Folded back CorkboardUI")
	
	# Also fold back ConsumableUI if available (fallback)
	if game_controller.consumable_ui and game_controller.consumable_ui.has_method("fold_back"):
		game_controller.consumable_ui.fold_back()
		print("[VisitTheShopConsumable] Folded back ConsumableUI")
	
	# Call the internal shop opening method directly
	# This bypasses the normal round completion flow
	if game_controller.shop_ui:
		game_controller._open_shop_ui()
		print("[VisitTheShopConsumable] Shop opened successfully")
	else:
		push_error("[VisitTheShopConsumable] No shop_ui found in game_controller")
