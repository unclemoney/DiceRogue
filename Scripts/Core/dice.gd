class_name Dice
extends Area2D

signal rolled(value: int)
signal selected(dice: Dice)
signal clicked

static var dice_textures := {}
var home_position: Vector2 = Vector2.ZERO
var _can_process_input := true
var _lock_shader_enabled := true

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

func set_dice_input_enabled(enabled: bool) -> void:
	_can_process_input = enabled
	print("[Dice] Input processing ", "enabled" if enabled else "disabled", " for ", name)

func set_lock_shader_enabled(enabled: bool) -> void:
	_lock_shader_enabled = enabled
	# Update shader visibility if die is locked
	if is_locked and has_node("Sprite2D"):
		$Sprite2D.material.set_shader_parameter("enabled", enabled)

func animate_roll():
	var tween := get_tree().create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1, 1), 0.1).set_delay(0.1)

func update_visual():
	sprite.texture = dice_textures.get(value, null)
	dice_material.set_shader_parameter("lock_overlay_strength", 0.6 if is_locked else 0.0)


func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("select_die") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		if not _can_process_input:
			print("[Dice] Ignoring input - processing disabled")
			shake_denied()  # Add shake effect when trying to interact while disabled
			return
		print("[Dice] Die selected:", name)
		emit_signal("selected", self)
		emit_signal("clicked")
		
		if not is_locked:
			lock()
		else:
			unlock()
			
func _on_mouse_entered():
	if not _can_process_input:
		#shake_denied()
		return  # Don't show hover effects if input is disabled
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
	if not _can_process_input:
		return
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
	if not _can_process_input:
		print("[Dice] Cannot toggle lock - input disabled")
		return
		
	is_locked = !is_locked
	update_visual()

func animate_entry(from_position: Vector2, duration := 0.4):
	position = from_position
	var tween := get_tree().create_tween()
	tween.tween_property(self, "position", home_position, duration)\
		.set_trans(Tween.TRANS_BOUNCE)\
		.set_ease(Tween.EASE_OUT)

func lock() -> void:
	if not _can_process_input:
		print("[Dice] Cannot lock - input disabled")
		return
		
	is_locked = true
	if has_node("Sprite2D") and _lock_shader_enabled:
		$Sprite2D.material.set_shader_parameter("enabled", true)

func unlock() -> void:
	is_locked = false
	if has_node("Sprite2D"):
		$Sprite2D.material.set_shader_parameter("enabled", false)
	update_visual()

func shake_denied() -> void:
	var tween := get_tree().create_tween()
	# Quick left-right shake
	tween.tween_property(self, "position:x", position.x - 5, 0.05)
	tween.tween_property(self, "position:x", position.x + 5, 0.05)
	tween.tween_property(self, "position:x", position.x, 0.05)
	# Optional: Add subtle color flash
	tween.parallel().tween_property(sprite, "modulate", Color(1.5, 0.3, 0.3), 0.05)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.1)