extends RefCounted
class_name MallMapLayout

## MallMapLayout
##
## Fixed, deterministic mall directory layout:
## - MAP_FRAME bounds the mall; the courtyard is a rotated square at its center.
## - Four corridor arms radiate from the courtyard to the frame edges (N/S/E/W).
## - Exactly four wing zones (channels 1-4): north-west, north-east,
##   south-west, south-east. Each zone is an L: a long horizontal bar with a
##   short vertical stub at its courtyard-side end, the short leg of the L
##   reaching toward the center diamond.

const BOARD_SIZE := Vector2(900, 640)
const MAP_FRAME := Rect2(20, 20,700, 340)
const DIRECTORY_LIST_TOP := 348.0

const MAIN_CORRIDOR_WIDTH := 85.0
const INTERSECTION_RADIUS := 85.0

const ZONE_EDGE_MARGIN := 14.0
const ZONE_BAR_WIDTH := 320.0
const ZONE_BAR_HEIGHT := 90.0
const ZONE_STUB_WIDTH := 44.0
const ZONE_STUB_LENGTH := 56.0

static var _layout_cache: Dictionary = {}


static func get_board_size() -> Vector2:
	return BOARD_SIZE


static func get_map_frame() -> Rect2:
	return MAP_FRAME


static func get_directory_top() -> float:
	return DIRECTORY_LIST_TOP


static func get_layout_data() -> Dictionary:
	if _layout_cache.is_empty():
		_layout_cache = _build_layout()
	return _layout_cache.duplicate(true)


static func invalidate_layout_cache() -> void:
	_layout_cache.clear()


static func get_corridor_paths() -> Array[PackedVector2Array]:
	var layout_data := get_layout_data()
	return layout_data.get("corridors", []).duplicate(true)


static func get_corridor_width() -> float:
	var layout_data := get_layout_data()
	return layout_data.get("corridor_width", MAIN_CORRIDOR_WIDTH)


static func get_intersection_shape() -> Dictionary:
	var layout_data := get_layout_data()
	return layout_data.get("intersection", {}).duplicate(true)


static func get_wayfinding_blocks() -> Array[Dictionary]:
	var layout_data := get_layout_data()
	return layout_data.get("wayfinding_blocks", []).duplicate(true)


static func get_zone_layouts() -> Array[Dictionary]:
	var layout_data := get_layout_data()
	return layout_data.get("zones", []).duplicate(true)


static func get_debug_build_steps() -> Array[Dictionary]:
	var layout_data := get_layout_data()
	var zones: Array = layout_data.get("zones", [])
	return [
		{
			"label": "frame",
			"intersection": {},
			"corridors": [],
			"zones": [],
		},
		{
			"label": "intersection",
			"intersection": layout_data.get("intersection", {}).duplicate(true),
			"corridors": [],
			"zones": [],
		},
		{
			"label": "walkway",
			"intersection": layout_data.get("intersection", {}).duplicate(true),
			"corridors": layout_data.get("corridors", []).duplicate(true),
			"zones": [],
		},
		{
			"label": "zones",
			"intersection": layout_data.get("intersection", {}).duplicate(true),
			"corridors": layout_data.get("corridors", []).duplicate(true),
			"zones": zones.duplicate(true),
		},
		{
			"label": "full_layout",
			"intersection": layout_data.get("intersection", {}).duplicate(true),
			"corridors": layout_data.get("corridors", []).duplicate(true),
			"zones": zones.duplicate(true),
		},
	]


