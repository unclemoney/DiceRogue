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
var buff_icon_row: PanelContainer
var buff_detail_row: HBoxContainer
var _buff_icon_box: HBoxContainer
var _compact_shell: PanelContainer
var _chores_manager = null  # ChoresManager - duck typed to avoid class resolution issues

# Buff icon state (e.g. the Rebellion buff lives here, not in the Debuff UI)
var _buff_icons: Dictionary = {}         # id -> DebuffIcon (compact chip)
var _buff_instances: Dictionary = {}     # id -> Debuff (live buff instance)
var _buff_detail_icons: Dictionary = {}  # id -> DebuffIcon (fan-out chip)
var _buff_detail_labels: Dictionary = {} # id -> Label (fan-out name/stacks)
var _buff_chip_config = null             # DebuffVisualConfig for compact chips
var _buff_detail_config = null           # DebuffVisualConfig for fan-out chips

# Fan-out state
enum State { SPINE, FANNED }
var _current_state: State = State.SPINE
var _background: ColorRect = null
var _is_animating: bool = false
var _fan_center: Vector2
var _compact_hover_tween: Tween

# Visual settings
const BAR_WIDTH: float = 118.0 # narrowed so the 84px buff slot fits the panel
const BAR_HEIGHT: float = 26.0
const WARNING_THRESHOLD: float = 60.0
const CHORE_BG_SOFT: Color = Color(0.247059, 0.219608, 0.345098, 0.4)
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
const BAR_TEXTURE_UNDER : CompressedTexture2D = preload("res://Resources/Art/UI/under-export.png")
const BAR_TEXTURE_PROGRESS : CompressedTexture2D = preload("res://Resources/Art/UI/progress-export.png")
const BAR_TEXTURE_OVER : CompressedTexture2D = preload("res://Resources/Art/UI/over-export.png")
const BAR_NINE_PATCH_MARGIN: int = 32
# Standard UI font for text not covered by the panel theme (RichTextLabel).
const VCR_FONT := preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
# Buff chips reuse the DebuffIcon scene so the SDF glyph shader renders
# identically to the Debuff UI.
const DEBUFF_ICON_SCENE: PackedScene = preload("res://Scenes/Debuff/DebuffIcon.tscn")
const DebuffVisualConfigScript = preload("res://Scripts/Debuff/debuff_visual_config.gd")
# Buff chip sizing (smaller than the Debuff UI slots).
const BUFF_CHIP_SIZE := Vector2(82, 86)
const BUFF_DETAIL_CHIP_SIZE := Vector2(44, 48)
# Reserved slot around the buff chip; matches the Debuff UI's translucent
# empty-slot look (bg 0.12/0.10/0.14 @ 0.3, border 0.3/0.25/0.35 @ 0.15).
# It expands vertically to fill the shell, so this is only the minimum.
const BUFF_SLOT_SIZE := Vector2(84, 44)
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
	# No outer margins: the compact shell fills the parent ChoreMeterContainer
	# edge to edge (the container's own purple border is the frame).
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
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
	_compact_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_compact_shell.custom_minimum_size = Vector2(0, 84)
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

	# Shell row: meter column (bar + task label) on the left, buff slot on
	# the far right. The slot stretches the full shell height so it reads as
	# a proper icon square rather than a sliver under the bar.
	var shell_content = HBoxContainer.new()
	shell_content.name = "ShellRow"
	shell_content.add_theme_constant_override("separation", 4)
	shell_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell_margin.add_child(shell_content)

	var meter_column = VBoxContainer.new()
	meter_column.name = "MeterColumn"
	meter_column.add_theme_constant_override("separation", 2)
	meter_column.alignment = BoxContainer.ALIGNMENT_CENTER
	meter_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	meter_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell_content.add_child(meter_column)

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
	# Nine-patch on: the 344px-wide bar textures otherwise become the bar's
	# minimum size, forcing the shell ~23px past the ChoreMeterContainer's
	# right edge. With the 32px end caps preserved, the bar shrinks to its
	# BAR_WIDTH x BAR_HEIGHT minimum and stretches to fit instead.
	progress_bar.nine_patch_stretch = true
	progress_bar.stretch_margin_left = BAR_NINE_PATCH_MARGIN
	progress_bar.stretch_margin_right = BAR_NINE_PATCH_MARGIN
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter_column.add_child(progress_bar)

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
	task_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter_column.add_child(task_label)

	_buff_chip_config = DebuffVisualConfigScript.new()
	_buff_chip_config.compact_icon_size = Vector2(20, 20)
	_buff_detail_config = DebuffVisualConfigScript.new()
	_buff_detail_config.compact_icon_size = Vector2(30, 30)

	# Reserved buff slot on the far right of the shell row, styled like the
	# Debuff UI's translucent empty slots. It stretches the full shell
	# height and is always visible so the layout never jumps; the chip is
	# centered inside it on both axes.
	buff_icon_row = PanelContainer.new()
	buff_icon_row.name = "BuffIconRow"
	buff_icon_row.custom_minimum_size = BUFF_SLOT_SIZE
	buff_icon_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	buff_icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot_style := StyleBoxFlat.new()
	slot_style.bg_color = Color(0.12, 0.10, 0.14, 0.3)
	slot_style.border_color = Color(0.3, 0.25, 0.35, 0.15)
	slot_style.set_border_width_all(1)
	slot_style.set_corner_radius_all(10)
	slot_style.corner_detail = 6
	buff_icon_row.add_theme_stylebox_override("panel", slot_style)
	shell_content.add_child(buff_icon_row)

	_buff_icon_box = HBoxContainer.new()
	_buff_icon_box.name = "BuffIconBox"
	_buff_icon_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_buff_icon_box.add_theme_constant_override("separation", 2)
	_buff_icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buff_icon_row.add_child(_buff_icon_box)

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

	buff_detail_row = HBoxContainer.new()
	buff_detail_row.name = "BuffDetailRow"
	buff_detail_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buff_detail_row.add_theme_constant_override("separation", 10)
	buff_detail_row.visible = false
	buff_detail_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details_vbox.add_child(buff_detail_row)

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
	# Flat dark fill, no border/shadow: the shell spans the parent container
	# edge to edge, so the container's own border is the only frame.
	var shell_style = StyleBoxFlat.new()
	shell_style.bg_color = CHORE_BG_SOFT
	shell_style.set_border_width_all(0)
	shell_style.set_corner_radius_all(6)
	shell_style.corner_detail = 6
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
## Rebuilds the chore status panel as organized BBCode sections (CHORE,
## PROGRESS, STATUS, and BUFF when Rebellion is active) with section
## headers in the panel palette and [table=2] label/value pairs.
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

	var sections: Array[String] = []

	# 1. CHORE — name, description, difficulty
	var chore_section := "[color=#79e2e3][b]CHORE[/b][/color]\n"
	if task:
		if task_label:
			task_label.text = task.display_name
		var difficulty_text := "Easy"
		var difficulty_color := "#79e2e3"
		if "difficulty" in task and task.difficulty == ChoreData.Difficulty.HARD:
			difficulty_text = "Hard"
			difficulty_color = "#e2648c"
		chore_section += "[table=2]"
		chore_section += "[cell][color=#c7bbdd]Name[/color][/cell][cell]%s [color=%s](%s)[/color][/cell]" % [
			task.display_name, difficulty_color, difficulty_text]
		chore_section += "[cell][color=#c7bbdd]Task[/color][/cell][cell]%s[/cell]" % task.description
		chore_section += "[/table]"
	else:
		var waiting_for_selection = _chores_manager.pending_chore_selection if _chores_manager.has_method("get_pending_tasks") else false
		if task_label:
			task_label.text = "Choose a chore" if waiting_for_selection else "No active chore"
		if waiting_for_selection:
			chore_section += "[b]Choose a new chore[/b] — a fresh chore is required before play continues."
		else:
			chore_section += "[b]No active chore[/b] — take a breather, but keep an eye on the meter."
	sections.append(chore_section)

	# 2. PROGRESS — x / max (pct), expiry
	var expiry_text := "Expires when this round ends"
	if _chores_manager.has_method("get_rounds_until_expiry") and _chores_manager.get_rounds_until_expiry() <= 0:
		expiry_text = "Awaiting replacement"
	var progress_section := "[color=#79e2e3][b]PROGRESS[/b][/color]\n"
	progress_section += "[table=2]"
	progress_section += "[cell][color=#c7bbdd]Progress[/color][/cell][cell]%s / %s (%d%%)[/cell]" % [
		NumberFormatter.format_int(current_progress_val),
		NumberFormatter.format_int(max_progress),
		percent
	]
	progress_section += "[cell][color=#c7bbdd]Expiry[/color][/cell][cell]%s[/cell]" % expiry_text
	progress_section += "[/table]"
	sections.append(progress_section)

	# 3. STATUS — Mom mood, completed counts, Rep
	var status_section := "[color=#79e2e3][b]STATUS[/b][/color]\n"
	status_section += "[table=2]"
	status_section += "[cell][color=#c7bbdd]Mom Mood[/color][/cell][cell]%s %s (%d/10)[/cell]" % [
		mood_emoji, mood_desc, _chores_manager.mom_mood]
	status_section += "[cell][color=#c7bbdd]Completed[/color][/cell][cell]%d easy, %d hard[/cell]" % [
		easy_count, hard_count]
	var pm := get_node_or_null("/root/ProgressManager")
	if pm and pm.has_method("get_rep"):
		status_section += "[cell][color=#ff4080]Rep[/color][/cell][cell]%d/100 — %s (POGs up to %s)[/cell]" % [
			pm.get_rep(), pm.get_rep_stage_name(), pm.get_rep_tier_name()]
	status_section += "[/table]"
	sections.append(status_section)

	# 4. BUFF — only while a buff (e.g. Rebellion) is active
	if not _buff_icons.is_empty():
		var buff_section := "[color=#ff6d9e][b]BUFF[/b][/color]\n"
		buff_section += "[table=2]"
		for id in _buff_icons.keys():
			var icon = _buff_icons[id] as DebuffIcon
			if not is_instance_valid(icon) or icon.data == null:
				continue
			buff_section += "[cell][color=#c7bbdd]%s[/color][/cell][cell]%s[/cell]" % [
				icon.data.display_name, _get_buff_display_suffix(id)]
			buff_section += "[cell][color=#c7bbdd]Effect[/color][/cell][cell]%s[/cell]" % _get_buff_effect_summary(id)
		buff_section += "[/table]"
		sections.append(buff_section)

	details_label.text = "\n".join(sections)

	# Keep the fan-out buff labels in sync with live stack counts
	for id in _buff_detail_labels.keys():
		var lbl = _buff_detail_labels[id] as Label
		var icon = _buff_icons.get(id) as DebuffIcon
		if is_instance_valid(lbl) and is_instance_valid(icon) and icon.data:
			lbl.text = "%s  %s" % [icon.data.display_name, _get_buff_display_suffix(id)]


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


