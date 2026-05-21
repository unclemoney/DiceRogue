extends Node
class_name CameraDynamics

## CameraDynamics
##
## Attach as a child of a Camera2D to add dynamic zoom, pan, and shake effects.
## Used by ScoringAnimationController for big scores and celebrations.
## Falls back to animating a Node2D parent if no Camera2D is present.

@export var default_zoom: Vector2 = Vector2.ONE
@export var max_zoom: float = 1.3
@export var min_zoom: float = 0.8

var _camera: Camera2D
var _node2d: Node2D
var _original_zoom: Vector2
var _original_offset: Vector2
var _original_scale: Vector2
var _original_position: Vector2
var _is_active: bool = false

func _ready() -> void:
	_camera = get_parent() as Camera2D
	if _camera:
		_original_zoom = _camera.zoom
		_original_offset = _camera.offset
		_camera.enabled = true
		_camera.make_current()
	else:
		_node2d = get_parent() as Node2D
		if _node2d:
			_original_scale = _node2d.scale
			_original_position = _node2d.position
		else:
			push_warning("[CameraDynamics] Parent is neither Camera2D nor Node2D!")


## zoom_to(scale, duration)
##
## Smoothly zooms the camera to the target scale relative to default.
## scale > 1 = zoom in, scale < 1 = zoom out.
## Falls back to scaling the parent Node2D if no Camera2D.
func zoom_to(scale_factor: float, duration: float = 0.4) -> void:
	if _camera:
		var target := default_zoom * scale_factor
		var tween := create_tween()
		tween.tween_property(_camera, "zoom", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elif _node2d:
		var tween := create_tween()
		tween.tween_property(_node2d, "scale", _original_scale * scale_factor, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## zoom_in(duration)
##
## Quick zoom-in for emphasis moments.
func zoom_in(duration: float = 0.3) -> void:
	zoom_to(max_zoom, duration)


## zoom_out(duration)
##
## Pull-back zoom for wide reveals.
func zoom_out(duration: float = 0.4) -> void:
	zoom_to(min_zoom, duration)


## reset_zoom(duration)
##
## Returns camera to its original zoom level.
func reset_zoom(duration: float = 0.5) -> void:
	if _camera:
		var tween := create_tween()
		tween.tween_property(_camera, "zoom", _original_zoom, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elif _node2d:
		var tween := create_tween()
		tween.tween_property(_node2d, "scale", _original_scale, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## subtle_pan_to(target_pos, duration)
##
## Slightly offsets the camera toward a target position.
## Useful for drawing attention to dice or UI elements.
func subtle_pan_to(target_pos: Vector2, duration: float = 0.4) -> void:
	if _camera:
		var viewport_size := get_viewport().get_visible_rect().size
		var center := viewport_size / 2.0
		var direction := (target_pos - center).normalized()
		var offset := direction * 30.0
		var tween := create_tween()
		tween.tween_property(_camera, "offset", _original_offset + offset, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	elif _node2d:
		var direction := (target_pos - _node2d.position).normalized()
		var offset := direction * 10.0
		var tween := create_tween()
		tween.tween_property(_node2d, "position", _original_position + offset, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## reset_pan(duration)
##
## Returns camera offset to original.
func reset_pan(duration: float = 0.4) -> void:
	if _camera:
		var tween := create_tween()
		tween.tween_property(_camera, "offset", _original_offset, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	elif _node2d:
		var tween := create_tween()
		tween.tween_property(_node2d, "position", _original_position, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## celebrate_zoom(duration)
##
## Quick zoom-in then settle back — perfect for score celebrations.
func celebrate_zoom(duration: float = 0.6) -> void:
	if _camera:
		var tween := create_tween()
		var peak_zoom := default_zoom * 1.08
		tween.tween_property(_camera, "zoom", peak_zoom, duration * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(_camera, "zoom", _original_zoom, duration * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elif _node2d:
		var tween := create_tween()
		var peak_scale := _original_scale * 1.04
		tween.tween_property(_node2d, "scale", peak_scale, duration * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(_node2d, "scale", _original_scale, duration * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
