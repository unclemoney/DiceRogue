extends Control

const GlassButtonFactoryRef = preload("res://Scripts/UI/glass_button_factory.gd")
const MomPortraitAnimatorScript = preload("res://Scripts/UI/mom_portrait_animator.gd")
const BACKDROP_SHADER_PATH := "res://Scripts/Shaders/panel_backdrop.gdshader"
const TYPEWRITER_SPEED := 0.02
const TRANSITION_DURATION := 0.25
const GOLDEN_COLOR := Color(1.0, 0.85, 0.32, 1.0)
const DARK_PURPLE_BG := Color(0.08, 0.05, 0.15, 0.97)
const PANEL_CORNER_RADIUS := 12.0

signal next_clicked
signal back_clicked
signal exit_confirmed

var vcr_font: Font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
var dialog_panel: PanelContainer
var backdrop_fx_rect: ColorRect
var portrait: MomPortraitAnimator
var title_label: Label
var step_counter_label: Label
var message_label: RichTextLabel
var back_button
var exit_button
var next_button
var exit_confirm_dialog: ConfirmationDialog

var _current_step = null
var _typewriter_tween: Tween
var _transition_tween: Tween
var _full_message_text := ""
var _typing_complete := false
var _can_advance := true
var _panel_home := Vector2.ZERO
var _tfx: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tfx = get_node_or_null("/root/TweenFXHelper")
	_build_ui()
	hide()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_panel = PanelContainer.new()
	dialog_panel.name = "DialogPanel"
	dialog_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	dialog_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	dialog_panel.custom_minimum_size = Vector2(700, 210)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = DARK_PURPLE_BG
	panel_style.border_color = GOLDEN_COLOR
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(int(PANEL_CORNER_RADIUS))
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 14
	panel_style.content_margin_bottom = 14
	dialog_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(dialog_panel)
	_create_backdrop_fx_rect()

	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 16)
	dialog_panel.add_child(main_hbox)
	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(112, 112)
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	main_hbox.add_child(portrait_frame)
	portrait = MomPortraitAnimatorScript.new()
	portrait.name = "Portrait"
	portrait.position = Vector2(56, 92)
	portrait.scale = Vector2.ONE * 0.85
	portrait_frame.add_child(portrait)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(content)
	var title_row := HBoxContainer.new()
	content.add_child(title_row)
	title_label = Label.new()
	title_label.add_theme_font_override("font", vcr_font)
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", GOLDEN_COLOR)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_label)
	step_counter_label = Label.new()
	step_counter_label.add_theme_font_override("font", vcr_font)
	step_counter_label.add_theme_font_size_override("font_size", 13)
	title_row.add_child(step_counter_label)

	message_label = RichTextLabel.new()
	message_label.bbcode_enabled = true
	message_label.fit_content = false
	message_label.custom_minimum_size = Vector2(0, 92)
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	message_label.add_theme_font_override("normal_font", vcr_font)
	message_label.add_theme_font_size_override("normal_font_size", 15)
	message_label.add_theme_color_override("default_color", Color(0.9, 0.9, 0.95))
	message_label.scroll_active = true
	message_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	content.add_child(message_label)

	var button_row := HBoxContainer.new()
	button_row.name = "ButtonRow"
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 18)
	content.add_child(button_row)
	back_button = _create_button("← Back", Color(0.4, 0.5, 0.75), 112)
	back_button.pressed.connect(func(): back_clicked.emit())
	button_row.add_child(back_button)
	exit_button = _create_button("Exit", Color(0.65, 0.35, 0.35), 100)
	exit_button.pressed.connect(func(): exit_confirm_dialog.popup_centered())
	button_row.add_child(exit_button)
	next_button = _create_button("Next →", Color(0.3, 0.7, 0.4), 124)
	next_button.pressed.connect(_on_next_pressed)
	button_row.add_child(next_button)

	exit_confirm_dialog = ConfirmationDialog.new()
	exit_confirm_dialog.title = "Exit Tutorial?"
	exit_confirm_dialog.dialog_text = "Return to the main menu?\n\nThe tutorial stays incomplete and will restart next time."
	exit_confirm_dialog.ok_button_text = "Exit to Main Menu"
	exit_confirm_dialog.cancel_button_text = "Keep Learning"
	exit_confirm_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	exit_confirm_dialog.confirmed.connect(func(): exit_confirmed.emit())
	add_child(exit_confirm_dialog)


func _create_button(text: String, color: Color, width: float):
	var button = GlassButtonFactoryRef.create_button(text, Vector2(width, 34), _palette(color), 14, vcr_font)
	button.set_uniform_padding(8, 4)
	return button


func _palette(accent: Color) -> Dictionary:
	return GlassButtonFactoryRef.build_palette(accent.darkened(0.58), accent.darkened(0.32), accent, accent.lightened(0.18), Color(0.97, 0.94, 1.0), Color(0.97, 0.94, 1.0), Color(0.13, 0.12, 0.2), 1)


func set_navigation_state(can_go_back: bool, can_advance: bool) -> void:
	_can_advance = can_advance
	if back_button:
		back_button.disabled = not can_go_back
	if next_button:
		next_button.disabled = not can_advance


