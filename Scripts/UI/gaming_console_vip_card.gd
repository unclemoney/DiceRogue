extends Control
class_name GamingConsoleVIPCard

const GamingConsoleCardFXRef = preload("res://Scripts/UI/gaming_console_card_fx.gd")

signal activate_pressed

const CARD_SIZE := Vector2(338, 470)
const PANEL_FILL := Color(0.247059, 0.219608, 0.345098, 0.98)
const PANEL_BORDER := Color(0.713725, 0.301961, 0.478431, 1.0)
const PANEL_ACCENT := Color(0.137255, 0.411765, 0.415686, 1.0)
const PANEL_TEXT := Color(0.968627, 0.941176, 1.0, 1.0)
const PANEL_OUTLINE := Color(0.129412, 0.121569, 0.2, 1.0)
const PANEL_SHADOW := Color(0.070588, 0.062745, 0.101961, 0.45)
const VCR_FONT := preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

@export var data: GamingConsoleData

var _console_instance: GamingConsole = null
var _panel: PanelContainer = null
var _title_label: Label = null
var _status_label: Label = null
var _art_panel: PanelContainer = null
var _artwork: TextureRect = null
var _description_label: Label = null
var _activate_button: Button = null
var _close_hint_label: Label = null
var _art_shader_material: ShaderMaterial = null
var _shader_time: float = 0.0

@onready var _tfx := get_node_or_null("/root/TweenFXHelper")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	visible = false
	_build_ui()
	if data:
		_apply_data()


func _process(delta: float) -> void:
	if not _art_shader_material or not _art_panel:
		return
	_shader_time += delta
	GamingConsoleCardFXRef.configure_material(_art_shader_material, _art_panel.size, _shader_time, 1.0)


func set_console(new_data: GamingConsoleData, instance: GamingConsole) -> void:
	data = new_data
	_console_instance = instance
	_apply_data()


func clear_console() -> void:
	data = null
	_console_instance = null
	visible = false
	if _artwork:
		_artwork.texture = null
		_artwork.material = null
	if _tfx and _activate_button:
		_tfx.stop_effect(_activate_button)


func set_button_state(text: String, disabled: bool, accent_color: Color, pulse: bool) -> void:
	if not _activate_button:
		return
	_activate_button.text = text
	_activate_button.disabled = disabled
	_apply_button_style(_activate_button, accent_color, 13)
	if _tfx:
		if pulse and not disabled:
			_tfx.idle_pulse(_activate_button)
		else:
			_tfx.stop_effect(_activate_button)


func set_status_text(text: String, color: Color) -> void:
	if not _status_label:
		return
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


func set_description(text: String) -> void:
	if _description_label:
		_description_label.text = text


func set_card_size(card_size: Vector2) -> void:
	custom_minimum_size = card_size
	size = card_size
	set_anchors_preset(Control.PRESET_TOP_LEFT)


