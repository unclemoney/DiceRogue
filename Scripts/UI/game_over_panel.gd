extends Control
class_name GameOverPanel

signal new_game_pressed
signal continue_pressed
signal quit_pressed

const MomPortraitAnimatorScript := preload("res://Scripts/UI/mom_portrait_animator.gd")
const GlassActionButtonScript := preload("res://Scripts/UI/glass_action_button.gd")
const GlassButtonFactoryScript := preload("res://Scripts/UI/glass_button_factory.gd")
const VCR_FONT: Font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
const BACKDROP_SHADER_PATH := "res://Scripts/Shaders/panel_backdrop.gdshader"
const PANEL_SIZE := Vector2(620, 420)
const PORTRAIT_FRAME_SIZE := 192.0
const PORTRAIT_BORDER_WIDTH := 2.0
const PORTRAIT_SCALE := 0.9
const PANEL_CORNER_RADIUS := 20.0

const VICTORY_LINES: Array[String] = [
	"You cleared the store. See? I knew you had it in you.",
	"Not bad. Maybe all that sass was worth something.",
	"You win this round. Don’t let it go to your head."
]
const LOW_REP_LINES: Array[String] = [
	"You tried. That counts for something.",
	"Not every trip to the mall ends in victory. Try again.",
	"Even a teacher’s pet misses the mark sometimes. Dust yourself off."
]
const MEDIUM_REP_LINES: Array[String] = [
	"That’s the best you could do?",
	"I’ve seen better dice work in a bargain bin.",
	"Try again. And maybe listen to your mother this time."
]
const HIGH_REP_LINES: Array[String] = [
	"Look at that. All mouth, no dice.",
	"You sassed me for THIS score?",
	"When I was your age, I cleared this place before dinner.",
	"High Rep. Low score. Cute combination."
]

var _overlay: ColorRect
var _panel: PanelContainer
var _backdrop_fx_rect: ColorRect
var _portrait: MomPortraitAnimatorScript
var _score_label: Label
var _action_buttons: Array[GlassActionButton] = []
var _entrance_tween: Tween
var _count_tween: Tween
var _exit_tween: Tween
var _is_exiting: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = RenderLayers.Z_MODAL
	visible = false


## show_game_over(data)
##
## Rebuilds and displays the panel. Data contains final_score, target_score,
## and challenge_completed. Action signals fire only after an animated exit.
func show_game_over(data: Dictionary) -> void:
	_kill_tweens()
	_is_exiting = false
	_clear_ui()
	_build_ui(data)
	visible = true
	_animate_entrance(int(data.get("final_score", 0)))


func _clear_ui() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_action_buttons.clear()
	_overlay = null
	_panel = null
	_backdrop_fx_rect = null
	_portrait = null
	_score_label = null


