extends Control
class_name ChoreUI

## ChoreUI
##
## Displays the chore meter and current task inside the GameUI center column.
## Progress increases by 1 each dice roll and decreases by 20 when tasks complete.
## Uses a compact neon meter in the collapsed state.
## Clicking on the meter opens a centered chore board and fans out completed chore cards.

signal task_clicked

@export var chores_manager_path: NodePath

# Node references
var progress_bar: ProgressBar
var task_label: Label
var details_panel: PanelContainer
var details_label: RichTextLabel
var _compact_shell: PanelContainer
var _chores_manager = null  # ChoresManager - duck typed to avoid class resolution issues

# Fan-out state
enum State { SPINE, FANNED }
var _current_state: State = State.SPINE
var _background: ColorRect = null
var _fanned_cards: Array[Control] = []
var _is_animating: bool = false
var _fan_center: Vector2
var _compact_hover_tween: Tween

# Visual settings
const BAR_WIDTH: float = 156.0
const BAR_HEIGHT: float = 18.0
const DANGER_THRESHOLD: float = 80.0
const WARNING_THRESHOLD: float = 60.0
const CHORE_BG: Color = Color(0.247059, 0.219608, 0.345098, 0.9)
const CHORE_BG_SOFT: Color = Color(0.247059, 0.219608, 0.345098, 0.4)
const CHORE_BORDER: Color = Color(0.713725, 0.301961, 0.478431, 0.05)
const CHORE_ACCENT: Color = Color(0.137255, 0.411765, 0.415686, 1.0)
const CHORE_TEXT: Color = Color(0.968627, 0.941176, 1.0, 1.0)
const CHORE_TEXT_SOFT: Color = Color(0.780392, 0.733333, 0.866667, 1.0)
const CHORE_OUTLINE: Color = Color(0.129412, 0.121569, 0.2, 1.0)
const CHORE_DANGER: Color = Color(0.886275, 0.392157, 0.54902, 1.0)
const CHORE_WARNING: Color = Color(0.886275, 0.67451, 0.356863, 1.0)
const CHORE_SAFE: Color = Color(0.47451, 0.886275, 0.890196, 1.0)
const DETAILS_PANEL_SIZE := Vector2(420, 250)
const CARD_SIZE := Vector2(128, 92)
const BAR_CORNER_RADIUS := 9
const BAR_CONTENT_INSET := 2
const CARD_ROW_GAP: float = 68.0
const CARD_SPACING: float = 14.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_create_ui_structure()
	_create_background_overlay()
	_setup_signals()
	_fan_center = get_viewport_rect().size / 2.0
	print("[ChoreUI] Initialized")


func _exit_tree() -> void:
	if _compact_hover_tween and _compact_hover_tween.is_valid():
		_compact_hover_tween.kill()
		_compact_hover_tween = null
	if _background and is_instance_valid(_background):
		_background.queue_free()
	if details_panel and is_instance_valid(details_panel):
		details_panel.queue_free()

## set_chores_manager()
##
## Sets the ChoresManager reference and connects signals.
##
## Parameters:
##   manager: ChoresManager - the ChoresManager instance
func set_chores_manager(manager) -> void:
	if _chores_manager:
		_disconnect_signals()
	
	_chores_manager = manager
	
	if _chores_manager:
		_chores_manager.progress_changed.connect(_on_progress_changed)
		_chores_manager.task_selected.connect(_on_task_selected)
		_chores_manager.task_completed.connect(_on_task_completed)
		if _chores_manager.has_signal("task_rotated"):
			_chores_manager.task_rotated.connect(_on_task_rotated)
		
		# Defer initialization to ensure UI nodes exist
		call_deferred("_initialize_from_manager")
	
	print("[ChoreUI] Connected to ChoresManager")

## _initialize_from_manager()
##
## Deferred initialization after UI is ready.
func _initialize_from_manager() -> void:
	if not _chores_manager:
		return
	
	# Initialize with current values
	_on_progress_changed(_chores_manager.current_progress)
	if _chores_manager.current_task:
		_on_task_selected(_chores_manager.current_task)
		print("[ChoreUI] Initialized with task: %s" % _chores_manager.current_task.display_name)
	else:
		print("[ChoreUI] No initial task available")

