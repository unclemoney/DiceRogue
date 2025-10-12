extends Control
class_name ConsumableUI

signal consumable_used(consumable_id: String)
signal consumable_sold(consumable_id: String) 
signal max_consumables_reached

@export var consumable_icon_scene: PackedScene
@export var consumable_spine_scene: PackedScene
@export var max_consumables: int = 2
@onready var container: HBoxContainer
@onready var slots_label: Label = $SlotsLabel

# Data storage
var _consumable_data := {}  # consumable_id -> ConsumableData
var _spines := {}  # consumable_id -> ConsumableSpine
var _fanned_icons := {}  # consumable_id -> ConsumableIcon

# State management
enum State { SPINES, FANNED }
var _current_state: State = State.SPINES
var _is_animating: bool = false

# Layout properties
var _spine_shelf_y: float = 263.0  # Y position of spine shelf
var _spine_spacing: float = 30.0  # Horizontal spacing between spines
var _fan_center: Vector2  # Center point for fanned cards
var _fan_radius: float = 400.0  # How spread out the fan is
var _selected_spine_id: String = ""

# Animation and background
var _background: ColorRect
var _idle_tweens: Array[Tween] = []  # Track individual idle animation tweens
var _spine_tooltip: Label

# Safe consumable tracking
var _active_consumable_count: int = 0

func _ready() -> void:
	print("[ConsumableUI] Initializing new spine-based system...")
	add_to_group("consumable_ui")
	
	# Calculate center position for fanned cards
	_fan_center = get_viewport_rect().size / 2.0
	
	# Load scenes if not set
	if not consumable_icon_scene:
		consumable_icon_scene = load("res://Scenes/Consumable/consumable_icon.tscn")
		if not consumable_icon_scene:
			push_error("[ConsumableUI] Failed to load consumable_icon scene")
	
	if not consumable_spine_scene:
		consumable_spine_scene = load("res://Scenes/UI/consumable_spine.tscn")
		if not consumable_spine_scene:
			push_error("[ConsumableUI] Failed to load consumable_spine scene")
	
	# Create background
	_create_background()
	
	# Create spine tooltip
	_create_spine_tooltip()
	
	# Keep existing container for backward compatibility but hide it initially
	if has_node("VBoxContainer/Container"):
		container = $VBoxContainer/Container
		print("[ConsumableUI] Found Container under VBoxContainer")
		container.visible = false  # Hidden by default in spine mode
	else:
		# Fallback: create Container if not found
		container = HBoxContainer.new()
		container.name = "Container"
		container.mouse_filter = Control.MOUSE_FILTER_PASS
		container.set_anchors_preset(Control.PRESET_TOP_WIDE)
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_theme_constant_override("separation", 40)
		container.visible = false
		add_child(container)
	
	# Set up slots label
	if not has_node("SlotsLabel"):
		slots_label = Label.new()
		slots_label.name = "SlotsLabel"
		slots_label.position = Vector2(135, -28)
		add_child(slots_label)
	else:
		slots_label = $SlotsLabel
	
	# Initialize slots label
	update_slots_label()
	
	print("[ConsumableUI] New spine-based system initialized")

func _create_background() -> void:
	# Create semi-transparent background for when cards are fanned
	print("[ConsumableUI] Creating background for fanned cards")
	_background = ColorRect.new()
	_background.name = "Background"
	_background.color = Color(0, 0, 0, 0.5)
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	_background.visible = false  # Start hidden
	_background.z_index = 5
	add_child(_background)
	
	# Connect background click to fold cards back
	_background.gui_input.connect(_on_background_clicked)

