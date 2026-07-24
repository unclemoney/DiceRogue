extends Control
class_name ChoreSelectionPopup

const GlassActionButtonClass = preload("res://Scripts/UI/glass_action_button.gd")

## ChoreSelectionPopup
##
## Popup panel that lets the player choose between an EASY or HARD chore task.
## Shown when a chore needs replacement, either mid-round or at round start.
## Displays current goof-off meter level, Mom's mood, and task previews.
## Uses powerup_hover_theme for visual consistency.

signal chore_selected(is_hard: bool)
signal popup_dismissed  # Emitted after _animate_out() and _on_animation_finished() complete

var _overlay: ColorRect
var _panel: PanelContainer
var _backdrop_fx_rect: ColorRect
var _chores_manager = null
var _panel_original_pos: Vector2 = Vector2.ZERO

const PANEL_BG := Color(0.247059, 0.219608, 0.345098, 0.98)
const PANEL_BG_SOFT := Color(0.247059, 0.219608, 0.345098, 0.55)
const PANEL_BORDER := Color(0.713725, 0.301961, 0.478431, 1.0)
const PANEL_TEXT := Color(0.968627, 0.941176, 1.0, 1.0)
const PANEL_TEXT_SOFT := Color(0.780392, 0.733333, 0.866667, 1.0)
const PANEL_OUTLINE := Color(0.129412, 0.121569, 0.2, 1.0)
const PANEL_ACCENT := Color(0.137255, 0.411765, 0.415686, 1.0)
const EASY_COLOR := Color(0.47451, 0.886275, 0.890196, 1.0)
const HARD_COLOR := Color(0.886275, 0.392157, 0.54902, 1.0)

const BACKDROP_SHADER_PATH := "res://Scripts/Shaders/panel_backdrop.gdshader"
const PANEL_CORNER_RADIUS := 20.0

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100


## show_popup(chores_manager)
##
## Shows the chore selection popup with EASY/HARD options.
## Displays goof-off meter progress, Mom's mood, and task previews.
## @param chores_manager: The ChoresManager instance
func show_popup(chores_manager) -> void:
	_chores_manager = chores_manager
	if not _chores_manager:
		push_error("[ChoreSelectionPopup] No ChoresManager provided")
		return
	
	var pending = _chores_manager.get_pending_tasks()
	if not pending["easy"] and not pending["hard"]:
		push_error("[ChoreSelectionPopup] No pending tasks to choose from")
		return
	
	_build_ui(pending["easy"], pending["hard"])
	visible = true
	_animate_in()
	print("[ChoreSelectionPopup] Popup shown with EASY/HARD options")


## _build_ui(easy_task, hard_task)
##
## Builds the popup UI elements dynamically.
## @param easy_task: ChoreData for the EASY option
## @param hard_task: ChoreData for the HARD option
func _build_ui(easy_task, hard_task) -> void:
	# Clear previous content
	for child in get_children():
		child.queue_free()
	
	# Semi-transparent overlay
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	
	# Main panel with powerup_hover_theme
	_panel = PanelContainer.new()
	_panel.name = "MainPanel"
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(500, 388)
	
	var theme_res = load("res://Resources/UI/powerup_hover_theme.tres")
	if theme_res:
		_panel.theme = theme_res
	_apply_popup_panel_style()
	
	# Center the panel
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -250
	_panel.offset_top = -194
	_panel.offset_right = 250
	_panel.offset_bottom = 194
	add_child(_panel)
	
	# Shader backdrop behind all panel content (gradient, vignette, grain, sheen)
	_backdrop_fx_rect = _create_backdrop_fx_rect()
	_panel.resized.connect(_update_backdrop_fx_size)
	
	# Content layout
	var margin = MarginContainer.new()
	margin.name = "PanelMargin"
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.name = "Content"
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "CHOOSE YOUR NEXT CHORE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", PANEL_TEXT)
	title.add_theme_color_override("font_outline_color", PANEL_OUTLINE)
	title.add_theme_constant_override("outline_size", 1)
	vbox.add_child(title)
	
	# Status bar: Goof-off meter + Mom's mood
	var status_hbox = HBoxContainer.new()
	status_hbox.add_theme_constant_override("separation", 14)
	status_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	status_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(status_hbox)
	
	_add_meter_display(status_hbox)
	_add_mood_display(status_hbox)
	
	# Separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 5)
	vbox.add_child(sep)
	
	# Task choices side by side
	var choices_hbox = HBoxContainer.new()
	choices_hbox.add_theme_constant_override("separation", 16)
	choices_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	choices_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(choices_hbox)
	
	# EASY option
	if easy_task:
		var easy_card = _create_task_card(easy_task, false)
		choices_hbox.add_child(easy_card)
	
	# HARD option
	if hard_task:
		var hard_card = _create_task_card(hard_task, true)
		choices_hbox.add_child(hard_card)


