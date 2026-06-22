extends Control
class_name ChannelManagerUI

## ChannelManagerUI
##
## Full-screen mall directory selector used at game start.
## Preserves the existing ChannelManagerUI public API while replacing the
## remote-control presentation with a runtime-generated map.

signal start_pressed(channel: int)

const VCR_FONT: Font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
const ACTION_THEME: Theme = preload("res://Resources/UI/action_button_theme.tres")
const MallMapLayoutScript = preload("res://Scripts/Managers/mall_map_layout.gd")
const MallMapZoneScript = preload("res://Scripts/Managers/mall_map_zone.gd")
const SHELL_VIEWPORT_MARGIN := Vector2(34, 26)
const SHELL_MAX_SIZE := Vector2(1180, 680)
const SHELL_MIN_SIZE := Vector2(980, 600)

const SECTION_COLORS := {
	"eatery": Color(0.96, 0.76, 0.18, 1.0),
	"entertainment": Color(0.86, 0.25, 0.46, 1.0),
	"lifestyle": Color(0.29, 0.78, 0.95, 1.0),
	"specialty": Color(0.30, 0.82, 0.45, 1.0),
	"major_stores": Color(0.97, 0.46, 0.16, 1.0),
}

const SECTION_LABELS := {
	"eatery": "EATERY",
	"entertainment": "ENTERTAINMENT",
	"lifestyle": "LIFESTYLE",
	"specialty": "SPECIALTY",
	"major_stores": "DEPARTMENT STORES",
}

# References
var channel_manager = null

# Overlay and shell
var overlay: ColorRect
var shader_overlay: ColorRect
var panel_container: Control
var _shell_frame: PanelContainer
var _intro_label: Label
var _shader_material: ShaderMaterial

# Map scene
var _map_shell: PanelContainer
var _map_padding: MarginContainer
var _map_view: SubViewportContainer
var _map_viewport: SubViewport
var _map_root: Node2D
var _map_hit_surface: Control
var _directory_title: Label
var _map_legend: VBoxContainer
var _directory_grid: GridContainer
var _keyboard_hint_label: Label

# Side panel
var channel_label: Label
var zone_name_label: Label
var checkmark_icon: Label
var completion_label: Label
var multiplier_label: Label
var difficulty_label: Label
var bonus_label: Label
var description_label: Label
var section_chip: Label
var up_button: Button
var down_button: Button
var start_button: Button

# Tooltip
var _tooltip_panel: PanelContainer
var _tooltip_label: Label

# Runtime map state
var _zones_by_channel: Dictionary = {}
var _zone_order: Array[int] = []
var _hovered_channel: int = -1
var _selected_channel: int = -1
var _corridor_lines: Array[Line2D] = []
var _wayfinding_nodes: Array[Node2D] = []

@onready var _tfx := get_node_or_null("/root/TweenFXHelper")


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	set_process_unhandled_input(true)
	_build_ui()
	resized.connect(_on_root_resized)


## set_channel_manager(manager) -> void
##
## Sets the ChannelManager reference and connects signals.
func set_channel_manager(manager) -> void:
	channel_manager = manager
	if channel_manager and not channel_manager.channel_changed.is_connected(_on_channel_changed):
		channel_manager.channel_changed.connect(_on_channel_changed)
		_update_display()


## show_channel_selector() -> void
##
## Shows the mall directory selector at game start.
func show_channel_selector() -> void:
	print("[ChannelManagerUI] Showing channel selector")
	_position_to_viewport()
	_build_map_if_needed()
	visible = true
	if _map_viewport:
		_map_viewport.physics_object_picking = true
	if channel_manager:
		_selected_channel = channel_manager.current_channel
		_hovered_channel = -1
		_sync_selection_from_manager(false)
		_update_display()
	_animate_entrance()


## hide_channel_selector() -> void
##
## Hides the channel selection UI.
func hide_channel_selector() -> void:
	print("[ChannelManagerUI] Hiding channel selector")
	_hide_tooltip(false)
	_animate_exit()


func _position_to_viewport() -> void:
	var viewport = get_viewport()
	if viewport:
		var viewport_rect = viewport.get_visible_rect()
		global_position = Vector2.ZERO
		size = viewport_rect.size
		_fit_shell_to_viewport()


