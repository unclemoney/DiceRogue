# ConsumableSpine.gd
extends Control
class_name ConsumableSpine

signal spine_clicked(consumable_id: String)
signal spine_hovered(consumable_id: String, mouse_pos: Vector2)
signal spine_unhovered(consumable_id: String)

@export var data: ConsumableData
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
	
	# Set spine size for coupon (horizontal layout) - use call_deferred to avoid anchor warning
	call_deferred("_set_spine_size")

	# Connect mouse signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _set_spine_size() -> void:
	custom_minimum_size = Vector2(92, 16)
	size = Vector2(92, 16)

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
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 8)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_label)

func _apply_data_to_ui() -> void:
	if not data:
		return
	
	# Set spine texture (coupon spine)
	if not spine_texture:
		spine_texture = load("res://Resources/Art/Powerups/coupon_spine.png")
		if not spine_texture:
			push_error("[ConsumableSpine] Failed to load coupon spine texture")
			# Use a fallback colored rectangle
			spine_rect.texture = null
			spine_rect.color = Color(0.3, 0.4, 0.2, 1.0)  # Green fallback
	
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
		return full_name.substr(0, min(8, full_name.length()))
	else:
		# Multiple words - take first letter of each word
		var abbreviation: String = ""
		for word in words:
			if word.length() > 0:
				abbreviation += word[0].to_upper()
		return abbreviation

func set_data(new_data: ConsumableData) -> void:
	data = new_data
	if is_node_ready():
		_apply_data_to_ui()

func set_base_position(pos: Vector2) -> void:
	_base_position = pos
	position = pos

func _on_mouse_entered() -> void:
	if data:
		emit_signal("spine_hovered", data.id, global_position)
	
	# Animate hover effect
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	_current_tween = create_tween().set_parallel()
	_current_tween.tween_property(self, "position", _base_position + _hover_offset, 0.1)
	_current_tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)

func _on_mouse_exited() -> void:
	if data:
		emit_signal("spine_unhovered", data.id)
	
	# Animate back to base position
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	_current_tween = create_tween().set_parallel()
	_current_tween.tween_property(self, "position", _base_position, 0.1)
	_current_tween.tween_property(self, "scale", Vector2.ONE, 0.1)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if data:
			emit_signal("spine_clicked", data.id)