## add_buff_icon(data, buff_instance) -> Control
##
## Adds a compact buff chip (e.g. the Rebellion buff) to the reserved slot
## at the far right of the task row, reusing the DebuffIcon chip so the SDF
## glyph shader renders identically to the Debuff UI. Also registers the
## buff for the fan-out details panel. Mirrors DebuffUI.add_debuff().
func add_buff_icon(data: DebuffData, buff_instance = null) -> Control:
	if data == null:
		return null
	if _buff_icons.has(data.id):
		return _buff_icons[data.id]

	var icon := DEBUFF_ICON_SCENE.instantiate() as DebuffIcon
	if not icon:
		push_error("[ChoreUI] Failed to instantiate buff icon")
		return null

	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_visual_config(_buff_chip_config)
	icon.set_data(data)
	_buff_icon_box.add_child(icon)
	icon.custom_minimum_size = BUFF_CHIP_SIZE
	# Center the chip inside the slot on both axes.
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_buff_icons[data.id] = icon
	if buff_instance:
		_buff_instances[data.id] = buff_instance
		buff_instance.debuff_started.connect(func():
			icon.set_active(true)
			print("[ChoreUI] Buff started:", data.id))
		buff_instance.debuff_ended.connect(func():
			icon.set_active(false)
			print("[ChoreUI] Buff ended:", data.id))
		buff_instance.visual_pulse_requested.connect(func(strength: float, duration: float):
			icon.trigger_visual_pulse(strength, duration))

	_rebuild_buff_detail_row()
	_update_details_with_progress()
	print("[ChoreUI] Added buff icon:", data.id)
	return icon


