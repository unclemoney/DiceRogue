extends Control
class_name ChoreUI

## ChoreUI
##
## Displays the chore meter and current task inside the GameUI center column.
## Progress increases by 1 each dice roll and decreases by 20 when tasks complete.
## Uses a TextureProgressBar with generated textures; tints shift with
## progress (fill), Mom's mood (frame), and chore difficulty (track).
## Clicking on the meter opens a centered chore status panel.

signal task_clicked

@export var chores_manager_path: NodePath
## Pixel offset applied to the progress (fill) texture on the meter.
@export var texture_progress_offset: Vector2 = Vector2(67,0)

# Node references
var progress_bar: TextureProgressBar
var task_label: Label
var details_panel: PanelContainer
var details_label: RichTextLabel
var _compact_shell: PanelContainer
var _chores_manager = null  # ChoresManager - duck typed to avoid class resolution issues

# Fan-out state
enum State { SPINE, FANNED }
var _current_state: State = State.SPINE
var _background: ColorRect = null
var _is_animating: bool = false
var _fan_center: Vector2
var _compact_hover_tween: Tween

# Visual settings
const BAR_WIDTH: float = 172.0 #172
const BAR_HEIGHT: float = 32.0
const WARNING_THRESHOLD: float = 60.0
const CHORE_BG_SOFT: Color = Color(0.247059, 0.219608, 0.345098, 0.4)
const CHORE_BORDER: Color = Color(0.713725, 0.301961, 0.478431, 0.05)
const CHORE_ACCENT: Color = Color(0.137255, 0.411765, 0.415686, 1.0)
const CHORE_TEXT: Color = Color(0.968627, 0.941176, 1.0, 1.0)
const CHORE_TEXT_SOFT: Color = Color(0.780392, 0.733333, 0.866667, 1.0)
const CHORE_OUTLINE: Color = Color(0.129412, 0.121569, 0.2, 1.0)
const CHORE_DANGER: Color = Color(0.886275, 0.392157, 0.54902, 1.0)
const CHORE_WARNING: Color = Color(0.886275, 0.67451, 0.356863, 1.0)
const CHORE_SAFE: Color = Color(0.47451, 0.886275, 0.890196, 1.0)
const MOOD_ANGRY: Color = Color(0.886275, 0.301961, 0.34902, 1.0)
const DETAILS_PANEL_SIZE := Vector2(460, 340)
# Bar textures (generated pixel art, 344x64). Tints multiply these, so the
# tintable regions are drawn in light/neutral tones.
const BAR_TEXTURE_UNDER := preload("res://Resources/Art/UI/under-export.png")
const BAR_TEXTURE_PROGRESS := preload("res://Resources/Art/UI/progress-export.png")
const BAR_TEXTURE_OVER := preload("res://Resources/Art/UI/over-export.png")
const BAR_NINE_PATCH_MARGIN: int = 32
# Standard UI font for text not covered by the panel theme (RichTextLabel).
const VCR_FONT := preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
# Subtle alpha levels for the mood (frame) and difficulty (track) tints.
const MOOD_TINT_ALPHA: float = 0.2
const DIFFICULTY_TINT_ALPHA: float = 0.1

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
		if _chores_manager.has_signal("mom_mood_changed"):
			_chores_manager.mom_mood_changed.connect(_on_mom_mood_changed)
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
	_update_mood_tint(_chores_manager.mom_mood)
	_update_difficulty_tint(_chores_manager.current_task)
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
		if _chores_manager.has_signal("mom_mood_changed") and _chores_manager.mom_mood_changed.is_connected(_on_mom_mood_changed):
			_chores_manager.mom_mood_changed.disconnect(_on_mom_mood_changed)
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
	_compact_shell.custom_minimum_size = Vector2(0, 62)
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

	progress_bar = TextureProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = 0
	progress_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	progress_bar.texture_under = BAR_TEXTURE_UNDER
	progress_bar.texture_progress = BAR_TEXTURE_PROGRESS
	progress_bar.texture_over = BAR_TEXTURE_OVER
	progress_bar.texture_progress_offset = texture_progress_offset
	progress_bar.nine_patch_stretch = false
	progress_bar.stretch_margin_left = BAR_NINE_PATCH_MARGIN
	progress_bar.stretch_margin_right = BAR_NINE_PATCH_MARGIN
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	details_label.custom_minimum_size = Vector2(0, 220)
	details_label.add_theme_font_override("normal_font", VCR_FONT)
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