func _build_ui(data: Dictionary) -> void:
	var challenge_completed := bool(data.get("challenge_completed", false))
	var target_score := int(data.get("target_score", 0))
	var reaction := _resolve_mom_reaction(challenge_completed)

	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.z_index = RenderLayers.Z_MODAL_DIM
	add_child(_overlay)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -PANEL_SIZE.x / 2.0
	_panel.offset_top = -PANEL_SIZE.y / 2.0
	_panel.offset_right = PANEL_SIZE.x / 2.0
	_panel.offset_bottom = PANEL_SIZE.y / 2.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.z_index = RenderLayers.Z_MODAL_CONTENT
	_panel.modulate.a = 0.0
	_apply_panel_style(challenge_completed)
	add_child(_panel)

	_create_backdrop_fx_rect()
	_panel.resized.connect(_update_backdrop_fx_size)

	var main_row := HBoxContainer.new()
	main_row.name = "MainRow"
	main_row.add_theme_constant_override("separation", 20)
	_panel.add_child(main_row)

	var portrait_column := VBoxContainer.new()
	portrait_column.name = "PortraitColumn"
	portrait_column.custom_minimum_size = Vector2(210, 0)
	portrait_column.alignment = BoxContainer.ALIGNMENT_CENTER
	main_row.add_child(portrait_column)

	var portrait_frame := PanelContainer.new()
	portrait_frame.name = "MomPortraitFrame"
	portrait_frame.custom_minimum_size = Vector2.ONE * PORTRAIT_FRAME_SIZE
	portrait_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_portrait_frame_style(portrait_frame)
	portrait_column.add_child(portrait_frame)

	_portrait = MomPortraitAnimatorScript.new()
	_portrait.name = "MomPortrait"
	_portrait.position = Vector2(
		PORTRAIT_FRAME_SIZE / 2.0,
		(PORTRAIT_FRAME_SIZE - PORTRAIT_BORDER_WIDTH) - (PORTRAIT_FRAME_SIZE * PORTRAIT_SCALE) / 2.0
	)
	_portrait.scale = Vector2.ONE * PORTRAIT_SCALE
	portrait_frame.add_child(_portrait)
	_portrait.set_expression_hint(String(reaction["expression"]))
	_apply_mom_mood()

	var content := VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	main_row.add_child(content)

	var title_label := Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "CHALLENGE COMPLETE!" if challenge_completed else "GAME OVER"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", VCR_FONT)
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3) if challenge_completed else Color(1.0, 0.35, 0.35))
	title_label.add_theme_color_override("font_outline_color", Color(0.13, 0.12, 0.2))
	title_label.add_theme_constant_override("outline_size", 1)
	content.add_child(title_label)

	var mom_line_label := Label.new()
	mom_line_label.name = "MomLineLabel"
	mom_line_label.text = String(reaction["line"])
	mom_line_label.custom_minimum_size = Vector2(0, 76)
	mom_line_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mom_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mom_line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mom_line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mom_line_label.add_theme_font_override("font", VCR_FONT)
	mom_line_label.add_theme_font_size_override("font_size", 16)
	mom_line_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.92))
	content.add_child(mom_line_label)

	_score_label = Label.new()
	_score_label.name = "FinalScoreLabel"
	_score_label.text = "Final Score: 0"
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_override("font", VCR_FONT)
	_score_label.add_theme_font_size_override("font_size", 24)
	_score_label.add_theme_color_override("font_color", Color.WHITE)
	content.add_child(_score_label)

	var goal_label := Label.new()
	goal_label.name = "GoalLabel"
	goal_label.text = "Goal: %d pts" % target_score if target_score > 0 else ""
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal_label.add_theme_font_override("font", VCR_FONT)
	goal_label.add_theme_font_size_override("font_size", 18)
	goal_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.45) if challenge_completed else Color(1.0, 0.45, 0.45))
	content.add_child(goal_label)

	var button_row := HBoxContainer.new()
	button_row.name = "ButtonRow"
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 10)
	content.add_child(button_row)

	button_row.add_child(_create_action_button("New Game", "new_game", Vector2(120, 44), Color(0.35, 0.75, 0.65)))
	if challenge_completed:
		button_row.add_child(_create_action_button("Continue", "continue", Vector2(110, 44), Color(0.95, 0.72, 0.25)))
	button_row.add_child(_create_action_button("Quit", "quit", Vector2(90, 44), Color(0.85, 0.35, 0.4)))


func _apply_panel_style(challenge_completed: bool) -> void:
	var panel_theme := load("res://Resources/UI/powerup_hover_theme.tres") as Theme
	if panel_theme:
		_panel.theme = panel_theme
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.16, 0.98)
	style.border_color = Color(0.95, 0.72, 0.25) if challenge_completed else Color(0.8, 0.25, 0.3)
	style.set_border_width_all(4)
	style.set_corner_radius_all(int(PANEL_CORNER_RADIUS))
	style.corner_detail = 8
	style.shadow_color = Color(0.07, 0.06, 0.1, 0.45)
	style.shadow_size = 8
	style.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", style)


func _apply_portrait_frame_style(frame: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.15, 0.25)
	style.border_color = Color(0.5, 0.4, 0.6)
	style.set_border_width_all(int(PORTRAIT_BORDER_WIDTH))
	style.set_corner_radius_all(5)
	style.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", style)


func _create_action_button(text: String, action: String, button_size: Vector2, accent: Color) -> GlassActionButton:
	var palette := GlassButtonFactoryScript.build_palette(
		accent.darkened(0.58),
		accent.darkened(0.32),
		accent,
		accent.lightened(0.18),
		Color(0.968627, 0.941176, 1.0),
		Color(0.968627, 0.941176, 1.0),
		Color(0.129412, 0.121569, 0.2),
		1
	)
	var button := GlassActionButtonScript.new()
	button.name = "%sButton" % action.to_pascal_case()
	button.configure(text, button_size, palette, 16, VCR_FONT)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_on_action_pressed.bind(action))
	_action_buttons.append(button)
	return button


