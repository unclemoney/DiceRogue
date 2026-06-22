extends Area2D
class_name MallMapZone

## MallMapZone
##
## Runtime-generated interactive zone used by the mall selector map.
## Owns the polygon fill, outline, collision shape, and hover/select state.

signal zone_hovered(channel: int)
signal zone_unhovered(channel: int)
signal zone_pressed(channel: int)

const ZONE_SHADER := preload("res://Scripts/Shaders/mall_zone.gdshader")
const VCR_FONT := preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

var channel: int = 1
var zone_name: String = ""
var directory_label: String = ""
var section_id: String = "specialty"
var tooltip_flavor: String = ""
var label_text: String = ""

var _polygon: Polygon2D
var _outline: Line2D
var _collision: CollisionPolygon2D
var _label: Label
var _material: ShaderMaterial
var _hover_tween: Tween

var _accent_color: Color = Color(0.88, 0.36, 0.60, 1.0)
var _base_color: Color = Color(0.18, 0.16, 0.22, 0.98)
var _locked: bool = false
var _completed: bool = false
var _selected: bool = false
var _hovered: bool = false


func _ready() -> void:
	input_pickable = true
	monitoring = false
	_ensure_structure()
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	if not input_event.is_connected(_on_input_event):
		input_event.connect(_on_input_event)
	_refresh_visuals(false)


## configure(zone_data, accent_color)
##
## Applies runtime geometry and selector metadata to the zone.
func configure(zone_data: Dictionary, accent_color: Color) -> void:
	_ensure_structure()
	channel = zone_data.get("channel", 1)
	zone_name = zone_data.get("zone_name", "")
	directory_label = zone_data.get("directory_label", "")
	section_id = zone_data.get("section_id", "specialty")
	tooltip_flavor = zone_data.get("tooltip_flavor", "")
	label_text = zone_data.get("label_text", "")
	_accent_color = accent_color
	_base_color = _build_base_color(accent_color)
	_material.set_shader_parameter("base_color", _base_color)
	_material.set_shader_parameter("accent_color", _accent_color)

	var polygon_points: PackedVector2Array = zone_data.get("points", PackedVector2Array())
	_polygon.polygon = polygon_points
	_polygon.uv = _build_uvs(polygon_points)
	_collision.polygon = polygon_points
	_outline.points = _closed_points(polygon_points)
	_outline.default_color = accent_color.lightened(0.15)

	_layout_label(zone_data)
	_refresh_visuals(false)


func set_locked(value: bool, animate: bool = true) -> void:
	_locked = value
	_refresh_visuals(animate)


func set_hovered(value: bool, animate: bool = true) -> void:
	_hovered = value
	_refresh_visuals(animate)


func set_completed(value: bool, animate: bool = true) -> void:
	_completed = value
	_refresh_visuals(animate)


func set_selected(value: bool, animate: bool = true) -> void:
	_selected = value
	_refresh_visuals(animate)


func get_anchor_rect() -> Rect2:
	var points := _polygon.polygon
	if points.is_empty():
		return Rect2(global_position, Vector2.ZERO)

	var min_point := to_global(points[0])
	var max_point := min_point
	for point in points:
		var global_point := to_global(point)
		min_point.x = minf(min_point.x, global_point.x)
		min_point.y = minf(min_point.y, global_point.y)
		max_point.x = maxf(max_point.x, global_point.x)
		max_point.y = maxf(max_point.y, global_point.y)
	return Rect2(min_point, max_point - min_point)


func get_directory_text() -> String:
	if not directory_label.is_empty():
		return directory_label
	return zone_name


func contains_local_point(board_point: Vector2) -> bool:
	var local_point := to_local(board_point)
	return Geometry2D.is_point_in_polygon(local_point, _polygon.polygon)


func get_center_point() -> Vector2:
	var rect := _get_local_bounds()
	return rect.position + rect.size * 0.5


func play_reveal(delay: float) -> Tween:
	modulate.a = 0.0
	scale = Vector2(0.96, 0.96)
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(self, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween


func _ensure_structure() -> void:
	if _polygon == null:
		_polygon = Polygon2D.new()
		_polygon.name = "Fill"
		_polygon.color = Color.WHITE
		add_child(_polygon)
	if _outline == null:
		_outline = Line2D.new()
		_outline.name = "Outline"
		_outline.width = 4.0
		_outline.joint_mode = Line2D.LINE_JOINT_ROUND
		_outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_outline.end_cap_mode = Line2D.LINE_CAP_ROUND
		add_child(_outline)
	if _collision == null:
		_collision = CollisionPolygon2D.new()
		_collision.name = "Collision"
		add_child(_collision)
	if _label == null:
		_label = Label.new()
		_label.name = "Label"
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.add_theme_font_override("font", VCR_FONT)
		_label.add_theme_font_size_override("font_size", 16)
		_label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
		_label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.10))
		_label.add_theme_constant_override("outline_size", 2)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_label)
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = ZONE_SHADER
		_polygon.material = _material


