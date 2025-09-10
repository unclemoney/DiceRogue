# PowerUpUI.gd
extends Control
class_name PowerUpUI

signal power_up_selected(power_up_id: String)
signal power_up_deselected(power_up_id: String)
signal power_up_sold(power_up_id: String)

@export var power_up_icon_scene: PackedScene
@onready var container: Control

var _icons := {}  # power_up_id -> PowerUpIcon

func _ready() -> void:
	print("[PowerUpUI] Initializing...")
	print("[PowerUpUI] Children:", get_children())
	print("[PowerUpUI] power_up_icon_scene set:", power_up_icon_scene != null)
	
	# Fix 1: Create the container if it doesn't exist
	if not has_node("PowerUpContainer"):
		print("[PowerUpUI] Creating PowerUpContainer")
		container = Control.new()
		container.name = "PowerUpContainer"
		container.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(container)
	else:
		container = $PowerUpContainer
		print("[PowerUpUI] Found existing PowerUpContainer")
		
	# Fix 2: Load the power_up_icon scene if not set
	if not power_up_icon_scene:
		print("[PowerUpUI] Loading default power_up_icon scene")
		power_up_icon_scene = load("res://Scenes/PowerUp/power_up_icon.tscn")
		if not power_up_icon_scene:
			push_error("[PowerUpUI] Failed to load default power_up_icon scene")

func add_power_up(data: PowerUpData) -> PowerUpIcon:
	print("[PowerUpUI] Adding power up:", data.id if data else "null")
	
	if not power_up_icon_scene:
		push_error("[PowerUpUI] power_up_icon_scene not set")
		return null
		
	if not data:
		push_error("[PowerUpUI] Cannot add null power-up data")
		return null
		
	if not container:
		push_error("[PowerUpUI] Container is null, trying to create it")
		# Last resort fallback
		container = Control.new()
		container.name = "PowerUpContainer"
		add_child(container)
		
	var icon = power_up_icon_scene.instantiate() as PowerUpIcon
	if not icon:
		push_error("[PowerUpUI] Failed to instantiate power-up icon")
		return null
		
	container.add_child(icon)
	icon.set_data(data)
	
	# Connect signals
	icon.connect("power_up_sell_requested", Callable(self, "_on_power_up_sell_requested"))
	
	# Store the icon reference
	_icons[data.id] = icon
	
	print("[PowerUpUI] Added power-up:", data.id)
	return icon
	
func _on_power_up_sell_requested(power_up_id: String) -> void:
	print("[PowerUpUI] Power-up sell requested:", power_up_id)
	emit_signal("power_up_sold", power_up_id)
	
func remove_power_up(power_up_id: String) -> void:
	if _icons.has(power_up_id):
		var icon = _icons[power_up_id]
		if icon:
			icon.queue_free()
		_icons.erase(power_up_id)
		print("[PowerUpUI] Removed power-up icon:", power_up_id)