func _create_spine_tooltip() -> void:
	# Create tooltip for spine hover
	_spine_tooltip = Label.new()
	_spine_tooltip.name = "SpineTooltip"
	_spine_tooltip.visible = false
	_spine_tooltip.z_index = 20
	_spine_tooltip.add_theme_color_override("font_color", Color.WHITE)
	_spine_tooltip.add_theme_color_override("font_shadow_color", Color.BLACK)
	_spine_tooltip.add_theme_font_size_override("font_size", 14)
	_spine_tooltip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spine_tooltip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_spine_tooltip.custom_minimum_size = Vector2(200, 0)
	
	# Add semi-transparent background
	var tooltip_background: StyleBoxFlat = StyleBoxFlat.new()
	tooltip_background.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Semi-transparent grey
	tooltip_background.corner_radius_top_left = 4
	tooltip_background.corner_radius_top_right = 4
	tooltip_background.corner_radius_bottom_left = 4
	tooltip_background.corner_radius_bottom_right = 4
	tooltip_background.content_margin_left = 8
	tooltip_background.content_margin_right = 8
	tooltip_background.content_margin_top = 4
	tooltip_background.content_margin_bottom = 4
	_spine_tooltip.add_theme_stylebox_override("normal", tooltip_background)
	
	add_child(_spine_tooltip)

func add_consumable(data: ConsumableData) -> Node:
	print("[ConsumableUI] Adding consumable:", data.id if data else "null")
	
	# Check if we've reached the max number of consumables
	if _consumable_data.size() >= max_consumables:
		print("[ConsumableUI] Maximum number of consumables reached!")
		emit_signal("max_consumables_reached")
		return null
		
	if not consumable_spine_scene:
		push_error("[ConsumableUI] consumable_spine_scene not set")
		return null
		
	if not data:
		push_error("[ConsumableUI] Cannot add null consumable data")
		return null
	
	# Store the data
	_consumable_data[data.id] = data
	_active_consumable_count += 1
	
	# Create spine
	var spine: ConsumableSpine = consumable_spine_scene.instantiate()
	if not spine:
		push_error("[ConsumableUI] Failed to instantiate consumable spine")
		return null
	
	# Add spine to UI
	add_child(spine)
	spine.set_data(data)
	
	# Connect spine signals
	if not spine.is_connected("spine_clicked", _on_spine_clicked):
		spine.spine_clicked.connect(_on_spine_clicked)
	if not spine.is_connected("spine_hovered", _on_spine_hovered):
		spine.spine_hovered.connect(_on_spine_hovered)
	if not spine.is_connected("spine_unhovered", _on_spine_unhovered):
		spine.spine_unhovered.connect(_on_spine_unhovered)
	
	# Store spine reference
	_spines[data.id] = spine
	
	# Position spine on shelf
	_position_spines()
	
	# Update slots label
	update_slots_label()
	
	print("[ConsumableUI] Added consumable spine:", data.id)
	return spine

func _position_spines() -> void:
	var spine_ids: Array = _spines.keys()
	var spine_count: int = spine_ids.size()
	
	if spine_count == 0:
		return
	
	# Start at fixed position and space out to the right
	var start_x: float = 65.0
	
	# Position each spine
	for i in range(spine_count):
		var spine_id: String = spine_ids[i]
		var spine: ConsumableSpine = _spines[spine_id]
		if spine:
			var pos: Vector2 = Vector2(start_x + i * _spine_spacing, _spine_shelf_y)
			spine.set_base_position(pos)

func _on_spine_clicked(consumable_id: String) -> void:
	print("[ConsumableUI] Spine clicked:", consumable_id)
	
	if _is_animating:
		print("[ConsumableUI] Animation in progress, ignoring click")
		return
	
	if _current_state == State.SPINES:
		_selected_spine_id = consumable_id
		_fan_out_cards()
	elif _current_state == State.FANNED:
		# If clicking the same spine, fold back
		if _selected_spine_id == consumable_id:
			_fold_back_cards()
		else:
			# Switch to new spine
			_selected_spine_id = consumable_id
			_fan_out_cards()

