extends Area2D
class_name Dice

const DiceColorClass = preload("res://Scripts/Core/dice_color.gd")

## Dice state machine enum
enum DiceState {
	ROLLABLE,   # Ready to be rolled at start of turn
	ROLLED,     # Has been rolled, can be locked or scored
	LOCKED,     # Locked by player, will not roll but can be scored
	DISABLED    # After scoring, cannot interact
}

signal rolled(value: int)
signal selected(dice: Dice)
signal clicked
signal mod_sell_requested(mod_id: String, dice: Dice)
signal color_changed(dice: Dice, new_color: DiceColor.Type)
signal state_changed(dice: Dice, old_state: DiceState, new_state: DiceState)

var active_mods: Dictionary = {}  # id -> Mod
var home_position: Vector2 = Vector2.ZERO
var _can_process_input := true
var _lock_shader_enabled := true
@export var is_locked: bool = false

# State machine properties
var current_state: DiceState = DiceState.ROLLABLE
var _previous_state: DiceState = DiceState.ROLLABLE

@export var dice_data: DiceData

var value: int = 1
var color: DiceColorClass.Type = DiceColorClass.Type.NONE

# Signal for when this die is locked
signal die_locked(die: Dice)

@onready var sprite: Sprite2D = $Sprite2D
@onready var dice_combined_shader := load("res://Scripts/Shaders/dice_combined_effects.gdshader")
@onready var dice_material := ShaderMaterial.new()

@onready var mod_container: Control = $ModContainer
@onready var color_label_bg: PanelContainer = $ColorLabelBg
@onready var color_hover_label: Label = $ColorLabelBg/ColorHoverLabel
const ModIconScene := preload("res://Scenes/Mods/ModIcon.tscn")

