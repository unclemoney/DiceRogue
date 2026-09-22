extends Area2D
class_name MallStoreIcon

## MallStoreIcon
##
## One interactive wayfinding icon on the mall map: a plaque plate with a
## zone-colored trim ring and the store's pictogram from the MallStoreIcons
## atlas. Visual juice only — hover pops scale + trim glow, press gives a
## squash. No fast travel, no selection state, no gameplay logic.
## The in-game popup additionally tints the plaque by store state
## (completed/current/failed) and pulses the current store.

signal icon_hovered(icon: MallStoreIcon)
signal icon_unhovered(icon: MallStoreIcon)

const MallStoreIconsScript = preload("res://Scripts/Managers/mall_store_icons.gd")

const PLAQUE_SIZE := Vector2(32, 24)
const COLOR_FACE := Color(0.97, 0.96, 0.92, 1.0)
const COLOR_COMPLETED := Color(0.35, 0.92, 0.48, 1.0)
const COLOR_CURRENT := Color(1.0, 0.92, 0.40, 1.0)
const COLOR_FAILED := Color(0.62, 0.34, 0.36, 1.0)

var channel: int = 1
var store_index: int = 0
var store_name: String = ""
var state: String = "upcoming"

var _shadow: Polygon2D
var _plaque: Polygon2D
var _trim: Line2D
var _sprite: Sprite2D
var _accent: Color = Color.WHITE
var _hover_tween: Tween
var _pulse_tween: Tween


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


## configure(p_channel, p_store_index, p_store_name, accent) -> void
##
## Applies identity, pictogram, and zone trim color.
func configure(p_channel: int, p_store_index: int, p_store_name: String, accent: Color) -> void:
	_ensure_structure()
	channel = p_channel
	store_index = p_store_index
	store_name = p_store_name
	_accent = accent
	set_meta("channel", channel)
	set_meta("store_index", store_index)
	_sprite.texture = MallStoreIconsScript.get_icon(store_name)
	_trim.default_color = accent.darkened(0.25)


## set_state(p_state) -> void
##
## Tints the plaque by store state ("completed"/"current"/"failed"/"upcoming")
## and starts the pulse on the current store. Selector icons stay "upcoming".
func set_state(p_state: String) -> void:
	state = p_state
	set_meta("state", state)
	set_meta("is_current", state == "current")
	match state:
		"completed":
			_plaque.color = COLOR_FACE.lerp(COLOR_COMPLETED, 0.35)
			_trim.default_color = COLOR_COMPLETED
		"current":
			_plaque.color = COLOR_FACE.lerp(COLOR_CURRENT, 0.35)
			_trim.default_color = COLOR_CURRENT
		"failed":
			_plaque.color = COLOR_FACE.lerp(COLOR_FAILED, 0.45)
			_trim.default_color = COLOR_FAILED
		_:
			_plaque.color = COLOR_FACE
			_trim.default_color = _accent.darkened(0.25)
	if state == "current":
		_start_pulse()
	elif _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_plaque.scale = Vector2.ONE


func play_reveal(delay: float) -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(self, "modulate:a", 1.0, 0.15)


func _ensure_structure() -> void:
	var plaque_points := _plaque_points()
	if _shadow == null:
		_shadow = Polygon2D.new()
		_shadow.name = "Shadow"
		_shadow.color = Color(0.10, 0.10, 0.12, 0.25)
		_shadow.position = Vector2(2, 3)
		add_child(_shadow)
		_shadow.polygon = plaque_points
	if _plaque == null:
		_plaque = Polygon2D.new()
		_plaque.name = "Plaque"
		_plaque.color = COLOR_FACE
		add_child(_plaque)
		_plaque.polygon = plaque_points
	if _trim == null:
		_trim = Line2D.new()
		_trim.name = "Trim"
		_trim.width = 2.0
		_trim.joint_mode = Line2D.LINE_JOINT_ROUND
		_trim.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_trim.end_cap_mode = Line2D.LINE_CAP_ROUND
		add_child(_trim)
		var closed := PackedVector2Array(plaque_points)
		closed.append(plaque_points[0])
		_trim.points = closed
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Pictogram"
		_sprite.centered = true
		add_child(_sprite)
		var shape := CollisionShape2D.new()
		shape.name = "Collision"
		var rect := RectangleShape2D.new()
		rect.size = PLAQUE_SIZE + Vector2(6, 6)  # generous hover area
		shape.shape = rect
		add_child(shape)


## _plaque_points() -> PackedVector2Array
##
## Rounded-square plate: a rect with 4px corner cuts, centered on origin.
static func _plaque_points() -> PackedVector2Array:
	var half := PLAQUE_SIZE * 0.5
	var cut := 4.0
	return PackedVector2Array([
		Vector2(-half.x + cut, -half.y),
		Vector2(half.x - cut, -half.y),
		Vector2(half.x, -half.y + cut),
		Vector2(half.x, half.y - cut),
		Vector2(half.x - cut, half.y),
		Vector2(-half.x + cut, half.y),
		Vector2(-half.x, half.y - cut),
		Vector2(-half.x, -half.y + cut),
	])


func _start_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(_plaque, "scale", Vector2(1.12, 1.12), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.chain().tween_property(_plaque, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_mouse_entered() -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_parallel(true)
	_hover_tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(_trim, "width", 3.0, 0.12)
	var glow_color := _accent.lightened(0.35)
	if state == "current":
		glow_color = COLOR_CURRENT
	_hover_tween.tween_property(_trim, "default_color", glow_color, 0.12)
	emit_signal("icon_hovered", self)


func _on_mouse_exited() -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_parallel(true)
	_hover_tween.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(_trim, "width", 2.0, 0.14)
	var rest_color := _accent.darkened(0.25)
	match state:
		"completed":
			rest_color = COLOR_COMPLETED
		"current":
			rest_color = COLOR_CURRENT
		"failed":
			rest_color = COLOR_FAILED
	_hover_tween.tween_property(_trim, "default_color", rest_color, 0.14)
	emit_signal("icon_unhovered", self)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			get_viewport().set_input_as_handled()
			_play_press()


func _play_press() -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.chain().tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
