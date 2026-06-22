extends RefCounted
class_name MallMapLayout

## MallMapLayout
##
## Simplified mall selector layout rules:
## - Walkway is always a plus shape.
## - The intersection is always a rotated square.
## - Four large corner stores face the intersection with one 45-degree cut edge.
## - Remaining stores are packed into four non-overlapping horizontal strips.
## - Every store fronts directly onto the walkway and remains fully visible.
## - Exits appear on 2-4 walkway endpoints; parking remains outside the frame.

const BOARD_SIZE := Vector2(900, 640)
const MAP_FRAME := Rect2(20, 20,760, 380)
const DIRECTORY_LIST_TOP := 348.0

const MAIN_CORRIDOR_WIDTH := 20.0
const INTERSECTION_RADIUS := 45.0

const NORMAL_MIN_WIDTH := 42.0
const NORMAL_MAX_WIDTH := 110.0
const NORMAL_MIN_HEIGHT := 34.0
const NORMAL_MAX_HEIGHT := 82.0

const LARGE_MIN_WIDTH := 110.0
const LARGE_MAX_WIDTH := 160.0
const LARGE_MIN_HEIGHT := 74.0
const LARGE_MAX_HEIGHT := 160.0

const EXIT_WIDTH := 58.0
const EXIT_HEIGHT := 18.0
const EXIT_VERTICAL_WIDTH := 18.0
const EXIT_VERTICAL_HEIGHT := 58.0
const EXIT_OUTSET := 10.0
const INNER_STORE_GAP := 10.0
const LARGE_STORE_PADDING := 10.0

const LARGE_CHANNELS := [1, 5, 10, 17]
const HORIZONTAL_STRIPS := {
	"west_upper": [2, 3, 4],
	"west_lower": [6, 7, 8, 9],
	"east_upper": [12, 13, 19, 20],
	"east_lower": [11, 14, 15, 16, 18],
}

static var _layout_cache: Dictionary = {}
static var _layout_seed: int = -1
static var _resolved_layout_seed: int = -1


static func get_board_size() -> Vector2:
	return BOARD_SIZE


static func get_map_frame() -> Rect2:
	return MAP_FRAME


static func get_directory_top() -> float:
	return DIRECTORY_LIST_TOP


static func set_layout_seed(layout_seed: int) -> void:
	_layout_seed = layout_seed
	_resolved_layout_seed = layout_seed
	invalidate_layout_cache()


static func clear_layout_seed() -> void:
	_layout_seed = -1
	_resolved_layout_seed = -1
	invalidate_layout_cache()


static func get_layout_seed() -> int:
	_ensure_layout_seed()
	return _resolved_layout_seed


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
			"label": "corner_stores",
			"intersection": layout_data.get("intersection", {}).duplicate(true),
			"corridors": layout_data.get("corridors", []).duplicate(true),
			"zones": _filter_zones_by_channels(layout_data.get("zones", []), LARGE_CHANNELS),
		},
		{
			"label": "full_layout",
			"intersection": layout_data.get("intersection", {}).duplicate(true),
			"corridors": layout_data.get("corridors", []).duplicate(true),
			"zones": layout_data.get("zones", []).duplicate(true),
		},
	]