func _fan_out_cards() -> void:
	print("[ConsumableUI] Fanning out cards")
	_is_animating = true
	_current_state = State.FANNED
	
	# Show background
	_background.visible = true
	_background.modulate.a = 0.0
	var bg_tween: Tween = create_tween()
	bg_tween.tween_property(_background, "modulate:a", 1.0, 0.3)
	
	# Hide all spines first
	for spine_id in _spines.keys():
		var spine: ConsumableSpine = _spines[spine_id]
		if spine:
			var tween: Tween = create_tween()
			tween.tween_property(spine, "modulate:a", 0.0, 0.2)
	
	# Wait a bit, then create and show fanned icons
	await get_tree().create_timer(0.2).timeout
	_create_fanned_icons()
	
	_is_animating = false

func _create_fanned_icons() -> void:
	# Clear existing fanned icons
	_clear_fanned_icons()
	
	var consumable_ids: Array = _consumable_data.keys()
	var count: int = consumable_ids.size()
	
	if count == 0:
		return
	
	# Calculate horizontal positions for cards
	var positions: Array[Vector2] = _calculate_fan_positions(count)
	
	# Create and position icons
	for i in range(count):
		var consumable_id: String = consumable_ids[i]
		var data: ConsumableData = _consumable_data[consumable_id]
		var fan_pos: Vector2 = positions[i]
		
		# Create icon
		var icon: ConsumableIcon = consumable_icon_scene.instantiate()
		if not icon:
			continue
		
		add_child(icon)
		icon.set_data(data)
		icon.z_index = 10 + i  # Ensure cards are above background
		
		# Hide CardInfo/Title for cleaner fanned view
		var card_info: VBoxContainer = icon.get_node_or_null("CardInfo")
		if card_info:
			card_info.visible = false
		
		# Connect signals - NOTE: These are different from PowerUp signals!
		if not icon.is_connected("consumable_used", _on_consumable_used):
			icon.consumable_used.connect(_on_consumable_used)
		if not icon.is_connected("consumable_sell_requested", _on_consumable_sell_requested):
			icon.consumable_sell_requested.connect(_on_consumable_sell_requested)
		
		# Store reference
		_fanned_icons[consumable_id] = icon
		
		# Position and animate icon
		icon.position = _fan_center 
		icon.modulate.a = 0.0
		icon.scale = Vector2(0.5, 0.5)
		
		print("[ConsumableUI] Card ", i, " (", consumable_id, ") - Start pos: ", icon.position, ", Target pos: ", fan_pos)
		
		# Animate to final position
		var tween: Tween = create_tween().set_parallel()
		tween.tween_property(icon, "position", fan_pos, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.05)
		tween.tween_property(icon, "modulate:a", 1.0, 0.3).set_delay(i * 0.05)
		tween.tween_property(icon, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.05)
	
	# Start idle animations after a delay
	await get_tree().create_timer(0.6).timeout
	_start_idle_animations()
	
	# Update consumable usability for all fanned icons
	update_consumable_usability()

