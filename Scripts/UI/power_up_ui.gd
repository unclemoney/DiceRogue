# PowerUpUI.gd
extends Control
class_name PowerUpUI

signal power_up_selected(power_up_id: String)
signal power_up_deselected(power_up_id: String)
signal power_up_sold(power_up_id: String)
signal max_power_ups_reached

@export var power_up_icon_scene: PackedScene
@export var power_up_spine_scene: PackedScene
@export var max_power_ups: int = 10
@onready var slots_label: Label = $SlotsLabel

# Data storage
var _power_up_data := {}  # power_up_id -> PowerUpData
var _spines := {}  # power_up_id -> PowerUpSpine
var _fanned_icons := {}  # power_up_id -> PowerUpIcon

# State management
enum State { SPINES, FANNED }
var _current_state: State = State.SPINES
var _is_animating: bool = false

# Layout properties
var _spine_shelf_y: float = 263.0  # Y position of spine shelf (275 + small margin)
var _spine_spacing: float = 30.0  # Horizontal spacing between spines
var _fan_center: Vector2  # Center point for fanned cards
var _fan_radius: float = 400.0  # How spread out the fan is (increased for more space)
var _selected_spine_id: String = ""

# Animation and background
var _background: ColorRect
var _idle_tweens: Array[Tween] = []  # Track individual idle animation tweens
var _spine_tooltip: Label

func _ready() -> void:
	print("[PowerUpUI] Initializing new spine-based system...")
	add_to_group("power_up_ui")
	
	# Calculate center position for fanned cards
	_fan_center = get_viewport_rect().size / 2.0
	
	# Load scenes if not set
	if not power_up_icon_scene:
		power_up_icon_scene = load("res://Scenes/PowerUp/power_up_icon.tscn")
		if not power_up_icon_scene:
			push_error("[PowerUpUI] Failed to load power_up_icon scene")
	
	if not power_up_spine_scene:
		power_up_spine_scene = load("res://Scenes/UI/power_up_spine.tscn")
		if not power_up_spine_scene:
			push_error("[PowerUpUI] Failed to load power_up_spine scene")
	
	# Create background
	_create_background()
	
	# Create spine tooltip
	_create_spine_tooltip()
	
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
	
	print("[PowerUpUI] New spine-based system initialized")

func _exit_tree() -> void:
	# Clean up all tracked tweens to prevent warnings
	for tween in _idle_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_idle_tweens.clear()

func _create_background() -> void:
	# Create semi-transparent background for when cards are fanned
	_background = ColorRect.new()
	_background.name = "Background"
	_background.color = Color(0, 0, 0, 0.5)
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	_background.visible = false
	_background.z_index = 5  # Above spines but below fanned cards
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

func add_power_up(data: PowerUpData) -> Node:
	print("[PowerUpUI] Adding power up:", data.id if data else "null")
	
	# Check if we've reached the max number of power ups
	if _power_up_data.size() >= max_power_ups:
		print("[PowerUpUI] Maximum number of power ups reached!")
		emit_signal("max_power_ups_reached")
		return null
	
	if not power_up_spine_scene:
		push_error("[PowerUpUI] power_up_spine_scene not set")
		return null
	
	if not data:
		push_error("[PowerUpUI] Cannot add null power up data")
		return null
	
	# Store the data
	_power_up_data[data.id] = data
	
	# Create spine
	var spine: PowerUpSpine = power_up_spine_scene.instantiate()
	if not spine:
		push_error("[PowerUpUI] Failed to instantiate power up spine")
		return null
	
	print("[PowerUpUI] Created spine, about to add_child")
	# Add spine to UI
	add_child(spine)
	print("[PowerUpUI] Added spine to tree, setting data")
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
	
	print("[PowerUpUI] About to position spines")
	# Position spine on shelf
	_position_spines()
	print("[PowerUpUI] Positioned spines")
	
	# Update slots label
	update_slots_label()
	
	print("[PowerUpUI] Added power up spine:", data.id)
	return spine

