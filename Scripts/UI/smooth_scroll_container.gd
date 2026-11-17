extends ScrollContainer
class_name SmoothScrollContainer

const SCROLL_DURATION := 0.32
const DEFAULT_WHEEL_STEP := 96.0

var _target_scroll := 0.0
var _rendered_scroll := 0.0
var _scroll_tween: Tween = null
var _dragging := false
var _drag_last_y := 0.0
var _applying_scroll := false

@onready var _vertical_bar: VScrollBar = get_v_scroll_bar()


func _ready() -> void:
	_target_scroll = float(scroll_vertical)
	_rendered_scroll = _target_scroll
	_vertical_bar.value_changed.connect(_on_scrollbar_value_changed)
	visibility_changed.connect(_on_visibility_changed)


func _exit_tree() -> void:
	_kill_scroll_tween()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_dragging = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_target_scroll(_target_scroll - _wheel_step())
			accept_event()
		elif mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_target_scroll(_target_scroll + _wheel_step())
			accept_event()
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mouse_event.pressed
			_drag_last_y = mouse_event.global_position.y
			if _dragging:
				accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mouse_motion := event as InputEventMouseMotion
		_target_scroll += _drag_last_y - mouse_motion.global_position.y
		_drag_last_y = mouse_motion.global_position.y
		_set_target_scroll(_target_scroll)
		accept_event()


func _wheel_step() -> float:
	if _vertical_bar.page > 0.0:
		return maxf(DEFAULT_WHEEL_STEP, _vertical_bar.page * 0.25)
	return DEFAULT_WHEEL_STEP


func _max_scroll() -> float:
	return maxf(_vertical_bar.min_value, _vertical_bar.max_value - _vertical_bar.page)


func _set_target_scroll(target: float) -> void:
	_target_scroll = clampf(target, _vertical_bar.min_value, _max_scroll())
	_kill_scroll_tween()
	if is_equal_approx(_rendered_scroll, _target_scroll):
		_apply_scroll_position(_target_scroll)
		return
	_scroll_tween = create_tween()
	_scroll_tween.tween_method(_apply_scroll_position, _rendered_scroll, _target_scroll, SCROLL_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _apply_scroll_position(value: float) -> void:
	_rendered_scroll = value
	_applying_scroll = true
	scroll_vertical = int(roundf(value))
	_applying_scroll = false


func _on_scrollbar_value_changed(value: float) -> void:
	if _applying_scroll:
		return
	var restored_position := _rendered_scroll
	_apply_scroll_position(restored_position)
	_set_target_scroll(value)


func _on_visibility_changed() -> void:
	if visible:
		return
	_kill_scroll_tween()
	_target_scroll = clampf(_rendered_scroll, _vertical_bar.min_value, _max_scroll())
	_apply_scroll_position(_target_scroll)


func _kill_scroll_tween() -> void:
	if _scroll_tween and _scroll_tween.is_valid():
		_scroll_tween.kill()
	_scroll_tween = null
