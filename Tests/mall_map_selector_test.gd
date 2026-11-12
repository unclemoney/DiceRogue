extends Control

## MallMapSelectorTest
##
## Focused runtime validation for the mall directory selector.
## Instantiates ChannelManager + ChannelManagerUI, verifies the fixed
## 4-zone map generation, selector metadata, hit detection, and that
## zone navigation inputs no longer move the selection, then exits.

const ChannelManagerScript = preload("res://Scripts/Managers/channel_manager.gd")
const ChannelManagerUIScene = preload("res://Scenes/Managers/ChannelManagerUI.tscn")

var _channel_manager
var _channel_manager_ui
var _failed := false
var _mall_map_layout_script = load("res://Scripts/Managers/mall_map_layout.gd")
var _mall_map_renderer_script = load("res://Scripts/Managers/mall_map_renderer.gd")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	call_deferred("_run_test")


func _run_test() -> void:
	print("[MallMapSelectorTest] Starting")
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
	var zone_one_center: Vector2 = _channel_manager_ui._zones_by_channel[1].get_center_point()

	_assert_true(_channel_manager.get_selector_zone_name(1) == "North Wing", "Channel 1 zone should be North Wing")
	_assert_true(_channel_manager.get_selector_zone_name(2) == "East Wing", "Channel 2 zone should be East Wing")
	_assert_true(_channel_manager.get_selector_zone_name(3) == "West Wing", "Channel 3 zone should be West Wing")
	_assert_true(_channel_manager.get_selector_zone_name(4) == "South Wing", "Channel 4 zone should be South Wing")
	_assert_true(_channel_manager.get_selector_directory_label(1) == "01", "Channel 1 directory label should be 01")
	_assert_true(_channel_manager.get_selector_directory_label(4) == "04", "Channel 4 directory label should be 04")
	_assert_true(_channel_manager_ui._zones_by_channel.size() == 4, "Mall selector should build exactly 4 zones")
	_assert_true(_channel_manager_ui._find_zone_at_point(zone_one_center) == 1, "North Wing hit area should resolve to channel 1")
	_assert_true(_channel_manager_ui.zone_name_label.text == "NORTH WING", "Initial selector label should show NORTH WING")
	_assert_true(_channel_manager_ui._directory_grid.get_child_count() == 4, "Directory index should list all 4 zones")
	_assert_true(not intersection.is_empty(), "Courtyard diamond should be generated")
	_assert_true(cross_point.distance_to(frame_center) < 1.0, "Fixed layout courtyard should sit at the frame center")
	_assert_true(layout_data.get("corridors", []).size() == 4, "Layout should have exactly 4 corridor arms")
	_assert_true(layout_data.get("wayfinding_blocks", []).is_empty(), "Layout should no longer emit numbered wayfinding plaques")
	var icon_total := 0
	for channel in _channel_manager_ui._store_icons:
		var zone_icons: Array = _channel_manager_ui._store_icons[channel]
		_assert_true(zone_icons.size() == 6, "Zone %d should have exactly 6 store icons" % channel)
		icon_total += zone_icons.size()
	_assert_true(_channel_manager_ui._store_icons.size() == 4, "Selector should have icons for all 4 zones")
	_assert_true(icon_total == 24, "Selector should build exactly 24 store icons (got %d)" % icon_total)
	_assert_true(not _zones_overlap(layout_data.get("zones", [])), "Fixed zones should not overlap")
	_assert_true(_zones_inside_frame(layout_data.get("zones", []), frame), "Fixed zones should stay inside the frame")
	_assert_true(_zone_labels_inside_polygons(layout_data.get("zones", [])), "Zone labels should sit inside their polygons")
	_assert_true(_zone_in_quadrant(layout_data, 1, frame_center, -1.0, -1.0), "Zone 1 should occupy the north-west quadrant")
	_assert_true(_zone_in_quadrant(layout_data, 2, frame_center, 1.0, -1.0), "Zone 2 should occupy the north-east quadrant")
	_assert_true(_zone_in_quadrant(layout_data, 3, frame_center, -1.0, 1.0), "Zone 3 should occupy the south-west quadrant")
	_assert_true(_zone_in_quadrant(layout_data, 4, frame_center, 1.0, 1.0), "Zone 4 should occupy the south-east quadrant")
	_assert_true(_stub_at_courtyard_end(layout_data, 1), "Zone 1 stub should anchor to the bar's right edge (courtyard side)")
	_assert_true(_stub_at_courtyard_end(layout_data, 2), "Zone 2 stub should anchor to the bar's left edge (courtyard side)")
	_assert_true(_stub_at_courtyard_end(layout_data, 3), "Zone 3 stub should anchor to the bar's right edge (courtyard side)")
	_assert_true(_stub_at_courtyard_end(layout_data, 4), "Zone 4 stub should anchor to the bar's left edge (courtyard side)")
	print("[MallMapSelectorTest] viewport=%s shell_rect=%s" % [str(get_viewport_rect().size), str(_channel_manager_ui.panel_container.get_global_rect())])
	_assert_true(_channel_manager_ui.panel_container.get_global_rect().end.y <= get_viewport_rect().size.y, "Selector shell should fit within the viewport height")

	# show_channel_selector defensively deals the store directory when empty.
	_assert_true(not _channel_manager.zone_store_names.is_empty(), "Selector should deal stores when zone_store_names is empty")
	var zone_one_store: String = _channel_manager.get_store_name(1, 1)
	_assert_true(zone_one_store != "Store 1-1", "Zone 1 round 1 should have a real store name, not the fallback")
	var directory_text := _collect_label_text(_channel_manager_ui._directory_grid)
	_assert_true(directory_text.contains(zone_one_store), "Store directory should list zone 1's first store")

	_channel_manager.set_channel(2)
	await get_tree().process_frame
	_assert_true(_channel_manager_ui.zone_name_label.text == "EAST WING", "Channel 2 should update selector label")

	# Zone keyboard navigation was removed: arrows must not move the selection.
	var arrow_event := InputEventAction.new()
	arrow_event.action = "ui_right"
	arrow_event.pressed = true
	_channel_manager_ui._unhandled_input(arrow_event)
	await get_tree().process_frame
	_assert_true(_channel_manager.current_channel == 2, "Arrow keys should no longer move the selection")

	var left_click := InputEventMouseButton.new()
	left_click.button_index = MOUSE_BUTTON_LEFT
	left_click.pressed = true
	_assert_true(not _channel_manager_ui._zones_by_channel[1].has_signal("zone_clicked"), "Zones should not expose a click tooltip signal")
	_assert_true(not _channel_manager_ui._map_tooltip.is_open(), "No zone tooltip should be open")

	# Store icon click parity: same content the popup's shared builder returns.
	var icon = _channel_manager_ui._store_icons[1][0]
	var popup_data: Dictionary = _mall_map_renderer_script.build_store_tooltip_text(_channel_manager, null, null, 1, 0)
	icon._on_input_event(get_viewport(), left_click, 0)
	await get_tree().create_timer(0.3).timeout
	_assert_true(_channel_manager_ui._map_tooltip.is_open(), "Plaque Area2D input should show the store tooltip")
	_assert_true(_channel_manager_ui._tooltip_panel._last_data == popup_data, "Selector store tooltip should match the shared builder output")
	_assert_true(_channel_manager_ui._tooltip_panel.get_text().contains(zone_one_store), "Store tooltip should name the store")
	_channel_manager_ui._on_store_icon_clicked(icon, left_click)
	_assert_true(not _channel_manager_ui._map_tooltip.is_open(), "Clicking the same store should toggle its tooltip closed")

	# Hover remains visual-only; no rest delay or quick-pass tooltip exists.
	var quick_icon = _channel_manager_ui._store_icons[2][0]
	var neighbor_icon = _channel_manager_ui._store_icons[2][1]
	_channel_manager_ui._on_store_icon_hovered(quick_icon)
	_channel_manager_ui._on_store_icon_unhovered(quick_icon)
	await get_tree().create_timer(0.25).timeout
	_assert_true(not _channel_manager_ui._map_tooltip.is_open(), "Hovering a store never opens a tooltip")

	_channel_manager_ui._on_store_icon_clicked(quick_icon, left_click)
	_channel_manager_ui._on_store_icon_clicked(neighbor_icon, left_click)
	_assert_true(not _channel_manager_ui._map_tooltip.is_open(), "Other store click should close first, not neighbor-swap")
	_channel_manager_ui._on_store_icon_clicked(neighbor_icon, left_click)
	var neighbor_store: String = _channel_manager.get_store_name(2, 2)
	_assert_true(_channel_manager_ui._tooltip_panel.get_text().contains(neighbor_store), "Second click should open the other store")
	_channel_manager_ui._input(left_click)
	_assert_true(not _channel_manager_ui._map_tooltip.is_open(), "Any screen click should dismiss the store tooltip")

	# The separate dice-set tooltip stays hover-driven and outside click state.
	_channel_manager_ui._show_dice_set_tooltip()
	_assert_true(not _channel_manager_ui._map_tooltip.is_open(), "Dice-set hover tooltip is not a map click tooltip")
	_assert_true(_channel_manager_ui._tooltip_panel.get_text().contains("sides"), "Dice-set hover tooltip still shows its content")
	_channel_manager_ui._on_dice_display_unhover()

	# Directory must fit inside the shell (bottom border visible, no scroll).
	var shell_rect: Rect2 = _channel_manager_ui.panel_container.get_global_rect()
	var grid_rect: Rect2 = _channel_manager_ui._directory_grid.get_global_rect()
	_assert_true(grid_rect.end.y <= shell_rect.end.y, "Store directory should fit inside the shell (grid bottom %.1f > shell bottom %.1f)" % [grid_rect.end.y, shell_rect.end.y])

	_channel_manager_ui._on_store_icon_clicked(icon, left_click)
	_channel_manager_ui.hide_channel_selector()
	_assert_true(not _channel_manager_ui._map_tooltip.is_open(), "Hiding the selector force-hides an open map tooltip")
	await get_tree().create_timer(1.0).timeout
	_assert_true(not _channel_manager_ui.visible, "Selector exit animation completes after tooltip cleanup")

	_finish()


