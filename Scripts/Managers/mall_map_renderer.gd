extends RefCounted
class_name MallMapRenderer

## MallMapRenderer
##
## Shared runtime builders for the mall directory map, extracted from
## ChannelManagerUI so both the game-start selector and the in-game
## MallMapPopup render the identical board from MallMapLayout geometry.
## The board is a lightbox: light procedural background, dark grey tiled
## corridor floor, and one pictogram plaque per store (6 per zone, 24 total).

const VCR_FONT: Font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
const MallMapLayoutScript = preload("res://Scripts/Managers/mall_map_layout.gd")
const MallMapZoneScript = preload("res://Scripts/Managers/mall_map_zone.gd")
const MallStoreIconScript = preload("res://Scripts/Managers/mall_store_icon.gd")
const FLOOR_SHADER: Shader = preload("res://Scripts/Shaders/mall_floor_tiles.gdshader")
const LIGHTBOX_SHADER: Shader = preload("res://Scripts/Shaders/mall_lightbox.gdshader")

const SECTION_COLORS := {
	"eatery": Color(0.96, 0.76, 0.18, 1.0),
	"entertainment": Color(0.86, 0.25, 0.46, 1.0),
	"lifestyle": Color(0.29, 0.78, 0.95, 1.0),
	"specialty": Color(0.30, 0.82, 0.45, 1.0),
	"major_stores": Color(0.97, 0.46, 0.16, 1.0),
}

## Mall-core palette for GlassActionButton on the mall screens: dark warm
## brown glass body, mall-gold accent, warm cream glow/rim/specular.
const MALL_GLASS_PALETTE := {
	"accent_color": Color(0.85, 0.62, 0.20, 1.0),
	"glow_color": Color(0.98, 0.90, 0.66, 1.0),
	"base_color": Color(0.16, 0.11, 0.08, 0.98),
	"mid_color": Color(0.26, 0.18, 0.12, 0.98),
	"rim_color": Color(0.98, 0.95, 0.86, 1.0),
	"specular_color": Color(0.99, 0.97, 0.90, 1.0),
	"font_color": Color(0.97, 0.93, 0.82, 1.0),
	"font_outline_color": Color(0.10, 0.07, 0.05, 1.0),
	"outline_size": 1,
}

## Directory typography: dark slate on the light lightbox shell.
const DIRECTORY_TEXT_COLOR := Color(0.18, 0.20, 0.26)
const DIRECTORY_FONT_SIZES: Array[int] = [14, 13, 12, 11]
const DIRECTORY_ROW_PADDING := 12.0

const ICON_ROW_BOTTOM_MARGIN := 18.0
const ICON_PLATE_MARGIN := 4.0
const ICON_TRIM_WIDTH := 2.0


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
## Builds the lightbox paper base (procedural sheen/vignette shader) and the
## mall frame into the given map root.
static func build_directory_backdrop(map_root: Node2D) -> void:
	var paper := Polygon2D.new()
	paper.name = "LightboxPaper"
	paper.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(MallMapLayoutScript.get_board_size().x, 0),
		MallMapLayoutScript.get_board_size(),
		Vector2(0, MallMapLayoutScript.get_board_size().y),
	])
	paper.color = Color.WHITE
	var paper_material := ShaderMaterial.new()
	paper_material.shader = LIGHTBOX_SHADER
	paper_material.set_shader_parameter("view_size", MallMapLayoutScript.get_map_view_size())
	paper.material = paper_material
	map_root.add_child(paper)

	var mall_frame_rect: Rect2 = MallMapLayoutScript.get_map_frame()
	var frame := Line2D.new()
	frame.width = 6.0
	frame.default_color = Color(0.52, 0.55, 0.61, 1.0)
	frame.points = PackedVector2Array([
		mall_frame_rect.position,
		Vector2(mall_frame_rect.end.x, mall_frame_rect.position.y),
		mall_frame_rect.end,
		Vector2(mall_frame_rect.position.x, mall_frame_rect.end.y),
		mall_frame_rect.position,
	])
	map_root.add_child(frame)


