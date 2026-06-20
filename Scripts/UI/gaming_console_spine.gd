extends Control
class_name GamingConsoleSpine

const GamingConsoleCardFXRef = preload("res://Scripts/UI/gaming_console_card_fx.gd")

signal activate_pressed
signal card_pressed

const PREVIEW_SIZE : Vector2 = Vector2(104, 56)
const PANEL_FILL : Color = Color(0.247059, 0.219608, 0.345098, 0.0)
const PANEL_BORDER : Color = Color(0.713725, 0.301961, 0.478431, 0.0)
const PANEL_ACCENT : Color = Color(0.137255, 0.411765, 0.415686, 1.0)
const PANEL_TEXT : Color = Color(0.968627, 0.941176, 1.0, 1.0)
const PANEL_OUTLINE : Color = Color(0.129412, 0.121569, 0.2, 0.0)
const PANEL_SHADOW : Color = Color(0.070588, 0.062745, 0.101961, 0.36)
const VCR_FONT : FontFile = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

@export var data: GamingConsoleData

var _console_instance: GamingConsole = null
var _shell: PanelContainer = null
var _art_panel: PanelContainer = null
var _artwork: TextureRect = null
var _title_label: Label = null
var _status_label: Label = null
var _activate_button: Button = null
var _state_led: ColorRect = null
var _art_shader_material: ShaderMaterial = null
var _shader_time: float = 0.0

@onready var _tfx := get_node_or_null("/root/TweenFXHelper")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	custom_minimum_size = Vector2(0.0, 78.0)
	visible = false
	_build_ui()
	if data:
		_apply_data()


func _process(delta: float) -> void:
	if not _art_shader_material or not _art_panel:
		return
	_shader_time += delta
	GamingConsoleCardFXRef.configure_material(_art_shader_material, _art_panel.size, _shader_time, 0.72)


func _gui_input(event: InputEvent) -> void:
	if not data:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if _activate_button and _activate_button.get_global_rect().has_point(get_global_mouse_position()):
				return
			emit_signal("card_pressed")
			get_viewport().set_input_as_handled()


func set_console(new_data: GamingConsoleData, instance: GamingConsole) -> void:
	data = new_data
	_console_instance = instance
	visible = data != null
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
	_apply_button_style(_activate_button, accent_color, 11)
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


func set_led_color(color: Color) -> void:
	if _state_led:
		_state_led.color = color


func _build_ui() -> void:
	_shell = PanelContainer.new()
	_shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shell.add_theme_stylebox_override("panel", _build_panel_style(PANEL_BORDER, PANEL_FILL))
	add_child(_shell)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 1)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 1)
	_shell.add_child(margin)

	var hbox : HBoxContainer = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	_art_panel = PanelContainer.new()
	_art_panel.custom_minimum_size = PREVIEW_SIZE
	_art_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_art_panel.clip_contents = false
	_art_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	#_art_panel.add_theme_stylebox_override("panel", _build_panel_style(PANEL_ACCENT, Color(0.09, 0.08, 0.14, 0.95)))
	hbox.add_child(_art_panel)

	_artwork = TextureRect.new()
	_artwork.set_anchors_preset(Control.PRESET_FULL_RECT)
	_artwork.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_panel.add_child(_artwork)

	var text_vbox : VBoxContainer = VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(text_vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.clip_text = true
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.add_theme_font_override("font", VCR_FONT)
	_title_label.add_theme_font_size_override("font_size", 13)
	_title_label.add_theme_color_override("font_color", PANEL_TEXT)
	_title_label.add_theme_color_override("font_outline_color", PANEL_OUTLINE)
	_title_label.add_theme_constant_override("outline_size", 1)
	text_vbox.add_child(_title_label)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.clip_text = true
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.add_theme_font_override("font", VCR_FONT)
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.add_theme_color_override("font_color", PANEL_ACCENT.lightened(0.4))
	_status_label.add_theme_color_override("font_outline_color", PANEL_OUTLINE)
	_status_label.add_theme_constant_override("outline_size", 1)
	text_vbox.add_child(_status_label)

	_activate_button = Button.new()
	_activate_button.text = "ACTIVATE"
	_activate_button.custom_minimum_size = Vector2(94.0, 34.0)
	_activate_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_activate_button.add_theme_font_override("font", VCR_FONT)
	_apply_button_style(_activate_button, PANEL_ACCENT, 11)
	_activate_button.pressed.connect(_on_activate_button_pressed)
	hbox.add_child(_activate_button)

	_state_led = ColorRect.new()
	_state_led.color = PANEL_ACCENT
	_state_led.custom_minimum_size = Vector2(10.0, 10.0)
	_state_led.anchor_left = 1.0
	_state_led.anchor_top = 0.0
	_state_led.anchor_right = 1.0
	_state_led.anchor_bottom = 0.0
	_state_led.offset_left = -20.0
	_state_led.offset_top = 10.0
	_state_led.offset_right = -10.0
	_state_led.offset_bottom = 20.0
	_state_led.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_state_led)

	if _tfx:
		_activate_button.mouse_entered.connect(_tfx.button_hover.bind(_activate_button))
		_activate_button.mouse_exited.connect(_tfx.button_unhover.bind(_activate_button))
		_activate_button.pressed.connect(_tfx.button_press.bind(_activate_button))


func _apply_data() -> void:
	if not data:
		return
	_title_label.text = data.display_name.to_upper()
	_status_label.text = "TAP CARD FOR DETAILS"
	_artwork.texture = GamingConsoleCardFXRef.get_art_texture(data)
	_apply_art_shader()


func _apply_art_shader() -> void:
	_art_shader_material = null
	_artwork.material = null
	_shader_time = 0.0
	if not data or data.vip_card_shader_key == "":
		return
	_art_shader_material = GamingConsoleCardFXRef.create_material(data.vip_card_shader_key, PREVIEW_SIZE, 0.72)
	if _art_shader_material:
		_artwork.material = _art_shader_material


func _on_activate_button_pressed() -> void:
	emit_signal("activate_pressed")


func _build_panel_style(accent_color: Color, bg_color: Color) -> StyleBoxFlat:
	var style : StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = accent_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.corner_detail = 8
	style.shadow_color = PANEL_SHADOW
	style.shadow_size = 4
	return style


func _apply_button_style(button: Button, accent_color: Color, font_size: int) -> void:
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", PANEL_TEXT)
	button.add_theme_color_override("font_hover_color", PANEL_TEXT)
	button.add_theme_color_override("font_pressed_color", PANEL_TEXT)
	button.add_theme_color_override("font_outline_color", PANEL_OUTLINE)
	button.add_theme_constant_override("outline_size", 1)

	var normal : StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = accent_color.darkened(0.28)
	normal.border_color = accent_color
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	normal.set_content_margin_all(4)
	button.add_theme_stylebox_override("normal", normal)

	var hover : StyleBoxFlat = StyleBoxFlat.new()
	hover.bg_color = accent_color
	hover.border_color = accent_color.lightened(0.12)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(8)
	hover.set_content_margin_all(4)
	button.add_theme_stylebox_override("hover", hover)

	var pressed : StyleBoxFlat = StyleBoxFlat.new()
	pressed.bg_color = accent_color.darkened(0.38)
	pressed.border_color = accent_color.darkened(0.16)
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(8)
	pressed.set_content_margin_all(4)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