## _build_ui() -> void
##
## Creates the overlay shell, map viewport, side panel, and tooltip.
func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0.02, 0.02, 0.03, 0.90)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	shader_overlay = ColorRect.new()
	shader_overlay.name = "ShaderOverlay"
	shader_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	shader_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shader_material = ShaderMaterial.new()
	var shader = load("res://Scripts/Shaders/vhs_wave.gdshader")
	if shader:
		_shader_material.shader = shader
		_shader_material.set_shader_parameter("wave_speed", 0.42)
		_shader_material.set_shader_parameter("chromatic_drift", 0.018)
		_shader_material.set_shader_parameter("noise_strength", 0.12)
		_shader_material.set_shader_parameter("scanline_intensity", 0.32)
		shader_overlay.material = _shader_material
	shader_overlay.modulate.a = 0.0
	add_child(shader_overlay)

	_intro_label = Label.new()
	_intro_label.name = "IntroLabel"
	_intro_label.text = "MALL DIRECTORY"
	_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intro_label.add_theme_font_override("font", VCR_FONT)
	_intro_label.add_theme_font_size_override("font_size", 34)
	_intro_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.78))
	_intro_label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.10))
	_intro_label.add_theme_constant_override("outline_size", 4)
	_intro_label.set_anchors_preset(Control.PRESET_CENTER)
	_intro_label.offset_left = -220
	_intro_label.offset_top = -26
	_intro_label.offset_right = 220
	_intro_label.offset_bottom = 26
	_intro_label.visible = false
	_intro_label.modulate.a = 0.0
	add_child(_intro_label)

	panel_container = Control.new()
	panel_container.name = "DirectoryShell"
	panel_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel_container.position = Vector2(52, 38)
	panel_container.size = Vector2(1120, 620)
	panel_container.custom_minimum_size = Vector2.ZERO
	panel_container.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_container.modulate.a = 0.0
	add_child(panel_container)

	_shell_frame = PanelContainer.new()
	_shell_frame.name = "DirectoryShellFrame"
	_shell_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shell_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_container.add_child(_shell_frame)

	var shell_style := StyleBoxFlat.new()
	shell_style.bg_color = Color(0.11, 0.09, 0.13, 0.97)
	shell_style.border_color = Color(0.86, 0.34, 0.58, 1.0)
	shell_style.set_border_width_all(4)
	shell_style.set_corner_radius_all(22)
	shell_style.corner_detail = 10
	_shell_frame.add_theme_stylebox_override("panel", shell_style)

	var shell_margin := MarginContainer.new()
	shell_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell_margin.add_theme_constant_override("margin_left", 22)
	shell_margin.add_theme_constant_override("margin_right", 22)
	shell_margin.add_theme_constant_override("margin_top", 18)
	shell_margin.add_theme_constant_override("margin_bottom", 18)
	_shell_frame.add_child(shell_margin)

	var shell_hbox := HBoxContainer.new()
	shell_hbox.add_theme_constant_override("separation", 16)
	shell_margin.add_child(shell_hbox)

	_map_shell = PanelContainer.new()
	_map_shell.name = "MapShell"
	_map_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_shell.custom_minimum_size = Vector2(0, 0)
	shell_hbox.add_child(_map_shell)

	var map_style := StyleBoxFlat.new()
	map_style.bg_color = Color(0.96, 0.91, 0.80, 0.98)
	map_style.border_color = Color(0.74, 0.60, 0.40, 1.0)
	map_style.set_border_width_all(4)
	map_style.set_corner_radius_all(18)
	map_style.corner_detail = 8
	_map_shell.add_theme_stylebox_override("panel", map_style)

	_map_padding = MarginContainer.new()
	_map_padding.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_padding.add_theme_constant_override("margin_left", 14)
	_map_padding.add_theme_constant_override("margin_right", 14)
	_map_padding.add_theme_constant_override("margin_top", 12)
	_map_padding.add_theme_constant_override("margin_bottom", 12)
	_map_shell.add_child(_map_padding)

	var map_vbox := VBoxContainer.new()
	map_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_vbox.add_theme_constant_override("separation", 6)
	_map_padding.add_child(map_vbox)

	_directory_title = Label.new()
	_directory_title.text = "SHOPPING DIRECTORY"
	_directory_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_directory_title.add_theme_font_override("font", VCR_FONT)
	_directory_title.add_theme_font_size_override("font_size", 22)
	_directory_title.add_theme_color_override("font_color", Color(0.28, 0.20, 0.10))
	map_vbox.add_child(_directory_title)

	_map_view = SubViewportContainer.new()
	_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_view.custom_minimum_size = Vector2(0, 360)
	_map_view.stretch = true
	_map_view.mouse_filter = Control.MOUSE_FILTER_STOP
	map_vbox.add_child(_map_view)

	_map_viewport = SubViewport.new()
	_map_viewport.name = "MapViewport"
	_map_viewport.disable_3d = true
	_map_viewport.transparent_bg = true
	_map_viewport.handle_input_locally = true
	_map_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_map_viewport.size = MallMapLayoutScript.get_board_size()
	_map_viewport.physics_object_picking = true
	_map_view.add_child(_map_viewport)

	_map_root = Node2D.new()
	_map_root.name = "MapRoot"
	_map_viewport.add_child(_map_root)

	_map_hit_surface = Control.new()
	_map_hit_surface.name = "MapHitSurface"
	_map_hit_surface.position = Vector2.ZERO
	_map_hit_surface.size = MallMapLayoutScript.get_board_size()
	_map_hit_surface.mouse_filter = Control.MOUSE_FILTER_STOP
	_map_hit_surface.gui_input.connect(_on_map_gui_input)
	_map_hit_surface.mouse_exited.connect(_on_map_mouse_exited)
	_map_viewport.add_child(_map_hit_surface)

	var directory_separator := HSeparator.new()
	map_vbox.add_child(directory_separator)

	var directory_list_margin := MarginContainer.new()
	directory_list_margin.add_theme_constant_override("margin_left", 4)
	directory_list_margin.add_theme_constant_override("margin_right", 4)
	directory_list_margin.add_theme_constant_override("margin_top", 2)
	directory_list_margin.add_theme_constant_override("margin_bottom", 2)
	map_vbox.add_child(directory_list_margin)

	var directory_list_vbox := VBoxContainer.new()
	directory_list_vbox.add_theme_constant_override("separation", 4)
	directory_list_margin.add_child(directory_list_vbox)

	var directory_list_title := Label.new()
	directory_list_title.text = "STORE DIRECTORY"
	directory_list_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	directory_list_title.add_theme_font_override("font", VCR_FONT)
	directory_list_title.add_theme_font_size_override("font_size", 14)
	directory_list_title.add_theme_color_override("font_color", Color(0.30, 0.22, 0.10))
	directory_list_vbox.add_child(directory_list_title)

	_directory_grid = GridContainer.new()
	_directory_grid.columns = 5
	_directory_grid.add_theme_constant_override("h_separation", 6)
	_directory_grid.add_theme_constant_override("v_separation", 2)
	directory_list_vbox.add_child(_directory_grid)

	var side_panel := PanelContainer.new()
	side_panel.name = "InfoPanel"
	side_panel.custom_minimum_size = Vector2(286, 0)
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell_hbox.add_child(side_panel)

	var side_style := StyleBoxFlat.new()
	side_style.bg_color = Color(0.15, 0.12, 0.18, 0.98)
	side_style.border_color = Color(0.28, 0.78, 0.92, 1.0)
	side_style.set_border_width_all(4)
	side_style.set_corner_radius_all(18)
	side_style.corner_detail = 8
	side_panel.add_theme_stylebox_override("panel", side_style)

	var side_margin := MarginContainer.new()
	side_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	side_margin.add_theme_constant_override("margin_left", 14)
	side_margin.add_theme_constant_override("margin_right", 14)
	side_margin.add_theme_constant_override("margin_top", 14)
	side_margin.add_theme_constant_override("margin_bottom", 14)
	side_panel.add_child(side_margin)

	var side_vbox := VBoxContainer.new()
	side_vbox.add_theme_constant_override("separation", 6)
	side_margin.add_child(side_vbox)

	var title_label := Label.new()
	title_label.text = "SELECT STORE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", VCR_FONT)
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.74))
	side_vbox.add_child(title_label)

	section_chip = Label.new()
	section_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section_chip.add_theme_font_override("font", VCR_FONT)
	section_chip.add_theme_font_size_override("font_size", 11)
	side_vbox.add_child(section_chip)

	zone_name_label = Label.new()
	zone_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	zone_name_label.add_theme_font_override("font", VCR_FONT)
	zone_name_label.add_theme_font_size_override("font_size", 22)
	zone_name_label.add_theme_color_override("font_color", Color(0.96, 0.95, 0.88))
	zone_name_label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.10))
	zone_name_label.add_theme_constant_override("outline_size", 3)
	side_vbox.add_child(zone_name_label)

	channel_label = Label.new()
	channel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	channel_label.add_theme_font_override("font", VCR_FONT)
	channel_label.add_theme_font_size_override("font_size", 34)
	channel_label.add_theme_color_override("font_color", Color(0.28, 0.96, 0.44))
	side_vbox.add_child(channel_label)

	var status_row := HBoxContainer.new()
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status_row.add_theme_constant_override("separation", 10)
	side_vbox.add_child(status_row)

	checkmark_icon = Label.new()
	checkmark_icon.add_theme_font_override("font", VCR_FONT)
	checkmark_icon.add_theme_font_size_override("font_size", 18)
	checkmark_icon.visible = false
	status_row.add_child(checkmark_icon)

	completion_label = Label.new()
	completion_label.add_theme_font_override("font", VCR_FONT)
	completion_label.add_theme_font_size_override("font_size", 12)
	status_row.add_child(completion_label)

	multiplier_label = Label.new()
	multiplier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	multiplier_label.add_theme_font_override("font", VCR_FONT)
	multiplier_label.add_theme_font_size_override("font_size", 18)
	multiplier_label.add_theme_color_override("font_color", Color(0.70, 0.94, 0.78))
	side_vbox.add_child(multiplier_label)

	difficulty_label = Label.new()
	difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	difficulty_label.add_theme_font_override("font", VCR_FONT)
	difficulty_label.add_theme_font_size_override("font_size", 15)
	side_vbox.add_child(difficulty_label)

	description_label = Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.custom_minimum_size = Vector2(0, 52)
	description_label.add_theme_font_override("font", VCR_FONT)
	description_label.add_theme_font_size_override("font_size", 11)
	description_label.add_theme_color_override("font_color", Color(0.84, 0.84, 0.88))
	side_vbox.add_child(description_label)

	bonus_label = Label.new()
	bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bonus_label.add_theme_font_override("font", VCR_FONT)
	bonus_label.add_theme_font_size_override("font_size", 12)
	bonus_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.36))
	side_vbox.add_child(bonus_label)

	_keyboard_hint_label = Label.new()
	_keyboard_hint_label.text = "ARROWS MOVE  •  ENTER START"
	_keyboard_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keyboard_hint_label.add_theme_font_override("font", VCR_FONT)
	_keyboard_hint_label.add_theme_font_size_override("font_size", 11)
	_keyboard_hint_label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.84))
	side_vbox.add_child(_keyboard_hint_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_vbox.add_child(spacer)

	var buttons_hbox := HBoxContainer.new()
	buttons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_hbox.add_theme_constant_override("separation", 12)
	side_vbox.add_child(buttons_hbox)

	down_button = _create_action_button("PREV")
	down_button.pressed.connect(_on_down_pressed)
	_connect_button_fx(down_button)
	buttons_hbox.add_child(down_button)

	up_button = _create_action_button("NEXT")
	up_button.pressed.connect(_on_up_pressed)
	_connect_button_fx(up_button)
	buttons_hbox.add_child(up_button)

	start_button = Button.new()
	start_button.name = "StartButton"
	start_button.theme = ACTION_THEME
	start_button.text = "START"
	start_button.custom_minimum_size = Vector2(210, 48)
	start_button.add_theme_font_override("font", VCR_FONT)
	start_button.add_theme_font_size_override("font_size", 22)
	start_button.pressed.connect(_on_start_pressed)
	_connect_button_fx(start_button)
	side_vbox.add_child(start_button)

	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.name = "MallTooltip"
	_tooltip_panel.visible = false
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.z_index = 4000
	_tooltip_panel.custom_minimum_size = Vector2(220, 0)
	add_child(_tooltip_panel)

	var tooltip_style := StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.12, 0.10, 0.14, 0.98)
	tooltip_style.border_color = Color(0.95, 0.86, 0.42, 1.0)
	tooltip_style.set_border_width_all(3)
	tooltip_style.set_corner_radius_all(14)
	_tooltip_panel.add_theme_stylebox_override("panel", tooltip_style)

	var tooltip_margin := MarginContainer.new()
	tooltip_margin.add_theme_constant_override("margin_left", 12)
	tooltip_margin.add_theme_constant_override("margin_right", 12)
	tooltip_margin.add_theme_constant_override("margin_top", 10)
	tooltip_margin.add_theme_constant_override("margin_bottom", 10)
	_tooltip_panel.add_child(tooltip_margin)

	_tooltip_label = Label.new()
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_label.custom_minimum_size = Vector2(220, 0)
	_tooltip_label.add_theme_font_override("font", VCR_FONT)
	_tooltip_label.add_theme_font_size_override("font_size", 13)
	_tooltip_label.add_theme_color_override("font_color", Color(0.96, 0.95, 0.88))
	tooltip_margin.add_child(_tooltip_label)