## build_corridors(map_root, initial_alpha) -> Array[Polygon2D]
##
## Builds the corridor floor into the map root and returns the floor polygons
## (4 arms + the courtyard diamond). Each is a Polygon2D carrying the tiled
## floor shader; the diamond keeps its outline as a child. Polygons start at
## initial_alpha (0.0 matches the selector's staged entrance reveal).
static func build_corridors(map_root: Node2D, initial_alpha: float = 0.0) -> Array[Polygon2D]:
	var floors: Array[Polygon2D] = []
	var width: float = MallMapLayoutScript.get_corridor_width()
	for path in MallMapLayoutScript.get_corridor_paths():
		if path.size() < 2:
			continue
		var corridor := _floor_polygon(_segment_rect_points(path[0], path[path.size() - 1], width))
		corridor.modulate.a = initial_alpha
		map_root.add_child(corridor)
		floors.append(corridor)

	var intersection_data := MallMapLayoutScript.get_intersection_shape()
	if not intersection_data.is_empty():
		var diamond := _floor_polygon(intersection_data.get("points", PackedVector2Array()))
		diamond.modulate.a = initial_alpha
		var outline := Line2D.new()
		outline.width = 3.0
		outline.default_color = Color(0.42, 0.45, 0.52, 1.0)
		outline.points = close_points(intersection_data.get("points", PackedVector2Array()))
		diamond.add_child(outline)
		map_root.add_child(diamond)
		floors.append(diamond)
	return floors


## _floor_polygon(points) -> Polygon2D
##
## One tiled-floor polygon: white base color, the shader owns the look.
static func _floor_polygon(points: PackedVector2Array) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = Color.WHITE
	var material := ShaderMaterial.new()
	material.shader = FLOOR_SHADER
	poly.material = material
	return poly


## _segment_rect_points(a, b, width) -> PackedVector2Array
##
## Rectangle polygon covering a corridor segment with the given stroke width.
static func _segment_rect_points(a: Vector2, b: Vector2, width: float) -> PackedVector2Array:
	var direction := (b - a).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var normal := Vector2(-direction.y, direction.x) * (width * 0.5)
	return PackedVector2Array([a + normal, b + normal, b - normal, a - normal])


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


## build_store_icons(map_root, channel_manager, on_hovered, on_unhovered) -> Dictionary
##
## Builds the 24 wayfinding icons — six pictogram plaques per zone, evenly
## spaced along the zone's bar rect — and returns channel -> Array of
## MallStoreIcon. Shared by the selector and the in-game popup so both
## screens carry the identical icons. Hover callbacks are optional.
static func build_store_icons(map_root: Node2D, channel_manager, on_hovered: Callable = Callable(), on_unhovered: Callable = Callable()) -> Dictionary:
	var icons: Dictionary = {}
	if channel_manager == null:
		return icons
	for layout in MallMapLayoutScript.get_zone_layouts():
		var channel: int = int(layout.get("channel", 1))
		var bar_rect: Rect2 = layout.get("bar_rect", Rect2())
		if bar_rect.size.x <= 0.0:
			continue
		var accent := get_section_color(channel_manager.get_selector_section_id(channel))
		var zone_icons: Array[MallStoreIcon] = []
		var count: int = channel_manager.STORES_PER_ZONE
		var inner := bar_rect.grow(-12.0)
		var polygon_points: PackedVector2Array = layout.get("points", PackedVector2Array())
		for store_index in range(count):
			var fraction := (float(store_index) + 0.5) / float(count)
			var icon_pos := Vector2(
				inner.position.x + inner.size.x * fraction,
				bar_rect.end.y - ICON_ROW_BOTTOM_MARGIN
			)
			icon_pos = _clamp_icon_inside_zone(icon_pos, bar_rect, polygon_points)
			var icon = MallStoreIconScript.new()
			icon.name = "StoreIcon_z%d_s%d" % [channel, store_index]
			icon.position = icon_pos
			icon.configure(channel, store_index, channel_manager.get_store_name(channel, store_index + 1), accent)
			if on_hovered.is_valid():
				icon.icon_hovered.connect(on_hovered)
			if on_unhovered.is_valid():
				icon.icon_unhovered.connect(on_unhovered)
			map_root.add_child(icon)
			zone_icons.append(icon)
		icons[channel] = zone_icons
	return icons


