extends RigidBody2D
class_name MenuDice

## Physics-based decorative dice for the main menu background.
## Falls with gravity, bounces on floor, reacts to clicks with impulse.

const MIN_BOUNCE_IMPULSE := 200.0
const MAX_BOUNCE_IMPULSE := 500.0
const MIN_TORQUE := -2000.0
const MAX_TORQUE := 2000.0

var _audio_manager: Node = null
var _shadow: ColorRect
var _floor_y: float = 720.0


func _ready() -> void:
	_audio_manager = get_node_or_null("/root/AudioManager")

	# Set up physics
	gravity_scale = 1.0
	mass = 0.5
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.6
	physics_material_override.friction = 0.4

	# Random initial spin
	angular_velocity = randf_range(-5.0, 5.0)

	# Set random face
	var d6_data = preload("res://Scripts/Dice/d6_dice.tres") as DiceData
	if d6_data and d6_data.textures.size() > 0:
		var face = randi() % d6_data.textures.size()
		$Sprite2D.texture = d6_data.textures[face]

	# Create shadow
	_shadow = ColorRect.new()
	_shadow.name = "Shadow"
	_shadow.color = Color(0, 0, 0, 0.25)
	_shadow.size = Vector2(48, 8)
	_shadow.pivot_offset = Vector2(24, 4)
	_shadow.top_level = true
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shadow)


## set_floor_y(y)
##
## Updates the floor Y position used for shadow calculation.
func set_floor_y(y: float) -> void:
	_floor_y = y


func _process(_delta: float) -> void:
	# Update shadow position and scale based on height
	if _shadow:
		var height = _floor_y - global_position.y
		var height_ratio = clampf(height / _floor_y, 0.0, 1.0)
		_shadow.global_position = Vector2(global_position.x - 24, _floor_y - 4)
		_shadow.scale = Vector2(1.0 + height_ratio * 0.5, 1.0)
		_shadow.modulate.a = 0.25 * (1.0 - height_ratio * 0.5)


func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_clicked()


func _on_clicked() -> void:
	var impulse = Vector2(
		randf_range(MIN_BOUNCE_IMPULSE, MAX_BOUNCE_IMPULSE) * (1.0 if randf() > 0.5 else -1.0),
		randf_range(-MAX_BOUNCE_IMPULSE, -MIN_BOUNCE_IMPULSE * 0.5)
	)
	apply_central_impulse(impulse)

	var torque = randf_range(MIN_TORQUE, MAX_TORQUE)
	apply_torque_impulse(torque)

	if _audio_manager:
		_audio_manager.play_dice_lock()