func _build_map_if_needed() -> void:
	if _zones_by_channel.size() > 0:
		_apply_progress_state(false)
		return

	for child in _map_root.get_children():
		child.queue_free()
	_zones_by_channel.clear()
	_zone_order.clear()
	_corridor_lines.clear()
	_wayfinding_nodes.clear()

	_build_directory_backdrop()
	_build_corridors()
	_build_wayfinding_blocks()
	_build_zones()
	_build_directory_index()
	_apply_progress_state(false)


func _build_directory_backdrop() -> void:
	var paper := Polygon2D.new()
	paper.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(MallMapLayoutScript.get_board_size().x, 0),
		MallMapLayoutScript.get_board_size(),
		Vector2(0, MallMapLayoutScript.get_board_size().y),
	])
	paper.color = Color(0.96, 0.91, 0.80, 0.98)
	_map_root.add_child(paper)

	var mall_frame_rect: Rect2 = MallMapLayoutScript.get_map_frame()
	var frame := Line2D.new()
	frame.width = 6.0
	frame.default_color = Color(0.72, 0.60, 0.40, 1.0)
	frame.points = PackedVector2Array([
		mall_frame_rect.position,
		Vector2(mall_frame_rect.end.x, mall_frame_rect.position.y),
		mall_frame_rect.end,
		Vector2(mall_frame_rect.position.x, mall_frame_rect.end.y),
		mall_frame_rect.position,
	])
	_map_root.add_child(frame)

	var directory_separator := Line2D.new()
	directory_separator.width = 2.0
	directory_separator.default_color = Color(0.62, 0.52, 0.34, 0.82)
	directory_separator.points = PackedVector2Array([
		Vector2(mall_frame_rect.position.x + 8.0, MallMapLayoutScript.get_directory_top()),
		Vector2(mall_frame_rect.end.x - 8.0, MallMapLayoutScript.get_directory_top())
	])
	_map_root.add_child(directory_separator)

	var intersection_data := MallMapLayoutScript.get_intersection_shape()
	if not intersection_data.is_empty():
		var intersection_poly := Polygon2D.new()
		intersection_poly.polygon = intersection_data.get("points", PackedVector2Array())
		intersection_poly.color = Color(0.89, 0.80, 0.58, 0.98)
		_map_root.add_child(intersection_poly)

		var intersection_outline := Line2D.new()
		intersection_outline.width = 3.0
		intersection_outline.default_color = Color(0.64, 0.54, 0.34, 1.0)
		intersection_outline.points = _closed_points(intersection_data.get("points", PackedVector2Array()))
		_map_root.add_child(intersection_outline)