## _clamp_icon_inside_zone(icon_pos, bar_rect, polygon_points) -> Vector2
##
## Clamps an icon's center so the full plate (plus trim and a small margin)
## stays inside the zone. The zone's bar is a rectangle fully inside the L
## polygon, so the analytic clamp against the shrunken bar does the bulk of
## the work; a corner test against the real polygon then pulls the plate up
## (and toward the bar center) if a corner still hangs over an edge — zone
## 03/04's bars sit low enough that the untrimmed row grazed the corridor.
static func _clamp_icon_inside_zone(icon_pos: Vector2, bar_rect: Rect2, polygon_points: PackedVector2Array) -> Vector2:
	var half := Vector2(MallStoreIconScript.PLAQUE_SIZE.x * 0.5, MallStoreIconScript.PLAQUE_SIZE.y * 0.5)
	half += Vector2(ICON_TRIM_WIDTH + ICON_PLATE_MARGIN, ICON_TRIM_WIDTH + ICON_PLATE_MARGIN)
	var clamped := Vector2(
		clampf(icon_pos.x, bar_rect.position.x + half.x, bar_rect.end.x - half.x),
		clampf(icon_pos.y, bar_rect.position.y + half.y, bar_rect.end.y - half.y)
	)
	if polygon_points.is_empty():
		return clamped
	var bar_center := bar_rect.position + bar_rect.size * 0.5
	for _step in range(24):
		if _plate_corners_inside(clamped, half, polygon_points):
			break
		var pulled := Vector2(clamped.x, clamped.y - 1.5)
		if not _plate_corners_inside(pulled, half, polygon_points):
			pulled.x = lerpf(clamped.x, bar_center.x, 0.15)
		clamped = pulled
	return clamped


static func _plate_corners_inside(center: Vector2, half: Vector2, polygon_points: PackedVector2Array) -> bool:
	for corner in [
		center + Vector2(-half.x, -half.y),
		center + Vector2(half.x, -half.y),
		center + Vector2(half.x, half.y),
		center + Vector2(-half.x, half.y),
	]:
		if not Geometry2D.is_point_in_polygon(corner, polygon_points):
			return false
	return true


## get_store_state(channel_manager, round_manager, channel, store_index) -> String
##
## Resolves a store's run state: completed/failed from round data, current
## from the live round index, upcoming otherwise. Other zones stay neutral.
static func get_store_state(channel_manager, round_manager, channel: int, store_index: int) -> String:
	if channel_manager == null or channel != channel_manager.current_channel:
		return "upcoming"
	if round_manager == null:
		return "upcoming"
	if store_index == round_manager.current_round:
		return "current"
	if store_index < round_manager.rounds_data.size():
		var round_data: Dictionary = round_manager.rounds_data[store_index]
		if round_data.get("completed", false):
			return "completed"
		if round_data.get("failed", false):
			return "failed"
	return "upcoming"


## build_store_tooltip_text(channel_manager, round_manager, debuff_manager, channel, store_index) -> Dictionary
##
## Tooltip content for one store, shared by both mall screens, shaped for
## MallStoreTooltip.show_for: {title, sections:[{text, style, label}]}.
## The current zone uses live rounds_data (scaled target, exact pre-selected
## debuffs, status); other zones — and the selector, which has no run state —
## show the round config target and debuffs as unknown until reached.
## Status colors are semantic (done/skipped/upcoming), NOT rarity tiers, so
## they stay inline bbcode rather than going through Tooltip.RarityColors.
static func build_store_tooltip_text(channel_manager, round_manager, debuff_manager, channel: int, store_index: int) -> Dictionary:
	var store_number := store_index + 1
	var store_name := "Store %d-%d" % [channel, store_number]
	if channel_manager:
		store_name = channel_manager.get_store_name(channel, store_number)
	var tip := {"title": store_name, "sections": []}

	var is_current_zone: bool = channel_manager != null and channel == channel_manager.current_channel
	if is_current_zone and round_manager and store_index < round_manager.rounds_data.size():
		var round_data: Dictionary = round_manager.rounds_data[store_index]
		# Target mirrors GameController._compute_round_target minus the
		# transient challenge_score_modifier (powerup effect, not shown here).
		var target := _compute_store_target(channel_manager, channel, store_number)
		if target > 0:
			tip["sections"].append({"text": NumberFormatter.format_int(target), "style": "stat", "label": "Target"})
		var debuff_ids: Array = round_data.get("debuff_ids", [])
		for debuff_id in debuff_ids:
			tip["sections"].append({"text": _get_debuff_display_name(debuff_manager, str(debuff_id)), "style": "stat", "label": "Debuff"})
		tip["sections"].append({"text": _colorize_store_status(_get_store_status_text(channel_manager, round_manager, store_index)), "style": "stat", "label": "Status"})
	else:
		if channel_manager:
			var round_config = channel_manager.get_round_config(channel, store_number)
			if round_config and round_config.target_score_override > 0:
				tip["sections"].append({"text": NumberFormatter.format_int(channel_manager.get_scaled_target_score(round_config.target_score_override, channel)), "style": "stat", "label": "Target"})
			if round_config and round_config.get("is_boss_round") == true:
				tip["sections"].append({"text": "Boss Store", "style": "plain"})
		tip["sections"].append({"text": "Debuffs: unknown until reached", "style": "plain"})
		tip["sections"].append({"text": "[color=gray]Upcoming[/color]", "style": "stat", "label": "Status"})

	return tip


