extends Node
class_name CRTManager

# Controls CRT shader visibility and TV "off" state
signal crt_enabled
signal crt_disabled

@export var crt_overlay_path: NodePath
@export var tv_off_overlay_path: NodePath
@export var tv_power_controller_path: NodePath

@onready var crt_overlay: CanvasLayer = get_node_or_null(crt_overlay_path)
@onready var tv_off_overlay: ColorRect = get_node_or_null(tv_off_overlay_path)
@onready var tv_power_controller: TVPowerController = get_node_or_null(tv_power_controller_path)

var _is_crt_enabled: bool = false

func _ready() -> void:
	# Default state: TV is off (black screen)
	#_set_tv_off_state()
	_ensure_tv_power_overlay.call_deferred()
	print("[CRTManager] Initialized with TV off state")

func enable_crt() -> void:
	"""Enable CRT effect for active gameplay"""
	if _is_crt_enabled:
		return
		
	_is_crt_enabled = true
	
	if tv_off_overlay:
		tv_off_overlay.visible = false
		
	if crt_overlay:
		crt_overlay.visible = true
		
	emit_signal("crt_enabled")
	print("[CRTManager] CRT enabled for gameplay")

func disable_crt() -> void:
	"""Disable CRT effect for menus/shop"""
	if not _is_crt_enabled:
		return
		
	_is_crt_enabled = false
	
	if crt_overlay:
		crt_overlay.visible = false
		
	emit_signal("crt_disabled")
	print("[CRTManager] CRT disabled for menu")

func set_tv_off() -> void:
	"""Show black screen (TV off state)"""
	_is_crt_enabled = false
	
	if crt_overlay:
		crt_overlay.visible = false
		
	if tv_off_overlay:
		tv_off_overlay.visible = true
		
	print("[CRTManager] TV set to off state")

func _set_tv_off_state() -> void:
	"""Internal helper to set initial TV off state"""
	_is_crt_enabled = false
	
	if crt_overlay:
		crt_overlay.visible = false
		
	if tv_off_overlay:
		tv_off_overlay.visible = true

func turn_on_tv() -> void:
	"""Play TV turn-on beam animation, then enable CRT effects."""
	if tv_power_controller:
		await tv_power_controller.turn_on()
	enable_crt()

func turn_off_tv() -> void:
	"""Disable CRT effects, play TV turn-off beam animation, hold black."""
	disable_crt()
	if tv_power_controller:
		await tv_power_controller.turn_off()

func is_crt_enabled() -> bool:
	return _is_crt_enabled

func snap_tv_off() -> void:
	"""Instantly set TV to black without animation."""
	disable_crt()
	if tv_power_controller:
		tv_power_controller.visible = true
		tv_power_controller.set_progress(0.0)

func _ensure_tv_power_overlay() -> void:
	## Ensures the TVPowerOverlay exists as the last child of the parent CRTTV node.
	## Creates it dynamically if not present in the scene.
	if tv_power_controller and is_instance_valid(tv_power_controller):
		return
	var parent = get_parent()
	if not parent:
		return
	tv_power_controller = parent.get_node_or_null("TVPowerOverlay")
	if tv_power_controller and is_instance_valid(tv_power_controller):
		return
	var overlay = TVPowerController.new()
	overlay.name = "TVPowerOverlay"
	overlay.offset_left = -137.0
	overlay.offset_top = -276.0
	overlay.offset_right = 563.0
	overlay.offset_bottom = 284.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader = load("res://Scripts/Shaders/tv_power_on.gdshader")
	if shader:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		overlay.material = mat
	parent.add_child(overlay)
	parent.move_child(overlay, -1)
	tv_power_controller = overlay
	print("[CRTManager] Auto-created TVPowerOverlay")