func _build_corridors() -> void:
	for path in MallMapLayoutScript.get_corridor_paths():
		var corridor := Line2D.new()
		corridor.width = MallMapLayoutScript.get_corridor_width()
		corridor.default_color = Color(0.82, 0.68, 0.42, 0.95)
		corridor.joint_mode = Line2D.LINE_JOINT_ROUND
		corridor.begin_cap_mode = Line2D.LINE_CAP_ROUND
		corridor.end_cap_mode = Line2D.LINE_CAP_ROUND
		corridor.points = path
		corridor.modulate.a = 0.0
		_map_root.add_child(corridor)
		_corridor_lines.append(corridor)


func _build_wayfinding_blocks() -> void:
	for block in MallMapLayoutScript.get_wayfinding_blocks():
		var root := Node2D.new()
		root.modulate.a = 0.0
		_map_root.add_child(root)

		var poly := Polygon2D.new()
		poly.polygon = block.get("points", PackedVector2Array())
		poly.color = Color(0.90, 0.85, 0.74, 1.0)
		root.add_child(poly)

		var outline := Line2D.new()
		outline.width = 3.0
		outline.default_color = Color(0.62, 0.52, 0.34, 1.0)
		outline.points = _closed_points(block.get("points", PackedVector2Array()))
		root.add_child(outline)

		var label := Label.new()
		label.text = block.get("label", "")
		label.position = block.get("label_pos", Vector2.ZERO) - Vector2(50, 10)
		label.size = Vector2(100, 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", VCR_FONT)
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color(0.32, 0.24, 0.12))
		root.add_child(label)

		_wayfinding_nodes.append(root)


func _build_zones() -> void:
	if channel_manager == null:
		return

	for layout in MallMapLayoutScript.get_zone_layouts():
		var channel: int = int(layout.get("channel", 1))
		var zone = MallMapZoneScript.new()
		var accent := _get_section_color(channel_manager.get_selector_section_id(channel))
		var zone_data := {
			"channel": channel,
			"label_text": channel_manager.get_channel_display_text(channel),
			"zone_name": channel_manager.get_selector_zone_name(channel),
			"directory_label": channel_manager.get_selector_directory_label(channel),
			"section_id": channel_manager.get_selector_section_id(channel),
			"tooltip_flavor": channel_manager.get_selector_tooltip_flavor(channel),
			"points": layout.get("points", PackedVector2Array()),
			"label_pos": layout.get("label_pos", Vector2.ZERO),
		}
		zone.configure(zone_data, accent)
		zone.zone_hovered.connect(_on_zone_hovered)
		zone.zone_unhovered.connect(_on_zone_unhovered)
		zone.zone_pressed.connect(_on_zone_pressed)
		_map_root.add_child(zone)
		_zones_by_channel[channel] = zone
		_zone_order.append(channel)

	_zone_order.sort()


