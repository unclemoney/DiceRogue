extends Control

## MallLayoutDebugTest
##
## Interactive debug scene for stepping through mall generation.
## Shows the frame, corridors, and zone placement in stages so the layout
## rules can be inspected without opening the full channel selector UI.

const MallMapZoneScript = preload("res://Scripts/Managers/mall_map_zone.gd")
const VCR_FONT = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

const SECTION_COLORS := {
	"eatery": Color(0.96, 0.76, 0.18, 1.0),
	"entertainment": Color(0.86, 0.25, 0.46, 1.0),
	"lifestyle": Color(0.29, 0.78, 0.95, 1.0),
	"specialty": Color(0.30, 0.82, 0.45, 1.0),
	"major_stores": Color(0.97, 0.46, 0.16, 1.0),
}

const STORE_SECTIONS := {
	1: "eatery",
	2: "entertainment",
	3: "specialty",
	4: "specialty",
	5: "major_stores",
	6: "entertainment",
	7: "eatery",
	8: "specialty",
	9: "specialty",
	10: "lifestyle",
	11: "lifestyle",
	12: "entertainment",
	13: "entertainment",
	14: "lifestyle",
	15: "specialty",
	16: "lifestyle",
	17: "lifestyle",
	18: "specialty",
	19: "major_stores",
	20: "major_stores",
}

const STORE_NAMES := {
	1: "FOOD COURT",
	2: "ARCADE",
	3: "BOOKSTORE",
	4: "HOBBY STORE",
	5: "DEPARTMENT STORE",
	6: "VIDEO RENTALS",
	7: "COFFEE CORNER",
	8: "TOY STORE",
	9: "ELECTRONICS",
	10: "FASHION BOUTIQUE",
	11: "JEWELRY",
	12: "CINEMA",
	13: "MUSIC SHOP",
	14: "SPORTS OUTLET",
	15: "PET STORE",
	16: "PERFUME SHOP",
	17: "FURNITURE",
	18: "PHOTO STUDIO",
	19: "SEARS",
	20: "J-MART",
}

var _board_root: Control
var _map_view: SubViewportContainer
var _map_viewport: SubViewport
var _map_root: Node2D
var _stage_label: Label
var _info_label: RichTextLabel
var _current_stage: int = 0
var _steps: Array[Dictionary] = []
var _mall_map_layout_script = load("res://Scripts/Managers/mall_map_layout.gd")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_steps = _mall_map_layout_script.get_debug_build_steps()
	_render_stage(0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept"):
		_render_stage(mini(_current_stage + 1, _steps.size() - 1))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_render_stage(maxi(_current_stage - 1, 0))
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var outer := MarginContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 24)
	outer.add_theme_constant_override("margin_right", 24)
	outer.add_theme_constant_override("margin_top", 24)
	outer.add_theme_constant_override("margin_bottom", 24)
	add_child(outer)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	outer.add_child(hbox)

	_board_root = Control.new()
	_board_root.custom_minimum_size = Vector2(920, 430)
	_board_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(_board_root)

	_map_view = SubViewportContainer.new()
	_map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_view.stretch = true
	_map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_root.add_child(_map_view)

	_map_viewport = SubViewport.new()
	_map_viewport.disable_3d = true
	_map_viewport.transparent_bg = true
	_map_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_map_viewport.size = _mall_map_layout_script.get_board_size()
	_map_view.add_child(_map_viewport)

	_map_root = Node2D.new()
	_map_viewport.add_child(_map_root)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(320, 430)
	side.add_theme_constant_override("separation", 12)
	hbox.add_child(side)

	_stage_label = Label.new()
	_stage_label.add_theme_font_override("font", VCR_FONT)
	_stage_label.add_theme_font_size_override("font_size", 26)
	_stage_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.74))
	side.add_child(_stage_label)

	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = false
	_info_label.fit_content = true
	_info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_label.add_theme_font_override("normal_font", VCR_FONT)
	_info_label.add_theme_font_size_override("normal_font_size", 14)
	side.add_child(_info_label)

	var hint := Label.new()
	hint.text = "RIGHT / ENTER: Next Stage\nLEFT: Previous Stage"
	hint.add_theme_font_override("font", VCR_FONT)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.78, 0.82, 0.90))
	side.add_child(hint)


