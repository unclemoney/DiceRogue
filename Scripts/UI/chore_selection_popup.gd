extends Control
class_name ChoreSelectionPopup

## ChoreSelectionPopup
##
## Popup panel that lets the player choose between an EASY or HARD chore task.
## Shown at turn end when a chore completes or expires.
## Displays current goof-off meter level, Mom's mood, and task previews.
## Uses powerup_hover_theme for visual consistency.

signal chore_selected(is_hard: bool)

var _overlay: ColorRect
var _panel: PanelContainer
var _chores_manager = null

const EASY_COLOR := Color(0.2, 0.7, 0.3)   # Green for easy
const HARD_COLOR := Color(0.8, 0.2, 0.2)   # Red for hard
const EASY_REDUCTION := 10
const HARD_REDUCTION := 30


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
	_panel.custom_minimum_size = Vector2(460, 340)
	
	var theme_res = load("res://Resources/UI/powerup_hover_theme.tres")
	if theme_res:
		_panel.theme = theme_res
	else:
		_apply_fallback_panel_style()
	
	# Center the panel
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -230
	_panel.offset_top = -170
	_panel.offset_right = 230
	_panel.offset_bottom = 170
	add_child(_panel)
	
	# Content layout
	var vbox = VBoxContainer.new()
	vbox.name = "Content"
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "CHOOSE YOUR NEXT CHORE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(title)
	
	# Status bar: Goof-off meter + Mom's mood
	var status_hbox = HBoxContainer.new()
	status_hbox.add_theme_constant_override("separation", 20)
	status_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(status_hbox)
	
	_add_meter_display(status_hbox)
	_add_mood_display(status_hbox)
	
	# Separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 5)
	vbox.add_child(sep)
	
	# Task choices side by side
	var choices_hbox = HBoxContainer.new()
	choices_hbox.add_theme_constant_override("separation", 15)
	choices_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
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
	var meter_vbox = VBoxContainer.new()
	meter_vbox.add_theme_constant_override("separation", 2)
	parent.add_child(meter_vbox)
	
	var meter_label = Label.new()
	meter_label.text = "Goof-Off Meter"
	meter_label.add_theme_font_size_override("font_size", 12)
	meter_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	meter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meter_vbox.add_child(meter_label)
	
	var progress = ProgressBar.new()
	progress.custom_minimum_size = Vector2(120, 16)
	progress.min_value = 0
	var max_val = 100
	if _chores_manager and _chores_manager.has_method("get_scaled_max_progress"):
		max_val = _chores_manager.get_scaled_max_progress()
	progress.max_value = max_val
	progress.value = _chores_manager.current_progress if _chores_manager else 0
	progress.show_percentage = false
	
	# Style the progress bar
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.15, 0.15)
	bg.set_corner_radius_all(3)
	progress.add_theme_stylebox_override("background", bg)
	
	var fill = StyleBoxFlat.new()
	var percent = float(progress.value) / float(max_val) if max_val > 0 else 0.0
	if percent >= 0.8:
		fill.bg_color = Color(0.8, 0.2, 0.2)
	elif percent >= 0.6:
		fill.bg_color = Color(0.8, 0.6, 0.2)
	else:
		fill.bg_color = Color(0.2, 0.7, 0.2)
	fill.set_corner_radius_all(3)
	progress.add_theme_stylebox_override("fill", fill)
	meter_vbox.add_child(progress)
	
	var value_label = Label.new()
	value_label.text = "%d / %d" % [progress.value, max_val]
	value_label.add_theme_font_size_override("font_size", 10)
	value_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meter_vbox.add_child(value_label)


