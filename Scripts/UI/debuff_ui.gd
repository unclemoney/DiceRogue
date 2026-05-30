extends Control
class_name DebuffUI

signal debuff_selected(id: String)

# Set default path directly to fix the instantiation error
@export var debuff_icon_scene: PackedScene = preload("res://Scenes/Debuff/DebuffIcon.tscn")
@export var max_debuffs: int = 5
@onready var container: Container

var _icons: Dictionary = {}  # id -> DebuffIcon

# Fan-out state
enum State { NORMAL, FANNED_OUT }
var _current_state: State = State.NORMAL
var _background: ColorRect
var _fanned_icons: Dictionary = {}
var _icon_positions: Dictionary = {}

func _ready() -> void:
	print("[DebuffUI] Initializing...")
	
	# Defensive cleanup: remove deprecated hardcoded nodes if editor cached an old scene
	for old_name in ["Label", "VBoxContainer"]:
		var old_node = get_node_or_null(old_name)
		if old_node:
			old_node.queue_free()
	
	# Try to find or create container
	if has_node("Container"):
		var existing = $Container
		if existing is GridContainer:
			container = existing
			print("[DebuffUI] Found existing GridContainer")
		else:
			print("[DebuffUI] Replacing existing container with GridContainer")
			existing.queue_free()
			container = null
	if not container:
		container = GridContainer.new()
		container.name = "Container"
		add_child(container)
	
	# Configure container to fill parent
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	if container is GridContainer:
		container.columns = 2
		container.add_theme_constant_override("h_separation", 16)
		container.add_theme_constant_override("v_separation", 16)
	elif container is BoxContainer:
		container.add_theme_constant_override("separation", 40)
	
	# Safety check - load the scene if not set
	if not debuff_icon_scene:
		print("[DebuffUI] debuff_icon_scene not set, attempting to load default")
		debuff_icon_scene = load("res://Scenes/Debuff/debuff_icon.tscn")
		
		if not debuff_icon_scene:
			push_error("[DebuffUI] Failed to load default debuff_icon_scene!")
			print("[DebuffUI] Please check that res://Scenes/Debuff/debuff_icon.tscn exists")
		
	print("[DebuffUI] Initialization complete")
	print("[DebuffUI] debuff_icon_scene is set:", debuff_icon_scene != null)
	
	# Ensure this UI layer receives input for fan-out clicks
	mouse_filter = Control.MOUSE_FILTER_STOP

func _get_fan_overlay() -> CanvasLayer:
	return FanOverlayHelper.get_overlay(self)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _current_state == State.FANNED_OUT:
			_fold_back_debuffs()
			get_viewport().set_input_as_handled()
		elif _current_state == State.NORMAL:
			if not _icons.is_empty():
				_fan_out_debuffs()
				get_viewport().set_input_as_handled()

func _fan_out_debuffs() -> void:
	if _current_state == State.FANNED_OUT:
		return
	_current_state = State.FANNED_OUT
	
	var overlay := _get_fan_overlay()
	var viewport_size := get_viewport_rect().size
	
	# Create background
	_background = FanOverlayHelper.create_background("DebuffFanBackground")
	overlay.add_child(_background)
	_background.visible = true
	_background.gui_input.connect(_on_background_clicked)
	
	_icon_positions.clear()
	_fanned_icons.clear()
	
	var debuff_ids := _icons.keys()
	var count := debuff_ids.size()
	var spacing := 112
	var total_width := count * spacing
	var start_x := (viewport_size.x - total_width) / 2.0 + spacing / 2.0
	var center_y := viewport_size.y / 2.0
	
	for i in range(count):
		var id: String = debuff_ids[i]
		var icon: DebuffIcon = _icons[id]
		if not icon:
			continue
		_icon_positions[id] = icon.position
		_fanned_icons[id] = icon
		if icon.get_parent() != overlay:
			icon.reparent(overlay, false)
		icon.position = Vector2(start_x + i * spacing - icon.size.x / 2.0, center_y - icon.size.y / 2.0)
		icon.z_index = 200 + i

