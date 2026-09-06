extends Control
class_name ChoreUI

## ChoreUI
##
## Displays the chore task, goof-off meter, and one buff slot inside the
## GameUI center column. The meter fills toward failure using the
## GameProgressBar fill_ramp mode; Mom's mood tints the meter frame and the
## GOOF-OFF label. Clicking opens a centered chore status fan-out panel.

signal task_clicked

@export var chores_manager_path: NodePath
## Optional Mom portrait for the fan-out panel; a placeholder shows when unset.
@export var portrait_texture: Texture2D

# Node references
var progress_bar: GameProgressBar
var task_label: Label
var details_panel: PanelContainer
var buff_icon_row: Panel
var buff_detail_row: HBoxContainer
var _buff_icon_box: HBoxContainer
var _compact_shell: PanelContainer
var _goof_off_label: Label
var _buff_slot_style: StyleBoxFlat
var _buff_slot_overlay: Control
var _empty_glyph: Label
var _duration_bar: ColorRect
var _chores_manager = null  # ChoresManager - duck typed to avoid class resolution issues

# Fan-out node references
var _title_label: Label
var _difficulty_tag: Label
var _desc_label: Label
var _mom_portrait: TextureRect
var _mom_placeholder: Label
var _mood_label: Label
var _fan_progress_bar: GameProgressBar
var _progress_numeral: Label
var _expiry_label: Label
var _rep_separator: HSeparator
var _rep_block: VBoxContainer
var _rep_tier_label: Label
var _rep_bar: GameProgressBar
var _rep_quote_label: Label
var _easy_badge_panel: PanelContainer
var _hard_badge_panel: PanelContainer

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
const CHORE_BG_SOFT: Color = Color(0.247059, 0.219608, 0.345098, 0.4)
const CHORE_ACCENT: Color = Color(0.137255, 0.411765, 0.415686, 1.0)
const CHORE_TEXT: Color = Color(0.968627, 0.941176, 1.0, 1.0)
const CHORE_TEXT_SOFT: Color = Color(0.780392, 0.733333, 0.866667, 1.0)
const CHORE_OUTLINE: Color = Color(0.129412, 0.121569, 0.2, 1.0)
const CHORE_DANGER: Color = Color(0.886275, 0.392157, 0.54902, 1.0)
const CHORE_WARNING: Color = Color(0.886275, 0.67451, 0.356863, 1.0)
const CHORE_SAFE: Color = Color(0.47451, 0.886275, 0.890196, 1.0)
const CHORE_PINK: Color = Color(1.0, 0.427451, 0.619608, 1.0)  # #ff6d9e section-header pink
const MOOD_ANGRY: Color = Color(0.886275, 0.301961, 0.34902, 1.0)
const DETAILS_PANEL_SIZE := Vector2(480, 420)
# (VCR_FONT retired with the RichTextLabel fan-out; labels use the panel theme.)
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
# Subtle alpha for the difficulty (track) tint.
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

	# Shell row, left to right: chore text block, goof-off meter (fills the
	# remaining width), then the single buff slot on the far right. The slot
	# stretches the full shell height so it reads as a proper icon square.
	var shell_content = HBoxContainer.new()
	shell_content.name = "ShellRow"
	shell_content.add_theme_constant_override("separation", 8)
	shell_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell_margin.add_child(shell_content)

	var chore_block = VBoxContainer.new()
	chore_block.name = "ChoreBlock"
	chore_block.add_theme_constant_override("separation", 2)
	chore_block.alignment = BoxContainer.ALIGNMENT_CENTER
	chore_block.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chore_block.custom_minimum_size = Vector2(150, 0)
	chore_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell_content.add_child(chore_block)

	var chore_micro = Label.new()
	chore_micro.name = "ChoreMicroLabel"
	chore_micro.text = "CHORE"
	chore_micro.add_theme_font_size_override("font_size", 9)
	chore_micro.add_theme_color_override("font_color", CHORE_PINK)
	chore_micro.add_theme_color_override("font_outline_color", CHORE_OUTLINE)
	chore_micro.add_theme_constant_override("outline_size", 1)
	chore_micro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chore_block.add_child(chore_micro)

	task_label = Label.new()
	task_label.name = "TaskLabel"
	task_label.text = "No active chore"
	task_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	task_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	task_label.add_theme_font_size_override("font_size", 10)
	task_label.add_theme_color_override("font_color", CHORE_TEXT)
	task_label.add_theme_color_override("font_outline_color", CHORE_OUTLINE)
	task_label.add_theme_constant_override("outline_size", 1)
	task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	task_label.max_lines_visible = 2
	task_label.custom_minimum_size = Vector2(0, 28)
	task_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chore_block.add_child(task_label)

	var meter_column = VBoxContainer.new()
	meter_column.name = "MeterColumn"
	meter_column.add_theme_constant_override("separation", 2)
	meter_column.alignment = BoxContainer.ALIGNMENT_CENTER
	meter_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	meter_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell_content.add_child(meter_column)

	_goof_off_label = Label.new()
	_goof_off_label.name = "GoofOffLabel"
	_goof_off_label.text = "GOOF-OFF"
	_goof_off_label.add_theme_font_size_override("font_size", 9)
	_goof_off_label.add_theme_color_override("font_color", CHORE_SAFE)
	_goof_off_label.add_theme_color_override("font_outline_color", CHORE_OUTLINE)
	_goof_off_label.add_theme_constant_override("outline_size", 1)
	_goof_off_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter_column.add_child(_goof_off_label)

	progress_bar = GameProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = 0
	progress_bar.fill_color = CHORE_SAFE
	progress_bar.fill_ramp = true
	progress_bar.show_ticks = true
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter_column.add_child(progress_bar)

	_buff_chip_config = DebuffVisualConfigScript.new()
	_buff_chip_config.compact_icon_size = Vector2(20, 20)
	_buff_detail_config = DebuffVisualConfigScript.new()
	_buff_detail_config.compact_icon_size = Vector2(30, 30)

	# Reserved buff slot on the far right of the shell row, styled like the
	# Debuff UI's translucent empty slots. It stretches the full shell
	# height and is always visible so the layout never jumps; the chip is
	# centered inside it on both axes. Empty state: dashed border (drawn by
	# the overlay) plus a faint "+" glyph; filled state: solid border tinted
	# to the buff's effect color, with a draining duration underline.
	buff_icon_row = Panel.new()
	buff_icon_row.name = "BuffIconRow"
	buff_icon_row.custom_minimum_size = BUFF_SLOT_SIZE
	buff_icon_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	buff_icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buff_slot_style = StyleBoxFlat.new()
	_buff_slot_style.bg_color = Color(0.12, 0.10, 0.14, 0.3)
	_buff_slot_style.set_border_width_all(0)  # empty state uses drawn dashes
	_buff_slot_style.set_corner_radius_all(10)
	_buff_slot_style.corner_detail = 6
	buff_icon_row.add_theme_stylebox_override("panel", _buff_slot_style)
	shell_content.add_child(buff_icon_row)

	_buff_icon_box = HBoxContainer.new()
	_buff_icon_box.name = "BuffIconBox"
	_buff_icon_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_buff_icon_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_buff_icon_box.add_theme_constant_override("separation", 2)
	_buff_icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buff_icon_row.add_child(_buff_icon_box)

	_empty_glyph = Label.new()
	_empty_glyph.name = "EmptyGlyph"
	_empty_glyph.text = "+"
	_empty_glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	_empty_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_glyph.add_theme_font_size_override("font_size", 28)
	_empty_glyph.add_theme_color_override("font_color", CHORE_TEXT_SOFT)
	_empty_glyph.modulate.a = 0.2
	_empty_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buff_icon_row.add_child(_empty_glyph)

	_duration_bar = ColorRect.new()
	_duration_bar.name = "DurationBar"
	_duration_bar.color = CHORE_PINK
	_duration_bar.anchor_left = 0.06
	_duration_bar.anchor_top = 1.0
	_duration_bar.anchor_bottom = 1.0
	_duration_bar.anchor_right = 0.94
	_duration_bar.offset_top = -4.0
	_duration_bar.offset_bottom = -2.0
	_duration_bar.offset_left = 0.0
	_duration_bar.offset_right = 0.0
	_duration_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_duration_bar.visible = false
	buff_icon_row.add_child(_duration_bar)

	_buff_slot_overlay = Control.new()
	_buff_slot_overlay.name = "BuffSlotOverlay"
	_buff_slot_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_buff_slot_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buff_icon_row.add_child(_buff_slot_overlay)
	_buff_slot_overlay.draw.connect(_draw_buff_slot_overlay)
	_buff_slot_overlay.resized.connect(_buff_slot_overlay.queue_redraw)

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
	details_vbox.name = "DetailsVBox"
	details_vbox.add_theme_constant_override("separation", 8)
	panel_margin.add_child(details_vbox)

	# Header: chore title + difficulty tag, one-line description beneath.
	var header_block = VBoxContainer.new()
	header_block.name = "HeaderBlock"
	header_block.add_theme_constant_override("separation", 2)
	header_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details_vbox.add_child(header_block)

	var title_row = HBoxContainer.new()
	title_row.name = "TitleRow"
	title_row.add_theme_constant_override("separation", 8)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_block.add_child(title_row)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "NO ACTIVE CHORE"
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", CHORE_TEXT)
	_title_label.add_theme_color_override("font_outline_color", CHORE_OUTLINE)
	_title_label.add_theme_constant_override("outline_size", 1)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(_title_label)

	_difficulty_tag = Label.new()
	_difficulty_tag.name = "DifficultyTag"
	_difficulty_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_difficulty_tag.add_theme_font_size_override("font_size", 12)
	_difficulty_tag.add_theme_color_override("font_color", CHORE_SAFE)
	_difficulty_tag.add_theme_color_override("font_outline_color", CHORE_OUTLINE)
	_difficulty_tag.add_theme_constant_override("outline_size", 1)
	_difficulty_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(_difficulty_tag)

	_desc_label = Label.new()
	_desc_label.name = "DescLabel"
	_desc_label.add_theme_font_size_override("font_size", 10)
	_desc_label.add_theme_color_override("font_color", CHORE_TEXT_SOFT)
	_desc_label.add_theme_color_override("font_outline_color", CHORE_OUTLINE)
	_desc_label.add_theme_constant_override("outline_size", 1)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_block.add_child(_desc_label)

	# Mom row: portrait on the left, mood label beside it (color = mood band).
	var mom_row = HBoxContainer.new()
	mom_row.name = "MomRow"
	mom_row.add_theme_constant_override("separation", 10)
	mom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details_vbox.add_child(mom_row)

	var portrait_slot = PanelContainer.new()
	portrait_slot.name = "MomPortraitSlot"
	portrait_slot.custom_minimum_size = Vector2(80, 80)
	portrait_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait_style := StyleBoxFlat.new()
	portrait_style.bg_color = Color(0.713725, 0.301961, 0.478431, 0.15)
	portrait_style.border_color = Color(0.713725, 0.301961, 0.478431, 0.4)
	portrait_style.set_border_width_all(2)
	portrait_style.set_corner_radius_all(12)
	portrait_style.corner_detail = 6
	portrait_slot.add_theme_stylebox_override("panel", portrait_style)
	mom_row.add_child(portrait_slot)

	_mom_placeholder = Label.new()
	_mom_placeholder.name = "MomPlaceholder"
	_mom_placeholder.text = "MOM"
	_mom_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mom_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mom_placeholder.add_theme_font_size_override("font_size", 14)
	_mom_placeholder.add_theme_color_override("font_color", CHORE_PINK)
	_mom_placeholder.add_theme_color_override("font_outline_color", CHORE_OUTLINE)
	_mom_placeholder.add_theme_constant_override("outline_size", 1)
	_mom_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_slot.add_child(_mom_placeholder)

	_mom_portrait = TextureRect.new()
	_mom_portrait.name = "MomPortrait"
	_mom_portrait.custom_minimum_size = Vector2(80, 80)
	_mom_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mom_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mom_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if portrait_texture:
		_mom_portrait.texture = portrait_texture
	_mom_portrait.visible = portrait_texture != null
	_mom_placeholder.visible = portrait_texture == null
	portrait_slot.add_child(_mom_portrait)

	_mood_label = Label.new()
	_mood_label.name = "MoodLabel"
	_mood_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mood_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mood_label.add_theme_font_size_override("font_size", 14)
	_mood_label.add_theme_color_override("font_color", CHORE_SAFE)
	_mood_label.add_theme_color_override("font_outline_color", CHORE_OUTLINE)
	_mood_label.add_theme_constant_override("outline_size", 1)
	_mood_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mom_row.add_child(_mood_label)

	# Progress: pink bar + numeral (no percentage), small expiry beneath.
	var progress_block = VBoxContainer.new()
	progress_block.name = "ProgressBlock"
	progress_block.add_theme_constant_override("separation", 3)
	progress_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details_vbox.add_child(progress_block)

	_fan_progress_bar = GameProgressBar.new()
	_fan_progress_bar.name = "ProgressBar"
	_fan_progress_bar.min_value = 0
	_fan_progress_bar.max_value = 100
	_fan_progress_bar.value = 0
	_fan_progress_bar.fill_color = CHORE_DANGER
	_fan_progress_bar.custom_minimum_size = Vector2(0, 18)
	_fan_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fan_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_block.add_child(_fan_progress_bar)

	_progress_numeral = Label.new()
	_progress_numeral.name = "ProgressNumeral"
	_progress_numeral.text = "0 / 100"
	_progress_numeral.add_theme_font_size_override("font_size", 12)
	_progress_numeral.add_theme_color_override("font_color", CHORE_TEXT)
	_progress_numeral.add_theme_color_override("font_outline_color", CHORE_OUTLINE)
	_progress_numeral.add_theme_constant_override("outline_size", 1)
	_progress_numeral.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_block.add_child(_progress_numeral)

	_expiry_label = Label.new()
	_expiry_label.name = "ExpiryLabel"
	_expiry_label.text = "Expires when this round ends"
	_expiry_label.add_theme_font_size_override("font_size", 9)
	_expiry_label.add_theme_color_override("font_color", CHORE_TEXT_SOFT)
	_expiry_label.add_theme_color_override("font_outline_color", CHORE_OUTLINE)
	_expiry_label.add_theme_constant_override("outline_size", 1)
	_expiry_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_block.add_child(_expiry_label)

	buff_detail_row = HBoxContainer.new()
	buff_detail_row.name = "BuffDetailRow"
	buff_detail_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buff_detail_row.add_theme_constant_override("separation", 10)
	buff_detail_row.visible = false
	buff_detail_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details_vbox.add_child(buff_detail_row)

	# Rep band: hairline separator, large tier name, small bar, effect quote.
	_rep_separator = HSeparator.new()
	_rep_separator.name = "RepSeparator"
	var sep_style := StyleBoxLine.new()
	sep_style.color = Color(0.780392, 0.733333, 0.866667, 0.35)
	sep_style.thickness = 1
	_rep_separator.add_theme_stylebox_override("separator", sep_style)
	_rep_separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details_vbox.add_child(_rep_separator)

	_rep_block = VBoxContainer.new()
	_rep_block.name = "RepBlock"
	_rep_block.add_theme_constant_override("separation", 3)
	_rep_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details_vbox.add_child(_rep_block)

	_rep_tier_label = Label.new()
	_rep_tier_label.name = "RepTierLabel"
	_rep_tier_label.add_theme_font_size_override("font_size", 18)
	_rep_tier_label.add_theme_color_override("font_color", CHORE_TEXT)
	_rep_tier_label.add_theme_color_override("font_outline_color", CHORE_OUTLINE)
	_rep_tier_label.add_theme_constant_override("outline_size", 1)
	_rep_tier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rep_block.add_child(_rep_tier_label)

	_rep_bar = GameProgressBar.new()
	_rep_bar.name = "RepBar"
	_rep_bar.min_value = 0
	_rep_bar.max_value = 100
	_rep_bar.value = 0
	_rep_bar.fill_color = CHORE_DANGER
	_rep_bar.custom_minimum_size = Vector2(0, 8)
	_rep_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rep_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rep_block.add_child(_rep_bar)

	_rep_quote_label = Label.new()
	_rep_quote_label.name = "RepQuoteLabel"
	_rep_quote_label.add_theme_font_size_override("font_size", 10)
	_rep_quote_label.add_theme_color_override("font_color", CHORE_TEXT_SOFT)
	_rep_quote_label.add_theme_color_override("font_outline_color", CHORE_OUTLINE)
	_rep_quote_label.add_theme_constant_override("outline_size", 1)
	_rep_quote_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rep_block.add_child(_rep_quote_label)

	# Completed counts: two badges, loud when nonzero.
	var completed_row = HBoxContainer.new()
	completed_row.name = "CompletedRow"
	completed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	completed_row.add_theme_constant_override("separation", 10)
	completed_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details_vbox.add_child(completed_row)

	_easy_badge_panel = _make_badge()
	completed_row.add_child(_easy_badge_panel)
	_hard_badge_panel = _make_badge()
	completed_row.add_child(_hard_badge_panel)

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
		_update_details_with_progress()
	print("[ChoreUI] Progress updated: %d" % new_value)

