extends Node
class_name ScreenShake

signal shake_finished

@export var noise_shake_speed := 15.0
@export var noise_shake_fade := 10.0
@export var noise_shake_strength := 60.0

var noise := FastNoiseLite.new()
var noise_i := 0.0
var shake_strength := 0.0
var shake_fade := 0.0
var original_pos := Vector2.ZERO

func _ready() -> void:
	randomize()
	noise.seed = randi()
	noise.frequency = 0.5

func _process(delta: float) -> void:
	if shake_strength <= 0:
		return
		
	shake_strength = move_toward(shake_strength, 0, shake_fade * delta)
	
	noise_i += delta * noise_shake_speed
	var x := noise.get_noise_2d(1, noise_i) * shake_strength
	var y := noise.get_noise_2d(100, noise_i) * shake_strength
	
	owner.position = original_pos + Vector2(x, y)
	
	if shake_strength <= 0:
		owner.position = original_pos
		emit_signal("shake_finished")

func shake(intensity: float = 1.0, duration: float = 0.5) -> void:
	shake_strength = noise_shake_strength * intensity
	shake_fade = shake_strength / duration
	original_pos = owner.position