func _apply_panel_style() -> void:
	var theme_res = load("res://Resources/UI/powerup_hover_theme.tres") as Theme
	if theme_res:
		details_panel.theme = theme_res
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.10, 0.14, 0.98)
	panel_style.border_color = Color(0.713725, 0.301961, 0.478431, 1.0)
	panel_style.set_border_width_all(4)
	panel_style.set_corner_radius_all(20)
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
		_update_progress_tint(new_value)
		_update_details_with_progress()
	print("[ChoreUI] Progress updated: %d" % new_value)

func _on_task_selected(task) -> void:  # ChoreData - duck typed
	if task == null:
		if task_label:
			task_label.text = "No active chore"
		_update_difficulty_tint(null)
		if details_label:
			_update_details_with_progress()
		return
	
	if task_label:
		task_label.text = task.display_name
	
	_update_difficulty_tint(task)
	_update_details_with_progress()
	
	print("[ChoreUI] Task selected: %s" % task.display_name)

func _on_task_completed(_task) -> void:  # ChoreData - duck typed, unused
	# Flash effect when task completes
	_play_completion_flash()


## _update_details_with_progress()
##
## Updates the chore status panel with current task info, progress percentage,
## Mom's mood, and counts of completed easy/hard chores.
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
	var mood_desc = _chores_manager.get_mood_description() if _chores_manager.has_method("get_mood_description") else "Neutral"
	var mood_emoji = _chores_manager.get_mood_emoji() if _chores_manager.has_method("get_mood_emoji") else "*"
	
	# Get scaled max progress if available
	if _chores_manager.has_method("get_scaled_max_progress"):
		max_progress = _chores_manager.get_scaled_max_progress()
	var percent := roundi(100.0 * float(current_progress_val) / maxf(float(max_progress), 1.0))
	
	# Count completed chores by difficulty instead of listing names
	var easy_count := 0
	var hard_count := 0
	for chore in _chores_manager.completed_chores:
		if chore and "difficulty" in chore and chore.difficulty == ChoreData.Difficulty.HARD:
			hard_count += 1
		else:
			easy_count += 1
	var completed_text = "[color=#c7bbdd]Completed:[/color] %d easy, %d hard" % [easy_count, hard_count]
	var progress_text = "[color=#c7bbdd]Progress:[/color] %s / %s (%d%%)" % [
		NumberFormatter.format_int(current_progress_val),
		NumberFormatter.format_int(max_progress),
		percent
	]
	var mood_text = "[color=#c7bbdd]Mom Mood:[/color] %s %s (%d/10)" % [
		mood_emoji,
		mood_desc,
		_chores_manager.mom_mood
	]
	
	if task:
		if task_label:
			task_label.text = task.display_name
		var expiry_text = "Expires when this round ends"
		if _chores_manager.has_method("get_rounds_until_expiry") and _chores_manager.get_rounds_until_expiry() <= 0:
			expiry_text = "Awaiting replacement"

		details_label.text = "[center][b]%s[/b][/center]\n%s\n\n%s\n[color=#c7bbdd]Expiry:[/color] %s\n%s\n%s" % [
			task.display_name,
			task.description,
			progress_text,
			expiry_text,
			mood_text,
			completed_text
		]
	else:
		var waiting_for_selection = _chores_manager.pending_chore_selection if _chores_manager.has_method("get_pending_tasks") else false
		if task_label:
			task_label.text = "Choose a chore" if waiting_for_selection else "No active chore"
		var no_task_text = "[center][b]Choose a new chore[/b][/center]\nA fresh chore is required before play continues." if waiting_for_selection else "[center][b]No active chore[/b][/center]\nTake a breather, but keep an eye on the meter."
		details_label.text = "%s\n\n%s\n%s\n%s" % [
			no_task_text,
			progress_text,
			mood_text,
			completed_text
		]


