extends Control
class_name ModSelectionOutline

const OUTLINE_COLOR := Color(1.0, 0.2, 0.85, 0.5)
const LINE_WIDTH := 1.5
const DASH_LENGTH := 6.0
const GAP_LENGTH := 4.0
const MARCH_SPEED := 18.0

var outline_points := PackedVector2Array()
var _phase := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_outline_points(points: PackedVector2Array) -> void:
	outline_points = points
	queue_redraw()


func _process(delta: float) -> void:
	_phase = fposmod(_phase + delta * MARCH_SPEED, DASH_LENGTH + GAP_LENGTH)
	queue_redraw()


func _draw() -> void:
	var travelled := 0.0
	for i in range(outline_points.size() - 1):
		var start := outline_points[i]
		var end := outline_points[i + 1]
		var segment := end - start
		var length := segment.length()
		if length <= 0.001:
			continue
		_draw_dashed_segment(start, segment / length, length, fposmod(travelled - _phase, DASH_LENGTH + GAP_LENGTH))
		travelled += length


func _draw_dashed_segment(start: Vector2, direction: Vector2, length: float, phase: float) -> void:
	var cursor := 0.0
	var period := DASH_LENGTH + GAP_LENGTH
	while cursor < length:
		var pattern_position := fposmod(phase + cursor, period)
		if pattern_position >= DASH_LENGTH:
			cursor += period - pattern_position
			continue
		var dash_end := minf(cursor + DASH_LENGTH - pattern_position, length)
		draw_line(start + direction * cursor, start + direction * dash_end, OUTLINE_COLOR, LINE_WIDTH, true)
		cursor = dash_end