func _on_task_selected(task) -> void:  # ChoreData - duck typed
	if task == null:
		if task_label:
			task_label.text = "No active chore"
		_update_difficulty_tint(null)
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
## Pushes live manager state into the fan-out's structured nodes: header
## (title/tag/description), Mom portrait + mood label, progress bar +
## numeral + expiry, rep band, and the EASY/HARD completed badges.
func _update_details_with_progress() -> void:
	if _title_label == null:
		return

	var task = _chores_manager.current_task if _chores_manager else null
	var progress_val: int = _chores_manager.current_progress if _chores_manager else 0
	var max_progress: int = 100
	var mood: int = _chores_manager.mom_mood if _chores_manager else 5
	if _chores_manager and _chores_manager.has_method("get_scaled_max_progress"):
		max_progress = _chores_manager.get_scaled_max_progress()

	# Header — stated once; no Name/Task label pair.
	if task:
		_title_label.text = task.display_name.to_upper()
		var hard: bool = "difficulty" in task and task.difficulty == ChoreData.Difficulty.HARD
		_difficulty_tag.text = "(Hard)" if hard else "(Easy)"
		_difficulty_tag.add_theme_color_override("font_color", CHORE_DANGER if hard else CHORE_SAFE)
		_desc_label.text = task.description
		if task_label:
			task_label.text = task.display_name
	else:
		var waiting: bool = _chores_manager != null and _chores_manager.get("pending_chore_selection") == true
		_title_label.text = "CHOOSE A CHORE" if waiting else "NO ACTIVE CHORE"
		_difficulty_tag.text = ""
		_desc_label.text = "A fresh chore is required before play continues." if waiting \
			else "Take a breather, but keep an eye on the meter."
		if task_label:
			task_label.text = "Choose a chore" if waiting else "No active chore"

	# Mom mood — text here, color from the same band scale as the meter frame.
	var mood_desc: String = _chores_manager.get_mood_description() \
		if _chores_manager and _chores_manager.has_method("get_mood_description") else "Neutral"
	_mood_label.text = "%s %d/10" % [mood_desc, mood]
	_mood_label.add_theme_color_override("font_color", _mood_color(mood))

	# Progress — numeral only, no percentage.
	_fan_progress_bar.max_value = max_progress
	_fan_progress_bar.set_value_instant(progress_val)
	_progress_numeral.text = "%s / %s" % [
		NumberFormatter.format_int(progress_val),
		NumberFormatter.format_int(max_progress)]
	var expiry_text := "Expires when this round ends"
	if _chores_manager and _chores_manager.has_method("get_rounds_until_expiry") \
			and _chores_manager.get_rounds_until_expiry() <= 0:
		expiry_text = "Awaiting replacement"
	_expiry_label.text = expiry_text

	# Rep band — hidden entirely when ProgressManager is unavailable.
	var pm := get_node_or_null("/root/ProgressManager")
	var rep_visible: bool = pm != null and pm.has_method("get_rep")
	_rep_block.visible = rep_visible
	_rep_separator.visible = rep_visible
	if rep_visible:
		_rep_tier_label.text = str(pm.get_rep_stage_name())
		_rep_bar.set_value_instant(pm.get_rep())
		_rep_quote_label.text = "POGs up to %s" % str(pm.get_rep_tier_name())

	# Completed badges
	var easy_count := 0
	var hard_count := 0
	if _chores_manager:
		for chore in _chores_manager.completed_chores:
			if chore and "difficulty" in chore and chore.difficulty == ChoreData.Difficulty.HARD:
				hard_count += 1
			else:
				easy_count += 1
	_style_badge(_easy_badge_panel, "EASY", easy_count, CHORE_SAFE)
	_style_badge(_hard_badge_panel, "HARD", hard_count, CHORE_DANGER)

	# Keep the fan-out buff labels in sync with live stack counts
	for id in _buff_detail_labels.keys():
		var lbl = _buff_detail_labels[id] as Label
		var icon = _buff_icons.get(id) as DebuffIcon
		if is_instance_valid(lbl) and is_instance_valid(icon) and icon.data:
			lbl.text = "%s  %s" % [icon.data.display_name, _get_buff_display_suffix(id)]