static func _build_layout() -> Dictionary:
	var frame := MAP_FRAME
	var cross_point := frame.position + frame.size * 0.5
	var cross_x := cross_point.x
	var cross_y := cross_point.y

	var intersection := {
		"center": cross_point,
		"radius": INTERSECTION_RADIUS,
		"points": PackedVector2Array([
			Vector2(cross_x, cross_y - INTERSECTION_RADIUS),
			Vector2(cross_x + INTERSECTION_RADIUS, cross_y),
			Vector2(cross_x, cross_y + INTERSECTION_RADIUS),
			Vector2(cross_x - INTERSECTION_RADIUS, cross_y),
		]),
	}

	# +/- 50/60 adjustments to the corridor endpoints to avoid overlapping with the frame edges
	var corridors: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(frame.position.x + 50, cross_y), Vector2(cross_x - INTERSECTION_RADIUS, cross_y)]),
		PackedVector2Array([Vector2(cross_x + INTERSECTION_RADIUS, cross_y), Vector2(frame.end.x -50 , cross_y)]),
		PackedVector2Array([Vector2(cross_x, frame.position.y +60), Vector2(cross_x, cross_y - INTERSECTION_RADIUS)]),
		PackedVector2Array([Vector2(cross_x, cross_y + INTERSECTION_RADIUS), Vector2(cross_x, frame.end.y -60)]),
	]

	var bar_w := ZONE_BAR_WIDTH
	var bar_h := ZONE_BAR_HEIGHT
	# bar_h was removed and +70 and -160 are manual adjustments to the north and south bar positions
	var north_bar_y := frame.position.y + ZONE_EDGE_MARGIN + 50
	var south_bar_y := frame.end.y - ZONE_EDGE_MARGIN - 140
	var west_bar_x := frame.position.x + ZONE_EDGE_MARGIN
	var east_bar_x := frame.end.x - ZONE_EDGE_MARGIN - bar_w

	# stub bools were flipped to make them fit correctly
	var zones: Array[Dictionary] = [
		_build_wing_zone(1, Rect2(west_bar_x, north_bar_y, bar_w, bar_h), false),
		_build_wing_zone(2, Rect2(east_bar_x, north_bar_y, bar_w, bar_h), false),
		_build_wing_zone(3, Rect2(west_bar_x, south_bar_y, bar_w, bar_h), true),
		_build_wing_zone(4, Rect2(east_bar_x, south_bar_y, bar_w, bar_h), true),
	]
	var wayfinding_blocks: Array[Dictionary] = []

	return {
		"cross_point": cross_point,
		"intersection": intersection,
		"corridors": corridors,
		"corridor_width": MAIN_CORRIDOR_WIDTH,
		"zones": zones,
		"wayfinding_blocks": wayfinding_blocks,
		"bounds": frame,
	}


## _build_wing_zone(channel, bar_rect, stub_below) -> Dictionary
##
## Builds one wing zone: a horizontal bar plus a short vertical stub at the
## bar end nearest the courtyard, forming an L whose short leg points at the
## center diamond (down for north wings, up for south wings). West-side
## channels (1, 3) anchor the stub to the bar's right edge; east-side
## channels (2, 4) anchor it to the left edge.
static func _build_wing_zone(channel: int, bar_rect: Rect2, stub_below: bool) -> Dictionary:
	var left := bar_rect.position.x
	var top := bar_rect.position.y
	var right := bar_rect.end.x
	var bottom := bar_rect.end.y
	var stub_at_right := channel == 1 or channel == 3
	var stub_left := left
	if stub_at_right:
		stub_left = right - ZONE_STUB_WIDTH
	var stub_right := stub_left + ZONE_STUB_WIDTH

	var points: PackedVector2Array
	if stub_below:
		var stub_bottom := bottom + ZONE_STUB_LENGTH
		points = PackedVector2Array([
			Vector2(left, top),
			Vector2(right, top),
			Vector2(right, bottom),
			Vector2(stub_right, bottom),
			Vector2(stub_right, stub_bottom),
			Vector2(stub_left, stub_bottom),
			Vector2(stub_left, bottom),
			Vector2(left, bottom),
		])
	else:
		var stub_top := top - ZONE_STUB_LENGTH
		points = PackedVector2Array([
			Vector2(left, top),
			Vector2(stub_left, top),
			Vector2(stub_left, stub_top),
			Vector2(stub_right, stub_top),
			Vector2(stub_right, top),
			Vector2(right, top),
			Vector2(right, bottom),
			Vector2(left, bottom),
		])

	return _zone(channel, points, bar_rect.position + bar_rect.size * 0.5, bar_rect)


static func _zone(channel: int, points: PackedVector2Array, label_pos: Vector2, bar_rect: Rect2 = Rect2()) -> Dictionary:
	return {
		"channel": channel,
		"points": points,
		"label_pos": label_pos,
		# The horizontal bar area of the L (stub excluded). Read-only layout
		# data; consumers like MallMapPopup use it to place store markers.
		"bar_rect": bar_rect,
	}
