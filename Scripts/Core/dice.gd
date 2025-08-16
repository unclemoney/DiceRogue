class_name Dice
extends Area2D

signal rolled(value: int)
signal selected(dice: Dice)
signal clicked

static var dice_textures := {}
var home_position: Vector2 = Vector2.ZERO

@export var sides: int = 6
@export var is_locked: bool = false
@export var value: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var lock_shader := load("res://Scripts/Shaders/lock_overlay.gdshader")
@onready var lock_shader_material := ShaderMaterial.new()

@onready var glow_shader := load("res://Scripts/Shaders/glow_overlay.gdshader")
@onready var dice_material := ShaderMaterial.new()


func _ready():
	add_to_group("dice")
	lock_shader_material.shader = lock_shader
	dice_material.shader = glow_shader
	sprite.material = dice_material
	dice_material.set_shader_parameter("glow_strength", 0.0)
	dice_material.set_shader_parameter("lock_overlay_strength", 0.6 if is_locked else 0.0)

	if dice_textures.is_empty():
		for i in range(1, 7):
			dice_textures[i] = load("res://Resources/Art/Dice/dieWhite_border%d.png" % i)

	update_visual()
	connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	connect("mouse_exited", Callable(self, "_on_mouse_exited"))

func roll():
	if is_locked:
		return
	value = randi() % sides + 1
	emit_signal("rolled", value)
	animate_roll()
	update_visual()

func animate_roll():
	var tween := get_tree().create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1, 1), 0.1).set_delay(0.1)

func update_visual():
	sprite.texture = dice_textures.get(value, null)
	dice_material.set_shader_parameter("lock_overlay_strength", 0.6 if is_locked else 0.0)

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_lock()
		emit_signal("clicked")

func _on_mouse_entered():
	var tween := get_tree().create_tween()

	tween.parallel().tween_method(
		func(strength):
			dice_material.set_shader_parameter("glow_strength", strength),
		0.0, 0.5, 0.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property(
		self, "scale", Vector2(1.2, 1.2), 0.2
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _on_mouse_exited():
	var tween := get_tree().create_tween()

	tween.parallel().tween_method(
		func(strength):
			dice_material.set_shader_parameter("glow_strength", strength),
		0.5, 0.0, 0.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property(
		self, "scale", Vector2(1.0, 1.0), 0.2
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func toggle_lock():
	is_locked = !is_locked
	update_visual()

func animate_entry(from_position: Vector2, duration := 0.4):
	position = from_position
	var tween := get_tree().create_tween()
	tween.tween_property(self, "position", home_position, duration)\
		.set_trans(Tween.TRANS_BOUNCE)\
		.set_ease(Tween.EASE_OUT)

func unlock():
	is_locked = false
	update_visual()
