extends Area2D
class_name Dice

const DiceColorClass = preload("res://Scripts/Core/dice_color.gd")

signal rolled(value: int)
signal selected(dice: Dice)
signal clicked
signal mod_sell_requested(mod_id: String, dice: Dice)
signal color_changed(dice: Dice, new_color: DiceColor.Type)

var active_mods: Dictionary = {}  # id -> Mod
var home_position: Vector2 = Vector2.ZERO
var _can_process_input := true
var _lock_shader_enabled := true
@export var is_locked: bool = false

@export var dice_data: DiceData

var value: int = 1
var color: DiceColorClass.Type = DiceColorClass.Type.NONE

# Signal for when this die is locked
signal die_locked(die: Dice)

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
	
	# Only connect signals if they aren't already connected
	if not is_connected("mouse_entered", _on_mouse_entered):
		connect("mouse_entered", Callable(self, "_on_mouse_entered"))
		
	if not is_connected("mouse_exited", _on_mouse_exited):
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

	# Check for WildDots bias meta (probability 0.0 - 1.0 to force the highest face)
	var bias: float = 0.0
	if has_meta("wild_dots_bias"):
		bias = float(get_meta("wild_dots_bias"))
		remove_meta("wild_dots_bias")

	# If bias triggers, force the highest face (e.g., 6 on d6)
	if bias > 0.0 and randf() < bias:
		value = dice_data.sides
	else:
		# Generate value between 1 and number of sides
		value = (randi() % dice_data.sides) + 1

	# Assign color based on random chance (if colors are enabled)
	_assign_random_color()
	#print("[Dice] Rolling", dice_data.display_name, "- got:", value, "color:", DiceColorClass.get_color_name(color))
	emit_signal("rolled", value)
	animate_roll()
	update_visual()

## Lock this die and emit die_locked signal
func lock() -> void:
	if not _can_process_input:
		#print("[Dice] Cannot lock - input disabled")
		return

	is_locked = true
	update_visual()  # Use update_visual to handle shader state
	emit_signal("die_locked", self)

func set_dice_input_enabled(enabled: bool) -> void:
	_can_process_input = enabled
	#print("[Dice] Input processing ", "enabled" if enabled else "disabled", " for ", name)

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
	# Replace check for non-existent "select_die" action with direct mouse button check
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _can_process_input:
			print("[Dice] Ignoring input - processing disabled")
			shake_denied()  # Add shake effect when trying to interact while disabled
			return
		#print("[Dice] Die selected:", name)
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
	
	# Connect the sell signal
	if not icon.is_connected("mod_sell_requested", _on_mod_sell_requested):
		icon.mod_sell_requested.connect(_on_mod_sell_requested)
	
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

func _on_mod_sell_requested(mod_id: String) -> void:
	#print("[Dice] MOD SELL REQUESTED:", mod_id)
	#print("[Dice] Emitting mod_sell_requested signal to GameController")
	emit_signal("mod_sell_requested", mod_id, self)

func check_mod_outside_clicks(event_position: Vector2) -> void:
	# Check all mod icons for outside clicks
	for icon in mod_container.get_children():
		if icon is ModIcon:
			icon.check_outside_click(event_position)