## _colorize_store_status(status) -> String
##
## Semantic status colors: completed green, failed red, anything else gray.
static func _colorize_store_status(status: String) -> String:
	match status.to_lower():
		"completed":
			return "[color=#8eff8e]Completed[/color]"
		"failed":
			return "[color=#ff5940]Failed[/color]"
		_:
			return "[color=gray]%s[/color]" % status.capitalize()


## _compute_store_target(channel_manager, channel, store_number) -> int
##
## Scaled target for a store: override x channel multiplier (rebel premium
## included via ChannelManager.get_scaled_target_score).
static func _compute_store_target(channel_manager, channel: int, store_number: int) -> int:
	if channel_manager == null:
		return 0
	var round_config = channel_manager.get_round_config(channel, store_number)
	if round_config == null:
		return 0
	var base: int = round_config.target_score_override
	if base <= 0:
		return 0
	return channel_manager.get_scaled_target_score(base, channel)


static func _get_debuff_display_name(debuff_manager, debuff_id: String) -> String:
	if debuff_manager and debuff_manager.has_method("get_def"):
		var def = debuff_manager.get_def(debuff_id)
		if def and not def.display_name.is_empty():
			return def.display_name
	return debuff_id


static func _get_store_status_text(channel_manager, round_manager, store_index: int) -> String:
	if round_manager == null or channel_manager == null:
		return "Upcoming"
	var state := get_store_state(channel_manager, round_manager, channel_manager.current_channel, store_index)
	match state:
		"completed":
			return "Completed"
		"current":
			return "YOU ARE HERE"
		"failed":
			return "Failed"
	return "Upcoming"


