# PowerUpSpine.gd
extends Control
class_name PowerUpSpine

signal spine_clicked(power_up_id: String)
signal spine_hovered(power_up_id: String, mouse_pos: Vector2)
signal spine_unhovered(power_up_id: String)

const COMPACT_SIZE: Vector2 = Vector2(72, 80)
const ICON_MAX_SIZE: Vector2 = Vector2(56, 56)
const SHELL_FILL: Color = Color(0.247059, 0.219608, 0.345098, 0.7)
const SHELL_BORDER: Color = Color(0.713725, 0.301961, 0.478431, 0.07)
const SHELL_SHADOW: Color = Color(0.070588, 0.062745, 0.101961, 0.34)
const TEXT_COLOR: Color = Color(0.968627, 0.941176, 1.0, 1.0)
const TEXT_OUTLINE: Color = Color(0.129412, 0.121569, 0.2, 1.0)
const VCR_FONT = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

@export var data: PowerUpData
@export var spine_texture: Texture2D

var shell: PanelContainer
var spine_rect: TextureRect
var title_label: Label
var rating_label: Label
@onready var _tfx := get_node("/root/TweenFXHelper")

var _base_position: Vector2 = Vector2.ZERO
var _hover_offset: Vector2 = Vector2(0, -3)
var _current_tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = COMPACT_SIZE
	size = COMPACT_SIZE
	_ensure_structure()
	_apply_shell_style()
	_apply_data_to_ui()

	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

func _exit_tree() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
		_current_tween = null
	if _tfx:
		_tfx.stop_effect(self)

func _ensure_structure() -> void:
	shell = get_node_or_null("Shell") as PanelContainer
	if not shell:
		shell = PanelContainer.new()
		shell.name = "Shell"
		shell.set_anchors_preset(Control.PRESET_FULL_RECT)
		shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shell)

	spine_rect = shell.get_node_or_null("IconRect") as TextureRect
	if not spine_rect:
		spine_rect = TextureRect.new()
		spine_rect.name = "IconRect"
		spine_rect.anchor_left = 0.5
		spine_rect.anchor_top = 0.0
		spine_rect.anchor_right = 0.5
		spine_rect.anchor_bottom = 0.0
		spine_rect.offset_left = -ICON_MAX_SIZE.x * 0.5
		spine_rect.offset_top = 6.0
		spine_rect.offset_right = ICON_MAX_SIZE.x * 0.5
		spine_rect.offset_bottom = 6.0 + ICON_MAX_SIZE.y
		spine_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		spine_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		spine_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shell.add_child(spine_rect)

	title_label = shell.get_node_or_null("TitleLabel") as Label
	if not title_label:
		title_label = Label.new()
		title_label.name = "TitleLabel"
		title_label.anchor_left = 0.0
		title_label.anchor_top = 1.0
		title_label.anchor_right = 1.0
		title_label.anchor_bottom = 1.0
		title_label.offset_left = 4.0
		title_label.offset_top = -18.0
		title_label.offset_right = -4.0
		title_label.offset_bottom = -2.0
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_label.clip_text = true
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shell.add_child(title_label)

	rating_label = shell.get_node_or_null("RatingLabel") as Label
	if not rating_label:
		rating_label = Label.new()
		rating_label.name = "RatingLabel"
		rating_label.anchor_left = 1.0
		rating_label.anchor_top = 0.0
		rating_label.anchor_right = 1.0
		rating_label.anchor_bottom = 0.0
		rating_label.offset_left = -24.0
		rating_label.offset_top = 4.0
		rating_label.offset_right = -4.0
		rating_label.offset_bottom = 18.0
		rating_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rating_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rating_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shell.add_child(rating_label)

func _apply_shell_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = SHELL_FILL
	style.border_color = SHELL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.corner_detail = 8
	style.shadow_color = SHELL_SHADOW
	style.shadow_size = 4
	shell.add_theme_stylebox_override("panel", style)

	title_label.add_theme_font_override("font", VCR_FONT)
	title_label.add_theme_font_size_override("font_size", 8)
	title_label.add_theme_color_override("font_color", TEXT_COLOR)
	title_label.add_theme_color_override("font_outline_color", TEXT_OUTLINE)
	title_label.add_theme_constant_override("outline_size", 1)

	rating_label.add_theme_font_override("font", VCR_FONT)
	rating_label.add_theme_font_size_override("font_size", 8)
	rating_label.add_theme_color_override("font_outline_color", TEXT_OUTLINE)
	rating_label.add_theme_constant_override("outline_size", 1)

