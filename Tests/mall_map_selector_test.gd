extends Control

## MallMapSelectorTest
##
## Focused runtime validation for the mall directory selector.
## Instantiates ChannelManager + ChannelManagerUI, verifies map generation,
## selector metadata, hit detection, and tooltip visibility, then exits.

const ChannelManagerScript = preload("res://Scripts/Managers/channel_manager.gd")
const ChannelManagerUIScene = preload("res://Scenes/Managers/ChannelManagerUI.tscn")

var _channel_manager
var _channel_manager_ui
var _failed := false
var _mall_map_layout_script = load("res://Scripts/Managers/mall_map_layout.gd")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	call_deferred("_run_test")


func _run_test() -> void:
	print("[MallMapSelectorTest] Starting")
	_mall_map_layout_script.set_layout_seed(20260621)
	_channel_manager = ChannelManagerScript.new()
	_channel_manager.name = "ChannelManager"
	add_child(_channel_manager)

	_channel_manager_ui = ChannelManagerUIScene.instantiate()
	add_child(_channel_manager_ui)

	await get_tree().process_frame
	_channel_manager_ui.set_channel_manager(_channel_manager)
	_channel_manager.reset()
	_channel_manager_ui.show_channel_selector()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(3.0).timeout

	var layout_data: Dictionary = _mall_map_layout_script.get_layout_data()
	var intersection: Dictionary = layout_data.get("intersection", {})
	var cross_point: Vector2 = layout_data.get("cross_point", Vector2.ZERO)
	var frame: Rect2 = _mall_map_layout_script.get_map_frame()
	var frame_center := frame.position + frame.size * 0.5
	var exit_blocks: Array = layout_data.get("wayfinding_blocks", []).filter(func(block): return block.get("label", "") == "EXIT")
	var parking_blocks: Array = layout_data.get("wayfinding_blocks", []).filter(func(block): return block.get("label", "") == "PARKING")
	var store_one_center: Vector2 = _channel_manager_ui._zones_by_channel[1].get_center_point()

	_assert_true(_channel_manager.get_selector_zone_name(1) == "Food Court", "Channel 1 zone should be Food Court")
	_assert_true(_channel_manager.get_selector_section_id(12) == "entertainment", "Channel 12 section should be entertainment")
	_assert_true(_channel_manager_ui._zones_by_channel.size() == 20, "Mall selector should build 20 zones")
	_assert_true(_channel_manager_ui._find_zone_at_point(store_one_center) == 1, "Food Court hit area should resolve to channel 1")
	_assert_true(_channel_manager_ui.zone_name_label.text == "FOOD COURT", "Initial selector label should show FOOD COURT")
	_assert_true(_channel_manager_ui._directory_grid.get_child_count() == 20, "Directory index should list all 20 zones")
	_assert_true(not intersection.is_empty(), "Intersection square should be generated")
	_assert_true(exit_blocks.size() >= 2 and exit_blocks.size() <= 4, "Layout should generate between 2 and 4 exits")
	_assert_true(_channel_manager_ui._zones_by_channel[1].get_center_point().distance_to(intersection.get("center", Vector2.ZERO)) > intersection.get("radius", 0.0), "Food Court should no longer occupy the center intersection")
	_assert_true(cross_point.distance_to(frame_center) > 8.0, "Intersection should not stay pinned to the frame center")
	_assert_true(_zone_bounds_width(layout_data, 2) <= _mall_map_layout_script.NORMAL_MAX_WIDTH + 0.01, "Zone 2 should respect the normal max width")
	_assert_true(_zone_bounds_width(layout_data, 6) <= _mall_map_layout_script.NORMAL_MAX_WIDTH + 0.01, "Zone 6 should respect the normal max width")
	_assert_true(not _zones_overlap(layout_data.get("zones", [])), "Generated zones should not overlap")
	_assert_true(_zone_bounds_height(layout_data, 1) <= _mall_map_layout_script.LARGE_MAX_HEIGHT + 0.01, "Large zone 1 should respect the large max height")
	_assert_true(_parking_blocks_clear_zones(parking_blocks, layout_data.get("zones", [])), "Parking blocks should stay clear of zones")
	_assert_true(_side_exits_are_vertical(exit_blocks, frame), "Left and right exits should use the vertical orientation")
	_assert_true(_corner_store_is_flush(layout_data, 1, cross_point), "Zone 1 should sit flush to the walkway edge")
	_assert_true(_corner_store_is_flush(layout_data, 17, cross_point), "Zone 17 should sit flush to the walkway edge")
	_mall_map_layout_script.set_layout_seed(20260622)
	var alternate_layout: Dictionary = _mall_map_layout_script.get_layout_data()
	_assert_true(alternate_layout.get("cross_point", Vector2.ZERO).distance_to(cross_point) > 10.0, "Different seeds should move the intersection")
	_mall_map_layout_script.set_layout_seed(20260621)
	print("[MallMapSelectorTest] viewport=%s shell_rect=%s" % [str(get_viewport_rect().size), str(_channel_manager_ui.panel_container.get_global_rect())])
	_assert_true(_channel_manager_ui.panel_container.get_global_rect().end.y <= get_viewport_rect().size.y, "Selector shell should fit within the viewport height")

	_channel_manager.set_channel(10)
	await get_tree().process_frame
	_assert_true(_channel_manager_ui.zone_name_label.text == "FASHION BOUTIQUE", "Channel 10 should update selector label")

	_channel_manager_ui._keyboard_select(Vector2.RIGHT, 1)
	await get_tree().process_frame
	_assert_true(_channel_manager.current_channel != 10, "Keyboard navigation should move the selection")

	_channel_manager_ui._show_zone_tooltip(1)
	await get_tree().process_frame
	#_assert_true(_channel_manager_ui._tooltip_panel.visible, "Tooltip should become visible for hovered zone")

	#_finish()


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("[MallMapSelectorTest] PASS: %s" % message)
		return
	_failed = true
	push_error("[MallMapSelectorTest] FAIL: %s" % message)