## remove_buff_icon(id)
##
## Removes a buff chip by id. The reserved slot stays in place (it never
## hides), so the compact shell size is unaffected.
func remove_buff_icon(id: String) -> void:
	if not _buff_icons.has(id):
		return
	var icon = _buff_icons[id] as DebuffIcon
	if is_instance_valid(icon):
		_buff_icon_box.remove_child(icon)
		icon.queue_free()
	_buff_icons.erase(id)
	_buff_instances.erase(id)
	_rebuild_buff_detail_row()
	_update_details_with_progress()
	print("[ChoreUI] Removed buff icon:", id)


## clear_buff_icons()
##
## Frees all buff chips and resets buff state. Called by GameController on
## channel start, mirroring DebuffUI.clear_all_debuffs().
func clear_buff_icons() -> void:
	for icon in _buff_icons.values():
		if is_instance_valid(icon):
			_buff_icon_box.remove_child(icon)
			icon.queue_free()
	_buff_icons.clear()
	_buff_instances.clear()
	_rebuild_buff_detail_row()
	_update_details_with_progress()
	print("[ChoreUI] Cleared all buff icons")


## _get_buff_stacks(id) -> int
##
## Live stack count for a buff, read from its instance (intensity) when
## available; falls back to 1.
func _get_buff_stacks(id: String) -> int:
	var inst = _buff_instances.get(id)
	if is_instance_valid(inst) and "intensity" in inst:
		return maxi(int(inst.intensity), 1)
	return 1