## _make_badge() -> PanelContainer
##
## Creates one completed-count badge (panel + "BadgeLabel" child).
func _make_badge() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.corner_detail = 6
	style.set_content_margin_all(6)
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.name = "BadgeLabel"
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lbl)
	return panel


## _style_badge(panel, name_text, count, accent)
##
## Loud (solid accent fill, dark text) when count > 0, quiet when zero.
func _style_badge(panel: PanelContainer, name_text: String, count: int, accent: Color) -> void:
	var lbl := panel.get_node("BadgeLabel") as Label
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	lbl.text = "%s %d" % [name_text, count]
	if count > 0:
		style.bg_color = accent
		lbl.add_theme_color_override("font_color", Color(0.1, 0.08, 0.12, 1.0))
	else:
		style.bg_color = Color(0.12, 0.10, 0.14, 0.3)
		lbl.add_theme_color_override("font_color", CHORE_TEXT_SOFT)


## _mood_color(mood) -> Color
##
## Banded mood scale shared by the meter frame, the GOOF-OFF label, and the
## fan-out mood label: 0-3 calm (cool), 4-6 tense (amber), 7-10 angry (red).
func _mood_color(mood: int) -> Color:
	if mood <= 3:
		return CHORE_SAFE
	elif mood <= 6:
		return CHORE_WARNING
	return MOOD_ANGRY