func _disconnect_signals() -> void:
	if _chores_manager:
		if _chores_manager.progress_changed.is_connected(_on_progress_changed):
			_chores_manager.progress_changed.disconnect(_on_progress_changed)
		if _chores_manager.task_selected.is_connected(_on_task_selected):
			_chores_manager.task_selected.disconnect(_on_task_selected)
		if _chores_manager.task_completed.is_connected(_on_task_completed):
			_chores_manager.task_completed.disconnect(_on_task_completed)
		if _chores_manager.has_signal("task_rotated") and _chores_manager.task_rotated.is_connected(_on_task_rotated):
			_chores_manager.task_rotated.disconnect(_on_task_rotated)

func _create_ui_structure() -> void:
	custom_minimum_size = Vector2(0, 0)

	var margin = MarginContainer.new()
	margin.name = "MarginContainer"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 1)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 2)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var main_container = VBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	main_container.add_theme_constant_override("separation", 4)
	main_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(main_container)

	_compact_shell = PanelContainer.new()
	_compact_shell.name = "CompactShell"
	_compact_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compact_shell.custom_minimum_size = Vector2(0, 50)
	_compact_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_container.add_child(_compact_shell)
	_apply_compact_shell_style()

	var shell_margin = MarginContainer.new()
	shell_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell_margin.add_theme_constant_override("margin_left", 8)
	shell_margin.add_theme_constant_override("margin_top", 4)
	shell_margin.add_theme_constant_override("margin_right", 8)
	shell_margin.add_theme_constant_override("margin_bottom", 4)
	shell_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compact_shell.add_child(shell_margin)

	var shell_content = VBoxContainer.new()
	shell_content.add_theme_constant_override("separation", 2)
	shell_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell_margin.add_child(shell_content)

	progress_bar = ProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = 0
	progress_bar.show_percentage = false
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	progress_bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_progress_bar_style()
	shell_content.add_child(progress_bar)

	task_label = Label.new()
	task_label.name = "TaskLabel"
	task_label.text = "No active chore"
	task_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	task_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	task_label.add_theme_font_size_override("font_size", 10)
	task_label.add_theme_color_override("font_color", CHORE_TEXT)
	task_label.add_theme_color_override("font_outline_color", CHORE_OUTLINE)
	task_label.add_theme_constant_override("outline_size", 1)
	task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	task_label.custom_minimum_size = Vector2(0, 14)
	task_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell_content.add_child(task_label)

	details_panel = PanelContainer.new()
	details_panel.name = "DetailsPanel"
	details_panel.visible = false
	details_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	details_panel.z_index = 60
	details_panel.custom_minimum_size = DETAILS_PANEL_SIZE
	_apply_panel_style()

	var panel_margin = MarginContainer.new()
	panel_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_margin.add_theme_constant_override("margin_left", 14)
	panel_margin.add_theme_constant_override("margin_top", 12)
	panel_margin.add_theme_constant_override("margin_right", 14)
	panel_margin.add_theme_constant_override("margin_bottom", 12)
	details_panel.add_child(panel_margin)

	var details_vbox = VBoxContainer.new()
	details_vbox.add_theme_constant_override("separation", 8)
	panel_margin.add_child(details_vbox)

	var details_title = Label.new()
	details_title.name = "DetailsTitle"
	details_title.text = "CHORE STATUS"
	details_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details_title.add_theme_font_size_override("font_size", 18)
	details_title.add_theme_color_override("font_color", CHORE_TEXT)
	details_title.add_theme_color_override("font_outline_color", CHORE_OUTLINE)
	details_title.add_theme_constant_override("outline_size", 1)
	details_vbox.add_child(details_title)

	details_label = RichTextLabel.new()
	details_label.name = "DetailsLabel"
	details_label.bbcode_enabled = true
	details_label.fit_content = false
	details_label.scroll_active = false
	details_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_label.custom_minimum_size = Vector2(0, 150)
	details_label.add_theme_color_override("default_color", CHORE_TEXT)
	details_label.add_theme_color_override("font_outline_color", CHORE_OUTLINE)
	details_label.add_theme_constant_override("outline_size", 1)
	details_vbox.add_child(details_label)

	var hint_label = Label.new()
	hint_label.name = "HintLabel"
	hint_label.text = "Click outside to close"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 10)
	hint_label.add_theme_color_override("font_color", CHORE_TEXT_SOFT)
	hint_label.add_theme_color_override("font_outline_color", CHORE_OUTLINE)
	hint_label.add_theme_constant_override("outline_size", 1)
	details_vbox.add_child(hint_label)

	_update_details_with_progress()