func _resolve_mom_reaction(challenge_completed: bool) -> Dictionary:
	var lines: Array[String] = LOW_REP_LINES
	var expression := "happy"
	if challenge_completed:
		lines = VICTORY_LINES
	else:
		var rep := 0
		var progress_manager := get_node_or_null("/root/ProgressManager")
		if progress_manager and progress_manager.has_method("get_rep"):
			rep = int(progress_manager.get_rep())
		if rep >= 60:
			lines = HIGH_REP_LINES
			expression = "upset"
		elif rep >= 30:
			lines = MEDIUM_REP_LINES
			expression = "neutral"
		else:
			var game_controller := get_tree().get_first_node_in_group("game_controller")
			if game_controller:
				var active_debuffs = game_controller.get("active_debuffs")
				if active_debuffs is Dictionary and active_debuffs.has("teacher_pet"):
					lines = LOW_REP_LINES
					expression = "happy"
	var line_index := GameRNG.randi_range(0, lines.size() - 1)
	return {"line": lines[line_index], "expression": expression}


func _apply_mom_mood() -> void:
	var game_controller := get_tree().get_first_node_in_group("game_controller")
	if game_controller == null:
		return
	var chores_manager = game_controller.get("chores_manager")
	if chores_manager:
		_portrait.set_mood(int(chores_manager.mom_mood))


func _create_backdrop_fx_rect() -> void:
	_backdrop_fx_rect = ColorRect.new()
	_backdrop_fx_rect.name = "BackdropFxRect"
	_backdrop_fx_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop_fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop_fx_rect.color = Color.WHITE
	var shader := load(BACKDROP_SHADER_PATH) as Shader
	if shader:
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("corner_radius", PANEL_CORNER_RADIUS)
		_backdrop_fx_rect.material = material
	else:
		push_error("[GameOverPanel] Failed to load shader: " + BACKDROP_SHADER_PATH)
	_panel.add_child(_backdrop_fx_rect)
	_panel.move_child(_backdrop_fx_rect, 0)
	_update_backdrop_fx_size()


func _update_backdrop_fx_size() -> void:
	if _backdrop_fx_rect == null or _backdrop_fx_rect.material == null or _panel == null:
		return
	var panel_size := _panel.size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		panel_size = _panel.custom_minimum_size
	(_backdrop_fx_rect.material as ShaderMaterial).set_shader_parameter("rect_size", panel_size)


func _animate_entrance(final_score: int) -> void:
	await get_tree().process_frame
	if _panel == null or _is_exiting:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	_panel.position = (viewport_size - _panel.size) / 2.0
	_panel.pivot_offset = _panel.size / 2.0
	var target_position := _panel.position
	_panel.position = target_position - Vector2(0, 48)
	_panel.scale = Vector2(1.1, 0.9)
	_panel.modulate.a = 0.0

	_entrance_tween = create_tween().set_parallel(true)
	_entrance_tween.tween_property(_overlay, "color:a", 0.75, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(_panel, "position", target_position, 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_entrance_tween.parallel().tween_property(_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_entrance_tween.parallel().tween_property(_panel, "modulate:a", 1.0, 0.2)
	await _entrance_tween.finished
	if _is_exiting or _score_label == null:
		return

	_count_tween = create_tween()
	_count_tween.tween_method(
		func(value: float):
			if _score_label:
				_score_label.text = "Final Score: %d" % int(value),
		0.0,
		float(final_score),
		1.0
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_action_pressed(action: String) -> void:
	if _is_exiting:
		return
	_is_exiting = true
	for button in _action_buttons:
		if is_instance_valid(button):
			button.disabled = true
	if _entrance_tween and _entrance_tween.is_valid():
		_entrance_tween.kill()
	if _count_tween and _count_tween.is_valid():
		_count_tween.kill()

	_exit_tween = create_tween().set_parallel(true)
	_exit_tween.tween_property(_panel, "position", _panel.position + Vector2(0, 420), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_exit_tween.parallel().tween_property(_panel, "modulate:a", 0.0, 0.25)
	_exit_tween.parallel().tween_property(_overlay, "color:a", 0.0, 0.3)
	await _exit_tween.finished
	visible = false
	match action:
		"new_game":
			new_game_pressed.emit()
		"continue":
			continue_pressed.emit()
		"quit":
			quit_pressed.emit()


func _kill_tweens() -> void:
	for tween in [_entrance_tween, _count_tween, _exit_tween]:
		if tween and tween.is_valid():
			tween.kill()
