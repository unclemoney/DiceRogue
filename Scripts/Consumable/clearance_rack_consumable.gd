extends Consumable
class_name ClearanceRackConsumable

func _ready() -> void:
	add_to_group("consumables")
	print("[ClearanceRackConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[ClearanceRackConsumable] Invalid target passed to apply()")
		return
	
	# Activate clearance rack - free shop rerolls until shop closes
	game_controller.clearance_rack_active = true
	print("[ClearanceRackConsumable] Clearance Rack activated. Shop rerolls are free until shop closes.")