func _position_spines() -> void:
	var spine_ids: Array = _spines.keys()
	var spine_count: int = spine_ids.size()
	
	if spine_count == 0:
		return
	
	# Start at fixed position (275) and space out to the right
	var start_x: float = 275.0
	
	# Position each spine
	for i in range(spine_count):
		var spine_id: String = spine_ids[i]
		var spine: PowerUpSpine = _spines[spine_id]
		if spine:
			var pos: Vector2 = Vector2(start_x + i * _spine_spacing, _spine_shelf_y)
			spine.set_base_position(pos)

func _on_spine_clicked(power_up_id: String) -> void:
	print("[PowerUpUI] Spine clicked:", power_up_id)
	
	if _is_animating:
		print("[PowerUpUI] Animation in progress, ignoring click")
		return
	
	if _current_state == State.SPINES:
		_selected_spine_id = power_up_id
		_fan_out_cards()
	elif _current_state == State.FANNED:
		# If clicking the same spine, fold back
		if _selected_spine_id == power_up_id:
			_fold_back_cards()
		else:
			# Switch to new spine
			_selected_spine_id = power_up_id
			_fan_out_cards()

func _fan_out_cards() -> void:
	print("[PowerUpUI] Fanning out cards")
	_is_animating = true
	_current_state = State.FANNED
	
	# Safety check - don't create tweens on invalid nodes
	if not is_inside_tree():
		return
	
	# Show background
	_background.visible = true
	_background.modulate.a = 0.0
	var bg_tween: Tween = create_tween()
	bg_tween.tween_property(_background, "modulate:a", 1.0, 0.3)
	
	# Hide all spines first
	for spine_id in _spines.keys():
		var spine: PowerUpSpine = _spines[spine_id]
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
	
	var power_up_ids: Array = _power_up_data.keys()
	var count: int = power_up_ids.size()
	
	if count == 0:
		return
	
	# Calculate horizontal positions for cards
	var positions: Array[Vector2] = _calculate_fan_positions(count)
	
	# Create and position icons
	for i in range(count):
		var power_up_id: String = power_up_ids[i]
		var data: PowerUpData = _power_up_data[power_up_id]
		var fan_pos: Vector2 = positions[i]
		
		# Create icon
		var icon: PowerUpIcon = power_up_icon_scene.instantiate()
		if not icon:
			continue
		
		add_child(icon)
		icon.set_data(data)
		icon.z_index = 10 + i  # Ensure cards are above background
		
		# Hide CardInfo/Title for cleaner fanned view
		var card_info: VBoxContainer = icon.get_node_or_null("CardInfo")
		if card_info:
			card_info.visible = false
		
		# Connect signals
		if not icon.is_connected("power_up_selected", _on_power_up_selected):
			icon.power_up_selected.connect(_on_power_up_selected)
		if not icon.is_connected("power_up_deselected", _on_power_up_deselected):
			icon.power_up_deselected.connect(_on_power_up_deselected)
		if not icon.is_connected("power_up_sell_requested", _on_power_up_sell_requested):
			icon.power_up_sell_requested.connect(_on_power_up_sell_requested)
		
		# Store reference
		_fanned_icons[power_up_id] = icon
		
		# Position and animate icon
		icon.position = _fan_center 
		icon.modulate.a = 0.0
		icon.scale = Vector2(0.5, 0.5)
		
		print("[PowerUpUI] Card ", i, " (", power_up_id, ") - Start pos: ", icon.position, ", Target pos: ", fan_pos)
		
		# Animate to final position
		var tween: Tween = create_tween().set_parallel()
		tween.tween_property(icon, "position", fan_pos, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.05)
		tween.tween_property(icon, "modulate:a", 1.0, 0.3).set_delay(i * 0.05)
		tween.tween_property(icon, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.05)
		tween.tween_property(icon, "rotation", 0.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.05)
	
	# Wait for all cards to reach their final positions, then start idle animations
	var max_delay: float = (count - 1) * 0.05 + 0.5  # Last card delay + animation duration
	await get_tree().create_timer(max_delay).timeout
	_start_idle_animations()