func _layout_label(zone_data: Dictionary) -> void:
	var bounds := _get_local_bounds()
	var label_center: Vector2 = zone_data.get("label_pos", bounds.position + bounds.size * 0.5)
	var display_text := label_text
	if display_text.is_empty():
		display_text = get_directory_text().to_upper()
	var label_width := maxf(bounds.size.x - 10.0, 34.0)
	if display_text.length() <= 2:
		label_width = 38.0
	_label.text = display_text
	_label.position = label_center - Vector2(label_width * 0.5, 12.0)
	_label.size = Vector2(label_width, 24.0)


func _refresh_visuals(animate: bool) -> void:
	if _material == null:
		return

	var hover_strength := 0.0
	if _hovered:
		hover_strength = 1.0

	var selected_strength := 0.0
	if _selected:
		selected_strength = 1.0

	var completion_strength := 0.0
	if _completed:
		completion_strength = 1.0

	var locked_strength := 0.0
	if _locked:
		locked_strength = 1.0

	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()

	if animate:
		_hover_tween = create_tween()
		_hover_tween.tween_method(_set_hover_strength, _get_uniform_value("hover_strength"), hover_strength, 0.16)
		_hover_tween.parallel().tween_method(_set_selected_strength, _get_uniform_value("selected_strength"), selected_strength, 0.18)
		_hover_tween.parallel().tween_method(_set_completion_strength, _get_uniform_value("completion_strength"), completion_strength, 0.18)
		_hover_tween.parallel().tween_method(_set_locked_strength, _get_uniform_value("locked_strength"), locked_strength, 0.18)
		var target_scale := Vector2.ONE
		if _selected:
			target_scale = Vector2(1.03, 1.03)
		elif _hovered and not _locked:
			target_scale = Vector2(1.02, 1.02)
		_hover_tween.parallel().tween_property(self, "scale", target_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_set_hover_strength(hover_strength)
		_set_selected_strength(selected_strength)
		_set_completion_strength(completion_strength)
		_set_locked_strength(locked_strength)
		scale = Vector2.ONE
		if _selected:
			scale = Vector2(1.03, 1.03)
		elif _hovered and not _locked:
			scale = Vector2(1.02, 1.02)

	_outline.width = 4.0
	if _selected:
		_outline.width = 6.0
	elif _hovered:
		_outline.width = 5.0

	_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if _locked:
		_label.modulate = Color(0.72, 0.72, 0.76, 1.0)
	elif _completed:
		_label.modulate = Color(0.88, 1.0, 0.90, 1.0)


func _set_hover_strength(value: float) -> void:
	_material.set_shader_parameter("hover_strength", value)


func _set_selected_strength(value: float) -> void:
	_material.set_shader_parameter("selected_strength", value)


func _set_completion_strength(value: float) -> void:
	_material.set_shader_parameter("completion_strength", value)


func _set_locked_strength(value: float) -> void:
	_material.set_shader_parameter("locked_strength", value)


func _get_uniform_value(parameter_name: String) -> float:
	var value = _material.get_shader_parameter(parameter_name)
	if value is float:
		return value
	return 0.0


func _on_mouse_entered() -> void:
	set_hovered(true, true)
	emit_signal("zone_hovered", channel)


func _on_mouse_exited() -> void:
	set_hovered(false, true)
	emit_signal("zone_unhovered", channel)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			get_viewport().set_input_as_handled()
			emit_signal("zone_pressed", channel)


func _build_base_color(accent_color: Color) -> Color:
	var mixed := Color(0.15, 0.13, 0.19, 0.98)
	mixed.r = lerpf(mixed.r, accent_color.r, 0.22)
	mixed.g = lerpf(mixed.g, accent_color.g, 0.22)
	mixed.b = lerpf(mixed.b, accent_color.b, 0.22)
	return mixed


func _build_uvs(points: PackedVector2Array) -> PackedVector2Array:
	var bounds := _get_bounds_for_points(points)
	var uvs := PackedVector2Array()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		for _point in points:
			uvs.append(Vector2.ZERO)
		return uvs
	for point in points:
		var uv_x := (point.x - bounds.position.x) / bounds.size.x
		var uv_y := (point.y - bounds.position.y) / bounds.size.y
		uvs.append(Vector2(uv_x, uv_y))
	return uvs


func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(points)
	if not closed.is_empty():
		closed.append(closed[0])
	return closed


func _get_local_bounds() -> Rect2:
	return _get_bounds_for_points(_polygon.polygon)


func _get_bounds_for_points(points: PackedVector2Array) -> Rect2:
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