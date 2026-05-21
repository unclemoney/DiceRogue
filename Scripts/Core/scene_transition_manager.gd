extends Node

## SceneTransitionManager
##
## Autoload singleton for cinematic scene transitions.
## Supports fade, CRT wipe, and crossfade styles.

enum Style { FADE, CRT_WIPE, CROSSFADE }

const FADE_SHADER := preload("res://Scripts/Shaders/tv_power_on.gdshader")

var _overlay: ColorRect
var _canvas: CanvasLayer
var _is_transitioning: bool = false

func _ready() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 999
	_canvas.name = "TransitionCanvas"
	add_child(_canvas)
	
	_overlay = ColorRect.new()
	_overlay.name = "TransitionOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	_canvas.add_child(_overlay)


## transition_to_scene(path, style, duration)
##
## Performs a transition to the given scene path.
## Awaits the full transition (out → change → in).
func transition_to_scene(scene_path: String, style: Style = Style.FADE, duration: float = 0.5) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	
	match style:
		Style.FADE:
			await _transition_fade(scene_path, duration)
		Style.CRT_WIPE:
			await _transition_crt_wipe(scene_path, duration)
		Style.CROSSFADE:
			await _transition_crossfade(scene_path, duration)
	
	_is_transitioning = false


## transition_to_scene_packed(scene, style, duration)
##
## Variant that takes a PackedScene instead of a path.
func transition_to_scene_packed(scene: PackedScene, style: Style = Style.FADE, duration: float = 0.5) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	
	match style:
		Style.FADE:
			await _transition_fade_packed(scene, duration)
		Style.CRT_WIPE:
			await _transition_crt_wipe_packed(scene, duration)
		Style.CROSSFADE:
			await _transition_crossfade_packed(scene, duration)
	
	_is_transitioning = false


func _transition_fade(scene_path: String, duration: float) -> void:
	await _fade_out(duration * 0.5)
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_in(duration * 0.5)


func _transition_fade_packed(scene: PackedScene, duration: float) -> void:
	await _fade_out(duration * 0.5)
	get_tree().change_scene_to_packed(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_in(duration * 0.5)


func _transition_crt_wipe(scene_path: String, duration: float) -> void:
	await _crt_wipe_out(duration * 0.5)
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	await _crt_wipe_in(duration * 0.5)


func _transition_crt_wipe_packed(scene: PackedScene, duration: float) -> void:
	await _crt_wipe_out(duration * 0.5)
	get_tree().change_scene_to_packed(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	await _crt_wipe_in(duration * 0.5)


func _transition_crossfade(scene_path: String, duration: float) -> void:
	await _crossfade_out(duration * 0.5)
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	await _crossfade_in(duration * 0.5)


func _transition_crossfade_packed(scene: PackedScene, duration: float) -> void:
	await _crossfade_out(duration * 0.5)
	get_tree().change_scene_to_packed(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	await _crossfade_in(duration * 0.5)


func _crossfade_out(duration: float) -> void:
	# Capture current viewport as texture
	var viewport_img := get_viewport().get_texture().get_image()
	var tex := ImageTexture.create_from_image(viewport_img)
	
	# Create full-screen snapshot overlay
	var snapshot := TextureRect.new()
	snapshot.name = "CrossfadeSnapshot"
	snapshot.set_anchors_preset(Control.PRESET_FULL_RECT)
	snapshot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	snapshot.texture = tex
	snapshot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	snapshot.z_index = 500
	_canvas.add_child(snapshot)
	
	# Brief hold so the old scene is fully visible before fading
	await get_tree().create_timer(duration * 0.2).timeout


func _crossfade_in(duration: float) -> void:
	var snapshot = _canvas.get_node_or_null("CrossfadeSnapshot")
	if not snapshot:
		return
	
	# Fade out the snapshot revealing the new scene underneath
	var tween := create_tween()
	tween.tween_property(snapshot, "modulate:a", 0.0, duration)
	await tween.finished
	
	if is_instance_valid(snapshot):
		snapshot.queue_free()


func _fade_out(duration: float) -> void:
	_overlay.material = null
	_overlay.color = Color.BLACK
	_overlay.modulate.a = 0.0
	_overlay.visible = true
	
	var tween := create_tween()
	tween.tween_property(_overlay, "modulate:a", 1.0, duration)
	await tween.finished


func _fade_in(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_overlay, "modulate:a", 0.0, duration)
	await tween.finished
	_overlay.visible = false


func _crt_wipe_out(duration: float) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = FADE_SHADER
	mat.set_shader_parameter("progress", 1.0)
	_overlay.material = mat
	_overlay.color = Color.WHITE
	_overlay.modulate.a = 1.0
	_overlay.visible = true
	
	var tween := create_tween()
	tween.tween_method(_set_crt_progress.bind(mat), 1.0, 0.0, duration)
	await tween.finished


func _crt_wipe_in(duration: float) -> void:
	var mat: ShaderMaterial = _overlay.material
	if not mat:
		mat = ShaderMaterial.new()
		mat.shader = FADE_SHADER
		_overlay.material = mat
	
	var tween := create_tween()
	tween.tween_method(_set_crt_progress.bind(mat), 0.0, 1.0, duration)
	await tween.finished
	_overlay.visible = false
	_overlay.material = null


func _set_crt_progress(value: float, mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("progress", value)