## _collect_label_text(root: Node) -> String
##
## Concatenates every Label text under root so directory content assertions
## don't depend on the exact container nesting.
func _collect_label_text(root: Node) -> String:
	var texts: Array[String] = []
	if root is Label:
		texts.append(root.text)
	for child in root.get_children():
		texts.append(_collect_label_text(child))
	return "\n".join(texts)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("[MallMapSelectorTest] PASS: %s" % message)
		return
	_failed = true
	push_error("[MallMapSelectorTest] FAIL: %s" % message)


func _finish() -> void:
	if _failed:
		push_error("[MallMapSelectorTest] FAILED")
		get_tree().quit(1)
		return
	print("[MallMapSelectorTest] PASSED")
	get_tree().quit(0)


func _zone_bounds(layout_data: Dictionary, channel_num: int) -> Rect2:
	for zone in layout_data.get("zones", []):
		if zone.get("channel", -1) == channel_num:
			return _points_bounds(zone.get("points", PackedVector2Array()))
	return Rect2(Vector2.ZERO, Vector2.ZERO)


func _zones_overlap(zones: Array) -> bool:
	for first_index in range(zones.size()):
		for second_index in range(first_index + 1, zones.size()):
			var first_rect := _points_bounds(zones[first_index].get("points", PackedVector2Array()))
			var second_rect := _points_bounds(zones[second_index].get("points", PackedVector2Array()))
			if first_rect.intersects(second_rect):
				print("[MallMapSelectorTest] OVERLAP: %s with %s" % [str(zones[first_index].get("channel", -1)), str(zones[second_index].get("channel", -1))])
				return true
	return false