var _is_hovering := false


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
	
	# Connect hover signals for colored dice tooltips
	if not is_connected("mouse_entered", _on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
		
	if not is_connected("mouse_exited", _on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	
	# Apply direct styling to color tooltip if it exists
	if color_label_bg and color_hover_label:
		_apply_hover_tooltip_style(color_label_bg)
		_apply_hover_label_style(color_hover_label)
		
	set_dice_input_enabled(true)
	set_lock_shader_enabled(true)

	# Create shader material if it doesn't exist
	if not material:
		material = ShaderMaterial.new()
		material.shader = preload("res://Scripts/Shaders/disabled_dice.gdshader")
		material.set_shader_parameter("disabled", false)

## State Machine Methods

## set_state(new_state: DiceState)
##
## Changes the dice state and handles all necessary transitions and validations.
## Emits state_changed signal and updates visual representations accordingly.
func set_state(new_state: DiceState) -> void:
	if new_state == current_state:
		return
		
	var old_state = current_state
	_previous_state = current_state
	current_state = new_state
	
	# Handle state-specific logic first
	match new_state:
		DiceState.ROLLABLE:
			_can_process_input = true
			is_locked = false
		DiceState.ROLLED:
			_can_process_input = true
			is_locked = false
		DiceState.LOCKED:
			_can_process_input = true
			is_locked = true
		DiceState.DISABLED:
			_can_process_input = false
			is_locked = false
	
	# Update visual representation based on new state (after is_locked is set)
	_update_state_visual()
	
	emit_signal("state_changed", self, old_state, new_state)
	print("[Dice] State changed from ", DiceState.keys()[old_state], " to ", DiceState.keys()[new_state])

## can_roll() -> bool
##
## Returns true if the dice can be rolled in its current state.
func can_roll() -> bool:
	return current_state == DiceState.ROLLABLE

## can_lock() -> bool  
##
## Returns true if the dice can be locked in its current state.
func can_lock() -> bool:
	return current_state == DiceState.ROLLED and _can_process_input

## can_score() -> bool
##
## Returns true if the dice can be used for scoring in its current state.
func can_score() -> bool:
	return current_state in [DiceState.ROLLED, DiceState.LOCKED]

## _update_state_visual()
##
## Updates visual elements based on current state.
func _update_state_visual() -> void:
	match current_state:
		DiceState.ROLLABLE:
			# Reset to default appearance
			if dice_material:
				dice_material.set_shader_parameter("lock_overlay_strength", 0.0)
				dice_material.set_shader_parameter("disabled", false)
		DiceState.ROLLED:
			# Available for interaction, no special visual
			if dice_material:
				dice_material.set_shader_parameter("lock_overlay_strength", 0.0)
				dice_material.set_shader_parameter("disabled", false)
		DiceState.LOCKED:
			# Show lock overlay
			if dice_material and _lock_shader_enabled:
				dice_material.set_shader_parameter("lock_overlay_strength", 0.6)
				dice_material.set_shader_parameter("disabled", false)
				print("[Dice] Applied lock overlay visual feedback")
		DiceState.DISABLED:
			# Show disabled/grayed out appearance
			if dice_material:
				dice_material.set_shader_parameter("disabled", true)
				dice_material.set_shader_parameter("lock_overlay_strength", 0.0)
	
	# Update existing visual elements
	update_visual()

func roll() -> void:
	if not can_roll():
		#print("[Dice] Cannot roll - state:", DiceState.keys()[current_state], "locked:", is_locked)
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
	
	# Transition to ROLLED state
	set_state(DiceState.ROLLED)
	
	emit_signal("rolled", value)
	animate_roll()
	update_visual()

## Lock this die and emit die_locked signal
func lock() -> void:
	if not can_lock():
		#print("[Dice] Cannot lock - state:", DiceState.keys()[current_state])
		return

	set_state(DiceState.LOCKED)
	emit_signal("die_locked", self)

func set_dice_input_enabled(enabled: bool) -> void:
	_can_process_input = enabled


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
		# Use state machine to determine if input should be processed
		if current_state == DiceState.DISABLED:
			print("[Dice] Ignoring input - dice is DISABLED")
			shake_denied()  # Add shake effect when trying to interact while disabled
			return
		
		print("[Dice] Click detected on dice in state:", get_state_name())
		emit_signal("selected", self)
		emit_signal("clicked")
		
		if current_state == DiceState.ROLLED:
			print("[Dice] Attempting to lock dice")
			lock()
		elif current_state == DiceState.LOCKED:
			print("[Dice] Attempting to unlock dice")
			unlock()
		else:
			print("[Dice] Cannot lock/unlock from state:", get_state_name())

func _on_mouse_entered():
	_is_hovering = true
	
	if current_state == DiceState.DISABLED:
		shake_denied()
		return  # Don't show hover effects if disabled
	
	var tween := get_tree().create_tween()

	tween.parallel().tween_method(
		func(strength):
			dice_material.set_shader_parameter("glow_strength", strength),
		0.0, 0.5, 0.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property(
		self, "scale", Vector2(1.2, 1.2), 0.2
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Show color tooltip for colored dice
	if color != DiceColor.Type.NONE and color_hover_label and color_label_bg:
		_update_color_tooltip()
		color_label_bg.visible = true
		color_label_bg.modulate.a = 0.0
		
		# Animate tooltip appearance
		tween.parallel().tween_property(color_label_bg, "modulate:a", 1.0, 0.2)

func _on_mouse_exited():
	_is_hovering = false
	
	if current_state == DiceState.DISABLED:
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
	
	# Hide color tooltip
	if color_label_bg:
		color_label_bg.visible = false

func toggle_lock():
	if current_state == DiceState.ROLLED:
		lock()
	elif current_state == DiceState.LOCKED:
		unlock()
	else:
		print("[Dice] Cannot toggle lock - current state:", DiceState.keys()[current_state])

## animate_entry(from_position: Vector2, duration: float)
##
## Animates the die entering from a starting position to its home position.
## Uses bounce easing for a playful feel.
func animate_entry(from_position: Vector2, duration := 0.4) -> void:
	position = from_position
	var tween := get_tree().create_tween()
	tween.tween_property(self, "position", home_position, duration)\
		.set_trans(Tween.TRANS_BOUNCE)\
		.set_ease(Tween.EASE_OUT)


signal exit_complete(die: Dice)

## animate_exit(to_position: Vector2, duration: float)
##
## Animates the die exiting from its current position to a target position.
## Uses back easing for a smooth departure and emits exit_complete when done.
func animate_exit(to_position: Vector2, duration := 0.3) -> void:
	var tween := get_tree().create_tween()
	
	# Scale down and move out
	tween.set_parallel(true)
	tween.tween_property(self, "position", to_position, duration)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.3, 0.3), duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, duration * 0.8)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	
	# Connect to tween finished using bound callable to avoid freed lambda capture
	tween.finished.connect(_on_exit_tween_finished)


## _on_exit_tween_finished()
##
## Called when exit animation tween completes. Emits exit_complete signal.
func _on_exit_tween_finished() -> void:
	if is_instance_valid(self):
		emit_signal("exit_complete", self)


## reset_visual_for_spawn()
##
## Resets visual properties to default for next spawn (scale, modulate, etc.)
func reset_visual_for_spawn() -> void:
	scale = Vector2.ONE
	modulate = Color.WHITE


func unlock() -> void:
	if current_state == DiceState.LOCKED:
		set_state(DiceState.ROLLED)
	else:
		print("[Dice] Cannot unlock - current state:", DiceState.keys()[current_state])

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

## Assign random color to dice based on chance rates and unlocked status
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
		
	# Check what colored dice features are unlocked AND purchased
	var progress_manager = get_node_or_null("/root/ProgressManager")
	var available_colors = []
	
	if progress_manager:
		# Check each colored dice feature unlock status AND purchase status
		if progress_manager.is_item_unlocked("green_dice") and color_manager.is_color_purchased(DiceColor.Type.GREEN):
			available_colors.append(DiceColor.Type.GREEN)
		if progress_manager.is_item_unlocked("red_dice") and color_manager.is_color_purchased(DiceColor.Type.RED):
			available_colors.append(DiceColor.Type.RED)
		if progress_manager.is_item_unlocked("purple_dice") and color_manager.is_color_purchased(DiceColor.Type.PURPLE):
			available_colors.append(DiceColor.Type.PURPLE)
		if progress_manager.is_item_unlocked("blue_dice") and color_manager.is_color_purchased(DiceColor.Type.BLUE):
			available_colors.append(DiceColor.Type.BLUE)
	
	if available_colors.size() == 0:
		#print("[Dice] No colored dice purchased for this session - setting to NONE")
		_set_color(DiceColor.Type.NONE)
		return
		
	var old_color = color
	var new_color = DiceColor.Type.NONE
	
	#print("[Dice] Colors enabled, checking random assignment from purchased colors:", available_colors)
	
	# Check each available color type for random assignment
	for color_type in available_colors:
		var chance = color_manager.get_modified_color_chance(color_type)
		if chance > 0:
			var color_roll = randi() % chance
			#print("[Dice] Color", DiceColor.get_color_name(color_type), "chance 1/", chance, "rolled:", color_roll)
			if color_roll == 0:
				new_color = color_type
				#print("[Dice] SUCCESS! Assigned color:", DiceColor.get_color_name(new_color))
				break  # First color that hits wins
	
	if new_color == DiceColor.Type.NONE:
		#print("[Dice] No color assigned, staying NONE")
		pass
	
	_set_color(new_color)
	
	# Emit signal if color changed
	if old_color != color:
		#print("[Dice] Color changed from", DiceColor.get_color_name(old_color), "to", DiceColor.get_color_name(color))
		emit_signal("color_changed", self, color)
	else:
		pass
		#print("[Dice] Color unchanged:", DiceColor.get_color_name(color))

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

## Update the color tooltip text based on dice color and value
func _update_color_tooltip() -> void:
	if not color_hover_label:
		return
		
	var tooltip_text = ""
	var color_name = DiceColor.get_color_name(color)
	
	match color:
		DiceColor.Type.GREEN:
			tooltip_text = "%s Die\nGrants $%d money" % [color_name, value]
		DiceColor.Type.RED:
			tooltip_text = "%s Die\nAdds +%d points" % [color_name, value]
		DiceColor.Type.PURPLE:
			tooltip_text = "%s Die\nMultiplies score ×%d" % [color_name, value]
		DiceColor.Type.BLUE:
			tooltip_text = "%s Die\nScore multiplier ×%d" % [color_name, value]
		_:
			tooltip_text = "%s Die" % color_name
	
	color_hover_label.text = tooltip_text

## Helper functions for consistent styling
func _apply_hover_tooltip_style(panel: PanelContainer) -> void:
	print("[Dice] Applying direct hover tooltip style")
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.1, 0.95)  # Dark background
	style_box.border_color = Color(1, 0.8, 0.2, 1)   # Golden border
	style_box.set_border_width_all(4)                # 4px border
	style_box.content_margin_left = 16
	style_box.content_margin_right = 16
	style_box.content_margin_top = 16
	style_box.content_margin_bottom = 16
	style_box.shadow_color = Color(0, 0, 0, 0.5)
	style_box.shadow_size = 2
	panel.add_theme_stylebox_override("panel", style_box)

func _apply_hover_label_style(label: Label) -> void:
	print("[Dice] Applying direct hover label style")
	# Load and apply VCR font
	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
	if vcr_font:
		label.add_theme_font_override("font", vcr_font)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))  # White text

## Public State Control Methods

## make_rollable()
##
## Sets dice to ROLLABLE state for start of turn. This forces the change regardless of current state.
func make_rollable() -> void:
	set_state(DiceState.ROLLABLE)

## make_rollable_if_allowed()
##
## Sets dice to ROLLABLE state only if it's in a valid transition state (ROLLED).
## Does not affect LOCKED or DISABLED dice.
func make_rollable_if_allowed() -> void:
	if current_state == DiceState.ROLLED:
		set_state(DiceState.ROLLABLE)
		print("[Dice] Made rollable from ROLLED state")
	else:
		print("[Dice] Preserving state", get_state_name(), "- not making rollable")

## make_disabled()
##
## Sets dice to DISABLED state after scoring.
func make_disabled() -> void:
	set_state(DiceState.DISABLED)

## get_state() -> DiceState
##
## Returns the current state of the dice.
func get_state() -> DiceState:
	return current_state

## get_state_name() -> String
##
## Returns the current state name as a string for debugging.
func get_state_name() -> String:
	return DiceState.keys()[current_state]