## _add_meter_display(parent)
##
## Adds goof-off meter progress display to the popup.
func _add_meter_display(parent: Control) -> void:
	var shell = PanelContainer.new()
	shell.custom_minimum_size = Vector2(180, 78)
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_status_shell_style(shell, PANEL_BORDER)
	parent.add_child(shell)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	shell.add_child(margin)

	var meter_vbox = VBoxContainer.new()
	meter_vbox.add_theme_constant_override("separation", 2)
	margin.add_child(meter_vbox)
	
	var meter_label = Label.new()
	meter_label.text = "Goof-Off Meter"
	meter_label.add_theme_font_size_override("font_size", 12)
	meter_label.add_theme_color_override("font_color", PANEL_TEXT_SOFT)
	meter_label.add_theme_color_override("font_outline_color", PANEL_OUTLINE)
	meter_label.add_theme_constant_override("outline_size", 1)
	meter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meter_vbox.add_child(meter_label)
	
	var progress = ProgressBar.new()
	progress.custom_minimum_size = Vector2(144, 16)
	progress.min_value = 0
	var max_val = 100
	if _chores_manager and _chores_manager.has_method("get_scaled_max_progress"):
		max_val = _chores_manager.get_scaled_max_progress()
	progress.max_value = max_val
	progress.value = _chores_manager.current_progress if _chores_manager else 0
	progress.show_percentage = false
	
	# Style the progress bar
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.078431, 0.066667, 0.113725, 0.92)
	bg.border_color = PANEL_BORDER.darkened(0.15)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(8)
	bg.set_content_margin_all(2)
	progress.add_theme_stylebox_override("background", bg)
	
	var fill = StyleBoxFlat.new()
	var percent = float(progress.value) / float(max_val) if max_val > 0 else 0.0
	if percent >= 0.8:
		fill.bg_color = HARD_COLOR
	elif percent >= 0.6:
		fill.bg_color = Color(0.886275, 0.67451, 0.356863, 1.0)
	else:
		fill.bg_color = EASY_COLOR
	fill.set_corner_radius_all(8)
	progress.add_theme_stylebox_override("fill", fill)
	meter_vbox.add_child(progress)
	
	var value_label = Label.new()
	value_label.text = "%s / %s" % [NumberFormatter.format_int(progress.value), NumberFormatter.format_int(max_val)]
	value_label.add_theme_font_size_override("font_size", 10)
	value_label.add_theme_color_override("font_color", PANEL_TEXT_SOFT)
	value_label.add_theme_color_override("font_outline_color", PANEL_OUTLINE)
	value_label.add_theme_constant_override("outline_size", 1)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meter_vbox.add_child(value_label)


## _add_mood_display(parent)
##
## Adds Mom's mood indicator to the popup.
func _add_mood_display(parent: Control) -> void:
	var shell = PanelContainer.new()
	shell.custom_minimum_size = Vector2(180, 78)
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_status_shell_style(shell, PANEL_ACCENT)
	parent.add_child(shell)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	shell.add_child(margin)

	var mood_vbox = VBoxContainer.new()
	mood_vbox.add_theme_constant_override("separation", 2)
	margin.add_child(mood_vbox)
	
	var mood_title = Label.new()
	mood_title.text = "Mom's Mood"
	mood_title.add_theme_font_size_override("font_size", 12)
	mood_title.add_theme_color_override("font_color", PANEL_TEXT_SOFT)
	mood_title.add_theme_color_override("font_outline_color", PANEL_OUTLINE)
	mood_title.add_theme_constant_override("outline_size", 1)
	mood_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mood_vbox.add_child(mood_title)
	
	var emoji_label = Label.new()
	if _chores_manager and _chores_manager.has_method("get_mood_emoji"):
		emoji_label.text = _chores_manager.get_mood_emoji()
	else:
		emoji_label.text = "😐"
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.add_theme_font_size_override("font_size", 24)
	emoji_label.add_theme_color_override("font_outline_color", PANEL_OUTLINE)
	emoji_label.add_theme_constant_override("outline_size", 1)
	mood_vbox.add_child(emoji_label)
	
	var mood_desc = Label.new()
	if _chores_manager and _chores_manager.has_method("get_mood_description"):
		mood_desc.text = "%s (%s/10)" % [_chores_manager.get_mood_description(), NumberFormatter.format_int(_chores_manager.mom_mood)]
	else:
		mood_desc.text = "Neutral (5/10)"
	mood_desc.add_theme_font_size_override("font_size", 10)
	mood_desc.add_theme_color_override("font_color", PANEL_TEXT_SOFT)
	mood_desc.add_theme_color_override("font_outline_color", PANEL_OUTLINE)
	mood_desc.add_theme_constant_override("outline_size", 1)
	mood_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mood_vbox.add_child(mood_desc)