func _build_directory_index() -> void:
	if _directory_grid == null or channel_manager == null:
		return
	for child in _directory_grid.get_children():
		child.queue_free()
	for channel in _zone_order:
		var entry := HBoxContainer.new()
		entry.custom_minimum_size = Vector2(118, 22)
		entry.add_theme_constant_override("separation", 4)
		_directory_grid.add_child(entry)

		var number_label := Label.new()
		number_label.text = channel_manager.get_channel_display_text(channel)
		number_label.add_theme_font_override("font", VCR_FONT)
		number_label.add_theme_font_size_override("font_size", 10)
		number_label.add_theme_color_override("font_color", _get_section_color(channel_manager.get_selector_section_id(channel)))
		entry.add_child(number_label)

		var name_label := Label.new()
		name_label.text = channel_manager.get_selector_directory_label(channel).to_upper()
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.custom_minimum_size = Vector2(88, 0)
		name_label.add_theme_font_override("font", VCR_FONT)
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.add_theme_color_override("font_color", Color(0.24, 0.18, 0.10))
		entry.add_child(name_label)


func _build_legend() -> void:
	for child in _map_legend.get_children():
		child.queue_free()
	for section_id in ["eatery", "entertainment", "lifestyle", "specialty", "major_stores"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_map_legend.add_child(row)

		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(26, 12)
		swatch.color = _get_section_color(section_id)
		row.add_child(swatch)

		var label := Label.new()
		label.text = SECTION_LABELS.get(section_id, section_id.to_upper())
		label.add_theme_font_override("font", VCR_FONT)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(0.90, 0.90, 0.94))
		row.add_child(label)


func _create_action_button(text: String) -> Button:
	var button := Button.new()
	button.theme = ACTION_THEME
	button.text = text
	button.custom_minimum_size = Vector2(90, 38)
	button.add_theme_font_override("font", VCR_FONT)
	button.add_theme_font_size_override("font_size", 14)
	return button


func _connect_button_fx(button: BaseButton) -> void:
	if _tfx == null:
		return
	button.mouse_entered.connect(_tfx.button_hover.bind(button))
	button.mouse_exited.connect(_tfx.button_unhover.bind(button))
	button.pressed.connect(_tfx.button_press.bind(button))


## _update_display() -> void
##
## Updates labels, button state, and selector visuals for the active channel.
func _update_display() -> void:
	if not channel_manager:
		return
	if zone_name_label == null:
		return

	var current_channel: int = channel_manager.current_channel
	_selected_channel = current_channel

	channel_label.text = channel_manager.get_channel_display_text()
	zone_name_label.text = channel_manager.get_selector_zone_name(current_channel).to_upper()
	section_chip.text = SECTION_LABELS.get(channel_manager.get_selector_section_id(current_channel), "DIRECTORY")
	section_chip.add_theme_color_override("font_color", _get_section_color(channel_manager.get_selector_section_id(current_channel)))

	var mult = channel_manager.get_difficulty_multiplier()
	multiplier_label.text = "%.2fx TARGET" % mult
	difficulty_label.text = channel_manager.get_difficulty_description()
	description_label.text = channel_manager.get_selector_tooltip_flavor(current_channel)
	if description_label.text.is_empty():
		description_label.text = channel_manager.get_channel_display_name()

	var is_locked := false
	if channel_manager.has_method("is_channel_unlocked"):
		is_locked = not channel_manager.is_channel_unlocked(current_channel)

	_update_completion_status()
	_update_bonus_preview()
	_update_start_button_state(is_locked)
	_update_difficulty_color(mult, is_locked)
	_sync_selection_from_manager(true)


func _update_difficulty_color(mult: float, is_locked: bool) -> void:
	if is_locked:
		difficulty_label.add_theme_color_override("font_color", Color(0.58, 0.58, 0.62))
	elif mult < 1.1:
		difficulty_label.add_theme_color_override("font_color", Color(0.48, 1.0, 0.56))
	elif mult < 2.0:
		difficulty_label.add_theme_color_override("font_color", Color(0.94, 0.92, 0.54))
	elif mult < 5.0:
		difficulty_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.34))
	elif mult < 15.0:
		difficulty_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.24))
	elif mult < 40.0:
		difficulty_label.add_theme_color_override("font_color", Color(1.0, 0.22, 0.22))
	else:
		difficulty_label.add_theme_color_override("font_color", Color(0.86, 0.20, 0.54))


## _update_completion_status() -> void
##
## Updates status indicators and applies completion/lock visuals to the map.
func _update_completion_status() -> void:
	if not checkmark_icon or not completion_label or not channel_manager:
		return

	var progress_manager = get_node_or_null("/root/ProgressManager")
	if not progress_manager:
		return

	var current_channel = channel_manager.current_channel
	var is_locked := false
	var required_completions := 0
	if channel_manager.has_method("is_channel_unlocked"):
		is_locked = not channel_manager.is_channel_unlocked(current_channel)
		required_completions = channel_manager.get_unlock_requirement(current_channel)

	if is_locked:
		checkmark_icon.visible = true
		checkmark_icon.text = "LOCK"
		checkmark_icon.add_theme_color_override("font_color", Color(0.68, 0.68, 0.72))
		var completed_channels = progress_manager.get_completed_channel_count() if progress_manager.has_method("get_completed_channel_count") else 0
		completion_label.text = "Locked (%d/%d)" % [completed_channels, required_completions]
		completion_label.add_theme_color_override("font_color", Color(0.68, 0.68, 0.72))
	else:
		var is_completed = progress_manager.is_channel_completed(current_channel)
		if is_completed:
			checkmark_icon.visible = true
			checkmark_icon.text = "CLEAR"
			checkmark_icon.add_theme_color_override("font_color", Color(0.32, 0.98, 0.48))
			completion_label.text = "Cleared"
			completion_label.add_theme_color_override("font_color", Color(0.32, 0.98, 0.48))
		else:
			checkmark_icon.visible = false
			completion_label.text = "Not Completed"
			completion_label.add_theme_color_override("font_color", Color(0.70, 0.70, 0.74))

	_apply_progress_state(true)


