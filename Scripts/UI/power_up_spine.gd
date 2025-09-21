# PowerUpSpine.gd
extends Control
class_name PowerUpSpine

signal spine_clicked(power_up_id: String)
signal spine_hovered(power_up_id: String, mouse_pos: Vector2)
signal spine_unhovered(power_up_id: String)

@export var data: PowerUpData
@export var spine_texture: Texture2D

@onready var spine_rect: TextureRect
@onready var title_label: Label

# Animation properties
var _base_position: Vector2
var _hover_offset: Vector2 = Vector2(0, -3)
var _current_tween: Tween

func _ready() -> void:
	_create_spine_structure()
	_apply_data_to_ui()
	
	# Set spine size
	custom_minimum_size = Vector2(16, 92)
	size = Vector2(16, 92)

	# Connect mouse signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _create_spine_structure() -> void:
	# Create spine texture display
	spine_rect = TextureRect.new()
	spine_rect.name = "SpineRect"
	spine_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	spine_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spine_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(spine_rect)
	
	# Create title label (visible on spine)
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	title_label.add_theme_font_size_override("font_size", 8)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_label)

func _apply_data_to_ui() -> void:
	if not data:
		return
	
	# Set spine texture
	if not spine_texture:
		spine_texture = load("res://Resources/Art/Powerups/powerup_spine.png")
		if not spine_texture:
			push_error("[PowerUpSpine] Failed to load spine texture")
			# Use a fallback colored rectangle
			spine_rect.texture = null
			spine_rect.color = Color(0.4, 0.3, 0.2, 1.0)  # Brown fallback
	
	if spine_rect and spine_texture:
		spine_rect.texture = spine_texture
	
	# Set title text (abbreviated for spine)
	if title_label and data:
		var abbreviated_name: String = _get_abbreviated_name(data.display_name)
		title_label.text = abbreviated_name

func _get_abbreviated_name(full_name: String) -> String:
	# Create abbreviated name that fits on spine
	var words: PackedStringArray = full_name.split(" ")
	if words.size() == 1:
		# Single word - take first few characters
		return words[0].substr(0, min(1, words[0].length()))
	else:
		# Multiple words - take first letter of each
		var abbrev: String = ""
		for word in words:
			if word.length() > 0:
				abbrev += word[0].to_upper()
		return abbrev

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_spine_clicked()

func _on_spine_clicked() -> void:
	if data:
		print("[PowerUpSpine] Spine clicked:", data.id)
		emit_signal("spine_clicked", data.id)

func _on_mouse_entered() -> void:
	# Small hover animation - lift spine slightly
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	_current_tween = create_tween()
	_current_tween.tween_property(self, "position", _base_position + _hover_offset, 0.1)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Emit hover signal with global mouse position
	if data:
		emit_signal("spine_hovered", data.id, get_global_mouse_position())

func _on_mouse_exited() -> void:
	# Return to base position
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	_current_tween = create_tween()
	_current_tween.tween_property(self, "position", _base_position, 0.1)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Emit unhover signal
	if data:
		emit_signal("spine_unhovered", data.id)

func set_data(new_data: PowerUpData) -> void:
	data = new_data
	_apply_data_to_ui()

func set_base_position(pos: Vector2) -> void:
	_base_position = pos
	position = pos

func get_data() -> PowerUpData:
	return data