static func _build_layout() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = get_layout_seed()
	var frame := MAP_FRAME
	var half_corridor := MAIN_CORRIDOR_WIDTH * 0.5

	var safe_min_x := frame.position.x + LARGE_MAX_WIDTH + LARGE_STORE_PADDING + INTERSECTION_RADIUS + half_corridor
	var safe_max_x := frame.end.x - LARGE_MAX_WIDTH - LARGE_STORE_PADDING - INTERSECTION_RADIUS - half_corridor
	var safe_min_y := frame.position.y + LARGE_MAX_HEIGHT + LARGE_STORE_PADDING + INTERSECTION_RADIUS + half_corridor
	var safe_max_y := frame.end.y - LARGE_MAX_HEIGHT - LARGE_STORE_PADDING - INTERSECTION_RADIUS - half_corridor

	var cross_x := rng.randf_range(safe_min_x, safe_max_x)
	var cross_y := rng.randf_range(safe_min_y, safe_max_y)
	var cross_point := Vector2(cross_x, cross_y)

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

	var corridors: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(frame.position.x, cross_y), Vector2(cross_x - INTERSECTION_RADIUS, cross_y)]),
		PackedVector2Array([Vector2(cross_x + INTERSECTION_RADIUS, cross_y), Vector2(frame.end.x, cross_y)]),
		PackedVector2Array([Vector2(cross_x, frame.position.y), Vector2(cross_x, cross_y - INTERSECTION_RADIUS)]),
		PackedVector2Array([Vector2(cross_x, cross_y + INTERSECTION_RADIUS), Vector2(cross_x, frame.end.y)]),
	]

	var zones: Array[Dictionary] = []
	var exits := _pick_exit_arms(rng)
	var corner_gap := half_corridor

	var top_left_size := Vector2(rng.randf_range(LARGE_MIN_WIDTH, LARGE_MAX_WIDTH), rng.randf_range(LARGE_MIN_HEIGHT, LARGE_MAX_HEIGHT))
	var top_right_size := Vector2(rng.randf_range(LARGE_MIN_WIDTH, LARGE_MAX_WIDTH), rng.randf_range(LARGE_MIN_HEIGHT, LARGE_MAX_HEIGHT))
	var bottom_left_size := Vector2(rng.randf_range(LARGE_MIN_WIDTH, LARGE_MAX_WIDTH), rng.randf_range(LARGE_MIN_HEIGHT, LARGE_MAX_HEIGHT))
	var bottom_right_size := Vector2(rng.randf_range(LARGE_MIN_WIDTH, LARGE_MAX_WIDTH), rng.randf_range(LARGE_MIN_HEIGHT, LARGE_MAX_HEIGHT))

	var top_left_rect := Rect2(cross_x - corner_gap - top_left_size.x, cross_y - corner_gap - top_left_size.y, top_left_size.x, top_left_size.y)
	var top_right_rect := Rect2(cross_x + corner_gap, cross_y - corner_gap - top_right_size.y, top_right_size.x, top_right_size.y)
	var bottom_left_rect := Rect2(cross_x - corner_gap - bottom_left_size.x, cross_y + corner_gap, bottom_left_size.x, bottom_left_size.y)
	var bottom_right_rect := Rect2(cross_x + corner_gap, cross_y + corner_gap, bottom_right_size.x, bottom_right_size.y)

	zones.append(_build_corner_store(1, top_left_rect, "bottom_right", INTERSECTION_RADIUS))
	zones.append(_build_corner_store(5, top_right_rect, "bottom_left", INTERSECTION_RADIUS))
	zones.append(_build_corner_store(10, bottom_left_rect, "top_right", INTERSECTION_RADIUS))
	zones.append(_build_corner_store(17, bottom_right_rect, "top_left", INTERSECTION_RADIUS))

	var west_upper_len := top_left_rect.position.x - frame.position.x
	var west_lower_len := bottom_left_rect.position.x - frame.position.x
	var east_upper_len := frame.end.x - top_right_rect.end.x
	var east_lower_len := frame.end.x - bottom_right_rect.end.x

	var upper_available := maxf(minf(top_left_rect.size.y, top_right_rect.size.y) - INNER_STORE_GAP, NORMAL_MIN_HEIGHT)
	var lower_available := maxf(minf(bottom_left_rect.size.y, bottom_right_rect.size.y) - INNER_STORE_GAP, NORMAL_MIN_HEIGHT)
	var west_upper_height := minf(rng.randf_range(NORMAL_MIN_HEIGHT, NORMAL_MAX_HEIGHT), upper_available)
	var west_lower_height := minf(rng.randf_range(NORMAL_MIN_HEIGHT, NORMAL_MAX_HEIGHT), lower_available)
	var east_upper_height := minf(rng.randf_range(NORMAL_MIN_HEIGHT, NORMAL_MAX_HEIGHT), upper_available)
	var east_lower_height := minf(rng.randf_range(NORMAL_MIN_HEIGHT, NORMAL_MAX_HEIGHT), lower_available)

	var west_upper_widths := _split_horizontal_span(rng, west_upper_len, HORIZONTAL_STRIPS["west_upper"].size())
	var west_lower_widths := _split_horizontal_span(rng, west_lower_len, HORIZONTAL_STRIPS["west_lower"].size())
	var east_upper_widths := _split_horizontal_span(rng, east_upper_len, HORIZONTAL_STRIPS["east_upper"].size())
	var east_lower_widths := _split_horizontal_span(rng, east_lower_len, HORIZONTAL_STRIPS["east_lower"].size())

	_append_horizontal_strip(zones, cross_y - half_corridor - west_upper_height, west_upper_widths, west_upper_height, HORIZONTAL_STRIPS["west_upper"], frame.position.x)
	_append_horizontal_strip(zones, cross_y + half_corridor, west_lower_widths, west_lower_height, HORIZONTAL_STRIPS["west_lower"], frame.position.x)
	_append_horizontal_strip(zones, cross_y - half_corridor - east_upper_height, east_upper_widths, east_upper_height, HORIZONTAL_STRIPS["east_upper"], top_right_rect.end.x)
	_append_horizontal_strip(zones, cross_y + half_corridor, east_lower_widths, east_lower_height, HORIZONTAL_STRIPS["east_lower"], bottom_right_rect.end.x)

	var wayfinding_blocks := _build_wayfinding_blocks(exits, cross_point, frame)

	return {
		"cross_point": cross_point,
		"intersection": intersection,
		"corridors": corridors,
		"corridor_width": MAIN_CORRIDOR_WIDTH,
		"zones": zones,
		"wayfinding_blocks": wayfinding_blocks,
		"exit_arms": exits,
		"large_channels": LARGE_CHANNELS.duplicate(),
		"bounds": frame,
		"seed": get_layout_seed(),
	}


