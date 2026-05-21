extends Node

## HitstopController
##
## Autoload singleton for frame freezes and slow-motion effects.
## Used for impactful moments: Yahtzee, challenge complete, debuff slam, etc.

var _original_time_scale: float = 1.0
var _is_active: bool = false

func _ready() -> void:
	_original_time_scale = Engine.time_scale


## trigger_hitstop(duration_frames, time_scale)
##
## Briefly freezes or slows time for a number of physics frames.
## Default: 3 frames at 0.01x speed (near-freeze).
## Call await trigger_hitstop() to wait for completion.
func trigger_hitstop(duration_frames: int = 3, time_scale: float = 0.01) -> void:
	if _is_active:
		return
	_is_active = true
	
	Engine.time_scale = time_scale
	
	# Wait for the specified number of physics frames
	for i in range(duration_frames):
		await get_tree().physics_frame
	
	Engine.time_scale = _original_time_scale
	_is_active = false


## trigger_slowmo(duration, target_scale, fade_in, fade_out)
##
## Smoothly ramps time scale down and back up.
## Useful for dramatic moments like dice rolling or challenge completion.
func trigger_slowmo(duration: float = 0.5, target_scale: float = 0.3, fade_in: float = 0.15, fade_out: float = 0.25) -> void:
	if _is_active:
		return
	_is_active = true
	
	var tween := create_tween()
	
	# Fade in to slow motion
	tween.tween_property(Engine, "time_scale", target_scale, fade_in)
	
	# Hold at slow motion
	if duration > fade_in + fade_out:
		tween.tween_interval(duration - fade_in - fade_out)
	
	# Fade out back to normal
	tween.tween_property(Engine, "time_scale", _original_time_scale, fade_out)
	
	await tween.finished
	_is_active = false


## reset_time_scale()
##
## Immediately restores normal time scale. Use as emergency brake.
func reset_time_scale() -> void:
	Engine.time_scale = _original_time_scale
	_is_active = false
