extends RefCounted
class_name GlassButtonFactory

const GlassActionButtonClass = preload("res://Scripts/UI/glass_action_button.gd")
const DEFAULT_FONT: Font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
const DEFAULT_FONT_COLOR := Color(0.968627, 0.941176, 1.0, 1.0)
const DEFAULT_FONT_OUTLINE := Color(0.129412, 0.121569, 0.2, 1.0)
const DEFAULT_RIM_COLOR := Color(0.968627, 0.941176, 1.0, 1.0)


static func build_palette(base_color: Color, mid_color: Color, accent_color: Color, glow_color: Color, rim_color: Color = DEFAULT_RIM_COLOR, font_color: Color = DEFAULT_FONT_COLOR, font_outline_color: Color = DEFAULT_FONT_OUTLINE, outline_size: int = 0) -> Dictionary:
	return {
		"base_color": base_color,
		"mid_color": mid_color,
		"accent_color": accent_color,
		"glow_color": glow_color,
		"rim_color": rim_color,
		"font_color": font_color,
		"font_outline_color": font_outline_color,
		"outline_size": outline_size,
	}


static func palette_neutral() -> Dictionary:
	return build_palette(
		Color(0.247059, 0.219608, 0.345098, 0.94),
		Color(0.298039, 0.239216, 0.380392, 0.98),
		Color(0.713725, 0.301961, 0.478431, 1.0),
		Color(0.901961, 0.45098, 0.556863, 1.0)
	)


static func palette_info() -> Dictionary:
	return build_palette(
		Color(0.145098, 0.254902, 0.415686, 0.94),
		Color(0.192157, 0.352941, 0.560784, 0.98),
		Color(0.498039, 0.760784, 0.964706, 1.0),
		Color(0.65098, 0.866667, 1.0, 1.0)
	)


static func palette_positive() -> Dictionary:
	return build_palette(
		Color(0.137255, 0.411765, 0.415686, 0.92),
		Color(0.2, 0.56, 0.56, 0.96),
		Color(0.47451, 0.886275, 0.890196, 1.0),
		Color(0.6, 0.94, 0.96, 1.0)
	)


static func palette_success() -> Dictionary:
	return build_palette(
		Color(0.192157, 0.431373, 0.203922, 0.92),
		Color(0.278431, 0.603922, 0.294118, 0.96),
		Color(0.47451, 0.886275, 0.521569, 1.0),
		Color(0.623529, 0.968627, 0.678431, 1.0)
	)


static func palette_warning() -> Dictionary:
	return build_palette(
		Color(0.321569, 0.203922, 0.070588, 0.92),
		Color(0.478431, 0.32549, 0.117647, 0.96),
		Color(0.964706, 0.760784, 0.360784, 1.0),
		Color(1.0, 0.898039, 0.6, 1.0),
		Color(1.0, 0.956863, 0.823529, 1.0),
		Color(1.0, 0.968627, 0.878431, 1.0),
		Color(0.2, 0.12, 0.03, 1.0),
		1
	)


static func palette_danger() -> Dictionary:
	return build_palette(
		Color(0.309804, 0.14902, 0.25098, 0.92),
		Color(0.443137, 0.203922, 0.360784, 0.96),
		Color(0.886275, 0.392157, 0.54902, 1.0),
		Color(0.952941, 0.584314, 0.72549, 1.0)
	)


static func palette_item_action() -> Dictionary:
	return build_palette(
		Color(0.196078, 0.14902, 0.25098, 0.94),
		Color(0.286275, 0.211765, 0.345098, 0.98),
		Color(1.0, 0.8, 0.2, 1.0),
		Color(1.0, 0.9, 0.3, 1.0),
		DEFAULT_RIM_COLOR,
		Color(1.0, 0.98, 0.9, 1.0),
		Color(0.0, 0.0, 0.0, 1.0),
		1
	)


static func palette_kiosk_sell() -> Dictionary:
	return build_palette(
		Color(0.65, 0.15, 0.4, 0.96),
		Color(0.85, 0.25, 0.55, 0.98),
		Color(1.0, 0.55, 0.75, 1.0),
		Color(1.0, 0.75, 0.85, 1.0),
		DEFAULT_RIM_COLOR,
		Color(1.0, 1.0, 0.9, 1.0),
		Color(0.0, 0.0, 0.0, 1.0),
		1
	)


static func palette_console_primary() -> Dictionary:
	return build_palette(
		Color(0.145098, 0.27451, 0.298039, 0.94),
		Color(0.176471, 0.396078, 0.423529, 0.98),
		Color(0.498039, 0.862745, 0.886275, 1.0),
		Color(0.65098, 0.941176, 0.964706, 1.0)
	)


static func palette_console_secondary() -> Dictionary:
	return build_palette(
		Color(0.247059, 0.219608, 0.345098, 0.94),
		Color(0.298039, 0.239216, 0.380392, 0.98),
		Color(0.713725, 0.301961, 0.478431, 1.0),
		Color(0.901961, 0.45098, 0.556863, 1.0)
	)


static func create_button(label_text: String, button_size: Vector2, palette: Dictionary, font_size: int = 18, font_resource: Font = DEFAULT_FONT, focus_mode: Control.FocusMode = Control.FOCUS_NONE):
	var button = GlassActionButtonClass.new()
	button.configure(label_text, button_size, palette, font_size, font_resource)
	button.set_button_focus_mode(focus_mode)
	return button


static func replace_button(source_button: Button, palette: Dictionary, font_size: int = 18, font_resource: Font = DEFAULT_FONT, override_text: String = "", focus_mode: Control.FocusMode = Control.FOCUS_NONE):
	if source_button == null:
		return null
	var parent = source_button.get_parent()
	if parent == null:
		return null
	var source_size = source_button.size
	if source_size == Vector2.ZERO:
		source_size = source_button.custom_minimum_size
	if source_size == Vector2.ZERO:
		source_size = Vector2(120, 40)
	var button_text = override_text if override_text != "" else source_button.text
	var replacement = create_button(button_text, source_size, palette, font_size, font_resource, focus_mode)
	replacement.name = source_button.name
	_copy_control_layout(source_button, replacement)
	var child_index = source_button.get_index()
	parent.add_child(replacement)
	parent.move_child(replacement, child_index)
	source_button.queue_free()
	return replacement


static func _copy_control_layout(source: Control, target: Control) -> void:
	target.layout_mode = source.layout_mode
	target.anchor_left = source.anchor_left
	target.anchor_top = source.anchor_top
	target.anchor_right = source.anchor_right
	target.anchor_bottom = source.anchor_bottom
	target.offset_left = source.offset_left
	target.offset_top = source.offset_top
	target.offset_right = source.offset_right
	target.offset_bottom = source.offset_bottom
	target.position = source.position
	target.size = source.size
	target.custom_minimum_size = source.custom_minimum_size
	target.size_flags_horizontal = source.size_flags_horizontal
	target.size_flags_vertical = source.size_flags_vertical
	target.grow_horizontal = source.grow_horizontal
	target.grow_vertical = source.grow_vertical
	target.mouse_filter = source.mouse_filter
	target.mouse_default_cursor_shape = source.mouse_default_cursor_shape
	target.visible = source.visible
	target.z_index = source.z_index
	target.tooltip_text = source.tooltip_text