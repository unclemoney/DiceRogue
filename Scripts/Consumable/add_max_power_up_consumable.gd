extends Consumable
class_name AddMaxPowerUpConsumable

signal max_power_up_increased(new_max: int)

# Maximum allowed power-up slots (hard cap)
const ABSOLUTE_MAX_SLOTS := 7

func _ready() -> void:
	add_to_group("consumables")
	print("[AddMaxPowerUp] Ready")

func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[AddMaxPowerUp] Invalid target passed to apply()")
		return
		
	var power_up_ui = game_controller.powerup_ui
	if not power_up_ui:
		push_error("[AddMaxPowerUp] No PowerUpUI found")
		return
		
	# Check if we've reached the absolute maximum
	if power_up_ui.max_power_ups >= ABSOLUTE_MAX_SLOTS:
		print("[AddMaxPowerUp] Already at maximum power-up capacity")
		return
		
	# Increase the maximum by 1
	power_up_ui.max_power_ups += 1
	print("[AddMaxPowerUp] Increased max power-ups to", power_up_ui.max_power_ups)
	
	# Update the UI to reflect new slot count
	power_up_ui.update_slots_label()
	
	# Emit signal for any listeners
	emit_signal("max_power_up_increased", power_up_ui.max_power_ups)
	
