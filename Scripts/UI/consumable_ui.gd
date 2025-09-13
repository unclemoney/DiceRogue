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
	print("[ConsumableUI] Children:", get_children())
	print("[ConsumableUI] consumable_icon_scene set:", consumable_icon_scene != null)

	if has_node("VBoxContainer/Container"):
		container = $VBoxContainer/Container
		print("[PowerUpUI] Found Container under VBoxContainer")
		
		# Apply correct container settings for proper layout
		container.mouse_filter = Control.MOUSE_FILTER_PASS
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.visible = true
		container.anchor_right = 1.0
		container.anchor_bottom = 0.0
		container.offset_top = 0
		container.offset_bottom = 64
		container.add_theme_constant_override("separation", 40)
		print("[ConsumableUI] Reconfigured existing Container")
	else:
		# Fallback: create Container at root if not found
		print("[ConsumableUI] Creating Container")
		container = HBoxContainer.new()
		container.name = "Container"
		container.mouse_filter = Control.MOUSE_FILTER_PASS
		container.set_anchors_preset(Control.PRESET_TOP_WIDE)
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_theme_constant_override("separation", 40)
		add_child(container)
	
	# Set up the slots label if it doesn't exist
	if not has_node("SlotsLabel"):
		slots_label = Label.new()
		slots_label.name = "SlotsLabel"
		slots_label.position = Vector2(135, -28)  # Position next to "CONSUMABLES" label
		add_child(slots_label)
	else:
		slots_label = $SlotsLabel
		
	# Load the consumable_icon scene if not set
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
	# Debug container properties
	print("[ConsumableUI] Container visible:", container.visible)
	print("[ConsumableUI] Container rect size:", container.size)
	print("[ConsumableUI] Container global position:", container.global_position)

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
		container = HBoxContainer.new()
		container.name = "Container"
		add_child(container)
		
	var icon = consumable_icon_scene.instantiate()
	if not icon:
		push_error("[ConsumableUI] Failed to instantiate consumable icon")
		return null
		
	# Add icon to container
	container.add_child(icon)
	
	# Debug node structure
	print("[ConsumableUI] Icon child count:", icon.get_child_count())
	for child in icon.get_children():
		print("[ConsumableUI] Child node:", child.name)
	
	# Set data after adding to tree
	icon.set_data(data)
	icon.set_meta("last_pos", icon.position)
	
	# Connect signals
	if not icon.is_connected("consumable_used", _on_consumable_used):
		icon.consumable_used.connect(_on_consumable_used)
	if not icon.is_connected("consumable_sell_requested", _on_consumable_sell_requested):
		icon.consumable_sell_requested.connect(_on_consumable_sell_requested)
	
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
		# Animate the remaining cards to their new positions
		await get_tree().process_frame # Wait for layout to update
		animate_consumable_shift()

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
	if container:
		for child in container.get_children():
			if child is ConsumableIcon and child.data and child.data.id == id:
				return child
	return null

func animate_consumable_removal(consumable_id: String, on_finished: Callable) -> void:
	var icon = get_consumable_icon(consumable_id)
	if icon:
		print("[ConsumableUI] Animating consumable icon for removal:", consumable_id)
		var tween := create_tween()
		# 1. Squish down
		tween.tween_property(icon, "scale", Vector2(1.2, 0.2), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# 2. Stretch up
		tween.tween_property(icon, "scale", Vector2(0.8, 1.6), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# 3. Move up and fade out
		var start_pos = icon.position
		var end_pos = start_pos + Vector2(0, -icon.size.y * 8)
		tween.tween_property(icon, "position", end_pos, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(icon, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_LINEAR)
		# 4. When finished, call the provided callback
		tween.finished.connect(on_finished)
	else:
		print("[ConsumableUI] No icon found for consumable, skipping animation:", consumable_id)
		on_finished.call()

func animate_consumable_shift() -> void:
	# Animate all ConsumableIcons to their new positions after a layout change
	print("[ConsumableUI] Animating consumable icons to new positions")
	for child in container.get_children():
		if child is ConsumableIcon:
			var icon := child as ConsumableIcon
			var target_pos := icon.position
			if not icon.has_meta("last_pos"):
				icon.set_meta("last_pos", target_pos)
			var last_pos: Vector2 = icon.get_meta("last_pos")
			# Move icon to last known position before tweening to new position
			icon.position = last_pos
			# Tween to new position
			print("[ConsumableUI] Tweening icon", icon.data.id if icon.data else "unknown", "from", last_pos, "to", target_pos)
			var tween := create_tween()
			tween.tween_property(icon, "position", target_pos, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			icon.set_meta("last_pos", target_pos)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Check if we clicked outside any card that has sell mode active
		var any_card_handled = false
		for id in _icons:
			var card = _icons[id]
			if card and card.check_outside_click(event.global_position):
				any_card_handled = true
		
		# If any card handled the click, mark it as handled
		if any_card_handled:
			get_viewport().set_input_as_handled()