func _calculate_fan_positions(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	
	if count == 0:
		return positions
	
	# Card dimensions (assuming standard card size)
	var card_width: float = 80.0  # ConsumableIcon width
	var spacing: float = 20.0  # Space between cards
	var card_spacing: float = card_width + spacing  # Total space per card
	
	# Screen center
	var center_x: float = _fan_center.x
	var center_y: float = _fan_center.y
	
	print("[ConsumableUI] Calculating fan positions for ", count, " cards")
	print("[ConsumableUI] Center position: ", _fan_center)
	print("[ConsumableUI] Card width: ", card_width, ", Spacing: ", spacing, ", Total per card: ", card_spacing)
	
	if count == 1:
		# Single card in center
		var pos: Vector2 = Vector2(center_x - card_width / 2.0, center_y)
		positions.append(pos)
		print("[ConsumableUI] Single card position: ", pos)
	elif count == 2:
		# Two cards: left and right of center
		var offset: float = card_spacing / 2.0
		var left_pos: Vector2 = Vector2(center_x - offset - card_width / 2.0, center_y)
		var right_pos: Vector2 = Vector2(center_x + offset - card_width / 2.0, center_y)
		positions.append(left_pos)
		positions.append(right_pos)
		print("[ConsumableUI] Two cards - Left: ", left_pos, ", Right: ", right_pos)
	else:
		# Three or more cards: spread horizontally from center
		var total_width: float = (count - 1) * card_spacing
		var start_x: float = center_x - total_width / 2.0 - card_width / 2.0
		
		for i in range(count):
			var pos_x: float = start_x + i * card_spacing
			var pos: Vector2 = Vector2(pos_x, center_y)
			positions.append(pos)
			print("[ConsumableUI] Card ", i, " position: ", pos)
	
	return positions

func _fold_back_cards() -> void:
	print("[ConsumableUI] Folding back cards")
	_is_animating = true
	_current_state = State.SPINES
	
	# Stop idle animations
	_stop_idle_animations()
	
	# Hide background
	var bg_tween: Tween = create_tween()
	bg_tween.tween_property(_background, "modulate:a", 0.0, 0.3)
	bg_tween.tween_callback(func(): _background.visible = false)
	
	# Animate fanned icons away
	for consumable_id in _fanned_icons.keys():
		var icon: ConsumableIcon = _fanned_icons[consumable_id]
		if icon and is_instance_valid(icon):
			var tween: Tween = create_tween().set_parallel()
			tween.tween_property(icon, "scale", Vector2(0.2, 0.2), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tween.tween_property(icon, "modulate:a", 0.0, 0.2)
			tween.tween_property(icon, "position", _fan_center, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	# Wait, then clear fanned icons and show spines
	await get_tree().create_timer(0.3).timeout
	_clear_fanned_icons()
	
	# Show spines again
	for spine_id in _spines.keys():
		var spine: ConsumableSpine = _spines[spine_id]
		if spine and is_instance_valid(spine):
			var tween: Tween = create_tween()
			tween.tween_property(spine, "modulate:a", 1.0, 0.2)
	
	_selected_spine_id = ""
	_is_animating = false

func _clear_fanned_icons() -> void:
	# Stop idle animations before freeing icons to prevent warnings
	_stop_idle_animations()
	
	for consumable_id in _fanned_icons.keys():
		var icon: ConsumableIcon = _fanned_icons[consumable_id]
		if icon and is_instance_valid(icon):
			icon.queue_free()
	_fanned_icons.clear()

func _on_background_clicked(event: InputEvent) -> void:
	print("[DEBUG] Background clicked: ", event)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _current_state == State.FANNED and not _is_animating:
			_fold_back_cards()

func _start_idle_animations() -> void:
	_stop_idle_animations()
	
	if _current_state != State.FANNED:
		return
	
	# Get the calculated fan positions (not the current positions)
	var consumable_ids: Array = _consumable_data.keys()
	var count: int = consumable_ids.size()
	var fan_positions: Array[Vector2] = _calculate_fan_positions(count)
	
	# Create gentle wave motion for fanned cards using their proper fan positions
	for i in range(count):
		var consumable_id: String = consumable_ids[i]
		var icon: ConsumableIcon = _fanned_icons.get(consumable_id)
		if not icon or i >= fan_positions.size() or not is_instance_valid(icon):
			continue
			
		var base_pos: Vector2 = fan_positions[i]
		var wave_offset: Vector2 = Vector2(randf_range(-5, 5), randf_range(-8, 8))
		var duration: float = randf_range(2.0, 4.0)
		
		var icon_tween: Tween = create_tween()
		icon_tween.set_loops()  # Default infinite loops (no argument)
		icon_tween.tween_property(icon, "position", base_pos + wave_offset, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		icon_tween.tween_property(icon, "position", base_pos - wave_offset, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
		# Track this tween for proper cleanup
		_idle_tweens.append(icon_tween)

func _on_consumable_used(consumable_id: String) -> void:
	print("[ConsumableUI] Consumable used:", consumable_id)
	
	# Safe removal with count tracking
	if _has_consumables() and _consumable_data.has(consumable_id):
		# Call remove_consumable to handle all cleanup
		remove_consumable(consumable_id)
		
		# Re-emit signal for game controller to handle
		emit_signal("consumable_used", consumable_id)
	else:
		print("[ConsumableUI] WARNING: Tried to use non-existent consumable:", consumable_id)

func _on_spine_hovered(consumable_id: String, mouse_pos: Vector2) -> void:
	print("[ConsumableUI] Spine hovered:", consumable_id)
	
	if not _spine_tooltip or not _consumable_data.has(consumable_id):
		return
	
	var data: ConsumableData = _consumable_data[consumable_id]
	
	# Create tooltip text showing all consumable names
	var tooltip_text: String = ""
	for id in _consumable_data.keys():
		var consumable_data: ConsumableData = _consumable_data[id]
		if tooltip_text != "":
			tooltip_text += "\n"
		tooltip_text += consumable_data.display_name
	
	_spine_tooltip.text = "Coupons:\n" + tooltip_text
	_spine_tooltip.position = mouse_pos + Vector2(-50, -_spine_tooltip.size.y * 2)
	_spine_tooltip.visible = true

func _on_spine_unhovered(consumable_id: String) -> void:
	print("[ConsumableUI] Spine unhovered:", consumable_id)
	
	if _spine_tooltip:
		_spine_tooltip.visible = false

func _on_consumable_sell_requested(consumable_id: String) -> void:
	print("[ConsumableUI] Consumable sell requested:", consumable_id)
	
	if _has_consumables() and _consumable_data.has(consumable_id):
		remove_consumable(consumable_id)
		emit_signal("consumable_sold", consumable_id)

func update_consumable_usability() -> void:
	print("[ConsumableUI] Updating consumable usability for fanned icons")
	
	# Only update usability when cards are fanned out
	if _current_state != State.FANNED:
		return
	
	# Apply usability logic to fanned icons
	for consumable_id in _fanned_icons.keys():
		var icon: ConsumableIcon = _fanned_icons.get(consumable_id)
		var data: ConsumableData = _consumable_data.get(consumable_id)
		
		if not icon or not data or not is_instance_valid(icon):
			continue
		
		# Check if consumable can be used based on game state
		var is_useable: bool = _can_use_consumable(data)
		
		# Apply usability to icon (assuming ConsumableIcon has set_useable method)
		if icon.has_method("set_useable"):
			icon.set_useable(is_useable)

func _can_use_consumable(data: ConsumableData) -> bool:
	# Default implementation - can be overridden with specific game logic
	# For now, assume all consumables are useable when fanned
	return true

func _stop_idle_animations() -> void:
	for tween in _idle_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_idle_tweens.clear()

func _has_consumables() -> bool:
	return _active_consumable_count > 0

func remove_consumable(consumable_id: String) -> void:
	print("[ConsumableUI] Removing consumable:", consumable_id)
	
	if not _consumable_data.has(consumable_id):
		print("[ConsumableUI] WARNING: Tried to remove non-existent consumable:", consumable_id)
		return
	
	# Update count first
	_active_consumable_count -= 1
	
	# Remove from data storage
	_consumable_data.erase(consumable_id)
	
	# Remove spine if it exists
	if _spines.has(consumable_id):
		var spine: ConsumableSpine = _spines[consumable_id]
		if spine and is_instance_valid(spine):
			spine.queue_free()
		_spines.erase(consumable_id)
	
	# Remove fanned icon if it exists
	if _fanned_icons.has(consumable_id):
		var icon: ConsumableIcon = _fanned_icons[consumable_id]
		if icon and is_instance_valid(icon):
			icon.queue_free()
		_fanned_icons.erase(consumable_id)
	
	# Reposition remaining spines
	_position_spines()
	
	# Update slots label
	update_slots_label()
	
	# Handle empty state
	if _active_consumable_count <= 0:
		_cleanup_empty_state()

func _cleanup_empty_state() -> void:
	print("[ConsumableUI] Cleaning up empty state")
	
	# Ensure we're in spine state when empty
	if _current_state == State.FANNED:
		_fold_back_cards()
	
	# Clear all references
	_spines.clear()
	_fanned_icons.clear()
	_consumable_data.clear()
	_active_consumable_count = 0
	_selected_spine_id = ""

func update_slots_label() -> void:
	# Update the slots label to show current/max consumables
	var current: int = _active_consumable_count  # Fixed: use _active_consumable_count instead of _icons
	slots_label.text = "(%d/%d)" % [current, max_consumables]
	
	# Change text color to red when at max capacity
	if current >= max_consumables:
		slots_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		slots_label.remove_theme_color_override("font_color")

func has_max_consumables() -> bool:
	"""Check if the maximum number of consumables has been reached"""
	return _active_consumable_count >= max_consumables

# Legacy compatibility methods - replace old icon access patterns
func get_consumable_spine(consumable_id: String) -> ConsumableSpine:
	"""Get the spine for a specific consumable (new spine system)"""
	if _spines.has(consumable_id):
		var spine: ConsumableSpine = _spines[consumable_id]
		if spine and is_instance_valid(spine):
			return spine
	return null

func get_fanned_icon(consumable_id: String) -> ConsumableIcon:
	"""Get the fanned icon for a specific consumable (only when fanned out)"""
	if _current_state == State.FANNED and _fanned_icons.has(consumable_id):
		var icon: ConsumableIcon = _fanned_icons[consumable_id]
		if icon and is_instance_valid(icon):
			return icon
	return null

func has_consumable(consumable_id: String) -> bool:
	"""Check if a consumable exists in the UI"""
	return _consumable_data.has(consumable_id)

func get_consumable_data(consumable_id: String) -> ConsumableData:
	"""Get the data for a specific consumable"""
	return _consumable_data.get(consumable_id)

func get_all_consumable_ids() -> Array[String]:
	"""Get all consumable IDs currently in the UI"""
	var ids: Array[String] = []
	for id in _consumable_data.keys():
		ids.append(id)
	return ids

func animate_consumable_removal(consumable_id: String, on_finished: Callable) -> void:
	# Check if we have a spine to animate
	if _spines.has(consumable_id):
		var spine: ConsumableSpine = _spines[consumable_id]
		if spine and is_instance_valid(spine):
			print("[ConsumableUI] Animating spine removal for:", consumable_id)
			var tween: Tween = create_tween()
			tween.tween_property(spine, "scale", Vector2(1.2, 0.2), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(spine, "scale", Vector2(0.8, 1.6), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(spine, "position", spine.position + Vector2(0, -100), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tween.parallel().tween_property(spine, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_LINEAR)
			tween.finished.connect(on_finished)
			return
	
	# Check if we have a fanned icon to animate
	if _fanned_icons.has(consumable_id):
		var icon: ConsumableIcon = _fanned_icons[consumable_id]
		if icon and is_instance_valid(icon):
			print("[ConsumableUI] Animating fanned icon removal for:", consumable_id)
			var tween: Tween = create_tween()
			tween.tween_property(icon, "scale", Vector2(1.2, 0.2), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(icon, "scale", Vector2(0.8, 1.6), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(icon, "position", icon.position + Vector2(0, -200), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tween.parallel().tween_property(icon, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_LINEAR)
			tween.finished.connect(on_finished)
			return
	
	# No animation needed, call callback immediately
	print("[ConsumableUI] No visual element found for consumable, skipping animation:", consumable_id)
	on_finished.call()

# Deprecated method for backward compatibility - logs warning and returns null
func get_consumable_icon(consumable_id: String):
	push_warning("[ConsumableUI] get_consumable_icon() is deprecated. Use get_consumable_spine() or get_fanned_icon() instead.")
	print("[ConsumableUI] DEPRECATED: get_consumable_icon called for ID: ", consumable_id)
	print("[ConsumableUI] Current state: ", _current_state)
	print("[ConsumableUI] Available methods: get_consumable_spine(), get_fanned_icon(), has_consumable(), get_consumable_data()")
	
	# For temporary compatibility, return fanned icon if available
	if _current_state == State.FANNED:
		return get_fanned_icon(consumable_id)
	
	return null
