extends Node
class_name CRTManager

# Controls CRT shader visibility and TV "off" state
signal crt_enabled
signal crt_disabled

@export var crt_overlay_path: NodePath
@export var tv_off_overlay_path: NodePath

@onready var crt_overlay: CanvasLayer = get_node_or_null(crt_overlay_path)
@onready var tv_off_overlay: ColorRect = get_node_or_null(tv_off_overlay_path)

var _is_crt_enabled: bool = false

func _ready() -> void:
	# Default state: TV is off (black screen)
	_set_tv_off_state()
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

func is_crt_enabled() -> bool:
	return _is_crt_enabled