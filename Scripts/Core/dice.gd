class_name Dice
extends Area2D

signal rolled(value: int)
signal selected(dice: Dice)
signal clicked

var active_mods: Dictionary = {}  # id -> Mod
var home_position: Vector2 = Vector2.ZERO
var _can_process_input := true
var _lock_shader_enabled := true
@export var is_locked: bool = false

@export var dice_data: DiceData
var value: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var dice_combined_shader := load("res://Scripts/Shaders/dice_combined_effects.gdshader")
@onready var dice_material := ShaderMaterial.new()

@onready var mod_container: Control = $ModContainer
const ModIconScene := preload("res://Scenes/Mods/ModIcon.tscn")


func _ready():
	add_to_group("dice")
	
	if not dice_data:
		push_error("[Dice] No DiceData resource assigned!")
		return
		
	# Set up combined shader
	dice_material.shader = dice_combined_shader
	sprite.material = dice_material
	dice_material.set_shader_parameter("glow_strength", 0.0)
	dice_material.set_shader_parameter("lock_overlay_strength", 0.6 if is_locked else 0.0)
	dice_material.set_shader_parameter("disabled", false)

	update_visual()
	connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	connect("mouse_exited", Callable(self, "_on_mouse_exited"))
	set_dice_input_enabled(true)
	set_lock_shader_enabled(true)

	# Create shader material if it doesn't exist
	if not material:
		material = ShaderMaterial.new()
		material.shader = preload("res://Scripts/Shaders/disabled_dice.gdshader")
		material.set_shader_parameter("disabled", false)

func roll() -> void:
	if is_locked:
		return
		
	if not dice_data:
		push_error("[Dice] Cannot roll - no DiceData assigned!")
		return
		
	# Generate value between 1 and number of sides
	value = (randi() % dice_data.sides) + 1
	print("[Dice] Rolling", dice_data.display_name, "- got:", value)
	
	emit_signal("rolled", value)
	animate_roll()
	update_visual()

func set_dice_input_enabled(enabled: bool) -> void:
	_can_process_input = enabled
	print("[Dice] Input processing ", "enabled" if enabled else "disabled", " for ", name)

func set_lock_shader_enabled(enabled: bool) -> void:
	_lock_shader_enabled = enabled
	# Update shader visibility based on both lock state and enabled state
	if has_node("Sprite2D"):
		dice_material.set_shader_parameter("lock_overlay_strength", 
			0.6 if (is_locked && enabled) else 0.0)

func animate_roll():
	var tween := get_tree().create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1, 1), 0.1).set_delay(0.1)

func update_visual():
	if not dice_data:
		push_error("[Dice] Cannot update visual - no DiceData assigned!")
		return
		
	if value <= dice_data.textures.size():
		sprite.texture = dice_data.textures[value - 1]
	else:
		push_error("[Dice] Invalid value for current dice:", value)
	
	dice_material.set_shader_parameter("lock_overlay_strength", 
		0.6 if (is_locked && _lock_shader_enabled) else 0.0)


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
		shake_denied()
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
	update_visual()  # Use update_visual to handle shader state

func unlock() -> void:
	is_locked = false
	update_visual()  # Use update_visual to handle shader state

func shake_denied() -> void:
	var original_x = position.x  # Store current x position
	var tween := get_tree().create_tween()
	
	# Quick left-right shake around current position
	tween.tween_property(self, "position:x", original_x - 5, 0.05)
	tween.tween_property(self, "position:x", original_x + 5, 0.05)
	tween.tween_property(self, "position:x", original_x, 0.05)
	
	# Color flash in parallel
	tween.parallel().tween_property(sprite, "modulate", Color(1.5, 0.3, 0.3), 0.05)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	# Ensure we end up at home position
	tween.tween_property(self, "position", home_position, 0.1)

func add_mod(mod_data: ModData) -> void:
	if active_mods.has(mod_data.id):
		print("[Dice] Mod already active:", mod_data.id)
		return
		
	var mod_scene = mod_data.scene
	if not mod_scene:
		push_error("[Dice] No scene found for mod:", mod_data.id)
		return
		
	var mod = mod_scene.instantiate()
	if not mod:
		push_error("[Dice] Failed to instantiate mod:", mod_data.id)
		return
		
	active_mods[mod_data.id] = mod
	add_child(mod)
	mod.apply(self)
	
	# Create and add mod icon from scene
	var icon = ModIconScene.instantiate() as ModIcon
	if not icon:
		push_error("[Dice] Failed to instantiate ModIcon")
		return
		
	icon.data = mod_data
	mod_container.add_child(icon)
	
	# Position icon in bottom right
	icon.position = Vector2(
		mod_container.size.x - icon.size.x - 2,
		mod_container.size.y - icon.size.y - 2
	)

func remove_mod(id: String) -> void:
	if active_mods.has(id):
		var mod = active_mods[id]
		mod.remove()
		mod.queue_free()
		active_mods.erase(id)
		
		# Remove associated icon
		for icon in mod_container.get_children():
			if icon is ModIcon and icon.data.id == id:
				icon.queue_free()
				break

func has_mod(id: String) -> bool:
	return active_mods.has(id)

func get_mod(id: String) -> Mod:
	return active_mods.get(id)