## Assign random color to dice based on chance rates
## Called when dice is rolled
func _assign_random_color() -> void:
	#print("[Dice] Assigning random color...")
	
	# Check if color system is enabled
	var color_manager = _get_dice_color_manager()
	if not color_manager:
		print("[Dice] No DiceColorManager found - setting to NONE")
		_set_color(DiceColor.Type.NONE)
		return
	
	if not color_manager.colors_enabled:
		print("[Dice] Colors disabled - setting to NONE")
		_set_color(DiceColor.Type.NONE)
		return
		
	var old_color = color
	var new_color = DiceColor.Type.NONE
	
	#print("[Dice] Colors enabled, checking random assignment...")
	
	# Check each color type for random assignment
	for color_type in DiceColor.get_all_colors():
		var chance = DiceColor.get_color_chance(color_type)
		if chance > 0:
			var color_roll = randi() % chance
			#print("[Dice] Color", DiceColor.get_color_name(color_type), "chance 1/", chance, "rolled:", color_roll)
			if color_roll == 0:
				new_color = color_type
				#print("[Dice] SUCCESS! Assigned color:", DiceColor.get_color_name(new_color))
				break  # First color that hits wins
	
	if new_color == DiceColor.Type.NONE:
		print("[Dice] No color assigned, staying NONE")
	
	_set_color(new_color)
	
	# Emit signal if color changed
	if old_color != color:
		#print("[Dice] Color changed from", DiceColor.get_color_name(old_color), "to", DiceColor.get_color_name(color))
		emit_signal("color_changed", self, color)
	else:
		print("[Dice] Color unchanged:", DiceColor.get_color_name(color))

## Get DiceColorManager safely
## @return DiceColorManager node or null if not found
func _get_dice_color_manager():
	if get_tree():
		var manager = get_tree().get_first_node_in_group("dice_color_manager")
		if manager:
			return manager
		
		# Fallback: try to find autoload directly
		var autoload_node = get_tree().get_first_node_in_group("dice_color_manager")
		if not autoload_node:
			autoload_node = get_node_or_null("/root/DiceColorManager")
		return autoload_node
	return null

## Set dice color and update visual effects
## @param new_color: DiceColor.Type to set
func _set_color(new_color: DiceColor.Type) -> void:
	color = new_color
	_update_color_shader()

## Update shader parameters based on current color
func _update_color_shader() -> void:
	if not dice_material:
		print("[Dice] ERROR: No dice_material for color shader update")
		return
	
	print("[Dice] Updating shader for color:", DiceColor.get_color_name(color))
		
	# Reset all color shader parameters
	dice_material.set_shader_parameter("green_color_strength", 0.0)
	dice_material.set_shader_parameter("red_color_strength", 0.0)
	dice_material.set_shader_parameter("purple_color_strength", 0.0)
	dice_material.set_shader_parameter("blue_color_strength", 0.0)
	
	# Set appropriate color strength
	match color:
		DiceColor.Type.GREEN:
			dice_material.set_shader_parameter("green_color_strength", 0.8)
			print("[Dice] Set GREEN shader strength to 0.8")
		DiceColor.Type.RED:
			dice_material.set_shader_parameter("red_color_strength", 0.8)
			print("[Dice] Set RED shader strength to 0.8")
		DiceColor.Type.PURPLE:
			dice_material.set_shader_parameter("purple_color_strength", 0.8)
			print("[Dice] Set PURPLE shader strength to 0.8")
		DiceColor.Type.BLUE:
			dice_material.set_shader_parameter("blue_color_strength", 0.8)
			print("[Dice] Set BLUE shader strength to 0.8")
		DiceColor.Type.NONE:
			print("[Dice] All color strengths set to 0.0 (NONE)")
		_:
			print("[Dice] WARNING: Unknown color type:", color)

## Get current dice color
## @return DiceColor.Type current color of this die
func get_color() -> DiceColor.Type:
	return color

## Force set dice color (for debug/testing)
## @param new_color: DiceColor.Type to force set
func force_color(new_color: DiceColor.Type) -> void:
	var old_color = color
	#print("[Dice] FORCE_COLOR: Changing from", DiceColor.get_color_name(old_color), "to", DiceColor.get_color_name(new_color))
	_set_color(new_color)
	
	# Emit signal if color changed
	if old_color != color:
		#print("[Dice] Color changed successfully - emitting signal")
		emit_signal("color_changed", self, color)
	else:
		print("[Dice] Color unchanged")

## Clear dice color back to none
func clear_color() -> void:
	force_color(DiceColor.Type.NONE)
