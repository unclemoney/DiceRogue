extends Consumable
class_name InsurancePolicyConsumable

func _ready() -> void:
	add_to_group("consumables")
	print("[InsurancePolicyConsumable] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[InsurancePolicyConsumable] Invalid target passed to apply()")
		return
	
	# Activate insurance - if next score is 0, grant $75 consolation
	game_controller.insurance_policy_active = true
	print("[InsurancePolicyConsumable] Insurance Policy activated. Next 0-score grants $75.")