func _apply_compact_shell_style() -> void:
	if _compact_shell == null:
		return
	var shell_style = StyleBoxFlat.new()
	shell_style.bg_color = CHORE_BG_SOFT
	shell_style.border_color = CHORE_BORDER
	shell_style.set_border_width_all(2)
	shell_style.set_corner_radius_all(12)
	shell_style.corner_detail = 6
	shell_style.shadow_color = Color(0.070588, 0.062745, 0.101961, 0.35)
	shell_style.shadow_size = 4
	_compact_shell.add_theme_stylebox_override("panel", shell_style)

# we might want to switch this to a TextureProgressBar using textures instead of theme resources
#
func _apply_progress_bar_style() -> void:
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.078431, 0.066667, 0.113725, 0.92)
	bg_style.border_color = CHORE_BORDER.darkened(0.15)
	bg_style.set_border_width_all(2)
	bg_style.set_corner_radius_all(BAR_CORNER_RADIUS)
	bg_style.set_content_margin_all(BAR_CONTENT_INSET)
	progress_bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = CHORE_SAFE
	fill_style.set_corner_radius_all(BAR_CORNER_RADIUS)
	progress_bar.add_theme_stylebox_override("fill", fill_style)

func _apply_panel_style() -> void:
	var theme_res = load("res://Resources/UI/powerup_hover_theme.tres") as Theme
	if theme_res:
		details_panel.theme = theme_res
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = CHORE_BG
	panel_style.border_color = CHORE_BORDER
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(18)
	panel_style.corner_detail = 8
	panel_style.shadow_color = Color(0.070588, 0.062745, 0.101961, 0.45)
	panel_style.shadow_size = 8
	panel_style.set_content_margin_all(10)
	details_panel.add_theme_stylebox_override("panel", panel_style)

func _setup_signals() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func _on_progress_changed(new_value: int) -> void:
	if progress_bar:
		# Update max value based on scaled threshold
		if _chores_manager and _chores_manager.has_method("get_scaled_max_progress"):
			progress_bar.max_value = _chores_manager.get_scaled_max_progress()
		progress_bar.value = new_value
		_update_progress_color(new_value)
		_update_details_with_progress()
	print("[ChoreUI] Progress updated: %d" % new_value)

func _on_task_selected(task) -> void:  # ChoreData - duck typed
	if task == null:
		if task_label:
			task_label.text = "No active chore"
		if details_label:
			_update_details_with_progress()
		return
	
	if task_label:
		task_label.text = task.display_name
	
	_update_details_with_progress()
	
	print("[ChoreUI] Task selected: %s" % task.display_name)

func _on_task_completed(_task) -> void:  # ChoreData - duck typed, unused
	# Flash effect when task completes
	_play_completion_flash()