## _on_mom_mood_changed(new_mood)
##
## Signal handler: retints the meter frame and labels to Mom's mood.
func _on_mom_mood_changed(new_mood: int) -> void:
	_update_mood_tint(new_mood)
	_update_details_with_progress()

## _update_mood_tint(mood)
##
## Mom's mood rides on the meter FRAME (track border) and the GOOF-OFF
## micro-label — one banded color, merged meaning. Matches ChoresManager's
## scale where low = happy and high = angry.
func _update_mood_tint(mood: int) -> void:
	var color := _mood_color(mood)
	if progress_bar:
		progress_bar.frame_color = color
	if _goof_off_label:
		_goof_off_label.add_theme_color_override("font_color", color)
	if _mood_label:
		_mood_label.add_theme_color_override("font_color", color)

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
## at the far right of the shell, reusing the DebuffIcon chip so the SDF
## glyph shader renders identically to the Debuff UI. ONE chip max: a new
## buff replaces the current one. Also registers the buff for the fan-out
## details panel. Mirrors DebuffUI.add_debuff().
func add_buff_icon(data: DebuffData, buff_instance = null) -> Control:
	if data == null:
		return null
	if _buff_icons.has(data.id):
		return _buff_icons[data.id]
	if not _buff_icons.is_empty():
		clear_buff_icons()

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
	_update_buff_slot_state()
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
	_update_buff_slot_state()
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
	_update_buff_slot_state()
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
		text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_vbox.add_child(desc)


