extends Control
class_name GlassActionButton

signal pressed

const SHADER_PATH := "res://Scripts/Shaders/shop_reroll_button_glass.gdshader"
const DEFAULT_FONT_COLOR := Color(0.968627, 0.941176, 1.0, 1.0)
const DEFAULT_FONT_OUTLINE := Color(0.129412, 0.121569, 0.2, 1.0)

var shader_rect: ColorRect
var content_margin: MarginContainer
var title_label: Label
var overlay_button: Button
var shader_material: ShaderMaterial

var _tfx: Node = null
var _is_disabled: bool = false
var _font_color: Color = DEFAULT_FONT_COLOR
var _button_text: String = ""

var disabled: bool:
	get:
		return _is_disabled
	set(value):
		set_button_disabled(value)

var text: String:
	get:
		return _button_text
	set(value):
		set_button_text(value)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_tfx = get_node_or_null("/root/TweenFXHelper")
	if shader_rect == null:
		_build_ui()
		_apply_default_palette()
		_update_aspect_ratio()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_aspect_ratio()


func configure(label_text: String, button_size: Vector2, palette: Dictionary = {}, font_size: int = 18, font_resource: Font = null) -> void:
	if shader_rect == null:
		_build_ui()
	custom_minimum_size = button_size
	set_button_text(label_text)
	set_font_size(font_size)
	set_font_resource(font_resource)
	set_palette(palette)
	_update_aspect_ratio()


func set_button_text(label_text: String) -> void:
	_button_text = label_text
	if title_label:
		title_label.text = label_text


func get_button_text() -> String:
	if title_label:
		return title_label.text
	return _button_text


func set_font_size(font_size: int) -> void:
	if title_label:
		title_label.add_theme_font_size_override("font_size", font_size)


func set_font_resource(font_resource: Font) -> void:
	if title_label and font_resource:
		title_label.add_theme_font_override("font", font_resource)


func set_palette(palette: Dictionary) -> void:
	if shader_material == null:
		return

	_apply_shader_color("accent_color", palette, Color(0.47451, 0.886275, 0.890196, 1.0))
	_apply_shader_color("glow_color", palette, Color(0.968627, 0.941176, 1.0, 1.0))
	_apply_shader_color("base_color", palette, Color(0.137255, 0.411765, 0.415686, 0.92))
	_apply_shader_color("mid_color", palette, Color(0.2, 0.56, 0.56, 0.96))
	_apply_shader_color("rim_color", palette, Color(0.968627, 0.941176, 1.0, 1.0))
	_apply_shader_color("specular_color", palette, Color(0.917647, 1.0, 0.984314, 1.0))

	_font_color = palette.get("font_color", DEFAULT_FONT_COLOR)
	var font_outline: Color = palette.get("font_outline_color", DEFAULT_FONT_OUTLINE)
	if title_label:
		title_label.add_theme_color_override("font_color", _font_color)
		title_label.add_theme_color_override("font_outline_color", font_outline)
		if palette.has("outline_size"):
			title_label.add_theme_constant_override("outline_size", palette.get("outline_size", 1))

	_update_disabled_visuals()


func set_button_disabled(is_disabled: bool) -> void:
	_is_disabled = is_disabled
	if is_disabled:
		clear_visual_state()
	_update_disabled_visuals()


func is_button_disabled() -> bool:
	return _is_disabled


func set_button_focus_mode(new_focus_mode: Control.FocusMode) -> void:
	if overlay_button:
		overlay_button.focus_mode = new_focus_mode


func get_overlay_button() -> Button:
	return overlay_button


func clear_visual_state() -> void:
	if shader_material:
		shader_material.set_shader_parameter("hover_strength", 0.0)
		shader_material.set_shader_parameter("pulse_strength", 0.0)
		shader_material.set_shader_parameter("press_flash", 0.0)


