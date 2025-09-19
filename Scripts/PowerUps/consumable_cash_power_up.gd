extends PowerUp
class_name ConsumableCashPowerUp

# Track total consumables used in the game for bonus calculation
var consumables_used_count: int = 0
var base_income_per_turn: int = 1

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")
	#add_to_group("turn_tracker")
	print("[ConsumableCashPowerUp] Added to 'power_ups' group")

func apply(target) -> void:
	# Get reference to the GameController to listen for signals
	#print("[ConsumableCashPowerUp] TurnTracker found:", turn_tracker != null)
	#print("[ConsumableCashPowerUp] TurnTracker groups:", turn_tracker.get_groups() if turn_tracker else "N/A")
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if not game_controller:
		push_error("[ConsumableCashPowerUp] GameController not found")
		return
		
	# Connect to consumable usage to track count
	if not game_controller.is_connected("consumable_used", _on_consumable_used):
		game_controller.consumable_used.connect(_on_consumable_used)
		print("[ConsumableCashPowerUp] Connected to consumable_used signal")
	
	# Connect to turn starts to grant money
	var turn_tracker = get_tree().get_first_node_in_group("turn_tracker")
	if not turn_tracker:
		push_error("[ConsumableCashPowerUp] TurnTracker not found")
		return
		
	if not turn_tracker.is_connected("turn_started", _on_turn_started):
		turn_tracker.turn_started.connect(_on_turn_started)
		print("[ConsumableCashPowerUp] Connected to turn_started signal")

func remove(target) -> void:
	# Disconnect from all signals when power-up is removed
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.is_connected("consumable_used", _on_consumable_used):
		game_controller.consumable_used.disconnect(_on_consumable_used)
		
	var turn_tracker = get_tree().get_first_node_in_group("turn_tracker")
	if turn_tracker and turn_tracker.is_connected("turn_started", _on_turn_started):
		turn_tracker.turn_started.disconnect(_on_turn_started)
		
	print("[ConsumableCashPowerUp] Disconnected from all signals")

func get_current_description() -> String:
	var desc = "Grants %d dollars per turn (%d base + %d bonus from %d consumables used)" % [
		get_total_income(),
		base_income_per_turn,
		consumables_used_count,
		consumables_used_count
	]
	return desc

func _on_consumable_used(consumable_id: String, _consumable) -> void:
	consumables_used_count += 1
	print("[ConsumableCashPowerUp] Consumable used count:", consumables_used_count)
	emit_signal("description_updated", id, get_current_description())

func _on_turn_started() -> void:
	var income = get_total_income()
	
	# Grant money through PlayerEconomy
	var player_economy = get_node("/root/PlayerEconomy")
	if player_economy:
		player_economy.add_money(income)
		print("[ConsumableCashPowerUp] Granted %d dollars for turn (base: %d + bonus: %d)" % [
			income, base_income_per_turn, consumables_used_count
		])
	else:
		push_error("[ConsumableCashPowerUp] PlayerEconomy autoload not found")

func get_total_income() -> int:
	return base_income_per_turn + consumables_used_count