## _get_buff_display_suffix(id) -> String
##
## Returns the compact suffix shown beside a buff's display name.
func _get_buff_display_suffix(id: String) -> String:
	var inst = _buff_instances.get(id)
	if is_instance_valid(inst) and inst.has_method("get_buff_display_suffix"):
		return str(inst.call("get_buff_display_suffix"))
	return "x%d" % _get_buff_stacks(id)


## _get_buff_effect_summary(id) -> String
##
## Returns a one-line effect summary for the details panel and fan-out row.
func _get_buff_effect_summary(id: String) -> String:
	var inst = _buff_instances.get(id)
	if is_instance_valid(inst) and inst.has_method("get_buff_effect_summary"):
		return str(inst.call("get_buff_effect_summary"))
	var icon = _buff_icons.get(id) as DebuffIcon
	if is_instance_valid(icon) and icon.data != null:
		return icon.data.description
	return "Buff active"


## _rebuild_buff_detail_row()
##
## Rebuilds the fan-out buff row (chip + name/stacks label + effect summary)
## above the details RichTextLabel from the currently registered buffs.
func _rebuild_buff_detail_row() -> void:
	if not buff_detail_row:
		return
	for child in buff_detail_row.get_children():
		child.queue_free()
	_buff_detail_icons.clear()
	_buff_detail_labels.clear()
	buff_detail_row.visible = not _buff_icons.is_empty()
	if details_label:
		if buff_detail_row.visible:
			details_label.custom_minimum_size = Vector2(0, 170)
		else:
			details_label.custom_minimum_size = Vector2(0, 220)
	for id in _buff_icons.keys():
		var source = _buff_icons[id] as DebuffIcon
		if not is_instance_valid(source) or source.data == null:
			continue
		var chip := DEBUFF_ICON_SCENE.instantiate() as DebuffIcon
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.set_visual_config(_buff_detail_config)
		chip.set_data(source.data)
		buff_detail_row.add_child(chip)
		chip.custom_minimum_size = BUFF_DETAIL_CHIP_SIZE
		_buff_detail_icons[id] = chip

		var text_vbox := VBoxContainer.new()
		text_vbox.name = "BuffText"
		text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		text_vbox.add_theme_constant_override("separation", 2)
		text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		buff_detail_row.add_child(text_vbox)

		var lbl := Label.new()
		lbl.name = "BuffLabel"
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", CHORE_TEXT)
		lbl.add_theme_color_override("font_outline_color", CHORE_OUTLINE)
		lbl.add_theme_constant_override("outline_size", 1)
		lbl.text = "%s  %s" % [source.data.display_name, _get_buff_display_suffix(id)]
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_vbox.add_child(lbl)
		_buff_detail_labels[id] = lbl

		var desc := Label.new()
		desc.name = "BuffDesc"
		desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		desc.add_theme_font_size_override("font_size", 9)
		desc.add_theme_color_override("font_color", CHORE_TEXT_SOFT)
		desc.add_theme_color_override("font_outline_color", CHORE_OUTLINE)
		desc.add_theme_constant_override("outline_size", 1)
		desc.text = _get_buff_effect_summary(id)
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_vbox.add_child(desc)

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