func _apply_data_to_ui() -> void:
	if not data:
		return

	if spine_rect:
		if data.icon:
			spine_rect.texture = data.icon
		elif spine_texture:
			spine_rect.texture = spine_texture
		else:
			spine_rect.texture = null
			spine_rect.modulate = Color(0.85, 0.78, 0.92, 1.0)

	if title_label:
		title_label.text = _get_abbreviated_name(data.display_name)

	if rating_label:
		rating_label.text = _get_short_rating(data.rating)
		rating_label.add_theme_color_override("font_color", _get_rating_color(data.rating))

func get_compact_size() -> Vector2:
	return COMPACT_SIZE

func _get_short_rating(rating: String) -> String:
	match rating:
		"PG-13":
			return "13"
		"NC-17":
			return "17"
		_:
			return rating

func _get_rating_color(rating: String) -> Color:
	match rating:
		"G":
			return Color(0.65098, 0.941176, 0.745098, 1.0)
		"PG":
			return Color(1.0, 0.854902, 0.631373, 1.0)
		"PG-13":
			return Color(1.0, 0.662745, 0.34902, 1.0)
		"R":
			return Color(1.0, 0.470588, 0.576471, 1.0)
		"NC-17":
			return Color(0.886275, 0.560784, 0.72549, 1.0)
		_:
			return TEXT_COLOR

func _get_abbreviated_name(full_name: String) -> String:
	var words: PackedStringArray = full_name.split(" ", false)
	if words.is_empty():
		return "???"
	if words.size() == 1:
		return words[0].substr(0, min(4, words[0].length())).to_upper()

	var abbrev := ""
	for word in words:
		if word.length() > 0:
			abbrev += word[0].to_upper()
	return abbrev.substr(0, min(4, abbrev.length()))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_spine_clicked()

func _on_spine_clicked() -> void:
	if data:
		emit_signal("spine_clicked", data.id)

func _on_mouse_entered() -> void:
	if not is_inside_tree():
		return
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	var old_pivot = pivot_offset
	_tfx.spine_hover(self)
	adjust_position_for_pivot_change(old_pivot)

	var tween_target = _base_position + _hover_offset + _get_current_pivot_compensation()
	_current_tween = create_tween()
	_current_tween.tween_property(self, "position", tween_target, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if data:
		emit_signal("spine_hovered", data.id, get_global_mouse_position())

func _on_mouse_exited() -> void:
	if not is_inside_tree():
		return
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	var tween_target = _base_position + _get_current_pivot_compensation()
	_current_tween = create_tween()
	_current_tween.tween_property(self, "position", tween_target, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var unhover_tween = _tfx.spine_unhover(self)
	if unhover_tween:
		unhover_tween.finished.connect(func():
			var old_pivot = pivot_offset
			pivot_offset = Vector2.ZERO
			adjust_position_for_pivot_change(old_pivot)
			scale = Vector2.ONE
		)
	else:
		var old_pivot = pivot_offset
		pivot_offset = Vector2.ZERO
		adjust_position_for_pivot_change(old_pivot)
		scale = Vector2.ONE

	if data:
		emit_signal("spine_unhovered", data.id)

func set_data(new_data: PowerUpData) -> void:
	data = new_data
	if is_inside_tree():
		_apply_data_to_ui()

func set_base_position(pos: Vector2) -> void:
	var old_pivot = pivot_offset
	pivot_offset = Vector2.ZERO
	adjust_position_for_pivot_change(old_pivot)
	_base_position = pos
	position = pos
	rotation_degrees = 0.0
	scale = Vector2.ONE

func get_base_position() -> Vector2:
	return _base_position

func get_data() -> PowerUpData:
	return data

func _get_pivot_compensation(old_pivot: Vector2, new_pivot: Vector2) -> Vector2:
	var diff = new_pivot - old_pivot
	if diff == Vector2.ZERO:
		return Vector2.ZERO
	var angle = deg_to_rad(rotation_degrees)
	var rot = Transform2D(angle, Vector2.ZERO)
	return rot * diff - diff

func adjust_position_for_pivot_change(old_pivot: Vector2) -> void:
	position += _get_pivot_compensation(old_pivot, pivot_offset)

func _get_current_pivot_compensation() -> Vector2:
	return _get_pivot_compensation(Vector2.ZERO, pivot_offset)
