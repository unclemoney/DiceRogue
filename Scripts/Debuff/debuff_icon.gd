extends Control
class_name DebuffIcon

## DebuffIcon
##
## Compact chip-style UI for a single debuff displayed inside debuff_container.
## Shows: debuff icon art, name label, difficulty stars.
## All hover/shader/physics effects removed. mouse_filter = IGNORE so
## DebuffUI intercepts all input.

signal debuff_selected(id: String)

@export var data: DebuffData

# Difficulty tint by tier: 0=white, 1=green, 2=yellow, 3=orange, 4=red, 5=purple
const DIFFICULTY_TINTS: Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(0.4, 1.0, 0.4),
	Color(1.0, 0.9, 0.2),
	Color(1.0, 0.55, 0.1),
	Color(1.0, 0.25, 0.25),
	Color(0.75, 0.3, 1.0),
]

var _bg_rect: ColorRect
var _icon_rect: TextureRect
var _name_label: Label
var _diff_label: Label

var is_active := false
var _current_tween: Tween



const CHIP_SIZE := Vector2(60, 64)

func _ready() -> void:
	custom_minimum_size = CHIP_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_apply_data_to_ui()


func _build_ui() -> void:
	_bg_rect = ColorRect.new()
	_bg_rect.name = "BgRect"
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.color = Color(0.10, 0.08, 0.14, 0.85)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_rect)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 4
	vbox.offset_top = 4
	vbox.offset_right = -4
	vbox.offset_bottom = -4
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	var vcr_font := load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf") as FontFile

	_icon_rect = TextureRect.new()
	_icon_rect.name = "IconRect"
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon_rect.custom_minimum_size = Vector2(28, 28)
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_icon_rect)

	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vcr_font:
		_name_label.add_theme_font_override("font", vcr_font)
	_name_label.add_theme_font_size_override("font_size", 10)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7, 1.0))
	_name_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_name_label.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(_name_label)

	_diff_label = Label.new()
	_diff_label.name = "DiffLabel"
	_diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_diff_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diff_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_diff_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vcr_font:
		_diff_label.add_theme_font_override("font", vcr_font)
	_diff_label.add_theme_font_size_override("font_size", 9)
	_diff_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1.0))
	vbox.add_child(_diff_label)


func _apply_data_to_ui() -> void:
	if not data:
		return

	if _name_label:
		_name_label.text = data.display_name if data.display_name else data.id

	if _diff_label:
		_diff_label.text = _build_star_string(data.difficulty_rating)

	if _icon_rect:
		if data.icon:
			_icon_rect.texture = data.icon

	if _bg_rect:
		var tier: int = clamp(data.difficulty_rating, 0, 5)
		var tint: Color = DIFFICULTY_TINTS[tier]
		_bg_rect.color = Color(
			0.10 * tint.r + 0.04,
			0.08 * tint.g + 0.04,
			0.14 * tint.b + 0.04,
			0.85
		)


func _build_star_string(difficulty: int) -> String:
	var clamped: int = clamp(difficulty, 0, 5)
	var result := ""
	for i in range(5):
		if i < clamped:
			result += "★"
		else:
			result += "☆"
	return result


## set_data(new_data)
##
## Updates the icon with a new DebuffData resource.
func set_data(new_data: DebuffData) -> void:
	data = new_data
	_apply_data_to_ui()


## set_active(active)
##
## Applies a red modulate tint when the debuff is active, white when inactive.
func set_active(active: bool) -> void:
	is_active = active
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	_current_tween = create_tween()
	if active:
		_current_tween.tween_property(self, "modulate", Color(1.2, 0.3, 0.3), 0.3)
	else:
		_current_tween.tween_property(self, "modulate", Color.WHITE, 0.3)

