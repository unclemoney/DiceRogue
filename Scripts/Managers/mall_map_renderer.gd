extends RefCounted
class_name MallMapRenderer

## MallMapRenderer
##
## Shared runtime builders for the mall directory map, extracted from
## ChannelManagerUI so both the game-start selector and the in-game
## MallMapPopup render the identical board from MallMapLayout geometry.

const VCR_FONT: Font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
const MallMapLayoutScript = preload("res://Scripts/Managers/mall_map_layout.gd")
const MallMapZoneScript = preload("res://Scripts/Managers/mall_map_zone.gd")

const SECTION_COLORS := {
	"eatery": Color(0.96, 0.76, 0.18, 1.0),
	"entertainment": Color(0.86, 0.25, 0.46, 1.0),
	"lifestyle": Color(0.29, 0.78, 0.95, 1.0),
	"specialty": Color(0.30, 0.82, 0.45, 1.0),
	"major_stores": Color(0.97, 0.46, 0.16, 1.0),
}


## get_section_color(section_id) -> Color
##
## Returns the accent color for a mall section id.
static func get_section_color(section_id: String) -> Color:
	return SECTION_COLORS.get(section_id, Color(0.30, 0.82, 0.45, 1.0))


## close_points(points) -> PackedVector2Array
##
## Returns a copy of the point list closed into a loop.
static func close_points(points: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(points)
	if not closed.is_empty():
		closed.append(closed[0])
	return closed


## build_directory_backdrop(map_root) -> void
##
## Builds the paper base, mall frame, directory separator, and courtyard
## diamond into the given map root.
static func build_directory_backdrop(map_root: Node2D) -> void:
	var paper := Polygon2D.new()
	paper.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(MallMapLayoutScript.get_board_size().x, 0),
		MallMapLayoutScript.get_board_size(),
		Vector2(0, MallMapLayoutScript.get_board_size().y),
	])
	paper.color = Color(0.96, 0.91, 0.80, 0.98)
	map_root.add_child(paper)

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
	map_root.add_child(frame)

	var directory_separator := Line2D.new()
	directory_separator.width = 2.0
	directory_separator.default_color = Color(0.62, 0.52, 0.34, 0.82)
	directory_separator.points = PackedVector2Array([
		Vector2(mall_frame_rect.position.x + 8.0, MallMapLayoutScript.get_directory_top()),
		Vector2(mall_frame_rect.end.x - 8.0, MallMapLayoutScript.get_directory_top())
	])
	map_root.add_child(directory_separator)

	var intersection_data := MallMapLayoutScript.get_intersection_shape()
	if not intersection_data.is_empty():
		var intersection_poly := Polygon2D.new()
		intersection_poly.polygon = intersection_data.get("points", PackedVector2Array())
		intersection_poly.color = Color(0.89, 0.80, 0.58, 0.98)
		map_root.add_child(intersection_poly)

		var intersection_outline := Line2D.new()
		intersection_outline.width = 3.0
		intersection_outline.default_color = Color(0.64, 0.54, 0.34, 1.0)
		intersection_outline.points = close_points(intersection_data.get("points", PackedVector2Array()))
		map_root.add_child(intersection_outline)


## build_corridors(map_root, initial_alpha) -> Array[Line2D]
##
## Builds the corridor lines into the map root and returns them. Lines start
## at initial_alpha (0.0 matches the selector's staged entrance reveal).
static func build_corridors(map_root: Node2D, initial_alpha: float = 0.0) -> Array[Line2D]:
	var corridors: Array[Line2D] = []
	for path in MallMapLayoutScript.get_corridor_paths():
		var corridor := Line2D.new()
		corridor.width = MallMapLayoutScript.get_corridor_width()
		corridor.default_color = Color(0.82, 0.68, 0.42, 0.95)
		corridor.joint_mode = Line2D.LINE_JOINT_ROUND
		corridor.begin_cap_mode = Line2D.LINE_CAP_ROUND
		corridor.end_cap_mode = Line2D.LINE_CAP_ROUND
		corridor.points = path
		corridor.modulate.a = initial_alpha
		map_root.add_child(corridor)
		corridors.append(corridor)
	return corridors


## build_wayfinding_blocks(map_root, initial_alpha) -> Array[Node2D]
##
## Builds the wayfinding blocks into the map root and returns their roots.
static func build_wayfinding_blocks(map_root: Node2D, initial_alpha: float = 0.0) -> Array[Node2D]:
	var blocks: Array[Node2D] = []
	for block in MallMapLayoutScript.get_wayfinding_blocks():
		var root := Node2D.new()
		root.modulate.a = initial_alpha
		map_root.add_child(root)

		var poly := Polygon2D.new()
		poly.polygon = block.get("points", PackedVector2Array())
		poly.color = Color(0.90, 0.85, 0.74, 1.0)
		root.add_child(poly)

		var outline := Line2D.new()
		outline.width = 3.0
		outline.default_color = Color(0.62, 0.52, 0.34, 1.0)
		outline.points = close_points(block.get("points", PackedVector2Array()))
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

		blocks.append(root)
	return blocks


## build_zones(map_root, channel_manager, on_hovered, on_unhovered) -> Dictionary
##
## Builds the wing zones into the map root and returns a Dictionary of
## channel -> MallMapZone. Hover callbacks are optional (pass an invalid
## Callable to skip connecting).
static func build_zones(map_root: Node2D, channel_manager, on_hovered: Callable = Callable(), on_unhovered: Callable = Callable()) -> Dictionary:
	var zones: Dictionary = {}
	if channel_manager == null:
		return zones

	for layout in MallMapLayoutScript.get_zone_layouts():
		var channel: int = int(layout.get("channel", 1))
		var zone = MallMapZoneScript.new()
		var accent := get_section_color(channel_manager.get_selector_section_id(channel))
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
		if on_hovered.is_valid():
			zone.zone_hovered.connect(on_hovered)
		if on_unhovered.is_valid():
			zone.zone_unhovered.connect(on_unhovered)
		map_root.add_child(zone)
		zones[channel] = zone

	return zones