func _build_ui() -> void:
	shader_rect = ColorRect.new()
	shader_rect.name = "ShaderRect"
	shader_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	shader_rect.color = Color.WHITE
	add_child(shader_rect)

	var shader = load(SHADER_PATH) as Shader
	if shader:
		shader_material = ShaderMaterial.new()
		shader_material.shader = shader
		shader_material.set_shader_parameter("hover_strength", 0.0)
		shader_material.set_shader_parameter("pulse_strength", 0.0)
		shader_material.set_shader_parameter("press_flash", 0.0)
		shader_material.set_shader_parameter("disabled_factor", 0.0)
		shader_rect.material = shader_material

	content_margin = MarginContainer.new()
	content_margin.name = "ContentMargin"
	content_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_margin.add_theme_constant_override("margin_left", 14)
	content_margin.add_theme_constant_override("margin_top", 8)
	content_margin.add_theme_constant_override("margin_right", 14)
	content_margin.add_theme_constant_override("margin_bottom", 8)
	add_child(content_margin)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_margin.add_child(center)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = _button_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	title_label.add_theme_color_override("font_color", DEFAULT_FONT_COLOR)
	title_label.add_theme_color_override("font_outline_color", DEFAULT_FONT_OUTLINE)
	title_label.add_theme_constant_override("outline_size", 1)
	center.add_child(title_label)

	overlay_button = Button.new()
	overlay_button.name = "OverlayButton"
	overlay_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_button.flat = true
	overlay_button.text = ""
	overlay_button.focus_mode = Control.FOCUS_NONE
	overlay_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty_style = StyleBoxEmpty.new()
	overlay_button.add_theme_stylebox_override("normal", empty_style)
	overlay_button.add_theme_stylebox_override("hover", empty_style)
	overlay_button.add_theme_stylebox_override("pressed", empty_style)
	overlay_button.add_theme_stylebox_override("disabled", empty_style)
	overlay_button.add_theme_stylebox_override("focus", empty_style)
	overlay_button.disabled = _is_disabled
	overlay_button.pressed.connect(_on_overlay_pressed)
	overlay_button.mouse_entered.connect(_on_overlay_mouse_entered)
	overlay_button.mouse_exited.connect(_on_overlay_mouse_exited)
	add_child(overlay_button)


func _apply_default_palette() -> void:
	set_palette({})


func _apply_shader_color(param_name: String, palette: Dictionary, default_color: Color) -> void:
	var color_value = palette.get(param_name, default_color)
	shader_material.set_shader_parameter(param_name, color_value)


func _update_aspect_ratio() -> void:
	if shader_material == null:
		return
	var width_value = size.x
	var height_value = size.y
	if width_value <= 0.0 or height_value <= 0.0:
		width_value = custom_minimum_size.x
		height_value = custom_minimum_size.y
	if width_value > 0.0 and height_value > 0.0:
		shader_material.set_shader_parameter("aspect_ratio", width_value / height_value)


func _update_disabled_visuals() -> void:
	if overlay_button:
		overlay_button.disabled = _is_disabled
	if shader_material:
		shader_material.set_shader_parameter("disabled_factor", 1.0 if _is_disabled else 0.0)
	if title_label:
		title_label.add_theme_color_override("font_color", _font_color)
		title_label.modulate = Color(1.0, 1.0, 1.0, 0.55 if _is_disabled else 1.0)


func _on_overlay_mouse_entered() -> void:
	if _is_disabled:
		return
	if _tfx:
		_tfx.button_hover(self)
	if shader_material:
		shader_material.set_shader_parameter("hover_strength", 1.0)
		shader_material.set_shader_parameter("pulse_strength", 0.3)


func _on_overlay_mouse_exited() -> void:
	if _tfx:
		_tfx.button_unhover(self)
	if shader_material:
		shader_material.set_shader_parameter("hover_strength", 0.0)
		shader_material.set_shader_parameter("pulse_strength", 0.0)


func _on_overlay_pressed() -> void:
	if _is_disabled:
		return
	if _tfx:
		_tfx.button_press(self)
	if shader_material:
		shader_material.set_shader_parameter("press_flash", 1.0)
		var tween = create_tween()
		tween.tween_method(_set_press_flash, 1.0, 0.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pressed.emit()


func _set_press_flash(value: float) -> void:
	if shader_material:
		shader_material.set_shader_parameter("press_flash", value)