func _zones_inside_frame(zones: Array, frame: Rect2) -> bool:
	for zone in zones:
		var zone_rect := _points_bounds(zone.get("points", PackedVector2Array()))
		if not frame.encloses(zone_rect):
			print("[MallMapSelectorTest] OUT OF FRAME: %s" % str(zone.get("channel", -1)))
			return false
	return true


func _zone_labels_inside_polygons(zones: Array) -> bool:
	for zone in zones:
		var points: PackedVector2Array = zone.get("points", PackedVector2Array())
		var label_pos: Vector2 = zone.get("label_pos", Vector2.ZERO)
		if not Geometry2D.is_point_in_polygon(label_pos, points):
			print("[MallMapSelectorTest] LABEL OUTSIDE: %s" % str(zone.get("channel", -1)))
			return false
	return true


func _zone_in_quadrant(layout_data: Dictionary, channel_num: int, center: Vector2, side_x: float, side_y: float) -> bool:
	var rect := _zone_bounds(layout_data, channel_num)
	var zone_center := rect.position + rect.size * 0.5
	if side_x < 0.0 and zone_center.x >= center.x:
		return false
	if side_x > 0.0 and zone_center.x <= center.x:
		return false
	if side_y < 0.0 and zone_center.y >= center.y:
		return false
	if side_y > 0.0 and zone_center.y <= center.y:
		return false
	return true


## _stub_at_courtyard_end(layout_data, channel_num) -> bool
##
## Verifies the zone's L shape: the stub tip corners must sit at the bar end
## nearest the courtyard (right edge for west channels 1/3, left edge for
## east channels 2/4). The stub tip is the polygon edge farthest from the
## bar (max y for north wings, min y for south wings).
func _stub_at_courtyard_end(layout_data: Dictionary, channel_num: int) -> bool:
	for zone in layout_data.get("zones", []):
		if zone.get("channel", -1) != channel_num:
			continue
		var points: PackedVector2Array = zone.get("points", PackedVector2Array())
		if points.size() < 8:
			return false
		var rect := _points_bounds(points)
		var tip_y := rect.position.y
		if channel_num == 1 or channel_num == 2:
			tip_y = rect.end.y
		var tip_xs: Array[float] = []
		for point in points:
			if absf(point.y - tip_y) < 0.01:
				tip_xs.append(point.x)
		if tip_xs.size() != 2:
			return false
		if channel_num == 1 or channel_num == 3:
			return absf(tip_xs.max() - rect.end.x) < 0.01
		return absf(tip_xs.min() - rect.position.x) < 0.01
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