static func _split_horizontal_span(rng: RandomNumberGenerator, total: float, segment_count: int) -> Array[float]:
	var clamped_total := clampf(total, NORMAL_MIN_WIDTH * float(segment_count), NORMAL_MAX_WIDTH * float(segment_count))
	var values: Array[float] = []
	var remaining := clamped_total
	for index in range(segment_count):
		var slots_left := segment_count - index - 1
		if slots_left == 0:
			values.append(remaining)
			break
		var min_value := maxf(NORMAL_MIN_WIDTH, remaining - NORMAL_MAX_WIDTH * slots_left)
		var max_value := minf(NORMAL_MAX_WIDTH, remaining - NORMAL_MIN_WIDTH * slots_left)
		var chosen := rng.randf_range(min_value, max_value)
		values.append(chosen)
		remaining -= chosen
	return values


static func _append_horizontal_strip(zones: Array[Dictionary], top_y: float, widths: Array[float], height: float, channels: Array, start_x: float) -> void:
	var cursor := start_x
	for index in range(mini(widths.size(), channels.size())):
		var width: float = widths[index]
		var channel: int = int(channels[index])
		zones.append(_zone_from_rect(channel, Rect2(cursor, top_y, width, height)))
		cursor += width


static func _build_corner_store(channel: int, rect: Rect2, cut_corner: String, chamfer_size: float) -> Dictionary:
	return _zone_from_chamfered_rect(channel, rect, cut_corner, minf(chamfer_size, minf(rect.size.x, rect.size.y) * 0.55))