func _fold_back_debuffs() -> void:
	if _current_state == State.NORMAL:
		return
	_current_state = State.NORMAL
	
	for id in _fanned_icons.keys():
		var icon: DebuffIcon = _fanned_icons[id]
		if not is_instance_valid(icon):
			continue
		if icon.get_parent() != container:
			icon.reparent(container, false)
		if _icon_positions.has(id):
			icon.position = _icon_positions[id]
		icon.z_index = 0
	
	_fanned_icons.clear()
	_icon_positions.clear()
	
	if _background:
		_background.queue_free()
		_background = null

func _on_background_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_fold_back_debuffs()

func add_debuff(data: DebuffData, debuff_instance: Debuff = null) -> DebuffIcon:
	print("[DebuffUI] Adding debuff to UI:", data.id if data else "null")
	
	if not debuff_icon_scene:
		push_error("[DebuffUI] debuff_icon_scene not set!")
		return null

	# Check if this debuff is already added
	if _icons.has(data.id):
		print("[DebuffUI] Debuff already exists:", data.id)
		return _icons[data.id]
	
	var icon = debuff_icon_scene.instantiate() as DebuffIcon
	if not icon:
		push_error("[DebuffUI] Failed to instantiate DebuffIcon")
		return null

	# Add icon to container
	container.add_child(icon)
	
	# Force smaller size and disable own input so DebuffUI gets the click
	icon.custom_minimum_size = Vector2(64, 64)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Set data after adding to tree
	icon.set_data(data)
	icon.set_meta("last_pos", icon.position)
	
	# Store in dictionary
	_icons[data.id] = icon
	
	# Juice: debuff acquisition effect
	var tfx = get_node_or_null("/root/TweenFXHelper")
	if tfx:
		tfx.negative_hit(icon)
	# Acquisition sound
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_denied_sound"):
		audio_mgr.play_denied_sound()
	
	# Connect signals
	if debuff_instance:
		debuff_instance.debuff_started.connect(func(): 
			icon.set_active(true)
			print("[DebuffUI] Debuff started:", data.id))
			
		debuff_instance.debuff_ended.connect(func(): 
			icon.set_active(false)
			print("[DebuffUI] Debuff ended:", data.id))
			
	# Connect icon selection signal
	if not icon.is_connected("debuff_selected", _on_debuff_selected):
		icon.debuff_selected.connect(_on_debuff_selected)
	
	print("[DebuffUI] Added debuff icon:", data.id)
	return icon

func _on_debuff_selected(id: String) -> void:
	print("[DebuffUI] Debuff selected:", id)
	emit_signal("debuff_selected", id)

func remove_debuff(id: String) -> void:
	if not _icons.has(id):
		return
		
	var icon = _icons[id]
	if icon:
		# Juice: removal animation
		var tfx = get_node_or_null("/root/TweenFXHelper")
		if tfx:
			tfx.icon_remove(icon)
			await get_tree().create_timer(0.3).timeout
		if is_instance_valid(icon):
			icon.queue_free()
	_icons.erase(id)
	print("[DebuffUI] Removed debuff icon:", id)
	# Animate the remaining cards to their new positions
	await get_tree().process_frame # Wait for layout to update
	animate_debuff_shift()

func get_debuff_icon(id: String) -> DebuffIcon:
	return _icons.get(id)

func animate_debuff_shift() -> void:
	# Animate all DebuffIcons to their new positions after a layout change
	print("[DebuffUI] Animating debuff icons to new positions")
	for child in container.get_children():
		if child is DebuffIcon:
			var icon := child as DebuffIcon
			var target_pos := icon.position
			if not icon.has_meta("last_pos"):
				icon.set_meta("last_pos", target_pos)
			var last_pos: Vector2 = icon.get_meta("last_pos")
			# Move icon to last known position before tweening to new position
			icon.position = last_pos
			# Tween to new position
			var tween := create_tween()
			tween.tween_property(icon, "position", target_pos, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			icon.set_meta("last_pos", target_pos)

func animate_debuff_removal(debuff_id: String, on_finished: Callable) -> void:
	var icon = get_debuff_icon(debuff_id)
	if icon:
		print("[DebuffUI] Animating debuff icon for removal:", debuff_id)
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
		print("[DebuffUI] No icon found for debuff, skipping animation:", debuff_id)
		on_finished.call()