## _update_details_with_progress()
##
## Updates the expanded chore board with current task info, progress, and expiration timer.
## Shows scaled max progress threshold and rolls until chore expires.
## Expiration text turns red when fewer than 5 rolls remain.
func _update_details_with_progress() -> void:
	if not details_label:
		return
	if not _chores_manager:
		if task_label:
			task_label.text = "No active chore"
		details_label.text = "[center][b]No chore data available[/b][/center]"
		return
	
	var task = _chores_manager.current_task
	var current_progress_val = _chores_manager.current_progress
	var max_progress = 100  # Default
	var completed_count = _chores_manager.completed_chores.size()
	var mood_desc = _chores_manager.get_mood_description() if _chores_manager.has_method("get_mood_description") else "Neutral"
	var mood_emoji = _chores_manager.get_mood_emoji() if _chores_manager.has_method("get_mood_emoji") else "*"
	
	# Get scaled max progress if available
	if _chores_manager.has_method("get_scaled_max_progress"):
		max_progress = _chores_manager.get_scaled_max_progress()
	
	if task:
		if task_label:
			task_label.text = task.display_name
		var expiry_text = "Stable"
		if _chores_manager.has_method("get_rolls_until_expiry"):
			var rolls_left = _chores_manager.get_rolls_until_expiry()
			if rolls_left >= 0:
				if rolls_left < 5:
					expiry_text = "[color=#ff7f9c]Expires in %d rolls[/color]" % rolls_left
				else:
					expiry_text = "Expires in %d rolls" % rolls_left

		details_label.text = "[center][b]%s[/b][/center]\n%s\n\n[color=#c7bbdd]Progress:[/color] %s / %s\n[color=#c7bbdd]Expiry:[/color] %s\n[color=#c7bbdd]Mom Mood:[/color] %s %s (%d/10)\n[color=#c7bbdd]Completed:[/color] %d chore(s)" % [
			task.display_name,
			task.description,
			NumberFormatter.format_int(current_progress_val),
			NumberFormatter.format_int(max_progress),
			expiry_text,
			mood_emoji,
			mood_desc,
			_chores_manager.mom_mood,
			completed_count
		]
	else:
		if task_label:
			task_label.text = "No active chore"
		details_label.text = "[center][b]No active chore[/b][/center]\nTake a breather, but keep an eye on the meter.\n\n[color=#c7bbdd]Progress:[/color] %s / %s\n[color=#c7bbdd]Mom Mood:[/color] %s %s (%d/10)\n[color=#c7bbdd]Completed:[/color] %d chore(s)" % [
			NumberFormatter.format_int(current_progress_val),
			NumberFormatter.format_int(max_progress),
			mood_emoji,
			mood_desc,
			_chores_manager.mom_mood,
			completed_count
		]


func _update_progress_color(value: int) -> void:
	var fill_style = progress_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style == null:
		return
	
	# Create a new stylebox to avoid modifying shared resource
	var new_style = StyleBoxFlat.new()
	new_style.set_corner_radius_all(BAR_CORNER_RADIUS)
	
	if value >= DANGER_THRESHOLD:
		new_style.bg_color = CHORE_DANGER
	elif value >= WARNING_THRESHOLD:
		new_style.bg_color = CHORE_WARNING
	else:
		new_style.bg_color = CHORE_SAFE
	
	progress_bar.add_theme_stylebox_override("fill", new_style)