## _update_buff_slot_state()
##
## Syncs the compact buff slot's chrome to empty/filled: dashed drawn border
## + faint glyph when empty, solid border tinted to the buff's effect color
## when filled. The duration underline is re-evaluated every frame in
## _process and starts hidden.
func _update_buff_slot_state() -> void:
	var filled := not _buff_icons.is_empty()
	if _empty_glyph:
		_empty_glyph.visible = not filled
	if _buff_slot_style:
		if filled:
			_buff_slot_style.border_color = _get_buff_effect_color()
			_buff_slot_style.set_border_width_all(2)
		else:
			_buff_slot_style.set_border_width_all(0)
	if _buff_slot_overlay:
		_buff_slot_overlay.queue_redraw()
	if _duration_bar:
		_duration_bar.visible = false


## _get_buff_effect_color() -> Color
##
## Border tint for the filled buff slot. Duck-types a color off the buff's
## DebuffData (effect_color / color / accent_color); falls back to pink.
func _get_buff_effect_color() -> Color:
	for id in _buff_icons.keys():
		var icon = _buff_icons[id] as DebuffIcon
		if is_instance_valid(icon) and icon.data != null:
			for key in ["effect_color", "color", "accent_color"]:
				var v = icon.data.get(key)
				if v is Color:
					return v
	return CHORE_PINK