## _create_task_card(task, is_hard)
##
## Creates a selectable card for a chore task option.
## @param task: ChoreData instance
## @param is_hard: Whether this is the HARD option
## @return Control: The task card
func _create_task_card(task, is_hard: bool) -> Control:
	var card = PanelContainer.new()
	card.name = "HardCard" if is_hard else "EasyCard"
	card.custom_minimum_size = Vector2(212, 224)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Card background
	var card_style = StyleBoxFlat.new()
	var accent_color = HARD_COLOR if is_hard else EASY_COLOR
	card_style.bg_color = Color(0.101961, 0.090196, 0.14902, 0.96)
	card_style.border_color = accent_color
	card_style.set_border_width_all(3)
	card_style.set_corner_radius_all(16)
	card_style.corner_detail = 8
	card_style.shadow_color = Color(0.070588, 0.062745, 0.101961, 0.45)
	card_style.shadow_size = 4
	card.add_theme_stylebox_override("panel", card_style)
	
	var card_margin = MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 12)
	card_margin.add_theme_constant_override("margin_right", 12)
	card_margin.add_theme_constant_override("margin_top", 12)
	card_margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(card_margin)

	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 7)
	card_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_margin.add_child(card_vbox)
	
	# Difficulty badge
	var badge = Label.new()
	badge.text = "HARD" if is_hard else "EASY"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 16)
	badge.add_theme_color_override("font_color", accent_color)
	badge.add_theme_color_override("font_outline_color", PANEL_OUTLINE)
	badge.add_theme_constant_override("outline_size", 1)
	card_vbox.add_child(badge)
	
	# Task name
	var name_label = Label.new()
	name_label.text = task.display_name if task else "Unknown"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", PANEL_TEXT)
	name_label.add_theme_color_override("font_outline_color", PANEL_OUTLINE)
	name_label.add_theme_constant_override("outline_size", 1)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(0, 34)
	card_vbox.add_child(name_label)
	
	# Task description
	var desc_label = RichTextLabel.new()
	desc_label.text = task.description if task else ""
	desc_label.fit_content = false
	desc_label.scroll_active = false
	desc_label.bbcode_enabled = false
	desc_label.custom_minimum_size = Vector2(0, 58)
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.add_theme_font_size_override("normal_font_size", 11)
	desc_label.add_theme_color_override("default_color", PANEL_TEXT_SOFT)
	desc_label.add_theme_color_override("font_outline_color", PANEL_OUTLINE)
	desc_label.add_theme_constant_override("outline_size", 1)
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_vbox.add_child(desc_label)

	# Reward amount
	var reward = task.reward_value if task else 0
	var reward_label = Label.new()
	reward_label.text = "Reward: $" + NumberFormatter.format_int(reward)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.add_theme_font_size_override("font_size", 13)
	reward_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	reward_label.add_theme_color_override("font_outline_color", PANEL_OUTLINE)
	reward_label.add_theme_constant_override("outline_size", 1)
	card_vbox.add_child(reward_label)

	# Reduction amount (per-chore value from the task itself)
	var reduction = task.get_progress_reduction() if task else 0
	var reduction_label = Label.new()
	reduction_label.text = "Meter -%s" % NumberFormatter.format_int(reduction)
	reduction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reduction_label.add_theme_font_size_override("font_size", 12)
	reduction_label.add_theme_color_override("font_color", accent_color)
	reduction_label.add_theme_color_override("font_outline_color", PANEL_OUTLINE)
	reduction_label.add_theme_constant_override("outline_size", 1)
	card_vbox.add_child(reduction_label)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_vbox.add_child(spacer)
	
	# Select button
	var button = GlassActionButtonClass.new()
	button.configure(
		"SELECT CHORE",
		Vector2(0, 34),
		{
			"base_color": accent_color.darkened(0.28),
			"mid_color": accent_color,
			"accent_color": accent_color,
			"glow_color": accent_color.lightened(0.15),
			"rim_color": PANEL_TEXT,
			"font_color": PANEL_TEXT,
			"font_outline_color": PANEL_OUTLINE,
			"outline_size": 1
		},
		14
	)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_task_selected.bind(is_hard))
	
	card_vbox.add_child(button)
	
	return card


