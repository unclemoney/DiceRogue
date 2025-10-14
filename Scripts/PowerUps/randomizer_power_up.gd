extends PowerUp
class_name RandomizerPowerUp

# Current effect state
var current_effect_type: String = ""  # "additive" or "multiplier"
var current_effect_value: int = 0
var current_multiplier_value: float = 1.0

signal effect_updated(effect_type: String, value_text: String)

func _ready() -> void:
	add_to_group("power_ups")
	print("[RandomizerPowerUp] Added to 'power_ups' group")

func apply(target) -> void:
	# Connect to turn_started signal to randomize effect each turn
	var turn_tracker = get_tree().get_first_node_in_group("turn_tracker")
	if not turn_tracker:
		push_error("[RandomizerPowerUp] TurnTracker not found")
		return
		
	if not turn_tracker.is_connected("turn_started", _on_turn_started):
		turn_tracker.turn_started.connect(_on_turn_started)
		print("[RandomizerPowerUp] Connected to turn_started signal")
	
	# Initialize with first random effect
	_randomize_effect()

func remove(target) -> void:
	# Disconnect from turn tracker
	var turn_tracker = get_tree().get_first_node_in_group("turn_tracker")
	if turn_tracker and turn_tracker.is_connected("turn_started", _on_turn_started):
		turn_tracker.turn_started.disconnect(_on_turn_started)
	
	# Clean up any active modifiers
	_clear_current_effect()
	print("[RandomizerPowerUp] Disconnected from all signals and cleared effects")

func _on_turn_started() -> void:
	print("[RandomizerPowerUp] New turn started, randomizing effect")
	_randomize_effect()

func _randomize_effect() -> void:
	# Clear previous effect first
	_clear_current_effect()
	
	# 80% chance additive, 20% chance multiplier
	var effect_roll = randf()
	
	if effect_roll < 0.8:
		_apply_additive_effect()
	else:
		_apply_multiplier_effect()

func _apply_additive_effect() -> void:
	current_effect_type = "additive"
	
	# Equal 10% chance for each additive value
	var additive_values = [-20, -10, 0, 5, 10, 15, 20, 25, 30, 50]
	var index = randi() % additive_values.size()
	current_effect_value = additive_values[index]
	
	# Register with ScoreModifierManager
	ScoreModifierManager.register_additive("randomizer", current_effect_value)
	
	var value_text = "+%d" % current_effect_value if current_effect_value >= 0 else str(current_effect_value)
	print("[RandomizerPowerUp] Applied additive effect:", current_effect_value)
	# Don't emit signal here anymore

func _apply_multiplier_effect() -> void:
	current_effect_type = "multiplier"
	
	# Weighted random selection for multiplier
	var roll = randf() * 100.0
	
	if roll < 5.0:  # 5% chance
		current_multiplier_value = -1.0
	elif roll < 15.0:  # 10% chance (5% + 10%)
		current_multiplier_value = 0.0
	elif roll < 65.0:  # 50% chance (15% + 50%)
		current_multiplier_value = 1.0
	elif roll < 85.0:  # 20% chance (65% + 20%)
		current_multiplier_value = 2.0
	elif roll < 99.0:  # 14% chance (85% + 14%)
		current_multiplier_value = 3.0
	else:  # 1% chance (99% + 1%)
		current_multiplier_value = 4.0
	
	# Register with ScoreModifierManager
	ScoreModifierManager.register_multiplier("randomizer", current_multiplier_value)
	
	print("[RandomizerPowerUp] Applied multiplier effect:", current_multiplier_value)
	# Don't emit signal here anymore

# Add new method to show effect after scoring
func show_effect_after_scoring() -> void:
	var value_text = ""
	if current_effect_type == "additive":
		value_text = "+%d" % current_effect_value if current_effect_value >= 0 else str(current_effect_value)
	elif current_effect_type == "multiplier":
		value_text = "×%d" % int(current_multiplier_value)
	
	if value_text != "":
		emit_signal("effect_updated", current_effect_type, value_text)

func _clear_current_effect() -> void:
	# Remove any existing effects from ScoreModifierManager
	if current_effect_type == "additive":
		ScoreModifierManager.unregister_additive("randomizer")
	elif current_effect_type == "multiplier":
		ScoreModifierManager.unregister_multiplier("randomizer")
	
	current_effect_type = ""
	current_effect_value = 0
	current_multiplier_value = 1.0

func get_current_effect_description() -> String:
	if current_effect_type == "additive":
		var value_text = "+%d" % current_effect_value if current_effect_value >= 0 else str(current_effect_value)
		return "Random Score Bonus: %s" % value_text
	elif current_effect_type == "multiplier":
		return "Random Score Multiplier: ×%d" % int(current_multiplier_value)
	else:
		return "Random Effect: Not yet determined"