## _update_bonus_preview() -> void
##
## Updates the side-panel bonus summary for the current channel.
func _update_bonus_preview() -> void:
	if not bonus_label or not channel_manager:
		return

	var current_channel = channel_manager.current_channel
	var bonus_data = channel_manager.get_channel_start_bonus(current_channel)
	var parts: Array[String] = []
	if bonus_data["bonus_money"] > 0:
		parts.append("+$%d" % bonus_data["bonus_money"])
	if bonus_data["bonus_powerup_count"] > 0:
		parts.append("%d PowerUp" % bonus_data["bonus_powerup_count"])
	if bonus_data["bonus_consumable_count"] > 0:
		parts.append("%d Consumable" % bonus_data["bonus_consumable_count"])
	if bonus_data["bonus_level_boost_count"] > 0:
		parts.append("%d Level Up" % bonus_data["bonus_level_boost_count"])

	if parts.is_empty():
		bonus_label.text = "No starting bonus"
	else:
		bonus_label.text = "BONUS: " + ", ".join(parts)


## _update_start_button_state(is_locked) -> void
##
## Updates the start button appearance based on lock status.
func _update_start_button_state(is_locked: bool) -> void:
	if not start_button:
		return
	if is_locked:
		start_button.text = "LOCKED"
		start_button.disabled = true
		start_button.modulate = Color(0.62, 0.62, 0.66)
	else:
		start_button.text = "START"
		start_button.disabled = false
		start_button.modulate = Color.WHITE


## _show_locked_feedback() -> void
##
## Shows visual feedback when player tries to start a locked channel.
func _show_locked_feedback() -> void:
	if not start_button:
		return
	if _tfx:
		_tfx.button_denied(start_button)
	var tween := create_tween()
	start_button.modulate = Color(1.0, 0.36, 0.36)
	tween.tween_property(start_button, "modulate", Color(0.62, 0.62, 0.66), 0.18)


## _on_up_pressed() -> void
##
## Advances to the next mall zone.
func _on_up_pressed() -> void:
	if channel_manager:
		channel_manager.increment_channel()
		_trigger_channel_glitch(+1)


## _on_down_pressed() -> void
##
## Moves to the previous mall zone.
func _on_down_pressed() -> void:
	if channel_manager:
		channel_manager.decrement_channel()
		_trigger_channel_glitch(-1)


## _on_start_pressed() -> void
##
## Confirms the current zone selection and starts the run.
func _on_start_pressed() -> void:
	if channel_manager:
		if channel_manager.has_method("is_channel_unlocked"):
			if not channel_manager.is_channel_unlocked(channel_manager.current_channel):
				_show_locked_feedback()
				return
		channel_manager.select_channel()
		emit_signal("start_pressed", channel_manager.current_channel)
	hide_channel_selector()


## _on_channel_changed(new_channel: int) -> void
##
## Keeps the directory visuals in sync with ChannelManager.
func _on_channel_changed(_new_channel: int) -> void:
	_update_display()


func _on_zone_hovered(channel: int) -> void:
	_hovered_channel = channel
	_show_zone_tooltip(channel)


func _on_zone_unhovered(channel: int) -> void:
	if _hovered_channel == channel:
		_hovered_channel = -1
	_hide_tooltip(true)


func _on_zone_pressed(channel: int) -> void:
	if not channel_manager:
		return
	if channel_manager.has_method("is_channel_unlocked") and not channel_manager.is_channel_unlocked(channel):
		channel_manager.set_channel(channel)
		_trigger_channel_glitch(1)
		_show_locked_feedback()
		return
	channel_manager.set_channel(channel)
	_trigger_channel_glitch(1)