## _on_task_selected(is_hard: bool)
##
## Handles the player's chore selection.
func _on_task_selected(is_hard: bool) -> void:
	print("[ChoreSelectionPopup] Player selected: %s" % ("HARD" if is_hard else "EASY"))
	chore_selected.emit(is_hard)
	_animate_out()


## _animate_in()
##
## Plays a smooth drop-in entrance animation for the popup.
## Overlay fades in while the panel settles into place without scale distortion.
func _animate_in() -> void:
	if _overlay:
		_overlay.modulate.a = 0.0
	if _panel:
		await get_tree().process_frame
		_panel_original_pos = _panel.position
		_panel.modulate.a = 0.0
		_panel.position = _panel_original_pos - Vector2(0, 240)

	var tween = create_tween()
	if _overlay:
		tween.parallel().tween_property(_overlay, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _panel:
		tween.parallel().tween_property(_panel, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(_panel, "position", _panel_original_pos + Vector2(0, 12), 0.46).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(_panel, "position", _panel_original_pos, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished


## _animate_out()
##
## Plays fly-off exit animation — panel flies downward and fades.
func _animate_out() -> void:
	var tween = create_tween()
	if _panel:
		tween.parallel().tween_property(_panel, "position:y", _panel_original_pos.y + 260.0, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(_panel, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _overlay:
		tween.parallel().tween_property(_overlay, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished

	_on_animation_finished()


func _on_animation_finished() -> void:
	visible = false
	# Clean up children
	for child in get_children():
		child.queue_free()
	popup_dismissed.emit()


## _apply_fallback_panel_style()
##
## Applies a fallback style if powerup_hover_theme is not found.
func _apply_fallback_panel_style() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.border_color = Color(0.5, 0.4, 0.2)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(15)
	_panel.add_theme_stylebox_override("panel", style)


func _apply_popup_panel_style() -> void:
	if _panel == null:
		return
	var style = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(4)
	style.set_corner_radius_all(20)
	style.corner_detail = 8
	style.shadow_color = Color(0.070588, 0.062745, 0.101961, 0.45)
	style.shadow_size = 8
	_panel.add_theme_stylebox_override("panel", style)


func _apply_status_shell_style(shell: PanelContainer, accent_color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = PANEL_BG_SOFT
	style.border_color = accent_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.corner_detail = 6
	shell.add_theme_stylebox_override("panel", style)



## _create_backdrop_fx_rect() -> ColorRect
##
## Builds a full-rect ColorRect with the panel backdrop shader and inserts it
## as the panel's first child so content draws on top.
func _create_backdrop_fx_rect() -> ColorRect:
	var fx_rect := ColorRect.new()
	fx_rect.name = "BackdropFxRect"
	fx_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_rect.color = Color.WHITE
	var shader := load(BACKDROP_SHADER_PATH) as Shader
	if shader:
		var fx_material := ShaderMaterial.new()
		fx_material.shader = shader
		fx_material.set_shader_parameter("corner_radius", PANEL_CORNER_RADIUS)
		fx_rect.material = fx_material
	else:
		push_error("[ChoreSelectionPopup] Failed to load shader: " + BACKDROP_SHADER_PATH)
	_panel.add_child(fx_rect)
	_panel.move_child(fx_rect, 0)
	_backdrop_fx_rect = fx_rect
	_update_backdrop_fx_size()
	return fx_rect


## _update_backdrop_fx_size()
##
## Pushes the panel's current size into the backdrop shader so its rounded
## mask tracks layout. Connected to the panel's resized signal.
func _update_backdrop_fx_size() -> void:
	if _backdrop_fx_rect == null or _backdrop_fx_rect.material == null or _panel == null:
		return
	var panel_size := _panel.size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		panel_size = _panel.custom_minimum_size
	(_backdrop_fx_rect.material as ShaderMaterial).set_shader_parameter("rect_size", panel_size)