## _get_buff_duration_ratio() -> float
##
## Remaining/total duration ratio for the active buff, duck-typed off the
## live instance. Returns -1 when no duration properties exist, which keeps
## the underline hidden.
func _get_buff_duration_ratio() -> float:
	for id in _buff_instances.keys():
		var inst = _buff_instances[id]
		if not is_instance_valid(inst):
			continue
		var total := 0.0
		for key in ["duration", "max_duration", "total_duration", "rounds_total"]:
			var v = inst.get(key)
			if v != null and float(v) > 0.0:
				total = float(v)
				break
		var left := -1.0
		for key in ["time_left", "duration_left", "rounds_left", "turns_remaining", "remaining"]:
			var v = inst.get(key)
			if v != null:
				left = float(v)
				break
		if total > 0.0 and left >= 0.0:
			return clampf(left / total, 0.0, 1.0)
	return -1.0


func _process(_delta: float) -> void:
	if _duration_bar == null:
		return
	var ratio := _get_buff_duration_ratio()
	_duration_bar.visible = ratio >= 0.0
	if ratio >= 0.0:
		_duration_bar.anchor_right = 0.06 + 0.88 * ratio


## _draw_buff_slot_overlay()
##
## Runs on the BuffSlotOverlay draw signal: the dashed empty-state border.
## The filled state uses the slot stylebox border instead.
func _draw_buff_slot_overlay() -> void:
	if not _buff_icons.is_empty():
		return
	var w := _buff_slot_overlay.size.x
	var h := _buff_slot_overlay.size.y
	if w <= 4.0 or h <= 4.0:
		return
	var rect := Rect2(2.0, 2.0, w - 4.0, h - 4.0)
	var col := Color(0.780392, 0.733333, 0.866667, 0.35)
	var corners := [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
		rect.position,
	]
	for i in range(4):
		_draw_dashed_line(corners[i], corners[i + 1], col)


func _draw_dashed_line(a: Vector2, b: Vector2, col: Color, dash: float = 5.0, gap: float = 3.0) -> void:
	var length := a.distance_to(b)
	if length <= 0.0:
		return
	var dir := (b - a) / length
	var d := 0.0
	while d < length:
		var e := minf(d + dash, length)
		_buff_slot_overlay.draw_line(a + dir * d, a + dir * e, col, 1.0)
		d += dash + gap


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
	_background.color = Color(0, 0, 0, 0.75)
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
	details_panel.position = panel_target - Vector2(0, 70)
	details_panel.modulate.a = 0.0
	details_panel.visible = true
	# A hidden panel never sorts, so autowrap labels keep a stale width-0
	# minimum size and clamp any size assignment upward. Re-assert the size
	# after the first visible layout pass.
	await get_tree().process_frame
	details_panel.size = DETAILS_PANEL_SIZE
	details_panel.position = panel_target - Vector2(0, 70)
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