func show_step(step) -> void:
	_current_step = step
	_kill_typewriter()
	_typing_complete = false
	title_label.text = step.title if step.title != "" else "MOM'S TIPS"
	step_counter_label.text = step.get_step_label()
	step_counter_label.visible = step_counter_label.text != ""
	next_button.text = "Finish!" if step.is_final_step() else "Next →"
	_full_message_text = step.message
	message_label.text = _full_message_text
	portrait.set_expression_hint(step.mom_expression)
	portrait.set_paused(false)
	show()
	if step.dialog_position == "hidden":
		_stop_portrait()
		dialog_panel.hide()
		return
	_position_dialog(step)
	_play_intro()
	_start_typewriter()


func hide_dialog() -> void:
	_kill_typewriter()
	_stop_portrait()
	if not dialog_panel or not dialog_panel.visible:
		hide()
		return
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = create_tween()
	_transition_tween.tween_property(dialog_panel, "position", _panel_home + Vector2(0, 24), TRANSITION_DURATION)
	_transition_tween.parallel().tween_property(dialog_panel, "modulate:a", 0.0, TRANSITION_DURATION)
	_transition_tween.finished.connect(func(): dialog_panel.hide())


func _play_intro() -> void:
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	dialog_panel.show()
	dialog_panel.modulate.a = 0.0
	dialog_panel.position = _panel_home + Vector2(0, 24)
	_transition_tween = create_tween()
	_transition_tween.tween_property(dialog_panel, "position", _panel_home, TRANSITION_DURATION)
	_transition_tween.parallel().tween_property(dialog_panel, "modulate:a", 1.0, TRANSITION_DURATION)


func _position_dialog(step) -> void:
	var viewport_size := get_viewport_rect().size
	var panel_size := Vector2(minf(700.0, viewport_size.x - 32.0), 210.0)
	dialog_panel.custom_minimum_size.x = panel_size.x
	var position_hint: String = step.dialog_position
	if position_hint == "auto":
		position_hint = _auto_position(step, viewport_size)
	var margin := 16.0
	match position_hint:
		"top":
			_panel_home = Vector2((viewport_size.x - panel_size.x) * 0.5, margin)
		"left":
			_panel_home = Vector2(margin, (viewport_size.y - panel_size.y) * 0.5)
		"right":
			_panel_home = Vector2(viewport_size.x - panel_size.x - margin, (viewport_size.y - panel_size.y) * 0.5)
		"center":
			_panel_home = (viewport_size - panel_size) * 0.5
		_:
			_panel_home = Vector2((viewport_size.x - panel_size.x) * 0.5, viewport_size.y - panel_size.y - margin)
	dialog_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	dialog_panel.position = _panel_home
	dialog_panel.size = panel_size


func _auto_position(step, viewport_size: Vector2) -> String:
	var target: CanvasItem = null
	var manager = get_node_or_null("/root/TutorialManager")
	if step.semantic_target != "" and manager and manager._gameplay:
		target = manager._gameplay.resolve_target(step.semantic_target)
	elif step.highlight_node_path != "":
		var root_node = _get_game_root()
		if root_node:
			target = root_node.get_node_or_null(step.highlight_node_path)
	if not target:
		return "top"
	var center := Vector2.ZERO
	if target is Control:
		center = target.get_global_rect().get_center()
	elif target is Node2D:
		center = target.global_position
	if center.x > viewport_size.x * 0.72:
		return "left"
	if center.x < viewport_size.x * 0.28:
		return "right"
	return "top" if center.y > viewport_size.y * 0.5 else "bottom"


func _get_game_root() -> Node:
	var controllers := get_tree().get_nodes_in_group("game_controller")
	if not controllers.is_empty():
		return controllers[0].get_parent()
	return get_tree().current_scene


func _start_typewriter() -> void:
	if _full_message_text.is_empty():
		_complete_typing()
		return
	message_label.visible_ratio = 0.0
	portrait.start_talking()
	var duration: float = _strip_bbcode(_full_message_text).length() * TYPEWRITER_SPEED
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_property(message_label, "visible_ratio", 1.0, duration)
	_typewriter_tween.finished.connect(_complete_typing)


func _complete_typing() -> void:
	message_label.visible_ratio = 1.0
	_typing_complete = true
	if portrait:
		portrait.stop_talking()


func _stop_portrait() -> void:
	if portrait:
		portrait.stop_talking()
		portrait.set_paused(true)


func _kill_typewriter() -> void:
	if _typewriter_tween and _typewriter_tween.is_valid():
		_typewriter_tween.kill()


func _strip_bbcode(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\[.*?\\]")
	return regex.sub(text, "", true)


func _on_next_pressed() -> void:
	if not dialog_panel.visible:
		return
	if not _typing_complete:
		_kill_typewriter()
		_complete_typing()
		return
	if _can_advance:
		next_clicked.emit()


func _input(event: InputEvent) -> void:
	if not dialog_panel or not dialog_panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_on_next_pressed()
			get_viewport().set_input_as_handled()


func _create_backdrop_fx_rect() -> void:
	backdrop_fx_rect = ColorRect.new()
	backdrop_fx_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop_fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := load(BACKDROP_SHADER_PATH) as Shader
	if shader:
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("corner_radius", PANEL_CORNER_RADIUS)
		backdrop_fx_rect.material = material
	dialog_panel.add_child(backdrop_fx_rect)
	dialog_panel.move_child(backdrop_fx_rect, 0)
	dialog_panel.resized.connect(_update_backdrop_size)
	_update_backdrop_size()


func _update_backdrop_size() -> void:
	if backdrop_fx_rect and backdrop_fx_rect.material and dialog_panel:
		(backdrop_fx_rect.material as ShaderMaterial).set_shader_parameter("rect_size", dialog_panel.size)