## build_store_directory(grid, channel_manager, zone_order, available_width) -> void
##
## Fills an HBoxContainer with the mall store directory: one fixed column per
## zone. Header is a colored bullet + zone number printed ONCE; each store is
## one bulleted line with autowrap OFF so nothing wraps or spills into a
## neighbor column. The font size is stepped down through
## DIRECTORY_FONT_SIZES until the longest "• name" row fits one column on a
## single line. Column width comes from available_width — the caller's
## runtime-measured width of the directory's enclosing layout at build time
## (the grid's own size cannot be used: label min-widths feed back into it
## and inflate the measurement). Shared by the selector and the popup.
static func build_store_directory(grid: HBoxContainer, channel_manager, zone_order: Array, available_width: float = 0.0) -> void:
	if grid == null or channel_manager == null:
		return
	for child in grid.get_children():
		child.queue_free()
	grid.set_meta("channel_manager", channel_manager)
	grid.set_meta("available_width", available_width)

	for channel in zone_order:
		var section_color := get_section_color(channel_manager.get_selector_section_id(channel))
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 0)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(column)

		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 6)
		column.add_child(header)

		var header_bullet := Label.new()
		header_bullet.text = "●"
		header_bullet.add_theme_font_override("font", VCR_FONT)
		header_bullet.add_theme_font_size_override("font_size", 14)
		header_bullet.add_theme_color_override("font_color", section_color)
		header.add_child(header_bullet)

		var number_label := Label.new()
		number_label.text = channel_manager.get_channel_display_text(channel)
		number_label.add_theme_font_override("font", VCR_FONT)
		number_label.add_theme_font_size_override("font_size", 16)
		number_label.add_theme_color_override("font_color", section_color.darkened(0.45))
		header.add_child(number_label)

		var store_line_index := 0
		for round_number in range(1, channel_manager.STORES_PER_ZONE + 1):
			var store_line_label := Label.new()
			store_line_label.text = "• " + channel_manager.get_store_name(channel, round_number)
			store_line_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			store_line_label.clip_text = false
			store_line_label.add_theme_font_override("font", VCR_FONT)
			store_line_label.add_theme_font_size_override("font_size", DIRECTORY_FONT_SIZES[0])

			var channel_color: Color = section_color.darkened(0.45)
			var alternate_tint: float = 0.10 if store_line_index % 2 == 0 else -0.10
			var varied_color: Color = Color(
				clampf(channel_color.r + alternate_tint, 0.0, 1.0),
				clampf(channel_color.g + alternate_tint, 0.0, 1.0),
				clampf(channel_color.b + alternate_tint, 0.0, 1.0),
				channel_color.a
			)
			store_line_label.add_theme_color_override("font_color", varied_color)
			column.add_child(store_line_label)
			store_line_index += 1

	if not grid.resized.is_connected(_on_directory_grid_resized.bind(grid)):
		grid.resized.connect(_on_directory_grid_resized.bind(grid), CONNECT_REFERENCE_COUNTED)
	refit_directory_grid.call_deferred(grid)


static func _on_directory_grid_resized(grid: HBoxContainer) -> void:
	refit_directory_grid(grid)


## set_directory_available_width(grid, available_width) -> void
##
## Updates the width budget used by refit_directory_grid and re-fits. Called
## by the owning screen whenever its shell is (re)sized.
static func set_directory_available_width(grid: HBoxContainer, available_width: float) -> void:
	if grid == null or not is_instance_valid(grid):
		return
	grid.set_meta("available_width", available_width)
	refit_directory_grid(grid)


## refit_directory_grid(grid) -> void
##
## Steps the store-line font down through DIRECTORY_FONT_SIZES until the
## longest "• name" row fits one column on a single line, then pins column
## minimum widths so no column can be squeezed below one-line width. Width
## budget: the meta available_width set at build/resize time; falls back to
## the grid's current laid-out width when unset.
static func refit_directory_grid(grid: HBoxContainer) -> void:
	if grid == null or not is_instance_valid(grid):
		return
	var channel_manager = grid.get_meta("channel_manager", null)
	if channel_manager == null:
		return
	var available: float = grid.get_meta("available_width", 0.0)
	if available <= 1.0:
		available = grid.size.x
	if available <= 1.0:
		return

	var separation := 6
	if grid.has_theme_constant_override("separation"):
		separation = grid.get_theme_constant("separation")
	var columns := grid.get_children()
	if columns.is_empty():
		return
	var column_width := (available - float(separation * (columns.size() - 1))) / float(columns.size())

	var longest_name := ""
	for channel in channel_manager.zone_store_names:
		for store_name in channel_manager.zone_store_names[channel]:
			if String(store_name).length() > longest_name.length():
				longest_name = store_name
	if longest_name.is_empty():
		for round_number in range(1, channel_manager.STORES_PER_ZONE + 1):
			var fallback_name: String = channel_manager.get_store_name(1, round_number)
			if fallback_name.length() > longest_name.length():
				longest_name = fallback_name

	var picked_size: int = DIRECTORY_FONT_SIZES.back()
	var picked_width := 0.0
	for font_size in DIRECTORY_FONT_SIZES:
		var row_width := VCR_FONT.get_string_size("• " + longest_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		picked_size = font_size
		picked_width = row_width
		if row_width + DIRECTORY_ROW_PADDING <= column_width:
			break

	for column in columns:
		column.custom_minimum_size.x = minf(picked_width + DIRECTORY_ROW_PADDING, column_width)
		for child in column.get_children():
			if child is Label:
				child.add_theme_font_size_override("font_size", picked_size)