static func _pick_exit_arms(rng: RandomNumberGenerator) -> Array[String]:
	var arm_pool := ["left", "right", "top", "bottom"]
	for index in range(arm_pool.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temp = arm_pool[index]
		arm_pool[index] = arm_pool[swap_index]
		arm_pool[swap_index] = temp
	var exit_count := rng.randi_range(2, 4)
	var exits: Array[String] = []
	for index in range(exit_count):
		exits.append(arm_pool[index])
	return exits


static func _build_wayfinding_blocks(exit_arms: Array, cross_point: Vector2, frame: Rect2) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	var parking_width := 96.0
	var parking_height := 24.0
	blocks.append(_block("PARKING", _rect_points(frame.position.x + 10.0, frame.position.y + 6.0, parking_width, parking_height), Vector2(frame.position.x + 10.0 + parking_width * 0.5, frame.position.y + 18.0)))
	blocks.append(_block("PARKING", _rect_points(frame.end.x - parking_width - 10.0, frame.position.y + 6.0, parking_width, parking_height), Vector2(frame.end.x - parking_width * 0.5 - 10.0, frame.position.y + 18.0)))
	for arm in exit_arms:
		blocks.append(_build_exit_block(arm, cross_point, frame))
	return blocks


static func _build_exit_block(arm: String, cross_point: Vector2, frame: Rect2) -> Dictionary:
	match arm:
		"left":
			return _block("EXIT", _rect_points(frame.position.x - EXIT_OUTSET - EXIT_VERTICAL_WIDTH, cross_point.y - EXIT_VERTICAL_HEIGHT * 0.5, EXIT_VERTICAL_WIDTH, EXIT_VERTICAL_HEIGHT), Vector2(frame.position.x - EXIT_OUTSET - EXIT_VERTICAL_WIDTH * 0.5, cross_point.y))
		"right":
			return _block("EXIT", _rect_points(frame.end.x + EXIT_OUTSET, cross_point.y - EXIT_VERTICAL_HEIGHT * 0.5, EXIT_VERTICAL_WIDTH, EXIT_VERTICAL_HEIGHT), Vector2(frame.end.x + EXIT_OUTSET + EXIT_VERTICAL_WIDTH * 0.5, cross_point.y))
		"top":
			return _block("EXIT", _rect_points(cross_point.x - EXIT_WIDTH * 0.5, frame.position.y - EXIT_OUTSET - EXIT_HEIGHT, EXIT_WIDTH, EXIT_HEIGHT), Vector2(cross_point.x, frame.position.y - EXIT_OUTSET - EXIT_HEIGHT * 0.5))
		_:
			return _block("EXIT", _rect_points(cross_point.x - EXIT_WIDTH * 0.5, frame.end.y + EXIT_OUTSET, EXIT_WIDTH, EXIT_HEIGHT), Vector2(cross_point.x, frame.end.y + EXIT_OUTSET + EXIT_HEIGHT * 0.5))


static func _filter_zones_by_channels(zones: Array, channels: Array[int]) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for zone in zones:
		var channel: int = zone.get("channel", -1)
		if channels.has(channel):
			filtered.append(zone.duplicate(true))
	return filtered


static func _ensure_layout_seed() -> void:
	if _resolved_layout_seed >= 0:
		return
	if _layout_seed >= 0:
		_resolved_layout_seed = _layout_seed
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_resolved_layout_seed = rng.randi_range(1, 2147483646)


static func _zone_from_rect(channel: int, rect: Rect2) -> Dictionary:
	return _zone(channel, _rect_points(rect.position.x, rect.position.y, rect.size.x, rect.size.y), rect.position + rect.size * 0.5)


static func _zone_from_chamfered_rect(channel: int, rect: Rect2, cut_corner: String, chamfer_size: float) -> Dictionary:
	return _zone(channel, _chamfered_points(rect, cut_corner, chamfer_size), rect.position + rect.size * 0.5)


static func _chamfered_points(rect: Rect2, cut_corner: String, chamfer_size: float) -> PackedVector2Array:
	var left := rect.position.x
	var top := rect.position.y
	var right := rect.position.x + rect.size.x
	var bottom := rect.position.y + rect.size.y

	match cut_corner:
		"top_left":
			return PackedVector2Array([
				Vector2(left + chamfer_size, top),
				Vector2(right, top),
				Vector2(right, bottom),
				Vector2(left, bottom),
				Vector2(left, top + chamfer_size),
			])
		"top_right":
			return PackedVector2Array([
				Vector2(left, top),
				Vector2(right - chamfer_size, top),
				Vector2(right, top + chamfer_size),
				Vector2(right, bottom),
				Vector2(left, bottom),
			])
		"bottom_left":
			return PackedVector2Array([
				Vector2(left, top),
				Vector2(right, top),
				Vector2(right, bottom),
				Vector2(left + chamfer_size, bottom),
				Vector2(left, bottom - chamfer_size),
			])
		"bottom_right":
			return PackedVector2Array([
				Vector2(left, top),
				Vector2(right, top),
				Vector2(right, bottom - chamfer_size),
				Vector2(right - chamfer_size, bottom),
				Vector2(left, bottom),
			])
		_:
			return _rect_points(left, top, rect.size.x, rect.size.y)


static func _zone(channel: int, points: PackedVector2Array, label_pos: Vector2) -> Dictionary:
	return {
		"channel": channel,
		"points": points,
		"label_pos": label_pos,
	}


static func _block(label_text: String, points: PackedVector2Array, label_pos: Vector2) -> Dictionary:
	return {
		"label": label_text,
		"points": points,
		"label_pos": label_pos,
	}


static func _rect_points(x: float, y: float, width: float, height: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x, y),
		Vector2(x + width, y),
		Vector2(x + width, y + height),
		Vector2(x, y + height),
	])