func _play_completion_flash() -> void:
	# Play completion sound effect
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_method("play_sfx"):
		audio_manager.play_sfx("chore_complete")
	elif audio_manager and audio_manager.has_method("play_ui_sound"):
		audio_manager.play_ui_sound()
	
	# Enhanced flash animation with scale pulse
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Color flash - bright green pulse
	tween.tween_property(progress_bar, "modulate", Color(0.3, 1.0, 0.3), 0.1)
	
	# Scale up for emphasis
	var original_scale = progress_bar.scale
	if original_scale == Vector2.ZERO:
		original_scale = Vector2.ONE
	tween.tween_property(progress_bar, "scale", original_scale * 1.3, 0.1)
	
	# Return to normal
	tween.chain().set_parallel(true)
	tween.tween_property(progress_bar, "modulate", Color.WHITE, 0.3)
	tween.tween_property(progress_bar, "scale", original_scale, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Also play bounce animation on completion
	_play_meter_bounce()
	
	print("[ChoreUI] Chore completed! Playing enhanced feedback animation")

## _on_task_rotated()
##
## Handler for when chores auto-rotate every 20 rolls.
## Plays a bounce animation to indicate the change.
func _on_task_rotated(_task) -> void:
	print("[ChoreUI] Task rotated, playing bounce animation")
	_play_meter_bounce()

## _play_meter_bounce()
##
## Plays a bouncy scale animation on the progress bar to indicate an update.
## Uses elastic easing for a playful bounce effect.
func _play_meter_bounce() -> void:
	if not progress_bar:
		return
	
	# Store original scale
	var original_scale = progress_bar.scale
	if original_scale == Vector2.ZERO:
		original_scale = Vector2.ONE
	
	# Create bounce tween
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	
	# Bounce up then back to normal
	tween.tween_property(progress_bar, "scale", original_scale * 1.15, 0.15)
	tween.tween_property(progress_bar, "scale", original_scale, 0.15)

## _update_details_position()
##
## Keeps the expanded chore board centered inside the viewport.
func _update_details_position() -> void:
	if not details_panel:
		return
	_position_details_panel()

func _on_mouse_entered() -> void:
	if _current_state == State.SPINE:
		_set_compact_hover(true)

func _on_mouse_exited() -> void:
	_set_compact_hover(false)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			task_clicked.emit()
			_play_meter_bounce()
			_toggle_fan_state()


## _create_background_overlay()
##
## Creates the semi-transparent background overlay for fanned state.
func _create_background_overlay() -> void:
	_background = ColorRect.new()
	_background.name = "FanBackground"
	_background.color = Color(0, 0, 0, 0.6)
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	_background.visible = false
	_background.z_index = 50
	
	# Add to scene tree at root level to cover everything
	call_deferred("_add_background_to_scene")


func _add_background_to_scene() -> void:
	var root = get_tree().current_scene
	if root == null:
		return
	if _background and is_instance_valid(_background) and _background.get_parent() == null:
		root.add_child(_background)
	if details_panel and is_instance_valid(details_panel) and details_panel.get_parent() == null:
		root.add_child(details_panel)
	if _background and not _background.gui_input.is_connected(_on_background_clicked):
		_background.gui_input.connect(_on_background_clicked)
	_position_background()
	_position_details_panel()


func _position_background() -> void:
	if not _background or not is_instance_valid(_background):
		return
	
	var viewport_size = get_viewport_rect().size
	_fan_center = viewport_size / 2.0
	_background.position = Vector2.ZERO
	_background.size = viewport_size


func _position_details_panel() -> void:
	if not details_panel or not is_instance_valid(details_panel):
		return
	var viewport_size = get_viewport_rect().size
	details_panel.size = DETAILS_PANEL_SIZE
	details_panel.position = (viewport_size - DETAILS_PANEL_SIZE) * 0.5


func _on_background_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_fold_back_cards()


## _toggle_fan_state()
##
## Toggles between spine and fanned states.
func _toggle_fan_state() -> void:
	if _is_animating:
		return
	
	if _current_state == State.SPINE:
		_fan_out_completed_chores()
	else:
		_fold_back_cards()


## _fan_out_completed_chores()
##
## Displays completed chores and Mom's mood as cards in a fan layout.
func _fan_out_completed_chores() -> void:
	if not _chores_manager:
		return
	
	_is_animating = true
	_current_state = State.FANNED
	_set_compact_hover(false)
	
	# Play fan out sound
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_fan_out()
	
	_update_details_with_progress()
	
	# Show and animate background
	_position_background()
	_position_details_panel()
	_background.visible = true
	_background.modulate.a = 0
	var bg_tween = create_tween()
	bg_tween.tween_property(_background, "modulate:a", 1.0, 0.2)

	# Create cards: Mom's mood card + completed chores
	var cards_to_create: Array = []
	
	# Mom's mood card (always first)
	var mood_card = _create_mood_card()
	cards_to_create.append(mood_card)
	
	# Completed chores cards (with checkmarks)
	for chore in _chores_manager.completed_chores:
		var chore_card = _create_completed_chore_card(chore)
		cards_to_create.append(chore_card)
	
	# If no completed chores, show "No Chores Completed" message
	if _chores_manager.completed_chores.is_empty():
		var no_chores_card = _create_no_chores_card()
		cards_to_create.append(no_chores_card)
	
	# Calculate single-row layout: details panel + cards side by side, all vertically centered
	var viewport_size = get_viewport_rect().size
	var spacing: float = CARD_SPACING
	var total_width: float = DETAILS_PANEL_SIZE.x + spacing
	for _c in cards_to_create:
		total_width += CARD_SIZE.x + spacing
	total_width -= spacing  # remove trailing spacing

	var start_x: float = clampf((viewport_size.x - total_width) * 0.5, 24.0, viewport_size.x - total_width - 24.0)
	var row_center_y: float = viewport_size.y * 0.5
	var details_target_y: float = row_center_y - DETAILS_PANEL_SIZE.y * 0.5
	var cards_target_y: float = row_center_y - CARD_SIZE.y * 0.5

	# Override details panel position for single-row layout
	var panel_target = Vector2(start_x, details_target_y)
	details_panel.position = panel_target - Vector2(0, 70)
	details_panel.modulate.a = 0.0
	details_panel.visible = true
	var panel_tween = create_tween()
	panel_tween.tween_property(details_panel, "position", panel_target, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	panel_tween.parallel().tween_property(details_panel, "modulate:a", 1.0, 0.22)

	# Position and animate cards to the right of the details panel
	var current_x: float = start_x + DETAILS_PANEL_SIZE.x + spacing
	for i in range(cards_to_create.size()):
		var card = cards_to_create[i]
		_background.add_child(card)
		_fanned_cards.append(card)
		var target_pos = Vector2(current_x, cards_target_y)
		_animate_card_fan_in(card, target_pos, 0.08 + i * 0.05)
		current_x += CARD_SIZE.x + spacing

	# Mark animation complete
	await get_tree().create_timer(0.45 + cards_to_create.size() * 0.05).timeout
	_is_animating = false


## _create_mood_card()
##
## Creates a card displaying Mom's current mood.
func _create_mood_card() -> Control:
	var shell = _create_card_shell("MoodCard", CHORE_ACCENT)
	var card = shell["card"] as PanelContainer
	var content = shell["content"] as VBoxContainer

	var title = Label.new()
	title.text = "MOM'S MOOD"
	_style_text_label(title, 11, CHORE_TEXT_SOFT)
	content.add_child(title)

	var emoji_label = Label.new()
	emoji_label.text = _chores_manager.get_mood_emoji() if _chores_manager.has_method("get_mood_emoji") else "*"
	_style_text_label(emoji_label, 22, CHORE_TEXT)
	content.add_child(emoji_label)

	var mood_text = Label.new()
	var mood_desc = _chores_manager.get_mood_description() if _chores_manager.has_method("get_mood_description") else "Neutral"
	mood_text.text = mood_desc + "\n" + str(_chores_manager.mom_mood) + "/10"
	mood_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mood_text.custom_minimum_size = Vector2(0, 20)
	_style_text_label(mood_text, 9, CHORE_TEXT)
	content.add_child(mood_text)

	return card


## _create_completed_chore_card(chore)
##
## Creates a card for a completed chore with a checkmark.
func _create_completed_chore_card(chore) -> Control:
	var card_name = "ChoreCard_" + str(chore.id) if chore else "ChoreCard"
	var shell = _create_card_shell(card_name, CHORE_BORDER)
	var card = shell["card"] as PanelContainer
	var content = shell["content"] as VBoxContainer

	var checkmark = Label.new()
	checkmark.text = "COMPLETE"
	_style_text_label(checkmark, 10, CHORE_SAFE)
	content.add_child(checkmark)

	var name_label = Label.new()
	name_label.text = chore.display_name if chore else "Unknown"
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(0, 28)
	_style_text_label(name_label, 10, CHORE_TEXT)
	content.add_child(name_label)

	var reward_label = Label.new()
	reward_label.text = NumberFormatter.format_money(chore.reward_value if chore else 0)
	_style_text_label(reward_label, 11, CHORE_SAFE)
	content.add_child(reward_label)

	return card


## _create_no_chores_card()
##
## Creates a card indicating no chores have been completed.
func _create_no_chores_card() -> Control:
	var shell = _create_card_shell("NoChoresCard", CHORE_BORDER)
	var card = shell["card"] as PanelContainer
	var content = shell["content"] as VBoxContainer

	var title = Label.new()
	title.text = "COMPLETED CHORES"
	_style_text_label(title, 10, CHORE_TEXT_SOFT)
	content.add_child(title)

	var message = Label.new()
	message.text = "NONE YET"
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size = Vector2(0, 20)
	_style_text_label(message, 12, CHORE_TEXT)
	content.add_child(message)

	var subtext = Label.new()
	subtext.text = "Finish a chore to populate this board."
	subtext.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtext.custom_minimum_size = Vector2(0, 24)
	_style_text_label(subtext, 8, CHORE_TEXT_SOFT)
	content.add_child(subtext)

	return card


## _calculate_fan_positions(count)
##
## Calculates positions for cards in a fan/arc layout.
func _calculate_fan_positions(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	
	if count == 0:
		return positions
	
	var viewport_size = get_viewport_rect().size
	var card_spacing = CARD_SIZE.x + CARD_SPACING
	var total_width = maxf(CARD_SIZE.x, count * card_spacing - 12.0)
	var start_x = clampf(_fan_center.x - total_width * 0.5, 24.0, maxf(24.0, viewport_size.x - total_width - 24.0))
	var panel_bottom = details_panel.position.y + details_panel.size.y if details_panel and details_panel.visible else _fan_center.y + 96.0
	var y = minf(viewport_size.y - CARD_SIZE.y - 24.0, panel_bottom + CARD_ROW_GAP)
	
	for i in range(count):
		var x = start_x + (i * card_spacing)
		positions.append(Vector2(x, y))
	
	return positions


## _animate_card_fan_in(card, target_position, delay)
##
## Animates a card from the meter position to its fan position.
func _animate_card_fan_in(card: Control, target_position: Vector2, delay: float) -> void:
	# Start from this UI's position
	card.position = global_position
	card.modulate.a = 0
	card.scale = Vector2(0.5, 0.5)
	
	# Set pivot for scaling
	card.pivot_offset = card.size / 2.0
	
	var tween = create_tween()
	tween.set_parallel()
	
	tween.tween_property(card, "position", target_position, 0.3)\
		.set_delay(delay)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate:a", 1.0, 0.2)\
		.set_delay(delay)
	tween.tween_property(card, "scale", Vector2.ONE, 0.3)\
		.set_delay(delay)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)


## _fold_back_cards()
##
## Animates cards back and returns to spine state.
func _fold_back_cards() -> void:
	if _is_animating:
		return
	
	_is_animating = true
	
	# Play fan in sound
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_fan_in()
	
	# Animate cards back
	for i in range(_fanned_cards.size()):
		var card = _fanned_cards[i]
		if is_instance_valid(card):
			var tween = create_tween()
			tween.set_parallel()
			tween.tween_property(card, "position", global_position, 0.2)
			tween.tween_property(card, "modulate:a", 0.0, 0.2)
			tween.tween_property(card, "scale", Vector2(0.5, 0.5), 0.2)

	if details_panel and details_panel.visible:
		var panel_tween = create_tween()
		panel_tween.set_parallel()
		panel_tween.tween_property(details_panel, "position", details_panel.position + Vector2(0, 50), 0.2)
		panel_tween.tween_property(details_panel, "modulate:a", 0.0, 0.18)
	
	# Fade out background
	if _background:
		var bg_tween = create_tween()
		bg_tween.tween_property(_background, "modulate:a", 0.0, 0.2)
	
	# Clean up after animation
	await get_tree().create_timer(0.25).timeout
	
	for card in _fanned_cards:
		if is_instance_valid(card):
			card.queue_free()
	_fanned_cards.clear()
	
	if _background:
		_background.visible = false
	if details_panel:
		details_panel.visible = false
		_position_details_panel()
	
	_current_state = State.SPINE
	_is_animating = false


func _set_compact_hover(is_hovered: bool) -> void:
	if _compact_shell == null:
		return
	if _compact_hover_tween and _compact_hover_tween.is_valid():
		_compact_hover_tween.kill()
		_compact_hover_tween = null
	_compact_hover_tween = create_tween()
	var target_modulate = Color(1.08, 1.08, 1.12, 1.0) if is_hovered else Color.WHITE
	_compact_hover_tween.tween_property(_compact_shell, "modulate", target_modulate, 0.18)
	if task_label:
		var task_color = CHORE_SAFE if is_hovered else CHORE_TEXT
		task_label.add_theme_color_override("font_color", task_color)


func _style_text_label(label: Label, font_size: int, font_color: Color) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", CHORE_OUTLINE)
	label.add_theme_constant_override("outline_size", 1)


func _create_card_shell(card_name: String, accent_color: Color) -> Dictionary:
	var card = PanelContainer.new()
	card.name = card_name
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.pivot_offset = CARD_SIZE * 0.5

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.101961, 0.090196, 0.14902, 0.96)
	style.border_color = accent_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.corner_detail = 8
	style.shadow_color = Color(0.070588, 0.062745, 0.101961, 0.45)
	style.shadow_size = 4
	card.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)

	var content = VBoxContainer.new()
	content.name = "ContentVBox"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 4)
	margin.add_child(content)

	return {
		"card": card,
		"content": content
	}
