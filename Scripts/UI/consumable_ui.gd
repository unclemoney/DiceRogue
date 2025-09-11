extends Control
class_name ConsumableUI

signal consumable_used(consumable_id: String)
signal consumable_sold(consumable_id: String) 
signal max_consumables_reached

@export var consumable_icon_scene: PackedScene
@export var max_consumables: int = 2
@onready var container: HBoxContainer
@onready var slots_label: Label = $SlotsLabel

var _icons := {}  # consumable_id -> ConsumableIcon

func _ready() -> void:
	print("[ConsumableUI] Initializing...")
	
	# Get the Container node - use the existing one in the scene
	if has_node("Container"):
		container = $Container
		# Make sure container is properly configured
		container.mouse_filter = Control.MOUSE_FILTER_PASS
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.visible = true
		# Set container separation
		container.add_theme_constant_override("separation", 10)
		print("[ConsumableUI] Found existing Container")
	else:
		# Create Container if it doesn't exist (fallback)
		print("[ConsumableUI] Creating Container")
		container = HBoxContainer.new()
		container.name = "Container"
		container.mouse_filter = Control.MOUSE_FILTER_PASS
		container.set_anchors_preset(Control.PRESET_TOP_WIDE)
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_theme_constant_override("separation", 10)
		add_child(container)
	
	# Set up the slots label if it doesn't exist
	if not has_node("SlotsLabel"):
		slots_label = Label.new()
		slots_label.name = "SlotsLabel"
		slots_label.position = Vector2(135, -28)  # Position next to "CONSUMABLES" label
		add_child(slots_label)
	else:
		slots_label = $SlotsLabel
		
	# Fix 2: Load the consumable_icon scene if not set
	if not consumable_icon_scene:
		print("[ConsumableUI] Loading default consumable_icon scene")
		consumable_icon_scene = load("res://Scenes/Consumable/consumable_icon.tscn")
		if not consumable_icon_scene:
			push_error("[ConsumableUI] Failed to load default consumable_icon scene")
	
	# Add to group for easy lookup
	add_to_group("consumable_ui")
	
	# Initialize slots label
	update_slots_label()
	
	print("[ConsumableUI] Initialization complete")

func add_consumable(data: ConsumableData) -> ConsumableIcon:
	print("[ConsumableUI] Adding consumable:", data.id if data else "null")
	
	# Check if we've reached the max number of consumables
	if _icons.size() >= max_consumables:
		print("[ConsumableUI] Maximum number of consumables reached!")
		emit_signal("max_consumables_reached")
		return null
		
	if not consumable_icon_scene:
		push_error("[ConsumableUI] consumable_icon_scene not set")
		return null
		
	if not data:
		push_error("[ConsumableUI] Cannot add null consumable data")
		return null
		
	if not container:
		push_error("[ConsumableUI] Container is null, trying to create it")
		# Last resort fallback
		container = HBoxContainer.new()
		container.name = "Container"
		add_child(container)
		
	var icon = consumable_icon_scene.instantiate() as ConsumableIcon
	if not icon:
		push_error("[ConsumableUI] Failed to instantiate consumable icon")
		return null
		
	# Add icon to container
	container.add_child(icon)
	icon.set_data(data)
	
	# Connect signals
	icon.consumable_used.connect(_on_consumable_used)
	
	# Add sell functionality
	icon.connect("consumable_sell_requested", Callable(self, "_on_consumable_sell_requested"))
	
	# Store the icon reference
	_icons[data.id] = icon
	
	# Update the slots label
	update_slots_label()
	
	print("[ConsumableUI] Added consumable:", data.id)
	return icon
	
func _on_consumable_used(consumable_id: String) -> void:
	print("[ConsumableUI] Consumable used:", consumable_id)
	emit_signal("consumable_used", consumable_id)
	
func _on_consumable_sell_requested(consumable_id: String) -> void:
	print("[ConsumableUI] Consumable sell requested:", consumable_id)
	emit_signal("consumable_sold", consumable_id)
	
func remove_consumable(consumable_id: String) -> void:
	if _icons.has(consumable_id):
		var icon = _icons[consumable_id]
		if icon:
			icon.queue_free()
		_icons.erase(consumable_id)
		# Update slots label after removing a consumable
		update_slots_label()
		print("[ConsumableUI] Removed consumable icon:", consumable_id)

func update_slots_label() -> void:
	# Update the slots label to show current/max consumables
	var current = _icons.size()
	slots_label.text = "(%d/%d)" % [current, max_consumables]
	
	# Change text color to red when at max capacity
	if current >= max_consumables:
		slots_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		slots_label.remove_theme_color_override("font_color")

func has_max_consumables() -> bool:
	return _icons.size() >= max_consumables

func get_consumable_icon(id: String) -> ConsumableIcon:
	for child in get_children():
		if child is ConsumableIcon and child.data and child.data.id == id:
			return child
	return null