## _add_mood_display(parent)
##
## Adds Mom's mood indicator to the popup.
func _add_mood_display(parent: Control) -> void:
	var mood_vbox = VBoxContainer.new()
	mood_vbox.add_theme_constant_override("separation", 2)
	parent.add_child(mood_vbox)
	
	var mood_title = Label.new()
	mood_title.text = "Mom's Mood"
	mood_title.add_theme_font_size_override("font_size", 12)
	mood_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	mood_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mood_vbox.add_child(mood_title)
	
	var emoji_label = Label.new()
	if _chores_manager and _chores_manager.has_method("get_mood_emoji"):
		emoji_label.text = _chores_manager.get_mood_emoji()
	else:
		emoji_label.text = "😐"
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.add_theme_font_size_override("font_size", 28)
	mood_vbox.add_child(emoji_label)
	
	var mood_desc = Label.new()
	if _chores_manager and _chores_manager.has_method("get_mood_description"):
		mood_desc.text = "%s (%d/10)" % [_chores_manager.get_mood_description(), _chores_manager.mom_mood]
	else:
		mood_desc.text = "Neutral (5/10)"
	mood_desc.add_theme_font_size_override("font_size", 10)
	mood_desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
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
	card.custom_minimum_size = Vector2(200, 160)
	
	# Card background
	var card_style = StyleBoxFlat.new()
	var accent_color = HARD_COLOR if is_hard else EASY_COLOR
	card_style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	card_style.border_color = accent_color
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(8)
	card_style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", card_style)
	
	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 6)
	card.add_child(card_vbox)
	
	# Difficulty badge
	var badge = Label.new()
	badge.text = "⚡ HARD" if is_hard else "✿ EASY"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 16)
	badge.add_theme_color_override("font_color", accent_color)
	card_vbox.add_child(badge)
	
	# Task name
	var name_label = Label.new()
	name_label.text = task.display_name if task else "Unknown"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	card_vbox.add_child(name_label)
	
	# Task description
	var desc_label = Label.new()
	desc_label.text = task.description if task else ""
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size = Vector2(180, 0)
	card_vbox.add_child(desc_label)
	
	# Reduction amount
	var reduction = HARD_REDUCTION if is_hard else EASY_REDUCTION
	var reduction_label = Label.new()
	reduction_label.text = "Meter -%d" % reduction
	reduction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reduction_label.add_theme_font_size_override("font_size", 13)
	reduction_label.add_theme_color_override("font_color", accent_color)
	card_vbox.add_child(reduction_label)
	
	# Select button
	var button = Button.new()
	button.text = "SELECT"
	button.custom_minimum_size = Vector2(120, 30)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_on_task_selected.bind(is_hard))
	
	# Button style
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = accent_color.darkened(0.3)
	btn_style.set_corner_radius_all(5)
	btn_style.set_content_margin_all(4)
	button.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = accent_color
	btn_hover.set_corner_radius_all(5)
	btn_hover.set_content_margin_all(4)
	button.add_theme_stylebox_override("hover", btn_hover)
	
	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = accent_color.darkened(0.5)
	btn_pressed.set_corner_radius_all(5)
	btn_pressed.set_content_margin_all(4)
	button.add_theme_stylebox_override("pressed", btn_pressed)
	
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
## Plays entrance animation for the popup.
func _animate_in() -> void:
	if _overlay:
		_overlay.modulate.a = 0
	if _panel:
		_panel.modulate.a = 0
		_panel.scale = Vector2(0.8, 0.8)
		_panel.pivot_offset = _panel.size / 2.0
	
	var tween = create_tween()
	tween.set_parallel()
	if _overlay:
		tween.tween_property(_overlay, "modulate:a", 1.0, 0.2)
	if _panel:
		tween.tween_property(_panel, "modulate:a", 1.0, 0.2)
		tween.tween_property(_panel, "scale", Vector2.ONE, 0.3)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## _animate_out()
##
## Plays exit animation and hides the popup.
func _animate_out() -> void:
	var tween = create_tween()
	tween.set_parallel()
	if _overlay:
		tween.tween_property(_overlay, "modulate:a", 0.0, 0.15)
	if _panel:
		tween.tween_property(_panel, "modulate:a", 0.0, 0.15)
		tween.tween_property(_panel, "scale", Vector2(0.8, 0.8), 0.15)
	
	tween.chain().tween_callback(_on_animation_finished)


func _on_animation_finished() -> void:
	visible = false
	# Clean up children
	for child in get_children():
		child.queue_free()


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