## _update_progress_tint(value)
##
## Shifts tint_progress from safe teal to danger pink as the meter fills.
## Colors are blended toward white so the neon fill texture still reads.
func _update_progress_tint(value: int) -> void:
	if not progress_bar:
		return
	var ratio := clampf(float(value) / maxf(progress_bar.max_value, 1.0), 0.0, 1.0)
	var warn_ratio: float = WARNING_THRESHOLD / 100.0
	var color: Color
	if ratio <= warn_ratio:
		color = CHORE_SAFE.lerp(CHORE_WARNING, ratio / warn_ratio)
	else:
		color = CHORE_WARNING.lerp(CHORE_DANGER, (ratio - warn_ratio) / (1.0 - warn_ratio))
	progress_bar.tint_progress = Color.WHITE.lerp(color, 0.75)

## _on_mom_mood_changed(new_mood)
##
## Signal handler: retints the bar frame to hint at Mom's mood.
func _on_mom_mood_changed(new_mood: int) -> void:
	_update_mood_tint(new_mood)

## _update_mood_tint(mood)
##
## Tints texture_over (the frame) from angry red (mood 0) through neutral
## white (5) to content teal (10). Applied with a very subtle alpha so the
## frame art still reads.
func _update_mood_tint(mood: int) -> void:
	if not progress_bar:
		return
	var color: Color
	if mood <= 5:
		color = MOOD_ANGRY.lerp(Color.WHITE, float(mood) / 5.0)
	else:
		color = Color.WHITE.lerp(CHORE_SAFE, float(mood - 5) / 5.0)
	color = Color.WHITE.lerp(color, 0.7)
	color.a = MOOD_TINT_ALPHA
	progress_bar.tint_over = color

## _update_difficulty_tint(task)
##
## Tints texture_under (the track) by the active chore's difficulty:
## teal for EASY, pink for HARD, neutral when no chore is active.
## Applied with a very subtle alpha so it only ghosts over the track.
func _update_difficulty_tint(task) -> void:  # ChoreData - duck typed
	if not progress_bar:
		return
	if task == null:
		progress_bar.tint_under = Color.WHITE
		return
	var color: Color
	if "difficulty" in task and task.difficulty == ChoreData.Difficulty.HARD:
		color = Color.WHITE.lerp(CHORE_DANGER, 0.7)
	else:
		color = Color.WHITE.lerp(CHORE_ACCENT, 0.7)
	color.a = DIFFICULTY_TINT_ALPHA
	progress_bar.tint_under = color

## get_progress_percent() -> int
##
## Returns the meter fill as a 0-100 percentage for external tooltips.
func get_progress_percent() -> int:
	if not progress_bar or progress_bar.max_value <= 0:
		return 0
	return roundi(100.0 * progress_bar.value / progress_bar.max_value)

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
## Handler for when the active chore expires and a new choice is required.
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
			_close_details_panel()


## _toggle_fan_state()
##
## Toggles between spine and fanned states.
func _toggle_fan_state() -> void:
	if _is_animating:
		return
	
	if _current_state == State.SPINE:
		_open_details_panel()
	else:
		_close_details_panel()


## _open_details_panel()
##
## Shows the centered chore status panel over a dimmed background.
func _open_details_panel() -> void:
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
	_background.visible = true
	_background.modulate.a = 0
	var bg_tween = create_tween()
	bg_tween.tween_property(_background, "modulate:a", 1.0, 0.2)
	
	# Drop the status panel in from above center
	var viewport_size = get_viewport_rect().size
	var panel_target: Vector2 = (viewport_size - DETAILS_PANEL_SIZE) * 0.5
	details_panel.size = DETAILS_PANEL_SIZE
	details_panel.position = panel_target - Vector2(0, 70)
	details_panel.modulate.a = 0.0
	details_panel.visible = true
	var panel_tween = create_tween()
	panel_tween.tween_property(details_panel, "position", panel_target, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	panel_tween.parallel().tween_property(details_panel, "modulate:a", 1.0, 0.22)
	
	# Mark animation complete
	await get_tree().create_timer(0.45).timeout
	_is_animating = false


## _close_details_panel()
##
## Animates the status panel out and returns to spine state.
func _close_details_panel() -> void:
	if _is_animating:
		return
	
	_is_animating = true
	
	# Play fan in sound
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_fan_in()
	
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
