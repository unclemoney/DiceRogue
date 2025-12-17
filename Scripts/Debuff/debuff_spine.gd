extends Control
class_name DebuffSpine
## DebuffSpine
##
## A spine component that displays debuff information on a LIST_NOTE texture.
## Shows LIST_NOTE when debuffs exist. When clicked, triggers fan-out to show all debuffs.

signal spine_clicked()
signal spine_hovered(mouse_pos: Vector2)
signal spine_unhovered()

@export var list_note_texture: Texture2D

@onready var spine_rect: TextureRect
@onready var title_label: Label
@onready var count_label: Label

# State tracking
var _has_debuffs: bool = false
var _debuff_count: int = 0

# Animation properties
var _base_position: Vector2
var _hover_offset: Vector2 = Vector2(0, -5)
var _current_tween: Tween


func _ready() -> void:
	_create_spine_structure()
	_apply_data_to_ui()
	
	# Set spine size for list note
	call_deferred("_set_spine_size")
	
	# Connect mouse signals if not already connected (may be connected in scene)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)


func _exit_tree() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
		_current_tween = null


func _set_spine_size() -> void:
	custom_minimum_size = Vector2(100, 130)
	set_deferred("size", Vector2(100, 130))


func _create_spine_structure() -> void:
	# Create spine texture display (LIST_NOTE)
	spine_rect = TextureRect.new()
	spine_rect.name = "SpineRect"
	spine_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	spine_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spine_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(spine_rect)
	
	# Create title label
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_label.position = Vector2(-40, 15)
	title_label.size = Vector2(80, 20)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 10)
	title_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	title_label.text = "DEBUFFS"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_label)
	
	# Create count label (shows number of debuffs)
	count_label = Label.new()
	count_label.name = "CountLabel"
	count_label.set_anchors_preset(Control.PRESET_CENTER)
	count_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	count_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 24)
	count_label.add_theme_color_override("font_color", Color(0.6, 0.2, 0.2, 1))
	count_label.text = "0"
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(count_label)


func _apply_data_to_ui() -> void:
	# Load LIST_NOTE texture
	if not list_note_texture:
		list_note_texture = load("res://Resources/Art/Background/LIST_NOTE.png")
		if not list_note_texture:
			push_error("[DebuffSpine] Failed to load LIST_NOTE texture")
	
	if spine_rect and list_note_texture:
		spine_rect.texture = list_note_texture
	
	_update_visual_state()


func _update_visual_state() -> void:
	# Update count display
	if count_label:
		count_label.text = str(_debuff_count)
		
		# Change color based on count
		if _debuff_count == 0:
			count_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
		else:
			count_label.add_theme_color_override("font_color", Color(0.6, 0.2, 0.2, 1))
	
	# Adjust modulate for empty vs full state
	if spine_rect:
		if _has_debuffs:
			spine_rect.modulate = Color(1, 1, 1, 1)
		else:
			spine_rect.modulate = Color(0.8, 0.8, 0.8, 0.7)


## set_has_debuffs(has_debuffs)
##
## Updates the spine to show full or empty state.
func set_has_debuffs(has_debuffs: bool) -> void:
	_has_debuffs = has_debuffs
	_update_visual_state()


## set_debuff_count(count)
##
## Updates the debuff count display.
func set_debuff_count(count: int) -> void:
	_debuff_count = count
	_has_debuffs = count > 0
	_update_visual_state()


func set_base_position(pos: Vector2) -> void:
	_base_position = pos
	position = pos


func _on_mouse_entered() -> void:
	emit_signal("spine_hovered", global_position)
	
	if not is_inside_tree() or not is_instance_valid(self):
		return
	
	if not get_parent():
		return
	
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	_current_tween = create_tween().set_parallel()
	_current_tween.tween_property(self, "position", _base_position + _hover_offset, 0.1)
	_current_tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)


func _on_mouse_exited() -> void:
	emit_signal("spine_unhovered")
	
	if not is_inside_tree() or not is_instance_valid(self):
		return
	
	if not get_parent():
		return
	
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	_current_tween = create_tween().set_parallel()
	_current_tween.tween_property(self, "position", _base_position, 0.1)
	_current_tween.tween_property(self, "scale", Vector2.ONE, 0.1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("spine_clicked")
