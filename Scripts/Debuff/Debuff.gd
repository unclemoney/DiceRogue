extends Node
class_name Debuff

## Debuff
##
## Base class for all debuffs in the game.
## Debuffs apply negative effects that can scale with channel difficulty.
##
## Intensity System:
## - intensity: float value from 1.0 (normal) to higher values (more severe)
## - Debuffs can use intensity to scale their effects
## - Set by DebuffManager when applying debuffs based on channel config

@export var id: String
var target: Node
var is_active := false
var intensity: float = 1.0  ## Difficulty intensity multiplier (1.0 = normal, 2.0 = double, etc.)

signal debuff_started
signal debuff_ended
signal visual_pulse_requested(strength: float, duration: float)


## set_intensity(value)
##
## Sets the intensity multiplier for this debuff.
## Called by DebuffManager before apply() is invoked.
## @param value: The intensity multiplier (1.0 = normal)
func set_intensity(value: float) -> void:
	intensity = maxf(1.0, value)  # Minimum intensity is 1.0


## request_visual_pulse(strength, duration)
##
## Emits a UI-facing pulse request so debuff-specific gameplay events can trigger
## compact and fan-out neon feedback without the UI inferring gameplay semantics.
func request_visual_pulse(strength: float = 1.0, duration: float = 0.42) -> void:
	emit_signal("visual_pulse_requested", clampf(strength, 0.0, 1.4), maxf(duration, 0.05))


func start() -> void:
	print("[Debuff] Starting debuff:", id, "with intensity:", intensity)
	is_active = true
	apply(target)
	emit_signal("debuff_started")


func apply(_target) -> void:
	push_error("Debuff.apply() must be overridden")


func remove() -> void:
	push_error("Debuff.remove() must be overridden")


func end() -> void:
	print("[Debuff] Ending debuff:", id)
	is_active = false
	remove()
	emit_signal("debuff_ended")