func _render_stage(stage_index: int) -> void:
	_current_stage = stage_index
	for child in _map_root.get_children():
		child.queue_free()

	var mall_frame: Rect2 = _mall_map_layout_script.get_map_frame()
	var paper := Polygon2D.new()
	paper.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(_mall_map_layout_script.get_board_size().x, 0),
		_mall_map_layout_script.get_board_size(),
		Vector2(0, _mall_map_layout_script.get_board_size().y),
	])
	paper.color = Color(0.96, 0.91, 0.80, 0.98)
	_map_root.add_child(paper)

	var frame := Line2D.new()
	frame.width = 5.0
	frame.default_color = Color(0.72, 0.60, 0.40, 1.0)
	frame.points = PackedVector2Array([
		mall_frame.position,
		Vector2(mall_frame.end.x, mall_frame.position.y),
		mall_frame.end,
		Vector2(mall_frame.position.x, mall_frame.end.y),
		mall_frame.position,
	])
	_map_root.add_child(frame)

	var separator := Line2D.new()
	separator.width = 2.0
	separator.default_color = Color(0.62, 0.52, 0.34, 0.82)
	separator.points = PackedVector2Array([
		Vector2(mall_frame.position.x + 8.0, _mall_map_layout_script.get_directory_top()),
		Vector2(mall_frame.end.x - 8.0, _mall_map_layout_script.get_directory_top()),
	])
	_map_root.add_child(separator)

	var step := _steps[stage_index]
	var intersection: Dictionary = step.get("intersection", {})
	if not intersection.is_empty():
		var poly := Polygon2D.new()
		poly.polygon = intersection.get("points", PackedVector2Array())
		poly.color = Color(0.89, 0.80, 0.58, 0.98)
		_map_root.add_child(poly)

		var outline := Line2D.new()
		outline.width = 3.0
		outline.default_color = Color(0.64, 0.54, 0.34, 1.0)
		outline.points = _closed_points(intersection.get("points", PackedVector2Array()))
		_map_root.add_child(outline)

	for path in step.get("corridors", []):
		var corridor := Line2D.new()
		corridor.width = _mall_map_layout_script.get_corridor_width()
		corridor.default_color = Color(0.82, 0.68, 0.42, 0.95)
		corridor.joint_mode = Line2D.LINE_JOINT_ROUND
		corridor.begin_cap_mode = Line2D.LINE_CAP_ROUND
		corridor.end_cap_mode = Line2D.LINE_CAP_ROUND
		corridor.points = path
		_map_root.add_child(corridor)

	for zone_data in step.get("zones", []):
		var channel: int = zone_data.get("channel", 1)
		var zone = MallMapZoneScript.new()
		zone.configure({
			"channel": channel,
			"label_text": "%02d" % channel,
			"zone_name": STORE_NAMES.get(channel, "STORE"),
			"directory_label": STORE_NAMES.get(channel, "STORE"),
			"section_id": STORE_SECTIONS.get(channel, "specialty"),
			"tooltip_flavor": "",
			"points": zone_data.get("points", PackedVector2Array()),
			"label_pos": zone_data.get("label_pos", Vector2.ZERO),
		}, SECTION_COLORS.get(STORE_SECTIONS.get(channel, "specialty"), Color(0.30, 0.82, 0.45, 1.0)))
		_map_root.add_child(zone)

	_stage_label.text = "Stage %d/%d: %s" % [_current_stage + 1, _steps.size(), str(step.get("label", "layout")).to_upper()]
	_info_label.text = _describe_stage(step)


func _describe_stage(step: Dictionary) -> String:
	var label := str(step.get("label", "layout"))
	match label:
		"frame":
			return "Map frame and directory split only. Use this to confirm the mall bounds and vertical budget."
		"intersection":
			return "Intersection only. Verify the rotated square sits inside the frame and leaves enough room for the four large corner stores."
		"walkway":
			return "Corridors only. Verify the mall uses a simple plus-shaped network with four straight arms meeting the rotated square."
		"corner_stores":
			return "Corner stores only. Check the four large stores wrap the diamond and each uses one 45-degree cut edge facing the intersection."
		_:
			return "Full layout. Inspect corridor clearance, board fit, and store adjacency before opening the full selector."


func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(points)
	if not closed.is_empty():
		closed.append(closed[0])
	return closed