func get_card_size() -> Vector2:
	if size != Vector2.ZERO:
		return size
	return custom_minimum_size


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_theme_stylebox_override("panel", _build_panel_style(PANEL_BORDER, PANEL_FILL))
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var title_panel := PanelContainer.new()
	title_panel.custom_minimum_size = Vector2(0.0, 48.0)
	title_panel.add_theme_stylebox_override("panel", _build_panel_style(PANEL_ACCENT, Color(0.09, 0.08, 0.14, 0.92)))
	content.add_child(title_panel)

	var title_margin := MarginContainer.new()
	title_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_margin.add_theme_constant_override("margin_left", 12)
	title_margin.add_theme_constant_override("margin_top", 10)
	title_margin.add_theme_constant_override("margin_right", 12)
	title_margin.add_theme_constant_override("margin_bottom", 10)
	title_panel.add_child(title_margin)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 2)
	title_margin.add_child(title_vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.clip_text = true
	_title_label.add_theme_font_override("font", VCR_FONT)
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", PANEL_TEXT)
	_title_label.add_theme_color_override("font_outline_color", PANEL_OUTLINE)
	_title_label.add_theme_constant_override("outline_size", 1)
	title_vbox.add_child(_title_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_override("font", VCR_FONT)
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", PANEL_ACCENT.lightened(0.45))
	_status_label.add_theme_color_override("font_outline_color", PANEL_OUTLINE)
	_status_label.add_theme_constant_override("outline_size", 1)
	title_vbox.add_child(_status_label)

	_art_panel = PanelContainer.new()
	_art_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_art_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_art_panel.custom_minimum_size = Vector2(0.0, 220.0)
	_art_panel.clip_contents = true
	_art_panel.add_theme_stylebox_override("panel", _build_panel_style(PANEL_ACCENT, Color(0.08, 0.07, 0.12, 0.0)))
	content.add_child(_art_panel)

	_artwork = TextureRect.new()
	_artwork.set_anchors_preset(Control.PRESET_FULL_RECT)
	_artwork.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_panel.add_child(_artwork)

	var description_panel := PanelContainer.new()
	description_panel.custom_minimum_size = Vector2(0.0, 118.0)
	description_panel.add_theme_stylebox_override("panel", _build_panel_style(PANEL_BORDER, Color(0.09, 0.08, 0.14, 0.94)))
	content.add_child(description_panel)

	var description_margin := MarginContainer.new()
	description_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	description_margin.add_theme_constant_override("margin_left", 12)
	description_margin.add_theme_constant_override("margin_top", 12)
	description_margin.add_theme_constant_override("margin_right", 12)
	description_margin.add_theme_constant_override("margin_bottom", 12)
	description_panel.add_child(description_margin)

	_description_label = Label.new()
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_description_label.add_theme_font_override("font", VCR_FONT)
	_description_label.add_theme_font_size_override("font_size", 13)
	_description_label.add_theme_color_override("font_color", PANEL_TEXT)
	_description_label.add_theme_color_override("font_outline_color", PANEL_OUTLINE)
	_description_label.add_theme_constant_override("outline_size", 1)
	description_margin.add_child(_description_label)

	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	content.add_child(footer)

	_activate_button = Button.new()
	_activate_button.text = "ACTIVATE"
	_activate_button.custom_minimum_size = Vector2(0.0, 42.0)
	_activate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_activate_button.add_theme_font_override("font", VCR_FONT)
	_apply_button_style(_activate_button, PANEL_ACCENT, 13)
	_activate_button.pressed.connect(_on_activate_button_pressed)
	footer.add_child(_activate_button)

	_close_hint_label = Label.new()
	_close_hint_label.text = "CLICK OUTSIDE CARD TO CLOSE"
	_close_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_close_hint_label.add_theme_font_override("font", VCR_FONT)
	_close_hint_label.add_theme_font_size_override("font_size", 10)
	_close_hint_label.add_theme_color_override("font_color", PANEL_BORDER.lightened(0.25))
	_close_hint_label.add_theme_color_override("font_outline_color", PANEL_OUTLINE)
	_close_hint_label.add_theme_constant_override("outline_size", 1)
	footer.add_child(_close_hint_label)

	if _tfx:
		_activate_button.mouse_entered.connect(_tfx.button_hover.bind(_activate_button))
		_activate_button.mouse_exited.connect(_tfx.button_unhover.bind(_activate_button))
		_activate_button.pressed.connect(_tfx.button_press.bind(_activate_button))


func _apply_data() -> void:
	if not data:
		return
	_title_label.text = data.display_name.to_upper()
	_status_label.text = "VIP PREVIEW"
	_description_label.text = data.description
	_artwork.texture = GamingConsoleCardFXRef.get_art_texture(data)
	_apply_art_shader()


func _apply_art_shader() -> void:
	_art_shader_material = null
	_artwork.material = null
	_shader_time = 0.0
	if not data or data.vip_card_shader_key == "":
		return
	_art_shader_material = GamingConsoleCardFXRef.create_material(data.vip_card_shader_key, CARD_SIZE, 1.0)
	if _art_shader_material:
		_artwork.material = _art_shader_material


func _on_activate_button_pressed() -> void:
	emit_signal("activate_pressed")


func _build_panel_style(accent_color: Color, bg_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = accent_color
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.corner_detail = 8
	style.shadow_color = PANEL_SHADOW
	style.shadow_size = 5
	return style


func _apply_button_style(button: Button, accent_color: Color, font_size: int) -> void:
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", PANEL_TEXT)
	button.add_theme_color_override("font_hover_color", PANEL_TEXT)
	button.add_theme_color_override("font_pressed_color", PANEL_TEXT)
	button.add_theme_color_override("font_outline_color", PANEL_OUTLINE)
	button.add_theme_constant_override("outline_size", 1)

	var normal := StyleBoxFlat.new()
	normal.bg_color = accent_color.darkened(0.28)
	normal.border_color = accent_color
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(6)
	button.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = accent_color
	hover.border_color = accent_color.lightened(0.12)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(10)
	hover.set_content_margin_all(6)
	button.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = accent_color.darkened(0.38)
	pressed.border_color = accent_color.darkened(0.16)
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(10)
	pressed.set_content_margin_all(6)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