func _on_map_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_update_hover_from_point(motion.position)
	elif event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.button_index == MOUSE_BUTTON_LEFT and button_event.pressed:
			var channel := _find_zone_at_point(button_event.position)
			if channel > 0:
				_on_zone_pressed(channel)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or channel_manager == null:
		return
	if event.is_action_pressed("ui_left"):
		_keyboard_select(Vector2.LEFT, -1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_keyboard_select(Vector2.RIGHT, 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_keyboard_select(Vector2.UP, -1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_keyboard_select(Vector2.DOWN, 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_on_start_pressed()
		get_viewport().set_input_as_handled()


func _update_hover_from_point(board_point: Vector2) -> void:
	var channel := _find_zone_at_point(board_point)
	if channel == _hovered_channel:
		return
	if _hovered_channel > 0 and _zones_by_channel.has(_hovered_channel):
		var old_zone = _zones_by_channel[_hovered_channel]
		old_zone.set_hovered(false, true)
		_hide_tooltip(true)
	_hovered_channel = channel
	if _hovered_channel > 0 and _zones_by_channel.has(_hovered_channel):
		var new_zone = _zones_by_channel[_hovered_channel]
		new_zone.set_hovered(true, true)
		_show_zone_tooltip(_hovered_channel)


func _find_zone_at_point(board_point: Vector2) -> int:
	for channel in _zone_order:
		var zone = _zones_by_channel.get(channel)
		if zone and zone.contains_local_point(board_point):
			return channel
	return -1


func _keyboard_select(direction: Vector2, fallback_step: int) -> void:
	var next_channel := _find_neighbor_channel(direction)
	if next_channel <= 0:
		next_channel = _get_fallback_channel(fallback_step)
	if next_channel <= 0 or next_channel == channel_manager.current_channel:
		return
	channel_manager.set_channel(next_channel)
	_trigger_channel_glitch(1 if fallback_step >= 0 else -1)


func _find_neighbor_channel(direction: Vector2) -> int:
	var current_zone = _zones_by_channel.get(channel_manager.current_channel)
	if current_zone == null:
		return -1
	var current_center: Vector2 = current_zone.get_center_point()
	var best_channel := -1
	var best_score := INF
	var perpendicular := Vector2(-direction.y, direction.x)
	for channel in _zone_order:
		if channel == channel_manager.current_channel:
			continue
		var zone = _zones_by_channel.get(channel)
		if zone == null:
			continue
		var offset: Vector2 = zone.get_center_point() - current_center
		var forward := offset.dot(direction)
		if forward <= 2.0:
			continue
		var lateral: float = absf(offset.dot(perpendicular))
		var score: float = offset.length() + lateral * 1.4
		if score < best_score:
			best_score = score
			best_channel = channel
	return best_channel


func _get_fallback_channel(step: int) -> int:
	var current_index := _zone_order.find(channel_manager.current_channel)
	if current_index < 0:
		return -1
	var next_index := clampi(current_index + step, 0, _zone_order.size() - 1)
	return _zone_order[next_index]


func _show_zone_tooltip(channel: int) -> void:
	if _tooltip_panel == null or channel_manager == null:
		return
	var zone = _zones_by_channel.get(channel)
	if zone == null:
		return

	var text_lines: Array[String] = []
	text_lines.append("%s  %s" % [channel_manager.get_channel_display_text(channel), channel_manager.get_selector_zone_name(channel)])
	text_lines.append("Section: %s" % SECTION_LABELS.get(channel_manager.get_selector_section_id(channel), "DIRECTORY"))
	text_lines.append("Difficulty: %s (%.2fx)" % [channel_manager.get_difficulty_description(channel), channel_manager.get_difficulty_multiplier(channel)])
	var flavor: String = channel_manager.get_selector_tooltip_flavor(channel)
	if not flavor.is_empty():
		text_lines.append("")
		text_lines.append(flavor)
	_tooltip_label.text = "\n".join(text_lines)
	_tooltip_panel.visible = true
	_tooltip_panel.reset_size()
	if _tfx:
		_tfx.place_tooltip(_tooltip_panel, _get_zone_screen_rect(zone), SIDE_RIGHT, true)
	else:
		_tooltip_panel.global_position = _get_zone_screen_rect(zone).end + Vector2(12, -16)


func _on_map_mouse_exited() -> void:
	if _hovered_channel > 0 and _zones_by_channel.has(_hovered_channel):
		var zone = _zones_by_channel[_hovered_channel]
		zone.set_hovered(false, true)
	_hovered_channel = -1
	_hide_tooltip(true)


func _hide_tooltip(animate: bool) -> void:
	if _tooltip_panel == null:
		return
	if not animate:
		_tooltip_panel.visible = false
		_tooltip_panel.modulate.a = 1.0
		return
	if _tfx:
		var tween: Tween = _tfx.tooltip_fade_out(_tooltip_panel, 0.08)
		if tween:
			tween.finished.connect(func():
				if is_instance_valid(_tooltip_panel):
					_tooltip_panel.visible = false
					_tooltip_panel.modulate.a = 1.0
			)
			return
	_tooltip_panel.visible = false


func _apply_progress_state(animate: bool) -> void:
	var progress_manager = get_node_or_null("/root/ProgressManager")
	for channel in _zone_order:
		var zone = _zones_by_channel.get(channel)
		if zone == null:
			continue
		var is_completed := false
		if progress_manager and progress_manager.has_method("is_channel_completed"):
			is_completed = progress_manager.is_channel_completed(channel)
		var is_locked := false
		if channel_manager and channel_manager.has_method("is_channel_unlocked"):
			is_locked = not channel_manager.is_channel_unlocked(channel)
		zone.set_completed(is_completed, animate)
		zone.set_locked(is_locked, animate)
		zone.set_selected(channel == channel_manager.current_channel, animate)


func _sync_selection_from_manager(animate: bool) -> void:
	_apply_progress_state(animate)


## _trigger_channel_glitch(direction: int) -> void
##
## Triggers a brief static hit and wakes the selected map zone.
func _trigger_channel_glitch(direction: int) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("glitch_intensity", 0.55)
		_shader_material.set_shader_parameter("horizontal_tear", 0.18)
		_shader_material.set_shader_parameter("brightness_spike", 0.28)
		_shader_material.set_shader_parameter("rgb_split", 0.03)
		var shader_tween = create_tween().set_parallel()
		shader_tween.tween_property(_shader_material, "shader_parameter/glitch_intensity", 0.0, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		shader_tween.tween_property(_shader_material, "shader_parameter/horizontal_tear", 0.0, 0.18)
		shader_tween.tween_property(_shader_material, "shader_parameter/brightness_spike", 0.0, 0.14)
		shader_tween.tween_property(_shader_material, "shader_parameter/rgb_split", 0.0, 0.18)

	_shake_panel(0.12, 4.0)
	var zone = _zones_by_channel.get(channel_manager.current_channel)
	if zone:
		zone.set_selected(true, true)
		if direction > 0:
			zone.rotation_degrees = 1.0
		else:
			zone.rotation_degrees = -1.0
		var zone_tween := create_tween()
		zone_tween.tween_property(zone, "rotation_degrees", 0.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_method("play_static_burst"):
		audio_manager.play_static_burst()


## _shake_panel(duration: float, intensity: float) -> void
##
## Brief shell shake for the selection board.
func _shake_panel(duration: float, intensity: float) -> void:
	if not panel_container:
		return
	var original_pos = panel_container.position
	var shake_tween = create_tween()
	shake_tween.tween_property(panel_container, "position:x", original_pos.x + intensity, duration * 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	shake_tween.tween_property(panel_container, "position:x", original_pos.x - intensity * 0.6, duration * 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	shake_tween.tween_property(panel_container, "position:x", original_pos.x, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## _animate_entrance() -> void
##
## Staged mall-directory entrance: overlay, title card, corridor trace, shell settle.
func _animate_entrance() -> void:
	_fit_shell_to_viewport()
	panel_container.modulate.a = 0.0
	panel_container.scale = Vector2.ONE
	panel_container.pivot_offset = panel_container.size / 2.0
	overlay.modulate.a = 0.0
	shader_overlay.modulate.a = 0.0
	_intro_label.visible = true
	_intro_label.modulate.a = 0.0
	_intro_label.pivot_offset = Vector2(220, 26)

	for corridor in _corridor_lines:
		corridor.modulate.a = 0.0
	for block in _wayfinding_nodes:
		block.modulate.a = 0.0
	for channel in _zone_order:
		var zone = _zones_by_channel[channel]
		zone.modulate.a = 0.0
		zone.scale = Vector2(0.96, 0.96)

	var overlay_tween = create_tween()
	overlay_tween.tween_property(overlay, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await overlay_tween.finished

	var shader_tween = create_tween()
	shader_tween.tween_property(shader_overlay, "modulate:a", 0.55, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await shader_tween.finished

	_intro_label.modulate.a = 1.0
	var label_tween = TweenFX.drop_in(_intro_label, 0.55, 130.0, Vector2(1.25, 0.78))
	await label_tween.finished
	await get_tree().create_timer(0.55).timeout
	var vanish_tween = TweenFX.vanish(_intro_label, 0.28)
	await vanish_tween.finished
	_intro_label.visible = false

	var panel_original_pos: Vector2 = panel_container.position
	var panel_original_scale: Vector2 = panel_container.scale
	var entrance_offset_y := _get_safe_entrance_offset_y(panel_original_pos)
	panel_container.position = panel_original_pos + Vector2(0, entrance_offset_y)
	panel_container.scale = Vector2(1.02, 0.98)
	var panel_tween = create_tween()
	panel_tween.tween_property(panel_container, "position", panel_original_pos, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	panel_tween.parallel().tween_property(panel_container, "scale", panel_original_scale, 0.40).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	panel_tween.parallel().tween_property(panel_container, "modulate:a", 1.0, 0.22)
	await panel_tween.finished

	var delay := 0.0
	for corridor in _corridor_lines:
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_property(corridor, "modulate:a", 1.0, 0.18)
		delay += 0.06

	var block_delay := 0.08
	for block in _wayfinding_nodes:
		var block_tween := create_tween()
		block_tween.tween_interval(block_delay)
		block_tween.tween_property(block, "modulate:a", 1.0, 0.16)
		block_delay += 0.04

	var zone_delay := 0.12
	for channel in _zone_order:
		var zone = _zones_by_channel[channel]
		zone.play_reveal(zone_delay)
		zone_delay += 0.03


## _animate_exit() -> void
##
## Fades the board out and clears the tooltip.
func _animate_exit() -> void:
	var panel_tween = TweenFX.drop_out(panel_container, 0.38, 420.0)
	await panel_tween.finished

	var shader_tween = create_tween()
	shader_tween.tween_property(shader_overlay, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await shader_tween.finished

	var overlay_tween = create_tween()
	overlay_tween.tween_property(overlay, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await overlay_tween.finished

	visible = false


func _get_section_color(section_id: String) -> Color:
	return SECTION_COLORS.get(section_id, Color(0.30, 0.82, 0.45, 1.0))


func _fit_shell_to_viewport() -> void:
	if panel_container == null or not is_inside_tree():
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var available := viewport_size - SHELL_VIEWPORT_MARGIN * 2.0
	var target_size := Vector2(
		minf(available.x, SHELL_MAX_SIZE.x),
		minf(available.y, SHELL_MAX_SIZE.y)
	)
	target_size.x = maxf(target_size.x, minf(SHELL_MIN_SIZE.x, available.x))
	target_size.y = maxf(target_size.y, minf(SHELL_MIN_SIZE.y, available.y))
	panel_container.size = target_size
	panel_container.position = (viewport_size - target_size) * 0.5


func _on_root_resized() -> void:
	if visible:
		_fit_shell_to_viewport()


func _get_safe_entrance_offset_y(panel_original_pos: Vector2) -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	var bottom_margin := viewport_size.y - (panel_original_pos.y + panel_container.size.y)
	return minf(96.0, maxf(bottom_margin - 6.0, 0.0))


func _get_zone_screen_rect(zone) -> Rect2:
	var board_rect: Rect2 = zone.get_anchor_rect()
	var view_rect := _map_view.get_global_rect()
	var board_size: Vector2 = MallMapLayoutScript.get_board_size()
	var scale_x := 1.0
	var scale_y := 1.0
	if board_size.x > 0.0:
		scale_x = view_rect.size.x / board_size.x
	if board_size.y > 0.0:
		scale_y = view_rect.size.y / board_size.y
	var rect_position := view_rect.position + Vector2(board_rect.position.x * scale_x, board_rect.position.y * scale_y)
	var rect_size := Vector2(board_rect.size.x * scale_x, board_rect.size.y * scale_y)
	return Rect2(rect_position, rect_size)


func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(points)
	if not closed.is_empty():
		closed.append(closed[0])
	return closed
