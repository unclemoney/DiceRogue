extends RefCounted
class_name TooltipPlacement

const VIEWPORT_MARGIN := 8.0
const CURSOR_EXCLUSION_SIZE := Vector2(8.0, 8.0)


static func resolve(tooltip: Control, desired_position: Vector2, anchor_rect: Rect2 = Rect2(), cursor_position: Vector2 = Vector2.INF) -> Vector2:
	var viewport_rect := tooltip.get_viewport().get_visible_rect()
	var tooltip_size := tooltip.size
	if tooltip_size == Vector2.ZERO:
		tooltip_size = tooltip.get_combined_minimum_size()
	var minimum := viewport_rect.position + Vector2.ONE * VIEWPORT_MARGIN
	var maximum := viewport_rect.end - tooltip_size - Vector2.ONE * VIEWPORT_MARGIN
	maximum.x = maxf(minimum.x, maximum.x)
	maximum.y = maxf(minimum.y, maximum.y)
	var clamped := Vector2(
		clampf(desired_position.x, minimum.x, maximum.x),
		clampf(desired_position.y, minimum.y, maximum.y)
	)
	if not _overlaps_exclusion(clamped, tooltip_size, anchor_rect, cursor_position):
		return clamped

	if anchor_rect.has_area():
		var below := Vector2(clamped.x, anchor_rect.end.y + VIEWPORT_MARGIN)
		below.y = clampf(below.y, minimum.y, maximum.y)
		if not _overlaps_exclusion(below, tooltip_size, anchor_rect, cursor_position):
			return below
		var above := Vector2(clamped.x, anchor_rect.position.y - tooltip_size.y - VIEWPORT_MARGIN)
		above.y = clampf(above.y, minimum.y, maximum.y)
		if not _overlaps_exclusion(above, tooltip_size, anchor_rect, cursor_position):
			return above
	elif cursor_position != Vector2.INF:
		var below_cursor := Vector2(clamped.x, cursor_position.y + CURSOR_EXCLUSION_SIZE.y)
		below_cursor.y = clampf(below_cursor.y, minimum.y, maximum.y)
		if not _overlaps_exclusion(below_cursor, tooltip_size, anchor_rect, cursor_position):
			return below_cursor

	return clamped


static func _overlaps_exclusion(position: Vector2, tooltip_size: Vector2, anchor_rect: Rect2, cursor_position: Vector2) -> bool:
	var tooltip_rect := Rect2(position, tooltip_size)
	if anchor_rect.has_area() and tooltip_rect.intersects(anchor_rect):
		return true
	if cursor_position != Vector2.INF:
		var cursor_rect := Rect2(cursor_position - CURSOR_EXCLUSION_SIZE * 0.5, CURSOR_EXCLUSION_SIZE)
		if tooltip_rect.intersects(cursor_rect):
			return true
	return false
