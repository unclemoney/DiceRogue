# PowerUpUI.gd
extends Control
class_name PowerUpUI

signal power_up_selected(power_up_id: String)
signal power_up_deselected(power_up_id: String)
signal power_up_sold(power_up_id: String)
signal max_power_ups_reached

@export var power_up_icon_scene: PackedScene
@export var max_power_ups: int = 2
@onready var container: HBoxContainer
@onready var slots_label: Label = $SlotsLabel

var _icons := {}  # power_up_id -> PowerUpIcon

func _ready() -> void:
	print("[PowerUpUI] Initializing...")
	print("[PowerUpUI] Children:", get_children())
	print("[PowerUpUI] power_up_icon_scene set:", power_up_icon_scene != null)
	
	# Get the Container node - use the existing one in the scene
	if has_node("Container"):
		container = $Container
		
		# Fix: Apply correct container settings for proper layout
		container.mouse_filter = Control.MOUSE_FILTER_PASS
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		#container.size_flags_vertical = Control.SIZE_BEGIN
		container.visible = true
		
		# Ensure anchors are set correctly for top-wide layout
		container.anchor_right = 1.0
		container.anchor_bottom = 0.0
		container.offset_top = 0
		container.offset_bottom = 64  # Height to accommodate icons
		
		print("[PowerUpUI] Reconfigured existing Container")
	else:
		# Create Container if it doesn't exist (fallback)
		print("[PowerUpUI] Creating Container")
		container = HBoxContainer.new()
		container.name = "Container"
		container.mouse_filter = Control.MOUSE_FILTER_PASS
		container.set_anchors_preset(Control.PRESET_TOP_WIDE)
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		#container.size_flags_vertical = Control.SIZE_BEGIN
		add_child(container)
	
	# Set up the slots label if it doesn't exist
	if not has_node("SlotsLabel"):
		slots_label = Label.new()
		slots_label.name = "SlotsLabel"
		slots_label.position = Vector2(100, -28)  # Position next to "POWER UPS" label
		add_child(slots_label)
	else:
		slots_label = $SlotsLabel
		
	# Fix 2: Load the power_up_icon scene if not set
	if not power_up_icon_scene:
		print("[PowerUpUI] Loading default power_up_icon scene")
		power_up_icon_scene = load("res://Scenes/PowerUp/power_up_icon.tscn")
		if not power_up_icon_scene:
			push_error("[PowerUpUI] Failed to load default power_up_icon scene")
	
	# Initialize slots label
	update_slots_label()
	
	print("[PowerUpUI] Initialization complete")
	# Debug container properties
	print("[PowerUpUI] Container visible:", container.visible)
	print("[PowerUpUI] Container rect size:", container.size)
	print("[PowerUpUI] Container global position:", container.global_position)

func add_power_up(data: PowerUpData) -> PowerUpIcon:
	print("[PowerUpUI] Adding power up:", data.id if data else "null")
	
	# Check if we've reached the max number of power-ups
	if _icons.size() >= max_power_ups:
		print("[PowerUpUI] Maximum number of power-ups reached!")
		emit_signal("max_power_ups_reached")
		return null
		
	if not power_up_icon_scene:
		push_error("[PowerUpUI] power_up_icon_scene not set")
		return null
		
	if not data:
		push_error("[PowerUpUI] Cannot add null power-up data")
		return null
		
	if not container:
		push_error("[PowerUpUI] Container is null, trying to create it")
		# Last resort fallback
		container = HBoxContainer.new()
		container.name = "Container"
		add_child(container)
		
	var icon = power_up_icon_scene.instantiate() as PowerUpIcon
	if not icon:
		push_error("[PowerUpUI] Failed to instantiate power-up icon")
		return null
		
	# Add icon to container
	container.add_child(icon)
	icon.set_data(data)
	
	# Connect signals
	icon.connect("power_up_sell_requested", Callable(self, "_on_power_up_sell_requested"))
	
	# Store the icon reference
	_icons[data.id] = icon
	
	# Update the slots label
	update_slots_label()
	
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
		# Update slots label after removing a power-up
		update_slots_label()
		print("[PowerUpUI] Removed power-up icon:", power_up_id)

func update_slots_label() -> void:
	# Update the slots label to show current/max power-ups
	var current = _icons.size()
	slots_label.text = "(%d/%d)" % [current, max_power_ups]
	
	# Change text color to red when at max capacity
	if current >= max_power_ups:
		slots_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		slots_label.remove_theme_color_override("font_color")

func has_max_power_ups() -> bool:
	return _icons.size() >= max_power_ups
