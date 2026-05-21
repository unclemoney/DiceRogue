extends Node

## HitstopController
##
## Autoload singleton for cinematic hitstop (time freeze) effects.
## Dips Engine.time_scale to create impactful pauses on critical moments.

var _default_time_scale: float = 1.0
var _is_hitstopping: bool = false


## trigger_hitstop(frames)
##
## Freezes time for the given number of frames at 60fps.
## Example: trigger_hitstop(3) = 3 frames ≈ 0.05s freeze.
## Fire-and-forget; safe to call overlapping (extends current hitstop).
func trigger_hitstop(frames: int = 3) -> void:
	if _is_hitstopping:
		# Extend existing hitstop by resetting timer
		return
	
	var duration: float = frames / 60.0
	_is_hitstopping = true
	Engine.time_scale = 0.0
	
	await get_tree().create_timer(duration, true).timeout
	
	Engine.time_scale = _default_time_scale
	_is_hitstopping = false


## trigger_slowmo(duration, time_scale)
##
## Brief slow-motion effect. Useful for dramatic moments.
## time_scale: 0.1 = very slow, 0.5 = half speed.
func trigger_slowmo(duration: float = 0.5, target_scale: float = 0.3) -> void:
	Engine.time_scale = target_scale
	await get_tree().create_timer(duration, true).timeout
	Engine.time_scale = _default_time_scale