func _calculate_fan_positions(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	
	# Card dimensions (from PowerUpIcon)
	var card_width: float = 80.0  # PowerUpIcon minimum width
	var spacing: float = 20.0     # Desired spacing between cards
	var card_spacing: float = card_width + spacing  # Total space per card
	
	# Screen center
	var center_x: float = _fan_center.x
	var center_y: float = _fan_center.y
	
	print("[PowerUpUI] Calculating fan positions for ", count, " cards")
	print("[PowerUpUI] Center position: ", _fan_center)
	print("[PowerUpUI] Card width: ", card_width, ", Spacing: ", spacing, ", Total per card: ", card_spacing)
	
	if count == 1:
		# Single card in center
		var pos: Vector2 = Vector2(center_x - card_width / 2.0, center_y)
		positions.append(pos)
		print("[PowerUpUI] Single card position: ", pos)
	elif count == 2:
		# Two cards: left and right of center
		var offset: float = card_spacing / 2.0
		var left_pos: Vector2 = Vector2(center_x - offset - card_width / 2.0, center_y)
		var right_pos: Vector2 = Vector2(center_x + offset - card_width / 2.0, center_y)
		positions.append(left_pos)
		positions.append(right_pos)
		print("[PowerUpUI] Two cards - Left: ", left_pos, ", Right: ", right_pos)
	else:
		# Three or more cards: spread horizontally from center
		var total_width: float = (count - 1) * card_spacing
		var start_x: float = center_x - total_width / 2.0 - card_width / 2.0
		
		for i in range(count):
			var pos_x: float = start_x + i * card_spacing
			var pos: Vector2 = Vector2(pos_x, center_y)
			positions.append(pos)
			print("[PowerUpUI] Card ", i, " position: ", pos)
	
	return positions

func _fold_back_cards() -> void:
	print("[PowerUpUI] Folding back cards")
	_is_animating = true
	_current_state = State.SPINES
	
	# Safety check - don't create tweens on invalid nodes
	if not is_inside_tree():
		return
	
	# Stop idle animations
	_stop_idle_animations()
	
	# Hide background
	var bg_tween: Tween = create_tween()
	bg_tween.tween_property(_background, "modulate:a", 0.0, 0.3)
	bg_tween.tween_callback(func(): _background.visible = false)
	
	# Animate fanned icons away
	for power_up_id in _fanned_icons.keys():
		var icon: PowerUpIcon = _fanned_icons[power_up_id]
		if icon:
			var tween: Tween = create_tween().set_parallel()
			tween.tween_property(icon, "scale", Vector2(0.2, 0.2), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tween.tween_property(icon, "modulate:a", 0.0, 0.2)
			tween.tween_property(icon, "position", _fan_center, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	# Wait, then clear fanned icons and show spines
	await get_tree().create_timer(0.3).timeout
	_clear_fanned_icons()
	
	# Show spines again
	for spine_id in _spines.keys():
		var spine: PowerUpSpine = _spines[spine_id]
		if spine:
			var tween: Tween = create_tween()
			tween.tween_property(spine, "modulate:a", 1.0, 0.2)
	
	_selected_spine_id = ""
	_is_animating = false

func _clear_fanned_icons() -> void:
	# Stop idle animations before freeing icons to prevent warnings
	_stop_idle_animations()
	
	for power_up_id in _fanned_icons.keys():
		var icon: PowerUpIcon = _fanned_icons[power_up_id]
		if icon:
			icon.queue_free()
	_fanned_icons.clear()

func _on_background_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _current_state == State.FANNED and not _is_animating:
			_fold_back_cards()

func _start_idle_animations() -> void:
	_stop_idle_animations()
	
	if _current_state != State.FANNED:
		print("[PowerUpUI] Skipping idle animations - not in FANNED state (current: ", _current_state, ")")
		return
	
	# Get the calculated fan positions (not the current positions)
	var power_up_ids: Array = _power_up_data.keys()
	var count: int = power_up_ids.size()
	
	if count == 0:
		print("[PowerUpUI] No power-ups to animate")
		return
		
	var fan_positions: Array[Vector2] = _calculate_fan_positions(count)
	
	print("[PowerUpUI] Starting idle animations for ", count, " power-ups")
	
	# Create gentle wave motion for fanned cards using their proper fan positions
	var created_tweens := 0
	for i in range(count):
		var power_up_id: String = power_up_ids[i]
		var icon: PowerUpIcon = _fanned_icons.get(power_up_id)
		if not icon or i >= fan_positions.size():
			print("[PowerUpUI] Skipping animation for ", power_up_id, " - no icon or invalid position")
			continue
		
		# Verify icon is still valid and in tree
		if not is_instance_valid(icon) or not icon.is_inside_tree():
			print("[PowerUpUI] Skipping animation for ", power_up_id, " - icon not valid or not in tree")
			continue
			
		var base_pos: Vector2 = fan_positions[i]  # Use calculated fan position, not current position
		var wave_offset: Vector2 = Vector2(randf_range(-5, 5), randf_range(-8, 8))
		var duration: float = randf_range(2.0, 4.0)
		
		print("[PowerUpUI] Idle animation - Card ", i, " (", power_up_id, ") - Base pos: ", base_pos, ", Final idle pos: ", base_pos + wave_offset)
		
		var icon_tween: Tween = create_tween()
		icon_tween.set_loops(1000)  # Large finite number instead of infinite
		icon_tween.tween_property(icon, "position", base_pos + wave_offset, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		icon_tween.tween_property(icon, "position", base_pos - wave_offset, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
		# Track this tween for proper cleanup
		_idle_tweens.append(icon_tween)
		created_tweens += 1
	
	print("[PowerUpUI] Created ", created_tweens, " idle animation tweens")

func _stop_idle_animations() -> void:
	for tween in _idle_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_idle_tweens.clear()

func _on_spine_hovered(_power_up_id: String, mouse_pos: Vector2) -> void:
	if _current_state != State.SPINES:
		return
	
	# Create list of all power-up names
	var power_up_names: Array[String] = []
	for id in _power_up_data.keys():
		var data: PowerUpData = _power_up_data[id]
		if data:
			power_up_names.append(data.display_name)
	
	if power_up_names.size() > 0:
		_spine_tooltip.text = "Videos:\n" + "\n".join(power_up_names)
		# Adjust position: move up 50 pixels on x-axis (left) and center vertically on tooltip height
		await get_tree().process_frame  # Wait for tooltip to calculate its size
		_spine_tooltip.position = mouse_pos + Vector2(-50, -_spine_tooltip.size.y * 2)
		_spine_tooltip.visible = true

func _on_spine_unhovered(_power_up_id: String) -> void:
	_spine_tooltip.visible = false
	
func _on_power_up_sell_requested(power_up_id: String) -> void:
	print("[PowerUpUI] Power-up sell requested:", power_up_id)
	emit_signal("power_up_sold", power_up_id)

func remove_power_up(power_up_id: String) -> void:
	print("[PowerUpUI] Removing power-up:", power_up_id)
	
	# Remove from data
	if _power_up_data.has(power_up_id):
		_power_up_data.erase(power_up_id)
	
	# Remove spine if exists
	if _spines.has(power_up_id):
		var spine: PowerUpSpine = _spines[power_up_id]
		if spine:
			spine.queue_free()
		_spines.erase(power_up_id)
		
		# Reposition remaining spines
		await get_tree().process_frame
		_position_spines()
	
	# Remove fanned icon if exists
	if _fanned_icons.has(power_up_id):
		var icon: PowerUpIcon = _fanned_icons[power_up_id]
		if icon:
			icon.queue_free()
		_fanned_icons.erase(power_up_id)
		
		# If we're in fanned state, recreate the fan layout
		if _current_state == State.FANNED:
			await get_tree().process_frame
			_clear_fanned_icons()
			_create_fanned_icons()
	
	update_slots_label()
	print("[PowerUpUI] Removed power-up:", power_up_id)

func update_slots_label() -> void:
	# Update the slots label to show current/max power-ups
	var current: int = _power_up_data.size()
	slots_label.text = "(%d/%d)" % [current, max_power_ups]
	
	# Change text color to red when at max capacity
	if current >= max_power_ups:
		slots_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		slots_label.remove_theme_color_override("font_color")

func has_max_power_ups() -> bool:
	return _power_up_data.size() >= max_power_ups

func has_power_up(power_up_id: String) -> bool:
	return _power_up_data.has(power_up_id)

func get_owned_power_up_ids() -> Array[String]:
	var result: Array[String] = []
	for id in _power_up_data.keys():
		result.append(id)
	return result

func get_power_up_icon(id: String) -> PowerUpIcon:
	# Return fanned icon if it exists and we're in fanned state
	if _current_state == State.FANNED and _fanned_icons.has(id):
		return _fanned_icons[id]
	return null

func animate_power_up_removal(power_up_id: String, on_finished: Callable) -> void:
	# Check if we have a spine to animate
	if _spines.has(power_up_id):
		var spine: PowerUpSpine = _spines[power_up_id]
		if spine:
			print("[PowerUpUI] Animating spine removal for:", power_up_id)
			var tween: Tween = create_tween()
			tween.tween_property(spine, "scale", Vector2(1.2, 0.2), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(spine, "scale", Vector2(0.8, 1.6), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(spine, "position", spine.position + Vector2(0, -100), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tween.parallel().tween_property(spine, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_LINEAR)
			tween.finished.connect(on_finished)
			return
	
	# Check if we have a fanned icon to animate
	if _fanned_icons.has(power_up_id):
		var icon: PowerUpIcon = _fanned_icons[power_up_id]
		if icon:
			print("[PowerUpUI] Animating fanned icon removal for:", power_up_id)
			var tween: Tween = create_tween()
			tween.tween_property(icon, "scale", Vector2(1.2, 0.2), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(icon, "scale", Vector2(0.8, 1.6), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(icon, "position", icon.position + Vector2(0, -200), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tween.parallel().tween_property(icon, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_LINEAR)
			tween.finished.connect(on_finished)
			return
	
	# No animation needed, call callback immediately
	print("[PowerUpUI] No visual element found for power-up, skipping animation:", power_up_id)
	on_finished.call()

func _on_power_up_selected(power_up_id: String) -> void:
	print("[PowerUpUI] Power-up selected:", power_up_id)
	emit_signal("power_up_selected", power_up_id)
	
	# Deselect other icons in fanned state
	if _current_state == State.FANNED:
		for id in _fanned_icons:
			if id != power_up_id and _fanned_icons[id]:
				_fanned_icons[id].deselect()

func _on_power_up_deselected(power_up_id: String) -> void:
	print("[PowerUpUI] Power-up deselected:", power_up_id)
	emit_signal("power_up_deselected", power_up_id)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Handle clicks when cards are fanned - check if we need to fold back
		if _current_state == State.FANNED and not _is_animating:
			var clicked_on_card: bool = false
			
			# Check if we clicked on any fanned card
			for power_up_id in _fanned_icons.keys():
				var card: PowerUpIcon = _fanned_icons[power_up_id]
				if card and card.get_global_rect().has_point(event.global_position):
					clicked_on_card = true
					break
			
			# If we didn't click on a card, fold back
			if not clicked_on_card:
				_fold_back_cards()
				get_viewport().set_input_as_handled()
