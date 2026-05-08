extends ColorRect
class_name TVPowerController

## Controls the TV turn-on/off beam animation by tweening the shader progress uniform.
##
## Attach to a ColorRect with tv_power_on.gdshader material. The overlay must be
## the topmost child of CRTTV so SCREEN_TEXTURE captures all siblings.

signal tv_turned_on
signal tv_turned_off

@export var turn_on_duration: float = 1.2
@export var turn_off_duration: float = 0.8

var _progress_tween: Tween


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


## turn_on()
##
## Plays the CRT beam expansion animation (progress 0 -> 1) and hides the node
## when complete for performance.
func turn_on() -> void:
	visible = true
	if _progress_tween and _progress_tween.is_valid():
		_progress_tween.kill()
	_progress_tween = create_tween()
	_progress_tween.tween_method(_set_progress, 0.0, 1.0, turn_on_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await _progress_tween.finished
	visible = false
	tv_turned_on.emit()


## turn_off()
##
## Shows the node, snaps progress to 1.0, then plays the collapse animation
## (progress 1 -> 0). The node remains visible on black after completion.
func turn_off() -> void:
	visible = true
	_set_progress(1.0)
	if _progress_tween and _progress_tween.is_valid():
		_progress_tween.kill()
	_progress_tween = create_tween()
	_progress_tween.tween_method(_set_progress, 1.0, 0.0, turn_off_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await _progress_tween.finished
	tv_turned_off.emit()


## set_progress(value)
##
## Directly sets the shader progress uniform. Useful for debug or instant state.
func set_progress(value: float) -> void:
	_set_progress(value)


func _set_progress(value: float) -> void:
	if material and material is ShaderMaterial:
		material.set_shader_parameter("progress", clampf(value, 0.0, 1.0))
