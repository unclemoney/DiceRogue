extends Control
class_name DebuffUI

signal debuff_selected(id: String)

# Set default path directly to fix the instantiation error
@export var debuff_icon_scene: PackedScene = preload("res://Scenes/Debuff/DebuffIcon.tscn")
@export var max_debuffs: int = 5
@onready var container: HBoxContainer

var _icons: Dictionary = {}  # id -> DebuffIcon

func _ready() -> void:
	print("[DebuffUI] Initializing...")
	
	# Try to find or create container
	if has_node("Container"):
		container = $Container
		print("[DebuffUI] Found existing Container")
	else:
		print("[DebuffUI] Creating Container")
		container = HBoxContainer.new()
		container.name = "Container"
		add_child(container)
	
	# Configure container
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.visible = true
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
	
	# Set data after adding to tree
	icon.set_data(data)
	icon.set_meta("last_pos", icon.position)
	
	# Store in dictionary
	_icons[data.id] = icon
	
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