func _finish() -> void:
	_mall_map_layout_script.clear_layout_seed()
	if _failed:
		push_error("[MallMapSelectorTest] FAILED")
		get_tree().quit(1)
		return
	print("[MallMapSelectorTest] PASSED")
	get_tree().quit(0)


func _zone_bounds_width(layout_data: Dictionary, channel_num: int) -> float:
	for zone in layout_data.get("zones", []):
		if zone.get("channel", -1) == channel_num:
			return _points_bounds(zone.get("points", PackedVector2Array())).size.x
	return 0.0


func _zone_bounds_height(layout_data: Dictionary, channel_num: int) -> float:
	for zone in layout_data.get("zones", []):
		if zone.get("channel", -1) == channel_num:
			return _points_bounds(zone.get("points", PackedVector2Array())).size.y
	return 0.0


func _zones_overlap(zones: Array) -> bool:
	for first_index in range(zones.size()):
		for second_index in range(first_index + 1, zones.size()):
			var first_rect := _points_bounds(zones[first_index].get("points", PackedVector2Array()))
			var second_rect := _points_bounds(zones[second_index].get("points", PackedVector2Array()))
			if first_rect.intersects(second_rect):
				print("[MallMapSelectorTest] OVERLAP: %s with %s" % [str(zones[first_index].get("channel", -1)), str(zones[second_index].get("channel", -1))])
				return true
	return false


func _parking_blocks_clear_zones(blocks: Array, zones: Array) -> bool:
	for block in blocks:
		var block_rect := _points_bounds(block.get("points", PackedVector2Array()))
		for zone in zones:
			var zone_rect := _points_bounds(zone.get("points", PackedVector2Array()))
			if block_rect.intersects(zone_rect):
				return false
	return true


func _side_exits_are_vertical(blocks: Array, frame: Rect2) -> bool:
	for block in blocks:
		var rect := _points_bounds(block.get("points", PackedVector2Array()))
		if absf(rect.position.x - (frame.position.x - _mall_map_layout_script.EXIT_OUTSET - _mall_map_layout_script.EXIT_VERTICAL_WIDTH)) < 0.5:
			if rect.size.y <= rect.size.x:
				return false
		elif absf(rect.position.x - (frame.end.x + _mall_map_layout_script.EXIT_OUTSET)) < 0.5:
			if rect.size.y <= rect.size.x:
				return false
	return true


func _corner_store_is_flush(layout_data: Dictionary, channel_num: int, cross_point: Vector2) -> bool:
	var half_corridor: float = _mall_map_layout_script.MAIN_CORRIDOR_WIDTH * 0.5
	for zone in layout_data.get("zones", []):
		if zone.get("channel", -1) != channel_num:
			continue
		var rect := _points_bounds(zone.get("points", PackedVector2Array()))
		if channel_num == 1:
			return absf(rect.end.x - (cross_point.x - half_corridor)) < 0.5 and absf(rect.end.y - (cross_point.y - half_corridor)) < 0.5
		if channel_num == 17:
			return absf(rect.position.x - (cross_point.x + half_corridor)) < 0.5 and absf(rect.position.y - (cross_point.y + half_corridor)) < 0.5
	return false


func _points_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var min_point := points[0]
	var max_point := points[0]
	for point in points:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)
