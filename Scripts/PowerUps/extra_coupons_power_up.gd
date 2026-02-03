extends PowerUp
class_name ExtraCouponsPowerUp

## ExtraCouponsPowerUp
## 
## Allows the player to hold 2 additional consumables (increases max from 3 to 5).
## When removed, triggers overflow handling if player has more than 3 consumables.
## Works with both ConsumableUI and CorkboardUI.

const EXTRA_SLOTS: int = 2
const DEFAULT_MAX: int = 3

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")
	print("[ExtraCouponsPowerUp] Ready")

func apply(target) -> void:
	print("=== Applying ExtraCouponsPowerUp ===")
	print("[ExtraCouponsPowerUp] Target type: %s" % target.get_class() if target else "null")
	
	# Target should be the GameController
	var game_controller = target
	if not game_controller:
		push_error("[ExtraCouponsPowerUp] No target provided")
		return
	
	# Update CorkboardUI if available (primary)
	if game_controller.has_node("../CorkboardUI"):
		var corkboard = game_controller.get_node("../CorkboardUI")
		if corkboard:
			corkboard.max_consumables = DEFAULT_MAX + EXTRA_SLOTS
			if corkboard.has_method("update_consumable_label"):
				corkboard.update_consumable_label()
			print("[ExtraCouponsPowerUp] Updated CorkboardUI max_consumables to %d" % corkboard.max_consumables)
	elif game_controller.get("corkboard_ui"):
		var corkboard = game_controller.corkboard_ui
		if corkboard:
			corkboard.max_consumables = DEFAULT_MAX + EXTRA_SLOTS
			if corkboard.has_method("update_consumable_label"):
				corkboard.update_consumable_label()
			print("[ExtraCouponsPowerUp] Updated CorkboardUI max_consumables to %d" % corkboard.max_consumables)
	
	# Also update ConsumableUI if available (fallback/secondary)
	if game_controller.get("consumable_ui"):
		var consumable_ui = game_controller.consumable_ui
		if consumable_ui:
			consumable_ui.max_consumables = DEFAULT_MAX + EXTRA_SLOTS
			if consumable_ui.has_method("update_slots_label"):
				consumable_ui.update_slots_label()
			print("[ExtraCouponsPowerUp] Updated ConsumableUI max_consumables to %d" % consumable_ui.max_consumables)
	
	print("[ExtraCouponsPowerUp] Applied - max consumables now %d" % (DEFAULT_MAX + EXTRA_SLOTS))

func remove(target) -> void:
	print("=== Removing ExtraCouponsPowerUp ===")
	print("[ExtraCouponsPowerUp] Target type: %s" % target.get_class() if target else "null")
	
	# Target should be the GameController
	var game_controller = target
	if not game_controller:
		push_error("[ExtraCouponsPowerUp] No target provided for removal")
		return
	
	var current_count: int = 0
	var corkboard = null
	var consumable_ui = null
	
	# Get CorkboardUI if available (primary)
	if game_controller.get("corkboard_ui"):
		corkboard = game_controller.corkboard_ui
	
	# Get ConsumableUI if available (fallback)
	if game_controller.get("consumable_ui"):
		consumable_ui = game_controller.consumable_ui
	
	# Determine current count from whichever UI is active
	if corkboard:
		current_count = corkboard._active_consumable_count
		print("[ExtraCouponsPowerUp] CorkboardUI active count: %d" % current_count)
	elif consumable_ui:
		current_count = consumable_ui._active_consumable_count
		print("[ExtraCouponsPowerUp] ConsumableUI active count: %d" % current_count)
	
	var overflow_count: int = current_count - DEFAULT_MAX
	print("[ExtraCouponsPowerUp] Current: %d, Default max: %d, Overflow: %d" % [current_count, DEFAULT_MAX, overflow_count])
	
	# Reset max consumables on CorkboardUI
	if corkboard:
		corkboard.max_consumables = DEFAULT_MAX
		if corkboard.has_method("update_consumable_label"):
			corkboard.update_consumable_label()
		print("[ExtraCouponsPowerUp] Reset CorkboardUI max_consumables to %d" % DEFAULT_MAX)
		
		# Trigger overflow if needed
		if overflow_count > 0 and corkboard.has_method("handle_consumable_overflow"):
			print("[ExtraCouponsPowerUp] Triggering CorkboardUI overflow for %d excess" % overflow_count)
			corkboard.handle_consumable_overflow(overflow_count)
	
	# Also reset ConsumableUI if available
	if consumable_ui:
		consumable_ui.max_consumables = DEFAULT_MAX
		if consumable_ui.has_method("update_slots_label"):
			consumable_ui.update_slots_label()
		print("[ExtraCouponsPowerUp] Reset ConsumableUI max_consumables to %d" % DEFAULT_MAX)
		
		# Trigger overflow on ConsumableUI too if CorkboardUI didn't handle it
		if overflow_count > 0 and not corkboard and consumable_ui.has_method("handle_consumable_overflow"):
			print("[ExtraCouponsPowerUp] Triggering ConsumableUI overflow for %d excess" % overflow_count)
			consumable_ui.handle_consumable_overflow(overflow_count)
	
	if overflow_count <= 0:
		print("[ExtraCouponsPowerUp] No overflow - current count %d <= max %d" % [current_count, DEFAULT_MAX])

func get_current_description() -> String:
	return "Hold 2 additional consumables (5 max)"
